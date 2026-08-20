# Security Baseline

## 1. Purpose

This document defines the security baseline applied to the Mini-Write staging host.

The security baseline is part of the infrastructure layer and establishes the minimum host-level security posture required before the application stack is deployed.

The baseline is implemented through Ansible rather than through manual host configuration.

Its purpose is not to provide a complete security program.

Instead, it establishes a controlled foundation covering:

- host network exposure;
- SSH access hardening;
- privileged access restrictions;
- authentication behavior;
- firewall policy;
- infrastructure configuration ownership;
- Docker-related security boundaries;
- validation of the resulting security posture;
- repeatability and idempotency.

The security model can be summarized as:

```text
                    Ubuntu Host
                        │
            ┌───────────┴───────────┐
            │                       │
         SSH Access             Network Access
            │                       │
            ▼                       ▼
      SSH Hardening                 UFW
            │                       │
            └───────────┬───────────┘
                        │
                        ▼
                 Docker Runtime
                        │
                        ▼
                Container Boundary
                        │
                        ▼
              Mini-Write Services
````

The baseline therefore establishes security controls **below the application layer**.

Application-level security remains the responsibility of the application and runtime architecture.

---

# 2. Security Baseline Scope

The current baseline belongs to the Stage 3 infrastructure implementation.

The implemented security hardening is intentionally moderate.

It focuses on controls that materially improve the staging host's security posture without introducing unnecessary operational complexity.

The baseline currently covers:

```text
Host
├── Firewall
├── SSH
├── Privileged access
├── Authentication configuration
├── Deployment ownership
└── Docker execution boundary
```

It does not attempt to implement a complete enterprise security platform.

For example, this baseline does not establish:

```text
Centralized identity management
Enterprise PAM
Host intrusion detection
Full SIEM integration
Automated vulnerability management
Secrets management platform
Zero-trust network architecture
Multi-host security orchestration
```

Those capabilities belong to later architectural evolution rather than the current Stage 3 scope.

---

# 3. Security Design Principles

The baseline follows several principles.

## 3.1 Default Deny

Unnecessary inbound network traffic should not be accepted by default.

The host therefore uses:

```text
Incoming → DENY
Outgoing → ALLOW
```

This establishes a restrictive inbound network posture while preserving normal outbound operation.

---

## 3.2 Explicit Exposure

Services that need inbound access are explicitly allowed.

The current host firewall allows:

```text
TCP/22
TCP/80
TCP/443
```

Everything else remains blocked by the default inbound policy unless explicitly allowed later.

---

## 3.3 Minimize Privileged Access

Root access should not be the normal execution path for deployment operations.

The deployment user is granted the capabilities required to perform its role.

The goal is:

```text
Human / CI Runner
       │
       ▼
Deployment User
       │
       ▼
Required Infrastructure Capabilities
```

rather than:

```text
Human / CI Runner
       │
       ▼
Unrestricted Root Shell
```

---

## 3.4 Configuration as Code

Security configuration is managed through Ansible.

The desired model is:

```text
Git
 │
 ▼
Ansible Security Role
 │
 ▼
Host Security Configuration
```

Manual modifications are therefore not the authoritative source of the security posture.

---

## 3.5 Validate Before Applying Risky Changes

Security configuration can itself cause operational outages.

For example, an incorrect SSH configuration could prevent future access.

Therefore security changes should be validated before they become authoritative.

The SSH hardening implementation explicitly validates the resulting SSH configuration using:

```bash
sshd -t
```

before relying on the hardened configuration.

---

# 4. Ansible Security Role

The security baseline is implemented through:

```text
infra/ansible/roles/security_baseline/
```

The role represents the security baseline as infrastructure code.

Its architectural position is:

```text
Ansible
   │
   ├── base
   ├── deploy_runtime
   ├── docker
   ├── github_runner
   └── security_baseline
```

The security role is therefore one of the infrastructure building blocks rather than an application component.

---

# 5. Security Baseline Lifecycle

The security baseline follows:

```text
Desired Security State
        │
        ▼
Ansible Role
        │
        ▼
Host Configuration
        │
        ▼
Validation
        │
        ▼
Operational Security State
```

The role should be safely repeatable.

Running it again should converge the host toward the same desired state rather than progressively modifying the system.

---

# 6. Firewall Architecture

The host uses UFW as the host-level firewall management interface.

The current policy is:

```text
Default incoming: deny
Default outgoing: allow
```

This produces:

```text
                  Internet
                     │
                     ▼
                  Ubuntu
                     │
                     ▼
                    UFW
                     │
           ┌─────────┴─────────┐
           │                   │
        Allowed             Blocked
           │                   │
     ┌─────┼─────┐             │
     │     │     │             │
    22    80    443            │
     │     │     │             │
     ▼     ▼     ▼             X
    SSH   HTTP  HTTPS       Other inbound
```

This is the primary host-level network boundary.

---

# 7. Allowed Firewall Ports

The baseline explicitly allows:

|  Port | Protocol | Purpose                  |
| ----: | -------- | ------------------------ |
|  `22` | TCP      | SSH administration       |
|  `80` | TCP      | HTTP application traffic |
| `443` | TCP      | HTTPS traffic            |

No broad inbound port range is opened.

This is important because Docker services may expose additional ports internally or through Docker's networking rules.

The host firewall policy must therefore remain aligned with the actual externally required interfaces.

---

# 8. OpenSSH Rule Deduplication

The final firewall configuration does not intentionally maintain duplicate SSH allow rules.

The OpenSSH rule was normalized so that port `22/tcp` has a single authoritative allow rule.

This matters for two reasons:

1. it keeps the firewall state deterministic;
2. it avoids configuration noise during repeated Ansible execution.

The resulting policy is therefore easier to inspect and reason about.

---

# 9. Firewall Default Policy

The firewall baseline intentionally separates:

```text
Inbound
```

from:

```text
Outbound
```

The current policy is:

```text
Inbound  → deny by default
Outbound → allow by default
```

This reflects the staging host's operational requirement to initiate:

```text
Package downloads
Container image pulls
External GitHub communication
Other required outbound dependency access
```

while restricting unsolicited inbound connections.

---

# 10. SSH Hardening

SSH is the primary administrative entry point to the host.

The security baseline therefore applies explicit SSH hardening.

The hardening configuration is maintained through:

```text
/etc/ssh/sshd_config.d/99-miniwrite-hardening.conf
```

This is preferable to embedding project-specific settings directly into the main:

```text
/etc/ssh/sshd_config
```

because the project-specific security policy remains isolated and easier to manage.

The configuration is:

```text
sshd_config
     │
     ├── system configuration
     │
     └── 99-miniwrite-hardening.conf
             │
             ▼
       Mini-Write SSH Policy
```

---

# 11. SSH Authentication Policy

The hardened SSH configuration establishes the following effective settings:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
```

The resulting authentication model is:

```text
SSH
 │
 ├── Root login
 │      └── Disabled
 │
 ├── Password authentication
 │      └── Disabled
 │
 ├── Public-key authentication
 │      └── Enabled
 │
 └── Empty passwords
        └── Disabled
```

This substantially reduces common SSH attack paths.

---

# 12. Root SSH Access

The baseline explicitly disables direct root SSH login:

```text
PermitRootLogin no
```

Administrative access should therefore proceed through an authorized non-root account.

The intended operational model is:

```text
Administrator
     │
     ▼
Authorized User
     │
     ▼
Privilege escalation when required
```

rather than:

```text
Administrator
     │
     ▼
Direct root SSH
```

---

# 13. Password Authentication

Password-based SSH authentication is disabled:

```text
PasswordAuthentication no
```

The host therefore relies on public-key authentication for SSH access.

This reduces exposure to:

```text
Password guessing
Credential spraying
Brute-force password attacks
```

The security boundary becomes:

```text
Private Key
     │
     ▼
SSH Client
     │
     ▼
Public Key
     │
     ▼
Authorized SSH Account
```

---

# 14. Public-Key Authentication

Public-key authentication remains enabled:

```text
PubkeyAuthentication yes
```

This is the intended SSH authentication mechanism for the staging host.

The security of this mechanism depends on protecting the corresponding private keys outside the host.

The server-side configuration cannot compensate for a compromised private key.

---

# 15. Empty Passwords

The configuration explicitly disables empty-password authentication:

```text
PermitEmptyPasswords no
```

This reinforces the baseline even if account-level password configuration changes in the future.

---

# 16. SSH Configuration Validation

SSH configuration changes are validated using:

```bash
sshd -t
```

The purpose is to verify that the resulting configuration is syntactically valid before relying on it.

The validation flow is:

```text
Generate SSH Configuration
          │
          ▼
       sshd -t
          │
     ┌────┴────┐
     │         │
   Valid     Invalid
     │         │
     ▼         ▼
 Continue    Stop / Fix
```

This is particularly important because SSH is itself the remote recovery channel.

---

# 17. SSH Operational Validation

After hardening, the resulting host was validated by establishing a new SSH session.

This verifies not merely configuration syntax but actual operational access.

The validation therefore covers two different properties:

```text
Configuration Validity
        │
        ▼
      sshd -t
```

and:

```text
Operational Accessibility
        │
        ▼
New SSH Session
```

Both are required.

---

# 18. SSH Hardening Safety Principle

SSH hardening should never be evaluated solely by asking:

> Is the configuration more secure?

It must also answer:

> Can authorized administrators still reach the host?

The baseline therefore treats:

```text
Security
+
Recoverability
```

as a combined requirement.

A security configuration that locks out all legitimate administrators is operationally defective.

---

# 19. Idempotency

The security baseline was tested for idempotency.

After the desired state had been established, subsequent Ansible execution produced:

```text
changed=0
```

This is an important property.

It demonstrates that the role is convergent:

```text
First Run
   │
   ▼
Apply Security State
   │
   ▼
Host Reaches Desired State
   │
   ▼
Second Run
   │
   ▼
No Unnecessary Changes
```

Idempotency is especially important for security because uncontrolled repeated modifications make the security state difficult to audit.

---

# 20. Security State Convergence

The desired behavior is:

```text
Current Host State
       │
       ▼
Compare with Desired State
       │
       ├── Different
       │      │
       │      ▼
       │   Remediate
       │
       └── Equal
              │
              ▼
          No Change
```

This makes the Ansible role suitable for repeated infrastructure execution.

---

# 21. Deployment User and Security Boundary

The infrastructure architecture uses a dedicated deployment user.

The deployment user participates in:

```text
CI/CD
Deployment
Docker interaction
Infrastructure operations
```

This creates an explicit boundary between:

```text
System Administration
```

and:

```text
Application Deployment
```

The deployment user is not intended to replace the operating system's root account.

Instead, it is the controlled execution identity for automated deployment operations.

---

# 22. Docker Group Privilege

The deployment user is granted Docker access through membership in the Docker group.

This is operationally necessary because the self-hosted GitHub Actions runner needs to interact with Docker.

However, Docker group membership must be considered privileged.

Conceptually:

```text
docker group
      │
      ▼
Docker Engine Access
      │
      ▼
High Host Privilege
```

Therefore:

```text
Docker access
    ≠
ordinary application permission
```

The account receiving Docker access should be treated as a trusted deployment identity.

---

# 23. GitHub Actions Runner Security Boundary

The self-hosted GitHub Actions runner executes on the same Ubuntu host.

The resulting chain is:

```text
GitHub
   │
   ▼
GitHub Actions Job
   │
   ▼
Self-hosted Runner
   │
   ▼
Deployment User
   │
   ▼
Docker
   │
   ▼
Application Stack
```

This means the runner is part of the host's security boundary.

A compromised workflow or malicious deployment command could potentially affect the Docker environment and therefore the host.

Consequently, repository workflow changes and third-party GitHub Actions should be treated as privileged execution paths.

---

# 24. Docker Security Boundary

Docker provides process, filesystem, network, and resource isolation.

The security model is approximately:

```text
Ubuntu Host
    │
    ▼
Docker Engine
    │
    ├── Container A
    ├── Container B
    ├── Container C
    └── ...
```

However, Docker is not a complete security boundary equivalent to a separate physical machine or VM.

The Docker daemon is highly privileged.

Therefore the security model assumes:

```text
Docker Host
    +
Trusted Deployment Identity
    +
Trusted Container Images
```

are part of the trusted infrastructure base.

---

# 25. Container Isolation

The Docker architecture reduces unnecessary communication through network segmentation.

The current topology separates:

```text
frontend-network
```

from:

```text
backend-network
```

The intended boundary is:

```text
External Traffic
       │
       ▼
Frontend Network
       │
       ▼
Gateway / API
       │
       ▼
Backend Network
       │
       ├── PostgreSQL
       ├── Redis
       ├── MinIO
       └── Worker
```

This limits direct network participation to services that require it.

---

# 26. Host Port Exposure

Security of the host depends not only on UFW but also on Docker port publishing.

The architectural distinction is:

```text
Docker internal port
        ≠
Host published port
```

A service may listen on a container network without requiring host-level exposure.

Therefore the security review must inspect:

```text
Compose ports:
```

together with:

```text
UFW rules
```

The intended rule is:

> Do not publish a service to the host unless there is an explicit operational requirement.

---

# 27. Internal Services

The architecture keeps several backend services internal to Docker networking.

Examples include:

```text
PostgreSQL
Redis
Worker
```

They communicate through Docker's backend network rather than requiring broad host exposure.

This reduces the attack surface of the host.

The model is:

```text
API ───────► PostgreSQL
 │
 ├─────────► Redis
 │
 └─────────► MinIO
```

rather than exposing every dependency directly to external clients.

---

# 28. Observability Security

The observability stack contains components with elevated visibility into the host and containers.

Examples include:

```text
Promtail
Node Exporter
cAdvisor
```

These components may access:

```text
Container logs
Host filesystem information
Container runtime information
Docker metadata
```

Therefore observability infrastructure is itself part of the security boundary.

Observability should not be treated as inherently harmless simply because it does not serve business traffic.

---

# 29. Docker Socket Consideration

Promtail requires access to:

```text
/var/run/docker.sock
```

for Docker runtime integration.

The mount is read-only in the current configuration.

Nevertheless, Docker socket access is security-sensitive because the Docker socket represents access to the Docker control plane.

The architectural principle is:

```text
Docker Socket
     │
     ▼
Privileged Infrastructure Component
```

rather than:

```text
Docker Socket
     │
     ▼
Ordinary Application Container
```

Only components that genuinely require this access should receive it.

---

# 30. Host Filesystem Mounts

Some infrastructure containers require host filesystem visibility for monitoring.

Examples include:

```text
Node Exporter
cAdvisor
Promtail
```

These mounts should be:

```text
Explicit
Minimal
Read-only where possible
Purpose-specific
```

The goal is to avoid turning monitoring containers into general-purpose host filesystem access points.

---

# 31. File Permission Principle

Security-sensitive infrastructure files should not be globally writable or readable without a requirement.

This principle applies particularly to:

```text
Deployment configuration
Environment files
SSH configuration
Infrastructure state
Deployment logs
```

The deployment environment file is configured with restricted permissions:

```text
0640
```

The broader rule is:

```text
Configuration
    │
    ▼
Least required access
```

rather than:

```text
Configuration
    │
    ▼
World-readable
```

---

# 32. Deployment Directory Boundary

The deployment runtime is located under:

```text
/opt/deploy
```

This directory forms an operational boundary for:

```text
Rendered deployment configuration
Compose files
Environment configuration
Deployment logs
Deployment state
```

The conceptual structure is:

```text
/opt/deploy
├── compose/
├── env/
├── logs/
└── state/
```

The security objective is to keep deployment artifacts separate from arbitrary user files and application source code.

---

# 33. Deployment State Security

Deployment state contains information about the currently deployed and previously deployed application versions.

The state model includes:

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

Although this state is not itself a secret, it is operationally sensitive.

It influences deployment and rollback decisions and should therefore be controlled as infrastructure state.

The security requirement is:

```text
Deployment State
      │
      ▼
Controlled Ownership
      │
      ▼
Controlled Write Access
```

---

# 34. Security and Configuration Separation

The infrastructure architecture separates:

```text
Code
Configuration
Secrets
Runtime State
```

These should not be treated as one category.

For example:

```text
Application Image
    → immutable application artifact

Compose Configuration
    → deployment topology

Environment File
    → runtime configuration / sensitive values

Deployment State
    → operational state
```

This separation improves both security and maintainability.

---

# 35. Secrets Boundary

The current baseline does not introduce a dedicated external secrets-management system.

Sensitive configuration is therefore handled through controlled environment configuration.

This is adequate for the current project scope but represents a known security boundary.

The current model is:

```text
Ansible
   │
   ▼
Protected Environment File
   │
   ▼
Docker Compose
   │
   ▼
Container Environment
```

Future production evolution may replace this with a dedicated secret-management mechanism.

---

# 36. Image Trust

Container images are part of the security supply chain.

The current Compose configuration uses explicitly versioned image references rather than:

```text
latest
```

This improves predictability.

However, version tags are not immutable guarantees.

A stronger future model is:

```text
Image
 +
Immutable Digest
```

The current security baseline therefore treats image provenance and pinning as an area for continued hardening.

---

# 37. Package Installation Security

Host packages are installed through APT and the configured package repositories.

The Docker installation specifically establishes repository signing trust using a GPG keyring.

The desired chain is:

```text
Repository
    │
    ▼
Signature
    │
    ▼
Configured Keyring
    │
    ▼
APT Verification
    │
    ▼
Package
```

This avoids treating arbitrary package sources as trusted.

---

# 38. Security Validation Model

Security validation is not a single check.

The baseline uses multiple validation dimensions:

```text
Configuration
     │
     ├── SSH syntax
     ├── Firewall state
     └── Desired Ansible state

Operational
     │
     └── New SSH session

Repeatability
     │
     └── Idempotent Ansible execution
```

This produces a more reliable validation model than checking whether an Ansible playbook merely completed successfully.

---

# 39. Security Validation Checklist

The baseline should be considered operationally valid when:

```text
Firewall
    ✓ UFW active
    ✓ Incoming default deny
    ✓ Outgoing default allow
    ✓ TCP/22 allowed
    ✓ TCP/80 allowed
    ✓ TCP/443 allowed
    ✓ No unintended duplicate SSH rule

SSH
    ✓ sshd configuration syntactically valid
    ✓ Root SSH login disabled
    ✓ Password authentication disabled
    ✓ Public-key authentication enabled
    ✓ Empty passwords disabled
    ✓ New SSH session succeeds

Ansible
    ✓ Security role executes successfully
    ✓ Repeated execution is idempotent
    ✓ No unnecessary changes after convergence

Docker
    ✓ Deployment user has required Docker access
    ✓ Container network exposure matches intended architecture
    ✓ Privileged infrastructure containers are known
    ✓ Host port exposure is intentional
```

---

# 40. Idempotency Validation

Idempotency is a specific security property of the infrastructure implementation.

The expected result after convergence is:

```text
changed=0
```

A repeated run should not:

```text
Duplicate firewall rules
Rewrite unchanged security configuration
Change permissions unnecessarily
Restart services unnecessarily
```

This makes the security posture predictable.

---

# 41. Security Failure Modes

The security baseline introduces its own failure modes.

## 41.1 Incorrect Firewall Rule

Possible consequence:

```text
Legitimate service inaccessible
```

Mitigation:

```text
Explicit port inventory
Firewall validation
Connectivity testing
```

---

## 41.2 Invalid SSH Configuration

Possible consequence:

```text
Administrative access failure
```

Mitigation:

```text
sshd -t
New SSH session validation
```

---

## 41.3 Incorrect Permission

Possible consequence:

```text
Deployment failure
```

or:

```text
Unauthorized configuration access
```

Mitigation:

```text
Controlled ownership
Controlled permissions
Ansible convergence
```

---

## 41.4 Excessive Docker Privilege

Possible consequence:

```text
Container compromise
       │
       ▼
Docker control
       │
       ▼
Host compromise
```

Mitigation:

```text
Limit privileged containers
Limit Docker socket exposure
Treat Docker group membership as privileged
```

---

# 42. Security Baseline Versus Application Security

The host baseline does not replace application security.

The layers are:

```text
Host Security
    │
    ▼
Container Security
    │
    ▼
Network Security
    │
    ▼
Application Security
    │
    ▼
Runtime Reliability
```

For example:

```text
UFW
```

protects the host network boundary.

It does not determine whether:

```text
JWT authentication
```

is implemented correctly.

Likewise:

```text
SSH hardening
```

does not determine whether an API endpoint correctly enforces authorization.

These are separate security domains.

---

# 43. Security Baseline and Reliability

Security and reliability are related but not interchangeable.

For example:

```text
SSH hardening
```

improves security but can reduce recoverability if applied incorrectly.

Therefore the implementation explicitly validates continued administrative access.

Similarly:

```text
Firewall default deny
```

improves isolation but can break service availability if required ports are omitted.

The engineering principle is:

```text
Security Control
      │
      ├── Security Benefit
      │
      └── Operational Consequence
```

Both must be evaluated.

---

# 44. Security Baseline and Observability

Security controls should remain observable.

For example, operational diagnosis may require distinguishing:

```text
Application Failure
```

from:

```text
Network Policy Failure
```

from:

```text
Container Failure
```

from:

```text
Host Failure
```

The observability architecture therefore complements the security baseline.

The intended operational chain is:

```text
Security Boundary
      │
      ▼
Observable Behavior
      │
      ▼
Detection
      │
      ▼
Incident Diagnosis
```

---

# 45. Security Baseline and Deployment

Deployment modifies the runtime environment and therefore interacts directly with the security baseline.

The relationship is:

```text
Infrastructure Provisioning
        │
        ▼
Security Baseline
        │
        ▼
Docker Runtime
        │
        ▼
Deployment
        │
        ▼
Running Workload
```

A deployment should not silently redefine host security policy.

Host security remains infrastructure-owned.

---

# 46. Ownership Model

Security responsibility is distributed across layers.

| Concern                     | Owner                       |
| --------------------------- | --------------------------- |
| Host firewall               | Security baseline / Ansible |
| SSH configuration           | Security baseline / Ansible |
| Host user access            | Infrastructure              |
| Docker installation         | Docker Ansible role         |
| Docker group access         | Infrastructure / Docker     |
| Container network isolation | Compose                     |
| Container privileges        | Compose                     |
| Application authentication  | Application                 |
| Application authorization   | Application                 |
| Runtime failure handling    | Runtime                     |
| Secret values               | Deployment configuration    |
| Security observability      | Observability               |
| Incident response           | Operations                  |

This prevents the security baseline from becoming a catch-all document for unrelated controls.

---

# 47. Current Security Posture

The resulting host security posture can be summarized as:

```text
                 Mini-Write Host
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
       UFW            SSH          Docker
        │              │              │
   Default deny    Key-based      Container
   inbound        authentication  isolation
        │              │              │
        └──────────────┼──────────────┘
                       │
                       ▼
                 Deployment Layer
                       │
                       ▼
                Application Stack
```

The baseline therefore establishes a coherent set of controls rather than a collection of unrelated hardening commands.

---

# 48. Current Limitations

The current baseline intentionally has limitations.

## 48.1 Single Host

The host remains a single security and availability domain.

A host compromise affects the complete Mini-Write staging environment.

---

## 48.2 Docker Trust

Docker Engine and identities with Docker access are highly trusted.

Docker group membership therefore remains a privileged capability.

---

## 48.3 No Dedicated Secret Manager

Secrets are currently handled through protected environment configuration rather than a dedicated secret-management platform.

---

## 48.4 No Immutable Image Digests Everywhere

Explicit image versions improve reproducibility, but not every image is pinned by digest.

---

## 48.5 Moderate Hardening Scope

The baseline is intentionally moderate.

It is not intended to claim compliance with:

```text
CIS Benchmark
SOC 2
PCI DSS
ISO 27001
```

or another formal security standard.

No such compliance claim should be inferred from this baseline.

---

# 49. Future Security Evolution

Potential future hardening can be introduced as separate architectural capabilities.

Examples include:

```text
Immutable image digests
Dedicated secrets management
Container image vulnerability scanning
Host vulnerability scanning
Centralized security audit logging
SSH certificate-based access
Stronger Docker isolation
Network policy enforcement
Runtime security monitoring
Automated security compliance checks
```

These should be introduced based on an explicit security requirement rather than added indiscriminately.

---

# 50. Security Invariants

The following invariants define the intended baseline.

### Network

```text
Inbound traffic is denied by default.
```

### SSH

```text
Root SSH login is disabled.
Password-based SSH authentication is disabled.
Public-key authentication remains enabled.
```

### Configuration

```text
Security configuration is managed through Ansible.
```

### Repeatability

```text
Repeated application of the baseline converges without unnecessary changes.
```

### Docker

```text
Docker access is treated as privileged.
```

### Exposure

```text
Only explicitly required host ports should be exposed.
```

### Validation

```text
Security changes must not invalidate legitimate administrative access.
```

---

# 51. Definition of Done

The Mini-Write host security baseline is considered established when:

```text
✓ UFW is active.

✓ UFW defaults to deny inbound traffic.

✓ UFW allows outbound traffic.

✓ Required TCP ports 22, 80, and 443 are explicitly allowed.

✓ SSH root login is disabled.

✓ SSH password authentication is disabled.

✓ SSH public-key authentication is enabled.

✓ Empty-password SSH authentication is disabled.

✓ SSH configuration passes sshd -t.

✓ A new SSH session can be established after hardening.

✓ The deployment user has the required Docker access.

✓ Security configuration is managed through Ansible.

✓ Repeated Ansible execution is idempotent.

✓ Docker network exposure remains aligned with the intended architecture.

✓ Privileged Docker/observability components are explicitly recognized as part of the trusted infrastructure boundary.
```

---

# 52. Final Security Architecture

The Mini-Write security baseline can ultimately be represented as:

```text
┌──────────────────────────────────────────────────────────────┐
│                         Ubuntu Host                          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Security Baseline                   │  │
│  │                                                        │  │
│  │  ┌─────────────┐       ┌───────────────────────────┐  │  │
│  │  │     UFW     │       │       SSH Hardening       │  │  │
│  │  │             │       │                           │  │  │
│  │  │ deny inbound│       │ no root login             │  │  │
│  │  │ allow needed│       │ no password auth          │  │  │
│  │  │ outbound    │       │ public key authentication │  │  │
│  │  └──────┬──────┘       └─────────────┬─────────────┘  │  │
│  │         │                            │                │  │
│  │         └──────────────┬─────────────┘                │  │
│  │                        ▼                              │  │
│  │                 Trusted Host Access                   │  │
│  │                        │                              │  │
│  │                        ▼                              │  │
│  │                 Docker Engine                        │  │
│  │                        │                              │  │
│  │              ┌─────────┴──────────┐                   │  │
│  │              ▼                    ▼                   │  │
│  │       Network Isolation      Resource Controls        │  │
│  │              │                    │                   │  │
│  │              └─────────┬──────────┘                   │  │
│  │                        ▼                              │  │
│  │                  Containers                           │  │
│  │                        │                              │  │
│  │              ┌─────────┴─────────┐                    │  │
│  │              ▼                   ▼                    │  │
│  │        Application          Observability              │  │
│  │        Services              Services                  │  │
│  │                                                         │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

The resulting model is intentionally layered:

```text
Ansible
   │
   ▼
Host Security Baseline
   │
   ├── UFW
   ├── SSH Hardening
   ├── Access Control
   └── Configuration Ownership
          │
          ▼
Docker Security Boundary
   │
   ├── Networks
   ├── Resource Limits
   ├── Container Isolation
   └── Privileged Component Control
          │
          ▼
Mini-Write Runtime
```

The key architectural principle is:

> **The security baseline establishes the minimum trusted and controlled host environment in which the Mini-Write runtime can operate; it does not replace application security, runtime reliability, or operational incident management.**

```
```
