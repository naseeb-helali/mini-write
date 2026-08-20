# Architecture Overview

## 1. Purpose

This document provides the architectural entry point for the Mini-Write platform.

It explains the overall architectural shape of the system, the major engineering boundaries, the responsibilities of its principal layers, and the relationships between them.

This document intentionally remains at the architectural overview level.

Detailed implementation and operational behavior are documented separately in:

- [System Architecture](./system-architecture.md)
- [Service Architecture](./service-architecture.md)
- [Networking](./networking.md)
- [Runtime Architecture](./runtime-architecture.md)

Infrastructure-specific concerns are documented under:

- [Infrastructure Overview](../infrastructure/overview.md)
- [Infrastructure as Code](../infrastructure/infrastructure-as-code.md)

Reliability-specific concerns are documented under:

- [Reliability](../reliability/reliability.md)
- [Failure Model](../reliability/failure-model.md)
- [Runtime Reliability](../reliability/runtime-reliability.md)

Observability-specific concerns are documented under:

- [Observability](../observability/observability.md)

---

# 2. System Context

Mini-Write is a production-oriented distributed-system simulation designed to exercise real engineering concerns across application development, infrastructure, deployment, reliability, and observability.

The system is intentionally operated on a single staging host rather than a cloud or multi-node production platform.

The environment therefore represents a **single-node distributed application**:

- multiple application and infrastructure services
- isolated container networks
- persistent service state
- asynchronous background processing
- infrastructure automation
- centralized observability
- runtime reliability controls
- deployment automation
- operational health and failure detection

The single-node constraint does not eliminate distributed-system concerns.

Instead, distribution exists at the service and runtime level:

```text
                    External Traffic
                           │
                           ▼
                    ┌─────────────┐
                    │   Gateway   │
                    │   Nginx     │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │     API     │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
          PostgreSQL      Redis       MinIO
              │            │            │
              │            ▼            │
              │       ┌──────────┐      │
              └──────►│  Worker  │◄─────┘
                      └──────────┘

                    Observability
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
      Prometheus          Loki          Alertmanager
          │                │                │
          └────────────────┼────────────────┘
                           ▼
                        Grafana
````

The diagram represents the architectural relationships rather than a deployment topology specification. The detailed topology is defined in [System Architecture](./system-architecture.md).

---

# 3. Architectural Model

Mini-Write is organized around several cooperating architectural layers.

At the highest level:

```text
┌─────────────────────────────────────────────────────┐
│                 Application Layer                   │
│                                                     │
│        API                  Worker                  │
│                                                     │
├─────────────────────────────────────────────────────┤
│                 Runtime Layer                       │
│                                                     │
│   Execution Context • Operations • Reliability      │
│   Failure Classification • Runtime Boundaries       │
│                                                     │
├─────────────────────────────────────────────────────┤
│                Infrastructure Layer                 │
│                                                     │
│ PostgreSQL • Redis • MinIO • Docker • Host Runtime │
│                                                     │
├─────────────────────────────────────────────────────┤
│                Observability Layer                   │
│                                                     │
│ Metrics • Logs • Alerts • Dashboards                │
│                                                     │
├─────────────────────────────────────────────────────┤
│             Infrastructure Automation                │
│                                                     │
│                     Ansible                         │
│                                                     │
├─────────────────────────────────────────────────────┤
│                    Host Layer                       │
│                                                     │
│              Ubuntu Staging VM                      │
└─────────────────────────────────────────────────────┘
```

These layers are related but are not interchangeable.

Each layer has a defined responsibility and should not absorb responsibilities belonging to another layer.

---

# 4. Core Architectural Components

The platform is composed of the following principal components.

| Component             | Primary Responsibility                        |
| --------------------- | --------------------------------------------- |
| Gateway               | External HTTP entry point and reverse proxy   |
| API                   | Synchronous application/API processing        |
| Worker                | Asynchronous background job processing        |
| PostgreSQL            | Persistent relational application state       |
| Redis                 | Queue and cache infrastructure                |
| MinIO                 | Object storage                                |
| Docker                | Container execution and service isolation     |
| Ansible               | Infrastructure provisioning and configuration |
| GitHub Actions Runner | CI/CD execution on the staging host           |
| Prometheus            | Metrics collection and alert rule evaluation  |
| Loki                  | Centralized log storage and querying          |
| Promtail              | Log collection and forwarding                 |
| Alertmanager          | Alert routing and grouping                    |
| Grafana               | Operational visualization                     |
| Node Exporter         | Host-level metrics                            |
| cAdvisor              | Container-level metrics                       |
| Redis Exporter        | Redis metrics                                 |
| PostgreSQL Exporter   | PostgreSQL metrics                            |

The responsibilities above describe architectural ownership.

They do not imply that each component represents an independent deployment host.

---

# 5. Application Architecture

The application layer contains two primary execution services:

```text
Application
│
├── API
│   ├── HTTP interface
│   ├── authentication
│   ├── user operations
│   ├── ID upload workflow
│   └── health endpoints
│
└── Worker
    ├── background processing
    ├── queue consumption
    ├── job execution
    └── asynchronous reliability
```

The API and Worker have different execution models.

### API

The API is primarily request-driven.

Its execution lifecycle is associated with an incoming HTTP request:

```text
HTTP Request
    │
    ▼
Runtime Bootstrap
    │
    ▼
Runtime Guard
    │
    ▼
Operation Resolution
    │
    ▼
Reliability Activation
    │
    ▼
Application Operation
    │
    ▼
Infrastructure Operations
    │
    ▼
HTTP Response
```

### Worker

The Worker is primarily job-driven.

Its execution lifecycle is associated with background work retrieved from the queue.

The Worker therefore adapts the Runtime Reliability architecture to an asynchronous execution model rather than reproducing the HTTP request lifecycle.

This distinction is important:

> API and Worker share architectural reliability principles, but their execution boundaries are different.

Detailed service responsibilities are documented in [Service Architecture](./service-architecture.md).

---

# 6. Runtime as an Architectural Layer

Reliability is not implemented exclusively inside individual application functions.

The platform introduces a dedicated Runtime layer between application execution and infrastructure operations.

Conceptually:

```text
Application Operation
        │
        ▼
Runtime Context
        │
        ├── Operation Identity
        ├── Execution Identity
        ├── Execution State
        ├── Reliability Policy
        ├── Failure State
        ├── Metadata
        └── Recovery State
        │
        ▼
Infrastructure Boundary
        │
        ├── PostgreSQL
        ├── Redis
        └── MinIO
```

The Runtime provides a common execution model for:

* operation identity
* execution identity
* lifecycle state
* reliability policy
* timeout behavior
* retry behavior
* failure classification
* recovery eligibility
* execution metadata
* reliability observability

The Runtime therefore acts as an **operational control layer** rather than being merely a utility library.

The complete Runtime architecture is documented in [Runtime Architecture](./runtime-architecture.md).

---

# 7. Infrastructure Architecture

The platform infrastructure is intentionally reproducible.

Infrastructure configuration is maintained as code using Ansible.

The high-level relationship is:

```text
Ansible
   │
   ├── Base Host Configuration
   │
   ├── Docker Installation
   │
   ├── Deployment Runtime
   │
   ├── GitHub Actions Runner
   │
   └── Security Baseline
           │
           ▼
      Staging Host
           │
           ▼
        Docker
           │
           ▼
     Mini-Write Services
```

The Ansible playbook composes the principal infrastructure roles:

```text
site.yml
 │
 ├── base
 ├── docker
 ├── deploy_runtime
 ├── github_runner
 └── security_baseline
```

Infrastructure automation is therefore not an external operational procedure.

It is part of the system architecture.

Detailed infrastructure behavior is documented under [Infrastructure](../infrastructure/overview.md).

---

# 8. Deployment Runtime

The application services are deployed through a controlled runtime directory on the staging host.

The deployment structure provides separation between:

* deployment configuration
* immutable runtime assets
* mutable runtime state
* environment configuration
* deployment logs
* runtime modules
* observability configuration
* metrics artifacts

The deployment runtime is therefore a boundary between:

```text
Repository / CI
       │
       ▼
Deployment Automation
       │
       ▼
/opt/deploy
       │
       ├── compose
       ├── proxy
       ├── scripts
       ├── state
       ├── env
       ├── logs
       ├── metrics
       └── observability
```

The exact filesystem contract and deployment procedures belong to the infrastructure and deployment documentation rather than this overview.

---

# 9. Network Architecture

The containerized application uses logical network separation.

The principal application networks are:

```text
frontend-network
        │
        ├── Gateway
        └── API

backend-network
        │
        ├── API
        ├── Worker
        ├── PostgreSQL
        ├── Redis
        ├── MinIO
        └── Observability services
```

This separation establishes an architectural communication boundary.

The Gateway is the externally exposed application entry point.

The API participates in both frontend and backend communication because it receives requests from the Gateway while also communicating with backend dependencies.

The Worker operates on the backend network because its primary dependencies are internal services.

Detailed network topology, exposure boundaries, and communication paths are documented in [Networking](./networking.md).

---

# 10. State and Persistence

The system contains multiple categories of state.

### Application State

PostgreSQL stores persistent relational application state.

### Queue State

Redis provides queue infrastructure and persistent queue-related state through its configured persistence mechanism.

### Object State

MinIO provides object storage for uploaded files.

### Observability State

The observability stack maintains its own persistent state for metrics, logs, dashboards, and alerting data where configured.

The architecture therefore distinguishes between:

```text
Application State
       │
       ├── PostgreSQL
       ├── Redis
       └── MinIO

Operational State
       │
       ├── Deployment State
       ├── Logs
       └── Metrics Artifacts

Observability State
       │
       ├── Prometheus
       ├── Loki
       ├── Grafana
       └── Alertmanager
```

This distinction becomes important during deployment, recovery, and failure analysis.

---

# 11. Observability Architecture

Observability is implemented as a separate platform capability rather than being embedded into a single service.

The architecture collects three primary signal categories:

```text
                    ┌───────────────┐
                    │   Mini-Write  │
                    └───────┬───────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
           Metrics         Logs         Events
              │             │
              ▼             ▼
         Prometheus        Loki
              │             │
              └──────┬──────┘
                     ▼
                  Grafana
                     │
                     ▼
                Operators

Prometheus
    │
    ▼
Alert Rules
    │
    ▼
Alertmanager
```

Metrics originate from multiple architectural layers:

* API
* Worker
* Redis
* PostgreSQL
* Host
* Containers
* Observability services

Logs are collected from Docker containers and deployment log files.

Grafana provides the operational visualization layer.

Prometheus and Alertmanager provide the detection and alerting path.

Detailed observability behavior is documented under [Observability](../observability/observability.md).

---

# 12. Reliability Architecture

Reliability is treated as a cross-cutting architectural capability.

It is not limited to:

* retrying requests
* restarting containers
* adding health checks
* catching exceptions

Instead, reliability is distributed across several architectural boundaries.

```text
                  Reliability Architecture
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
 Failure Model        Runtime Control    Operational Detection
        │                  │                  │
        ▼                  ▼                  ▼
 Failure Taxonomy     Policies           Metrics
 Failure Boundaries   Timeouts           Logs
 Propagation          Retries            Alerts
 Detection            Recovery           Health Checks
 Handling             Classification     Dashboards
```

The Runtime provides execution-level reliability mechanisms.

The infrastructure provides containment and service-level isolation.

The observability system provides failure detection and operational visibility.

The deployment system provides controlled change.

These mechanisms cooperate but retain separate responsibilities.

---

# 13. Health Model

The application exposes explicit health semantics.

The API distinguishes at least two operational states:

### Liveness

Liveness answers:

> Is the service process alive?

### Readiness

Readiness answers:

> Is the service currently capable of serving its intended workload?

This distinction allows infrastructure and deployment systems to differentiate between:

```text
Process Failure
      vs.
Service Unavailability
```

The health model is part of the operational architecture and is consumed by the container orchestration/deployment layer through service health checks.

Detailed health behavior is documented in [Health Checks](../operations/health-checks.md).

---

# 14. Failure and Recovery Model

Failures are treated as architectural events rather than merely JavaScript exceptions.

At a high level:

```text
Failure
   │
   ▼
Classification
   │
   ▼
Boundary Identification
   │
   ▼
Detection
   │
   ▼
Handling Decision
   │
   ├── Contain
   ├── Abort
   ├── Retry
   ├── Recover
   ├── Isolate
   ├── Observe
   └── Escalate
```

The Runtime implements part of this model for application execution.

Infrastructure and operational systems implement additional containment and detection mechanisms.

The complete failure model is documented in [Failure Model](../reliability/failure-model.md).

---

# 15. Deployment and Change Flow

The system follows an automated deployment path.

At a high level:

```text
Developer
    │
    ▼
Git Repository
    │
    ▼
GitHub Actions
    │
    ▼
Self-Hosted Runner
    │
    ▼
Deployment Runtime
    │
    ▼
Docker Compose
    │
    ▼
Mini-Write Services
```

The deployment architecture separates:

* source code
* build artifacts/images
* deployment configuration
* deployment state
* runtime environment
* service execution

Deployment state is persisted independently from the application containers.

The deployment system therefore has an explicit operational state model rather than relying solely on container state.

Detailed deployment behavior is documented in [Deployment](../deployment/deployment.md).

---

# 16. Security Boundaries

Security controls exist at multiple layers.

### Host Layer

The host uses a security baseline including:

* UFW firewall policy
* SSH hardening
* controlled inbound access
* controlled service exposure

### Container Layer

Container network separation limits communication paths between services.

### Application Layer

The API provides authentication and authorization mechanisms.

### Infrastructure Automation Layer

Ansible manages host configuration as code rather than relying on undocumented manual changes.

Security is therefore considered a layered concern.

The security baseline is documented in [Security Baseline](../infrastructure/security-baseline.md).

---

# 17. Architectural Boundaries

The platform can be understood through several important boundaries.

| Boundary                     | Purpose                                                                      |
| ---------------------------- | ---------------------------------------------------------------------------- |
| External / Gateway           | Controls entry into the application                                          |
| Gateway / API                | Separates external routing from application processing                       |
| API / Worker                 | Separates synchronous and asynchronous execution                             |
| Application / Infrastructure | Prevents business operations from directly owning infrastructure reliability |
| Runtime / Application        | Provides a common execution control model                                    |
| Runtime / Dependency         | Centralizes infrastructure-operation reliability                             |
| Container / Network          | Controls service communication                                               |
| Host / Container             | Separates infrastructure runtime from workloads                              |
| Application / Observability  | Separates application execution from operational telemetry                   |
| Repository / Host            | Separates desired infrastructure state from deployed runtime state           |

These boundaries are central to maintaining the system as it evolves.

---

# 18. Architectural Principles

The architecture follows several governing principles.

## 18.1 Separation of Responsibility

Each architectural layer should own a clearly defined responsibility.

A component should not become the accidental owner of concerns belonging to another layer.

---

## 18.2 Reliability Before Complexity

Reliability mechanisms should solve concrete operational problems before additional infrastructure complexity is introduced.

The architecture therefore favors explicit mechanisms over unnecessary platform abstraction.

---

## 18.3 Explicit Boundaries

Communication between application components and infrastructure dependencies should cross explicit boundaries.

The Runtime infrastructure boundary is one example of this principle.

---

## 18.4 Deterministic Behavior

Operational behavior should be predictable.

Examples include:

* explicit runtime states
* explicit reliability policies
* explicit retry limits
* explicit health semantics
* explicit deployment state
* explicit network boundaries

---

## 18.5 Infrastructure as Code

Infrastructure configuration should be reproducible and reviewable.

Ansible is therefore treated as the source of truth for host provisioning and infrastructure configuration.

---

## 18.6 Observability as an Architectural Capability

Observability should not be added after the system fails.

Metrics, logs, health signals, and alerts are part of the operational architecture.

---

## 18.7 Failure-Aware Design

Failure scenarios are considered during architectural design rather than being treated exclusively as runtime exceptions.

---

## 18.8 Progressive Complexity

The architecture is designed to support future evolution toward more sophisticated infrastructure without pretending that the current single-node environment is already a multi-node production platform.

For example:

```text
Current
Single Host
    │
    └── Docker / Compose
             │
             └── Multiple Services

Potential Future
Multiple Hosts
    │
    └── Container Orchestration
             │
             └── Distributed Service Runtime
```

The current architecture should therefore remain honest about its operational environment while preserving clean architectural boundaries that can evolve later.

---

# 19. Current Architectural Scope

The current system provides the following major capabilities:

```text
Application
    ├── API
    └── Worker

Infrastructure
    ├── Ubuntu staging host
    ├── Docker
    ├── Ansible
    └── GitHub Actions self-hosted runner

Data Services
    ├── PostgreSQL
    ├── Redis
    └── MinIO

Reliability
    ├── Runtime execution context
    ├── Reliability policies
    ├── Timeouts
    ├── Retry control
    ├── Failure classification
    └── Recovery state

Observability
    ├── Prometheus
    ├── Loki
    ├── Promtail
    ├── Alertmanager
    ├── Grafana
    ├── Node Exporter
    ├── cAdvisor
    ├── Redis Exporter
    └── PostgreSQL Exporter

Operations
    ├── Health checks
    ├── Deployment state
    ├── Deployment logs
    ├── Metrics
    ├── Alerts
    └── Dashboards
```

---

# 20. Architectural Evolution

Mini-Write is developed as an evolving engineering system rather than as a static application.

The architecture has progressively introduced capabilities across:

```text
Application Foundation
        ↓
Infrastructure Reproducibility
        ↓
Observability
        ↓
Reliability
        ↓
Runtime Reliability
        ↓
Operational Integration
        ↓
Continuous Improvement
```

Each capability builds on the previous architectural foundation.

The purpose of this evolution is not to maximize the number of technologies used.

The purpose is to progressively establish stronger engineering properties:

```text
Reproducibility
       ↓
Visibility
       ↓
Reliability
       ↓
Operational Control
       ↓
Feedback
       ↓
Continuous Improvement
```

The historical and architectural evolution of the project is documented in:

* [Engineering Evolution](../project/engineering-evolution.md)
* [Roadmap](../project/roadmap.md)

---

# 21. Documentation Map

This document provides the architectural entry point.

Readers should continue according to their objective.

### Understand the complete system

→ [System Architecture](./system-architecture.md)

### Understand individual services

→ [Service Architecture](./service-architecture.md)

### Understand communication and network boundaries

→ [Networking](./networking.md)

### Understand Runtime architecture

→ [Runtime Architecture](./runtime-architecture.md)

### Understand infrastructure

→ [Infrastructure Overview](../infrastructure/overview.md)

### Understand deployment

→ [Deployment](../deployment/deployment.md)

### Understand reliability

→ [Reliability](../reliability/reliability.md)

### Understand observability

→ [Observability](../observability/observability.md)

### Operate the system

→ [Operations](../operations/operations.md)

### Troubleshoot failures

→ [Troubleshooting](../troubleshooting/common-issues.md)

### Find configuration and technical reference information

→ [Reference](../reference/configuration-reference.md)

---

# 22. Architectural Reading Order

For readers who are new to the project, the recommended reading sequence is:

```text
Architecture Overview
        │
        ▼
System Architecture
        │
        ▼
Service Architecture
        │
        ├───────────────┐
        ▼               ▼
Networking          Runtime Architecture
        │               │
        └───────┬───────┘
                ▼
        Infrastructure
                │
                ▼
        Deployment
                │
        ┌───────┴────────┐
        ▼                ▼
   Reliability      Observability
        │                │
        └───────┬────────┘
                ▼
            Operations
                │
                ▼
         Troubleshooting
```

This ordering moves from:

```text
What the system is
        ↓
How it is structured
        ↓
How components communicate
        ↓
How execution is controlled
        ↓
How infrastructure is provisioned
        ↓
How the system is deployed
        ↓
How it behaves under failure
        ↓
How it is observed
        ↓
How it is operated
```

---

# 23. Architectural Contract

This document establishes the high-level vocabulary used by the remainder of the documentation.

The following concepts should therefore retain consistent meanings throughout the repository:

* **API** — synchronous application service
* **Worker** — asynchronous background processing service
* **Runtime** — execution control and reliability layer
* **Infrastructure Boundary** — controlled interface between application execution and infrastructure dependencies
* **Infrastructure** — host, container runtime, data services, and provisioning mechanisms
* **Observability** — metrics, logs, alerts, and dashboards used to understand system behavior
* **Reliability** — architectural capability for predictable behavior under abnormal conditions
* **Deployment Runtime** — host-side filesystem and execution structure used to deploy and operate the application
* **Failure Boundary** — architectural boundary within which a failure is detected, contained, and handled
* **Operational State** — runtime state required to understand and control deployment and service operation

Future documentation should build upon these definitions rather than redefining them independently.

---

# 24. Summary

Mini-Write is structured as a layered, containerized, reliability-oriented distributed application operated on a reproducible single-node staging infrastructure.

Its architecture separates:

```text
Application
Infrastructure
Runtime
Reliability
Observability
Deployment
Operations
```

while connecting them through explicit boundaries.

The most important architectural property is therefore not the individual technologies used by the project, but the separation of responsibilities between them.

At a high level:

```text
                 Mini-Write
                     │
        ┌────────────┼────────────┐
        │            │            │
   Application   Infrastructure  Operations
        │            │            │
        ▼            ▼            ▼
      API/        Ansible/     Observability/
     Worker       Docker       Health/Alerts
        │            │            │
        └────────────┼────────────┘
                     │
                     ▼
              Runtime Reliability
                     │
                     ▼
             Controlled Execution
                     │
                     ▼
             Predictable Operation
```

The subsequent architecture documents provide the implementation-level detail required to understand and operate these boundaries.

```
