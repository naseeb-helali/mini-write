#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# Resolve adapter directory and load shared libraries
# ============================================================================

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_ROOT="${DEPLOYMENT_ROOT:-/opt/deploy}"

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
  || deployment_die "Deployment request is required"

request_init "$REQUEST_FILE"
request_validate "staging"


# ============================================================================
# Validate deployment runtime
# ============================================================================

deployment_require_file \
  "$DEPLOYMENT_ROOT/scripts/deploy.sh"

[[ -x "$DEPLOYMENT_ROOT/scripts/deploy.sh" ]] \
  || deployment_die \
      "VM deployment runtime is not executable: $DEPLOYMENT_ROOT/scripts/deploy.sh"


# ============================================================================
# Validate required commands
# ============================================================================

deployment_require_command docker


# ============================================================================
# Read request identity
# ============================================================================

SOURCE_SHA="$(request_release_source)"
API_DIGEST="$(request_api_digest)"
WORKER_DIGEST="$(request_worker_digest)"


# ============================================================================
# Resolve artifact registry and image references
# ============================================================================

ARTIFACT_REGISTRY="${ARTIFACT_REGISTRY:-ghcr.io/${GITHUB_REPOSITORY:-}}"

deployment_require_nonempty \
  "ARTIFACT_REGISTRY" \
  "$ARTIFACT_REGISTRY"

API_IMAGE="${ARTIFACT_REGISTRY}/mini-write-api@${API_DIGEST}"
WORKER_IMAGE="${ARTIFACT_REGISTRY}/mini-write-worker@${WORKER_DIGEST}"


# ============================================================================
# Log deployment target
# ============================================================================

deployment_log "VM deployment adapter"
deployment_log "Environment: $(request_environment)"
deployment_log "Release: $(request_release_id)"
deployment_log "Source: $SOURCE_SHA"
deployment_log "API: $API_IMAGE"
deployment_log "Worker: $WORKER_IMAGE"


# ============================================================================
# Emit resolved deployment request
# ============================================================================

cat <<EOF
VM deployment request resolved.

Target:
  vm

Environment:
  $(request_environment)

Release:
  $(request_release_id)

API image:
  $API_IMAGE

Worker image:
  $WORKER_IMAGE
EOF


# ============================================================================
# Execute VM deployment runtime
# ============================================================================

"$DEPLOYMENT_ROOT/scripts/deploy.sh" \
  "$API_IMAGE" \
  "$WORKER_IMAGE"


# ============================================================================
# Done
# ============================================================================

deployment_log "VM deployment completed successfully."