#!/usr/bin/env bash

set -euo pipefail

die() {
    echo "ROLLBACK ERROR: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || \
        die "Required command not found: $1"
}

require_command jq

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${FAILED_SOURCE_SHA:?FAILED_SOURCE_SHA is required}"

API_URL="https://api.github.com"

owner="${GITHUB_REPOSITORY%%/*}"
repo="${GITHUB_REPOSITORY##*/}"

headers=(
    -H "Accept: application/vnd.github+json"
    -H "Authorization: Bearer ${GITHUB_TOKEN}"
    -H "X-GitHub-Api-Version: 2022-11-28"
)

echo "Searching for previous known-good production release."

runs_json="$(
    curl \
        --fail \
        --silent \
        --show-error \
        "${headers[@]}" \
        "${API_URL}/repos/${owner}/${repo}/actions/workflows/cd.yml/runs?status=success&per_page=100"
)"

mapfile -t candidate_runs < <(
    echo "$runs_json" |
    jq -r \
      --arg failed "$FAILED_SOURCE_SHA" '
      .workflow_runs[]
      | select(
          .conclusion == "success"
          and .head_sha != $failed
          and (
            .event == "push"
            or .event == "workflow_dispatch"
          )
        )
      | .id
    '
)

if [[ "${#candidate_runs[@]}" -eq 0 ]]; then
    die "No previous successful production candidate found."
fi

for run_id in "${candidate_runs[@]}"; do

    artifacts_json="$(
        curl \
            --fail \
            --silent \
            --show-error \
            "${headers[@]}" \
            "${API_URL}/repos/${owner}/${repo}/actions/runs/${run_id}/artifacts"
    )"

    artifact_name="$(
        echo "$artifacts_json" |
        jq -r '
          .artifacts[]
          | select(
              .expired == false
              and (.name | startswith("mini-write-production-verification-"))
            )
          | .name
        ' |
        head -n 1
    )"

    [[ -n "$artifact_name" ]] || continue

    previous_sha="${artifact_name#mini-write-production-verification-}"

    if [[ "$previous_sha" == "$FAILED_SOURCE_SHA" ]]; then
        continue
    fi

    echo "Previous known-good release found:"
    echo "  run: $run_id"
    echo "  source: $previous_sha"
    echo "  artifact: $artifact_name"

    echo "run_id=$run_id" >> "$GITHUB_OUTPUT"
    echo "source_sha=$previous_sha" >> "$GITHUB_OUTPUT"
    echo "artifact_name=$artifact_name" >> "$GITHUB_OUTPUT"

    exit 0
done

die "No non-expired previous production verification evidence found."