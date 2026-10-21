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
  || deployment_die "Rollback request is required"

request_init "$REQUEST_FILE"
request_validate


# ============================================================================
# Validate rollback runtime
# ============================================================================

deployment_require_file \
  "$DEPLOYMENT_ROOT/scripts/rollback.sh"

[[ -x "$DEPLOYMENT_ROOT/scripts/rollback.sh" ]] \
  || deployment_die \
      "VM rollback runtime is not executable"


# ============================================================================
# Execute VM rollback runtime
# ============================================================================

deployment_log "Executing existing VM rollback runtime."

"$DEPLOYMENT_ROOT/scripts/rollback.sh"


# ============================================================================
# Done
# ============================================================================

deployment_log "VM rollback completed successfully."