#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# Helpers
# ============================================================================

die() {
  echo "KUBERNETES TARGET VALIDATION ERROR: $*" >&2
  exit 1
}


# ============================================================================
# Validate environment argument
# ============================================================================

ENVIRONMENT="${1:-}"

[[ "$ENVIRONMENT" == staging || "$ENVIRONMENT" == production || "$ENVIRONMENT" == rollback ]] \
  || die "Usage: $0 {staging|production|rollback}"


# ============================================================================
# Validate required environment variables
# ============================================================================

required=(
  DEPLOYMENT_TARGET
  REGISTRY_TYPE
  AWS_ACCOUNT_ID
  AWS_REGION
  K8S_CLUSTER_NAME
  K8S_NAMESPACE
  K8S_CONTROL_PLANE_INSTANCE_ID
  KUBECONFIG
  K8S_MANIFEST_DIR
)

for name in "${required[@]}"; do
  [[ -n "${!name:-}" ]] || die "$name is required for $ENVIRONMENT"
done


# ============================================================================
# Validate fixed deployment target values
# ============================================================================

[[ "$DEPLOYMENT_TARGET" == kubernetes-ec2 ]] \
  || die "Expected DEPLOYMENT_TARGET=kubernetes-ec2; got '$DEPLOYMENT_TARGET'"

[[ "$REGISTRY_TYPE" == ecr ]] \
  || die "This EC2 Kubernetes cluster supports ECR node-side pulls only; REGISTRY_TYPE must be ecr"

[[ "$AWS_ACCOUNT_ID" == 496494570164 ]] \
  || die "Unexpected AWS account: $AWS_ACCOUNT_ID"

[[ "$AWS_REGION" == us-east-1 ]] \
  || die "Unexpected AWS region: $AWS_REGION"

[[ "$K8S_CLUSTER_NAME" == mini-write-staging-k8s ]] \
  || die "Unexpected Kubernetes cluster name: $K8S_CLUSTER_NAME"

[[ "$K8S_NAMESPACE" == mini-write-staging ]] \
  || die "Unexpected Kubernetes namespace: $K8S_NAMESPACE"

[[ "$K8S_CONTROL_PLANE_INSTANCE_ID" == i-0552c82b27dd23b29 ]] \
  || die "Unexpected SSM control-plane target"


# ============================================================================
# Validate kubeconfig
# ============================================================================

[[ "$KUBECONFIG" == /home/janad/.kube/mini-write-deployer/kubeconfig ]] \
  || die "Unexpected deployer kubeconfig path"

[[ -r "$KUBECONFIG" ]] \
  || die "Deployer kubeconfig is not readable"

mode="$(stat -c %a "$KUBECONFIG")"

[[ "$mode" == 600 ]] \
  || die "Deployer kubeconfig must have mode 600; got $mode"


# ============================================================================
# Validate kustomize base
# ============================================================================

[[ -f "$K8S_MANIFEST_DIR/kustomization.yaml" ]] \
  || die "Kustomize base is missing: $K8S_MANIFEST_DIR"


# ============================================================================
# Validate required runner commands
# ============================================================================

for cmd in aws kubectl jq python3 curl setsid session-manager-plugin; do
  command -v "$cmd" >/dev/null 2>&1 \
    || die "Required runner command is missing: $cmd"
done


# ============================================================================
# Validate kubeconfig endpoint and context
# ============================================================================

server="$(
  KUBECONFIG="$KUBECONFIG" kubectl config view --minify \
    -o jsonpath='{.clusters[0].cluster.server}'
)"

[[ "$server" == https://localhost:6443 ]] \
  || die "Kubeconfig server must be https://localhost:6443; got '$server'"

context="$(
  KUBECONFIG="$KUBECONFIG" kubectl config current-context
)"

[[ -n "$context" ]] \
  || die "Kubeconfig has no current context"


# ============================================================================
# Validate rendered workload manifests
# ============================================================================

rendered="$(kubectl kustomize "$K8S_MANIFEST_DIR")" \
  || die "Unable to render Kubernetes workload manifests"

grep -Fq "namespace: $K8S_NAMESPACE" <<<"$rendered" \
  || die "Rendered manifests do not target namespace $K8S_NAMESPACE"

grep -Fq 'name: api' <<<"$rendered" \
  || die "Rendered manifests do not contain API workload"

grep -Fq 'name: worker' <<<"$rendered" \
  || die "Rendered manifests do not contain Worker workload"


# ============================================================================
# Report
# ============================================================================

echo "Deployment target validated: $DEPLOYMENT_TARGET"
echo "Registry validated: $REGISTRY_TYPE (node-side ECR credential provider)"
echo "AWS target validated: $AWS_ACCOUNT_ID / $AWS_REGION"
echo "Kubernetes target validated: $K8S_CLUSTER_NAME / $K8S_NAMESPACE"
echo "SSM target validated: $K8S_CONTROL_PLANE_INSTANCE_ID"
echo "Runner prerequisites, kubeconfig endpoint, and rendered workload target validated for $ENVIRONMENT."