#!/usr/bin/env bash

set -euo pipefail

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_ROOT="${DEPLOYMENT_ROOT:-/opt/deploy}"

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
request_validate "staging"

deployment_require_file \
    "$DEPLOYMENT_ROOT/scripts/runtime/verifier.sh"

[[ -x "$DEPLOYMENT_ROOT/scripts/runtime/verifier.sh" ]] || \
    deployment_die \
      "VM verifier is not executable"

deployment_log "Running existing VM deployment verification runtime."

"$DEPLOYMENT_ROOT/scripts/runtime/verifier.sh"

deployment_log "VM environment verification completed successfully."