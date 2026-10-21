#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# Helpers
# ============================================================================

die() {
  echo "KUBERNETES ARTIFACT ERROR: $*" >&2
  exit 1
}


# ============================================================================
# Defaults
# ============================================================================

MANIFEST=""
EXPECTED_SHA=""


# ============================================================================
# Argument parsing
# ============================================================================

while [[ $# -gt 0 ]]; do
  case "$1" in

    --manifest)
      [[ $# -ge 2 ]] || die "--manifest requires a value"
      MANIFEST="$2"
      shift 2
      ;;

    --expected-sha)
      [[ $# -ge 2 ]] || die "--expected-sha requires a value"
      EXPECTED_SHA="$2"
      shift 2
      ;;

    --help)
      echo "Usage: $0 --manifest <artifact-manifest.json> --expected-sha <40-char-sha>"
      exit 0
      ;;

    *)
      die "Unknown argument: $1"
      ;;

  esac
done


# ============================================================================
# Validate inputs
# ============================================================================

[[ -f "$MANIFEST" ]] \
  || die "Manifest not found: $MANIFEST"

[[ "$EXPECTED_SHA" =~ ^[0-9a-f]{40}$ ]] \
  || die "Invalid expected source SHA"

: "${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID is required}"
: "${AWS_REGION:?AWS_REGION is required}"

command -v jq >/dev/null 2>&1 \
  || die "jq is required"


# ============================================================================
# Expected repository identities
# ============================================================================

api_repo="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/mini-write-api"
worker_repo="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/mini-write-worker"


# ============================================================================
# Validate manifest identity, repository, tag, and digest
# ============================================================================

jq -e \
  --arg sha "$EXPECTED_SHA" \
  --arg api "$api_repo" \
  --arg worker "$worker_repo" \
  '
    .schemaVersion == "1.0"
    and .project == "mini-write"

    and .source.commit == $sha
    and .release.id == $sha
    and (.release.version | type == "string" and length > 0)

    and .artifacts.api.name == $api
    and .artifacts.worker.name == $worker

    and .artifacts.api.tag == $sha
    and .artifacts.worker.tag == $sha

    and (.artifacts.api.digest    | type == "string" and test("^sha256:[0-9a-f]{64}$"))
    and (.artifacts.worker.digest | type == "string" and test("^sha256:[0-9a-f]{64}$"))
  ' \
  "$MANIFEST" >/dev/null \
  || die "Manifest identity, repository, tag, or digest validation failed"


# ============================================================================
# Report
# ============================================================================

echo "Kubernetes CI artifact manifest validated."

jq '{
  source:  .source.commit,
  release: .release,
  api:     .artifacts.api,
  worker:  .artifacts.worker
}' "$MANIFEST"