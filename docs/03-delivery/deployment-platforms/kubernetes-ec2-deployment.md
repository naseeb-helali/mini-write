# Kubernetes on AWS EC2 Deployment

## 1. Deployment model

Mini-Write's Kubernetes deployment target is a self-managed Kubernetes cluster installed on AWS EC2 instances. It is **not Amazon EKS**. Terraform provisions the EC2/network foundation; a dedicated Ansible project prepares the nodes; kubeadm bootstraps the cluster; Calico provides pod networking; Kubernetes manifests deploy the API and Worker.

The deployment system is intentionally isolated from the legacy VM Ansible project and VM/ECS helper structure.

## 2. Infrastructure topology

The reviewed target consists of:

- One control-plane EC2 instance.
- Two worker EC2 instances.
- Private node networking.
- Containerd runtime.
- Kubernetes packages in the 1.35 series; kubeadm configuration records v1.35.9 expectations.
- Calico networking (VXLAN configuration).
- ECR credential provider for node image pulls.
- SSM access/port forwarding for private control-plane API access from the runner.

This is a practical single-control-plane cluster. It should not be described as control-plane HA.

## 3. Provisioning separation

The relevant paths are:

- Terraform: `infra/terraform/modules/kubernetes-ec2/` and Staging environment Kubernetes resource files.
- Ansible: `infra/kubernetes-ec2/ansible/`.
- kubeadm and CNI configuration: `infra/kubernetes-ec2/kubernetes/`.
- Workload manifests: `infra/kubernetes-ec2/manifests/workloads/staging/`.

The separate Ansible path is a hard project boundary. Do not move Kubernetes configuration into `infra/ansible` or change the VM Ansible configuration as part of Kubernetes documentation or maintenance.

## 4. Workload configuration

The Staging manifests define:

- Namespace `mini-write-staging`.
- API ConfigMap and Deployment.
- API Service.
- Worker Deployment.
- Worker Service.
- Kustomize configuration and validation helper.

The API Service maps its Service port to the API container port. The API Deployment uses a `Recreate` strategy with one replica in the reviewed manifest, which means downtime can occur during replacement. The Worker uses `RollingUpdate` with `maxSurge: 1`, allowing temporary overlap between old and new Worker Pods. Queue behavior and idempotency therefore matter during rollout.

Both workloads define readiness probes using `/health/ready`. Kubernetes kubelet probe results are consumed by deployment verification.

## 5. CI/CD workflow

The dedicated workflow is `.github/workflows/kubernetes-cd.yml`. Kubernetes-specific scripts are under `ci/kubernetes/`:

- `connection/` — SSM tunnel and deployer identity/permission checks.
- `deployment/` — target, AWS identity, artifact validation, apply, rollout, readiness, and evidence recording.
- `promotion/` — Staging evidence validation.
- `rollback/` — prior release resolution, validation, and restore.
- `secrets/` — Secrets Manager synchronization and validation.

The workflow validates the expected AWS account/role, cluster, namespace, control-plane instance, ECR repositories, kubeconfig endpoint, and rendered workload namespace. The kubeconfig remains on the self-hosted runner and is not printed or uploaded as an artifact.

## 6. Registry authentication

The cluster is configured for ECR. The GitHub runner does not perform Docker login for node pulls; the EC2 nodes use the ECR credential provider. The workflow validates the ECR registry model and repository identity.

The credential-provider binary is supplied from an external path during provisioning and is not included in the repository archive. The provisioning process must obtain the expected binary and validate its pinned checksum.

## 7. Deployment verification

The workflow verifies more than the desired Deployment template:

1. The expected Deployment generation and replica counts are observed.
2. The current ReplicaSet is associated with the intended Deployment.
3. Pods belonging to that ReplicaSet are inspected.
4. Running container `imageID` digests are compared with the CI artifact digests.
5. API and Worker readiness probe configuration is checked.
6. Pod Ready and application container Ready states are checked.

The readiness mechanism is the kubelet's HTTP readiness probe and resulting Pod Ready condition. It is not a direct HTTP request from the GitHub runner to the private ClusterIP Service.

## 8. Promotion and environment model

The workflow uses one shared concurrency group because Staging and Production stages mutate the same API and Worker Deployments in the same namespace.

Both stages target:

- Cluster: `mini-write-staging-k8s`.
- Namespace: `mini-write-staging`.

Production promotion reapplies the exact digests verified in Staging. Production rollback restores the previous successfully verified Production-stage digests. This provides release-control and rollback practice, but it is not a separate Production environment. A Production rollback also changes the shared Staging workload to the restored digest.

The first Production-stage release has no automatic previous-release rollback target. If there is no prior successful Production verification artifact, rollback resolution fails closed and operator recovery is required.

## 9. Secrets

The workflow retrieves required values from AWS Secrets Manager and synchronizes Kubernetes Secrets. The script uses restrictive temporary-file permissions and masks secret values. However, environment variables already loaded into running containers do not change merely because the Kubernetes Secret object is updated. A rotation procedure must include a Pod restart/rollout or another explicit refresh mechanism.

## 10. Known integration and reproducibility constraints

- Terraform does not pin the private IPs that some kubeadm/inventory/verification configuration expects. Instance replacement may require coordinated configuration updates.
- The ALB target group references NodePort 30080, but the reviewed workload Services are ClusterIP and no corresponding NodePort/Gateway/Ingress service was identified. Do not claim that the external ALB-to-workload path is complete.
- The repository does not contain a complete deployer RBAC bootstrap definition; the workflow depends on a pre-existing deployer kubeconfig/identity on the runner.
- Kubernetes secret updates do not automatically refresh existing process environment variables.
- The cluster does not have a Kubernetes-specific Prometheus/Loki/Grafana deployment represented in the reviewed repository.
- The cluster has one control plane and should not be described as highly available.
- `cluster-bootstrap.yml` handles a worker join token; the reviewed task does not set `no_log: true`, so token output exposure should be addressed before treating the bootstrap path as secret-safe.
- Kubernetes package installation uses a 1.35 wildcard while preflight expects v1.35.9; the pinning contract should be made consistent.

These are implementation constraints relevant to accurate documentation, not a requirement to expand the project into enterprise-grade Kubernetes operations.

## 11. Retained evidence

The archive contains:

- Staging promotion eligibility evidence.
- Production-stage verification evidence.
- Rollback verification evidence.

Recorded timings:

| Scenario | Duration |
|---|---:|
| Staging deployment | 16 seconds |
| Production-stage verification | 15 seconds |
| Rollback | 48 seconds |

The evidence records the same Staging cluster and namespace for both Staging and Production-stage operations. Durations describe those recorded workflow runs, not guaranteed future deployment times.

## 12. Source map

- `.github/workflows/kubernetes-cd.yml`
- `infra/terraform/environments/staging/kubernetes-*.tf`
- `infra/terraform/modules/kubernetes-ec2/`
- `infra/kubernetes-ec2/ansible/`
- `infra/kubernetes-ec2/kubernetes/`
- `infra/kubernetes-ec2/manifests/workloads/staging/`
- `infra/kubernetes-ec2/CD-README.md`
- `ci/kubernetes/`
- `ci/promotion/promote.sh`
- `evidence/kubernetes-ec2 evidence/`

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../../06-engineering-evidence/validation-and-limitations.md) where applicable.
