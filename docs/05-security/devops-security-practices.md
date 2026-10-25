# DevOps Security Practices

## 1. Scope

This document records security practices implemented in the project's infrastructure and delivery workflows. It is not a formal security audit, compliance statement, or claim of complete DevSecOps maturity.

## 2. Identity and access management

Terraform defines IAM roles and policies for infrastructure operations, CI/CD access, compute nodes, and related AWS services. GitHub OIDC is used for workflow identity federation where configured, reducing the need to store long-lived AWS access keys in GitHub secrets.

The infrastructure automation evidence records removal of attached managed policies from the inspected Terraform apply role and replacement with custom inline policies. The closure contains an internal count inconsistency: it says nine policies, then corrects the observed inventory to ten. Documentation should refer to the listed policy inventory and avoid repeating the incorrect count.

The existence of scoped policy names is not proof that every permission is least-privilege. A complete IAM permission review would require evaluating actions, resources, conditions, and effective permission paths.

## 3. Self-hosted runner security

The GitHub Actions runner is provisioned through `infra/ansible/roles/github_runner/` and has Docker access. This is operationally useful but increases the importance of workflow trust boundaries. Untrusted pull-request code executed on a persistent runner with Docker privileges could expose runner resources or credentials.

Use repository branch protections, trusted workflow triggers, environment restrictions, and runner isolation appropriate to the project's workflow model. Do not claim that the runner is hardened against every untrusted workflow scenario solely because it is installed through Ansible.

## 4. Secrets management

The project uses:

- Ansible Vault for VM-side encrypted variables.
- AWS Secrets Manager for AWS-side secret storage.
- A Kubernetes secret synchronization helper under `ci/kubernetes/secrets/`.
- Example environment files rather than committing ordinary runtime secret values.

The reviewed archive contained `.env.example`, not a populated root `.env`; the Vault file was encrypted and `.vault-password` contained a placeholder. The ZIP does not include Git metadata, so it cannot establish the full secret history or whether every sensitive file was never committed.

Secret rotation requires runtime refresh. Kubernetes Secret updates do not automatically update environment variables already loaded by running Pods.

## 5. Network exposure

Terraform security groups and VM security-baseline configuration define network and host access controls. Kubernetes cluster communication uses explicit control-plane/kubelet/networking ports, and nodes are configured as private instances in the reviewed design.

The ALB/NodePort integration has a known gap: a target group references NodePort 30080, but the reviewed workload manifests do not define the corresponding NodePort Service or Ingress/Gateway path. This should be resolved before claiming the external application ingress path is complete.

## 6. Host and instance security

The VM Ansible security baseline configures SSH/host security settings. Kubernetes EC2 configuration requires IMDSv2 and uses encrypted gp3 volumes in the reviewed Terraform source. These are concrete controls, but they do not amount to a full host compliance benchmark.

## 7. Container and dependency scanning

CI includes `npm audit` and Trivy image scans. The Trivy optimization reuses scanner setup state between API and Worker scans without skipping the second scan. In the reviewed workflow, Trivy's `exit-code: 0` makes the scan non-blocking. Therefore, describe it as a security visibility step, not a mandatory vulnerability release gate.

The repository does not establish a complete image signing, provenance attestation, SBOM enforcement, or supply-chain policy framework. Do not claim these capabilities.

## 8. Kubernetes access model

The Kubernetes workflow uses a deployer kubeconfig on the self-hosted runner and SSM port forwarding to reach the private API endpoint. The CD README describes namespace-scoped permissions and avoids cluster-admin, Pod exec, and broad Secret read permissions in the deployment workflow.

However, the reviewed repository does not include a complete deployer RBAC bootstrap definition. The workflow therefore depends on pre-existing cluster-side identity/RBAC setup. Document this dependency instead of claiming the cluster access model is fully self-contained and reproducible from the repository.

The worker join token task in `cluster-bootstrap.yml` should use `no_log: true` to avoid accidental token exposure in Ansible output.

## 9. AWS workload permissions

The Kubernetes EC2 node role includes permissions used for ECR pulls and selected AWS integrations. The reviewed repository does not demonstrate per-Pod AWS identity isolation. Workloads may therefore inherit capabilities associated with the node role depending on credential exposure and runtime behavior. Do not claim workload-level least privilege.

## 10. Security validation boundaries

The evidence supports selected IAM inventory and workflow validation. The archive review did not perform penetration testing, full IAM policy simulation, secret-history analysis using Git metadata, or compliance assessment.

## 11. Source map

- `.github/workflows/`
- `infra/terraform/environments/staging/iam.tf`
- `infra/terraform/environments/staging/github-oidc.tf`
- `infra/terraform/environments/staging/kubernetes-github-access.tf`
- `infra/terraform/environments/staging/kubernetes-apply-permissions.tf`
- `infra/ansible/roles/security_baseline/`
- `infra/ansible/roles/github_runner/`
- `infra/ansible/vault/`
- `infra/kubernetes-ec2/ansible/`
- `ci/kubernetes/secrets/`
- `evidence/infrastructure-automation/`

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
