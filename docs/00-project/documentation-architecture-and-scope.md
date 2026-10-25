# Documentation Architecture & Scope

**Status:** Frozen baseline v1.0  
**Source baseline:** `mini-write.zip`, reviewed 2026-10-24

## 1. Governing principle

> The documentation must demonstrate DevOps Engineering competency, not Enterprise Engineering maturity.

Documentation exists to make the engineering work understandable and defensible. It is not a tutorial library, an exhaustive source-code commentary, or a maturity-assessment backlog.

## 2. Architecture

The documentation is organized around engineering responsibilities, not the chronological order in which the project was built.

```text
docs/
├── README.md
├── 00-project/
│   ├── project-overview.md
│   ├── engineering-scope.md
│   ├── documentation-architecture-and-scope.md
│   └── documentation-traceability-matrix.md
├── 01-architecture/
│   ├── system-architecture.md
│   └── deployment-architecture.md
├── 02-infrastructure/
│   ├── infrastructure-overview.md
│   ├── terraform-and-provisioning.md
│   └── aws-infrastructure.md
├── 03-delivery/
│   ├── ci-pipeline.md
│   ├── artifact-management.md
│   └── deployment-platforms/
│       ├── vm-deployment.md
│       ├── aws-ecs-deployment.md
│       └── kubernetes-ec2-deployment.md
├── 04-operations/
│   ├── observability.md
│   ├── reliability-and-recovery.md
│   └── operational-runbooks.md
├── 05-security/
│   └── devops-security-practices.md
└── 06-engineering-evidence/
    ├── competency-evidence.md
    └── validation-and-limitations.md
```

The architecture contains 18 engineering documents plus the navigation index and two governance documents.

## 3. Document responsibilities

| ID | Document | Single primary responsibility |
|---|---|---|
| D00 | Project Overview | Explain purpose, workload, platforms, and portfolio intent |
| D01 | Engineering Scope | Define competency target and exclusions |
| D02 | System Architecture | Explain application components and data flow |
| D03 | Deployment Architecture | Explain deployment topology and shared/platform-specific dependencies |
| D04 | Infrastructure Overview | Give an operator-oriented view of infrastructure components |
| D05 | Terraform & Provisioning | Explain infrastructure automation and the two independent Ansible paths |
| D06 | AWS Infrastructure | Explain AWS resources and their relationships |
| D07 | CI Pipeline | Explain validation, test, scan, and build workflow |
| D08 | Artifact Management | Explain image identity, manifests, promotion, and rollback artifact selection |
| D09 | VM Deployment | Explain VM/Compose deployment path |
| D10 | AWS ECS Deployment | Explain ECS deployment path and evidence boundary |
| D11 | Kubernetes on EC2 | Explain self-managed Kubernetes deployment path |
| D12 | Observability | Explain metrics, logs, dashboards, and alerting by platform |
| D13 | Reliability & Recovery | Explain runtime failure handling and deployment recovery |
| D14 | Operational Runbooks | Provide project-specific operational procedures |
| D15 | DevOps Security Practices | Explain implemented security controls in delivery and infrastructure |
| D16 | Competency Evidence | Map responsibilities to defensible outcomes |
| D17 | Validation & Limitations | Record validation results, gaps, and claims boundaries |

## 4. Content rules

- Explain the operational purpose before describing a tool.
- Describe the actual implementation, not a generic ideal architecture.
- Use diagrams where they clarify dependencies or workflow boundaries.
- Link to repository paths using relative links where practical.
- Separate shared AWS data services from compute-platform-specific components.
- Avoid repeating detailed explanations owned by another document; link to the owner document instead.
- State platform-specific limitations next to the relevant capability.
- Do not include secrets, credentials, private keys, kubeconfigs, or real secret values.

## 5. Scope exclusions

Do not create generic Docker, Linux, Terraform, Kubernetes, or AWS tutorials. Do not add Enterprise capabilities merely because they are common in larger organizations. Include a technology only when it explains an implemented responsibility or a relevant operational boundary.

## 6. Source of truth

The repository is authoritative for implementation. Retained evidence is authoritative only for the result it explicitly records. Existing documentation is reference material and must be checked against the source before reuse.

## 7. Change control

A source change that materially changes a workflow, resource, deployment target, verification method, or operational behavior requires review of its owning document and dependent documents. The traceability matrix is updated when source ownership, evidence, or verification status changes.

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
