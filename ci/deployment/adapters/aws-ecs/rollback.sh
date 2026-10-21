#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# Resolve adapter directory and load shared libraries
# ============================================================================

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$ADAPTER_DIR/../../lib/common.sh"
source "$ADAPTER_DIR/../../lib/request.sh"


# ============================================================================
# Defaults
# ============================================================================

REQUEST_FILE=""


# ============================================================================
# Argument parsing
# ============================================================================

while [[ $# -gt 0 ]]; do
  case "$1" in

    --request)
      [[ $# -ge 2 ]] || deployment_die "--request requires a value"
      REQUEST_FILE="$2"
      shift 2
      ;;

    *)
      deployment_die "Unknown argument: $1"
      ;;

  esac
done


# ============================================================================
# Validate request
# ============================================================================

[[ -n "$REQUEST_FILE" ]] \
  || deployment_die "Rollback request is required"

request_init "$REQUEST_FILE"
request_validate


# ============================================================================
# Validate required commands
# ============================================================================

deployment_require_command aws


# ============================================================================
# Validate required environment variables
# ============================================================================

AWS_REGION="${AWS_REGION:-}"

deployment_require_nonempty "AWS_REGION" "$AWS_REGION"
deployment_require_nonempty "AWS_ECS_CLUSTER" "${AWS_ECS_CLUSTER:-}"
deployment_require_nonempty "AWS_ECS_API_SERVICE" "${AWS_ECS_API_SERVICE:-}"
deployment_require_nonempty "AWS_ECS_WORKER_SERVICE" "${AWS_ECS_WORKER_SERVICE:-}"

deployment_require_nonempty \
  "AWS_ECS_API_ROLLBACK_TASK_DEFINITION" \
  "${AWS_ECS_API_ROLLBACK_TASK_DEFINITION:-}"

deployment_require_nonempty \
  "AWS_ECS_WORKER_ROLLBACK_TASK_DEFINITION" \
  "${AWS_ECS_WORKER_ROLLBACK_TASK_DEFINITION:-}"


# ============================================================================
# Roll back API service
# ============================================================================

deployment_log "Rolling back API service."

aws ecs update-service \
  --cluster "$AWS_ECS_CLUSTER" \
  --service "$AWS_ECS_API_SERVICE" \
  --task-definition "$AWS_ECS_API_ROLLBACK_TASK_DEFINITION" \
  --region "$AWS_REGION" \
  >/dev/null


# ============================================================================
# Roll back Worker service
# ============================================================================

deployment_log "Rolling back Worker service."

aws ecs update-service \
  --cluster "$AWS_ECS_CLUSTER" \
  --service "$AWS_ECS_WORKER_SERVICE" \
  --task-definition "$AWS_ECS_WORKER_ROLLBACK_TASK_DEFINITION" \
  --region "$AWS_REGION" \
  >/dev/null


# ============================================================================
# Wait for rollback stability
# ============================================================================

deployment_log "Waiting for rollback stability."

aws ecs wait services-stable \
  --cluster "$AWS_ECS_CLUSTER" \
  --services \
    "$AWS_ECS_API_SERVICE" \
    "$AWS_ECS_WORKER_SERVICE" \
  --region "$AWS_REGION"


# ============================================================================
# Read rollback artifact digests
# ============================================================================

API_DIGEST="$(request_api_digest)"
WORKER_DIGEST="$(request_worker_digest)"


# ============================================================================
# Write rollback identity
# ============================================================================

OUTPUT_DIR="${DEPLOYMENT_OUTPUT_DIR:-deployment-output}"

mkdir -p "$OUTPUT_DIR"

cat > "$OUTPUT_DIR/deployment.json" <<EOF
{
  "schemaVersion": "1.0",
  "deploymentTarget": "aws-ecs",
  "cluster": "$AWS_ECS_CLUSTER",
  "api": {
    "service": "$AWS_ECS_API_SERVICE",
    "taskDefinitionArn": "$AWS_ECS_API_ROLLBACK_TASK_DEFINITION"
  },
  "worker": {
    "service": "$AWS_ECS_WORKER_SERVICE",
    "taskDefinitionArn": "$AWS_ECS_WORKER_ROLLBACK_TASK_DEFINITION"
  },
  "artifact": {
    "apiDigest": "$API_DIGEST",
    "workerDigest": "$WORKER_DIGEST"
  }
}
EOF

deployment_log "Rollback identity written to $OUTPUT_DIR/deployment.json"


# ============================================================================
# Done
# ============================================================================

deployment_log "AWS ECS rollback completed successfully."