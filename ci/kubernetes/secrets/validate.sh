#!/usr/bin/env bash
set -euo pipefail

# Validate the fixed Mini-Write Secrets Manager sources and the exact
# namespace-scoped Kubernetes permissions needed by sync.sh.


# ============================================================================
# Helpers
# ============================================================================

die() {
  echo "KUBERNETES SECRET VALIDATION ERROR: $*" >&2
  exit 1
}


# ============================================================================
# Validate required inputs
# ============================================================================

: "${AWS_REGION:?AWS_REGION is required}"
: "${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID is required}"
: "${K8S_NAMESPACE:?K8S_NAMESPACE is required}"
: "${KUBECONFIG:?KUBECONFIG is required}"
: "${K8S_DATABASE_SECRET_ARN:?K8S_DATABASE_SECRET_ARN is required}"
: "${K8S_REDIS_SECRET_ARN:?K8S_REDIS_SECRET_ARN is required}"
: "${K8S_JWT_SECRET_ARN:?K8S_JWT_SECRET_ARN is required}"


# ============================================================================
# Validate fixed AWS and Kubernetes targets
# ============================================================================

[[ "$AWS_REGION"    == "us-east-1"          ]] || die "Unexpected AWS region"
[[ "$AWS_ACCOUNT_ID" == "496494570164"      ]] || die "Unexpected AWS account"
[[ "$K8S_NAMESPACE"  == "mini-write-staging" ]] || die "Unexpected Kubernetes namespace"


# ============================================================================
# Validate fixed Secrets Manager ARNs
# ============================================================================

expected_database='arn:aws:secretsmanager:us-east-1:496494570164:secret:mini-write-staging/database-nl8beV'
expected_redis='arn:aws:secretsmanager:us-east-1:496494570164:secret:mini-write-staging/redis-lIfx33'
expected_jwt='arn:aws:secretsmanager:us-east-1:496494570164:secret:mini-write-staging/jwt-KSUqf8'

[[ "$K8S_DATABASE_SECRET_ARN" == "$expected_database" ]] \
  || die "Database Secret ARN does not match the provisioned resource"

[[ "$K8S_REDIS_SECRET_ARN" == "$expected_redis" ]] \
  || die "Redis Secret ARN does not match the provisioned resource"

[[ "$K8S_JWT_SECRET_ARN" == "$expected_jwt" ]] \
  || die "JWT Secret ARN does not match the provisioned resource"


# ============================================================================
# Validate required commands
# ============================================================================

for cmd in aws kubectl jq; do
  command -v "$cmd" >/dev/null 2>&1 || die "Required command is missing: $cmd"
done


# ============================================================================
# Validate kubeconfig and Kubernetes API connectivity
# ============================================================================

[[ -r "$KUBECONFIG" ]] \
  || die "Kubernetes deployer kubeconfig is not readable"

KUBECONFIG="$KUBECONFIG" kubectl --request-timeout=5s get --raw=/readyz >/dev/null \
  || die "Kubernetes API is not reachable; start the SSM tunnel first"


# ============================================================================
# Validate namespace-scoped Secret permissions
#
# The deployer can create Secrets in the namespace, but can read/patch only
# the one application Secret used by the Mini-Write workloads.
# ============================================================================

KUBECONFIG="$KUBECONFIG" kubectl auth can-i create secrets \
  -n "$K8S_NAMESPACE" >/dev/null \
  || die "Deployer lacks create permission for Secrets in $K8S_NAMESPACE"

KUBECONFIG="$KUBECONFIG" kubectl auth can-i get secret/mini-write-staging-secrets \
  -n "$K8S_NAMESPACE" >/dev/null \
  || die "Deployer lacks get permission for mini-write-staging-secrets"

KUBECONFIG="$KUBECONFIG" kubectl auth can-i patch secret/mini-write-staging-secrets \
  -n "$K8S_NAMESPACE" >/dev/null \
  || die "Deployer lacks patch permission for mini-write-staging-secrets"


# ============================================================================
# Report
# ============================================================================

printf '%s\n' "Secret source identifiers, Kubernetes API connectivity, and namespace-scoped Secret permissions validated."