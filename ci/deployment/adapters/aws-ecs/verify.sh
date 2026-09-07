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
    deployment_die "Deployment request is required"

request_init "$REQUEST_FILE"
request_validate

deployment_require_command aws
deployment_require_command jq
deployment_require_command curl

AWS_REGION="${AWS_REGION:-}"

deployment_require_nonempty "AWS_REGION" "$AWS_REGION"
deployment_require_nonempty "AWS_ECS_CLUSTER" "${AWS_ECS_CLUSTER:-}"
deployment_require_nonempty "AWS_ECS_API_SERVICE" "${AWS_ECS_API_SERVICE:-}"
deployment_require_nonempty "AWS_ECS_WORKER_SERVICE" "${AWS_ECS_WORKER_SERVICE:-}"

deployment_log "Waiting for ECS services to be stable."

aws ecs wait services-stable \
    --cluster "$AWS_ECS_CLUSTER" \
    --services \
        "$AWS_ECS_API_SERVICE" \
        "$AWS_ECS_WORKER_SERVICE" \
    --region "$AWS_REGION"

deployment_log "Checking ECS service task counts."

SERVICE_DATA="$(
    aws ecs describe-services \
        --cluster "$AWS_ECS_CLUSTER" \
        --services \
            "$AWS_ECS_API_SERVICE" \
            "$AWS_ECS_WORKER_SERVICE" \
        --region "$AWS_REGION"
)"

echo "$SERVICE_DATA" |
    jq -e '
      .services
      | length == 2
      and all(
          .;
          (.desiredCount == .runningCount)
          and (.runningCount > 0)
        )
    ' >/dev/null

deployment_log "ECS service verification passed."

API_HEALTH_URL="${API_HEALTH_URL:-}"

if [[ -n "$API_HEALTH_URL" ]]; then
    deployment_log "Checking application readiness endpoint."

    curl \
        --fail \
        --silent \
        --show-error \
        --retry 10 \
        --retry-delay 5 \
        --retry-connrefused \
        "$API_HEALTH_URL" \
        >/dev/null

    deployment_log "Application readiness verification passed."
else
    deployment_log \
      "API_HEALTH_URL not configured; ECS-level verification completed."
fi

deployment_log "AWS ECS environment verification completed successfully."