#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DIR="${1:-$SCRIPT_DIR}"
RENDERED="$(mktemp -t mini-write-stage-4.2.XXXXXX.yaml)"
trap 'rm -f "$RENDERED"' EXIT

command -v kubectl >/dev/null 2>&1 || {
  echo "ERROR: kubectl is required for Kustomize rendering." >&2
  exit 1
}
test -f "$DIR/kustomization.yaml" || {
  echo "ERROR: kustomization.yaml not found in: $DIR" >&2
  exit 1
}

kubectl kustomize "$DIR" > "$RENDERED"

if grep -qE 'REPLACE_WITH|CHANGEME|TODO_IMAGE_DIGEST' "$RENDERED"; then
  echo "ERROR: unresolved placeholders found in rendered manifests." >&2
  exit 1
fi

if command -v kubeconform >/dev/null 2>&1; then
  kubeconform -strict -summary "$RENDERED"
else
  echo "WARN: kubeconform is not installed; Kubernetes schema validation was skipped." >&2
fi

echo "PASS: Kustomize rendered successfully. No resources were applied."
