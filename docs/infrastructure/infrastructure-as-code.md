# Infrastructure as Code

## 1. Purpose

This document describes the **Infrastructure as Code (IaC)** architecture used by Mini-Write.

It explains how the infrastructure is represented, organized, provisioned, validated, and maintained through version-controlled configuration.

The primary IaC technology used by Mini-Write is **Ansible**.

The purpose of the IaC layer is not merely to automate installation commands.

It establishes a reproducible infrastructure state in which:

- the host can be provisioned consistently;
- required infrastructure components are installed deterministically;
- deployment directories and runtime state are created explicitly;
- security controls are applied consistently;
- the GitHub Actions self-hosted runner is configured;
- Docker and its supporting configuration are established;
- infrastructure changes can be reviewed through source control;
- infrastructure behavior can be reproduced after host loss or rebuild.

---

# 2. Infrastructure as Code Philosophy

Mini-Write treats infrastructure configuration as an engineering artifact.

The intended model is:

```text
Infrastructure Requirement
        │
        ▼
Infrastructure Code
        │
        ▼
Version Control
        │
        ▼
Validation
        │
        ▼
Ansible Execution
        │
        ▼
Host State
        │
        ▼
Operational Verification
````

The infrastructure should therefore not depend on undocumented manual commands.

A manually configured host may represent the current state of the environment, but it is not the authoritative definition of that environment.

The authoritative definition belongs in the repository.

---

# 3. Why Ansible

The current Mini-Write infrastructure is centered around an existing Linux virtual machine.

The primary infrastructure problem is therefore:

```text
Configure and maintain an existing host
```

rather than:

```text
Provision a fleet of cloud resources
```

The current environment requires management of:

* Ubuntu host configuration;
* system packages;
* Docker;
* deployment directories;
* deployment configuration;
* GitHub Actions runner;
* host security baseline;
* runtime filesystem state.

Ansible is therefore a natural fit for the current infrastructure boundary.

---

# 4. Current IaC Boundary

The current Infrastructure as Code boundary is:

```text
                    Ansible
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Host         Runtime       Security
    Provisioning   Preparation     Baseline
          │            │            │
          └────────────┼────────────┘
                       ▼
                  Ready Host
```

Ansible does not own application business logic.

It prepares the execution environment in which the application is deployed.

---

# 5. Repository Structure

The Ansible implementation is organized under:

```text
infra/ansible/
```

The important structure is:

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

The exact supporting files and variable definitions may evolve, but the architectural separation remains:

```text
Playbook
   │
   ▼
Roles
   │
   ├── Base
   ├── Docker
   ├── Deployment Runtime
   ├── GitHub Runner
   └── Security Baseline
```

---

# 6. Entry Point

The main provisioning entry point is:

```text
infra/ansible/playbooks/site.yml
```

Its responsibility is orchestration.

The playbook currently defines:

```yaml
- name: Provision Mini-Write staging host
  hosts: staging
  become: true
```

The target infrastructure environment is therefore represented by the `staging` inventory group.

The playbook also loads staging secrets through:

```yaml
vars_files:
  - ../vault/staging-secrets.yml
```

This establishes a separation between:

```text
Infrastructure Logic
```

and:

```text
Environment-Specific Sensitive Configuration
```

---

# 7. Playbook Responsibility

`site.yml` should remain an orchestration layer.

It defines **what infrastructure capabilities are applied and in what order**.

It should not become a large collection of implementation tasks.

The current role sequence is:

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

This sequence is significant because later roles depend on infrastructure established by earlier roles.

---

# 8. Provisioning Dependency Order

The current role order establishes the following dependency model:

```text
Base Host
    │
    ▼
Docker Runtime
    │
    ▼
Deployment Runtime
    │
    ▼
GitHub Runner
    │
    ▼
Security Baseline
```

The dependency relationships are not arbitrary.

For example:

* the Docker role requires a functioning base host;
* the deployment runtime assumes the host is prepared;
* the GitHub runner requires deployment infrastructure and Docker access;
* security hardening is applied after the required host configuration has been established.

This means the playbook represents an infrastructure dependency graph, not merely a list of unrelated tasks.

---

# 9. Role Architecture

Each role represents a bounded infrastructure responsibility.

```text
roles/
│
├── base/
│
├── docker/
│
├── deploy_runtime/
│
├── github_runner/
│
└── security_baseline/
```

The intended ownership model is:

| Role                | Primary Responsibility                          |
| ------------------- | ----------------------------------------------- |
| `base`              | Base operating-system preparation               |
| `docker`            | Docker runtime installation and configuration   |
| `deploy_runtime`    | Deployment filesystem and runtime configuration |
| `github_runner`     | GitHub Actions self-hosted runner               |
| `security_baseline` | Host security baseline                          |

This separation prevents infrastructure logic from collapsing into a single provisioning script.

---

# 10. Base Role

The `base` role establishes the baseline operating-system environment.

Its current tasks include:

```text
Update apt package index
Upgrade installed packages
Install base system packages
```

The implementation uses Ansible's `apt` module.

Conceptually:

```text
Ubuntu Host
    │
    ▼
APT Update
    │
    ▼
System Upgrade
    │
    ▼
Required Base Packages
```

The role therefore establishes prerequisites for subsequent infrastructure roles.

---

# 11. Base Role Boundary

The `base` role should be understood as:

```text
Operating System Preparation
```

rather than:

```text
Application Deployment
```

It should not own:

* application containers;
* application configuration;
* deployment state;
* GitHub runner registration;
* firewall policy.

Those concerns belong to their respective roles.

---

# 12. Docker Role

The `docker` role establishes the Docker execution environment.

Its current responsibilities include:

```text
Create Docker keyring directory
Download Docker GPG key
Configure Docker APT repository
Update APT cache
Install Docker packages
Enable and start Docker
Add deployment user to docker group
```

The flow is:

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
  │
  ▼
Docker Service
  │
  ▼
Deployment User Docker Access
```

---

# 13. Docker Repository Configuration

The Docker repository is configured using the Ubuntu distribution release dynamically:

```text
{{ ansible_distribution_release }}
```

This avoids hard-coding a specific Ubuntu release into the repository declaration.

The repository is configured with a signed keyring:

```text
/etc/apt/keyrings/
```

This provides an explicit package trust mechanism.

---

# 14. Check Mode Consideration

The Docker role explicitly avoids package installation and service manipulation during Ansible check mode:

```yaml
when: not ansible_check_mode
```

This distinction is important.

The role differentiates between:

```text
Inspect Desired Changes
```

and:

```text
Actually Modify Host
```

This supports safer infrastructure validation before applying changes.

---

# 15. Docker Access Model

The deployment user is explicitly added to the Docker group.

Conceptually:

```text
Deployment User
      │
      ▼
docker group
      │
      ▼
Docker CLI Access
      │
      ▼
Deployment Workloads
```

This is particularly important because the GitHub Actions runner executes under the deployment user.

The infrastructure therefore establishes a dependency:

```text
Docker Role
     │
     ▼
deploy_user ∈ docker
     │
     ▼
GitHub Runner
     │
     ▼
Docker Workloads
```

---

# 16. Deployment Runtime Role

The `deploy_runtime` role prepares the filesystem and configuration required by application deployment.

Its responsibilities include:

```text
Deployment root
Deployment subdirectories
Metrics directory
Runtime modules directory
Docker Compose configuration
Nginx configuration
Deployment scripts
Runtime modules
Deployment state
Staging environment file
Runtime directory ownership
Deployment log
Observability configuration
```

This role therefore creates the operational filesystem contract consumed by deployment automation.

---

# 17. Deployment Root

The role establishes:

```text
{{ deploy_root }}
```

as the deployment root.

The root directory is created with:

```text
owner: root
group: root
mode: 0755
```

This establishes the root of the deployment filesystem as an infrastructure-managed location.

---

# 18. Deployment Directory Model

The role creates deployment subdirectories using:

```text
{{ deploy_directories }}
```

Additional directories are explicitly created for:

```text
metrics
scripts/{{ runtime_subdirectory }}
```

The infrastructure therefore distinguishes between generic deployment directories and specialized runtime locations.

---

# 19. Immutable and Mutable Runtime Areas

The deployment runtime establishes an ownership boundary between immutable and mutable directories.

The architecture is:

```text
Deployment Runtime
       │
       ├── Immutable Runtime Directories
       │       │
       │       └── root:root
       │
       └── Mutable Runtime Directories
               │
               └── deploy_user:deploy_user
```

This distinction is important for operational safety.

Files that should be controlled by infrastructure remain owned by `root`.

Runtime state that must be modified by deployment processes can belong to the deployment user.

---

# 20. Configuration Deployment

The `deploy_runtime` role uses Ansible templates to generate runtime configuration.

Examples include:

```text
docker-compose.staging.yml
nginx.conf
deployment scripts
runtime modules
deployment_state.json
.env.staging
```

The model is:

```text
Repository Template
       │
       ▼
Ansible Template Module
       │
       ▼
Rendered Host Configuration
```

This allows infrastructure configuration to remain version-controlled while environment-specific values are injected during provisioning.

---

# 21. Docker Compose as Generated Infrastructure Configuration

The staging Docker Compose file is deployed through:

```text
docker-compose.staging.yml.j2
```

The resulting file is placed under the deployment root.

This means the actual runtime topology is not maintained through an undocumented manually edited file on the host.

Instead:

```text
Jinja2 Template
      │
      ▼
Ansible
      │
      ▼
Rendered Compose File
      │
      ▼
Docker Compose
```

---

# 22. Deployment State Initialization

The deployment runtime role checks whether the deployment state file exists.

If it does not exist, Ansible creates it from:

```text
deployment_state.json.j2
```

The initial structure is:

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

This establishes deployment state as a persistent infrastructure artifact.

---

# 23. Environment File Initialization

The role also checks for:

```text
{{ deploy_root }}/env/.env.staging
```

If the file does not exist, it is generated from:

```text
env.staging.j2
```

The file is initially created with restricted permissions:

```text
0640
```

The deployment runtime subsequently applies the intended ownership and permissions.

This demonstrates an important IaC principle:

```text
Configuration Creation
        +
Configuration Security
```

must both be represented in infrastructure code.

---

# 24. Deployment Logs

The role establishes:

```text
{{ deploy_root }}/logs/deploy.log
```

if the file does not already exist.

The file is owned by:

```text
deploy_user:deploy_user
```

with:

```text
0644
```

This provides a stable filesystem target for deployment logging and subsequent log collection.

---

# 25. Observability Configuration as Infrastructure

The deployment runtime also synchronizes the observability platform configuration:

```text
observability/
```

into the deployment environment.

This includes configuration consumed by the observability services.

Therefore observability infrastructure is itself part of the reproducible infrastructure state.

The conceptual model is:

```text
Repository
    │
    ▼
Observability Configuration
    │
    ▼
Ansible
    │
    ▼
Deployment Runtime
    │
    ▼
Observability Containers
```

---

# 26. GitHub Runner Role

The `github_runner` role manages the GitHub Actions self-hosted runner.

Its responsibilities include:

```text
Install runner dependencies
Create runner installation directory
Download runner archive
Extract runner
Establish ownership
Register runner
Install runner service
Enable runner service
Verify Docker access
Verify deployment runtime
Verify runner service status
```

This makes the CI/CD execution environment part of the Infrastructure as Code model.

---

# 27. Runner Installation State

The role uses filesystem state to determine whether the runner has already been installed.

It checks for:

```text
{{ github_runner_install_dir }}/run.sh
```

If the runner does not exist, Ansible downloads and extracts the archive.

This establishes a basic idempotent pattern:

```text
Runner Exists
     │
     ├── Yes ──► Skip Installation
     │
     └── No ───► Download + Extract
```

---

# 28. Runner Registration State

Runner registration is represented by:

```text
{{ github_runner_install_dir }}/.runner
```

The role checks this file before requesting a registration token.

The flow is:

```text
.runner exists?
      │
 ┌────┴────┐
 │         │
Yes        No
 │          │
Skip       Request Token
            │
            ▼
        Register Runner
```

This prevents unnecessary registration attempts on every provisioning run.

---

# 29. Secret Handling

The GitHub runner registration token is obtained through the GitHub API using a Personal Access Token.

The task uses:

```yaml
no_log: true
```

for sensitive operations.

This is important because infrastructure automation can otherwise leak credentials into Ansible output.

The broader architecture is:

```text
Sensitive Configuration
        │
        ▼
Ansible Vault / Protected Variables
        │
        ▼
Provisioning
        │
        ▼
Runtime Configuration
```

Secrets should never become ordinary repository configuration.

---

# 30. Runner Service Model

The GitHub runner is installed as a system service.

The service is:

```text
enabled
```

and:

```text
started
```

The infrastructure therefore ensures that the CI/CD execution capability is persistent across host reboots.

The lifecycle becomes:

```text
Host Boot
   │
   ▼
systemd
   │
   ▼
GitHub Runner Service
   │
   ▼
GitHub Actions Jobs
```

---

# 31. Runner Validation

The role performs explicit validation after configuring the runner.

It verifies:

```text
Docker group membership
Deployment runtime directories
Runner service status
```

For example, the role asserts that the deployment user belongs to the Docker group.

It also verifies the existence of:

```text
/opt/deploy/state
/opt/deploy/logs
/opt/deploy/env
```

This is significant because the role is not limited to configuration.

It also validates the infrastructure contract required by the runner.

---

# 32. Security Baseline Role

The `security_baseline` role establishes host-level security controls.

Its current responsibilities include:

```text
Install UFW
Set incoming default policy
Set outgoing default policy
Allow required TCP ports
Enable UFW
Deploy SSH hardening configuration
Validate SSH configuration
Enable SSH service
```

The intended security model is:

```text
Incoming
   │
   ▼
UFW
   │
   ├── Default: DENY
   │
   └── Explicitly Allowed Ports
```

---

# 33. SSH Hardening

SSH configuration is deployed using a dedicated drop-in:

```text
/etc/ssh/sshd_config.d/99-miniwrite-hardening.conf
```

The configuration is generated from:

```text
sshd_config.j2
```

The current template controls:

```text
PasswordAuthentication
PermitRootLogin
PubkeyAuthentication
PermitEmptyPasswords
```

The values are derived from Ansible variables.

---

# 34. SSH Configuration Validation

The SSH configuration is not blindly written.

The task uses:

```text
validate: "/usr/sbin/sshd -t -f %s"
```

Therefore the intended flow is:

```text
Generate Candidate Configuration
          │
          ▼
sshd -t Validation
          │
      ┌───┴───┐
      ▼       ▼
    Valid   Invalid
      │       │
      ▼       ▼
 Install    Reject
```

This is an important production-grade IaC pattern.

Configuration changes should be validated before they can damage the running service.

---

# 35. UFW Configuration

The security role explicitly configures:

```text
incoming = deny
outgoing = allow
```

Required TCP ports are then allowed from:

```text
{{ security_allowed_tcp_ports }}
```

The model is therefore:

```text
Default Deny
     │
     ▼
Explicit Allowlist
     │
     ▼
Required Services
```

This is preferable to opening arbitrary ports and relying on individual services to protect themselves.

---

# 36. Idempotency Model

A central characteristic of the IaC implementation is that tasks attempt to converge the host toward a known state.

Examples include:

### Directory creation

```text
state: directory
```

### Package installation

```text
state: present
```

### Service state

```text
enabled: true
state: started
```

### Conditional initialization

```text
when: not <state>.stat.exists
```

The general model is:

```text
Current Host State
       │
       ▼
Ansible Task
       │
       ▼
Desired State
       │
       ▼
No Change / Required Change
```

---

# 37. State Detection

The infrastructure implementation frequently uses Ansible's `stat` module before performing stateful operations.

Examples include checking:

```text
Runner installation
Runner registration
Deployment state file
Environment file
Deployment log
Runner service
```

This produces a state-aware provisioning process.

The pattern is:

```text
Inspect
  │
  ▼
Determine State
  │
  ▼
Apply Only When Necessary
```

---

# 38. Infrastructure Convergence

The desired behavior of the provisioning process is convergence.

Let:

```text
D = Desired Infrastructure State
A = Actual Host State
```

The provisioning process attempts to transform:

```text
A → D
```

If:

```text
A = D
```

then the provisioning process should perform minimal or no changes.

If:

```text
A ≠ D
```

then Ansible should apply the required changes.

This is the core operational model of the IaC system.

---

# 39. Idempotency vs One-Time Installation

Not every infrastructure operation has identical idempotency characteristics.

The implementation therefore distinguishes between:

```text
State-based modules
```

and:

```text
Conditionally executed commands
```

For example:

```text
apt
file
systemd
template
copy
stat
```

are primarily state-oriented.

Runner registration uses a command because registration is an external operation that should only occur when registration state is absent.

This distinction is important.

The objective is not to avoid all commands.

The objective is to ensure commands are executed under controlled state conditions.

---

# 40. Validation as Part of IaC

Infrastructure provisioning is not considered complete merely because Ansible finishes without a fatal error.

The current implementation contains explicit assertions and checks.

Examples include:

```text
Docker group membership
Deployment directory existence
Runner service status
SSH configuration validity
```

Therefore the infrastructure lifecycle is:

```text
Provision
   │
   ▼
Validate
   │
   ▼
Declare Infrastructure Ready
```

---

# 41. Assertions

Assertions are used to convert infrastructure assumptions into executable contracts.

For example:

```text
deploy_user must belong to docker group
```

is represented as an Ansible assertion.

Similarly:

```text
deployment runtime directories must exist
```

is validated explicitly.

This changes an assumption from:

```text
"It should exist."
```

into:

```text
"The provisioning process verifies that it exists."
```

---

# 42. Infrastructure Contracts

The current IaC system establishes several implicit infrastructure contracts.

### Contract 1

Docker must be installed and running.

### Contract 2

The deployment user must have Docker access.

### Contract 3

Deployment runtime directories must exist.

### Contract 4

The GitHub runner service must be active.

### Contract 5

SSH configuration must pass syntax validation.

### Contract 6

The host firewall must have the intended default policies.

These contracts form part of the operational foundation consumed by deployment and application layers.

---

# 43. Secrets and IaC

Infrastructure code frequently needs sensitive values.

Mini-Write separates those values from ordinary role logic.

The playbook references:

```text
../vault/staging-secrets.yml
```

The intended architectural model is:

```text
Role Logic
    │
    ├── Public / Non-sensitive Variables
    │
    └── Sensitive Variables
             │
             ▼
        Protected Secret Store
```

This allows the same role architecture to operate across environments while keeping sensitive configuration separate.

---

# 44. Template Architecture

Jinja2 templates are used where configuration must be rendered dynamically.

Examples include:

```text
docker-compose.staging.yml.j2
nginx.conf.j2
sshd_config.j2
deployment_state.json.j2
env.staging.j2
```

The template model is:

```text
Template
    +
Variables
    │
    ▼
Rendered Configuration
```

This allows infrastructure configuration to contain environment-aware values without duplicating complete configuration files for every environment.

---

# 45. Copy vs Template

The IaC architecture uses both:

```text
template
```

and:

```text
copy
```

for different purposes.

### Template

Used when values must be rendered dynamically.

Examples:

```text
Docker Compose
Nginx
SSH configuration
Environment configuration
Deployment state
```

### Copy

Used when repository content should be synchronized without Jinja rendering.

The observability configuration is an example of this pattern.

This distinction keeps configuration semantics explicit.

---

# 46. Infrastructure Configuration Flow

The complete configuration flow is:

```text
Git Repository
      │
      ├── Playbooks
      ├── Roles
      ├── Templates
      └── Observability Configuration
              │
              ▼
          Ansible
              │
              ├── Variables
              └── Secrets
                    │
                    ▼
                 Host
                    │
          ┌─────────┼──────────┐
          ▼         ▼          ▼
       Docker    Runtime    Security
          │         │          │
          └─────────┼──────────┘
                    ▼
              Ready Environment
```

---

# 47. Infrastructure Lifecycle

The intended infrastructure lifecycle is:

```text
1. Define
   │
   ▼
2. Version
   │
   ▼
3. Validate
   │
   ▼
4. Provision
   │
   ▼
5. Verify
   │
   ▼
6. Operate
   │
   ▼
7. Change
   │
   └──────────────► back to Define
```

This transforms infrastructure management from a collection of manual actions into an engineering lifecycle.

---

# 48. Change Management

Infrastructure changes should be implemented through the repository whenever possible.

The preferred workflow is:

```text
Infrastructure Change
       │
       ▼
Modify Ansible Code
       │
       ▼
Review
       │
       ▼
Validate
       │
       ▼
Apply
       │
       ▼
Verify
       │
       ▼
Document
```

Direct manual changes to the host create configuration drift and should not become the normal mechanism for permanent infrastructure changes.

---

# 49. Configuration Drift

Configuration drift occurs when:

```text
Repository Desired State
          ≠
Host Actual State
```

For example:

```text
Repository
    │
    └── Docker configuration A

Host
    │
    └── Docker configuration B
```

The resulting mismatch makes the environment difficult to reproduce.

The IaC model attempts to reduce this by making the repository the source of truth.

---

# 50. Drift Recovery

When drift is detected:

```text
Detect Drift
     │
     ▼
Determine Intended State
     │
     ▼
Update IaC if Necessary
     │
     ▼
Re-apply Ansible
     │
     ▼
Validate
```

The critical rule is:

> Do not simply modify the host to match an outdated repository definition.

If the desired infrastructure has changed, the infrastructure code should change first.

---

# 51. Infrastructure Testing Strategy

Infrastructure code should be validated at multiple levels.

## Syntax

Verify that Ansible files are syntactically valid.

## Static

Verify:

```text
Task structure
Variables
Templates
Role references
```

## Check Mode

Where supported, use:

```text
ansible-playbook --check
```

to inspect intended changes without applying them.

## Provisioning

Apply the infrastructure to the target host.

## Assertions

Verify infrastructure contracts.

## Runtime

Verify:

```text
Services
Docker
Networking
Filesystem
Runner
Security controls
```

The architecture is therefore:

```text
Static Validation
       │
       ▼
Check Mode
       │
       ▼
Provision
       │
       ▼
Assertions
       │
       ▼
Runtime Verification
```

---

# 52. Check Mode Limitations

Ansible check mode should not be treated as proof that the infrastructure will succeed.

Some operations depend on:

* external APIs;
* generated values;
* service runtime state;
* command behavior;
* actual filesystem state.

The Docker role already reflects this distinction by explicitly excluding certain installation/service tasks from check mode.

Therefore:

```text
Check Mode
```

is a predictive validation mechanism, not a complete replacement for real provisioning.

---

# 53. Operational Verification

After provisioning, infrastructure verification should confirm more than the presence of files.

The verification hierarchy should be:

```text
Host
  │
  ├── SSH
  ├── Firewall
  └── Filesystem
        │
        ▼
Docker
  │
  ├── Engine
  ├── Networks
  └── Volumes
        │
        ▼
Services
  │
  ├── API
  ├── Worker
  ├── PostgreSQL
  ├── Redis
  └── MinIO
        │
        ▼
Observability
```

---

# 54. Failure Handling During Provisioning

Infrastructure failures should be interpreted according to their layer.

Examples:

### APT failure

Likely:

```text
Host / package-management problem
```

### Docker repository failure

Likely:

```text
Repository / network / package trust problem
```

### Template failure

Likely:

```text
IaC configuration problem
```

### Runner registration failure

Likely:

```text
GitHub API / credential / runner configuration problem
```

### SSH validation failure

Likely:

```text
Security configuration problem
```

The provisioning error should therefore be mapped to the infrastructure responsibility that produced it.

---

# 55. External Dependencies

Infrastructure provisioning is not completely self-contained.

The current implementation depends on external systems such as:

```text
Ubuntu APT repositories
Docker package repository
GitHub API
GitHub Runner distribution
```

This means infrastructure reproducibility should be understood as:

```text
Reproducible Configuration
```

rather than:

```text
Complete Offline Reproduction
```

External availability remains an operational dependency.

---

# 56. IaC Security Considerations

Infrastructure code has privileged access to the host.

Therefore the Ansible execution environment must be treated as a privileged control plane.

Important security properties include:

```text
Protected credentials
Controlled runner access
Minimal secret exposure
Reviewable infrastructure changes
SSH hardening
Firewall policy
Controlled privilege escalation
```

The use of:

```yaml
become: true
```

means the playbook executes with elevated privileges where required.

That privilege should be considered part of the infrastructure security boundary.

---

# 57. Privilege Model

The playbook operates against the host with privilege escalation:

```text
Ansible
   │
   ▼
become
   │
   ▼
root-level host configuration
```

However, the GitHub runner itself operates under:

```text
deploy_user
```

This creates an important separation:

```text
Infrastructure Provisioning
          │
          ▼
        root
          │
          ▼
Host Configuration

Runtime Deployment
          │
          ▼
    deploy_user
          │
          ▼
Docker Workloads
```

This distinction should remain explicit.

---

# 58. Why the Runner Is Infrastructure

The GitHub Actions runner is not application code.

It provides execution capability for:

```text
CI
CD
Deployment automation
```

Because the runner depends on:

* the host;
* Docker;
* filesystem paths;
* credentials;
* systemd;
* deployment runtime;

its lifecycle belongs to the infrastructure domain.

---

# 59. IaC and Observability

Infrastructure code also establishes the foundation for observability.

The deployment runtime creates and synchronizes observability configuration.

The Docker Compose topology then runs:

```text
Prometheus
Loki
Promtail
Grafana
Alertmanager
Exporters
```

This creates an important feedback loop:

```text
Infrastructure
     │
     ▼
Observability
     │
     ▼
Infrastructure Signals
     │
     ▼
Operations
     │
     ▼
Infrastructure Changes
```

Infrastructure is therefore not only provisioning the platform.

It is also provisioning the mechanisms used to understand the platform.

---

# 60. IaC and Reliability

The IaC layer contributes to reliability indirectly.

It provides:

```text
Reproducibility
Consistency
Deterministic configuration
Controlled changes
Recovery foundation
```

For example, if the host is lost:

```text
Host Failure
     │
     ▼
New / Rebuilt Host
     │
     ▼
Ansible
     │
     ▼
Known Infrastructure State
     │
     ▼
Deployment
     │
     ▼
Application Recovery
```

This is an infrastructure-level recovery capability.

---

# 61. IaC and Disaster Recovery

The current architecture does not imply complete disaster recovery.

Ansible can recreate infrastructure configuration, but recovery of persistent application data depends on the persistence and backup strategy.

Therefore:

```text
Infrastructure Rebuild
        ≠
Complete Data Recovery
```

A complete recovery model must separately address:

```text
Host configuration
Application configuration
Persistent volumes
Database data
Object storage data
Secrets
Deployment state
```

This distinction is essential when documenting recovery capabilities.

---

# 62. IaC Source of Truth

The repository should be treated as the source of truth for intended infrastructure behavior.

The relationship is:

```text
Repository
    │
    ├── Playbooks
    ├── Roles
    ├── Templates
    └── Configuration
            │
            ▼
       Desired State
```

The host is an instance of that state:

```text
Repository Desired State
            │
            ▼
        Ansible
            │
            ▼
       Host Actual State
```

---

# 63. What Belongs in IaC

The following categories belong naturally in the IaC layer:

```text
Host package requirements
Docker installation
Docker service configuration
Deployment directories
Filesystem ownership
Runtime configuration templates
Infrastructure services configuration
Firewall rules
SSH hardening
Runner installation
Runner service configuration
Infrastructure validation
```

---

# 64. What Does Not Belong in IaC

The following should not be embedded into infrastructure roles merely because they execute during deployment:

```text
Application business logic
Application source code
Business workflows
User-facing behavior
Application-specific runtime decisions
Database business migrations
Incident diagnosis
Manual operational procedures
```

Those concerns belong to application, deployment, reliability, or operations documentation.

---

# 65. Role Dependency Matrix

The current architecture can be summarized as:

| Capability               | base | docker | deploy_runtime | github_runner | security_baseline |
| ------------------------ | ---: | -----: | -------------: | ------------: | ----------------: |
| OS packages              |    ✓ |        |                |             ✓ |                 ✓ |
| Docker installation      |      |      ✓ |                |               |                   |
| Docker service           |      |      ✓ |                |               |                   |
| Deployment filesystem    |      |        |              ✓ |             ✓ |                   |
| Compose configuration    |      |        |              ✓ |               |                   |
| Runtime configuration    |      |        |              ✓ |               |                   |
| Runner installation      |      |        |                |             ✓ |                   |
| Runner registration      |      |        |                |             ✓ |                   |
| Docker access validation |      |      ✓ |                |             ✓ |                   |
| Firewall                 |      |        |                |               |                 ✓ |
| SSH hardening            |      |        |                |               |                 ✓ |
| Host security            |      |        |                |               |                 ✓ |

This matrix clarifies responsibility boundaries.

---

# 66. End-to-End IaC Execution

The complete provisioning flow can be represented as:

```text
site.yml
   │
   ▼
base
   │
   ├── apt update
   ├── package upgrade
   └── base packages
   │
   ▼
docker
   │
   ├── repository
   ├── packages
   ├── service
   └── docker group
   │
   ▼
deploy_runtime
   │
   ├── directories
   ├── templates
   ├── deployment state
   ├── environment
   ├── logs
   └── observability
   │
   ▼
github_runner
   │
   ├── dependencies
   ├── installation
   ├── registration
   ├── systemd
   └── validation
   │
   ▼
security_baseline
   │
   ├── UFW
   ├── SSH hardening
   └── service validation
   │
   ▼
Provisioned Host
```

---

# 67. Desired End State

After successful execution, the host should satisfy the following conceptual state:

```text
Host
├── Base packages installed
├── Docker installed
├── Docker running
├── Deployment runtime present
├── Deployment configuration present
├── Observability configuration present
├── GitHub runner installed
├── GitHub runner registered
├── GitHub runner active
├── Docker access available to deploy_user
├── UFW configured
└── SSH configuration validated
```

This is the infrastructure contract upon which later deployment and operations depend.

---

# 68. Infrastructure as Code Maturity

The current IaC implementation has several characteristics of a production-oriented infrastructure model:

```text
✓ Version-controlled infrastructure
✓ Role-based separation
✓ State-aware execution
✓ Conditional initialization
✓ Privilege boundaries
✓ Secret separation
✓ Configuration templating
✓ Runtime assertions
✓ Service verification
✓ Security baseline
✓ Check-mode awareness
```

It should nevertheless not be interpreted as a fully mature enterprise IaC platform.

The current environment remains:

```text
Single Host
Single Primary Environment
Local VM
Docker Compose
Ansible-based provisioning
```

The architecture is intentionally appropriate to that scope.

---

# 69. Current Limitations

The current IaC model has known limitations.

## 69.1 Single Host

There is no multi-node infrastructure orchestration.

## 69.2 Local Persistence

Persistent data remains tied to the host's storage model.

## 69.3 External Dependencies

Provisioning depends on external repositories and APIs.

## 69.4 Limited Environment Abstraction

The current implementation is centered around the staging environment.

## 69.5 No Full Infrastructure Test Framework

The existing assertions provide useful validation, but they do not constitute a complete infrastructure integration testing framework.

## 69.6 No Automatic Disaster Recovery

Ansible provides infrastructure reconstruction capability but does not by itself restore persistent application data.

These limitations are architectural constraints, not undocumented assumptions.

---

# 70. Evolution Path

The IaC architecture can evolve incrementally.

A possible progression is:

```text
Current
  │
  ▼
Stronger Ansible Validation
  │
  ▼
Infrastructure Integration Tests
  │
  ▼
Environment Abstraction
  │
  ▼
Secrets Management Improvements
  │
  ▼
Backup / Restore Automation
  │
  ▼
Multi-Host Infrastructure
  │
  ▼
Orchestrated Runtime
```

The introduction of a new IaC technology should be driven by an actual infrastructure requirement.

---

# 71. Engineering Decision

The current infrastructure follows this decision:

> Use Ansible as the primary Infrastructure as Code mechanism for configuring and maintaining the Mini-Write Linux host and its execution environment.

The decision is based on the current infrastructure boundary:

```text
Existing VM
+
Linux Host Configuration
+
Docker Runtime
+
Deployment Runtime
+
Security Baseline
+
Runner
```

This provides the required automation without introducing infrastructure tooling whose primary value would be cloud resource lifecycle management that the current project does not require.

---

# 72. Operational Rule

The most important operational rule is:

> Permanent infrastructure changes should be represented in Infrastructure as Code.

A manual host change may be useful during investigation or emergency recovery.

However, if the change becomes part of the intended infrastructure state, it must eventually be reflected in the repository.

Otherwise:

```text
Manual Change
     │
     ▼
Host State Changed
     │
     ▼
Repository Unchanged
     │
     ▼
Configuration Drift
```

The correct lifecycle is:

```text
Manual Discovery / Emergency Change
              │
              ▼
Document Intended State
              │
              ▼
Update IaC
              │
              ▼
Validate
              │
              ▼
Repository and Host Converge
```

---

# 73. Summary

Mini-Write uses **Ansible as the Infrastructure as Code control layer** for its single-node Linux infrastructure.

The IaC architecture is organized around bounded roles:

```text
base
docker
deploy_runtime
github_runner
security_baseline
```

The main playbook orchestrates those capabilities in dependency order:

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

The resulting infrastructure provides:

```text
Host Preparation
       +
Docker Runtime
       +
Deployment Runtime
       +
CI/CD Runner
       +
Security Baseline
       +
Observability Configuration
```

The most important architectural property is that the infrastructure is represented as **version-controlled desired state** rather than as undocumented host configuration.

The resulting lifecycle is:

```text
Code
  │
  ▼
Review
  │
  ▼
Validate
  │
  ▼
Provision
  │
  ▼
Assert
  │
  ▼
Verify
  │
  ▼
Operate
  │
  ▼
Change through Code
```

This establishes the Infrastructure as Code foundation on which the remaining Mini-Write infrastructure, deployment, operations, reliability, and observability capabilities are built.

```
```
