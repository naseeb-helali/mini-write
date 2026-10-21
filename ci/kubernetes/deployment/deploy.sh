#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# Helpers
# ============================================================================

die() {
  echo "KUBERNETES DEPLOYMENT ERROR: $*" >&2
  exit 1
}


# ============================================================================
# Defaults
# ============================================================================

REQUEST=""
MANIFEST_DIR="${K8S_MANIFEST_DIR:-infra/kubernetes-ec2/manifests/workloads/staging}"
OUTPUT_DIR="${DEPLOYMENT_OUTPUT_DIR:-deployment-output}"
NAMESPACE="${K8S_NAMESPACE:-mini-write-staging}"


# ============================================================================
# Argument parsing
# ============================================================================

while [[ $# -gt 0 ]]; do
  case "$1" in

    --request)
      [[ $# -ge 2 ]] || die "--request requires a value"
      REQUEST="$2"
      shift 2
      ;;

    --manifest-dir)
      [[ $# -ge 2 ]] || die "--manifest-dir requires a value"
      MANIFEST_DIR="$2"
      shift 2
      ;;

    --output-dir)
      [[ $# -ge 2 ]] || die "--output-dir requires a value"
      OUTPUT_DIR="$2"
      shift 2
      ;;

    --help)
      echo "Usage: $0 --request <request.json> [--manifest-dir <dir>] [--output-dir <dir>]"
      exit 0
      ;;

    *)
      die "Unknown argument: $1"
      ;;

  esac
done


# ============================================================================
# Environment validation
# ============================================================================

[[ "${DEPLOYMENT_TARGET:-}" == kubernetes-ec2 ]] \
  || die "DEPLOYMENT_TARGET must be kubernetes-ec2"

[[ -f "$REQUEST" ]] \
  || die "Deployment request not found: $REQUEST"

[[ -f "$MANIFEST_DIR/kustomization.yaml" ]] \
  || die "Kustomize base not found: $MANIFEST_DIR/kustomization.yaml"

for c in kubectl jq; do
  command -v "$c" >/dev/null 2>&1 || die "$c is required"
done

: "${KUBECONFIG:?KUBECONFIG must point to the Kubernetes deployer kubeconfig}"


# ============================================================================
# Read deployment request
# ============================================================================

schema="$(jq -er '.schemaVersion' "$REQUEST")"
project="$(jq -er '.project' "$REQUEST")"
environment="$(jq -er '.environment' "$REQUEST")"

source_sha="$(jq -er '.release.source' "$REQUEST")"
release_id="$(jq -er '.release.id' "$REQUEST")"

api_tag="$(jq -er '.artifacts.api.tag' "$REQUEST")"
worker_tag="$(jq -er '.artifacts.worker.tag' "$REQUEST")"

api_name="$(jq -er '.artifacts.api.name' "$REQUEST")"
worker_name="$(jq -er '.artifacts.worker.name' "$REQUEST")"

api_digest="$(jq -er '.artifacts.api.digest' "$REQUEST")"
worker_digest="$(jq -er '.artifacts.worker.digest' "$REQUEST")"


# ============================================================================
# Validate request identity
# ============================================================================

[[ "$schema" == "1.0" && "$project" == "mini-write" ]] \
  || die "Invalid request schema or project"

[[ "$environment" == staging || "$environment" == production || "$environment" == rollback ]] \
  || die "Unsupported environment: $environment"

[[ "$source_sha" =~ ^[0-9a-f]{40}$ && "$release_id" == "$source_sha" ]] \
  || die "Invalid source SHA or release ID"

[[ "$api_tag" == "$source_sha" && "$worker_tag" == "$source_sha" ]] \
  || die "Artifact tags must match the source SHA"

[[ "$api_digest" =~ ^sha256:[0-9a-f]{64}$ && "$worker_digest" =~ ^sha256:[0-9a-f]{64}$ ]] \
  || die "Invalid image digest"


# ============================================================================
# Validate repository identity
# ============================================================================

registry="${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID is required}.dkr.ecr.${AWS_REGION:?AWS_REGION is required}.amazonaws.com"

[[ "$api_name" == "$registry/mini-write-api" ]] \
  || die "Unexpected API repository: $api_name"

[[ "$worker_name" == "$registry/mini-write-worker" ]] \
  || die "Unexpected Worker repository: $worker_name"


# ============================================================================
# Render manifests with requested image digests
# ============================================================================

api_image="${api_name}@${api_digest}"
worker_image="${worker_name}@${worker_digest}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cp -a "$MANIFEST_DIR/." "$tmp_dir/"

cat >> "$tmp_dir/kustomization.yaml" <<KUSTOMIZE_IMAGES

images:
  - name: ${api_name}
    newName: ${api_name}
    digest: ${api_digest}
  - name: ${worker_name}
    newName: ${worker_name}
    digest: ${worker_digest}
KUSTOMIZE_IMAGES

mkdir -p "$OUTPUT_DIR"

kubectl kustomize "$tmp_dir" > "$OUTPUT_DIR/rendered-manifests.yaml"

grep -Fq "image: ${api_image}" "$OUTPUT_DIR/rendered-manifests.yaml" \
  || die "Rendered API image does not match request"

grep -Fq "image: ${worker_image}" "$OUTPUT_DIR/rendered-manifests.yaml" \
  || die "Rendered Worker image does not match request"

grep -Fq "namespace: ${NAMESPACE}" "$OUTPUT_DIR/rendered-manifests.yaml" \
  || die "Rendered manifests target an unexpected namespace"


# ============================================================================
# Apply manifests
# ============================================================================

echo "Applying Kubernetes manifests to ${NAMESPACE}."

if [[ "${MARK_DEPLOYMENT_STARTED:-false}" == "true" ]]; then

  : "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required when MARK_DEPLOYMENT_STARTED=true}"

  mkdir -p deployment-state

  jq -n \
    --arg release "$release_id" \
    --arg source "$source_sha" \
    --arg environment "$environment" \
    '{
      schemaVersion: "1.0",
      project: "mini-write",
      environment: $environment,
      release: $release,
      source: $source,
      status: "mutation-started"
    }' \
    > deployment-state/deployment-started.json

  jq empty deployment-state/deployment-started.json

  echo "deployment_started=true" >> "$GITHUB_OUTPUT"

fi

kubectl apply -k "$tmp_dir"


# ============================================================================
# Snapshot applied Deployment templates
# ============================================================================

kubectl -n "$NAMESPACE" get deployments api worker -o json > "$OUTPUT_DIR/deployment.json"

jq -e \
  --arg api "$api_image" \
  --arg worker "$worker_image" \
  '
    [.items[]
      | {
          name: .metadata.name,
          image: .spec.template.spec.containers[0].image
        }
    ] as $d
    | any($d[]; .name == "api"    and .image == $api)
      and any($d[]; .name == "worker" and .image == $worker)
  ' \
  "$OUTPUT_DIR/deployment.json" >/dev/null \
  || die "Applied Deployment templates do not contain requested images"


# ============================================================================
# Done
# ============================================================================

echo "Manifests applied. Rollout, runtime image identity, and application readiness verification remain separate gates."