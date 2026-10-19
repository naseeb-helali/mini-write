#!/usr/bin/env bash
set -euo pipefail

die() { echo "AWS IDENTITY VALIDATION ERROR: $*" >&2; exit 1; }
: "${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID is required}"
command -v aws >/dev/null 2>&1 || die "aws CLI is required"
command -v jq >/dev/null 2>&1 || die "jq is required"
identity="$(aws sts get-caller-identity --output json)" || die "Unable to resolve assumed AWS identity"
jq -e --arg account "$AWS_ACCOUNT_ID" '
  .Account == $account
  and (.Arn | contains(":assumed-role/mini-write-github-cd-runner/"))
' <<<"$identity" >/dev/null || die "Runner is not using mini-write-github-cd-runner in account $AWS_ACCOUNT_ID"
echo "AWS OIDC identity verified: $(jq -r '.Arn' <<<"$identity")"
