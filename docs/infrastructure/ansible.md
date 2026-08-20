# Ansible

## 1. Purpose

This document describes the **Ansible implementation** used by Mini-Write to provision and maintain the infrastructure defined by the project.

Where [`infrastructure-as-code.md`](./infrastructure-as-code.md) explains the broader IaC architecture and its engineering principles, this document focuses specifically on **how Ansible is structured and executed** within the repository.

The objective is to make the Ansible implementation understandable to an engineer who needs to:

- locate the provisioning entry point;
- understand the role structure;
- understand role responsibilities;
- follow provisioning dependencies;
- understand how variables and templates are used;
- understand how secrets are handled;
- execute the playbook;
- validate its behavior;
- troubleshoot provisioning failures;
- modify the infrastructure without violating its architecture.

---

# 2. Ansible's Role in Mini-Write

Ansible is the configuration and provisioning engine for the Mini-Write staging host.

The architectural relationship is:

```text
Mini-Write Repository
        │
        ▼
   Ansible Code
        │
        ├── Playbooks
        ├── Roles
        ├── Templates
        ├── Variables
        └── Secrets
        │
        ▼
   Staging Host
        │
        ├── Base OS
        ├── Docker
        ├── Deployment Runtime
        ├── GitHub Actions Runner
        └── Security Baseline
````

Ansible therefore sits between the **version-controlled infrastructure definition** and the **actual host state**.

It is not responsible for application business logic and is not the application deployment mechanism itself.

---

# 3. Repository Location

The Ansible implementation is located under:

```text
infra/ansible/
```

The principal structure is:

```text
infra/
└── ansible/
    ├── playbooks/
    │   └── site.yml
    │
    ├── roles/
    │   ├── base/
    │   ├── docker/
    │   ├── deploy_runtime/
    │   ├── github_runner/
    │   └── security_baseline/
    │
    └── vault/
        └── staging-secrets.yml
```

This structure separates:

```text
Orchestration
    │
    └── playbooks/

Implementation
    │
    └── roles/

Sensitive Configuration
    │
    └── vault/
```

---

# 4. Ansible Architecture

The implementation follows the standard Ansible concept of using a playbook to orchestrate independently scoped roles.

The execution model is:

```text
site.yml
   │
   ├── base
   │
   ├── docker
   │
   ├── deploy_runtime
   │
   ├── github_runner
   │
   └── security_baseline
```

Each role owns a specific infrastructure concern.

The playbook determines **which capabilities are applied and in what order**.

The roles determine **how those capabilities are implemented**.

This distinction is important because it prevents `site.yml` from becoming a monolithic provisioning script.

---

# 5. Main Playbook

The main provisioning entry point is:

```text
infra/ansible/playbooks/site.yml
```

Its conceptual responsibility is:

```text
Define Target
      │
      ▼
Load Environment Configuration
      │
      ▼
Apply Infrastructure Roles
      │
      ▼
Produce Provisioned Host
```

The playbook targets the `staging` inventory group and uses privilege escalation:

```yaml
- name: Provision Mini-Write staging host
  hosts: staging
  become: true
```

This means the playbook represents the provisioning contract for the staging infrastructure.

---

# 6. Privilege Model

The playbook uses:

```yaml
become: true
```

because several infrastructure operations require root privileges.

Examples include:

* package installation;
* Docker installation;
* system service configuration;
* filesystem creation under protected paths;
* UFW configuration;
* SSH configuration.

The resulting privilege model is:

```text
Ansible
    │
    ▼
Privilege Escalation
    │
    ▼
Root-level Host Configuration
```

This should not be confused with the runtime identity of the application or GitHub Actions runner.

The runner operates under the deployment user, while Ansible is capable of configuring the host with elevated privileges.

---

# 7. Environment Configuration

The staging playbook loads sensitive environment-specific configuration from:

```text
infra/ansible/vault/staging-secrets.yml
```

The playbook therefore separates:

```text
Infrastructure Logic
```

from:

```text
Environment-Specific Secrets
```

The conceptual model is:

```text
Role / Playbook
       │
       ├── Normal Variables
       │
       └── Sensitive Variables
                 │
                 ▼
          Protected Configuration
```

Secrets should not be embedded directly inside tasks, templates, or source-controlled configuration files.

---

# 8. Role Execution Order

The current execution order is:

```text
1. base
       │
       ▼
2. docker
       │
       ▼
3. deploy_runtime
       │
       ▼
4. github_runner
       │
       ▼
5. security_baseline
```

This order represents infrastructure dependencies.

It should therefore be treated as an architectural decision rather than an arbitrary ordering of tasks.

---

# 9. Role Dependency Model

The dependency chain can be expressed as:

```text
                    base
                     │
                     ▼
                   docker
                     │
                     ▼
              deploy_runtime
                     │
                     ▼
               github_runner
                     │
                     ▼
             security_baseline
```

The practical interpretation is:

### `base`

Provides the operating-system prerequisites.

### `docker`

Provides the container execution environment.

### `deploy_runtime`

Creates the deployment filesystem and runtime configuration.

### `github_runner`

Provides the CI/CD execution agent that depends on the host and Docker environment.

### `security_baseline`

Applies the host security controls.

---

# 10. `base` Role

The `base` role prepares the underlying Ubuntu host.

Its responsibility is deliberately narrow:

```text
Operating System Preparation
```

The role handles foundational package-management tasks, including:

```text
APT package index
System package upgrade
Required base packages
```

Conceptually:

```text
Ubuntu Host
     │
     ▼
APT Preparation
     │
     ▼
System Packages
     │
     ▼
Base Host Ready
```

The role should not become responsible for application deployment or application runtime configuration.

---

# 11. `docker` Role

The `docker` role establishes the Docker runtime required by Mini-Write.

Its responsibility includes:

```text
Docker Repository
Docker Package Installation
Docker Service
Docker User Access
```

The sequence is:

```text
Docker Repository
       │
       ▼
Docker Packages
       │
       ▼
Docker Service
       │
       ▼
Deployment User
       │
       ▼
Docker Access
```

The role therefore establishes the container execution foundation used by later infrastructure components.

---

# 12. Docker Repository Setup

The Docker role configures the Docker package repository and its signing key.

The Ubuntu release is determined dynamically using:

```text
{{ ansible_distribution_release }}
```

This avoids coupling the repository declaration to a hard-coded Ubuntu release.

The package trust chain is represented by the Docker keyring under:

```text
/etc/apt/keyrings/
```

The resulting flow is:

```text
Ubuntu
  │
  ▼
APT Keyring
  │
  ▼
Docker Repository
  │
  ▼
Docker Packages
```

---

# 13. Docker Service

After installation, the Docker service is configured to be:

```text
enabled
started
```

This ensures Docker is available after provisioning and remains available after host reboot.

The operational dependency is:

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
Mini-Write Containers
```

---

# 14. Docker Group Access

The deployment user is added to the Docker group.

This is important because the GitHub Actions runner operates using the deployment user.

The relationship is:

```text
deploy_user
     │
     ▼
docker group
     │
     ▼
Docker CLI
     │
     ▼
Deployment / CI Jobs
```

The Ansible implementation subsequently validates this membership.

This converts an assumed dependency into a checked infrastructure contract.

---

# 15. Check Mode Handling

The Docker role distinguishes between configuration inspection and actual host modification.

Operations such as package installation and service manipulation are guarded against execution in Ansible check mode where required.

The conceptual distinction is:

```text
--check
   │
   └── Determine intended changes

Normal execution
   │
   └── Apply changes
```

Check mode is therefore treated as a validation mechanism rather than as a second execution path.

---

# 16. `deploy_runtime` Role

The `deploy_runtime` role prepares the filesystem and configuration consumed by deployment.

Its responsibilities include:

```text
Deployment Root
Deployment Directories
Metrics Directory
Runtime Modules
Docker Compose Configuration
Nginx Configuration
Deployment Scripts
Deployment State
Environment Configuration
Deployment Logs
Observability Configuration
```

Its architectural role is:

```text
Provisioned Host
      │
      ▼
Deployment Runtime Contract
      │
      ├── Filesystem
      ├── Configuration
      ├── State
      ├── Scripts
      └── Observability
```

---

# 17. Deployment Root

The role creates the configured deployment root:

```text
{{ deploy_root }}
```

The root directory is managed explicitly by Ansible.

The intended ownership model is:

```text
root:root
0755
```

This establishes the top-level deployment filesystem as infrastructure-controlled state.

---

# 18. Deployment Directories

The role creates the configured deployment directories through:

```text
{{ deploy_directories }}
```

It also creates specialized directories for:

```text
metrics
scripts/{{ runtime_subdirectory }}
```

The resulting structure is conceptually:

```text
deploy_root/
├── deployment directories
├── metrics/
├── scripts/
│   └── runtime/
├── env/
├── logs/
└── state/
```

The exact directory set is controlled by the Ansible configuration rather than being manually established on the host.

---

# 19. Ownership Model

The deployment runtime distinguishes between infrastructure-controlled files and runtime-modifiable state.

The general model is:

```text
Infrastructure-Controlled
        │
        └── root:root

Runtime / Deployment State
        │
        └── deploy_user:deploy_user
```

This prevents the deployment process from automatically owning every infrastructure configuration file.

It also establishes a clearer security boundary between:

```text
Infrastructure Configuration
```

and:

```text
Operational State
```

---

# 20. Configuration Templates

The `deploy_runtime` role uses Jinja2 templates to generate environment-specific configuration.

Important examples include:

```text
docker-compose.staging.yml.j2
nginx.conf.j2
deployment_state.json.j2
env.staging.j2
```

The template pipeline is:

```text
Jinja2 Template
      +
Ansible Variables
      │
      ▼
Rendered Configuration
      │
      ▼
Deployment Host
```

This allows one infrastructure implementation to produce configuration appropriate to the staging environment.

---

# 21. Docker Compose Template

The staging Compose configuration is rendered from:

```text
docker-compose.staging.yml.j2
```

The resulting configuration is placed under the deployment runtime.

This means the Docker Compose topology is not treated as a manually maintained host artifact.

Instead:

```text
Repository
    │
    ▼
Compose Template
    │
    ▼
Ansible
    │
    ▼
Rendered Compose Configuration
```

The resulting configuration becomes part of the provisioned host state.

---

# 22. Deployment State

The deployment runtime initializes deployment state from:

```text
deployment_state.json.j2
```

The initial state contains:

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

Ansible first checks whether the state file already exists.

The behavior is therefore:

```text
State Exists?
     │
 ┌───┴────┐
 │        │
Yes       No
 │         │
Skip      Initialize
```

This avoids overwriting deployment state during subsequent provisioning runs.

---

# 23. Environment Configuration

The staging environment file is generated from:

```text
env.staging.j2
```

The role checks whether the target file already exists before initializing it.

The initial file permissions are restricted:

```text
0640
```

This is important because environment files may contain sensitive configuration.

The provisioning lifecycle therefore includes both:

```text
Configuration Creation
```

and:

```text
Configuration Protection
```

---

# 24. Deployment Logging

The role ensures that the deployment log exists under the deployment root:

```text
{{ deploy_root }}/logs/deploy.log
```

The log is owned by:

```text
deploy_user:deploy_user
```

This provides a stable location for deployment logging and creates a filesystem contract consumed by the deployment and observability layers.

---

# 25. Observability Synchronization

The `deploy_runtime` role also synchronizes the project's observability configuration into the deployment environment.

This includes the configuration required by the monitoring stack.

The relationship is:

```text
Repository
    │
    ▼
observability/
    │
    ▼
Ansible
    │
    ▼
Deployment Runtime
    │
    ▼
Observability Services
```

This makes observability configuration part of the reproducible infrastructure state.

---

# 26. `github_runner` Role

The `github_runner` role manages the GitHub Actions self-hosted runner.

Its responsibilities include:

```text
Runner Dependencies
Runner Installation Directory
Runner Archive
Runner Extraction
Runner Ownership
Runner Registration
Runner Service
Runner Validation
```

The architectural purpose is to turn the provisioned host into a CI/CD execution environment.

```text
Provisioned Host
       │
       ▼
GitHub Actions Runner
       │
       ▼
CI/CD Jobs
       │
       ▼
Deployment
```

---

# 27. Runner Installation State

The role detects whether the runner is already installed by checking for:

```text
{{ github_runner_install_dir }}/run.sh
```

If the runner is already present, installation is skipped.

Otherwise:

```text
Download
   │
   ▼
Extract
   │
   ▼
Set Ownership
```

This prevents repeated installation during normal provisioning.

---

# 28. Runner Registration State

Runner registration is represented by:

```text
{{ github_runner_install_dir }}/.runner
```

The role checks this state before attempting registration.

The flow is:

```text
.runner exists?
       │
   ┌───┴───┐
   │       │
  Yes      No
   │        │
 Skip    Obtain Token
            │
            ▼
       Register Runner
```

This is important because registration is an external side effect and should not be repeated unnecessarily.

---

# 29. GitHub Registration Token

Runner registration requires communication with the GitHub API.

The role uses a GitHub Personal Access Token to obtain the runner registration token.

Sensitive registration operations use:

```yaml
no_log: true
```

to prevent sensitive values from being exposed through Ansible task output.

The security model is:

```text
Protected GitHub Credential
          │
          ▼
      Ansible
          │
          ▼
GitHub Registration Token
          │
          ▼
   Runner Registration
```

---

# 30. Runner Service

After registration, the runner is installed as a system service.

The intended service state is:

```text
enabled
started
```

This provides persistence across host restarts.

The resulting lifecycle is:

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
GitHub Actions
```

---

# 31. Runner Validation

The role validates several dependencies after configuration.

The validation includes:

```text
Docker group membership
Deployment runtime directories
Runner service status
```

The purpose is to ensure that:

```text
Runner Installed
```

is not incorrectly interpreted as:

```text
Runner Operational
```

A CI/CD runner that cannot access Docker or the deployment filesystem is not a valid execution environment.

---

# 32. `security_baseline` Role

The `security_baseline` role establishes host-level security controls.

Its primary responsibilities are:

```text
UFW
SSH Hardening
Security Configuration Validation
```

The security model is:

```text
Host
  │
  ├── Firewall
  │     └── UFW
  │
  └── SSH
        └── Hardened Configuration
```

---

# 33. UFW Policy

The firewall uses:

```text
Default Incoming: DENY
Default Outgoing: ALLOW
```

Required ports are explicitly allowed through:

```text
{{ security_allowed_tcp_ports }}
```

The resulting model is:

```text
Incoming Traffic
       │
       ▼
      UFW
       │
       ├── Allowed
       │
       └── Denied
```

This establishes an allowlist-oriented host boundary.

---

# 34. SSH Hardening

The security role deploys an SSH hardening configuration under:

```text
/etc/ssh/sshd_config.d/99-miniwrite-hardening.conf
```

The configuration is rendered from:

```text
sshd_config.j2
```

The template controls settings such as:

```text
PasswordAuthentication
PermitRootLogin
PubkeyAuthentication
PermitEmptyPasswords
```

The actual values are driven by Ansible configuration.

---

# 35. SSH Configuration Validation

The SSH configuration is validated before it is accepted.

The validation command is:

```text
/usr/sbin/sshd -t -f %s
```

The configuration lifecycle is therefore:

```text
Generate Configuration
        │
        ▼
sshd Syntax Validation
        │
     ┌──┴──┐
     │     │
   Valid Invalid
     │     │
     ▼     ▼
 Install Reject
```

This prevents an invalid SSH configuration from silently replacing the intended host configuration.

---

# 36. Role Boundaries

The five roles intentionally have separate ownership.

| Role                | Owns                                    |
| ------------------- | --------------------------------------- |
| `base`              | Base operating-system preparation       |
| `docker`            | Docker runtime                          |
| `deploy_runtime`    | Deployment filesystem and configuration |
| `github_runner`     | CI/CD runner                            |
| `security_baseline` | Host security controls                  |

A role should not absorb unrelated responsibilities simply because another capability depends on it.

For example:

```text
docker
```

should not become responsible for:

```text
UFW
SSH
GitHub registration
Application deployment
```

This keeps the infrastructure maintainable.

---

# 37. Variables

The Ansible implementation relies on variables to separate infrastructure logic from environment-specific values.

Important conceptual variables include:

```text
deploy_root
deploy_directories
runtime_subdirectory
deploy_user
security_allowed_tcp_ports
github_runner_install_dir
```

Additional variables are used for environment-specific and sensitive configuration.

The principle is:

```text
Role Logic
    │
    ▼
Variables
    │
    ▼
Environment-Specific State
```

The role should therefore avoid embedding environment-specific values directly into tasks whenever those values can be represented as variables.

---

# 38. Templates and Variables

Variables and templates work together.

For example:

```text
deploy_root
     │
     ▼
docker-compose.staging.yml.j2
     │
     ▼
Rendered Compose Configuration
```

Likewise:

```text
security variables
       │
       ▼
sshd_config.j2
       │
       ▼
Rendered SSH Configuration
```

This creates a reusable configuration mechanism without duplicating the role implementation.

---

# 39. Secrets

Sensitive variables are separated from ordinary infrastructure configuration.

The staging playbook references:

```text
../vault/staging-secrets.yml
```

This provides a dedicated boundary for sensitive values.

The architecture is:

```text
Non-sensitive IaC
       │
       ├── Roles
       ├── Tasks
       └── Templates

Sensitive Configuration
       │
       └── Vault
```

Sensitive values should not be copied into ordinary task definitions or committed as plaintext configuration.

---

# 40. State-Aware Execution

Several Ansible tasks inspect the current host state before performing initialization.

The common pattern is:

```text
stat
  │
  ▼
State Exists?
  │
  ├── Yes → Preserve Existing State
  │
  └── No  → Initialize
```

This pattern is used for stateful artifacts such as:

```text
Runner installation
Runner registration
Deployment state
Environment configuration
Deployment logs
```

It is particularly important for artifacts whose contents represent operational history.

---

# 41. Idempotency

The target behavior of the roles is idempotent convergence.

For a desired state `D` and actual state `A`:

```text
A ≠ D
   │
   ▼
Ansible applies required changes
   │
   ▼
A → D
```

When:

```text
A = D
```

subsequent execution should result in minimal or no changes.

This is why Ansible state-oriented modules such as:

```text
apt
file
template
copy
systemd
stat
```

are preferred over uncontrolled shell scripting.

---

# 42. Conditional Commands

Some operations cannot be represented purely as declarative resource state.

GitHub runner registration is one example.

Registration is an external side effect:

```text
GitHub API
     │
     ▼
Registration
```

The implementation therefore protects the operation with state detection.

The important property is not:

```text
"No command modules are ever used."
```

The important property is:

```text
"Imperative operations are executed only under controlled conditions."
```

---

# 43. Validation Layer

Ansible execution includes explicit validation.

Validation occurs at multiple levels:

```text
Configuration
     │
     ▼
Task Execution
     │
     ▼
Assertions
     │
     ▼
Service State
     │
     ▼
Infrastructure Readiness
```

Examples include:

```text
SSH configuration syntax
Docker group membership
Deployment directory existence
Runner service status
```

This makes validation part of provisioning rather than an entirely separate manual activity.

---

# 44. Assertions as Infrastructure Contracts

Assertions convert assumptions into executable checks.

For example:

```text
deploy_user ∈ docker group
```

is verified explicitly.

Likewise:

```text
deployment runtime directories exist
```

is checked after provisioning.

This produces a stronger guarantee than simply assuming that previous tasks succeeded.

---

# 45. Provisioning Lifecycle

The complete Ansible lifecycle is:

```text
1. Load Playbook
       │
       ▼
2. Resolve Variables
       │
       ▼
3. Load Protected Configuration
       │
       ▼
4. Execute Roles
       │
       ▼
5. Validate Infrastructure
       │
       ▼
6. Report Result
```

The host is considered provisioned only when the expected infrastructure contracts have been satisfied.

---

# 46. Operational Execution Model

An engineer should conceptually think of execution as:

```text
Desired Infrastructure
        │
        ▼
site.yml
        │
        ▼
Role Sequence
        │
        ▼
Tasks
        │
        ▼
Host Changes
        │
        ▼
Validation
```

The important distinction is that Ansible is not simply running a sequence of shell commands.

It is attempting to reconcile the host with the infrastructure definition.

---

# 47. Failure Localization

Ansible's role separation also helps localize provisioning failures.

Examples:

### Failure in `base`

Investigate:

```text
APT
Ubuntu packages
Repository connectivity
Host OS
```

### Failure in `docker`

Investigate:

```text
Docker repository
GPG key
Package installation
Docker service
User group membership
```

### Failure in `deploy_runtime`

Investigate:

```text
Variables
Templates
Filesystem
Permissions
Configuration rendering
```

### Failure in `github_runner`

Investigate:

```text
GitHub API
Credentials
Runner archive
Registration
systemd
Docker access
```

### Failure in `security_baseline`

Investigate:

```text
UFW
SSH configuration
SSH validation
Required ports
```

This makes the role boundaries useful during incident diagnosis as well as development.

---

# 48. Re-running Ansible

The infrastructure should be safe to re-run as part of normal convergence.

A subsequent run should:

```text
Inspect Current State
       │
       ▼
Identify Drift
       │
       ▼
Apply Required Changes
       │
       ▼
Preserve State Where Appropriate
       │
       ▼
Validate
```

Operational state such as deployment history should not be unnecessarily overwritten.

---

# 49. Configuration Drift

If the host is manually modified, the resulting state can diverge from the repository.

```text
Repository
   │
   └── Desired State

Host
   │
   └── Actual State
```

When:

```text
Desired ≠ Actual
```

configuration drift exists.

The preferred remediation is:

```text
Detect Drift
     │
     ▼
Determine Intended State
     │
     ▼
Update IaC if required
     │
     ▼
Re-run Ansible
     │
     ▼
Validate
```

Permanent infrastructure changes should therefore be represented in the repository.

---

# 50. Ansible and Deployment

Ansible and application deployment have different responsibilities.

```text
Ansible
   │
   └── Prepare Infrastructure

Deployment
   │
   └── Deploy Application Version
```

Ansible establishes the environment required for deployment, including:

```text
Docker
Deployment directories
Configuration
Runner
Logs
Observability
Security
```

The deployment layer subsequently uses that environment to perform application release operations.

This boundary should remain explicit.

---

# 51. Ansible and Runtime

The deployment runtime created by Ansible is consumed by the application deployment system.

Therefore:

```text
Ansible
   │
   ▼
Deployment Runtime
   │
   ▼
Deployment Automation
   │
   ▼
Application Runtime
```

Ansible does not own the application's runtime reliability behavior.

That belongs to the application and runtime architecture documented elsewhere.

---

# 52. Ansible and Observability

Ansible also establishes the configuration required for the observability stack.

The relationship is:

```text
Ansible
   │
   ▼
Observability Configuration
   │
   ▼
Prometheus / Loki / Grafana / Alertmanager
   │
   ▼
Infrastructure Signals
```

This means infrastructure provisioning and observability are connected without making Ansible responsible for observability analysis itself.

---

# 53. Security Boundary

Ansible is a privileged infrastructure control mechanism.

Consequently:

```text
Ansible Credentials
        +
Repository Access
        +
Vault Secrets
        +
SSH Access
```

should be treated as part of the infrastructure security boundary.

Compromise of the Ansible execution environment can result in host-level compromise.

Therefore infrastructure changes should be reviewable and secrets should be protected.

---

# 54. Recommended Change Workflow

Infrastructure modifications should follow:

```text
Understand Existing Role
        │
        ▼
Identify Correct Ownership
        │
        ▼
Modify Variables / Task / Template
        │
        ▼
Validate Syntax
        │
        ▼
Run Check Mode Where Applicable
        │
        ▼
Apply
        │
        ▼
Validate Host State
        │
        ▼
Review Result
```

The key rule is to modify the role that owns the behavior instead of introducing unrelated changes into another role.

---

# 55. Adding a New Infrastructure Capability

A new capability should first be classified.

For example:

```text
New Host Package
      → base

New Container Runtime Configuration
      → docker

New Deployment Filesystem
      → deploy_runtime

New CI/CD Capability
      → github_runner

New Host Security Control
      → security_baseline
```

If the capability does not clearly belong to any existing role, its architectural boundary should be evaluated before adding it.

The goal is to preserve coherent role ownership rather than maximize the number of roles.

---

# 56. What Should Not Be Added to `site.yml`

`site.yml` should remain an orchestration layer.

It should not become a location for:

```text
Large shell scripts
Complex application logic
Detailed Docker configuration
SSH implementation
Firewall implementation
Runner registration logic
Deployment workflow logic
```

Those concerns belong in their respective roles.

The desired structure is:

```text
site.yml
   │
   └── "What capabilities should run?"

roles/
   │
   └── "How is each capability implemented?"
```

---

# 57. Ansible as a Convergence Engine

The most useful mental model for the Mini-Write implementation is:

```text
Ansible ≠ Installation Script

Ansible = Desired-State Convergence Mechanism
```

The implementation continuously expresses:

```text
This host should have:
    Docker
    Deployment Runtime
    Runner
    Security Baseline
```

and Ansible performs the work required to bring the actual host toward that state.

---

# 58. Reproducibility Boundary

The Ansible implementation provides reproducibility for the host configuration represented by the repository.

It does not automatically guarantee recovery of:

```text
Persistent application data
Database contents
Object storage contents
Historical deployment artifacts
```

Therefore:

```text
Infrastructure Reproducibility
          ≠
Complete Disaster Recovery
```

The distinction is important for operational planning.

---

# 59. Current Implementation Characteristics

The current Ansible implementation provides:

```text
Role separation
Version-controlled configuration
Jinja2 templating
State detection
Conditional initialization
Privilege escalation
Secret separation
Service management
Configuration validation
Assertions
Docker provisioning
CI/CD runner provisioning
Host security configuration
Observability configuration deployment
```

These capabilities establish the current infrastructure provisioning foundation of Mini-Write.

---

# 60. Summary

Mini-Write uses a single Ansible provisioning entry point:

```text
infra/ansible/playbooks/site.yml
```

which orchestrates five bounded infrastructure roles:

```text
base
docker
deploy_runtime
github_runner
security_baseline
```

The execution order is:

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

The roles are responsible for progressively establishing:

```text
Operating System
      ↓
Docker Runtime
      ↓
Deployment Runtime
      ↓
CI/CD Execution Environment
      ↓
Host Security Baseline
```

The implementation uses Ansible's state-oriented modules, conditional initialization, templates, protected configuration, assertions, and service validation to move the host toward a known desired state.

The resulting operational model is:

```text
Infrastructure Definition
        │
        ▼
      Ansible
        │
        ▼
   Role Execution
        │
        ▼
   Host Convergence
        │
        ▼
    Validation
        │
        ▼
 Infrastructure Ready
```

The critical architectural principle is:

> **Ansible defines and converges the infrastructure; it does not replace the deployment, application runtime, reliability, or operations layers.**

This separation keeps the infrastructure automation understandable, reviewable, and maintainable as Mini-Write evolves.

```
```
