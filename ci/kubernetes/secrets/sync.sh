#!/usr/bin/env bash
set -euo pipefail

# Fetch the three existing Secrets Manager JSON values and synchronize them
# into the single Kubernetes Secret consumed by API and Worker.
# Secret values are never passed as command-line arguments or printed.

die() { echo "KUBERNETES SECRET SYNC ERROR: $*" >&2; exit 1; }

: "${AWS_REGION:?AWS_REGION is required}"
: "${K8S_NAMESPACE:?K8S_NAMESPACE is required}"
: "${KUBECONFIG:?KUBECONFIG is required}"
: "${K8S_DATABASE_SECRET_ARN:?K8S_DATABASE_SECRET_ARN is required}"
: "${K8S_REDIS_SECRET_ARN:?K8S_REDIS_SECRET_ARN is required}"
: "${K8S_JWT_SECRET_ARN:?K8S_JWT_SECRET_ARN is required}"

for cmd in aws kubectl jq; do
  command -v "$cmd" >/dev/null 2>&1 || die "Required command is missing: $cmd"
done

umask 077
tmp_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
mkdir -p "$tmp_root"
tmp_dir="$(mktemp -d "$tmp_root/mini-write-k8s-secrets.XXXXXX")"
chmod 700 "$tmp_dir"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT INT TERM

database_file="$tmp_dir/database.json"
redis_file="$tmp_dir/redis.json"
jwt_file="$tmp_dir/jwt.json"
secret_file="$tmp_dir/kubernetes-secret.json"

# AWS CLI writes SecretString directly to mode-600 temporary files. Do not
# enable shell tracing around this script and do not emit the file contents.
aws secretsmanager get-secret-value \
  --region "$AWS_REGION" \
  --secret-id "$K8S_DATABASE_SECRET_ARN" \
  --query SecretString --output text --no-cli-pager > "$database_file"
aws secretsmanager get-secret-value \
  --region "$AWS_REGION" \
  --secret-id "$K8S_REDIS_SECRET_ARN" \
  --query SecretString --output text --no-cli-pager > "$redis_file"
aws secretsmanager get-secret-value \
  --region "$AWS_REGION" \
  --secret-id "$K8S_JWT_SECRET_ARN" \
  --query SecretString --output text --no-cli-pager > "$jwt_file"
chmod 600 "$database_file" "$redis_file" "$jwt_file"

# Validate exact JSON keys agreed for the existing Secrets Manager records.
jq -e 'type == "object" and (.password | type == "string" and length > 0)' "$database_file" >/dev/null \
  || die "Database SecretString must contain a non-empty string key named password"
jq -e 'type == "object" and (.password | type == "string" and length > 0)' "$redis_file" >/dev/null \
  || die "Redis SecretString must contain a non-empty string key named password"
jq -e 'type == "object" and (.jwt_secret | type == "string" and length > 0)' "$jwt_file" >/dev/null \
  || die "JWT SecretString must contain a non-empty string key named jwt_secret"

# Mask values in subsequent GitHub Actions log output. Reject line breaks so
# secret values cannot inject additional workflow-command lines.
mask_value() {
  local value="$1"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || die "Secret values must not contain line breaks"
  printf '::add-mask::%s\n' "$value"
}
mask_value "$(jq -er '.password' "$database_file")"
mask_value "$(jq -er '.password' "$redis_file")"
mask_value "$(jq -er '.jwt_secret' "$jwt_file")"

# Build a Secret manifest using slurpfile inputs. Values are base64-encoded
# into a private temporary file; they never appear in argv or console output.
jq -n \
  --arg namespace "$K8S_NAMESPACE" \
  --slurpfile database "$database_file" \
  --slurpfile redis "$redis_file" \
  --slurpfile jwt "$jwt_file" \
  '{apiVersion:"v1",kind:"Secret",
    metadata:{name:"mini-write-staging-secrets",namespace:$namespace,
      labels:{"app.kubernetes.io/part-of":"mini-write",
              "app.kubernetes.io/managed-by":"mini-write-kubernetes-cd"}},
    type:"Opaque",
    data:{POSTGRES_PASSWORD:($database[0].password|@base64),
          REDIS_PASSWORD:($redis[0].password|@base64),
          JWT_SECRET:($jwt[0].jwt_secret|@base64)}}' > "$secret_file"
chmod 600 "$secret_file"

secret_resource='secret/mini-write-staging-secrets'
if KUBECONFIG="$KUBECONFIG" kubectl get "$secret_resource" -n "$K8S_NAMESPACE" -o name >/dev/null 2>&1; then
  # Use a merge patch rather than client-side apply: kubectl apply would add
  # a last-applied annotation containing another copy of the secret data.
  KUBECONFIG="$KUBECONFIG" kubectl patch "$secret_resource" \
    --type=merge --patch-file "$secret_file" -n "$K8S_NAMESPACE" >/dev/null
  operation=updated
else
  KUBECONFIG="$KUBECONFIG" kubectl create -f "$secret_file" -n "$K8S_NAMESPACE" >/dev/null
  operation=created
fi

# Verify object metadata and required data keys without printing Secret data.
KUBECONFIG="$KUBECONFIG" kubectl get "$secret_resource" -n "$K8S_NAMESPACE" -o json \
  | jq -e --arg namespace "$K8S_NAMESPACE" '
      .type == "Opaque" and
      .metadata.name == "mini-write-staging-secrets" and
      .metadata.namespace == $namespace and
      (.data | has("POSTGRES_PASSWORD") and has("REDIS_PASSWORD") and has("JWT_SECRET"))
    ' >/dev/null

printf 'Kubernetes Secret mini-write-staging-secrets successfully %s in namespace %s.\n' "$operation" "$K8S_NAMESPACE"
