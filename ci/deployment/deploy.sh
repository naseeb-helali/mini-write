#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/request.sh"

REQUEST_FILE=""

usage() {
    cat <<EOF
Usage:
  $0 --request <deployment-request.json>

Environment:
  DEPLOYMENT_TARGET=vm
  DEPLOYMENT_TARGET=aws-ecs
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --request)
            [[ $# -ge 2 ]] || deployment_die "--request requires a value"
            REQUEST_FILE="$2"
            shift 2
            ;;

        --help)
            usage
            exit 0
            ;;

        *)
            deployment_die "Unknown argument: $1"
            ;;
    esac
done

[[ -n "$REQUEST_FILE" ]] || {
    usage >&2
    exit 1
}

request_init "$REQUEST_FILE"
request_validate

DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-vm}"

case "$DEPLOYMENT_TARGET" in

    vm)
        exec "$SCRIPT_DIR/adapters/vm/deploy.sh" \
            --request "$REQUEST_FILE"
        ;;

    aws-ecs)
        exec "$SCRIPT_DIR/adapters/aws-ecs/deploy.sh" \
            --request "$REQUEST_FILE"
        ;;

    *)
        deployment_die \
            "Unsupported deployment target: $DEPLOYMENT_TARGET"
        ;;

esac