#!/usr/bin/env bash
set -euo pipefail

echo "== OS =="
. /etc/os-release
printf '%s %s\n' "$NAME" "$VERSION"

echo "== Runtime =="
containerd --version
systemctl is-active containerd
systemctl is-enabled containerd
grep -n 'SystemdCgroup' /etc/containerd/config.toml

echo "== Kubernetes binaries =="
kubeadm version -o short
kubelet --version
kubectl version --client

echo "== Swap =="
if [[ -n "$(swapon --show --noheadings)" ]]; then
  echo "ERROR: swap is still active"
  exit 1
fi
echo "No active swap"

echo "== Kernel modules =="
lsmod | grep -E '^(overlay|br_netfilter)\b'

echo "== Sysctls =="
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
