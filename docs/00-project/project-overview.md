# Project Overview

## 1. What Mini-Write is

Mini-Write is a portfolio and hands-on engineering project built to practice the responsibilities of a DevOps Engineer through the lifecycle of a small distributed application. The application provides a realistic workload around which infrastructure, CI/CD, container delivery, deployment automation, observability, reliability, and security practices can be implemented and exercised.

The application is the workload. The primary engineering subject of this repository is the platform and operational work required to build, package, provision, deploy, observe, and recover that workload.

## 2. Why it was built

The project has two connected objectives:

1. **Competency development:** gain practical exposure to the tools, workflows, operational decisions, and failure scenarios expected in current DevOps roles.
2. **Professional evidence:** create a coherent GitHub portfolio project that demonstrates relevant DevOps responsibilities beyond listing technologies or completing isolated tutorials.

The project deliberately uses implementation and simulation to encounter practical engineering problems: repeatable infrastructure, CI duration, image identity, controlled deployment, readiness verification, rollback, secrets, runtime dependencies, and operational visibility.

## 3. Engineering scope

The repository demonstrates work across:

- Application containerization and service dependencies.
- Infrastructure as Code with Terraform.
- Host provisioning and configuration with Ansible.
- AWS networking, compute, registry, database, cache, storage, IAM, and monitoring resources.
- GitHub Actions CI and deployment workflows.
- Container image build, tagging, digest-based release identity, and promotion.
- VM/Compose, ECS, and Kubernetes-on-EC2 deployment paths.
- Metrics, logs, dashboards, health checks, and alert configuration.
- Retry, idempotency, deployment verification, rollback, and recovery controls.
- Security practices for IAM, secrets, network exposure, runners, and image/dependency scanning.

These capabilities are not equally complete on every platform. Their individual status and evidence are documented in the relevant domain documents.

## 4. System at a glance

The application follows a distributed processing model:

```text
Client
  |
  v
Nginx Gateway
  |
  v
Stateless Node.js API ------> PostgreSQL
  |                              ^
  |                              |
  +----> Redis / BullMQ           |
              |                  |
              v                  |
         Worker -----------------+
              |
              v
       Object Storage
       (MinIO or S3)
```

The API accepts requests and coordinates state, queueing, and storage. The Worker consumes asynchronous image-processing jobs and writes processing results. PostgreSQL stores application state, Redis/Valkey provides queue infrastructure, and object storage holds uploaded and processed objects.

The deployment platform changes, but the application workload and major managed dependencies are reused where configured.

## 5. Deployment models

| Platform | Infrastructure / runtime model | Main automation |
|---|---|---|
| VM | Linux VM running Docker Compose behind Nginx | Ansible plus VM deployment adapter |
| AWS ECS | ECS services and task definitions behind an AWS load balancer | Terraform plus ECS deployment adapter |
| Kubernetes on EC2 | Self-managed Kubernetes cluster on EC2 instances; not EKS | Separate Terraform module, separate Ansible tree, Kubernetes manifests, and dedicated CD workflow |

The AWS ECS and Kubernetes-on-EC2 paths use shared AWS data services defined in the Staging Terraform environment. The VM path uses its own deployment configuration and must not be assumed to share the same runtime data plane.

## 6. What the project demonstrates

The strongest evidence-backed examples include:

- CI optimization measured across repeated runs, reducing E2E execution from 1866 seconds to an optimized median of 893 seconds.
- Build execution reduction from 954 seconds to an optimized median of 412 seconds.
- Terraform Staging apply followed by a plan reporting no changes.
- Controlled deployment and rollback evidence for ECS.
- Kubernetes deployment, Production-stage verification, and rollback evidence with image digest checks.
- Explicit artifact identity and release validation controls.

The measured values and their limitations are explained in the delivery and evidence documents.

## 7. What this project is not

Mini-Write is not presented as a mature enterprise platform operated by a team with several years of production ownership. It does not claim multi-region availability, independent high-availability control planes, comprehensive compliance, exhaustive disaster recovery, or uniform observability across all deployment targets.

A small project can still demonstrate meaningful DevOps engineering when the work is concrete, automated, tested, measured, and honestly bounded.

## 8. How to evaluate the project

Reviewers should follow the evidence chain:

**Responsibility → Repository implementation → Verification method → Retained evidence → Result.**

Technology presence alone is not the achievement. The engineering value lies in the problem addressed, the implementation decision, the automation or control introduced, and the result that can be substantiated.

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
