#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# Resolve script directory and load shared libraries
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/request.sh"


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

    --help)
      echo "Usage: $0 --request <rollback-request.json>"
      exit 0
      ;;

    *)
      deployment_die "Unknown argument: $1"
      ;;

  esac
done


# ============================================================================
# Validate request
# ============================================================================

[[ -n "$REQUEST_FILE" ]] || {
  echo "Usage: $0 --request <rollback-request.json>" >&2
  exit 1
}

request_init "$REQUEST_FILE"
request_validate


# ============================================================================
# Resolve deployment target
# ============================================================================

DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-vm}"


# ============================================================================
# Dispatch to the rollback adapter
# ============================================================================

case "$DEPLOYMENT_TARGET" in

  vm)
    exec "$SCRIPT_DIR/adapters/vm/rollback.sh" \
      --request "$REQUEST_FILE"
    ;;

  aws-ecs)
    exec "$SCRIPT_DIR/adapters/aws-ecs/rollback.sh" \
      --request "$REQUEST_FILE"
    ;;

  *)
    deployment_die \
      "Unsupported deployment target: $DEPLOYMENT_TARGET"
    ;;

esac