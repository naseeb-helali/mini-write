# Infrastructure Overview

## 1. Purpose

The infrastructure exists to provide the network, compute, identity, storage, database, cache, registry, and operational dependencies required to run Mini-Write and automate its delivery.

## 2. Infrastructure layers

| Layer | Project components | DevOps responsibility |
|---|---|---|
| Network | VPC, subnets, route tables, security groups, ALB | Define reachability and exposure boundaries |
| Compute | VM, ECS, EC2 Kubernetes nodes | Provide execution capacity |
| Container delivery | ECR, Docker images, task definitions, Kubernetes workloads | Deliver immutable application artifacts |
| State services | PostgreSQL/RDS, Redis locally or Valkey in AWS, S3/MinIO | Provide durable application dependencies |
| Identity | IAM roles/policies, GitHub OIDC, runner access | Control automation and workload permissions |
| Configuration/secrets | Ansible variables/Vault, Secrets Manager, Kubernetes Secrets | Deliver configuration without embedding secret values in source |
| Operations | CloudWatch, Prometheus, Loki, Grafana, health endpoints | Observe application and infrastructure behavior |

## 3. Terraform environment structure

The main Terraform work is under `infra/terraform/`:

- `bootstrap/` — state/bootstrap support.
- `environments/staging/` — active Staging environment configuration.
- `environments/production/` — scaffold for a future environment, not a demonstrated deployed Production stack.
- `modules/` — reusable resource definitions such as VPC, security groups, ALB, ECS, ECR, RDS, ElastiCache, S3, IAM, Secrets Manager, CloudWatch, and Kubernetes EC2.

The Staging root composes modules and exposes outputs used by other infrastructure and delivery components.

## 4. Provisioning paths

There are two distinct Ansible projects:

### VM provisioning

`infra/ansible/` configures the VM host and runtime. Roles include base configuration, Docker, deployment runtime, security baseline, and GitHub runner.

### Kubernetes-on-EC2 provisioning

`infra/kubernetes-ec2/ansible/` is a separate provisioning project for Kubernetes node prerequisites, containerd, Kubernetes packages, ECR credential provider, bootstrap, and cluster verification. It is not a refactor or replacement of the legacy VM Ansible project.

This separation is intentional and must remain explicit in operational instructions.

## 5. AWS data plane

The Staging AWS environment defines shared services used by the ECS and Kubernetes-on-EC2 paths, including:

- VPC and security groups.
- ECR repositories.
- RDS PostgreSQL.
- ElastiCache-compatible Valkey.
- S3 object storage.
- Secrets Manager.
- IAM roles and policies.
- CloudWatch resources.

The configured cache engine in the Terraform module is Valkey, while local Compose uses Redis. Documentation should use the accurate name for each runtime context rather than referring to every cache instance generically as Redis.

## 6. Infrastructure automation workflow

The infrastructure workflow separates plan from apply. The closure evidence records that apply was invoked through `workflow_dispatch`, not automatically on `push`, and that a subsequent Terraform plan reported no changes after the tested apply.

This demonstrates controlled infrastructure change execution and state reconciliation for the tested Staging scope. It does not establish a formal human approval gate for every apply or validate an independent Production environment.

## 7. Operational boundaries

Infrastructure configuration is not equivalent to infrastructure verification. A Terraform resource declaration demonstrates intended state; an apply log demonstrates an execution; a post-apply plan demonstrates reconciliation at that time. Application readiness requires additional checks at the workload layer.

Likewise, a security group rule or IAM policy file establishes configuration intent but not a complete security audit.

## 8. Source map

- `infra/terraform/bootstrap/`
- `infra/terraform/environments/staging/`
- `infra/terraform/environments/production/`
- `infra/terraform/modules/`
- `infra/ansible/`
- `infra/kubernetes-ec2/ansible/`
- `infra/kubernetes-ec2/kubernetes/`
- `infra/kubernetes-ec2/manifests/`
- `.github/workflows/infrastructure.yml`

## 9. Related documents

See [Terraform & Provisioning](terraform-and-provisioning.md), [AWS Infrastructure](aws-infrastructure.md), and [Deployment Architecture](../01-architecture/deployment-architecture.md).

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
