# Competency Evidence

## 1. Purpose

This document translates repository work into defensible DevOps competency statements. It avoids treating tool usage as an achievement by itself. Each claim connects a responsibility to implementation, verification, and an observable result.

## 2. Evidence-backed achievements

### 2.1 CI execution optimization

**Responsibility:** Improve CI efficiency without removing required security checks.

**Implementation:** Reuse Trivy setup/cache/database initialization between API and Worker image scans within the same GitHub Actions job.

**Verification:** Three optimized timing observations were retained under the same measurement contract.

**Result:**

| Metric | Baseline | Optimized median | Reduction |
|---|---:|---:|---:|
| CI E2E | 1866s | 893s | 973s (~52.14%) |
| Build | 954s | 412s | 542s (~56.81%) |

**Boundary:** These are measurements from the Mini-Write CI environment, not universal benchmark claims. The Trivy scans remained present, but the current scan action is non-blocking due to `exit-code: 0`.

### 2.2 Infrastructure change automation

**Responsibility:** Automate infrastructure changes and establish reconciliation after apply.

**Implementation:** Terraform Staging configuration is executed through GitHub Actions with explicit apply invocation.

**Verification:** The infrastructure closure records successful plan/apply and a subsequent plan reporting no changes.

**Result:** The tested Staging configuration reconciled with the Terraform-managed infrastructure at the time of verification.

**Boundary:** This does not establish independent Production provisioning or a formal approval gate for every apply.

### 2.3 IAM permission reduction

**Responsibility:** Reduce broad managed-policy attachment on the Terraform apply role.

**Implementation:** Replace attached AWS managed full-access policies with custom inline policies.

**Verification:** The closure records an empty attached managed-policy inventory and lists ten inline policies after correcting an earlier count statement.

**Result:** The tested infrastructure workflow continued to complete after the policy changes.

**Boundary:** This does not prove least privilege for every effective permission.

### 2.4 ECS deployment and recovery

**Responsibility:** Automate application deployment, verification, and rollback on ECS.

**Implementation:** ECS adapter scripts and Terraform-defined ECS infrastructure.

**Verification:** Historical deployment/recovery evidence records a Staging deployment and controlled failure/rollback scenarios.

**Result:** 215 seconds recorded for Staging deployment and 182 seconds for rollback.

**Boundary:** Current archived `aws-ecs/verify.sh` fails shell syntax validation; historical evidence must not be represented as proof that the current adapter source is clean.

### 2.5 Artifact identity and release validation

**Responsibility:** Ensure deployment and promotion use a known artifact rather than a mutable image reference.

**Implementation:** SHA-based tags, image digests, artifact manifest, promotion validation, and rollback artifact resolution.

**Verification:** Release-management evidence records positive identity checks and rejection of a digest mismatch.

**Result:** The tested release path can reject an artifact identity mismatch before promotion/deployment proceeds.

**Boundary:** No artifact signing or complete provenance attestation is established.

### 2.6 Kubernetes deployment on EC2

**Responsibility:** Provision and deploy a Kubernetes workload on self-managed EC2 infrastructure.

**Implementation:** Terraform EC2 resources, independent Ansible setup, kubeadm, Calico, ECR credential provider, workload manifests, SSM-based private API access, and dedicated CD automation.

**Verification:** Retained evidence records Staging deployment, Production-stage verification, image identity/readiness checks, and rollback.

**Result:** 16 seconds Staging deployment, 15 seconds Production-stage verification, and 48 seconds rollback in the recorded runs.

**Boundary:** Production stage uses the same Staging cluster and namespace; this is not a separate Production environment. The ALB-to-workload NodePort path is not fully established in the reviewed manifests.

## 3. Competency map

| DevOps competency | Repository implementation | Evidence strength |
|---|---|---|
| CI automation | GitHub Actions workflow, tests, scans, image build | Strong for recorded CI measurements |
| CI optimization | Trivy initialization reuse | Strong; repeated optimized observations |
| Infrastructure as Code | Terraform modules and Staging root | Strong for tested Staging apply/reconciliation |
| Configuration management | VM and Kubernetes-specific Ansible trees | Source-backed; execution evidence varies |
| AWS infrastructure | VPC, ALB, ECS, EC2, ECR, RDS, Valkey, S3, IAM | Configured; selected apply/deployment evidence |
| Container delivery | Dockerfiles, Buildx, ECR, digest-based artifacts | Strong for release validation scenarios |
| Deployment automation | VM/ECS/Kubernetes adapters and workflows | Different evidence strength by platform |
| Kubernetes operations | kubeadm cluster setup and workload deployment | Strong for recorded deployment/rollback scenarios, bounded by shared environment model |
| Observability | Application instrumentation, Prometheus stack, CloudWatch | Partial and platform-dependent |
| Reliability/recovery | Retry/state logic and deployment rollback | Selected tests and recovery evidence |
| Security practices | OIDC, IAM, secrets, scans, network controls | Implemented/configured; not comprehensive audit |

## 4. How to present these achievements professionally

Prefer statements that include a responsibility and a measurable or verifiable outcome. For example:

- Optimized GitHub Actions CI by reusing Trivy initialization across API and Worker scans, reducing measured E2E time from 31m06s to a 14m53s median across three optimized runs while retaining both scans.
- Automated Staging infrastructure changes with Terraform through GitHub Actions and verified post-apply reconciliation with a no-change plan.
- Implemented digest-based release validation and rollback artifact resolution across container deployment workflows.
- Built a self-managed Kubernetes-on-EC2 deployment path with automated provisioning, SSM-based private API access, workload readiness verification, and evidence-backed rollback.

Do not claim professional employment experience, enterprise-scale operations, or a guaranteed reliability level based on this portfolio project.

## 5. Evidence locations

- `evidence/ci-cd-delivery/`
- `evidence/infrastructure-automation/`
- `evidence/deployment-recovery/`
- `evidence/release-artifact-management/`
- `evidence/kubernetes-ec2 evidence/`

## 6. Review rule

Before publishing a portfolio claim, confirm the exact source revision, the corresponding evidence artifact, the target platform, and the measurement boundary. If the evidence is historical or platform-specific, say so.

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
