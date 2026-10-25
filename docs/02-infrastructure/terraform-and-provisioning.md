# Terraform and Provisioning

## 1. Responsibility

This document describes how infrastructure is declared and how compute hosts are prepared. Terraform manages cloud resources; Ansible configures operating systems and software on hosts. They solve related but different problems.

## 2. Terraform structure

```text
infra/terraform/
├── bootstrap/
├── environments/
│   ├── staging/
│   └── production/
└── modules/
    ├── vpc/
    ├── security-groups/
    ├── alb/
    ├── ecs/
    ├── ecr/
    ├── rds/
    ├── elasticache/
    ├── s3/
    ├── secrets/
    ├── iam/
    ├── cloudwatch/
    └── kubernetes-ec2/
```

The Staging environment composes reusable modules and declares environment-specific settings. The Production directory in the reviewed archive is a scaffold and must not be represented as a fully provisioned Production environment.

## 3. Infrastructure workflow

The infrastructure workflow follows this operating pattern:

```text
Terraform source change
        |
        v
GitHub Actions workflow
        |
        v
terraform init / validate / plan
        |
        v
Review planned changes
        |
        v
Explicit apply invocation
        |
        v
terraform apply
        |
        v
Post-apply terraform plan
        |
        v
No changes (reconciliation evidence)
```

The infrastructure automation closure records successful Staging plan/apply and a subsequent plan returning `No changes. Your infrastructure matches the configuration.` The closure also records apply execution through `workflow_dispatch` rather than automatic apply on push.

This is evidence for the tested Staging change set. It does not prove every future plan is safe or that every apply has a human approval gate.

## 4. VM Ansible project

The VM Ansible tree is located at `infra/ansible/` and includes:

- Inventory and Staging group variables.
- `site.yml` orchestration playbook.
- `base` role for host baseline configuration.
- `docker` role for container runtime installation/configuration.
- `deploy_runtime` role for Compose deployment assets, runtime scripts, environment templates, and observability configuration.
- `security_baseline` role for SSH/host hardening settings.
- `github_runner` role for the self-hosted GitHub Actions runner.

The deploy runtime role creates the expected runtime structure and templates under the target host's deployment directory. Its scripts cover preflight, execution, verification, state, telemetry, metrics, recovery, and cleanup.

## 5. Kubernetes-on-EC2 Ansible project

The Kubernetes-specific Ansible project is located at `infra/kubernetes-ec2/ansible/`. It is independent of `infra/ansible/` and handles:

- OS prerequisites.
- Containerd installation/configuration.
- Kubernetes package installation.
- ECR credential provider installation/configuration.
- Preflight checks.
- Control-plane and worker bootstrap orchestration.
- Cluster verification.

The cluster uses kubeadm and Calico. The reviewed configuration pins Kubernetes packages to the 1.35 series and the kubeadm configuration records the control-plane endpoint and networking setup.

Do not run VM provisioning instructions against Kubernetes nodes or reuse the old VM inventory as a substitute for the Kubernetes inventory.

## 6. Provisioning dependencies and reproducibility

The Kubernetes configuration currently expects specific private node addresses in parts of kubeadm configuration, Ansible inventory, and verification logic, while the EC2 Terraform module does not itself establish all those private addresses through fixed `private_ip` declarations. This is a reproducibility dependency: replacing an instance may require coordinated updates unless addressing is made deterministic.

The ECR credential provider also depends on an external binary path supplied to the Ansible role; that binary is not included in the repository archive. The setup procedure must therefore obtain the correct binary and verify its checksum before provisioning.

## 7. State and secrets

Terraform state is a sensitive operational asset and must not be committed as an ordinary source file. Environment-specific `.tfvars` files may contain sensitive values; the archive's ignore rules indicate these are not intended for source control. Review actual repository history before making claims about what was committed.

VM Ansible uses Ansible Vault for encrypted variables. Kubernetes CD retrieves required values from AWS Secrets Manager and synchronizes Kubernetes Secrets through `ci/kubernetes/secrets/sync.sh`. Temporary secret files are handled with restrictive permissions in the script. Secret rotation still requires a workload refresh mechanism; updating a Kubernetes Secret does not automatically replace environment variables already loaded into running containers.

## 8. Validation status

The archive review confirmed source structure and performed static parsing, but Terraform and Ansible CLIs were not available for fresh CLI validation in the review environment. The infrastructure closure provides execution evidence for a specific Staging Terraform apply and reconciliation.

Do not describe every Ansible role or every Terraform module as freshly executed or independently validated.

## 9. Source map

- `infra/terraform/`
- `infra/ansible/`
- `infra/kubernetes-ec2/ansible/`
- `infra/kubernetes-ec2/kubernetes/`
- `.github/workflows/infrastructure.yml`
- `evidence/infrastructure-automation/`

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
