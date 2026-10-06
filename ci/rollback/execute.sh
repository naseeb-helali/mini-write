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

api_task_definition="$(
    jq -er '.deployment.api.taskDefinitionArn' "$ROLLBACK_EVIDENCE"
)"

worker_task_definition="$(
    jq -er '.deployment.worker.taskDefinitionArn' "$ROLLBACK_EVIDENCE"
)"

[[ -n "$api_task_definition" ]] || \
    die "API task definition ARN missing from rollback evidence"

[[ -n "$worker_task_definition" ]] || \
    die "Worker task definition ARN missing from rollback evidence"

mkdir -p rollback-request

cat > rollback-request/request.json <<EOF
{
  "schemaVersion": "1.0",
  "project": "mini-write",
  "environment": "production",
  "release": {
    "id": "$TARGET_SOURCE_SHA",
    "source": "$TARGET_SOURCE_SHA",
    "version": "$version"
  },
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

export AWS_ECS_API_ROLLBACK_TASK_DEFINITION="$api_task_definition"
export AWS_ECS_WORKER_ROLLBACK_TASK_DEFINITION="$worker_task_definition"

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