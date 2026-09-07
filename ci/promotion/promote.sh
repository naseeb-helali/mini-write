#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REQUEST_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --request)
            [[ $# -ge 2 ]] || {
                echo "--request requires a value" >&2
                exit 1
            }

            REQUEST_FILE="$2"
            shift 2
            ;;

        --help)
            echo "Usage: $0 --request <promotion-request.json>"
            exit 0
            ;;

        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

[[ -n "$REQUEST_FILE" ]] || {
    echo "Usage: $0 --request <promotion-request.json>" >&2
    exit 1
}

"$SCRIPT_DIR/eligibility.sh" \
    --request "$REQUEST_FILE"

echo "Promotion authorized for execution."
echo "Release:"
jq -r '.release.id' "$REQUEST_FILE"

echo "Source environment:"
jq -r '.sourceEnvironment' "$REQUEST_FILE"

echo "Target environment:"
jq -r '.targetEnvironment' "$REQUEST_FILE"

echo "API digest:"
jq -r '.artifact.api.digest' "$REQUEST_FILE"

echo "Worker digest:"
jq -r '.artifact.worker.digest' "$REQUEST_FILE"