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
# Validate VM verifier runtime
# ============================================================================

deployment_require_file \
  "$DEPLOYMENT_ROOT/scripts/runtime/verifier.sh"

[[ -x "$DEPLOYMENT_ROOT/scripts/runtime/verifier.sh" ]] \
  || deployment_die \
      "VM verifier is not executable"


# ============================================================================
# Execute VM verification runtime
# ============================================================================

deployment_log "Running existing VM deployment verification runtime."

"$DEPLOYMENT_ROOT/scripts/runtime/verifier.sh"


# ============================================================================
# Done
# ============================================================================

deployment_log "VM environment verification completed successfully."