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

AWS_REGION="${AWS_REGION:-}"

deployment_require_nonempty \
    "AWS_REGION" \
    "$AWS_REGION"

deployment_require_nonempty \
    "AWS_ECS_CLUSTER" \
    "${AWS_ECS_CLUSTER:-}"

deployment_require_nonempty \
    "AWS_ECS_API_SERVICE" \
    "${AWS_ECS_API_SERVICE:-}"

deployment_require_nonempty \
    "AWS_ECS_WORKER_SERVICE" \
    "${AWS_ECS_WORKER_SERVICE:-}"

SOURCE_SHA="$(request_release_source)"
API_DIGEST="$(request_api_digest)"
WORKER_DIGEST="$(request_worker_digest)"

# حساب الـ registry URL بناءً على نوع الـ registry
if [[ -n "${ARTIFACT_REGISTRY:-}" ]]; then
  # استخدام القيمة الممررة من الـ environment
  REGISTRY_URL="$ARTIFACT_REGISTRY"
elif [[ "${REGISTRY_TYPE:-}" == "ecr" ]]; then
  # حساب ECR URL تلقائيًا
  REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
else
  # الافتراضي GHCR
  REGISTRY_URL="ghcr.io"
fi

API_IMAGE="${REGISTRY_URL}/${API_IMAGE_NAME:-mini-write-api}@${API_DIGEST}"
WORKER_IMAGE="${REGISTRY_URL}/${WORKER_IMAGE_NAME:-mini-write-worker}@${WORKER_DIGEST}"

deployment_log "AWS ECS deployment adapter"
deployment_log "Region: $AWS_REGION"
deployment_log "Cluster: $AWS_ECS_CLUSTER"
deployment_log "API service: $AWS_ECS_API_SERVICE"
deployment_log "Worker service: $AWS_ECS_WORKER_SERVICE"
deployment_log "Release: $(request_release_id)"
deployment_log "Source: $SOURCE_SHA"

deployment_require_nonempty "API_IMAGE" "$API_IMAGE"
deployment_require_nonempty "WORKER_IMAGE" "$WORKER_IMAGE"

register_task_definition() {
    local family="$1"
    local image="$2"

    local tmp_desc_json
    local tmp_reg_json
    tmp_desc_json="$(mktemp)"
    tmp_reg_json="$(mktemp)"

    echo "[deployment] Fetching current task definition for family: ${family}" >&2

    # 1. جلب الـ Task Definition الحالي وتخزينه في ملف مؤقت
    if ! aws ecs describe-task-definition \
            --task-definition "$family" \
            --region "$AWS_REGION" > "$tmp_desc_json" 2>&2; then
        echo "[ERROR] Failed to fetch task definition for family: ${family}" >&2
        cat "$tmp_desc_json" >&2
        rm -f "$tmp_desc_json" "$tmp_reg_json"
        return 1
    fi

    # 2. تحويل الـ JSON وتجهيز الـ Payload الصالح للتسجيل
    jq \
      --arg image "$image" \
      '
      .taskDefinition
      | {
          family,
          taskRoleArn,
          executionRoleArn,
          networkMode,
          containerDefinitions,
          volumes,
          placementConstraints,
          requiresCompatibilities,
          cpu,
          memory,
          pidMode,
          ipcMode,
          proxyConfiguration,
          inferenceAccelerators,
          ephemeralStorage,
          runtimePlatform
        }
      | .containerDefinitions[0].image = $image
      | with_entries(select(.value != null))
      ' "$tmp_desc_json" > "$tmp_reg_json"

    # 3. التحقق من صحة بنية الـ JSON المولد
    if ! jq empty "$tmp_reg_json" 2>/dev/null; then
        echo "[ERROR] Generated Task Definition JSON is invalid for family: ${family}" >&2
        echo "=== Generated JSON Content ===" >&2
        cat "$tmp_reg_json" >&2
        echo "==============================" >&2
        rm -f "$tmp_desc_json" "$tmp_reg_json"
        return 1
    fi

    # 4. تسجيل الـ Task Definition الجديد
    local registered_output
    if ! registered_output="$(aws ecs register-task-definition \
            --cli-input-json "file://$tmp_reg_json" \
            --region "$AWS_REGION" 2>&1)"; then
        echo "[ERROR] Failed to register task definition for family: ${family}" >&2
        echo "$registered_output" >&2
        rm -f "$tmp_desc_json" "$tmp_reg_json"
        return 1
    fi

    # تنظيف الملفات المؤقتة
    rm -f "$tmp_desc_json" "$tmp_reg_json"

    # 5. طباعة الـ ARN فقط إلى stdout لإتاحة التقاطه من المتغير
    echo "$registered_output" | jq -r '.taskDefinition.taskDefinitionArn'
}

deployment_log "Registering API task definition."

API_TASK_DEFINITION="$(
    register_task_definition \
        "$AWS_ECS_API_TASK_DEFINITION_FAMILY" \
        "$API_IMAGE"
)"

deployment_log "API task definition: $API_TASK_DEFINITION"

deployment_log "Registering Worker task definition."

WORKER_TASK_DEFINITION="$(
    register_task_definition \
        "$AWS_ECS_WORKER_TASK_DEFINITION_FAMILY" \
        "$WORKER_IMAGE"
)"

deployment_log "Worker task definition: $WORKER_TASK_DEFINITION"

OUTPUT_DIR="${DEPLOYMENT_OUTPUT_DIR:-deployment-output}"

mkdir -p "$OUTPUT_DIR"

cat > "$OUTPUT_DIR/deployment.json" <<EOF
{
  "schemaVersion": "1.0",
  "deploymentTarget": "aws-ecs",
  "cluster": "$AWS_ECS_CLUSTER",
  "api": {
    "service": "$AWS_ECS_API_SERVICE",
    "taskDefinitionArn": "$API_TASK_DEFINITION"
  },
  "worker": {
    "service": "$AWS_ECS_WORKER_SERVICE",
    "taskDefinitionArn": "$WORKER_TASK_DEFINITION"
  },
  "artifact": {
    "apiDigest": "$API_DIGEST",
    "workerDigest": "$WORKER_DIGEST"
  }
}
EOF

deployment_log "Deployment identity written to $OUTPUT_DIR/deployment.json"

deployment_log "Updating API ECS service."

aws ecs update-service \
    --cluster "$AWS_ECS_CLUSTER" \
    --service "$AWS_ECS_API_SERVICE" \
    --task-definition "$API_TASK_DEFINITION" \
    --region "$AWS_REGION" \
    >/dev/null

deployment_log "Updating Worker ECS service."

aws ecs update-service \
    --cluster "$AWS_ECS_CLUSTER" \
    --service "$AWS_ECS_WORKER_SERVICE" \
    --task-definition "$WORKER_TASK_DEFINITION" \
    --region "$AWS_REGION" \
    >/dev/null

deployment_log "Waiting for API service stability."

aws ecs wait services-stable \
    --cluster "$AWS_ECS_CLUSTER" \
    --services "$AWS_ECS_API_SERVICE" \
    --region "$AWS_REGION"

deployment_log "Waiting for Worker service stability."

aws ecs wait services-stable \
    --cluster "$AWS_ECS_CLUSTER" \
    --services "$AWS_ECS_WORKER_SERVICE" \
    --region "$AWS_REGION"

deployment_log "AWS ECS deployment completed successfully."