# Mini-Write

### DevOps Engineering Portfolio Project

Mini-Write is a hands-on DevOps engineering project built around a distributed image-processing application. It uses a realistic application workload to demonstrate how infrastructure is provisioned, software is validated and packaged, releases are deployed, and runtime behavior is observed and recovered across different deployment environments.

**The application is the workload. The engineering focus of this repository is the delivery and operation of that workload.**

> **Engineering scope:** Demonstrate practical DevOps Engineering competency through implemented automation, operational workflows, verification, and retained evidence — without claiming enterprise-scale maturity or capabilities that have not been established.

---

## Project at a Glance

| Area | Implementation |
|---|---|
| Application workload | Node.js API and asynchronous image-processing Worker |
| Gateway | Nginx |
| Application state | PostgreSQL |
| Queue and cache | Redis / Valkey, with BullMQ |
| Object storage | MinIO for the VM/local path; Amazon S3 for AWS paths where configured |
| Containers | Docker |
| Infrastructure as Code | Terraform |
| Host configuration | Ansible |
| CI/CD | GitHub Actions |
| AWS | VPC, networking, EC2, ECS, ECR, RDS, ElastiCache/Valkey, S3, IAM, and related services |
| Orchestration | Docker Compose, Amazon ECS, and self-managed Kubernetes on AWS EC2 |
| Kubernetes networking | Calico |
| Observability | Prometheus, Grafana, Loki, Promtail, Alertmanager, and exporters where configured |
| Security practices | IAM and OIDC integration, secrets handling, network controls, dependency and container-image scanning |

The implementation and evidence are not uniform across all deployment targets. The documentation identifies the scope and verification status of each capability.

## Architecture Overview

The application follows an asynchronous processing model:

```text
                         Client
                           |
                           v
                     Nginx Gateway
                           |
                           v
                    Node.js API
                     /    |     \
                    /     |      \
                   v      v       v
             PostgreSQL  Redis   Object Storage
                           |
                        BullMQ
                           |
                           v
                    Image Worker
                           |
                           v
                  Processed Objects
```

- **API:** Handles incoming application requests, authentication-related operations, upload coordination, and application state interactions.
- **Queue:** Decouples request handling from background processing.
- **Worker:** Consumes asynchronous jobs and performs image processing.
- **PostgreSQL:** Persists application state.
- **Redis / Valkey:** Provides queue infrastructure.
- **Object storage:** Stores uploaded and processed objects.
- **Nginx:** Acts as the HTTP gateway in the Compose-based deployment path.

The same workload is delivered through multiple infrastructure and runtime models. Their topology and dependencies are described in the deployment documentation.

## Deployment Environments

Mini-Write contains three distinct deployment paths:

| Deployment path | Runtime model | Provisioning and delivery |
|---|---|---|
| VM | Linux VM with Docker Compose and Nginx | Ansible host configuration and VM deployment adapter |
| AWS ECS | ECS services and task definitions using AWS infrastructure | Terraform and ECS deployment adapter |
| Kubernetes on AWS EC2 | Self-managed Kubernetes cluster using kubeadm, containerd, and Calico; **not Amazon EKS** | Dedicated Terraform configuration, a separate Kubernetes Ansible project, Kubernetes manifests, and a dedicated GitHub Actions workflow |

### Kubernetes isolation

The Kubernetes-on-EC2 provisioning and configuration path is maintained separately under `infra/kubernetes-ec2/`. It does not replace or modify the existing VM Ansible project under `infra/ansible/`.

The documented Kubernetes topology targets one control-plane node and two worker nodes. It is a self-managed cluster exercise, not an EKS deployment or a highly available Kubernetes control plane.

### AWS environment boundary

The ECS and Kubernetes-on-EC2 paths use AWS infrastructure and shared Staging data services where configured. The Kubernetes workflow's Staging and Production stages currently target the same Staging cluster and namespace. They represent workflow stages, not two independently provisioned environments.

---

## DevOps Engineering Work

### 1. Continuous Integration

The CI workflow automates the repository's validation and container delivery stages, including:

- API and Worker test execution.
- Coverage measurement and a configured line-coverage threshold.
- Docker image builds using Buildx.
- Container image publication and release identity.
- Dependency and image security scanning configuration.
- Workflow execution optimization with retained timing evidence.

**Measured CI optimization**

The following figures are based on retained project measurements, not a general performance guarantee:

| Measurement | Baseline | Optimized median | Reduction |
|---|---:|---:|---:|
| End-to-end CI execution | 1,866 s | 893 s | ~52.1% |
| Container build execution | 954 s | 412 s | ~56.8% |

The measurements and their methodology are documented in [Competency Evidence](docs/06-engineering-evidence/competency-evidence.md). Security scanning is configured as non-blocking in the reviewed workflow; it should therefore be interpreted as an informational check, not a release-blocking security gate.

### 2. Infrastructure as Code

Terraform is used to define AWS infrastructure and environment resources. The repository includes reusable infrastructure modules and environment-specific configuration.

The Staging infrastructure workflow supports controlled Terraform execution. Retained evidence includes an apply followed by a reconciliation plan reporting no changes.

### 3. Configuration and Provisioning

Ansible is used for Linux host preparation and configuration in the VM deployment path. Kubernetes-on-EC2 has its own Ansible project and provisioning workflow, kept independent from the VM Ansible tree.

### 4. Deployment and Release Management

The repository maintains deployment automation for:

- VM/Compose deployment and recovery.
- AWS ECS release deployment and rollback.
- Kubernetes workload deployment, verification, and rollback on EC2-hosted Kubernetes.

Container image tags and digests are used as release identity inputs in the delivery process. Deployment workflows include readiness or verification steps appropriate to their implementation.

### 5. Observability and Operations

The project includes application health endpoints, Prometheus metrics, dashboards, log collection configuration, alert rules, and infrastructure exporters in the paths where configured.

Observability coverage differs by platform. The presence of configuration files does not by itself prove that every integration is deployed, receiving data, or delivering notifications in a live environment.

### 6. Reliability and Recovery

Reliability-related implementation includes queue-based asynchronous processing, retry and idempotency mechanisms, health/readiness checks, deployment state handling, rollback automation, and operational validation.

These controls have different levels of implementation and verification. Known limitations are documented rather than presented as solved capabilities.

---

## Repository Structure

```text
.
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── cd.yml
│       ├── infrastructure.yml
│       └── kubernetes-cd.yml
├── api/                         # Node.js API service
├── worker/                      # Background image-processing worker
├── proxy/                       # Nginx gateway configuration
├── ci/                          # CI/CD scripts, adapters, promotion and rollback
├── infra/
│   ├── terraform/                # AWS infrastructure as code
│   ├── ansible/                  # VM host provisioning and configuration
│   └── kubernetes-ec2/           # Independent Kubernetes-on-EC2 provisioning path
├── observability/                # Prometheus, Grafana, Loki and related configuration
├── evidence/                     # Retained engineering and execution evidence
├── scripts/                      # Supporting project scripts
├── docker-compose.yml            # Compose-based application stack
├── .env.example                  # Environment-variable template
└── docs/                         # Engineering documentation
```

The tree above is a high-level guide; individual directories contain additional implementation details.

## Getting Started

### Prerequisites

The exact prerequisites depend on which part of the project you intend to run or inspect.

| Activity | Required tooling |
|---|---|
| Inspect or run the application locally | Git, Docker Engine, Docker Compose |
| Run API or Worker tests directly | Node.js and npm |
| Validate AWS infrastructure | Terraform and AWS credentials with the required permissions |
| Provision/configure Linux hosts | Ansible and SSH access |
| Execute deployment workflows | GitHub Actions configuration, appropriate repository secrets/variables, and target-environment access |
| Operate the Kubernetes path | AWS access, EC2 instances, kubeadm-based cluster prerequisites, and the dedicated Kubernetes configuration |

### Configuration

1. Clone the repository.
2. Review `.env.example` and the Compose configuration before starting the local stack.
3. Create a local `.env` file and replace all placeholder credentials and secrets with unique values.
4. Confirm that the configured ports, service endpoints, storage provider, and credentials are consistent with the deployment path you intend to use.
5. Do not commit `.env`, real credentials, private keys, kubeconfig files, or unencrypted secret material.

The repository contains multiple deployment paths with different configuration requirements. Do not assume that the root Compose environment file is suitable for AWS ECS or Kubernetes without reviewing the corresponding deployment documentation.

> **Important:** This README intentionally does not present a one-command production deployment. Infrastructure creation and deployment require environment-specific configuration, credentials, and review. Follow the relevant platform document and runbook before executing changes.

## Documentation

The `docs/` directory is the authoritative project documentation set.

| Documentation area | What it covers |
|---|---|
| [Project Overview](docs/00-project/project-overview.md) | Project purpose, workload, deployment models, and claim boundaries |
| [Engineering Scope](docs/00-project/engineering-scope.md) | Target DevOps competency scope and explicit exclusions |
| [System Architecture](docs/01-architecture/system-architecture.md) | Application components and service interactions |
| [Deployment Architecture](docs/01-architecture/deployment-architecture.md) | Deployment topologies and platform boundaries |
| [Infrastructure](docs/02-infrastructure/infrastructure-overview.md) | Infrastructure structure and relationships |
| [Terraform & Provisioning](docs/02-infrastructure/terraform-and-provisioning.md) | Infrastructure automation and host configuration |
| [AWS Infrastructure](docs/02-infrastructure/aws-infrastructure.md) | AWS resources and environment design |
| [CI Pipeline](docs/03-delivery/ci-pipeline.md) | Validation, build, scanning, and CI optimization |
| [Artifact Management](docs/03-delivery/artifact-management.md) | Image identity, artifacts, and release handling |
| [VM Deployment](docs/03-delivery/deployment-platforms/vm-deployment.md) | VM/Compose deployment path |
| [AWS ECS Deployment](docs/03-delivery/deployment-platforms/aws-ecs-deployment.md) | ECS delivery and recovery path |
| [Kubernetes on EC2](docs/03-delivery/deployment-platforms/kubernetes-ec2-deployment.md) | Self-managed Kubernetes provisioning and delivery |
| [Observability](docs/04-operations/observability.md) | Metrics, logs, dashboards, and alert configuration |
| [Reliability & Recovery](docs/04-operations/reliability-and-recovery.md) | Reliability mechanisms and recovery behavior |
| [Operational Runbooks](docs/04-operations/operational-runbooks.md) | Operational procedures and response guidance |
| [DevOps Security Practices](docs/05-security/devops-security-practices.md) | Security controls across infrastructure and delivery |
| [Competency Evidence](docs/06-engineering-evidence/competency-evidence.md) | Measured results and evidence of engineering work |
| [Validation & Limitations](docs/06-engineering-evidence/validation-and-limitations.md) | What was checked, known gaps, and verification boundaries |

For the full documentation map and governance model, see [Documentation Index](docs/README.md), [Documentation Architecture & Scope](docs/00-project/documentation-architecture-and-scope.md), and [Documentation Traceability Matrix](docs/00-project/documentation-traceability-matrix.md).

---

## Evidence and Engineering Claims

This repository is intended to be reviewed through an evidence chain:

**DevOps responsibility → implementation → verification method → retained evidence → measured or observed result.**

The `evidence/` directory contains retained project artifacts for selected CI/CD, deployment recovery, infrastructure automation, and release-management activities. The documentation links implementation areas to the available evidence.

Status terms are used deliberately:

- **Implemented:** relevant code or automation exists in the reviewed repository.
- **Configured:** declarative configuration exists; runtime success is not implied.
- **Verified:** a specific test, command, workflow run, or retained artifact supports the stated result.
- **Partial:** only part of the capability or its verification is established.
- **Not established:** the reviewed source and evidence do not support the claim.

A historical successful run is evidence of that recorded execution; it does not automatically prove that a later source revision is correct.

## Known Boundaries

Mini-Write is a portfolio engineering project, not a claim of enterprise production ownership. The following boundaries are important when interpreting the implementation:

- The Kubernetes cluster uses a single control-plane node and is not an HA control plane.
- Kubernetes workflow stages labelled Staging and Production currently use the same Staging cluster and namespace.
- Centralized Kubernetes-specific observability is not established in the reviewed repository snapshot.
- Observability and alert delivery capabilities vary by deployment platform.
- The reviewed Trivy scan configuration is non-blocking.
- Some runtime reliability and deployment integration gaps remain documented in the validation record.
- The reviewed ECS verification script has a shell syntax issue; historical ECS execution evidence is kept distinct from current-source validation.
- The repository snapshot used to prepare the documentation did not include Git metadata, so complete commit history and tracked-file status were not assessed.

These boundaries do not negate the engineering work that is implemented and evidenced. They define precisely what the project does and does not claim.

## Project Status and Documentation Baseline

The documentation was prepared from the supplied repository snapshot reviewed on **2026-10-24**. Repository code, infrastructure, workflows, and evidence may evolve after that baseline. Revalidate relevant claims when their implementation or environment changes.

For a capability-level assessment, consult [Validation & Limitations](docs/06-engineering-evidence/validation-and-limitations.md) rather than inferring operational maturity from the technology list.

---

## License

No license grant is asserted by this README. Check the repository for an explicit `LICENSE` file before reusing, modifying, or redistributing the project.
