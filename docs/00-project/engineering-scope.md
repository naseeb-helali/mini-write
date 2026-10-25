# Engineering Scope

## 1. Governing principle

> **The documentation must demonstrate DevOps Engineering competency, not Enterprise Engineering maturity.**

The project is evaluated by whether it demonstrates practical DevOps responsibilities at a level materially beyond introductory exposure. It is not evaluated against an imagined organization with a dedicated platform team, formal SRE program, multiple regions, or years of accumulated operational processes.

## 2. Competency model

The project emphasizes practical capability in the following areas:

| Domain | Competency demonstrated | Typical project evidence |
|---|---|---|
| Linux and host operations | Prepare and maintain deployment hosts | Ansible roles, host baseline, runtime layout |
| Infrastructure as Code | Declare and reconcile infrastructure | Terraform modules, environment configuration, plan/apply evidence |
| Cloud infrastructure | Assemble application infrastructure on AWS | VPC, security groups, ALB, EC2, ECS, ECR, RDS, Valkey, S3, IAM |
| Containers | Build reproducible application images | Dockerfiles, Buildx workflow, immutable image references |
| CI | Automate validation and build | GitHub Actions, tests, security checks, timing evidence |
| CD | Deploy, verify, promote, and recover releases | Deployment adapters, manifests, release evidence, rollback scripts |
| Kubernetes | Operate a small self-managed cluster workload | kubeadm, containerd, Calico, Deployments, Services, probes |
| Observability | Expose and inspect operational signals | Metrics, logs, dashboards, alert rules, health endpoints |
| Reliability | Handle retries, idempotency, failure, and recovery | Runtime modules, queue processing, deployment rollback |
| Security | Apply practical controls to infrastructure and delivery | IAM, OIDC, secrets handling, network controls, scans |

## 3. Expected depth

The project aims to show applied engineering rather than vocabulary familiarity. For a capability to count as demonstrated, the documentation should identify:

1. The operational problem or responsibility.
2. The relevant design decision.
3. The actual repository implementation.
4. How the implementation is exercised or verified.
5. The result and its limitations.

Some domains have strong retained execution evidence; others are primarily supported by source and configuration. That distinction must remain visible.

## 4. Included scope

### 4.1 Delivery engineering

- CI job orchestration and execution optimization.
- Test and coverage execution.
- Dependency and image scanning configuration.
- Container image build and registry publication.
- SHA/digest-based artifact identity.
- Release promotion and validation.
- Deployment readiness checks and rollback.

### 4.2 Infrastructure engineering

- Terraform-based AWS infrastructure definition.
- Staging infrastructure change workflow.
- VM provisioning through Ansible.
- Independent Kubernetes-on-EC2 provisioning through its own Ansible tree.
- IAM and network configuration necessary for delivery and runtime.

### 4.3 Operations engineering

- Health and readiness endpoints/probes.
- Application and infrastructure metrics.
- Centralized logging configuration where implemented.
- Dashboards and alert rules.
- Runtime retry and failure-handling behavior.
- Deployment state, verification, and recovery procedures.

## 5. Explicit exclusions

The documentation will not impose or claim capabilities that are not necessary to demonstrate the project's target DevOps responsibilities, including:

- Enterprise multi-region architecture.
- Multi-control-plane Kubernetes high availability.
- Organization-wide platform governance.
- Formal SRE error-budget programs.
- Comprehensive compliance certification.
- Full threat-modeling or penetration-test programs.
- Large-scale multi-team developer platform capabilities.
- Advanced service mesh, multi-cluster federation, or policy frameworks without actual implementation.

These are not presented as project failures. They are outside the chosen project scope unless a concrete implemented capability makes them relevant.

## 6. Evidence and claim discipline

Use the following wording consistently:

- **Implemented:** code or automation exists.
- **Configured:** configuration exists but operation is not established by evidence.
- **Executed:** a recorded run or operator execution is documented.
- **Verified:** a defined expected result was checked and recorded.
- **Partially verified:** only a subset of the intended behavior was checked.
- **Not established:** the repository/evidence does not support the claim.

Do not convert a planned feature into an implemented capability. Do not describe a historical evidence artifact as proof of the current source if the source has since changed or contains a known validation defect.

## 7. Portfolio positioning

The project should be positioned as a practical DevOps engineering project demonstrating hands-on responsibility across infrastructure, automation, deployment, observability, reliability, and security. It should not imply professional employment history or claim a specific number of years of production experience.

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
