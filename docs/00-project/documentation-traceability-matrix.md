# Documentation Traceability Matrix

**Status:** Baseline v1.0  
**Repository snapshot:** `mini-write.zip`, reviewed 2026-10-24

## 1. Status vocabulary

| Status | Meaning |
|---|---|
| Implemented | Code or automation exists in the repository |
| Configured | Declarative configuration exists; runtime success is not implied |
| Verified | Specific evidence supports the stated behavior |
| Partial | Implementation or evidence covers only part of the capability |
| Not established | No adequate source/evidence supports the claim |

## 2. Document-to-source mapping

| ID / Document | Primary repository sources | Evidence | Current assessment |
|---|---|---|---|
| D00 Project Overview | `.github/workflows/`, `api/`, `worker/`, `proxy/`, `ci/`, `infra/`, `observability/` | All `evidence/` areas | Implemented; selected capabilities verified |
| D01 Engineering Scope | Workflow, CI, infrastructure, runtime, observability, and deployment source trees | All evidence areas | Implemented; evidence depth varies |
| D02 System Architecture | `docker-compose.yml`, `api/src/`, `worker/src/`, `proxy/nginx.conf` | API/Worker tests and source | Implemented; selected behaviors tested |
| D03 Deployment Architecture | `docker-compose.yml`, `infra/ansible/`, `infra/terraform/`, `infra/kubernetes-ec2/`, `ci/` | Deployment and Kubernetes evidence | Configured; selected paths verified |
| D04 Infrastructure Overview | `infra/terraform/`, `infra/ansible/`, `infra/kubernetes-ec2/` | `evidence/infrastructure-automation/` | Configured; selected Staging changes verified |
| D05 Terraform & Provisioning | `infra/terraform/`, `infra/ansible/`, `infra/kubernetes-ec2/ansible/` | Infrastructure automation closure and JSON | Implemented; selected Staging Terraform apply/reconciliation verified |
| D06 AWS Infrastructure | Staging Terraform root and `infra/terraform/modules/` | Infrastructure, ECS, Kubernetes evidence | Configured; selected resources exercised |
| D07 CI Pipeline | `.github/workflows/ci.yml`, package manifests, tests, Dockerfiles | `evidence/ci-cd-delivery/` | Verified for recorded runs |
| D08 Artifact Management | `ci/artifact-manifest.schema.json`, `ci/promotion/`, `ci/rollback/`, `ci/kubernetes/` | `evidence/release-artifact-management/`, deployment evidence | Verified for selected scenarios |
| D09 VM Deployment | `.github/workflows/cd.yml`, `infra/ansible/`, `ci/deployment/adapters/vm/` | No dedicated VM runtime evidence artifact identified | Implemented/configured; runtime verification not established by archive evidence |
| D10 AWS ECS Deployment | `infra/terraform/.../ecs.tf`, ECS module, `ci/deployment/adapters/aws-ecs/` | `evidence/deployment-recovery/` | Historical verification; current adapter syntax issue |
| D11 Kubernetes on EC2 | Kubernetes Terraform, `infra/kubernetes-ec2/`, `ci/kubernetes/`, workflow | `evidence/kubernetes-ec2 evidence/` | Verified for recorded deployment/rollback scenarios; topology constraints apply |
| D12 Observability | `api/src/observability/`, `worker/src/observability/`, `observability/`, CloudWatch Terraform | Configurations and dashboards | Partial across platforms |
| D13 Reliability & Recovery | API/Worker runtime, queue processor, `ci/rollback/`, `ci/kubernetes/rollback/` | Runtime tests and recovery evidence | Implemented; selected scenarios verified |
| D14 Operational Runbooks | Existing `docs/operations/`, `docs/troubleshooting/`, operational scripts | Deployment and infrastructure evidence | Partial; commands require source-level review |
| D15 DevOps Security Practices | Workflow permissions, IAM Terraform, Ansible security roles, secret sync | Infrastructure and release validation evidence | Implemented/configured; partial verification |
| D16 Competency Evidence | All engineering source areas | All closure and evidence artifacts | Verified for recorded evidence areas |
| D17 Validation & Limitations | Tests, coverage, shell/YAML/JSON source, all workflows | Static review results and evidence files | Static validation completed; runtime validation partial |

## 3. Evidence register

| Evidence path | Claim it supports | Does not establish |
|---|---|---|
| `evidence/ci-cd-delivery/CI-CD-DELIVERY-CLOSURE.md` | CI measurement contract, baseline, optimized observations, optimization rationale | Universal CI performance or performance on other runners |
| `evidence/ci-cd-delivery/ci-cd-delivery-benchmark.json` | Raw timing observations used for benchmark | A fresh run of the current workflow revision |
| `evidence/infrastructure-automation/INFRASTRUCTURE-AUTOMATION-CLOSURE.md` | Staging Terraform plan/apply/reconciliation and inspected IAM policy inventory | Least-privilege proof for every action/resource or independent Production provisioning |
| `evidence/infrastructure-automation/infrastructure-automation-evidence.json` | Structured infrastructure validation result | Runtime health of application workloads |
| `evidence/deployment-recovery/DEPLOYMENT-RECOVERY-CLOSURE.md` | Historical ECS deployment/recovery scenarios | Current adapter source validity where static syntax currently fails |
| `evidence/deployment-recovery/deployment-recovery-benchmark.json` | Recorded deployment and rollback durations | SLA or future deployment time guarantee |
| `evidence/release-artifact-management/RELEASE-ARTIFACT-MANAGEMENT-CLOSURE.md` | Artifact identity and release validation controls | Artifact signing or full supply-chain attestation |
| `evidence/release-artifact-management/release-artifact-management-validation.json` | Recorded validation scenarios and outcomes | Security of every possible artifact path |
| `evidence/kubernetes-ec2 evidence/staging-evidence/promotion-eligibility.json` | Staging release evidence | Independent Production environment |
| `evidence/kubernetes-ec2 evidence/production-evidence/production-verification.json` | Production-stage verification on recorded target | Separate Production cluster/namespace |
| `evidence/kubernetes-ec2 evidence/rollback-evidence/rollback-verification.json` | Kubernetes rollback and post-rollback verification | Disaster recovery across regions or clusters |

## 4. Material source facts that constrain claims

### VM

VM provisioning and deployment configuration exists under `infra/ansible/` and `ci/deployment/adapters/vm/`. The reviewed evidence tree does not contain a dedicated VM deployment/rollback runtime evidence package. Describe implementation and configuration; do not invent timings or claim independently verified runtime success from this archive.

### ECS

Historical deployment evidence records 215 seconds for Staging deployment and 182 seconds for rollback. Static review found a shell syntax error in `ci/deployment/adapters/aws-ecs/verify.sh`. Historical results remain historical evidence; they do not clear the current source defect.

### Kubernetes

The Kubernetes workflow records Staging, Production-stage, and rollback evidence. Both Staging and Production-stage records target `mini-write-staging-k8s` / `mini-write-staging`; therefore, this is not independent Production infrastructure. The workflow is a controlled promotion model on one shared workload namespace.

The ALB target group references NodePort 30080, but the reviewed workload services are ClusterIP and no matching NodePort/Gateway/Ingress integration was identified. Do not claim complete external ALB-to-workload traffic integration.

### Observability

The repository contains application instrumentation and a Prometheus/Loki/Promtail/Grafana/Alertmanager configuration set used by the VM deployment path, plus CloudWatch resources for AWS. Equivalent Kubernetes observability deployment is not established by the archive.

### CI validation

The CI closure records E2E baseline 1866s and optimized median 893s; build baseline 954s and optimized median 412s. The reduction calculated from the displayed values is approximately 52.14% for E2E and 56.81% for build. Use raw values and recompute percentages consistently; the closure text contains a small E2E percentage rounding discrepancy.

## 5. Static review results

The reviewed archive's static checks recorded:

- JavaScript syntax: 93/93 passed `node --check`.
- JSON parsing: 23/23 passed.
- YAML parsing: 66/66 passed.
- Shell syntax: 31/32 passed; the failing file was `ci/deployment/adapters/aws-ecs/verify.sh`.
- Terraform, Ansible, and Kubernetes CLI validations were not run in the review environment.
- Jest tests were not freshly executed because dependencies were not installed in that environment.

These results describe the static archive review, not a CI run or live infrastructure test.

## 6. Change control

When a source file changes, identify its owning document in the table above. Reassess dependent documents if the change affects topology, interfaces, runtime behavior, deployment flow, verification, security boundaries, or evidence interpretation. Update this matrix only when ownership, evidence, or a material status changes.

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
