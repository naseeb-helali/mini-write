#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# deployment_die
#
# Terminate the deployment with a fatal error message on stderr.
# ============================================================================

deployment_die() {
  echo "DEPLOYMENT ERROR: $*" >&2
  exit 1
}


# ============================================================================
# deployment_require_command
#
# Fail if a required executable is not available on PATH.
# ============================================================================

deployment_require_command() {
  local command_name="$1"

  command -v "$command_name" >/dev/null 2>&1 \
    || deployment_die "Required command not found: $command_name"
}


# ============================================================================
# deployment_require_file
#
# Fail if a required file does not exist.
# ============================================================================

deployment_require_file() {
  local file_path="$1"

  [[ -f "$file_path" ]] \
    || deployment_die "Required file not found: $file_path"
}


# ============================================================================
# deployment_require_directory
#
# Fail if a required directory does not exist.
# ============================================================================

deployment_require_directory() {
  local directory_path="$1"

  [[ -d "$directory_path" ]] \
    || deployment_die "Required directory not found: $directory_path"
}


# ============================================================================
# deployment_log
#
# Emit an informational deployment log line on stdout.
# ============================================================================

deployment_log() {
  echo "[deployment] $*"
}


# ============================================================================
# deployment_require_nonempty
#
# Fail if a required variable does not have a non-empty value.
# ============================================================================

deployment_require_nonempty() {
  local variable_name="$1"
  local variable_value="${2:-}"

  [[ -n "$variable_value" ]] \
    || deployment_die "$variable_name must not be empty"
}