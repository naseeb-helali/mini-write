# Mini-Write — DevOps Engineering Documentation

> **The documentation must demonstrate DevOps Engineering competency, not Enterprise Engineering maturity.**
>
> يجب أن يثبت التوثيق امتلاك مهارات وممارسات DevOps Engineering المطلوبة في سوق العمل، من خلال توضيح ما تم بناؤه وأتمتته وتشغيله والتحقق منه والمشكلات التي تمت معالجتها، دون فرض متطلبات تتجاوز النطاق المهني المستهدف للمشروع أو تضخيم مستوى النضج التشغيلي الذي حققه.

## Purpose

This documentation describes the engineering work performed in Mini-Write as a practical DevOps portfolio project. It explains the system sufficiently to make infrastructure, delivery, deployment, operations, reliability, and security decisions understandable and reviewable. It is not an application-development manual and does not claim enterprise-scale maturity.

## Documentation map

| Area | Documents | Responsibility |
|---|---|---|
| Project context | [Project Overview](00-project/project-overview.md), [Engineering Scope](00-project/engineering-scope.md) | Purpose, intended competency level, boundaries, and interpretation rules |
| Architecture | [System Architecture](01-architecture/system-architecture.md), [Deployment Architecture](01-architecture/deployment-architecture.md) | Application dependencies and deployment topology |
| Infrastructure | [Infrastructure Overview](02-infrastructure/infrastructure-overview.md), [Terraform & Provisioning](02-infrastructure/terraform-and-provisioning.md), [AWS Infrastructure](02-infrastructure/aws-infrastructure.md) | Provisioning, AWS resources, and infrastructure relationships |
| Delivery | [CI Pipeline](03-delivery/ci-pipeline.md), [Artifact Management](03-delivery/artifact-management.md), [VM Deployment](03-delivery/deployment-platforms/vm-deployment.md), [ECS Deployment](03-delivery/deployment-platforms/aws-ecs-deployment.md), [Kubernetes on EC2](03-delivery/deployment-platforms/kubernetes-ec2-deployment.md) | Build, validation, immutable artifacts, release, promotion, and rollback |
| Operations | [Observability](04-operations/observability.md), [Reliability & Recovery](04-operations/reliability-and-recovery.md), [Operational Runbooks](04-operations/operational-runbooks.md) | Monitoring, failure handling, recovery, and operational procedures |
| Security | [DevOps Security Practices](05-security/devops-security-practices.md) | Security controls within delivery and infrastructure workflows |
| Evidence | [Competency Evidence](06-engineering-evidence/competency-evidence.md), [Validation & Limitations](06-engineering-evidence/validation-and-limitations.md) | Evidence-backed achievements and explicit verification boundaries |
| Governance | [Documentation Architecture & Scope](00-project/documentation-architecture-and-scope.md), [Documentation Traceability Matrix](00-project/documentation-traceability-matrix.md) | Document ownership, source mapping, and change control |

## How to read status statements

- **Implemented** — relevant code or automation is present in the reviewed repository.
- **Configured** — declarative configuration exists; this alone does not prove successful runtime operation.
- **Verified** — an identified test, command, workflow run, or retained evidence supports the specific claim.
- **Partial** — implementation or evidence covers only part of the stated capability.
- **Not established** — the reviewed repository and evidence do not support the claim.

A status applies only to the scope stated beside it. A successful historical run does not automatically validate a later source revision.

## Source baseline

This documentation was prepared against the supplied `mini-write.zip` repository snapshot reviewed on 2026-10-24. Repository paths and evidence references are relative to the repository root. If the implementation changes, the affected document and traceability matrix must be reviewed.

## Important scope notes

- The project has three deployment paths: VM/Compose, AWS ECS, and Kubernetes on AWS EC2 (not EKS).
- The VM Ansible project under `infra/ansible` is independent of the Kubernetes-specific Ansible project under `infra/kubernetes-ec2/ansible`.
- The Kubernetes workflow's Staging and Production stages target the same Staging cluster and namespace. This is a promotion-stage model, not independent Production infrastructure.
- Observability coverage differs by deployment platform.
- Historical ECS evidence exists, but the current archived `ci/deployment/adapters/aws-ecs/verify.sh` has a shell syntax error found during static review.
- The documentation does not represent every configured resource as freshly provisioned or live-verified.

## Intended audience

DevOps hiring teams, technical interviewers, engineering reviewers, and operators who need to understand what the project demonstrates, how its delivery paths work, and which claims are supported by evidence.

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](06-engineering-evidence/validation-and-limitations.md) where applicable.
