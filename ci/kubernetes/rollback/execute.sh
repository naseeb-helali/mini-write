#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# Helpers
# ============================================================================

die() {
  echo "KUBERNETES ROLLBACK ERROR: $*" >&2
  exit 1
}


# ============================================================================
# Validate inputs
# ============================================================================

: "${FAILED_SOURCE_SHA:?FAILED_SOURCE_SHA is required}"
: "${TARGET_SOURCE_SHA:?TARGET_SOURCE_SHA is required}"
: "${ROLLBACK_EVIDENCE:?ROLLBACK_EVIDENCE is required}"

[[ -f "$ROLLBACK_EVIDENCE" ]] \
  || die "Rollback evidence not found"


# ============================================================================
# Resolve script paths
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"


# ============================================================================
# Read previous known-good identity from evidence
# ============================================================================

api_name="$(jq -er '.artifact.api.name' "$ROLLBACK_EVIDENCE")"
api_digest="$(jq -er '.artifact.api.digest' "$ROLLBACK_EVIDENCE")"

worker_name="$(jq -er '.artifact.worker.name' "$ROLLBACK_EVIDENCE")"
worker_digest="$(jq -er '.artifact.worker.digest' "$ROLLBACK_EVIDENCE")"

version="$(jq -er '.release.version' "$ROLLBACK_EVIDENCE")"


# ============================================================================
# Build rollback deployment request
# ============================================================================

mkdir -p rollback-request rollback-output

jq -n \
  --arg failed "$FAILED_SOURCE_SHA" \
  --arg target "$TARGET_SOURCE_SHA" \
  --arg version "$version" \
  --arg an "$api_name" \
  --arg ad "$api_digest" \
  --arg wn "$worker_name" \
  --arg wd "$worker_digest" \
  '
    {
      schemaVersion: "1.0",
      project: "mini-write",
      environment: "rollback",
      release: {
        id: $target,
        source: $target,
        version: $version
      },
      artifacts: {
        api: {
          name: $an,
          tag: $target,
          digest: $ad
        },
        worker: {
          name: $wn,
          tag: $target,
          digest: $wd
        }
      },
      rollback: {
        failedRelease: {
          id: $failed,
          source: $failed
        },
        targetRelease: {
          id: $target,
          source: $target
        }
      },
      reason: {
        type: "production-verification-failure",
        message: "Kubernetes Production release failed deployment or verification."
      }
    }
  ' \
  > rollback-request/request.json

jq empty rollback-request/request.json


# ============================================================================
# Deploy previous known-good digests
# ============================================================================

export DEPLOYMENT_OUTPUT_DIR=rollback-output

"$K8S_ROOT/deployment/deploy.sh" \
  --request rollback-request/request.json \
  --output-dir rollback-output


# ============================================================================
# Report
# ============================================================================

echo "Previous known-good Kubernetes Production digests applied. Rollback verification is a separate gate."