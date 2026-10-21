#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# Defaults
# ============================================================================

REQUEST_FILE=""


# ============================================================================
# request_init
#
# Initialize the shared request file path and verify it exists.
# ============================================================================

request_init() {
  [[ $# -eq 1 ]] || {
    echo "Usage: request_init <request.json>" >&2
    return 1
  }

  REQUEST_FILE="$1"

  [[ -f "$REQUEST_FILE" ]] || {
    echo "Deployment request not found: $REQUEST_FILE" >&2
    return 1
  }
}


# ============================================================================
# request_require_jq
#
# Fail if jq is not available on PATH.
# ============================================================================

request_require_jq() {
  command -v jq >/dev/null 2>&1 || {
    echo "jq is required to process deployment requests" >&2
    return 1
  }
}


# ============================================================================
# request_get
#
# Extract a scalar value from the loaded request using a jq expression.
# ============================================================================

request_get() {
  local expression="$1"

  request_require_jq

  jq -er "$expression" "$REQUEST_FILE"
}


# ============================================================================
# request_schema_version
# ============================================================================

request_schema_version() {
  request_get '.schemaVersion'
}


# ============================================================================
# request_project
# ============================================================================

request_project() {
  request_get '.project'
}


# ============================================================================
# request_environment
# ============================================================================

request_environment() {
  request_get '.environment'
}


# ============================================================================
# request_release_id
# ============================================================================

request_release_id() {
  request_get '.release.id'
}


# ============================================================================
# request_release_source
# ============================================================================

request_release_source() {
  request_get '.release.source'
}


# ============================================================================
# request_release_version
# ============================================================================

request_release_version() {
  request_get '.release.version'
}


# ============================================================================
# request_api_tag
# ============================================================================

request_api_tag() {
  request_get '.artifacts.api.tag'
}


# ============================================================================
# request_api_digest
# ============================================================================

request_api_digest() {
  request_get '.artifacts.api.digest'
}


# ============================================================================
# request_worker_tag
# ============================================================================

request_worker_tag() {
  request_get '.artifacts.worker.tag'
}


# ============================================================================
# request_worker_digest
# ============================================================================

request_worker_digest() {
  request_get '.artifacts.worker.digest'
}


# ============================================================================
# request_validate
#
# Validate the loaded request against the expected schema, identity, and
# digest contract. Optionally enforce a specific environment.
# ============================================================================

request_validate() {
  local expected_environment="${1:-}"

  request_require_jq

  local schema_version
  local project
  local environment
  local release_id
  local release_source
  local release_version
  local api_tag
  local api_digest
  local worker_tag
  local worker_digest

  schema_version="$(request_schema_version)"
  project="$(request_project)"
  environment="$(request_environment)"
  release_id="$(request_release_id)"
  release_source="$(request_release_source)"
  release_version="$(request_release_version)"
  api_tag="$(request_api_tag)"
  api_digest="$(request_api_digest)"
  worker_tag="$(request_worker_tag)"
  worker_digest="$(request_worker_digest)"

  # ---- Schema identity -----------------------------------------------------
  [[ "$schema_version" == "1.0" ]] || {
    echo "Unsupported deployment request schema: $schema_version" >&2
    return 1
  }

  # ---- Project identity ----------------------------------------------------
  [[ "$project" == "mini-write" ]] || {
    echo "Invalid project: $project" >&2
    return 1
  }

  # ---- Environment format --------------------------------------------------
  [[ "$environment" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
    echo "Invalid environment: $environment" >&2
    return 1
  }

  # ---- Optional environment assertion -------------------------------------
  if [[ -n "$expected_environment" ]]; then
    [[ "$environment" == "$expected_environment" ]] || {
      echo \
        "Request environment '$environment' does not match expected '$expected_environment'" \
        >&2
      return 1
    }
  fi

  # ---- Release identity ----------------------------------------------------
  [[ "$release_id" =~ ^[0-9a-f]{40}$ ]] || {
    echo "Invalid release.id" >&2
    return 1
  }

  [[ "$release_source" =~ ^[0-9a-f]{40}$ ]] || {
    echo "Invalid release.source" >&2
    return 1
  }

  [[ "$release_id" == "$release_source" ]] || {
    echo "release.id must equal release.source" >&2
    return 1
  }

  [[ -n "$release_version" ]] || {
    echo "release.version must not be empty" >&2
    return 1
  }

  # ---- Artifact identity ---------------------------------------------------
  [[ "$api_tag" == "$release_source" ]] || {
    echo "API artifact tag does not match release source" >&2
    return 1
  }

  [[ "$worker_tag" == "$release_source" ]] || {
    echo "Worker artifact tag does not match release source" >&2
    return 1
  }

  # ---- Artifact digests ----------------------------------------------------
  [[ "$api_digest" =~ ^sha256:[0-9a-f]{64}$ ]] || {
    echo "Invalid API digest" >&2
    return 1
  }

  [[ "$worker_digest" =~ ^sha256:[0-9a-f]{64}$ ]] || {
    echo "Invalid Worker digest" >&2
    return 1
  }

  # ---- Report --------------------------------------------------------------
  echo "Deployment request validation passed."
}