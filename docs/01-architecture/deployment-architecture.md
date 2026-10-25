# Deployment Architecture

## 1. Purpose

Mini-Write has three deployment paths. The deployment architecture explains what changes between platforms, which dependencies are shared, and where automation and verification differ.

## 2. Platform overview

```text
                           GitHub Repository
                                  |
                     CI: test / scan / build images
                                  |
                         Immutable image artifacts
                                  |
               +------------------+------------------+
               |                  |                  |
               v                  v                  v
           VM / Compose        AWS ECS          Kubernetes on EC2
           Ansible             Terraform         Terraform + Ansible
           VM adapter          ECS adapter       kubeadm + manifests
```

### VM / Compose

A Linux host is prepared through `infra/ansible`. Docker Compose runs the application and supporting services according to the VM deployment templates. Nginx provides the HTTP gateway. Deployment and rollback are handled by the VM adapter and shared deployment scripts.

### AWS ECS

Terraform provisions the AWS resources, including ECS-related infrastructure and supporting managed services. The deployment adapter updates ECS task/service state using the immutable image references supplied by the release artifact. The load balancer exposes the application entry point.

### Kubernetes on EC2

This is a self-managed Kubernetes cluster running on EC2, not Amazon EKS. Terraform defines EC2/network resources; a separate Ansible project prepares nodes and cluster prerequisites; kubeadm bootstraps the control plane; Calico provides cluster networking; Kubernetes manifests define API and Worker workloads. A dedicated GitHub Actions workflow deploys through a private API connection using SSM port forwarding.

## 3. Shared and platform-specific components

| Concern | VM | ECS | Kubernetes on EC2 |
|---|---|---|---|
| Compute | Linux VM | ECS tasks/services | EC2 nodes + Kubernetes Pods |
| Provisioning | Ansible | Terraform | Terraform + dedicated Ansible |
| Workload definition | Compose templates | ECS task definitions | Kubernetes Deployments/Services |
| Deployment adapter | `ci/deployment/adapters/vm/` | `ci/deployment/adapters/aws-ecs/` | `ci/kubernetes/` |
| External entry | Nginx on VM | AWS load balancer | ALB target configuration exists; workload integration has a known gap |
| Health verification | VM adapter/runtime checks | ECS health/deployment checks | Pod readiness probes and Ready state |
| Rollback | Previous VM deployment state | Previous ECS task/image state | Previous successful Production-stage evidence/digests |

AWS ECS and Kubernetes-on-EC2 use shared AWS infrastructure definitions for services such as VPC networking, RDS, Valkey, S3, ECR, and Secrets Manager, as configured in the Staging Terraform environment. This means the two compute platforms are not necessarily isolated data environments. If both are active, they may interact with the same data services and queue.

The VM deployment has a distinct runtime configuration and should not be assumed to share AWS managed data services.

## 4. CI/CD separation

The repository contains:

- `.github/workflows/ci.yml` — validation and image build.
- `.github/workflows/cd.yml` — existing VM/ECS deployment path.
- `.github/workflows/infrastructure.yml` — Terraform infrastructure workflow.
- `.github/workflows/kubernetes-cd.yml` — Kubernetes-on-EC2 delivery path.

Kubernetes deployment helpers are isolated under `ci/kubernetes/`. The existing VM/ECS deployment helpers remain under `ci/deployment/`. Shared promotion functionality exists under `ci/promotion/`.

The workflows use different concurrency groups. The Kubernetes CD README warns that the older workflow should be disabled before enabling Kubernetes CD because the two workflows do not share one global deployment lock. This is a practical coordination constraint when multiple deployment paths target shared infrastructure or workloads.

## 5. Kubernetes Staging and Production-stage model

The Kubernetes workflow's Staging and Production stages target the same cluster and namespace:

- Cluster: `mini-write-staging-k8s`
- Namespace: `mini-write-staging`

The Production stage promotes the exact digests already verified in Staging and verifies them on the same runtime. Rollback restores previously verified Production-stage digests in that same namespace. Consequently, the workflow demonstrates release promotion and recovery controls, but not an independent Production environment. A rollback also moves the shared Staging workloads back to the prior digest.

## 6. Shared runner/control plane

The project uses a self-hosted GitHub Actions runner installed through the VM Ansible role. It is a delivery control-plane dependency: workflows execute on the runner, which has access to Docker and deployment tooling. Kubernetes deployment additionally depends on AWS credentials, SSM Session Manager Plugin, and a local deployer kubeconfig on the runner.

This architecture is useful for a hands-on project but creates a central operational dependency. Runner availability, credential access, and workflow trust boundaries affect delivery.

## 7. Topology limitations that affect claims

- Kubernetes is a single-control-plane design in the reviewed configuration; it is not a highly available control plane.
- Kubernetes workload Services are ClusterIP. The ALB target group references NodePort 30080, but a corresponding NodePort/Gateway/Ingress path was not identified in the reviewed workload manifests.
- Kubernetes-specific centralized observability deployment is not established by the repository.
- The Production Terraform directory is a scaffold, not a separate deployed Production environment.
- VM runtime evidence is not retained in the reviewed evidence tree.
- ECS historical evidence exists, but the current archived ECS verify script has a syntax defect.

## 8. Source map

- `.github/workflows/`
- `infra/terraform/environments/staging/`
- `infra/terraform/modules/`
- `infra/ansible/`
- `infra/kubernetes-ec2/`
- `ci/deployment/`
- `ci/kubernetes/`
- `ci/promotion/`
- `evidence/deployment-recovery/`
- `evidence/kubernetes-ec2 evidence/`

## 9. Design intent

The three deployment paths provide practical exposure to different operating models: host-centric deployment, managed container orchestration, and self-managed Kubernetes. The objective is to demonstrate that the engineer can reason about the consequences of each model, not to claim that all three have equivalent production readiness.

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
