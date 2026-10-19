# Mini-Write — Stage 2: Kubernetes EC2 Ansible Bootstrap

This package bootstraps the three existing private Ubuntu EC2 nodes created in
Stage 1. It is intentionally isolated from `infra/ansible/`.

## Scope

- Connect to EC2 nodes through AWS Systems Manager Session Manager (no SSH).
- Apply a common Ubuntu 24.04 baseline.
- Disable swap and configure Kubernetes kernel modules/sysctl.
- Install and configure `containerd` with the systemd cgroup driver.
- Install pinned Kubernetes `kubelet`, `kubeadm`, and `kubectl` packages from
  the Kubernetes community package repository.
- Enable kubelet without initializing or joining a cluster.

**This stage does not run `kubeadm init` or `kubeadm join`, install a CNI,
deploy workloads, configure ingress, or change AWS infrastructure.**

## Target inventory (from the supplied Terraform outputs)

| Host | Instance ID | Private IP |
|---|---|---|
| control_plane | `i-0552c82b27dd23b29` | `10.20.10.206` |
| worker_01 | `i-0512aeb1a30a22c4b` | `10.20.10.230` |
| worker_02 | `i-0ab5809e0a72e9cef` | `10.20.11.245` |

Region: `us-east-1`

SSM transfer bucket: `mini-write-staging-k8s-ansible-496494570164-us-east-1`

Bootstrap role ARN supplied from Terraform:
`arn:aws:iam::496494570164:role/mini-write-staging-k8s-bootstrap`

The inventory is populated with the actual IDs and addresses supplied by the
operator. It does not discover or create EC2 instances.

## Controller prerequisites

Run Ansible from a Linux controller with network access to AWS APIs:

- Python 3.10+
- Ansible Core 2.16+ (2.17 recommended)
- AWS CLI v2
- `boto3`, `botocore`, `requests`
- The `amazon.aws` and `ansible.posix` collections

Install the Python dependencies in an isolated virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install "ansible-core>=2.16,<2.19" boto3 botocore requests
ansible-galaxy collection install -r requirements.yml
```

The active AWS CLI credential chain must authorize the SSM operations and the
S3 transfer bucket operations required by `amazon.aws.aws_ssm`. The Terraform
output is the bootstrap role ARN, but the package does not assume that the
current local identity is allowed to assume it. Verify the caller and role
trust before attempting role assumption:

```bash
aws sts get-caller-identity
```

If your approved access path permits assuming the bootstrap role, use your
organization's approved role-assumption mechanism and then verify the resulting
identity. Do not edit the role trust policy or broaden IAM permissions merely
to make Ansible connect.

Required controller-side access includes, at minimum:
- SSM: describe managed instances and start/terminate sessions.
- S3: read/write/delete the SSM connection plugin's temporary objects in the
  specified transfer bucket.
- Any KMS permissions required by the bucket's actual encryption configuration.

The EC2 instance role must allow SSM Agent connectivity and the managed-node
permissions already provisioned in Stage 1. All three nodes were reported
`Online` in SSM in the operator's validation output.

## Configure and validate

From this directory:

```bash
cp group_vars/all.yml.example group_vars/all.yml
```

The example already contains the values from the supplied Terraform outputs.
Review it, then validate the controller identity and the inventory:

```bash
aws sts get-caller-identity
ansible-inventory -i inventory/hosts.yml --graph
ansible all -i inventory/hosts.yml -m ansible.builtin.ping
```

The SSM connection plugin does not use SSH. Do not add private keys or open
TCP/22.

Run a read-only preflight first:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/preflight.yml
```

Then execute the bootstrap:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml
```

The play targets all three nodes. If desired, limit a first run to one node:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --limit control_plane
```

## Version policy

The Kubernetes minor version is pinned through `kubernetes_minor_version`
(current package default: `v1.35`). The package installs the latest available
patch release within that minor line and applies an APT hold after installation.
Do not change the minor version independently on only one node. Before running,
confirm that the selected minor line is supported and compatible with the
planned CNI and any later add-ons. A cluster must use compatible kubeadm,
kubelet, and kubectl versions; kubelet must not be newer than kubeadm.

The container runtime package is Ubuntu's `containerd` package, not Docker
Engine. Its generated default configuration is adjusted to use
`SystemdCgroup = true`.

## Stage 2 completion criteria

On each node, verify:

```bash
containerd --version
sudo systemctl is-active containerd
sudo systemctl is-enabled containerd
kubeadm version -o short
kubelet --version
kubectl version --client
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.ipv4.ip_forward
grep -n 'SystemdCgroup' /etc/containerd/config.toml
```

Expected:
- `containerd` is active and enabled.
- Kubernetes tools report the selected minor line.
- `swapon --show` returns no active swap.
- `overlay` and `br_netfilter` are loaded.
- `net.bridge.bridge-nf-call-iptables = 1`.
- `net.ipv4.ip_forward = 1`.
- `SystemdCgroup = true`.

`kubelet` being enabled but not yet healthy/running as a functional cluster
service is expected before `kubeadm init` or `kubeadm join`.

## Explicit integration item before cluster creation

Stage 1 documentation states that the EC2 node role has ECR pull permissions
and that Stage 2 must configure kubelet's ECR credential-provider integration.
That integration is **not silently approximated** in this package: the exact
credential-provider binary source, release version, checksum, and kubelet
configuration need to be pinned and validated against the selected Kubernetes
minor version before we declare private ECR image pulls ready. This is a
required integration gate before deploying Mini-Write images in a later stage.
Do not treat node-role ECR permissions alone as proof that kubelet can pull
private ECR images.

## Safety

- No SSH keys, SSH connections, or TCP/22 changes.
- No `kubeadm init`, `kubeadm join`, reset, or CNI deployment.
- No edits to the existing `infra/ansible/` tree.
- No changes to Terraform, ECS, RDS, Redis, or application code.
- The playbooks do not perform a distribution upgrade or reboot nodes.
