#!/usr/bin/env bash
set -euo pipefail
die() { echo "KUBERNETES ROLLBACK ERROR: $*" >&2; exit 1; }
for c in curl jq; do command -v "$c" >/dev/null 2>&1 || die "$c is required"; done
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${FAILED_SOURCE_SHA:?FAILED_SOURCE_SHA is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
[[ "$FAILED_SOURCE_SHA" =~ ^[0-9a-f]{40}$ ]] || die "Invalid failed SHA"
owner="${GITHUB_REPOSITORY%%/*}"; repo="${GITHUB_REPOSITORY##*/}"
api="${GITHUB_API_URL:-https://api.github.com}"; workflow="${KUBERNETES_CD_WORKFLOW:-kubernetes-cd.yml}"
prefix="mini-write-kubernetes-production-verification-"
headers=(-H 'Accept: application/vnd.github+json' -H "Authorization: Bearer ${GITHUB_TOKEN}" -H 'X-GitHub-Api-Version: 2022-11-28')
echo "Searching only ${workflow} for a previous successful Kubernetes Production verification."
for page in $(seq 1 10); do
  runs="$(curl --fail --silent --show-error "${headers[@]}" "${api}/repos/${owner}/${repo}/actions/workflows/${workflow}/runs?status=completed&per_page=100&page=${page}")"
  count="$(jq -r '.workflow_runs | length' <<<"$runs")"; [[ "$count" -gt 0 ]] || break
  mapfile -t ids < <(jq -r --arg failed "$FAILED_SOURCE_SHA" '.workflow_runs[] | select(.conclusion=="success") | select(.event=="push" or .event=="workflow_dispatch") | .id' <<<"$runs")
  for id in "${ids[@]}"; do
    artifacts="$(curl --fail --silent --show-error "${headers[@]}" "${api}/repos/${owner}/${repo}/actions/runs/${id}/artifacts?per_page=100")"
    name="$(jq -r --arg p "$prefix" '[.artifacts[] | select(.expired==false and (.name|startswith($p)))] | sort_by(.created_at) | last | .name // empty' <<<"$artifacts")"
    [[ -n "$name" ]] || continue
    sha="${name#"$prefix"}"
    [[ "$sha" =~ ^[0-9a-f]{40}$ && "$sha" != "$FAILED_SOURCE_SHA" ]] || continue
    { echo "run_id=$id"; echo "source_sha=$sha"; echo "artifact_name=$name"; } >> "$GITHUB_OUTPUT"
    echo "Resolved previous verified Production release: run=${id}, source=${sha}"
    exit 0
  done
  [[ "$count" -eq 100 ]] || break
done
die "No non-expired previous Kubernetes Production verification artifact found."
