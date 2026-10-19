#!/usr/bin/env bash
set -euo pipefail

die() { echo "KUBERNETES CONNECTION ERROR: $*" >&2; exit 1; }
ACTION="${1:-}"
: "${AWS_REGION:=us-east-1}"
: "${KUBECONFIG:=/home/janad/.kube/mini-write-deployer/kubeconfig}"
: "${K8S_CONTROL_PLANE_INSTANCE_ID:=i-0552c82b27dd23b29}"
: "${RUNNER_TEMP:=${TMPDIR:-/tmp}}"
: "${GITHUB_RUN_ID:=local}"
: "${GITHUB_JOB:=local}"
PID_FILE="${RUNNER_TEMP}/mini-write-k8s-ssm-${GITHUB_RUN_ID}-${GITHUB_JOB}.pid"
LOG_FILE="${RUNNER_TEMP}/mini-write-k8s-ssm-${GITHUB_RUN_ID}-${GITHUB_JOB}.log"
case "$ACTION" in
  start)
    for c in aws session-manager-plugin kubectl setsid; do command -v "$c" >/dev/null 2>&1 || die "$c is required"; done
    [[ -r "$KUBECONFIG" ]] || die "Deployer kubeconfig is not readable: $KUBECONFIG"
    [[ ! -f "$PID_FILE" ]] || die "Tunnel PID file already exists: $PID_FILE"
    nohup setsid aws ssm start-session --region "$AWS_REGION" --target "$K8S_CONTROL_PLANE_INSTANCE_ID" \
      --document-name AWS-StartPortForwardingSession \
      --parameters "{\"portNumber\":[\"6443\"],\"localPortNumber\":[\"6443\"]}" \
      >"$LOG_FILE" 2>&1 </dev/null &
    pid=$!; printf '%s\n' "$pid" > "$PID_FILE"
    ready=false
    for _ in $(seq 1 30); do
      if ! kill -0 "$pid" 2>/dev/null; then cat "$LOG_FILE" >&2 || true; rm -f "$PID_FILE"; die "SSM tunnel exited"; fi
      if KUBECONFIG="$KUBECONFIG" kubectl --request-timeout=3s get --raw=/readyz >/dev/null 2>&1; then ready=true; break; fi
      sleep 2
    done
    [[ "$ready" == true ]] || { cat "$LOG_FILE" >&2 || true; kill "$pid" 2>/dev/null || true; rm -f "$PID_FILE"; die "Kubernetes API did not become ready through SSM"; }
    identity="$(KUBECONFIG="$KUBECONFIG" kubectl auth whoami -o json | jq -r '.status.userInfo.username')"
    [[ "$identity" == "mini-write-deployer" ]] || die "Unexpected Kubernetes identity: $identity"
    for permission in \
      "get deployments" "create deployments" "patch deployments" "watch deployments" \
      "get services" "create services" "patch services" \
      "get configmaps" "create configmaps" "patch configmaps" \
      "get pods" "list pods" "watch pods" "get replicasets" "list replicasets" "watch replicasets"; do
      verb="${permission%% *}"; resource="${permission#* }"
      KUBECONFIG="$KUBECONFIG" kubectl auth can-i "$verb" "$resource" -n "${K8S_NAMESPACE:-mini-write-staging}" >/dev/null \
        || die "Kubernetes deployer lacks required permission: $permission"
    done
    echo "Kubernetes API is reachable; identity and namespace-scoped deployment permissions verified."
    ;;
  stop)
    if [[ -f "$PID_FILE" ]]; then
      pid="$(cat "$PID_FILE")"
      if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
        for _ in $(seq 1 10); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
        kill -9 -- "-$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
      fi
      rm -f "$PID_FILE"
    fi
    echo "SSM Kubernetes API tunnel stopped."
    ;;
  *) die "Usage: $0 {start|stop}" ;;
esac
