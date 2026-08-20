# Mini-Write

A production-oriented DevOps engineering project designed to simulate the architecture, deployment, reliability, observability, and operational practices of a real distributed application platform within a controlled local environment.

Mini-Write is not primarily an application-development exercise.

It is an engineering platform built to explore how application services, infrastructure, deployment automation, reliability mechanisms, observability, and operational practices fit together as one coherent system.

---

## 1. Project Overview

Mini-Write consists of application services and supporting infrastructure deployed as a containerized distributed system.

At a high level:

```text
                         Mini-Write Platform
                                │
                ┌───────────────┴───────────────┐
                │                               │
          Application Layer              Infrastructure Layer
                │                               │
        ┌───────┴───────┐              ┌────────┴────────┐
        │               │              │                 │
       API            Worker       PostgreSQL          Redis
        │               │                                │
        └───────┬───────┘                                │
                │                                        │
                └────────────────┬───────────────────────┘
                                 │
                               MinIO
                                 │
                                 ▼
                         Operational Platform
                                 │
             ┌───────────────────┼───────────────────┐
             │                   │                   │
         Prometheus             Loki            Alertmanager
             │                   │                   │
             └───────────────────┴───────────────────┘
                                 │
                              Grafana
````

The platform is intentionally designed around operational concerns such as:

* reproducible infrastructure
* service isolation
* deterministic deployment
* runtime reliability
* failure classification
* retry and timeout behavior
* health verification
* structured logging
* metrics
* alerting
* operational troubleshooting

---

# 2. Engineering Goals

The project is designed around the following engineering goals.

### Reproducibility

Infrastructure and deployment behavior should be reproducible rather than dependent on undocumented manual configuration.

### Reliability

Failures are treated as architectural events that require explicit detection, classification, containment, recovery, and observability.

### Observability

The system should provide enough evidence to answer operational questions such as:

* What failed?
* Which component failed?
* When did it fail?
* Which dependency was involved?
* Was the failure transient?
* Was a retry attempted?
* Did recovery succeed?
* What was the effect on the system?

### Operational Determinism

The same operational inputs should produce predictable behavior.

### Maintainability

Infrastructure, runtime behavior, deployment logic, and documentation are separated into explicit domains.

### Progressive Engineering

The platform evolves through distinct engineering capabilities rather than introducing operational complexity prematurely.

---

# 3. Current Architecture

The platform is composed of several architectural layers.

```text
┌──────────────────────────────────────────────┐
│                Application                  │
│                                              │
│              API + Worker                   │
└──────────────────────┬───────────────────────┘
                       │
┌──────────────────────▼───────────────────────┐
│              Runtime Reliability             │
│                                              │
│ Execution Context                            │
│ Operation Resolution                         │
│ Reliability Policies                         │
│ Timeout / Retry / Recovery                   │
│ Failure Classification                       │
│ Infrastructure Boundaries                    │
└──────────────────────┬───────────────────────┘
                       │
┌──────────────────────▼───────────────────────┐
│              Infrastructure                 │
│                                              │
│ Docker / PostgreSQL / Redis / MinIO         │
│ Host / Networking / Security Baseline       │
└──────────────────────┬───────────────────────┘
                       │
┌──────────────────────▼───────────────────────┐
│               Observability                  │
│                                              │
│ Prometheus / Loki / Promtail                │
│ Alertmanager / Grafana                      │
└──────────────────────┬───────────────────────┘
                       │
┌──────────────────────▼───────────────────────┐
│                Operations                   │
│                                              │
│ Deployment / Health / Incidents / Recovery  │
└──────────────────────────────────────────────┘
```

Detailed architectural information is available under:

`docs/architecture/`

---

# 4. Services

## API

The API provides the HTTP-facing application interface.

Its responsibilities include:

* authentication
* user operations
* profile access
* ID-card upload
* health endpoints
* metrics exposure

The API also integrates with the Reliability Runtime.

Relevant runtime concepts include:

* execution context
* operation context
* reliability policies
* infrastructure execution boundaries
* timeout handling
* retry handling
* failure classification
* runtime completion

---

## Worker

The Worker processes asynchronous background jobs.

Its architecture adapts the Runtime Reliability model to a background-job execution environment rather than an HTTP request lifecycle.

The Worker is integrated with Redis/BullMQ and participates in the application's asynchronous processing workflow.

---

## PostgreSQL

PostgreSQL provides persistent relational data storage.

It is used by the application for persistent user-related data.

---

## Redis

Redis provides infrastructure for asynchronous job processing and queue coordination.

The API uses Redis to enqueue background processing work, while the Worker consumes the resulting jobs.

---

## MinIO

MinIO provides object storage for uploaded files.

The ID-upload workflow therefore crosses multiple infrastructure boundaries:

```text
API
 │
 ├── MinIO
 ├── PostgreSQL
 └── Redis
```

---

# 5. Infrastructure

Infrastructure is managed using Infrastructure as Code with Ansible.

The infrastructure layer covers:

* host preparation
* Docker installation/configuration
* deployment directories
* GitHub Actions runner
* security baseline
* deployment runtime
* operational infrastructure configuration

Infrastructure documentation is available under:

`docs/infrastructure/`

The infrastructure architecture is intentionally designed around reproducibility rather than manual server configuration.

---

# 6. Deployment

Deployment is designed around a local staging environment running on a dedicated Ubuntu VM.

The deployment model separates:

```text
Infrastructure Provisioning
        │
        ▼
Application Deployment
        │
        ▼
Health Verification
        │
        ▼
Operational Validation
```

Deployment documentation is available under:

`docs/deployment/`

---

# 7. CI/CD

The project uses GitHub Actions with a self-hosted runner hosted inside the project VM.

The runner is associated with the staging environment and is used to execute the project's CI/CD workflow.

The deployment pipeline is documented in:

`docs/deployment/ci-cd.md`

The CI/CD layer is intentionally treated as part of the operational architecture rather than merely as a build script.

---

# 8. Reliability Architecture

Reliability is implemented as an architectural capability.

The Runtime Reliability model provides a controlled execution boundary around application operations.

Conceptually:

```text
Operation
    │
    ▼
Execution Context
    │
    ▼
Operation Resolution
    │
    ▼
Reliability Policy
    │
    ▼
Reliability Activation
    │
    ▼
Infrastructure Operation
    │
    ├── Timeout
    ├── Failure Classification
    ├── Retry
    └── Recovery
    │
    ▼
Runtime Outcome
```

The runtime also maintains execution information such as:

* request/execution identity
* execution state
* operation
* reliability policy
* attempts
* retries
* failure classification
* recovery state
* timestamps

Reliability documentation is available under:

`docs/reliability/`

---

# 9. Failure Engineering

Failures are not treated as generic exceptions.

The system distinguishes different failure classes, including:

* timeout
* dependency failure
* validation failure
* authentication failure
* authorization failure
* internal failure

The classification influences whether a failure can safely be retried or recovered.

The general model is:

```text
Failure
   │
   ▼
Classification
   │
   ▼
Recoverability
   │
   ▼
Retryability
   │
   ▼
Runtime Decision
   │
   ├── Retry
   ├── Recover
   └── Propagate
```

Detailed failure engineering documentation is available in:

`docs/reliability/failure-model.md`

---

# 10. Observability

The platform uses a multi-signal observability architecture.

```text
                    Application / Infrastructure
                              │
                ┌─────────────┴─────────────┐
                │                           │
             Metrics                      Logs
                │                           │
                ▼                           ▼
           Prometheus                     Loki
                │                           ▲
                │                        Promtail
                │                           ▲
                │                     Docker / Host Logs
                │
                └─────────────┬─────────────┘
                              │
                              ▼
                           Grafana
                              │
                              ▼
                        Operational View
```

The observability stack includes:

* Prometheus
* Loki
* Promtail
* Alertmanager
* Grafana
* Node Exporter
* cAdvisor
* PostgreSQL exporter
* Redis exporter

Observability documentation is available under:

`docs/observability/`

---

# 11. Metrics

Metrics are used at multiple levels.

### Application Metrics

Examples include:

* HTTP request count
* HTTP request duration
* HTTP errors
* authentication attempts
* upload activity

### Business Metrics

Examples include:

* user registrations
* successful logins
* ID uploads
* background jobs enqueued

### Worker Metrics

Examples include:

* processed jobs
* failed jobs
* retries
* active jobs
* queue depth
* job duration

### Runtime Metrics

Runtime reliability exposes execution-level signals such as:

* runtime operations
* runtime retries
* runtime failures
* runtime operation duration

### Infrastructure Metrics

The observability platform also collects:

* host CPU
* host memory
* filesystem utilization
* container metrics
* PostgreSQL metrics
* Redis metrics

---

# 12. Logging

Application and runtime logs are emitted as structured JSON.

Logs include common operational context such as:

```text
timestamp
level
service
environment
request_id
operation_id
execution_id
```

Runtime-specific logs can additionally identify:

```text
dependency
failure_type
attempt
next_attempt
outcome
```

Logs are collected through Promtail and stored in Loki.

---

# 13. Alerting

Prometheus evaluates alert rules covering multiple operational domains.

Current alert categories include:

### Infrastructure

* Node Exporter availability
* CPU utilization
* memory utilization
* disk availability

### API

* API availability
* API error rate
* API latency

### Worker

* Worker availability
* queue backlog
* job failure rate
* job latency
* storage latency
* database latency

Alertmanager groups and routes alerts according to severity and operational dimensions.

---

# 14. Dashboards

Grafana provides operational dashboards for different system domains.

Current dashboard areas include:

```text
System
Application
Queue
Deployment
Incidents
```

The dashboards are provisioned from files rather than being treated as manually configured UI state.

This allows dashboard configuration to remain part of the repository and deployment process.

---

# 15. Health Model

The API exposes health endpoints for different purposes.

### Liveness

```text
/health/live
```

Liveness answers:

> Is the service process alive?

It is intentionally lightweight.

### Readiness

```text
/health/ready
```

Readiness performs actual service verification and therefore represents whether the application is ready to serve operational traffic.

The distinction is important:

```text
Liveness
    ≠
Readiness
```

A service may be alive while not being ready.

Detailed health behavior is documented in:

`docs/operations/health-checks.md`

---

# 16. Development

Development documentation is organized separately from production operations.

Start here:

`docs/development/getting-started.md`

Then continue with:

* `docs/development/local-development.md`
* `docs/development/testing.md`

The development documentation explains how to prepare the environment, run the project, and validate behavior.

---

# 17. Documentation Structure

The documentation is organized by engineering domain rather than by implementation chronology.

```text
docs/
│
├── architecture/
├── infrastructure/
├── development/
├── deployment/
├── operations/
├── reliability/
├── observability/
├── reference/
├── troubleshooting/
└── project/
```

### Architecture

System structure, service boundaries, networking, and runtime architecture.

### Infrastructure

Infrastructure as Code, Ansible, host provisioning, Docker, security, and infrastructure operations.

### Development

Developer setup, local development, and testing.

### Deployment

Deployment behavior, configuration, and CI/CD.

### Operations

Operational procedures, health checks, and incident response.

### Reliability

Reliability architecture, failure engineering, runtime reliability, and recovery.

### Observability

Metrics, logging, alerting, and dashboards.

### Reference

Stable technical reference material such as configuration, environment variables, runtime interfaces, and metrics.

### Troubleshooting

Problem-oriented guidance for common, infrastructure, deployment, and runtime issues.

### Project

Long-term engineering evolution and roadmap information.

---

# 18. Recommended Reading Order

For someone new to the project:

```text
README.md
    │
    ▼
docs/architecture/overview.md
    │
    ▼
docs/architecture/system-architecture.md
    │
    ▼
docs/architecture/service-architecture.md
    │
    ▼
docs/infrastructure/overview.md
    │
    ▼
docs/development/getting-started.md
    │
    ▼
docs/deployment/deployment.md
    │
    ▼
docs/operations/operations.md
    │
    ▼
docs/reliability/reliability.md
    │
    ▼
docs/observability/observability.md
```

For troubleshooting an existing deployment, start instead with:

```text
docs/operations/
        │
        ▼
docs/troubleshooting/
        │
        ├── common-issues.md
        ├── infrastructure-issues.md
        ├── deployment-issues.md
        └── runtime-issues.md
```

---

# 19. Repository Structure

The repository is organized approximately as follows:

```text
mini-write/
│
├── api/
│   └── src/
│
├── worker/
│   └── src/
│
├── infra/
│   └── ansible/
│
├── observability/
│   ├── Prometheus/
│   ├── promtail/
│   ├── loki/
│   ├── alertmanager/
│   └── grafana/
│
├── .github/
│   └── workflows/
│
├── docker-compose.yml
│
├── docs/
│   ├── architecture/
│   ├── infrastructure/
│   ├── development/
│   ├── deployment/
│   ├── operations/
│   ├── reliability/
│   ├── observability/
│   ├── reference/
│   ├── troubleshooting/
│   └── project/
│
├── CONTRIBUTING.md
├── SECURITY.md
└── CHANGELOG.md
```

The exact repository contents may evolve as the platform progresses.

---

# 20. Configuration and Secrets

Configuration is separated from application logic.

Environment-specific configuration should not be hard-coded into source code.

Sensitive values such as:

* passwords
* tokens
* JWT secrets
* credentials
* private keys

must not be committed to the repository.

See:

* `docs/deployment/configuration.md`
* `docs/reference/configuration-reference.md`
* `docs/reference/environment-variables.md`
* `SECURITY.md`

---

# 21. Troubleshooting

Troubleshooting is organized by failure domain.

### General

`docs/troubleshooting/common-issues.md`

### Infrastructure

`docs/troubleshooting/infrastructure-issues.md`

### Deployment

`docs/troubleshooting/deployment-issues.md`

### Runtime

`docs/troubleshooting/runtime-issues.md`

The preferred troubleshooting approach is evidence-driven:

```text
Symptom
   │
   ▼
Identify Layer
   │
   ▼
Collect Evidence
   │
   ├── Logs
   ├── Metrics
   ├── Health
   ├── Runtime State
   └── Infrastructure State
   │
   ▼
Identify Failure Domain
   │
   ▼
Apply Corrective Action
   │
   ▼
Validate Recovery
```

---

# 22. Engineering Principles

The project follows several principles throughout its architecture.

### Reliability Before Complexity

New mechanisms should solve an identified reliability problem rather than introduce complexity for its own sake.

### Explicit Boundaries

Infrastructure, application, runtime, deployment, and observability responsibilities should remain distinguishable.

### Deterministic Behavior

Operational behavior should be predictable and explainable.

### Failure-Aware Design

Failures are expected architectural conditions rather than exceptional events that can simply be ignored.

### Evidence-Driven Operations

Operational decisions should be based on observable evidence.

### Reproducibility

Infrastructure and operational configuration should be represented as code whenever practical.

### Separation of Concerns

Each engineering layer should have a clear responsibility.

### Production-Oriented Thinking

Even though Mini-Write runs in a constrained local environment, its architecture is designed using production-oriented engineering principles.

---

# 23. Project Evolution

Mini-Write is developed incrementally.

The engineering evolution has progressed through capabilities including:

```text
Infrastructure Foundation
        │
        ▼
Infrastructure Reproducibility
        │
        ▼
Observability
        │
        ▼
Reliability Architecture
        │
        ▼
Runtime Reliability
        │
        ▼
Operational Engineering
        │
        ▼
Continuous Improvement
```

The project documentation preserves the resulting engineering knowledge rather than documenting only the final implementation.

For the broader evolution model, see:

`docs/project/engineering-evolution.md`

---

# 24. Status

Mini-Write is an actively evolving engineering project.

The repository should therefore be treated as a living system:

```text
Architecture
     ↓
Implementation
     ↓
Validation
     ↓
Operations
     ↓
Evidence
     ↓
Engineering Improvement
     ↓
Architecture Evolution
```

Documentation is updated alongside meaningful architectural and operational changes.

---

# 25. Contributing

Engineering contribution guidelines are documented in:

`CONTRIBUTING.md`

Changes should preserve:

* architectural boundaries
* operational determinism
* reliability guarantees
* observability
* reproducibility
* documentation consistency

---

# 26. Security

Security-related practices and reporting guidance are documented in:

`SECURITY.md`

Security-sensitive information must never be committed to the repository.

---

# 27. License

License information should be added here when a project license is formally selected.

---

# 28. Quick Navigation

| Area              | Documentation           |
| ----------------- | ----------------------- |
| Architecture      | `docs/architecture/`    |
| Infrastructure    | `docs/infrastructure/`  |
| Development       | `docs/development/`     |
| Deployment        | `docs/deployment/`      |
| Operations        | `docs/operations/`      |
| Reliability       | `docs/reliability/`     |
| Observability     | `docs/observability/`   |
| Reference         | `docs/reference/`       |
| Troubleshooting   | `docs/troubleshooting/` |
| Project Evolution | `docs/project/`         |
| Contribution      | `CONTRIBUTING.md`       |
| Security          | `SECURITY.md`           |
| Changes           | `CHANGELOG.md`          |

---

# 29. Final Mental Model

Mini-Write should be understood as an operational platform rather than a collection of independent containers.

The complete system can be viewed as:

```text
                         MINI-WRITE
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   Application          Infrastructure        Operations
        │                    │                    │
    API / Worker       Docker / Ansible     Deployment / Health
        │                    │                    │
        └──────────────┬─────┴────────────────────┘
                       │
                       ▼
                Runtime Reliability
                       │
          ┌────────────┼────────────┐
          │            │            │
          ▼            ▼            ▼
       Timeout       Retry       Recovery
          │            │            │
          └────────────┼────────────┘
                       │
                       ▼
                 Failure Model
                       │
                       ▼
                Observability
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Metrics        Logs       Alerts
          │            │            │
          └────────────┼────────────┘
                       ▼
                    Grafana
                       │
                       ▼
               Operational Evidence
                       │
                       ▼
              Engineering Improvement
```

The central engineering objective is therefore not simply to make the application run.

It is to build a system whose:

```text
architecture
   +
infrastructure
   +
runtime
   +
deployment
   +
reliability
   +
observability
   +
operations
```

work together coherently and can be understood, reproduced, operated, diagnosed, and evolved by an engineer who did not originally build the system.

```
```
