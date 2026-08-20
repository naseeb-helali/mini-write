# System Architecture

## 1. Purpose

This document defines the system-level architecture of the Mini-Write platform.

It translates the high-level architecture described in
[Architecture Overview](./overview.md) into a concrete system model covering:

- system boundaries
- major components
- service relationships
- communication paths
- data flows
- network boundaries
- persistence boundaries
- deployment structure
- runtime boundaries
- observability flows
- operational dependencies
- failure propagation paths

This document describes **how the system is assembled and how its major parts interact**.

It does not replace the more specialized documentation:

- [Service Architecture](./service-architecture.md)
- [Networking](./networking.md)
- [Runtime Architecture](./runtime-architecture.md)
- [Infrastructure Overview](../infrastructure/overview.md)
- [Deployment](../deployment/deployment.md)
- [Observability](../observability/observability.md)
- [Reliability](../reliability/reliability.md)

---

# 2. System Scope

Mini-Write is a containerized multi-service application operated on a single Ubuntu staging host.

The system contains:

1. An externally reachable HTTP gateway.
2. A synchronous API service.
3. An asynchronous Worker service.
4. PostgreSQL for relational state.
5. Redis for queue and cache infrastructure.
6. MinIO for object storage.
7. A monitoring and observability platform.
8. Host-level and container-level telemetry collectors.
9. An infrastructure automation layer based on Ansible.
10. A self-hosted GitHub Actions runner used for CI/CD execution.

The architectural model is therefore:

```text
                         ┌─────────────────────┐
                         │      External        │
                         │       Client         │
                         └──────────┬──────────┘
                                    │
                                    │ HTTP
                                    ▼
                         ┌─────────────────────┐
                         │       Gateway       │
                         │       Nginx         │
                         └──────────┬──────────┘
                                    │
                                    │ HTTP
                                    ▼
                         ┌─────────────────────┐
                         │        API          │
                         │   Synchronous       │
                         │   Application        │
                         └───────┬─────┬───────┘
                                 │     │
                    ┌────────────┘     └──────────────┐
                    │                                 │
                    ▼                                 ▼
             ┌─────────────┐                   ┌─────────────┐
             │ PostgreSQL  │                   │    Redis     │
             │ Relational  │                   │ Queue/Cache  │
             │   State     │                   │              │
             └─────────────┘                   └──────┬──────┘
                                                      │
                                                      │ Jobs
                                                      ▼
                                               ┌─────────────┐
                                               │   Worker    │
                                               │ Asynchronous │
                                               │ Processing   │
                                               └──────┬──────┘
                                                      │
                                                      │
                                               ┌──────▼──────┐
                                               │    MinIO    │
                                               │   Object    │
                                               │   Storage   │
                                               └─────────────┘


                  ┌─────────────────────────────────────────┐
                  │          Observability Platform         │
                  │                                         │
                  │ Prometheus │ Loki │ Alertmanager       │
                  │ Grafana    │ Promtail │ Exporters      │
                  └─────────────────────────────────────────┘
````

The diagram represents logical relationships.

The complete physical deployment remains a single staging host.

---

# 3. Deployment Context

The current deployment model is intentionally single-node.

```text
┌──────────────────────────────────────────────────────────────┐
│                    Ubuntu Staging VM                          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Docker Runtime                      │  │
│  │                                                        │  │
│  │ Gateway │ API │ Worker │ PostgreSQL │ Redis │ MinIO   │  │
│  │                                                        │  │
│  │ Prometheus │ Loki │ Promtail │ Alertmanager │ Grafana │  │
│  │                                                        │  │
│  │ Node Exporter │ cAdvisor │ DB Exporter │ Redis Exporter│  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│                  /opt/deploy                                │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

This topology is deliberately different from a multi-node production cluster.

The architecture should therefore not be interpreted as Kubernetes or cloud-native infrastructure.

The system is a **service-distributed application running on a single infrastructure node**.

This distinction is important because:

* service boundaries exist;
* network boundaries exist;
* persistence boundaries exist;
* failure boundaries exist;

but the underlying host remains a shared infrastructure failure domain.

---

# 4. Major System Components

## 4.1 Gateway

The Gateway is implemented using Nginx.

Its architectural responsibilities are:

* receive external HTTP traffic;
* provide the external HTTP entry point;
* forward requests to the API;
* expose the application through a controlled frontend boundary.

The Gateway does not own application business logic.

The configured external HTTP path is:

```text
External Client
      │
      ▼
    Nginx
      │
      ▼
    API
```

The Gateway depends on API health through its configured service dependency.

---

# 4.2 API

The API is the primary synchronous application service.

Its responsibilities include:

* HTTP request processing;
* authentication;
* user registration;
* user login;
* authenticated profile access;
* ID-card upload workflow;
* application health endpoints;
* application metrics exposure.

The API also acts as an integration point with infrastructure dependencies:

```text
API
 ├── PostgreSQL
 ├── Redis
 └── MinIO
```

The API contains the application-level Runtime.

The Runtime establishes execution identity, operation identity, reliability policy, lifecycle state, failure state, and infrastructure execution boundaries.

---

# 4.3 Worker

The Worker is the asynchronous processing service.

Its primary responsibility is consuming and processing background jobs.

Its execution model differs from the API:

```text
API
 │
 └── enqueue job
          │
          ▼
        Redis
          │
          ▼
       Worker
          │
          ├── PostgreSQL
          └── MinIO
```

The Worker is therefore not an extension of the HTTP request lifecycle.

It has its own execution boundary adapted to background-job processing.

The Worker also exposes metrics for operational monitoring.

---

# 4.4 PostgreSQL

PostgreSQL is the relational persistence layer.

It stores application state such as user records.

The API communicates with PostgreSQL for synchronous application operations.

The Worker can also interact with PostgreSQL during background processing.

PostgreSQL therefore represents a shared infrastructure dependency:

```text
              ┌─────────┐
              │   API   │
              └────┬────┘
                   │
                   ▼
             ┌────────────┐
             │ PostgreSQL │
             └────────────┘
                   ▲
                   │
              ┌────┴────┐
              │ Worker  │
              └─────────┘
```

PostgreSQL state is persisted through the Docker volume:

```text
postgres_data
```

---

# 4.5 Redis

Redis provides queue and cache infrastructure.

Within the application architecture, Redis is particularly important for asynchronous processing.

The main workflow is:

```text
API
 │
 │ enqueue job
 ▼
Redis Queue
 │
 │ consume job
 ▼
Worker
```

Redis uses append-only persistence:

```text
redis-server --appendonly yes
```

and persists data through:

```text
redis_data
```

Redis therefore acts as both an infrastructure dependency and an asynchronous workflow boundary.

---

# 4.6 MinIO

MinIO provides S3-compatible object storage.

The API uses MinIO during the ID upload workflow.

The resulting object can subsequently participate in asynchronous processing performed by the Worker.

The high-level workflow is:

```text
Client
  │
  ▼
API
  │
  ├──────────────► MinIO
  │                   │
  │                   │ object
  │                   ▼
  │
  └──────────────► Redis
                      │
                      │ job
                      ▼
                   Worker
                      │
                      └──────► MinIO
```

MinIO state is persisted through:

```text
minio_data
```

---

# 5. Application Request Flow

The standard synchronous request path is:

```text
Client
  │
  ▼
Gateway
  │
  ▼
API
  │
  ├── Runtime Bootstrap
  │
  ├── Runtime Guard
  │
  ├── Operation Resolution
  │
  ├── Reliability Activation
  │
  └── Application Controller
          │
          ├── PostgreSQL
          ├── Redis
          └── MinIO
          │
          ▼
      HTTP Response
          │
          ▼
       Gateway
          │
          ▼
        Client
```

The Runtime is therefore part of the normal application execution path.

It is not an independent side process.

---

# 6. Runtime Request Lifecycle

For Runtime-enabled API operations, the request lifecycle is:

```text
HTTP Request
     │
     ▼
runtimeBootstrap
     │
     ├── createExecutionContext()
     ├── initialize()
     ├── generate request identity
     ├── generate execution identity
     ├── attach request metadata
     └── expose req.runtime
     │
     ▼
runtimeGuard
     │
     ├── runtime presence
     ├── runtime state
     ├── runtime identity
     └── runtime integrity
     │
     ▼
Application Route
     │
     ▼
runtimeOperationResolution
     │
     ├── operation identity
     └── reliability policy
     │
     ▼
runtimeStateActivation
     │
     ├── activate reliability
     └── activate execution
     │
     ▼
Controller
     │
     ▼
Infrastructure Boundary
     │
     ▼
Dependency
     │
     ▼
Response
     │
     ▼
Runtime Completion
```

The Runtime lifecycle is described in detail in
[Runtime Architecture](./runtime-architecture.md).

---

# 7. Operation Model

Application operations are explicitly represented in the Runtime.

Current API operations include:

```text
user_register
user_login
user_profile
id_upload
health_liveness
health_readiness
```

Operations are categorized as:

```text
authentication
user
storage
health
background
```

The operation identity allows reliability behavior and operational telemetry to be associated with a known logical operation.

This produces an architectural relationship:

```text
HTTP Route
    │
    ▼
Operation Definition
    │
    ▼
Reliability Policy
    │
    ▼
Runtime Execution
```

---

# 8. Reliability Policy Resolution

Reliability behavior is selected by operation.

The policy resolution flow is:

```text
Operation ID
     │
     ▼
Policy Resolver
     │
     ├── operation-specific policy
     │
     └── default policy
             │
             ▼
       Runtime Policy
```

Policies define properties such as:

* timeout;
* retry enablement;
* maximum retries;
* recoverability.

For example, the ID upload operation has a reliability policy allowing retries and recovery, while authentication operations use non-retry policies.

The system therefore avoids treating every operation as equally retryable.

---

# 9. Infrastructure Execution Boundary

Infrastructure operations do not directly execute dependency calls from the Runtime-aware application path.

Instead, they cross the Runtime infrastructure boundary:

```text
Application Controller
        │
        ▼
executeInfrastructureOperation()
        │
        ▼
Reliability Executor
        │
        ├── timeout
        ├── retry decision
        ├── backoff
        ├── failure classification
        └── recovery state
        │
        ▼
Infrastructure Dependency
```

Current dependencies are represented explicitly as:

```text
postgresql
redis
minio
```

This boundary is important because it centralizes reliability behavior around infrastructure operations rather than duplicating it throughout application controllers.

---

# 10. ID Upload System Flow

The ID upload workflow demonstrates the interaction between most application components.

The logical flow is:

```text
Client
  │
  │ multipart upload
  ▼
Gateway
  │
  ▼
API
  │
  ├── authenticate user
  │
  ├── create Runtime operation
  │
  ├── activate reliability
  │
  ▼
MinIO
  │
  │ store uploaded object
  ▼
API
  │
  ▼
PostgreSQL
  │
  │ persist object reference
  ▼
API
  │
  ▼
Redis
  │
  │ enqueue processing job
  ▼
Worker
  │
  ├── process job
  │
  ├── PostgreSQL
  │
  └── MinIO
  │
  ▼
Processing Result
```

The HTTP request does not wait for the complete background processing lifecycle.

The API returns after the upload and job-enqueue stages succeed.

The Worker owns the asynchronous processing stage.

---

# 11. Authentication Flow

The authentication architecture is primarily synchronous.

For registration:

```text
Client
  │
  ▼
Gateway
  │
  ▼
API
  │
  ▼
Runtime
  │
  ▼
PostgreSQL
  │
  ▼
User Created
  │
  ▼
HTTP Response
```

For login:

```text
Client
  │
  ▼
Gateway
  │
  ▼
API
  │
  ▼
Runtime
  │
  ▼
PostgreSQL
  │
  ▼
Credential Verification
  │
  ▼
JWT Generation
  │
  ▼
HTTP Response
```

The authentication operations use explicit Runtime operation identities and reliability policies.

---

# 12. Health Architecture

Health is represented at both service and dependency levels.

The API exposes:

```text
/health/live
/health/ready
```

### Liveness

The liveness endpoint represents process/service liveness.

It is intentionally lightweight.

```text
Client / Platform
        │
        ▼
/health/live
        │
        ▼
API Runtime
        │
        ▼
UP / Failure
```

### Readiness

Readiness performs actual system verification.

The API invokes the health service and returns an operational state.

```text
Client / Platform
        │
        ▼
/health/ready
        │
        ▼
API
        │
        ▼
System Health
        │
        ├── Database
        └── Other readiness dependencies
        │
        ▼
UP / DOWN
```

The container health check uses the readiness endpoint for the API.

---

# 13. Network Architecture

The application uses two principal Docker networks:

```text
frontend-network
backend-network
```

## 13.1 Frontend Network

The frontend network contains the externally facing application path.

Conceptually:

```text
frontend-network
      │
      ├── Gateway
      └── API
```

The Gateway is the principal externally exposed application component.

---

## 13.2 Backend Network

The backend network provides internal service communication.

Conceptually:

```text
backend-network
      │
      ├── API
      ├── Worker
      ├── PostgreSQL
      ├── Redis
      ├── MinIO
      └── Observability services
```

The Worker is not connected to the frontend network.

This prevents it from being part of the external HTTP ingress path.

---

# 14. External Exposure

The current Docker Compose configuration exposes several service ports on the host.

The principal application path is:

```text
Host
 │
 ▼
Gateway :80
 │
 ▼
API
```

Additional observability and storage ports are exposed according to the staging configuration.

These include ports for services such as:

* MinIO API;
* MinIO Console;
* Prometheus;
* Loki;
* Alertmanager;
* Grafana.

Host-level firewall policy remains an additional security boundary.

Therefore:

```text
Docker Port Exposure
        ≠
Automatic External Accessibility
```

Host firewall configuration determines which inbound connections are permitted.

---

# 15. Persistence Architecture

The deployment defines named Docker volumes for persistent service state.

```text
Docker Volumes
│
├── miniwrite_postgres_data
├── miniwrite_redis_data
├── miniwrite_minio_data
├── miniwrite_prometheus_data
├── miniwrite_grafana_data
├── miniwrite_loki_data
└── miniwrite_alertmanager_data
```

The persistence model can be divided into:

```text
Application Persistence
│
├── PostgreSQL
├── Redis
└── MinIO

Observability Persistence
│
├── Prometheus
├── Grafana
├── Loki
└── Alertmanager
```

Persistent volumes survive individual container replacement.

They do not, however, eliminate the single-host failure domain.

A failure of the underlying VM can affect all persistent services simultaneously.

---

# 16. Deployment State

Deployment state is maintained independently from container lifecycle.

The deployment state contains:

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

The conceptual model is:

```text
Deployment State
       │
       ├── Current API version
       ├── Current Worker version
       ├── Previous API version
       └── Previous Worker version
```

This provides a foundation for deployment tracking and controlled rollback-oriented operations.

The deployment state is part of the deployment runtime rather than application business state.

---

# 17. Infrastructure Automation Flow

Infrastructure is provisioned through Ansible.

The principal execution path is:

```text
Ansible Controller
       │
       ▼
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
       │
       ▼
Staging Host
```

Each role owns a distinct infrastructure concern.

### `base`

Responsible for base system preparation and package installation.

### `docker`

Responsible for Docker repository configuration, package installation, service activation, and deploy-user Docker access.

### `deploy_runtime`

Responsible for establishing `/opt/deploy`, deployment configuration, runtime modules, state, environment configuration, logs, metrics, and observability configuration.

### `github_runner`

Responsible for installing and registering the self-hosted GitHub Actions runner and validating its operational prerequisites.

### `security_baseline`

Responsible for firewall and SSH hardening configuration.

---

# 18. CI/CD Architecture

The GitHub Actions self-hosted runner is installed on the same staging host.

The conceptual flow is:

```text
GitHub Repository
       │
       ▼
GitHub Actions
       │
       ▼
Self-Hosted Runner
       │
       ▼
Staging Host
       │
       ▼
Docker / Deployment Runtime
       │
       ▼
Mini-Write Services
```

The runner therefore forms a bridge between the repository-level automation system and the staging host.

This introduces an important trust boundary:

```text
GitHub Workflow
       │
       ▼
Runner Identity
       │
       ▼
Host Execution Privileges
```

The runner's permissions and Docker access are therefore infrastructure concerns, not merely CI configuration details.

---

# 19. Observability System Architecture

The observability platform is integrated into the same deployment environment.

Its major components are:

```text
                         ┌──────────────┐
                         │  Prometheus  │
                         └──────┬───────┘
                                │
                         metrics│
                                │
       ┌────────────────────────┼────────────────────────┐
       │                        │                        │
       ▼                        ▼                        ▼
     API                    Worker                  Exporters
       │                        │                        │
       └────────────────────────┴────────────────────────┘


Docker Logs
     │
     ▼
 Promtail
     │
     ▼
   Loki
     │
     ▼
 Grafana


Prometheus
     │
     ▼
 Alert Rules
     │
     ▼
Alertmanager
```

---

# 20. Metrics Flow

Prometheus scrapes metrics from multiple targets.

The primary application targets are:

```text
api:80/metrics
worker:9464/metrics
```

Infrastructure targets include:

```text
redis-exporter:9121
postgres-exporter:9187
node-exporter:9100
cadvisor:8080
```

Observability services also expose their own metrics where configured.

The resulting flow is:

```text
Services / Exporters
        │
        │ scrape
        ▼
   Prometheus
        │
        ├── Rules
        │
        └── Time Series
        │
        ▼
     Grafana
```

---

# 21. Logging Flow

Container logs are collected by Promtail.

The principal flow is:

```text
Docker Containers
       │
       │ JSON logs
       ▼
   Promtail
       │
       │ parse / normalize
       ▼
      Loki
       │
       ▼
    Grafana
```

Promtail also collects deployment logs from:

```text
/opt/deploy/logs/*.log
```

The logging pipeline extracts selected fields and deliberately avoids promoting high-cardinality identifiers into Loki labels.

This is an important operational design choice because uncontrolled label cardinality can negatively affect log-storage performance.

---

# 22. Alerting Flow

Prometheus evaluates alerting rules.

The high-level flow is:

```text
Metrics
  │
  ▼
Prometheus
  │
  ▼
Alert Rules
  │
  ▼
Alert State
  │
  ▼
Alertmanager
  │
  ├── Critical
  ├── Warning
  └── Informational
```

Alertmanager groups alerts using:

```text
environment
category
service
```

Critical alerts can inhibit lower-severity warnings for the same service and environment.

This provides basic alert-noise reduction during major incidents.

---

# 23. Grafana Architecture

Grafana consumes:

```text
Prometheus
Loki
```

as provisioned datasources.

The dashboards are organized by operational concern:

```text
System
Application
Queue
Deployment
Incidents
```

The provisioning model is file-based.

Dashboard provisioning is configured to:

* disable deletion;
* disable UI updates;
* periodically reload dashboard definitions.

This means dashboard configuration is treated as managed configuration rather than as manually maintained runtime state.

---

# 24. Observability Dependency Model

The observability platform depends on the services it observes.

This creates an important architectural distinction:

```text
Application
    │
    └── observed by
            │
            ▼
      Observability
```

Observability failure should not automatically imply application failure.

For example:

```text
Grafana DOWN
     ≠
API DOWN
```

Similarly:

```text
Prometheus DOWN
     ≠
Worker DOWN
```

However, observability degradation reduces operational visibility and can itself become an operational incident.

Therefore observability is both:

* an independent operational subsystem;
* a dependency of incident detection and diagnosis.

---

# 25. Failure Propagation

The architecture contains multiple potential failure paths.

## 25.1 API → PostgreSQL

```text
API
 │
 ▼
PostgreSQL
 │
 └── Failure
       │
       ▼
Infrastructure Boundary
       │
       ▼
Failure Classification
       │
       ▼
API Operation Failure
```

Depending on the operation policy and failure classification, the Runtime may retry or propagate the failure.

---

## 25.2 API → Redis

```text
API
 │
 ▼
Redis
 │
 └── Failure
       │
       ▼
Runtime
       │
       ▼
Operation Failure
```

For asynchronous workflows, inability to enqueue a job prevents the Worker from receiving the corresponding work.

---

## 25.3 API → MinIO

```text
API
 │
 ▼
MinIO
 │
 └── Failure
       │
       ▼
Runtime
       │
       ▼
Upload Failure
```

The ID upload workflow therefore has a direct dependency on object-storage availability.

---

## 25.4 Redis → Worker

```text
Redis
 │
 └── Failure
       │
       ▼
Worker
       │
       ▼
Queue Consumption Failure
```

This can manifest operationally as:

* queue backlog;
* reduced throughput;
* failed jobs;
* unavailable background processing.

---

## 25.5 Host Failure

Because all services share one host:

```text
Host Failure
      │
      ├── API
      ├── Worker
      ├── PostgreSQL
      ├── Redis
      ├── MinIO
      └── Observability
```

may become unavailable simultaneously.

This is the most significant current infrastructure-level failure domain.

---

# 26. Failure Domain Model

The current system can be viewed as several nested failure domains.

```text
Host Failure Domain
│
├── Docker Runtime
│   │
│   ├── Application Services
│   │   ├── Gateway
│   │   ├── API
│   │   └── Worker
│   │
│   ├── Data Services
│   │   ├── PostgreSQL
│   │   ├── Redis
│   │   └── MinIO
│   │
│   └── Observability
│       ├── Prometheus
│       ├── Loki
│       ├── Alertmanager
│       └── Grafana
│
└── Host Services
    ├── Docker
    ├── SSH
    ├── UFW
    └── GitHub Runner
```

The system therefore has strong logical service boundaries but limited physical fault isolation.

This distinction must remain explicit when evaluating reliability.

---

# 27. Dependency Graph

The principal runtime dependency graph is:

```text
                         Gateway
                            │
                            ▼
                           API
                      ┌─────┼─────┐
                      │     │     │
                      ▼     ▼     ▼
                 PostgreSQL Redis MinIO
                      ▲      │      ▲
                      │      │      │
                      │      ▼      │
                      └────Worker───┘
```

The operational dependency graph adds observability:

```text
API ───────────────┐
Worker ────────────┤
PostgreSQL ────────┤
Redis ─────────────┤
MinIO ─────────────┤
Host ──────────────┤
Containers ────────┤
                   ▼
              Observability
                   │
          ┌────────┼────────┐
          ▼        ▼        ▼
      Prometheus  Loki  Alertmanager
          │        │        │
          └────────┼────────┘
                   ▼
                Grafana
```

The second graph represents monitoring relationships, not application execution dependencies.

---

# 28. Service Startup Dependencies

Docker Compose defines service startup dependencies using health conditions where appropriate.

Examples include:

```text
Gateway
   │
   └── API healthy

API
   ├── PostgreSQL healthy
   └── Redis healthy

Worker
   ├── Redis healthy
   ├── PostgreSQL healthy
   └── MinIO healthy

Redis Exporter
   └── Redis healthy

PostgreSQL Exporter
   └── PostgreSQL healthy

Grafana
   ├── Prometheus
   ├── Loki
   └── Alertmanager

Promtail
   └── Loki
```

These dependencies define startup ordering and readiness expectations.

They should not be interpreted as complete runtime dependency guarantees.

A service becoming healthy at startup does not guarantee that it will remain healthy throughout its lifetime.

---

# 29. Runtime Versus Container Lifecycle

Container lifecycle and application Runtime lifecycle are separate concepts.

### Container lifecycle

```text
Created
   ↓
Started
   ↓
Running
   ↓
Stopped / Restarted
```

### API Runtime lifecycle

```text
Created
   ↓
Initialized
   ↓
Active
   ↓
Completed
```

These lifecycles solve different problems.

The Docker lifecycle controls service process execution.

The application Runtime lifecycle controls individual logical executions.

Therefore:

```text
Container Restart
     ≠
Runtime Execution Completion
```

and:

```text
Runtime Failure
     ≠
Container Failure
```

A Runtime operation can fail while the API process remains healthy.

---

# 30. Configuration Boundaries

Configuration exists at several levels.

```text
Repository Configuration
        │
        ▼
Ansible Variables / Templates
        │
        ▼
Deployment Configuration
        │
        ▼
.env.staging
        │
        ▼
Docker Compose
        │
        ▼
Container Environment
        │
        ▼
Application Runtime
```

The deployment environment file is generated as part of the deployment runtime.

The application consumes environment configuration at runtime.

Secrets used by Ansible are separated into the Ansible vault structure rather than being hard-coded into application source files.

---

# 31. Security Architecture

Security is implemented through multiple boundaries.

```text
External Network
       │
       ▼
      UFW
       │
       ▼
    Host SSH
       │
       ▼
 Docker Network Boundaries
       │
       ▼
 Application Authentication
       │
       ▼
 Authorization
```

The host security baseline includes:

* default deny inbound traffic;
* allow-listed TCP ports;
* SSH configuration hardening;
* root login restrictions;
* password authentication configuration;
* public-key authentication configuration.

Container network separation provides an additional isolation layer.

Application authentication and authorization provide application-level access control.

---

# 32. Resource Boundaries

The Docker Compose configuration establishes explicit resource limits for major services.

Examples include:

```text
Gateway
    memory: 128 MB
    CPU:    0.2

API
    memory: 512 MB
    CPU:    0.5

Worker
    memory: 1024 MB
    CPU:    1.0

PostgreSQL
    memory: 512 MB
    CPU:    0.5

Redis
    memory: 256 MB
    CPU:    0.3
```

Observability services also receive defined resource limits.

These limits provide a degree of resource containment.

They do not create independent physical capacity because all limits ultimately share the host's resources.

---

# 33. Observability Resource Boundaries

The observability stack itself is resource-bounded.

Representative limits include:

```text
Prometheus       512 MB / 0.5 CPU
Loki             512 MB / 0.5 CPU
Grafana          512 MB / 0.5 CPU
Alertmanager     256 MB / 0.3 CPU
Promtail         256 MB / 0.3 CPU
Node Exporter    128 MB / 0.2 CPU
cAdvisor         256 MB / 0.3 CPU
Redis Exporter   128 MB / 0.2 CPU
Postgres Exporter
                 128 MB / 0.2 CPU
```

This is important because observability workloads themselves can consume meaningful host resources.

The observability system is therefore treated as a managed workload rather than as an unlimited side capability.

---

# 34. System-Level Reliability Controls

Reliability is distributed across several system layers.

```text
Host
 │
 ├── Firewall
 └── Resource Controls
       │
       ▼
Docker
 │
 ├── Restart Policies
 ├── Health Checks
 └── Network Isolation
       │
       ▼
Application
 │
 ├── Runtime State
 ├── Timeouts
 ├── Retry Policies
 ├── Failure Classification
 └── Recovery State
       │
       ▼
Observability
 │
 ├── Metrics
 ├── Logs
 ├── Alerts
 └── Dashboards
```

No single mechanism provides complete reliability.

The architecture relies on the combination of these controls.

---

# 35. Restart Versus Recovery

The system distinguishes between process-level restart and operation-level recovery.

### Restart

Docker can restart a failed service:

```text
Container Failure
      │
      ▼
Docker Restart
      │
      ▼
Service Process
```

### Runtime Recovery

An individual operation can be retried according to its Runtime policy:

```text
Operation Failure
      │
      ▼
Failure Classification
      │
      ▼
Retry Eligibility
      │
      ▼
Backoff
      │
      ▼
Retry
      │
      ▼
Success / Failure
```

These mechanisms operate at different layers.

A container restart does not replace Runtime retry logic.

Runtime retry logic does not replace container restart behavior.

---

# 36. Data Flow Categories

The system contains four major data-flow categories.

## 36.1 Request Data

```text
Client → Gateway → API
```

---

## 36.2 Application State

```text
API / Worker → PostgreSQL
```

---

## 36.3 Object Data

```text
API / Worker ↔ MinIO
```

---

## 36.4 Asynchronous Work

```text
API → Redis → Worker
```

---

## 36.5 Operational Telemetry

```text
Services / Host
      │
      ├── Metrics → Prometheus
      └── Logs → Promtail → Loki
```

These flows should remain conceptually separate even when they coexist within the same deployment environment.

---

# 37. System Invariants

The architecture relies on several important invariants.

## Invariant 1 — External Application Entry

The Gateway is the intended external HTTP entry point for the application.

---

## Invariant 2 — Worker Is Internal

The Worker is not part of the external HTTP ingress path.

---

## Invariant 3 — Runtime Is Request/Execution Scoped

A Runtime execution context belongs to a logical execution and is not a global application singleton.

---

## Invariant 4 — Infrastructure Operations Cross Explicit Boundaries

Runtime-aware dependency operations are executed through the infrastructure boundary.

---

## Invariant 5 — Service State Is Not Equivalent to Process State

A running process does not necessarily imply readiness to serve workload.

---

## Invariant 6 — Observability Is Operationally Independent

Failure of Grafana, Loki, or Prometheus does not by itself mean the application has failed.

---

## Invariant 7 — Host Is a Shared Failure Domain

All containers depend on the availability of the underlying staging host.

---

## Invariant 8 — Persistent Data Is Separate From Container Lifecycle

Named volumes preserve persistent state independently of individual container replacement.

---

## Invariant 9 — Deployment State Is Separate From Application State

Deployment metadata is maintained within the deployment runtime and is not part of PostgreSQL application state.

---

# 38. Current Architectural Limitations

The architecture deliberately accepts several limitations due to the single-node staging environment.

## 38.1 Single Host Failure Domain

All services depend on one VM.

A host outage can affect:

* application availability;
* database availability;
* queue availability;
* object storage;
* observability;
* CI/CD runner availability.

---

## 38.2 No Multi-Node Scheduling

There is currently no cluster scheduler.

The system does not provide:

* automatic workload rescheduling across hosts;
* node-level redundancy;
* distributed service placement.

---

## 38.3 Limited Data Redundancy

Docker volumes provide persistence but not distributed replication.

Persistent data remains dependent on the host storage subsystem.

---

## 38.4 Observability Shares the Same Host

The monitoring platform is itself deployed on the same host as the workloads it monitors.

A total host failure can therefore remove both:

```text
System
+
Observability
```

simultaneously.

---

## 38.5 Self-Hosted Runner Shares the Deployment Host

The GitHub Actions runner is also colocated with the workload.

Therefore CI/CD execution and application workloads share an infrastructure boundary.

---

# 39. Evolution Path

The architecture has been intentionally structured so that logical boundaries can evolve independently of the current single-node implementation.

The current topology:

```text
Single Host
    │
    └── Docker Compose
          │
          ├── API
          ├── Worker
          ├── Data Services
          └── Observability
```

can conceptually evolve toward:

```text
Multiple Nodes
    │
    ├── Application Workloads
    ├── Data Services
    └── Observability
```

and eventually toward an orchestrated environment:

```text
Cluster
  │
  ├── API Workloads
  ├── Worker Workloads
  ├── Service Networking
  ├── Persistent Storage
  └── Observability Platform
```

The architectural goal is not to prematurely implement the future topology.

The goal is to maintain boundaries that do not prevent future evolution.

---

# 40. System Architecture Summary

The Mini-Write system can be reduced to the following architectural model:

```text
                         ┌──────────────┐
                         │   External   │
                         │    Client    │
                         └──────┬───────┘
                                │
                                ▼
                         ┌──────────────┐
                         │    Nginx     │
                         │   Gateway    │
                         └──────┬───────┘
                                │
                                ▼
                     ┌────────────────────┐
                     │        API         │
                     │                    │
                     │  Runtime           │
                     │  Application       │
                     └─────┬──────┬──────┘
                           │       │
                ┌──────────┘       └──────────┐
                ▼                             ▼
         ┌─────────────┐               ┌─────────────┐
         │ PostgreSQL  │               │    MinIO    │
         └─────────────┘               └──────▲──────┘
                                              │
                                              │
                       ┌─────────────┐         │
                       │    Redis    │◄────────┘
                       └──────┬──────┘
                              │
                              ▼
                       ┌─────────────┐
                       │   Worker    │
                       │  Runtime    │
                       └──────┬──────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
               PostgreSQL            MinIO


             ┌────────────────────────────────┐
             │       Observability            │
             │                                │
             │ Prometheus ←── Metrics         │
             │ Loki       ←── Logs            │
             │ Alertmanager ← Alerts          │
             │ Grafana    ←── Visualization   │
             │ Exporters  ←── Infrastructure  │
             └────────────────────────────────┘


             ┌────────────────────────────────┐
             │       Infrastructure           │
             │                                │
             │ Ubuntu VM                      │
             │ Docker                         │
             │ Ansible                        │
             │ GitHub Actions Runner          │
             │ UFW / SSH Hardening            │
             └────────────────────────────────┘
```

The resulting architecture can therefore be understood as four interacting planes:

```text
┌───────────────────────────────────────────────┐
│              Application Plane                │
│                                               │
│              API + Worker                     │
└──────────────────────┬────────────────────────┘
                       │
┌──────────────────────▼────────────────────────┐
│               Runtime Plane                   │
│                                               │
│ Execution Context + Reliability + Boundaries  │
└──────────────────────┬────────────────────────┘
                       │
┌──────────────────────▼────────────────────────┐
│             Infrastructure Plane              │
│                                               │
│ Docker + Data Services + Host + Ansible       │
└──────────────────────┬────────────────────────┘
                       │
┌──────────────────────▼────────────────────────┐
│              Operations Plane                 │
│                                               │
│ Metrics + Logs + Alerts + Health + Deployment │
└───────────────────────────────────────────────┘
```

The key architectural property is the separation of these planes while preserving explicit communication paths between them.

This separation enables the system to evolve from a single-node staging implementation toward more sophisticated infrastructure without requiring the application architecture itself to absorb infrastructure-specific responsibilities.

```
```
