# Infrastructure Overview

## 1. Purpose

This document provides the architectural overview of the Mini-Write infrastructure.

It explains:

- what infrastructure Mini-Write requires;
- how infrastructure components are organized;
- how the infrastructure is provisioned;
- how application services are deployed onto it;
- how infrastructure responsibilities are separated;
- how Infrastructure as Code is used;
- how Docker fits into the runtime environment;
- how the host is secured;
- how infrastructure health is observed;
- how infrastructure changes are operated and maintained.

This document is an architectural entry point.

It intentionally does not replace the detailed infrastructure documents under this directory.

Detailed implementation and operational procedures are documented in:

```text
docs/infrastructure/
├── infrastructure-as-code.md
├── ansible.md
├── host-provisioning.md
├── docker.md
├── security-baseline.md
└── infrastructure-operations.md
````

---

# 2. Infrastructure Role in Mini-Write

Infrastructure is the execution foundation on which all application capabilities operate.

The architectural relationship is:

```text
┌──────────────────────────────────────────────┐
│                  Application                 │
│                                              │
│          API            Worker               │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│              Container Runtime               │
│                  Docker                      │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│              Service Dependencies            │
│                                              │
│      PostgreSQL    Redis    MinIO            │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│             Observability Stack              │
│                                              │
│ Prometheus │ Loki │ Grafana │ Alertmanager   │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│                Linux Host                    │
│                                              │
│ Ubuntu │ Docker │ Network │ Storage │ UFW   │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│             Virtualization Layer             │
│                   VMware                     │
└──────────────────────────────────────────────┘
```

Infrastructure therefore represents more than the Docker containers.

It includes the complete execution foundation from the Linux host to the service runtime.

---

# 3. Infrastructure Architecture

Mini-Write uses a deliberately constrained infrastructure model.

The project runs on:

```text
Physical / Development Host
        │
        ▼
VMware Virtual Machine
        │
        ▼
Ubuntu Linux
        │
        ▼
Docker Engine
        │
        ▼
Docker Compose
        │
        ├── Application Services
        ├── Infrastructure Services
        └── Observability Services
```

This architecture provides a production-oriented operational model without requiring cloud infrastructure.

The goal is not to reproduce a cloud provider mechanically.

The goal is to reproduce the engineering responsibilities normally encountered in a production environment:

* reproducible provisioning;
* deterministic deployment;
* service isolation;
* network segmentation;
* persistent storage;
* security baseline;
* observability;
* health verification;
* controlled configuration;
* operational recovery.

---

# 4. Infrastructure Environment

The current infrastructure is based on a single Linux virtual machine.

The VM provides the execution environment for the Mini-Write platform.

Conceptually:

```text
VMware
  │
  ▼
mini-write VM
  │
  ├── Ubuntu
  ├── Docker Engine
  ├── Ansible-managed configuration
  ├── GitHub Actions self-hosted runner
  └── Mini-Write deployment
```

The single-node topology is intentional.

It provides a realistic operational environment while keeping the infrastructure manageable for a single-developer engineering project.

---

# 5. Single-Node Architecture

Mini-Write does not currently use:

* Kubernetes;
* cloud-managed databases;
* cloud load balancers;
* managed object storage;
* managed Redis;
* multiple application nodes;
* multi-node container orchestration.

Instead:

```text
                    Linux VM
                       │
              Docker Compose
                       │
       ┌───────────────┼────────────────┐
       │               │                │
       ▼               ▼                ▼
  Application     Dependencies     Observability
       │               │                │
       ▼               ▼                ▼
      API        PostgreSQL          Prometheus
    Worker           Redis              Loki
                     MinIO            Grafana
                                  Alertmanager
```

This is a deliberate scope decision rather than an accidental limitation.

---

# 6. Infrastructure Design Goals

The infrastructure architecture is designed around the following goals.

## 6.1 Reproducibility

A newly prepared host should be capable of being brought into the expected infrastructure state using Infrastructure as Code.

---

## 6.2 Determinism

The same configuration should produce the same intended infrastructure state.

---

## 6.3 Isolation

Infrastructure components should not unnecessarily share responsibilities or network exposure.

---

## 6.4 Security

The host should begin from a defined security baseline rather than relying on ad-hoc manual configuration.

---

## 6.5 Observability

Infrastructure failures should be detectable through metrics, logs, health checks, and alerts.

---

## 6.6 Operability

An engineer should be able to:

* understand the infrastructure;
* deploy it;
* inspect it;
* troubleshoot it;
* recover it;
* reproduce it.

---

## 6.7 Evolution

The architecture should provide a foundation for future capabilities without prematurely introducing unnecessary infrastructure complexity.

---

# 7. Infrastructure Layers

The infrastructure is organized into logical layers.

```text
Layer 1 — Host
Layer 2 — Security Baseline
Layer 3 — Container Runtime
Layer 4 — Application Dependencies
Layer 5 — Application Services
Layer 6 — Observability
Layer 7 — Automation / Delivery
```

---

# 8. Layer 1 — Host

The host layer provides the underlying operating environment.

It includes:

```text
Ubuntu Linux
CPU
Memory
Disk
Filesystem
Networking
System services
Docker Engine
```

The host is the root infrastructure boundary.

If the host becomes unavailable, all services running on it become unavailable.

Therefore host reliability is a prerequisite for application reliability.

---

# 9. Layer 2 — Security Baseline

The security baseline establishes minimum host security requirements.

The current baseline includes controls such as:

```text
UFW
Default deny incoming
Controlled service exposure
Host-level configuration
```

The principle is:

```text
Secure Host
    │
    ▼
Controlled Runtime
    │
    ▼
Application Services
```

Security is therefore established before application deployment rather than added afterward.

---

# 10. Layer 3 — Container Runtime

Docker provides the container execution environment.

Docker is responsible for:

* container lifecycle;
* image execution;
* container networking;
* volume mounting;
* environment injection;
* process isolation;
* service startup.

Docker Compose provides the service topology.

Conceptually:

```text
Docker Engine
      │
      ▼
Docker Compose
      │
      ├── API
      ├── Worker
      ├── PostgreSQL
      ├── Redis
      ├── MinIO
      └── Observability Stack
```

---

# 11. Layer 4 — Infrastructure Dependencies

The application requires stateful infrastructure services.

The primary dependencies are:

```text
PostgreSQL
Redis
MinIO
```

Their responsibilities are intentionally separated.

### PostgreSQL

Persistent relational application data.

```text
Users
Application state
Relational records
```

### Redis

Runtime and asynchronous processing support.

```text
Queue
BullMQ state
Job coordination
```

### MinIO

Object storage.

```text
Uploaded files
Object-based application data
```

The separation creates explicit infrastructure dependency boundaries.

---

# 12. Layer 5 — Application Services

The application layer consists primarily of:

```text
API
Worker
```

The API handles synchronous application requests.

The Worker handles asynchronous background processing.

The architectural relationship is:

```text
Client
  │
  ▼
API
  │
  ├── PostgreSQL
  ├── Redis
  └── MinIO
        │
        ▼
     Queue Job
        │
        ▼
      Worker
        │
        ├── Redis
        ├── PostgreSQL
        └── MinIO
```

---

# 13. Layer 6 — Observability

The infrastructure includes a dedicated observability layer.

Its major components include:

```text
Prometheus
Loki
Promtail
Grafana
Alertmanager
Node Exporter
cAdvisor
PostgreSQL Exporter
Redis Exporter
```

The purpose is to observe the infrastructure and application layers without requiring those layers to implement their own monitoring infrastructure.

---

# 14. Infrastructure Observability Model

Infrastructure observability follows:

```text
Host
 │
 └── Node Exporter
          │
          ▼
      Prometheus

Containers
 │
 └── cAdvisor
          │
          ▼
      Prometheus

PostgreSQL
 │
 └── PostgreSQL Exporter
          │
          ▼
      Prometheus

Redis
 │
 └── Redis Exporter
          │
          ▼
      Prometheus

Docker Logs
 │
 └── Promtail
          │
          ▼
         Loki
```

Grafana consumes the resulting telemetry.

Alertmanager handles alert routing.

---

# 15. Layer 7 — Automation and Delivery

Infrastructure is not maintained solely through manual commands.

Automation is provided through:

```text
Ansible
GitHub Actions
Docker Compose
```

The general model is:

```text
Source Control
      │
      ▼
GitHub Actions
      │
      ▼
Deployment Automation
      │
      ▼
Ansible / Deployment Scripts
      │
      ▼
Docker Compose
      │
      ▼
Running Infrastructure
```

This creates a repeatable infrastructure lifecycle.

---

# 16. Infrastructure as Code

Infrastructure configuration is represented as code.

The primary Infrastructure as Code technology is:

```text
Ansible
```

Ansible is responsible for host-level configuration and infrastructure preparation.

The project intentionally uses Ansible rather than introducing Terraform for the current infrastructure scope.

This is appropriate because the current environment is:

```text
Existing VM
      │
      ▼
Linux Host Configuration
      │
      ▼
Docker Runtime
      │
      ▼
Application Deployment
```

The infrastructure problem is primarily host configuration and deployment automation rather than cloud resource provisioning.

---

# 17. Ansible Responsibility Boundary

Ansible manages infrastructure state that belongs to the host and deployment environment.

Its responsibilities include areas such as:

```text
Base host configuration
Docker installation/configuration
Deployment runtime
GitHub Actions runner
Security baseline
```

Conceptually:

```text
Ansible
   │
   ├── base
   ├── deploy_runtime
   ├── docker
   ├── github_runner
   └── security_baseline
```

Each role should maintain a clearly defined responsibility boundary.

---

# 18. Infrastructure State Model

Infrastructure should be understood as a desired-state system.

The conceptual model is:

```text
Desired State
      │
      ▼
Infrastructure Code
      │
      ▼
Ansible
      │
      ▼
Host
      │
      ▼
Actual State
```

The objective is convergence:

```text
Actual State ───────► Desired State
```

rather than a collection of undocumented manual commands.

---

# 19. Deployment Runtime

The deployment environment uses a dedicated deployment area.

The `/opt/deploy` hierarchy acts as the operational deployment location.

Conceptually:

```text
/opt/deploy/
│
├── application
├── configuration
├── logs
└── runtime state
```

The exact structure is governed by the deployment implementation.

The important architectural principle is that deployment state should have a predictable filesystem location.

---

# 20. Deployment State

Deployment state is explicitly represented rather than inferred only from running containers.

For example, the deployment state template contains:

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

This provides a foundation for tracking:

```text
Current API version
Current Worker version
Previous API version
Previous Worker version
```

The distinction is important because operational recovery requires knowledge of both the current and previous deployment states.

---

# 21. Current vs Previous Deployment State

The deployment model therefore supports:

```text
             Deployment State
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
       Current             Previous
          │                   │
      API/Worker           API/Worker
```

This provides an architectural basis for rollback-oriented operations.

The infrastructure documentation should treat deployment state as an operational concern rather than merely a deployment-script implementation detail.

---

# 22. Container Network Architecture

Docker networking separates communication domains.

The application topology uses dedicated networks such as:

```text
frontend-network
backend-network
```

The purpose is to prevent every service from automatically sharing the same communication boundary.

Conceptually:

```text
                    frontend-network
                           │
                     ┌─────┴─────┐
                     │    API    │
                     └─────┬─────┘
                           │
                    backend-network
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
      PostgreSQL         Redis             MinIO
          │                │                │
          └────────────────┼────────────────┘
                           ▼
                         Worker
```

The exact network membership is defined by the deployment configuration.

---

# 23. Persistence Model

Stateful services require persistent storage.

The Docker environment therefore uses persistent volumes for important state.

The current deployment includes volumes such as:

```text
postgres_data
redis_data
minio_data
```

Conceptually:

```text
Container
   │
   ▼
Persistent Volume
   │
   ▼
Host Storage
```

This separates container lifecycle from persistent application state.

---

# 24. Why Persistence Is an Infrastructure Concern

Containers are disposable execution units.

Persistent state should therefore not depend on the lifetime of a container.

For example:

```text
PostgreSQL Container
       │
       ▼
postgres_data
```

If the container is recreated:

```text
Old Container
     X
     │
     ▼
New Container
     │
     ▼
Same Persistent Volume
```

application state can survive container replacement.

---

# 25. Infrastructure and Application Boundaries

A clear ownership model is essential.

| Concern               | Primary Owner               |
| --------------------- | --------------------------- |
| Linux host            | Infrastructure              |
| Host security         | Infrastructure              |
| Docker Engine         | Infrastructure              |
| Container topology    | Deployment / Infrastructure |
| PostgreSQL runtime    | Infrastructure              |
| Redis runtime         | Infrastructure              |
| MinIO runtime         | Infrastructure              |
| API business logic    | Application                 |
| Worker business logic | Application                 |
| Runtime reliability   | Application Runtime         |
| Prometheus            | Observability               |
| Grafana               | Observability               |
| Alertmanager          | Observability               |

This prevents responsibilities from becoming mixed.

---

# 26. Infrastructure vs Deployment

Infrastructure and deployment are related but not identical.

### Infrastructure

Answers:

> What execution environment exists?

Examples:

```text
Ubuntu
Docker
Networks
Volumes
Firewall
Deployment directories
Runner
```

### Deployment

Answers:

> Which application version is currently running?

Examples:

```text
API image
Worker image
Configuration
Deployment state
Release transition
Rollback
```

Therefore:

```text
Infrastructure
      │
      ▼
Provides execution environment
      │
      ▼
Deployment
      │
      ▼
Places application release into environment
```

---

# 27. Infrastructure vs Reliability

Reliability is also a separate concern.

Infrastructure provides:

```text
Host
CPU
Memory
Network
Storage
Containers
Dependencies
```

Reliability defines:

```text
Failure detection
Failure classification
Timeout
Retry
Recovery
Operational behavior
```

The relationship is:

```text
Infrastructure
      │
      ▼
Execution Environment
      │
      ▼
Runtime Reliability
      │
      ▼
Reliable Application Behavior
```

Infrastructure cannot guarantee application reliability by itself.

---

# 28. Infrastructure Security Boundary

Security controls exist at multiple levels.

```text
Host Security
     │
     ▼
Container Isolation
     │
     ▼
Network Exposure
     │
     ▼
Application Authentication
     │
     ▼
Application Authorization
```

The host security baseline therefore represents one layer of a broader defense-in-depth architecture.

It should not be interpreted as the complete application security model.

---

# 29. Host Firewall Model

The host uses UFW as part of the security baseline.

The intended model is:

```text
Incoming Traffic
       │
       ▼
      UFW
       │
       ├── denied by default
       │
       └── explicitly allowed services
```

The principle is least exposure.

Services should not be externally accessible merely because a container publishes a port.

---

# 30. Infrastructure Exposure

The infrastructure should distinguish between:

```text
Externally exposed services
```

and:

```text
Internal services
```

For example, application dependencies such as PostgreSQL and Redis generally exist primarily for internal service-to-service communication.

The intended topology is:

```text
External Client
      │
      ▼
Application Entry Point
      │
      ▼
Internal Network
      │
      ├── PostgreSQL
      ├── Redis
      └── MinIO
```

This minimizes unnecessary attack surface.

---

# 31. Infrastructure Health

Infrastructure health is observed at multiple levels.

## Host

```text
CPU
Memory
Disk
Filesystem
```

## Container Runtime

```text
Container availability
Container resource usage
```

## Dependencies

```text
PostgreSQL
Redis
MinIO
```

## Application

```text
API
Worker
```

## Observability

```text
Prometheus
Loki
Grafana
Alertmanager
```

This creates layered infrastructure health detection.

---

# 32. Infrastructure Failure Domains

Infrastructure failures can be classified by layer.

```text
Host Failure
    │
    ▼
Container Runtime Failure
    │
    ▼
Dependency Failure
    │
    ▼
Application Service Failure
    │
    ▼
Operation Failure
```

Examples:

### Host failure

VM becomes unavailable.

### Docker failure

Container runtime becomes unavailable.

### Dependency failure

PostgreSQL or Redis becomes unavailable.

### Application failure

API or Worker process crashes.

### Operation failure

A specific request or job fails while the service remains healthy.

These failure domains should not be conflated.

---

# 33. Infrastructure Recovery Model

Recovery should operate from the lowest affected layer upward.

Conceptually:

```text
Detect Failure
     │
     ▼
Identify Failure Domain
     │
     ▼
Determine Scope
     │
     ▼
Recover Lowest Affected Layer
     │
     ▼
Verify Health
     │
     ▼
Restore Application Service
     │
     ▼
Verify End-to-End Behavior
```

For example:

```text
PostgreSQL failure
      │
      ▼
Recover PostgreSQL
      │
      ▼
Verify PostgreSQL
      │
      ▼
Verify API readiness
      │
      ▼
Verify application operation
```

---

# 34. Infrastructure Validation

Infrastructure validation should occur at multiple levels.

## Static Validation

Verify:

```text
Ansible syntax
Docker Compose configuration
Configuration files
Deployment templates
```

## Provisioning Validation

Verify:

```text
Host state
Docker installation
Security baseline
Required directories
Required users
```

## Runtime Validation

Verify:

```text
Containers
Networks
Volumes
Service health
```

## Application Validation

Verify:

```text
API health
Worker health
Database connectivity
Queue operation
Storage operation
```

## Observability Validation

Verify:

```text
Prometheus scraping
Loki ingestion
Grafana datasources
Alertmanager connectivity
```

---

# 35. Infrastructure Reproducibility Model

The intended lifecycle is:

```text
Clean / Known Host
       │
       ▼
Ansible
       │
       ▼
Base Configuration
       │
       ▼
Docker
       │
       ▼
Deployment Runtime
       │
       ▼
Application Stack
       │
       ▼
Observability
       │
       ▼
Operationally Ready Environment
```

This allows the infrastructure to be recreated without relying on undocumented manual intervention.

---

# 36. Infrastructure Change Model

Infrastructure changes should follow a controlled lifecycle:

```text
Change Proposal
      │
      ▼
Infrastructure Code
      │
      ▼
Validation
      │
      ▼
Apply
      │
      ▼
Operational Verification
      │
      ▼
Documentation
```

The infrastructure repository therefore becomes the source of truth for intended infrastructure behavior.

---

# 37. Configuration Management

Infrastructure configuration should be separated from application secrets.

The infrastructure configuration model distinguishes:

```text
Static Configuration
      │
      ├── Compose topology
      ├── Network definitions
      ├── Service configuration
      └── Monitoring configuration

Runtime Configuration
      │
      ├── Environment variables
      └── Deployment parameters

Secrets
      │
      └── Sensitive credentials
```

Sensitive values should not be committed directly to source control.

Detailed configuration rules are documented separately.

---

# 38. Infrastructure and CI/CD

The GitHub Actions self-hosted runner exists within the infrastructure environment.

Conceptually:

```text
GitHub
   │
   ▼
GitHub Actions
   │
   ▼
Self-Hosted Runner
   │
   ▼
Mini-Write VM
   │
   ▼
Deployment
```

The runner therefore forms part of the deployment infrastructure.

Its lifecycle and security must be treated as infrastructure concerns.

---

# 39. Operational Directory Model

The deployment environment uses dedicated filesystem locations rather than distributing deployment state arbitrarily across the host.

The architecture distinguishes:

```text
Application Source
      │
      ▼
Deployment Runtime
      │
      ├── configuration
      ├── logs
      └── state
```

This improves:

* discoverability;
* backup planning;
* troubleshooting;
* operational consistency;
* automation.

---

# 40. Infrastructure Documentation Model

Infrastructure documentation is intentionally divided by responsibility.

```text
overview.md
    │
    └── infrastructure architecture

infrastructure-as-code.md
    │
    └── IaC model

ansible.md
    │
    └── Ansible implementation

host-provisioning.md
    │
    └── host preparation

docker.md
    │
    └── Docker architecture

security-baseline.md
    │
    └── host security

infrastructure-operations.md
    │
    └── day-2 operations
```

The goal is to avoid creating a single infrastructure document that becomes a mixture of architecture, implementation, commands, and troubleshooting.

---

# 41. Relationship to Other Documentation Domains

Infrastructure documentation is part of a larger documentation architecture.

```text
docs/
│
├── architecture/
│       └── system-level architecture
│
├── infrastructure/
│       └── execution foundation
│
├── deployment/
│       └── release and deployment lifecycle
│
├── operations/
│       └── operational procedures
│
├── reliability/
│       └── failure and recovery architecture
│
└── observability/
        └── telemetry and monitoring
```

The boundaries are intentional.

---

# 42. Infrastructure Dependency Graph

The major infrastructure dependencies can be represented as:

```text
                     Linux Host
                         │
                         ▼
                    Docker Engine
                         │
                  ┌──────┴──────┐
                  ▼             ▼
             App Stack    Observability
                  │             │
        ┌─────────┼────────┐    │
        ▼         ▼        ▼    │
      API       Worker   Dependencies
        │         │        │
        └────┬────┘        │
             │             │
             ├── PostgreSQL│
             ├── Redis     │
             └── MinIO     │
                           │
                           ▼
                      Telemetry
```

This dependency graph is useful when determining failure propagation.

---

# 43. Critical Infrastructure Dependencies

From the application's perspective:

```text
API
 ├── PostgreSQL
 ├── Redis
 └── MinIO

Worker
 ├── Redis
 ├── PostgreSQL
 └── MinIO
```

From the infrastructure perspective:

```text
All Services
      │
      ▼
Docker
      │
      ▼
Linux Host
```

Therefore the host represents a common failure domain.

---

# 44. Single-Node Reliability Implication

Because Mini-Write currently runs on a single VM:

```text
Host Failure
     │
     ▼
Entire Platform Impact
```

There is no infrastructure-level high availability across multiple hosts.

This is an explicit architectural constraint.

The project compensates through:

* reproducible provisioning;
* persistent volumes;
* health checks;
* observability;
* deployment state;
* recovery procedures;
* infrastructure automation.

It does not claim multi-node high availability.

---

# 45. Infrastructure Trade-offs

The current architecture intentionally trades infrastructure scale for operational clarity.

### Advantages

* simple topology;
* low infrastructure overhead;
* reproducible environment;
* easy debugging;
* explicit service boundaries;
* realistic operational workflow.

### Limitations

* single host failure domain;
* no automatic node failover;
* limited horizontal scaling;
* local persistence;
* manual capacity expansion;
* no cloud-native managed infrastructure.

These limitations are accepted because they match the current scope of the project.

---

# 46. Infrastructure Evolution Path

The current architecture provides a foundation for future infrastructure evolution.

A possible progression is:

```text
Current
Single VM
   │
   ▼
Improved Host Operations
   │
   ▼
Container Hardening
   │
   ▼
More Explicit Service Isolation
   │
   ▼
Multi-Node Runtime
   │
   ▼
Container Orchestration
   │
   ▼
Cloud / Managed Infrastructure
```

Such evolution should occur only when the project's operational requirements justify the additional complexity.

---

# 47. What Infrastructure Guarantees

The infrastructure architecture aims to guarantee:

```text
Known host configuration
Reproducible provisioning
Controlled container execution
Persistent state for stateful services
Defined network topology
Host security baseline
Infrastructure observability
Automated deployment foundation
Operational recovery capability
```

---

# 48. What Infrastructure Does Not Guarantee

Infrastructure alone does not guarantee:

```text
Business correctness
Application-level reliability
Zero downtime
Multi-node availability
Automatic failover
Distributed consistency
Successful deployment
Successful application operations
```

Those guarantees belong to other architectural layers.

---

# 49. Infrastructure Readiness Model

An infrastructure environment should be considered operationally ready only when:

```text
Host
  │
  ├── provisioned
  ├── secured
  └── reachable
        │
        ▼
Docker
  │
  ├── installed
  ├── configured
  └── operational
        │
        ▼
Application Stack
  │
  ├── API
  ├── Worker
  ├── PostgreSQL
  ├── Redis
  └── MinIO
        │
        ▼
Observability
  │
  ├── Prometheus
  ├── Loki
  ├── Grafana
  └── Alertmanager
        │
        ▼
Operational Verification
```

Only after these layers are verified should the environment be considered ready for application deployment.

---

# 50. Infrastructure Engineering Principles

The infrastructure architecture follows these principles.

## Principle 1 — Infrastructure as Code

Infrastructure configuration belongs in version-controlled code.

## Principle 2 — Reproducibility

Manual configuration should not be a prerequisite for rebuilding the environment.

## Principle 3 — Least Exposure

Services should expose only what is required.

## Principle 4 — Explicit Boundaries

Infrastructure components should have clear responsibilities.

## Principle 5 — Persistent State Separation

Stateful data must not depend on container lifetime.

## Principle 6 — Observable Infrastructure

Infrastructure failures must generate operational evidence.

## Principle 7 — Deterministic Deployment

Application deployment should operate against a known infrastructure state.

## Principle 8 — Recoverability

Infrastructure should be designed so that failures can be diagnosed and recovered systematically.

## Principle 9 — Controlled Complexity

Infrastructure complexity should be introduced only when it solves an actual operational requirement.

## Principle 10 — Documentation as Operational Knowledge

Infrastructure documentation must describe not only what exists, but why it exists and how it is operated.

---

# 51. Infrastructure Mental Model

The most useful way to reason about Mini-Write infrastructure is:

```text
                HOST
                 │
                 ▼
              SECURITY
                 │
                 ▼
              DOCKER
                 │
       ┌─────────┼─────────┐
       ▼         ▼         ▼
   APPLICATION DEPENDENCIES OBSERVABILITY
       │         │         │
       └─────────┼─────────┘
                 ▼
             DEPLOYMENT
                 │
                 ▼
             OPERATIONS
```

Each layer has a different responsibility.

A failure should therefore first be mapped to its layer before a recovery action is selected.

---

# 52. Infrastructure Architecture Summary

Mini-Write infrastructure is a single-node, Linux-based, Dockerized execution platform managed through Infrastructure as Code.

Its architecture consists of:

```text
VMware
  │
  ▼
Ubuntu Host
  │
  ├── Security Baseline
  ├── Docker Engine
  ├── Deployment Runtime
  └── Self-Hosted CI Runner
          │
          ▼
     Docker Compose
          │
    ┌─────┼─────────────────────────┐
    │     │                         │
    ▼     ▼                         ▼
   API  Worker                 Observability
    │     │                         │
    └──┬──┘                         │
       │                            │
       ▼                            │
 ┌───────────────┐                 │
 │ Infrastructure│                 │
 │ Dependencies  │                 │
 ├───────────────┤                 │
 │ PostgreSQL    │                 │
 │ Redis         │                 │
 │ MinIO         │                 │
 └───────────────┘                 │
                                    │
                                    ▼
                     Prometheus / Loki /
                     Grafana / Alertmanager
```

The architecture deliberately separates:

```text
Host Infrastructure
        │
        ▼
Container Infrastructure
        │
        ▼
Application Dependencies
        │
        ▼
Application Services
        │
        ▼
Observability
        │
        ▼
Deployment and Operations
```

This separation provides the foundation required for Mini-Write to evolve from a simple containerized application into a progressively more reliable and operationally mature platform.

```
```
