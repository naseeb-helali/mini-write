#!/usr/bin/env bash

set -euo pipefail

die() {
    echo "ROLLBACK ERROR: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || \
        die "Required command not found: $1"
}

require_command jq

: "${FAILED_SOURCE_SHA:?FAILED_SOURCE_SHA is required}"
: "${TARGET_SOURCE_SHA:?TARGET_SOURCE_SHA is required}"
: "${ROLLBACK_EVIDENCE:?ROLLBACK_EVIDENCE is required}"
: "${DEPLOYMENT_TARGET:?DEPLOYMENT_TARGET is required}"

[[ -f "$ROLLBACK_EVIDENCE" ]] || \
    die "Rollback evidence not found"

api_digest="$(
    jq -er '.artifact.api.digest' "$ROLLBACK_EVIDENCE"
)"

worker_digest="$(
    jq -er '.artifact.worker.digest' "$ROLLBACK_EVIDENCE"
)"

version="$(
    jq -er '.release.version' "$ROLLBACK_EVIDENCE"
)"

mkdir -p rollback-request

cat > rollback-request/request.json <<EOF
{
  "schemaVersion": "1.0",
  "project": "mini-write",
  "environment": "production",
  "rollback": {
    "failedRelease": {
      "id": "$FAILED_SOURCE_SHA",
      "source": "$FAILED_SOURCE_SHA"
    },
    "targetRelease": {
      "id": "$TARGET_SOURCE_SHA",
      "source": "$TARGET_SOURCE_SHA",
      "version": "$version"
    }
  },
  "artifacts": {
    "api": {
      "tag": "$TARGET_SOURCE_SHA",
      "digest": "$api_digest"
    },
    "worker": {
      "tag": "$TARGET_SOURCE_SHA",
      "digest": "$worker_digest"
    }
  },
  "reason": {
    "type": "production-verification-failure",
    "message": "Production release failed deployment or verification."
  }
}
EOF

echo "Rollback request:"
cat rollback-request/request.json

echo "Executing rollback adapter."

case "$DEPLOYMENT_TARGET" in

    vm)
        exec ./ci/deployment/adapters/vm/rollback.sh \
            --request rollback-request/request.json
        ;;

    aws-ecs)
        exec ./ci/deployment/adapters/aws-ecs/rollback.sh \
            --request rollback-request/request.json
        ;;

    *)
        die "Unsupported deployment target: $DEPLOYMENT_TARGET"
        ;;

esac
