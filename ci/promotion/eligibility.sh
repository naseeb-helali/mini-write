#!/usr/bin/env bash

set -euo pipefail

die() {
    echo "PROMOTION ERROR: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || \
        die "Required command not found: $1"
}

REQUEST_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --request)
            [[ $# -ge 2 ]] || die "--request requires a value"
            REQUEST_FILE="$2"
            shift 2
            ;;

        --help)
            echo "Usage: $0 --request <promotion-request.json>"
            exit 0
            ;;

        *)
            die "Unknown argument: $1"
            ;;
    esac
done

[[ -n "$REQUEST_FILE" ]] || {
    echo "Usage: $0 --request <promotion-request.json>" >&2
    exit 1
}

[[ -f "$REQUEST_FILE" ]] || \
    die "Promotion request not found: $REQUEST_FILE"

require_command jq

SCHEMA_VERSION="$(jq -er '.schemaVersion' "$REQUEST_FILE")"
PROJECT="$(jq -er '.project' "$REQUEST_FILE")"
SOURCE_ENVIRONMENT="$(jq -er '.sourceEnvironment' "$REQUEST_FILE")"
TARGET_ENVIRONMENT="$(jq -er '.targetEnvironment' "$REQUEST_FILE")"
RELEASE_ID="$(jq -er '.release.id' "$REQUEST_FILE")"

[[ "$SCHEMA_VERSION" == "1.0" ]] || \
    die "Unsupported promotion schema: $SCHEMA_VERSION"

[[ "$PROJECT" == "mini-write" ]] || \
    die "Invalid project: $PROJECT"

[[ "$SOURCE_ENVIRONMENT" == "staging" ]] || \
    die "Promotion source must be staging"

[[ "$TARGET_ENVIRONMENT" == "production" ]] || \
    die "Promotion target must be production"

[[ "$RELEASE_ID" =~ ^[0-9a-f]{40}$ ]] || \
    die "Invalid release ID"

for service in api worker; do

    digest="$(
        jq -er \
          ".artifact.$service.digest" \
          "$REQUEST_FILE"
    )"

    [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || \
        die "Invalid $service artifact digest"

done

STAGING_VERIFIED="$(
    jq -er '.evidence.stagingVerified' "$REQUEST_FILE"
)"

[[ "$STAGING_VERIFIED" == "true" ]] || \
    die "Staging verification evidence is missing"

ARTIFACT_IDENTITY_VERIFIED="$(
    jq -er '.evidence.artifactIdentityVerified' "$REQUEST_FILE"
)"

[[ "$ARTIFACT_IDENTITY_VERIFIED" == "true" ]] || \
    die "Artifact identity verification failed"

echo "Promotion eligibility checks passed."