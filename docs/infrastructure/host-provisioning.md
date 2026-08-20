# Host Provisioning

## 1. Purpose

This document describes how the Mini-Write staging host is provisioned from an initially prepared Ubuntu machine into a host capable of running the complete Mini-Write platform.

The document focuses specifically on the **host provisioning lifecycle**.

It answers:

- What does the staging host need before Mini-Write can run?
- Which infrastructure layers are created during provisioning?
- In what order are those layers established?
- Which user owns which responsibilities?
- Which directories and files are created on the host?
- How are Docker, the deployment runtime, the GitHub Actions runner, and host security connected?
- Which validations determine whether the host is actually ready?
- What is infrastructure state versus application state?
- What happens when provisioning is repeated?
- What should be investigated when provisioning fails?

This document complements:

- [`overview.md`](./overview.md) — infrastructure architecture;
- [`infrastructure-as-code.md`](./infrastructure-as-code.md) — IaC principles and architecture;
- [`ansible.md`](./ansible.md) — Ansible implementation details.

The distinction is important:

```text
overview.md
    → What infrastructure exists and why?

infrastructure-as-code.md
    → How infrastructure is represented as code?

ansible.md
    → How Ansible implements that model?

host-provisioning.md
    → How an actual host moves from prepared machine to
      Mini-Write-ready staging host?
````

---

# 2. Provisioning Objective

The objective of host provisioning is to establish a **known operational foundation** on the staging host.

The final state is not simply:

```text
"Ubuntu + Docker"
```

It is:

```text
Prepared Ubuntu Host
        │
        ▼
Base System
        │
        ▼
Docker Runtime
        │
        ▼
Deployment Runtime
        │
        ▼
CI/CD Execution Environment
        │
        ▼
Security Baseline
        │
        ▼
Mini-Write Staging Host
```

A host is considered provisioned only when the infrastructure required by the downstream deployment and operations layers exists and the relevant validation checks succeed.

---

# 3. Provisioning Boundary

Host provisioning owns the **host-level foundation**.

It establishes:

```text
Operating System prerequisites
Docker
Deployment filesystem
Deployment configuration
Runtime scripts
Deployment state
Deployment logs
Observability configuration
GitHub Actions runner
Firewall
SSH hardening
```

It does not own:

```text
Application business logic
Application runtime reliability policy
Application request handling
Application job processing
Application data lifecycle
Incident investigation
Application release decisions
```

The boundary can be represented as:

```text
┌──────────────────────────────────────────────┐
│              Host Provisioning               │
│                                              │
│  OS → Docker → Deployment Runtime → Runner   │
│                         │                    │
│                    Security Baseline         │
└──────────────────────────────────────────────┘
                       │
                       ▼
              Deployment / Runtime
                       │
                       ▼
                 Application
```

---

# 4. Target Host

The current infrastructure model provisions the Mini-Write **staging host**.

The Ansible playbook explicitly targets:

```text
staging
```

and executes with privilege escalation.

Therefore the provisioning contract is:

```text
Target:
    staging host

Execution:
    Ansible

Privilege:
    elevated / root-capable

Desired result:
    Mini-Write-ready staging infrastructure
```

The exact host address and inventory-specific connection parameters belong to the Ansible inventory/environment configuration rather than the provisioning architecture itself.

---

# 5. Provisioning Entry Point

The provisioning lifecycle begins at:

```text
infra/ansible/playbooks/site.yml
```

The playbook orchestrates the provisioning roles in this order:

```text
base
  ↓
docker
  ↓
deploy_runtime
  ↓
github_runner
  ↓
security_baseline
```

This ordering establishes a dependency chain.

---

# 6. Provisioning Dependency Graph

The provisioning process can be understood as:

```text
                    ┌──────────────┐
                    │     base     │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │    docker    │
                    └──────┬───────┘
                           │
                           ▼
                 ┌───────────────────┐
                 │   deploy_runtime  │
                 └─────────┬─────────┘
                           │
                           ▼
                 ┌───────────────────┐
                 │   github_runner   │
                 └─────────┬─────────┘
                           │
                           ▼
                 ┌───────────────────┐
                 │ security_baseline│
                 └───────────────────┘
```

The dependency meaning is:

```text
base
  → provides host prerequisites

docker
  → provides container execution

deploy_runtime
  → provides the deployment filesystem and configuration

github_runner
  → provides CI/CD execution on the provisioned host

security_baseline
  → establishes host-level security controls
```

---

# 7. Provisioning Phases

Although Ansible implements provisioning through roles, the resulting host lifecycle is easier to understand through infrastructure phases.

## Phase 1 — Base Host Preparation

```text
APT
System Packages
Host Prerequisites
```

## Phase 2 — Container Runtime

```text
Docker Repository
Docker Packages
Docker Service
Docker Access
```

## Phase 3 — Deployment Runtime

```text
Deployment Root
Directories
Compose
Nginx
Scripts
Runtime Modules
State
Environment
Logs
Observability Configuration
```

## Phase 4 — CI/CD Runtime

```text
Runner Dependencies
Runner Installation
Runner Registration
Runner Service
Runner Validation
```

## Phase 5 — Security Baseline

```text
Firewall
SSH Hardening
SSH Service
```

The resulting host is:

```text
Base
 +
Docker
 +
Deployment Runtime
 +
CI/CD
 +
Security
 =
Mini-Write Staging Host
```

---

# 8. Phase 1 — Base Host Preparation

The first provisioning layer is the `base` role.

Its responsibility is to establish the basic operating-system environment required by subsequent infrastructure layers.

The role performs:

```text
APT cache update
Installed package upgrade
Base package installation
```

The lifecycle is:

```text
Ubuntu
  │
  ▼
Update Package Index
  │
  ▼
Upgrade Installed Packages
  │
  ▼
Install Required Base Packages
  │
  ▼
Base Host Ready
```

The important architectural principle is that later roles should not need to independently solve these foundational operating-system prerequisites.

---

# 9. Why Base Provisioning Comes First

The later infrastructure layers depend on the operating system being in a predictable state.

For example:

```text
Docker
    ↓
requires package-management infrastructure

GitHub Runner
    ↓
requires system packages and filesystem support

Security Baseline
    ↓
requires package installation and system services
```

Therefore:

```text
Base Host
    ↓
Infrastructure Runtime
```

is preferable to having every role independently prepare the operating system.

---

# 10. Phase 2 — Docker Runtime

The second layer establishes Docker.

The provisioning sequence is:

```text
Create keyring directory
        ↓
Install Docker repository key
        ↓
Configure Docker repository
        ↓
Update APT cache
        ↓
Install Docker packages
        ↓
Enable Docker service
        ↓
Start Docker service
        ↓
Grant deployment user Docker access
```

This creates the container execution substrate used by Mini-Write.

---

# 11. Docker Repository Trust

Docker packages are installed from the Docker repository.

The provisioning process creates:

```text
/etc/apt/keyrings/
```

and places the Docker GPG key there.

The repository is configured with a `signed-by` relationship.

Conceptually:

```text
Docker Repository
       │
       ▼
Repository Signature
       │
       ▼
Trusted Keyring
       │
       ▼
APT
       │
       ▼
Docker Packages
```

This is preferable to treating package installation as an untrusted download operation.

---

# 12. Docker Service Readiness

After installation, Docker is configured as a system service.

The intended state is:

```text
enabled = true
state   = started
```

This creates the following boot dependency:

```text
Host Boot
    │
    ▼
systemd
    │
    ▼
Docker
    │
    ▼
Containers
```

Without this property, a host reboot could leave the deployment runtime unavailable even though Docker had previously been installed.

---

# 13. Deployment User and Docker

The deployment user is added to the Docker group.

This creates an important operational relationship:

```text
deploy_user
      │
      ▼
docker group
      │
      ▼
Docker CLI/API access
      │
      ▼
Deployment and CI/CD workloads
```

The GitHub Actions runner is also configured to operate using this deployment identity.

Therefore Docker group membership is not merely a convenience; it is part of the CI/CD execution contract.

---

# 14. Phase 3 — Deployment Runtime

Once Docker is available, the `deploy_runtime` role establishes the filesystem and configuration required by deployment.

The deployment runtime is represented by:

```text
{{ deploy_root }}
```

and its configured subdirectories.

The resulting architecture is conceptually:

```text
/opt/deploy/
    │
    ├── compose/
    ├── proxy/
    ├── scripts/
    ├── state/
    ├── env/
    ├── logs/
    ├── metrics/
    └── ...
```

The exact directory set is controlled by Ansible variables and role configuration.

---

# 15. Deployment Root

The deployment root is created as:

```text
root:root
0755
```

at the root level.

This creates a controlled infrastructure boundary.

The deployment root is not treated as an arbitrary working directory owned entirely by the deployment user.

Instead, ownership is deliberately divided according to responsibility.

---

# 16. Immutable and Mutable Runtime Areas

The provisioning model distinguishes between infrastructure-controlled and runtime-modifiable directories.

Conceptually:

```text
Deployment Runtime
       │
       ├── Immutable / Infrastructure-Controlled
       │       │
       │       └── root:root
       │
       └── Mutable / Operational
               │
               └── deploy_user:deploy_user
```

This separation is important because deployment automation needs write access to certain stateful locations without automatically receiving ownership over every infrastructure configuration file.

---

# 17. Deployment Configuration

The host receives rendered configuration files from Ansible templates.

Important configuration artifacts include:

```text
docker-compose.staging.yml
nginx.conf
.env.staging
deployment_state.json
```

The flow is:

```text
Repository Template
        │
        +
        │
Ansible Variables
        │
        ▼
Rendered Configuration
        │
        ▼
Deployment Host
```

This ensures the host configuration can be reconstructed from version-controlled infrastructure definitions plus protected environment-specific configuration.

---

# 18. Docker Compose Configuration

The staging Compose file is generated from:

```text
docker-compose.staging.yml.j2
```

and deployed into the Compose configuration directory.

The rendered file defines the container topology used by the staging environment.

Its services include the application and infrastructure/observability components required by Mini-Write.

The provisioning responsibility is:

```text
Make Compose Configuration Available
```

not:

```text
Perform Application Release
```

This distinction keeps infrastructure provisioning separate from deployment execution.

---

# 19. Nginx Configuration

The provisioning process also renders:

```text
nginx.conf
```

from its Jinja2 template.

This provides the reverse-proxy configuration required by the deployment topology.

Conceptually:

```text
External Request
      │
      ▼
    Nginx
      │
      ▼
     API
```

Ansible ensures that the proxy configuration exists on the host; the application/deployment layer determines when and how the running services consume it.

---

# 20. Deployment Scripts

The deployment runtime also receives deployment scripts.

These scripts are rendered into:

```text
{{ deploy_root }}/scripts/
```

and marked executable.

The architecture is therefore:

```text
Infrastructure
      │
      ▼
Deployment Scripts
      │
      ▼
CI/CD Runner
      │
      ▼
Application Deployment
```

The scripts belong to the deployment layer rather than the host provisioning layer conceptually, but Ansible establishes the filesystem and makes the required scripts available.

---

# 21. Runtime Modules

The provisioning role creates a dedicated runtime module directory:

```text
{{ deploy_root }}/scripts/{{ runtime_subdirectory }}
```

Runtime modules are rendered from the Ansible template source:

```text
runtime/
```

and deployed with executable permissions.

This creates a stable host-side location for deployment runtime functionality.

---

# 22. Deployment State

The deployment runtime maintains:

```text
{{ deployment_state_file }}
```

and initializes it from:

```text
deployment_state.json.j2
```

The initial logical state is:

```json
{
  "current": {
    "api": "",
    "worker": ""
  },
  "previous": {
    "api": "",
    "worker": ""
  }
}
```

This state is designed to support deployment tracking.

The key distinction is:

```text
Infrastructure State
        ≠
Application Deployment State
```

Ansible creates the initial state structure but does not own the history of every subsequent application deployment.

---

# 23. State Preservation

The state file is checked before initialization.

The lifecycle is:

```text
Check deployment_state.json
          │
      ┌───┴────┐
      │        │
    Exists   Missing
      │        │
      ▼        ▼
   Preserve  Bootstrap
```

This behavior is essential.

If provisioning overwrote deployment state on every execution, re-running Ansible could destroy operational information.

Therefore state initialization is intentionally conditional.

---

# 24. Environment File

The staging environment configuration is provisioned at:

```text
{{ deploy_root }}/env/.env.staging
```

The file is initialized only if it does not already exist.

Its permissions are configured as:

```text
0640
```

and ownership is subsequently assigned to the deployment user.

The intended model is:

```text
Configuration
     │
     ├── Infrastructure-controlled creation
     │
     └── Restricted runtime access
```

The actual sensitive values are supplied through protected Ansible configuration rather than being embedded directly into the provisioning tasks.

---

# 25. Deployment Logs

The provisioning process establishes:

```text
{{ deploy_root }}/logs/deploy.log
```

if it does not already exist.

The file is owned by the deployment user.

This creates a stable operational contract:

```text
Deployment Automation
        │
        ▼
deploy.log
        │
        ▼
Observability Collection
```

The log location is therefore both a deployment concern and an observability integration point.

---

# 26. Metrics Directory

A dedicated metrics directory is created under the deployment root.

Conceptually:

```text
deploy_root/
    └── metrics/
```

This directory is owned by the deployment user.

It supports host-level metric integration, including the Node Exporter textfile collector used by the observability architecture.

The resulting flow is:

```text
Deployment / Runtime Script
          │
          ▼
      metrics file
          │
          ▼
    Node Exporter
          │
          ▼
      Prometheus
```

---

# 27. Observability Configuration

The provisioning process synchronizes the observability configuration into the deployment runtime.

This includes the configuration consumed by:

```text
Prometheus
Loki
Promtail
Alertmanager
Grafana
Exporters
```

The provisioning relationship is:

```text
Repository
    │
    ▼
observability/
    │
    ▼
Ansible copy/synchronization
    │
    ▼
Deployment Runtime
    │
    ▼
Observability Stack
```

This makes monitoring infrastructure reproducible along with the rest of the host configuration.

---

# 28. Phase 4 — GitHub Actions Runner

After the deployment runtime exists, the host can be configured as a CI/CD execution environment.

The `github_runner` role establishes the self-hosted GitHub Actions runner.

The lifecycle is:

```text
Install Dependencies
       │
       ▼
Create Runner Directory
       │
       ▼
Download Runner
       │
       ▼
Extract Runner
       │
       ▼
Register Runner
       │
       ▼
Install Service
       │
       ▼
Start Service
       │
       ▼
Validate Runner
```

---

# 29. Runner Installation Directory

The runner is installed under:

```text
{{ github_runner_install_dir }}
```

The directory is owned by:

```text
deploy_user:deploy_user
```

This aligns the runner's filesystem ownership with the identity under which the CI/CD workload operates.

---

# 30. Runner Installation Detection

Before downloading and extracting the runner, Ansible checks for:

```text
run.sh
```

inside the runner installation directory.

The behavior is:

```text
run.sh exists?
      │
  ┌───┴────┐
  │        │
 Yes       No
  │         │
Skip      Install
```

This makes runner installation state-aware.

---

# 31. Runner Registration

Runner registration is also state-aware.

The presence of:

```text
.runner
```

indicates an existing runner registration.

The lifecycle is:

```text
Check .runner
     │
 ┌───┴────┐
 │        │
Yes       No
 │         │
Skip    Obtain registration token
           │
           ▼
       Register runner
```

This avoids repeatedly registering the same runner.

---

# 32. Runner Credentials

Runner registration requires protected GitHub credentials.

The registration token is obtained dynamically through the GitHub API.

Sensitive tasks are executed with logging protection so credentials and tokens are not exposed in normal Ansible output.

The security boundary is:

```text
Protected Credential
        │
        ▼
GitHub API
        │
        ▼
Short-lived Registration Token
        │
        ▼
Runner Registration
```

The registration token is therefore an operational bootstrap artifact, not a static application configuration value.

---

# 33. Runner Labels

The runner receives its configured labels during registration.

The labels allow GitHub Actions workflows to select the intended execution environment.

Conceptually:

```text
GitHub Workflow
      │
      ▼
Runner Labels
      │
      ▼
Mini-Write Staging Runner
```

This creates an explicit scheduling relationship between CI/CD workflows and the provisioned host.

---

# 34. Runner Service

The runner is installed as a systemd service.

The desired state is:

```text
enabled
started
```

Therefore:

```text
Host Boot
    │
    ▼
systemd
    │
    ▼
GitHub Runner
    │
    ▼
Workflow Execution
```

This ensures the runner does not depend on an administrator manually starting the process after each reboot.

---

# 35. Runner Operational Contract

A runner is not considered operational merely because its files exist.

The host provisioning process additionally validates:

```text
Runner service is active
Deployment directories exist
Deployment user has Docker access
```

The actual operational contract is:

```text
Runner Installed
      +
Runner Registered
      +
Runner Service Active
      +
Docker Access
      +
Deployment Runtime Available
      =
CI/CD-Ready Host
```

---

# 36. Docker Access Validation

The provisioning process explicitly retrieves the deployment user's groups and verifies membership in:

```text
docker
```

The assertion exists because the runner depends on Docker access.

Without this check:

```text
Runner = Active
```

could incorrectly be interpreted as:

```text
Runner = Capable of Deployment
```

The validation closes that gap.

---

# 37. Deployment Runtime Validation

The runner role also validates the existence of critical deployment directories, including:

```text
/opt/deploy/state
/opt/deploy/logs
/opt/deploy/env
```

The purpose is to verify the dependency established by `deploy_runtime`.

The relationship is:

```text
deploy_runtime
      │
      ▼
Required Directories
      │
      ▼
github_runner Validation
      │
      ▼
CI/CD Readiness
```

This creates an explicit cross-role contract.

---

# 38. Phase 5 — Security Baseline

The final provisioning layer establishes host security controls.

The current security baseline includes:

```text
UFW
SSH hardening
SSH service enablement
```

The security model is:

```text
Host
 │
 ├── Network Boundary
 │      └── UFW
 │
 └── Administrative Access Boundary
        └── SSH Hardening
```

---

# 39. UFW Default Policy

The firewall is configured with:

```text
Incoming → DENY
Outgoing → ALLOW
```

This establishes a default-deny inbound posture.

The effective model is:

```text
Incoming Connection
       │
       ▼
      UFW
       │
       ├── Explicitly Allowed
       │
       └── Default Denied
```

Required TCP ports are explicitly allowed through the configured port list.

---

# 40. Firewall Ordering

The firewall configuration should be understood as a policy rather than simply a list of commands.

The intended policy is:

```text
1. Deny unsolicited incoming traffic
2. Allow required TCP services
3. Allow outbound traffic
4. Enable firewall
```

This creates a predictable network boundary around the host.

---

# 41. SSH Hardening

SSH configuration is rendered from:

```text
sshd_config.j2
```

and deployed as:

```text
/etc/ssh/sshd_config.d/99-miniwrite-hardening.conf
```

The configuration controls:

```text
PasswordAuthentication
PermitRootLogin
PubkeyAuthentication
PermitEmptyPasswords
```

The values are controlled through infrastructure variables.

This allows the security posture to be changed through version-controlled configuration rather than manual host editing.

---

# 42. SSH Validation Before Activation

An important provisioning safety mechanism is SSH configuration validation.

Before accepting the generated configuration, Ansible executes:

```text
/usr/sbin/sshd -t -f <generated-file>
```

The lifecycle is:

```text
Render SSH Configuration
          │
          ▼
      sshd -t
          │
      ┌───┴────┐
      │        │
    Valid    Invalid
      │        │
      ▼        ▼
 Accept      Reject
```

This is particularly important because an invalid SSH configuration could interfere with administrative access to the host.

---

# 43. Provisioning Completion

The host provisioning process is complete when the following conditions are satisfied.

## Operating System

```text
Base packages installed
```

## Docker

```text
Docker installed
Docker service active
Deployment user has Docker access
```

## Deployment Runtime

```text
Deployment directories exist
Compose configuration exists
Proxy configuration exists
Deployment scripts exist
Runtime modules exist
State exists
Environment configuration exists
Logs exist
Observability configuration exists
```

## CI/CD

```text
Runner installed
Runner registered
Runner service active
Runner can access Docker
Runner can access deployment runtime
```

## Security

```text
UFW enabled
Required ports allowed
SSH configuration valid
SSH service enabled
```

The overall readiness condition is:

```text
Base
 ∧ Docker
 ∧ Deployment Runtime
 ∧ CI/CD
 ∧ Security
 =
Provisioned Host
```

---

# 44. Provisioning Versus Deployment

A critical distinction must be maintained between **host provisioning** and **application deployment**.

### Host provisioning

Creates:

```text
Docker
Filesystem
Configuration
Runner
Security
Observability infrastructure
```

### Application deployment

Uses those capabilities to establish:

```text
API version
Worker version
Container state
Application release
```

Therefore:

```text
Provisioning
     │
     ▼
Deployment Foundation
     │
     ▼
Application Deployment
```

Ansible should not become the mechanism for encoding application release workflows that belong to the deployment layer.

---

# 45. Provisioning Versus Application Runtime

The same distinction applies to runtime reliability.

Ansible establishes the host environment in which the application runtime operates.

It does not implement:

```text
Request Context
Operation Context
Retry Policy
Timeout Handling
Failure Classification
Runtime Recovery
```

Those concerns belong to the application runtime architecture.

Therefore:

```text
Host Provisioning
        │
        ▼
Infrastructure Runtime
        │
        ▼
Application Runtime
        │
        ▼
Business Workload
```

Each layer has a different responsibility.

---

# 46. Provisioning Idempotency

Host provisioning is designed around repeated execution.

A typical lifecycle is:

```text
First Run
   │
   ▼
Create Missing Infrastructure
   │
   ▼
Validate
```

A later run becomes:

```text
Existing Host
   │
   ▼
Inspect State
   │
   ▼
Detect Drift / Missing Resources
   │
   ▼
Apply Required Changes
   │
   ▼
Preserve Existing Operational State
   │
   ▼
Validate
```

This is one of the primary advantages of representing infrastructure through Ansible.

---

# 47. What Should Be Preserved During Re-Provisioning

Certain host artifacts represent operational state and should not be blindly recreated.

Examples include:

```text
deployment_state.json
.env.staging
deploy.log
runner registration
```

The implementation therefore performs existence checks before initializing these artifacts.

The principle is:

```text
Infrastructure Definition
        │
        ▼
Converge Infrastructure
        │
        ├── Create missing state
        │
        └── Preserve valid existing state
```

---

# 48. Re-Provisioning After Host Drift

If the host is modified manually, the preferred recovery process is:

```text
Identify Drift
      │
      ▼
Determine Intended State
      │
      ▼
Update IaC if the change is legitimate
      │
      ▼
Re-run Ansible
      │
      ▼
Validate
```

Manual changes should not become the permanent source of truth.

The repository should remain authoritative for infrastructure configuration.

---

# 49. Re-Provisioning After Host Failure

If the host itself becomes unavailable or must be rebuilt, Ansible can recreate the infrastructure represented by the repository.

The conceptual recovery sequence is:

```text
New / Rebuilt Ubuntu Host
          │
          ▼
Ansible Provisioning
          │
          ▼
Base
          │
          ▼
Docker
          │
          ▼
Deployment Runtime
          │
          ▼
GitHub Runner
          │
          ▼
Security Baseline
          │
          ▼
Deployment
```

However, infrastructure reproducibility does not imply automatic restoration of persistent application data.

---

# 50. Persistent Data Boundary

The host contains persistent application and observability data such as:

```text
PostgreSQL data
Redis data
MinIO data
Prometheus data
Grafana data
Loki data
Alertmanager data
```

These are not equivalent to the Ansible-managed infrastructure definition.

Therefore:

```text
Ansible Reproducibility
        ≠
Persistent Data Backup
```

A rebuilt host may reproduce the infrastructure while still requiring a separate data restoration strategy.

This distinction is essential for disaster recovery planning.

---

# 51. Provisioning Failure Model

Provisioning failures should be localized by infrastructure layer.

```text
Failure
  │
  ├── Base
  │
  ├── Docker
  │
  ├── Deployment Runtime
  │
  ├── GitHub Runner
  │
  └── Security Baseline
```

Each layer has a different diagnostic path.

---

# 52. Base Provisioning Failures

Typical causes include:

```text
APT repository unavailable
Network connectivity failure
Package conflict
Unsupported package
Operating-system mismatch
```

Investigation should begin with:

```text
APT status
OS release
Repository connectivity
Package availability
```

---

# 53. Docker Provisioning Failures

Typical causes include:

```text
Docker repository configuration
GPG key retrieval
APT failure
Docker package conflict
Docker service failure
User group configuration
```

The validation sequence is:

```text
Docker Package
     ↓
Docker Service
     ↓
Docker CLI
     ↓
deploy_user group membership
```

A successful package installation does not by itself prove Docker readiness.

---

# 54. Deployment Runtime Failures

Typical causes include:

```text
Incorrect variable
Template rendering failure
Invalid path
Permission mismatch
Missing source configuration
Invalid generated configuration
```

The first investigation targets:

```text
Ansible variables
Template source
Rendered file
Filesystem permissions
```

---

# 55. GitHub Runner Failures

Typical causes include:

```text
Invalid GitHub credentials
GitHub API failure
Registration token failure
Runner archive download failure
Runner registration failure
systemd service failure
Docker access failure
Missing deployment runtime
```

The diagnostic dependency chain is:

```text
Runner Files
    ↓
Registration
    ↓
Service
    ↓
Docker Access
    ↓
Deployment Runtime
```

---

# 56. Security Provisioning Failures

Typical causes include:

```text
Invalid SSH configuration
Missing UFW package
Incorrect firewall rule
Missing required port
SSH service failure
```

SSH configuration failures require particular caution because remote administrative access may depend on the resulting configuration.

The generated configuration should therefore always be validated before activation.

---

# 57. Provisioning Validation Model

Validation should be performed at three levels.

## Level 1 — Configuration Validation

```text
Templates
Variables
Syntax
```

## Level 2 — Resource Validation

```text
Directories
Files
Ownership
Permissions
Services
```

## Level 3 — Operational Validation

```text
Docker usable
Runner active
Deployment runtime available
Security controls active
```

The model is:

```text
Configuration
      │
      ▼
Resources
      │
      ▼
Operational Capability
```

---

# 58. Why Resource Existence Is Not Enough

Consider:

```text
/etc/ssh/sshd_config.d/99-miniwrite-hardening.conf
```

Existing does not necessarily mean:

```text
Valid
```

Likewise:

```text
GitHub Runner files
```

existing does not necessarily mean:

```text
Runner operational
```

And:

```text
Docker package
```

installed does not necessarily mean:

```text
Docker usable by deployment user
```

Therefore provisioning validation must test **capability**, not only existence.

---

# 59. Host Readiness Model

The final host readiness state can be modeled as:

```text
Host Readiness
│
├── OS Ready
│
├── Docker Ready
│
├── Deployment Runtime Ready
│
├── CI/CD Ready
│
├── Security Ready
│
└── Observability Foundation Ready
```

Only when these conditions converge should the host be considered ready for application deployment.

---

# 60. Operational Ownership

The provisioning architecture creates several ownership boundaries.

| Area                            | Primary Owner                   |
| ------------------------------- | ------------------------------- |
| OS prerequisites                | Ansible / `base`                |
| Docker runtime                  | Ansible / `docker`              |
| Deployment filesystem           | Ansible / `deploy_runtime`      |
| Deployment scripts              | Deployment layer                |
| Application release             | CI/CD / deployment layer        |
| GitHub runner                   | Ansible / `github_runner`       |
| Firewall                        | Ansible / `security_baseline`   |
| SSH hardening                   | Ansible / `security_baseline`   |
| Application runtime reliability | Application runtime             |
| Application data                | Application / persistence layer |
| Metrics collection              | Observability stack             |
| Incident handling               | Operations layer                |

The purpose of this table is to prevent responsibility leakage between layers.

---

# 61. Security Considerations

Host provisioning is a privileged operation.

Ansible has the ability to modify:

```text
System packages
System services
Firewall
SSH configuration
Filesystem ownership
Docker
CI/CD execution infrastructure
```

Therefore the provisioning code should be treated as privileged infrastructure code.

Changes should be:

```text
Version controlled
Reviewed
Tested
Validated
Traceable
```

Sensitive configuration should remain protected.

---

# 62. Principle: Infrastructure Before Workload

The provisioning architecture follows:

```text
Infrastructure
      ↓
Execution Environment
      ↓
Application Workload
```

rather than attempting to deploy the application onto an incompletely prepared host.

This provides a stable boundary:

```text
Host Provisioning
        │
        └── "Can this host run Mini-Write?"

Deployment
        │
        └── "Which application version should run?"

Runtime
        │
        └── "How should that application behave?"

Operations
        │
        └── "Is the running system healthy?"
```

---

# 63. Principle: Provisioning Must Be Repeatable

A host should not depend on undocumented manual configuration.

The desired lifecycle is:

```text
Known Host
    +
Known IaC
    +
Known Variables
    +
Protected Secrets
    │
    ▼
Repeatable Provisioning
```

If an infrastructure requirement cannot be reproduced through the provisioning system, it should be treated as a potential infrastructure documentation or automation gap.

---

# 64. Principle: State Must Have an Owner

Every important host artifact should have a clear owner.

For example:

```text
Docker installation
    → Ansible

Deployment state
    → Deployment system

Application data
    → Persistence layer

Observability data
    → Observability services

Runner registration
    → GitHub Runner provisioning
```

Ambiguous ownership creates destructive automation risks.

The most important rule is:

> **Automation should not overwrite state it does not own.**

---

# 65. Provisioning as a Contract

The host provisioning system can ultimately be understood as an executable contract:

```text
Given:
    A supported Ubuntu staging host
    +
    Required variables
    +
    Protected credentials

Provision:

    Base OS prerequisites
    +
    Docker
    +
    Deployment Runtime
    +
    CI/CD Runner
    +
    Security Baseline
    +
    Observability Configuration

Then verify:

    Required resources exist
    +
    Required services are active
    +
    Required permissions are correct
    +
    Required operational dependencies are available
```

The result is:

```text
Mini-Write Staging Host
        │
        ▼
Ready for Deployment
```

---

# 66. End-to-End Provisioning Flow

The complete lifecycle is:

```text
                    ┌─────────────────────┐
                    │   Ubuntu Host       │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Base Preparation  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Docker Runtime    │
                    └──────────┬──────────┘
                               │
                               ▼
                 ┌─────────────────────────────┐
                 │   Deployment Runtime        │
                 │                             │
                 │ Compose                     │
                 │ Nginx                       │
                 │ Scripts                     │
                 │ Runtime Modules             │
                 │ State                       │
                 │ Environment                 │
                 │ Logs                        │
                 │ Metrics                     │
                 │ Observability Configuration │
                 └──────────────┬──────────────┘
                                │
                                ▼
                    ┌─────────────────────┐
                    │   GitHub Runner     │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │  Security Baseline  │
                    │                     │
                    │ UFW                 │
                    │ SSH Hardening       │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Validation        │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Staging Host Ready  │
                    └─────────────────────┘
```

---

# 67. Definition of a Provisioned Host

A Mini-Write host should not be described as "provisioned" merely because Ansible completed without a fatal task error.

A stronger definition is:

```text
Provisioned Host =
    Required infrastructure exists
    AND
    Required configuration is valid
    AND
    Required services are active
    AND
    Required permissions are correct
    AND
    Required downstream dependencies are satisfied
```

This is the operational meaning of provisioning in Mini-Write.

---

# 68. Relationship to the Infrastructure Layer

Host provisioning is one component of the broader infrastructure architecture.

The relationship is:

```text
Infrastructure Architecture
          │
          ├── Infrastructure as Code
          │       │
          │       └── Ansible
          │
          ├── Host Provisioning
          │       │
          │       └── This Document
          │
          ├── Docker
          │
          ├── Security Baseline
          │
          └── Infrastructure Operations
```

The host provisioning document therefore describes the **execution lifecycle**, while the other infrastructure documents describe the individual architectural mechanisms.

---

# 69. Summary

Mini-Write host provisioning transforms a prepared Ubuntu machine into a staging host capable of supporting the project's deployment and operational architecture.

The provisioning sequence is:

```text
Base
  ↓
Docker
  ↓
Deployment Runtime
  ↓
GitHub Runner
  ↓
Security Baseline
  ↓
Validation
```

The resulting host provides:

```text
Operating System Foundation
Container Runtime
Deployment Filesystem
Deployment Configuration
CI/CD Execution
Security Controls
Observability Configuration
```

The architecture intentionally separates:

```text
Host Provisioning
        from
Application Deployment
        from
Application Runtime
        from
Operations
```

The core principle is:

> **Host provisioning establishes a reproducible, validated execution environment; it does not become the owner of application release logic, application runtime behavior, or persistent workload state.**

A properly provisioned host is therefore not simply a machine on which Docker happens to be installed. It is a **validated infrastructure platform with explicit runtime, deployment, CI/CD, security, and observability contracts**.

```
```
