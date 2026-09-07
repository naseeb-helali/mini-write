#!/usr/bin/env bash

set -euo pipefail

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$ADAPTER_DIR/../../lib/common.sh"
source "$ADAPTER_DIR/../../lib/request.sh"

REQUEST_FILE=""

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

[[ -n "$REQUEST_FILE" ]] || \
    deployment_die "Rollback request is required"

request_init "$REQUEST_FILE"
request_validate

deployment_require_command aws

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

deployment_log "Rolling back API service."

aws ecs update-service \
    --cluster "$AWS_ECS_CLUSTER" \
    --service "$AWS_ECS_API_SERVICE" \
    --task-definition "$AWS_ECS_API_ROLLBACK_TASK_DEFINITION" \
    --region "$AWS_REGION" \
    >/dev/null

deployment_log "Rolling back Worker service."

aws ecs update-service \
    --cluster "$AWS_ECS_CLUSTER" \
    --service "$AWS_ECS_WORKER_SERVICE" \
    --task-definition "$AWS_ECS_WORKER_ROLLBACK_TASK_DEFINITION" \
    --region "$AWS_REGION" \
    >/dev/null

deployment_log "Waiting for rollback stability."

aws ecs wait services-stable \
    --cluster "$AWS_ECS_CLUSTER" \
    --services \
        "$AWS_ECS_API_SERVICE" \
        "$AWS_ECS_WORKER_SERVICE" \
    --region "$AWS_REGION"

deployment_log "AWS ECS rollback completed successfully."