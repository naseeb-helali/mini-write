# Validation and Limitations

## 1. Purpose

This document records what was validated during review of the supplied repository archive and what remains unverified. Its purpose is to protect the accuracy of project claims, not to create an unrestricted list of enterprise improvements.

## 2. Static validation results

The archive review performed static parsing/syntax checks with the following results:

| Check | Result | Interpretation |
|---|---:|---|
| JavaScript syntax (`node --check`) | 93/93 passed | All inspected JavaScript files parsed successfully |
| JSON parsing | 23/23 passed | All inspected JSON files parsed successfully |
| YAML parsing | 66/66 passed | All inspected YAML files parsed successfully |
| Shell syntax (`bash -n`) | 31/32 passed | One shell file failed syntax validation |

The failing file was:

`ci/deployment/adapters/aws-ecs/verify.sh`

The error is a syntax issue in the expected Worker digest command substitution. The current archived ECS verify adapter must be corrected and revalidated.

## 3. Checks not executed in the archive review

The following tools were not available/executed in the static review environment:

- Terraform CLI validation/plan.
- Ansible syntax/playbook execution.
- Kubernetes `kubectl` validation or live cluster inspection.
- Jest test execution, because Node dependencies were not installed in the review environment.
- Docker Compose runtime validation.

Therefore, parsing YAML successfully is not equivalent to validating Kubernetes API compatibility, and inspecting Terraform source is not equivalent to running `terraform validate` or applying infrastructure.

## 4. Coverage snapshots

The repository contains coverage summaries:

| Component | Lines | Statements | Functions | Branches |
|---|---:|---:|---:|---:|
| API | 80.44% | 80.22% | 75.83% | 53.62% |
| Worker | 87.74% | 87.17% | 66.66% | 54.90% |

The CI gate checks line coverage at 70%. Coverage summaries are retained artifacts and do not prove that tests were freshly run during the archive review. Branch/function coverage is materially lower than line coverage and should not be hidden by reporting only a single percentage.

## 5. Material implementation limitations

### Application and runtime

- API queue submission catches/logs errors without rethrowing in the reviewed path, which can separate API success from queue acceptance.
- Worker processing may leave a record in `processing` after failure and skip a retry based on that state.
- API retry timeout does not necessarily cancel the underlying operation.
- API does not demonstrate the same SIGTERM graceful shutdown behavior as Worker.
- Worker infrastructure boundary exists but is not integrated into the reviewed business path in the same way as API.

### VM

- VM provisioning and deployment code exists, but dedicated runtime deployment/rollback evidence was not found in the reviewed evidence directory.
- Root `.env.example` port value differs from root Compose healthcheck/Nginx expectations; VM Ansible template explicitly configures port 80 and is internally aligned with the VM template.

### ECS

- Current archived `ci/deployment/adapters/aws-ecs/verify.sh` fails shell syntax validation.
- Historical deployment and rollback evidence remains valid for its recorded run, but not as proof of current source correctness.
- Terraform task definition bootstrap uses `latest`, while CI release artifacts are SHA-tagged; first-provisioning alignment should be checked.

### Kubernetes on EC2

- One control-plane node; no HA control plane.
- Terraform does not pin all private node addresses expected by parts of kubeadm/inventory/verification configuration.
- Kubernetes package wildcard and preflight exact version expectation are not fully aligned.
- External ECR credential-provider binary is not included in the repository archive.
- Complete deployer RBAC bootstrap is not included; deployment depends on pre-existing cluster-side access configuration.
- ALB target group references NodePort 30080, but the workload manifests provide ClusterIP Services and no matching NodePort/Gateway/Ingress integration was identified.
- Secret updates do not automatically refresh environment variables in running Pods.
- `cluster-bootstrap.yml` worker join-token task should suppress sensitive output with `no_log: true`.
- No Kubernetes-specific centralized Prometheus/Loki/Grafana deployment was identified.
- Production-stage verification uses the Staging cluster and namespace.

### Observability and security

- Observability coverage differs by platform.
- Alertmanager receiver definitions that are commented out do not establish active outbound alert delivery.
- Trivy is configured as non-blocking (`exit-code: 0`) in the reviewed workflow.
- Self-hosted runner has Docker access; untrusted workflow execution is a trust-boundary concern.
- IAM policy inventory does not prove least privilege.
- Kubernetes node role permissions do not establish per-Pod AWS identity isolation.

## 6. Repository hygiene observations

- The root `.gitignore` excludes `.terraform.lock.hcl`, while an infrastructure ignore comment indicates the lock file should be retained; align the policy before relying on provider lock reproducibility.
- Coverage directories are present in the archive and should be reviewed for whether generated output belongs in source control.
- Coverage summary paths include machine-specific absolute paths.
- Kubernetes Ansible has both a root `group_vars/all.yml.example` and inventory-scoped group variable examples/configuration, which can create ambiguity in setup instructions.
- The ZIP excludes Git metadata; tracked/untracked status and complete commit history cannot be inferred from the archive.

## 7. Security review of archive contents

The reviewed ZIP contained `.env.example`, not a populated root `.env`. The Ansible Vault file was encrypted, and `.vault-password` contained a placeholder. No obvious plaintext AWS access key/private key pattern was identified in the inspected archive.

This is not a guarantee that secrets were never committed. The archive lacks Git history and cannot establish whether a credential existed in an earlier commit or another branch.

## 8. How limitations should be used

A limitation should appear in the document where it affects the reader's understanding of a capability. It should not dominate the project narrative or become an unrelated enterprise backlog.

The correct pattern is:

1. State the implemented capability.
2. State the evidence-backed result.
3. Identify the relevant limitation precisely.
4. Avoid implying that the limitation invalidates unrelated demonstrated work.

## 9. Revalidation triggers

Revalidate the affected area when:

- A source file associated with a known defect changes.
- Deployment target, namespace, instance addressing, or identity changes.
- Terraform modules or provider constraints change.
- A new evidence artifact is generated.
- A previously configured capability is exercised in a recorded runtime test.
- A platform's observability/security integration is added or materially changed.

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
