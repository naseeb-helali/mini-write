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

DEPLOYMENT_OUTPUT_DIR="${DEPLOYMENT_OUTPUT_DIR:-deployment-output}"
DEPLOYMENT_IDENTITY_FILE="$DEPLOYMENT_OUTPUT_DIR/deployment.json"

[[ -f "$DEPLOYMENT_IDENTITY_FILE" ]] || \
    deployment_die \
      "Deployment identity not found: $DEPLOYMENT_IDENTITY_FILE"


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

aws ecs describe-task-definition \
  --task-definition mini-write-api \
  --region "$AWS_REGION" |
jq -r '.taskDefinition.containerDefinitions[].name'

aws ecs describe-task-definition \
  --task-definition mini-write-worker \
  --region "$AWS_REGION" |
jq -r '.taskDefinition.containerDefinitions[].name'

verify_service_identity() {
    local service="$1"
    local expected_task_definition="$2"
    local expected_digest="$3"
    local container_name="$4"

    deployment_log \
      "Verifying ECS identity for service: $service"

    local service_data
    service_data="$(
        aws ecs describe-services \
            --cluster "$AWS_ECS_CLUSTER" \
            --services "$service" \
            --region "$AWS_REGION"
    )"

    local actual_task_definition
    actual_task_definition="$(
        echo "$service_data" |
        jq -er '.services[0].taskDefinition'
    )"

    [[ "$actual_task_definition" == "$expected_task_definition" ]] || {
        deployment_die \
          "Task definition mismatch for $service: expected=$expected_task_definition actual=$actual_task_definition"
    }

    local task_arns
    mapfile -t task_arns < <(
        aws ecs list-tasks \
            --cluster "$AWS_ECS_CLUSTER" \
            --service-name "$service" \
            --desired-status RUNNING \
            --region "$AWS_REGION" |
        jq -r '.taskArns[]'
    )

    [[ "${#task_arns[@]}" -gt 0 ]] || {
        deployment_die \
          "No RUNNING tasks found for service $service"
    }

    for task_arn in "${task_arns[@]}"; do

        local task_data
        task_data="$(
            aws ecs describe-tasks \
                --cluster "$AWS_ECS_CLUSTER" \
                --tasks "$task_arn" \
                --region "$AWS_REGION"
        )"

        local task_definition
        task_definition="$(
            echo "$task_data" |
            jq -er '.tasks[0].taskDefinitionArn'
        )"

        [[ "$task_definition" == "$expected_task_definition" ]] || {
            deployment_die \
              "Running task $task_arn is using unexpected task definition: $task_definition"
        }

        local actual_digest
        actual_digest="$(
            echo "$task_data" |
            jq -er \
              --arg name "$container_name" \
              '.tasks[0].containers[]
               | select(.name == $name)
               | .imageDigest'
        )"

        [[ "$actual_digest" == "$expected_digest" ]] || {
            deployment_die \
              "Image digest mismatch for $service: expected=$expected_digest actual=$actual_digest"
        }

        deployment_log \
          "Verified $service task=$task_arn taskDefinition=$task_definition imageDigest=$actual_digest"
    done
}

EXPECTED_API_TASK_DEFINITION="$(
    jq -er '.api.taskDefinitionArn' "$DEPLOYMENT_IDENTITY_FILE"
)"

EXPECTED_WORKER_TASK_DEFINITION="$(
    jq -er '.worker.taskDefinitionArn' "$DEPLOYMENT_IDENTITY_FILE"
)"

EXPECTED_API_DIGEST="$(
    jq -er '.artifact.apiDigest' "$DEPLOYMENT_IDENTITY_FILE"
)"

EXPECTED_WORKER_DIGEST="$(
    jq -er '.artifact.workerDigest' "$DEPLOYMENT_IDENTITY_FILE"
)"

verify_service_identity \
    "$AWS_ECS_API_SERVICE" \
    "$EXPECTED_API_TASK_DEFINITION" \
    "$EXPECTED_API_DIGEST" \
    "mini-write-api"

verify_service_identity \
    "$AWS_ECS_WORKER_SERVICE" \
    "$EXPECTED_WORKER_TASK_DEFINITION" \
    "$EXPECTED_WORKER_DIGEST" \
    "mini-write-worker"

deployment_log "ECS service verification passed."

API_HEALTH_URL="${API_HEALTH_URL:-}"

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


deployment_log "AWS ECS environment verification completed successfully."