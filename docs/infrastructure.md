# Infrastructure Reproducibility & Environment Ownership

## Overview

Stage 3 introduced Infrastructure-as-Code practices into Mini-Write with a
specific objective:

Transforming the deployment host from a manually assembled environment into a
reproducible operational platform.

The goal was not infrastructure complexity, cloud engineering, or platform
engineering.

The goal was deterministic environment reconstruction.

A new deployment host should become deployment-ready through automation rather
than undocumented manual knowledge.

---

## Problem Statement

Before this stage, the deployment environment relied on a sequence of manual
steps performed directly on the VM.

Although the environment was operational, it suffered from a classic
Snowflake Infrastructure problem:

- Infrastructure knowledge existed primarily in the operator's memory.
- Environment reconstruction required remembering previous actions.
- Runtime preparation was not formally described.
- GitHub Runner installation was partially manual.
- Operational consistency depended on human execution.

This introduced risk in several areas:

- Environment drift
- Recovery complexity
- Host replacement difficulty
- Onboarding friction
- Operational uncertainty

The objective of this stage was eliminating these risks.

---

## Design Principles

The implementation followed five principles.

### 1. Reproducibility

The same automation should produce the same host state repeatedly.

### 2. Idempotency

Executing provisioning multiple times must not introduce side effects.

### 3. Environment Ownership

Infrastructure behavior should be encoded in source control rather than
operator memory.

### 4. Operational Simplicity

The solution should remain appropriate for a single-node deployment platform.

### 5. Realistic DevOps Practices

The implementation should resemble real operational workflows without
introducing enterprise-scale complexity.

---

## Why Ansible

Terraform was intentionally excluded.

The problem being solved was not cloud resource provisioning.

The problem was:

- machine provisioning
- runtime preparation
- deployment host standardization
- service lifecycle automation

These concerns align directly with Ansible's configuration management model.

---

# Infrastructure Layout

The infrastructure repository was organized around reusable roles.

```text
infra/
└── ansible/
    ├── inventories/
    ├── playbooks/
    ├── roles/
    └── vault/
```

The environment is provisioned through a single orchestration entrypoint:

```yaml
playbooks/site.yml
```

This playbook applies all infrastructure roles in a deterministic order.

---

# System Preparation

The base layer provisions host-level requirements.

Responsibilities include:

- package installation
- operating system preparation
- deployment user preparation
- runtime prerequisites

This establishes a predictable operating environment before higher-level
services are installed.

---

# Docker Runtime Automation

Docker installation was fully automated.

Provisioning now guarantees:

- Docker Engine installation
- Docker Compose Plugin installation
- Service activation
- Boot-time startup
- User access configuration

Validation confirmed:

- Docker availability
- Compose availability
- Service persistence
- Idempotent behavior

The deployment host no longer depends on manual Docker installation.

---

# Deployment Runtime Automation

A dedicated runtime structure is provisioned under:

```text
/opt/deploy
```

Provisioning creates and validates:

```text
/opt/deploy
├── compose
├── env
├── logs
├── state
└── scripts
```

Runtime ownership and permissions are enforced automatically.

This guarantees that deployment tooling always executes against a known and
predictable filesystem structure.

---

# GitHub Actions Runner Automation

One of the most important outcomes of Stage 3 was complete runner lifecycle
automation.

Provisioning now performs:

- runner download
- archive extraction
- runner registration
- service installation
- automatic startup
- service validation

The implementation avoids duplicate registrations by detecting existing runner
state before registration.

Runner provisioning therefore remains idempotent.

---

## Registration Token Lifecycle

GitHub runner registration requires short-lived registration tokens.

Provisioning requests a registration token dynamically through the GitHub API.

The token is used only during initial registration.

Subsequent provisioning executions do not re-register the runner unless the
runner state is missing.

This prevents unnecessary registration churn.

---

## Runner Service Management

The runner is installed as a systemd service.

Provisioning validates:

- service existence
- service enablement
- service startup state

The runner therefore survives:

- reboot events
- service restarts
- host restarts

without manual intervention.

---

# Operational Hardening

Additional operational validation was added to ensure the deployment host can
safely execute CI/CD workloads.

Validation covers:

- Docker accessibility
- deployment runtime ownership
- writable deployment paths
- runner service availability

This confirms the runner can perform deployment operations successfully.

---

# Security Baseline

A moderate security baseline was implemented.

The goal was practical risk reduction rather than enterprise hardening.

---

## Firewall Controls

UFW was configured with:

- default deny incoming
- default allow outgoing

Allowed services:

- SSH (22)
- HTTP (80)
- HTTPS (443)

This establishes a minimal externally exposed surface.

---

## SSH Hardening

The following controls were enforced:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
```

This removes password-based remote access and enforces key-based
authentication.

---

## Least Privilege Validation

The deployment model was reviewed to ensure:

- Runner executes as the deployment user
- Deployment runtime ownership is delegated appropriately
- Deployment paths remain writable by operational processes
- Administrative access remains controlled

The objective was operational practicality while avoiding unnecessary
privilege escalation.

---

# Idempotency Validation

Idempotency was treated as a primary success criterion.

Provisioning was repeatedly executed after infrastructure convergence.

Expected result:

```text
changed = 0
```

Observed result:

```text
changed = 0
```

after convergence.

This demonstrates that infrastructure state is managed declaratively rather
than procedurally.

---

# Full Rebuild Validation

The most important validation of the entire stage was rebuild testing.

A VM clone was created from the original baseline image.

Provisioning was executed against the new host.

Results:

- Host preparation succeeded.
- Runtime preparation succeeded.
- Docker provisioning succeeded.
- Runner registration succeeded.
- Service installation succeeded.
- Security baseline succeeded.

Provisioning was executed again immediately afterward.

Result:

```text
changed = 0
```

confirming successful convergence.

---

# CI/CD Validation

A dedicated runner validation workflow was introduced.

The workflow validates:

- runner availability
- Docker execution
- Compose execution
- deployment runtime visibility
- write access to deployment logs

The workflow successfully executed on the rebuilt environment.

This provided end-to-end confirmation that:

Infrastructure → Runner → Pipeline → Runtime

operate correctly together.

---

# What Was Intentionally Excluded

The following technologies were intentionally excluded:

- Kubernetes
- Helm
- Terraform-managed cloud infrastructure
- Service Mesh
- Multi-node orchestration
- Advanced IAM
- Enterprise monitoring platforms

These topics solve different problems and would have introduced unnecessary
scope expansion.

The focus remained deployment host lifecycle automation.

---

# Final Outcome

Mini-Write now possesses a reproducible deployment platform.

A deployment host can be recreated through infrastructure automation rather
than undocumented manual actions.

The project transitioned from:

```text
Snowflake Infrastructure
```

to:

```text
Reproducible Infrastructure
```

with:

- Infrastructure-as-Code
- Environment Ownership
- Deterministic Provisioning
- Idempotent Configuration Management
- Automated Runner Lifecycle Management
- Operational Validation
- Moderate Security Baseline

This stage established the operational foundation required for reliable
deployment lifecycle management.