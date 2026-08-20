# Service Architecture

## 1. Purpose

This document defines the architecture of the application services that make up Mini-Write.

It describes:

- service responsibilities;
- service boundaries;
- service ownership;
- service dependencies;
- synchronous and asynchronous communication;
- service runtime models;
- data ownership;
- health and observability interfaces;
- reliability boundaries;
- failure behavior;
- scaling characteristics;
- interaction rules between services.

This document focuses on **application services and their relationships**.

It does not define the complete infrastructure architecture. Infrastructure concerns are documented under:

- [Infrastructure Overview](../infrastructure/overview.md)
- [Infrastructure as Code](../infrastructure/infrastructure-as-code.md)
- [Docker](../infrastructure/docker.md)
- [Host Provisioning](../infrastructure/host-provisioning.md)

The system-level composition is defined in
[System Architecture](./system-architecture.md).

---

# 2. Service Model

Mini-Write is organized around two primary application services:

```text
                 ┌─────────────────────┐
                 │    Application      │
                 │       Services      │
                 └──────────┬──────────┘
                            │
                 ┌──────────┴──────────┐
                 │                     │
                 ▼                     ▼
          ┌─────────────┐       ┌─────────────┐
          │     API     │       │   Worker    │
          │  Service    │       │   Service   │
          └─────────────┘       └─────────────┘
````

The two services have deliberately different execution models.

### API

The API is:

* synchronous;
* HTTP-driven;
* request-oriented;
* externally reachable through the Gateway;
* responsible for user-facing application operations.

### Worker

The Worker is:

* asynchronous;
* queue-driven;
* job-oriented;
* internally reachable;
* responsible for background processing.

The architecture therefore separates:

```text
Synchronous Work
       │
       ▼
      API
```

from:

```text
Asynchronous Work
       │
       ▼
    Worker
```

This separation prevents long-running background processing from becoming part of the synchronous HTTP request lifecycle.

---

# 3. Service Boundaries

The primary service boundaries are:

```text
┌──────────────────────────────────────────────────────┐
│                    Mini-Write                        │
│                                                      │
│  ┌────────────────┐          ┌────────────────┐      │
│  │      API       │          │     Worker     │      │
│  │                │          │                │      │
│  │ HTTP Runtime   │          │ Job Runtime    │      │
│  │ Controllers    │          │ Job Handlers   │      │
│  │ Routes         │          │ Queue Consumer │      │
│  └───────┬────────┘          └───────┬────────┘      │
│          │                           │               │
│          └───────────┬───────────────┘               │
│                      │                               │
│             Infrastructure Services                 │
│                                                      │
│     PostgreSQL │ Redis │ MinIO                      │
└──────────────────────────────────────────────────────┘
```

The service boundary means that each service owns its execution logic.

It does **not** mean that services own independent copies of every dependency.

For example, both API and Worker may interact with PostgreSQL, but they do so from different execution contexts and for different responsibilities.

---

# 4. Service Responsibility Matrix

| Service    | Primary Responsibility             | Execution Model       | External Access             | Main Dependencies        |
| ---------- | ---------------------------------- | --------------------- | --------------------------- | ------------------------ |
| API        | Synchronous application operations | HTTP request/response | Through Gateway             | PostgreSQL, Redis, MinIO |
| Worker     | Background job processing          | Queue/job execution   | Internal only               | Redis, PostgreSQL, MinIO |
| Gateway    | HTTP ingress and routing           | HTTP proxy            | External                    | API                      |
| PostgreSQL | Relational persistence             | Database server       | Internal                    | Host storage             |
| Redis      | Queue/in-memory infrastructure     | Queue/data service    | Internal                    | Host storage             |
| MinIO      | Object storage                     | S3-compatible storage | Internal/application-facing | Host storage             |

The API and Worker are the primary application services.

The Gateway and infrastructure services support those application services but do not replace their responsibilities.

---

# 5. API Service

## 5.1 Responsibility

The API is responsible for synchronous application behavior.

Its responsibilities include:

* receiving HTTP requests;
* validating request-level input;
* authenticating users;
* issuing JWTs;
* serving authenticated profile requests;
* handling ID-card uploads;
* persisting application state;
* storing uploaded objects;
* enqueueing asynchronous jobs;
* exposing application health endpoints;
* exposing application metrics;
* enforcing Runtime execution contracts.

The API is therefore the primary application-facing service.

---

# 5.2 API Internal Structure

The API is organized into several logical layers:

```text
api/src/
│
├── routes/
│
├── controllers/
│
├── middleware/
│
├── services/
│
├── models/
│
├── health/
│
├── config/
│
├── observability/
│
└── runtime/
```

Conceptually:

```text
HTTP
 │
 ▼
Routes
 │
 ▼
Middleware
 │
 ├── Authentication
 │
 └── Runtime
 │
 ▼
Controllers
 │
 ▼
Application Services
 │
 ▼
Infrastructure Boundaries
 │
 ├── PostgreSQL
 ├── Redis
 └── MinIO
```

The Runtime is therefore integrated into the API execution path rather than existing as an unrelated utility layer.

---

# 5.3 API HTTP Boundary

The API exposes the following major application operations:

```text
POST /api/v1/auth/register
POST /api/v1/auth/login
GET  /api/v1/auth/profile
POST /api/v1/auth/upload-id
```

Health endpoints:

```text
GET /health/live
GET /health/ready
```

Metrics endpoint:

```text
GET /metrics
```

The intended external path is:

```text
Client
  │
  ▼
Gateway
  │
  ▼
API
```

The API itself is not responsible for external traffic termination architecture.

That responsibility belongs to the Gateway and host/network configuration.

---

# 6. API Request Execution Model

Every Runtime-enabled request follows the Runtime lifecycle.

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
Route
     │
     ▼
Operation Resolution
     │
     ▼
Reliability Activation
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
HTTP Response
     │
     ▼
Runtime Completion
```

The API therefore treats a request as a managed execution rather than simply as an Express callback.

---

# 7. API Runtime Responsibilities

The API Runtime provides the execution-level abstraction required by reliability engineering.

Its responsibilities include:

* generating request identity;
* generating execution identity;
* tracking execution state;
* attaching operation identity;
* resolving reliability policy;
* activating reliability;
* tracking attempts;
* tracking retries;
* tracking failure classification;
* tracking recovery;
* exposing execution metadata;
* enforcing Runtime integrity;
* completing the execution lifecycle.

The Runtime lifecycle is:

```text
CREATED
   │
   ▼
INITIALIZED
   │
   ▼
ACTIVE
   │
   ▼
COMPLETED
```

Invalid transitions are rejected by the Runtime.

---

# 8. API Operation Model

API operations are explicitly modeled.

Current operations include:

```text
USER_REGISTER
USER_LOGIN
USER_PROFILE
ID_UPLOAD
HEALTH_LIVENESS
HEALTH_READINESS
```

Each operation has:

```text
Operation
├── identity
├── category
├── characteristics
└── metadata
```

Examples of operation characteristics include:

```text
requiresDatabase
requiresStorage
asynchronous
```

This allows the Runtime to reason about an operation independently from its HTTP route implementation.

---

# 9. API Reliability Model

Reliability behavior is policy-driven.

The API Runtime resolves a reliability policy for each operation.

Conceptually:

```text
Operation
   │
   ▼
Policy Resolver
   │
   ▼
Reliability Policy
   │
   ├── timeout
   ├── retry
   ├── maxRetries
   └── recoverable
```

Current operation policies include:

| Operation         | Timeout | Retry | Max Retries | Recoverable |
| ----------------- | ------: | ----: | ----------: | ----------: |
| User Login        |      5s |    No |           0 |          No |
| User Registration |      5s |    No |           0 |          No |
| User Profile      |      3s |    No |           0 |          No |
| ID Upload         |     10s |   Yes |           2 |         Yes |
| Liveness          |      1s |    No |           0 |          No |
| Readiness         |      3s |    No |           0 |          No |

The purpose of this model is to prevent indiscriminate retry behavior.

Not every failed operation is safe to retry.

---

# 10. API Infrastructure Boundary

The API uses an explicit infrastructure execution boundary.

Application controllers invoke:

```text
executeInfrastructureOperation()
```

rather than embedding reliability logic directly around every dependency call.

The resulting architecture is:

```text
Controller
    │
    ▼
Infrastructure Boundary
    │
    ▼
Reliability Executor
    │
    ├── Timeout
    ├── Failure Classification
    ├── Retry Decision
    ├── Backoff
    └── Recovery Tracking
    │
    ▼
Infrastructure Dependency
```

This creates a consistent reliability boundary around PostgreSQL, Redis, and MinIO operations.

---

# 11. API Dependency Model

The API has three primary infrastructure dependencies.

```text
                 ┌─────────────┐
                 │     API     │
                 └──────┬──────┘
                        │
          ┌─────────────┼─────────────┐
          │             │             │
          ▼             ▼             ▼
    PostgreSQL        Redis          MinIO
```

### PostgreSQL

Used for relational application state.

### Redis

Used for asynchronous job enqueueing and queue-related operations.

### MinIO

Used for object storage operations.

The API should therefore be considered unavailable for some operations when the corresponding dependency is unavailable, even if the API process itself remains running.

---

# 12. API Data Ownership

The API is the primary service responsible for synchronous mutation of user-facing application state.

Examples include:

```text
User Registration
      │
      ▼
PostgreSQL
```

and:

```text
ID Upload
      │
      ├── Object → MinIO
      │
      └── Reference → PostgreSQL
```

The API does not own the Worker processing lifecycle.

It creates the asynchronous work and hands that work to the queue.

---

# 13. API Authentication Boundary

Authentication is implemented within the API.

The primary flow is:

```text
Client
  │
  ▼
API
  │
  ▼
PostgreSQL
  │
  ▼
Credential Verification
  │
  ▼
JWT
  │
  ▼
Client
```

Authenticated routes use the authentication middleware before the protected controller is executed.

For example:

```text
GET /profile
     │
     ▼
Authentication Middleware
     │
     ▼
Runtime Operation Resolution
     │
     ▼
Runtime Activation
     │
     ▼
Controller
```

The API therefore has two distinct execution concerns:

```text
Authentication
+
Reliability Runtime
```

These concerns cooperate but are not the same architectural mechanism.

---

# 14. Worker Service

## 14.1 Responsibility

The Worker is responsible for asynchronous background processing.

Its primary responsibility is:

```text
Queue
  │
  ▼
Worker
  │
  ▼
Process Job
```

The Worker should not be treated as an HTTP replica of the API.

It has a different execution model and therefore requires its own runtime integration adapted to job processing.

---

# 15. Worker Execution Model

The Worker is driven by BullMQ and Redis.

The logical flow is:

```text
API
 │
 │ enqueue
 ▼
Redis
 │
 │ job
 ▼
BullMQ
 │
 ▼
Worker Runtime
 │
 ▼
Job Handler
 │
 ├── PostgreSQL
 └── MinIO
```

The Worker therefore has no dependency on the HTTP request lifecycle for normal job execution.

---

# 16. Worker Runtime

The Worker uses the same architectural Runtime principles as the API, adapted to the Worker execution model.

The Worker Runtime provides the equivalent execution-level capabilities required for reliable background processing:

```text
Job
 │
 ▼
Execution Context
 │
 ▼
Operation Context
 │
 ▼
Reliability Policy
 │
 ▼
Reliability Activation
 │
 ▼
Job Execution
 │
 ▼
Infrastructure Boundary
 │
 ▼
Completion / Failure
```

The important distinction is:

```text
API Runtime
    └── HTTP Request Execution

Worker Runtime
    └── Background Job Execution
```

The architecture is therefore shared at the capability level but adapted at the execution-boundary level.

---

# 17. Worker Reliability Model

The Worker requires reliability controls appropriate to asynchronous processing.

The Runtime capability profile includes:

```text
Timeout
Retry
Exponential Backoff
Graceful Cancellation
Idempotency
Resource Protection
Health Verification
```

These mechanisms must cooperate with BullMQ rather than attempt to replace BullMQ's queue semantics.

The conceptual relationship is:

```text
BullMQ
   │
   │ queue lifecycle
   ▼
Worker Runtime
   │
   │ execution reliability
   ▼
Job Handler
```

BullMQ remains responsible for queue mechanics.

The Worker Runtime governs the reliability of the execution performed around those queue mechanics.

---

# 18. Worker Concurrency

The Worker supports configurable concurrency.

The default configuration is:

```text
WORKER_CONCURRENCY=2
```

Concurrency is an operational resource-control parameter.

Increasing concurrency can improve throughput, but can also increase:

* CPU consumption;
* memory consumption;
* database pressure;
* object-storage pressure;
* queue consumption rate.

Therefore Worker concurrency must be considered together with host and container resource limits.

---

# 19. Worker Dependency Model

The Worker primarily depends on:

```text
Worker
 ├── Redis
 ├── PostgreSQL
 └── MinIO
```

Redis is the queue infrastructure dependency.

PostgreSQL is used for relational application operations required during processing.

MinIO is used for object-storage operations.

The dependency graph is therefore:

```text
                  Redis
                    │
                    │ jobs
                    ▼
                 Worker
                 /     \
                /       \
               ▼         ▼
        PostgreSQL      MinIO
```

---

# 20. Worker Data Ownership

The Worker does not become the owner of the application's entire persistent state.

Instead, it performs background processing against existing application data.

For example:

```text
API
 │
 ├── stores object
 ├── persists object reference
 └── enqueues job
          │
          ▼
        Worker
          │
          ├── reads required state
          ├── processes object
          └── updates required state
```

This preserves the separation between:

```text
Application State
```

and:

```text
Processing Execution
```

---

# 21. API-to-Worker Communication

The API and Worker do not communicate through direct HTTP calls for background processing.

The communication boundary is Redis/BullMQ.

```text
API
 │
 │ enqueue
 ▼
Redis / BullMQ
 │
 │ consume
 ▼
Worker
```

This creates temporal decoupling.

The API can complete an HTTP request after successfully enqueueing the job without waiting for the Worker to finish processing it.

---

# 22. Asynchronous Workflow Boundary

The asynchronous boundary is particularly important in the ID upload workflow.

```text
                    Synchronous Boundary
                           │
Client → Gateway → API ─────┤
                           │
                           ▼
                       MinIO Upload
                           │
                           ▼
                     PostgreSQL Update
                           │
                           ▼
                       Job Enqueue
                           │
═══════════════════════════╪════════════════════════════
                           │
                    Asynchronous Boundary
                           │
                           ▼
                         Redis
                           │
                           ▼
                        Worker
                           │
                           ▼
                     Job Processing
```

The horizontal boundary represents the point where request processing hands work to asynchronous processing.

This is an important architectural boundary because it determines:

* latency expectations;
* failure semantics;
* retry behavior;
* user-visible status;
* queue behavior;
* operational monitoring.

---

# 23. Gateway Service

The Gateway is implemented using Nginx.

Its responsibilities are intentionally limited.

It provides:

* external HTTP entry;
* reverse proxying;
* routing toward the API;
* boundary between external traffic and application services.

The Gateway does not own:

* authentication business logic;
* database access;
* queue processing;
* object storage;
* application reliability policy.

Its architecture is:

```text
External Traffic
      │
      ▼
   Gateway
      │
      ▼
     API
```

The Worker remains outside this path.

---

# 24. Infrastructure Services

Infrastructure services provide capabilities consumed by application services.

They are not application services themselves.

```text
Application Services
        │
        ▼
┌─────────────────────────────┐
│ Infrastructure Services     │
│                             │
│ PostgreSQL                  │
│ Redis                       │
│ MinIO                       │
└─────────────────────────────┘
```

Their responsibilities are:

### PostgreSQL

Persistent relational data.

### Redis

Queue and transient/in-memory infrastructure.

### MinIO

Persistent object storage.

These services are replaceable infrastructure implementations from the application's architectural perspective, provided their contracts remain compatible.

---

# 25. Dependency Direction

The intended dependency direction is:

```text
External Client
      │
      ▼
   Gateway
      │
      ▼
Application Services
      │
      ▼
Infrastructure Services
```

Not:

```text
Infrastructure
      │
      ▼
Application
```

Application services consume infrastructure capabilities.

Infrastructure services do not own application workflow semantics.

---

# 26. Service-to-Service Communication Matrix

| Source     | Target       | Protocol / Mechanism | Purpose                     | Sync |
| ---------- | ------------ | -------------------- | --------------------------- | ---- |
| Client     | Gateway      | HTTP                 | External request            | Yes  |
| Gateway    | API          | HTTP                 | Request forwarding          | Yes  |
| API        | PostgreSQL   | PostgreSQL protocol  | Application state           | Yes  |
| API        | Redis        | Redis/BullMQ         | Queue operations            | Yes  |
| API        | MinIO        | S3-compatible API    | Object storage              | Yes  |
| API        | Worker       | Redis/BullMQ         | Job dispatch                | No   |
| Worker     | Redis        | Redis/BullMQ         | Job consumption             | Yes  |
| Worker     | PostgreSQL   | PostgreSQL protocol  | Background state operations | Yes  |
| Worker     | MinIO        | S3-compatible API    | Object processing           | Yes  |
| Services   | Prometheus   | HTTP scrape          | Metrics                     | Pull |
| Containers | Promtail     | File/log source      | Log collection              | Pull |
| Promtail   | Loki         | HTTP                 | Log ingestion               | Push |
| Prometheus | Alertmanager | HTTP                 | Alert delivery              | Push |
| Grafana    | Prometheus   | HTTP                 | Metrics queries             | Pull |
| Grafana    | Loki         | HTTP                 | Log queries                 | Pull |

---

# 27. Synchronous Versus Asynchronous Boundaries

The architecture deliberately distinguishes two communication classes.

## Synchronous

```text
Client
  │
  ▼
Gateway
  │
  ▼
API
  │
  ├── PostgreSQL
  ├── Redis
  └── MinIO
```

The caller waits for the operation result.

---

## Asynchronous

```text
API
 │
 ▼
Redis
 │
 ▼
Worker
```

The caller does not wait for the Worker to complete processing.

This distinction is fundamental to the system's scalability and reliability model.

---

# 28. Service Health Model

Each application service has a different health model.

## API

The API exposes:

```text
/health/live
/health/ready
```

Liveness answers:

```text
"Is the API process alive?"
```

Readiness answers a broader question:

```text
"Can the API currently perform the required ready-state operations?"
```

---

## Worker

The Worker is monitored through:

* process/container health;
* metrics;
* queue state;
* processing activity;
* failure counters;
* job latency;
* Redis connectivity.

Worker health is therefore more closely associated with operational processing capability than with HTTP readiness.

---

# 29. Service Observability

Each service participates in the observability architecture.

## API Signals

The API provides:

```text
HTTP metrics
Business metrics
Runtime reliability metrics
Structured logs
Health endpoints
```

Examples include:

```text
mw_api_http_requests_total
mw_api_http_request_duration_seconds
mw_api_http_errors_total
mw_business_user_registrations_total
mw_business_user_logins_total
mw_business_id_uploads_total
```

---

## Worker Signals

The Worker exposes processing-oriented signals such as:

```text
jobsProcessedTotal
jobFailuresTotal
jobsRetriedTotal
jobsActive
queueDepth
queuePaused
jobDuration
```

These signals answer questions such as:

* Is the Worker running?
* Is the queue growing?
* Are jobs failing?
* Is processing slowing down?
* Are retries increasing?
* Is the Worker saturated?

---

# 30. Service Logging Model

Both application services produce structured JSON logs.

The logical log structure contains fields such as:

```text
timestamp
level
service
environment
event
request_id
execution_id
operation_id
user_id
dependency
error information
```

The API additionally uses operation context to associate logs with application operations.

The Worker adapts the equivalent context to job execution.

This provides a common observability model while preserving service-specific execution semantics.

---

# 31. Service Reliability Model

Reliability is not implemented identically at every service boundary.

Instead:

```text
Common Reliability Architecture
             │
      ┌──────┴──────┐
      │             │
      ▼             ▼
     API          Worker
      │             │
 HTTP Runtime   Job Runtime
      │             │
      └──────┬──────┘
             │
       Infrastructure
         Boundaries
```

The common capabilities include:

* execution identity;
* operation identity;
* timeout;
* failure classification;
* retry;
* backoff;
* failure tracking;
* recovery tracking;
* observability.

The execution mechanics differ because HTTP requests and background jobs have different lifecycle semantics.

---

# 32. Failure Isolation

A failure in one service should not automatically imply failure of every service.

For example:

```text
Worker Failure
     │
     ├── Background processing unavailable
     │
     └── API process may remain healthy
```

Similarly:

```text
API Failure
     │
     ├── HTTP operations unavailable
     │
     └── Existing Worker process may continue
```

However, shared dependencies create indirect coupling.

For example:

```text
PostgreSQL Failure
      │
      ├── API operations affected
      └── Worker operations affected
```

Therefore service isolation is logical rather than absolute.

---

# 33. Failure Propagation Matrix

| Failure                | API                            | Worker                      | Queue                      | User Impact                        |
| ---------------------- | ------------------------------ | --------------------------- | -------------------------- | ---------------------------------- |
| API process failure    | Unavailable                    | May continue                | May continue               | HTTP operations unavailable        |
| Worker process failure | May remain healthy             | Unavailable                 | Backlog may grow           | Background processing delayed      |
| PostgreSQL failure     | Dependent operations fail      | Dependent jobs fail         | Queue may remain available | Data-dependent operations degraded |
| Redis failure          | Queue operations fail          | Job consumption affected    | Unavailable                | Async workflows degraded           |
| MinIO failure          | Upload/storage operations fail | Object-processing jobs fail | Queue may remain available | Object workflows degraded          |
| Gateway failure        | Externally inaccessible        | May continue internally     | May continue               | External HTTP access unavailable   |
| Host failure           | Unavailable                    | Unavailable                 | Unavailable                | System-wide outage                 |

---

# 34. Service Recovery Boundaries

Different failures are recovered at different layers.

```text
Operation Failure
      │
      ▼
Runtime Recovery
      │
      ├── Retry
      └── Backoff
```

If the service process itself fails:

```text
Process Failure
      │
      ▼
Docker
      │
      ▼
Container Restart
```

If the host fails:

```text
Host Failure
      │
      ▼
Infrastructure Recovery
```

These are separate recovery mechanisms.

A service architecture should not rely on one layer to solve failures belonging to another layer.

---

# 35. Scaling Model

The API and Worker have different scaling characteristics.

## API Scaling

API scaling primarily addresses:

* concurrent HTTP requests;
* request throughput;
* latency;
* CPU utilization;
* memory utilization.

Conceptually:

```text
           ┌── API instance
Gateway ───┼── API instance
           └── API instance
```

---

## Worker Scaling

Worker scaling primarily addresses:

* queue backlog;
* job throughput;
* processing latency;
* concurrency;
* CPU and memory pressure.

Conceptually:

```text
                 ┌── Worker
Redis Queue ─────┼── Worker
                 └── Worker
```

The current deployment uses a single Worker instance, but the logical architecture does not require that limitation.

---

# 36. Statelessness

The API is designed so that request execution state is represented within the request-scoped Runtime rather than in global mutable application state.

This supports future horizontal scaling.

The API's durable application state is externalized to:

```text
PostgreSQL
Redis
MinIO
```

This means:

```text
API Process
    ≠
Application State
```

This separation is an important prerequisite for scaling the API service independently.

---

# 37. Worker State

Worker execution is inherently stateful at the job-execution level.

The Worker maintains active execution state such as:

```text
active jobs
attempts
retries
job duration
failure state
```

However, durable job coordination is provided by BullMQ/Redis.

Therefore:

```text
Worker Process State
        ≠
Durable Queue State
```

This distinction allows a Worker process to be restarted while preserving queue-level job coordination according to BullMQ semantics.

---

# 38. Service Configuration

Service configuration is environment-driven.

Typical configuration dimensions include:

```text
Environment
Ports
Database connection
Redis connection
Object storage connection
JWT configuration
Worker concurrency
Application version
```

The deployment system generates the environment configuration used by containers.

Application source code should not become the source of truth for deployment-specific infrastructure configuration.

---

# 39. Service Versioning

API and Worker versions are tracked independently by deployment state.

Conceptually:

```text
Deployment State
│
├── API
│   ├── current
│   └── previous
│
└── Worker
    ├── current
    └── previous
```

This is important because API and Worker deployments may evolve independently while still participating in the same asynchronous workflow.

However, compatibility between API-produced jobs and Worker-consumed jobs must remain an explicit architectural consideration.

---

# 40. API–Worker Compatibility

The API and Worker form a producer-consumer relationship.

```text
API
 │
 │ Job Contract
 ▼
Redis / BullMQ
 │
 │ Job Contract
 ▼
Worker
```

Therefore the job payload is effectively an internal API between the two services.

Changes to:

* job name;
* payload structure;
* required fields;
* object references;
* processing expectations;

must be treated as compatibility-sensitive changes.

The queue is therefore not merely a transport mechanism.

It is a service integration boundary.

---

# 41. Service Ownership Rules

The following ownership rules apply.

### API owns

* HTTP application operations;
* authentication;
* synchronous user-facing workflows;
* request-scoped Runtime;
* job creation.

### Worker owns

* background job execution;
* processing lifecycle;
* job-level Runtime;
* asynchronous failure handling.

### PostgreSQL owns

* relational persistence.

### Redis/BullMQ owns

* queue coordination and job delivery semantics.

### MinIO owns

* object persistence.

### Gateway owns

* external HTTP ingress and routing.

### Observability owns

* telemetry collection;
* storage;
* visualization;
* alerting.

No service should silently assume responsibility belonging to another service.

---

# 42. Service Boundary Rules

The architecture follows these rules.

## Rule 1 — API Does Not Process Long-Running Background Work

Long-running work should cross the asynchronous boundary.

```text
API → Redis → Worker
```

---

## Rule 2 — Worker Does Not Become an HTTP Dependency

The API does not depend on direct Worker HTTP invocation for queue-based processing.

---

## Rule 3 — Application Services Do Not Own Infrastructure Internals

Services interact with PostgreSQL, Redis, and MinIO through their defined application/infrastructure interfaces.

---

## Rule 4 — Reliability Is Centralized at Execution Boundaries

Retry and timeout logic should not be independently duplicated throughout controllers and job handlers.

---

## Rule 5 — Observability Does Not Own Business Logic

Metrics and logs describe application behavior.

They do not become part of business decisions unless explicitly required.

---

## Rule 6 — Service Health Is Not Equivalent to Process Existence

A process can be running while its operational capabilities are degraded.

---

# 43. Anti-Patterns Avoided

The service architecture intentionally avoids several patterns.

## 43.1 API Performing Worker Processing

Bad:

```text
HTTP Request
    │
    ▼
API
    │
    ▼
Long Processing
    │
    ▼
HTTP Response
```

Preferred:

```text
HTTP Request
    │
    ▼
API
    │
    ▼
Enqueue
    │
    ▼
HTTP Response

Redis
    │
    ▼
Worker
    │
    ▼
Processing
```

---

## 43.2 Distributed Retry Logic

Bad:

```text
Controller A → retry
Controller B → retry
Controller C → retry
```

Preferred:

```text
Infrastructure Boundary
        │
        ▼
Reliability Executor
        │
        ├── timeout
        ├── retry
        └── backoff
```

---

## 43.3 Shared Mutable Runtime State

Bad:

```text
Global Runtime
      │
      ├── Request A
      ├── Request B
      └── Request C
```

Preferred:

```text
Request A → Runtime A
Request B → Runtime B
Request C → Runtime C
```

---

## 43.4 Direct Infrastructure Coupling Everywhere

Bad:

```text
Controller
  ├── pool.query(...)
  ├── redis.call(...)
  ├── retry(...)
  ├── timeout(...)
  └── logging(...)
```

Preferred:

```text
Controller
     │
     ▼
Infrastructure Boundary
     │
     ├── Reliability
     ├── Failure Classification
     ├── Metrics
     └── Logging
     │
     ▼
Dependency
```

---

# 44. Service Evolution Strategy

The service architecture provides explicit boundaries that support future evolution.

Possible future changes include:

```text
Current
───────
Single API
Single Worker
Single Host
Docker Compose


Future
──────
Multiple API instances
Multiple Worker instances
Independent infrastructure
Orchestrated deployment
```

The architecture should evolve by strengthening existing boundaries rather than bypassing them.

For example:

```text
Current:
API → Redis → Worker

Future:
API instances → Shared Queue → Worker pool
```

The logical interaction remains the same even if the physical deployment changes.

---

# 45. Architectural Summary

The Mini-Write service architecture can be summarized as:

```text
                         External Client
                               │
                               ▼
                          ┌──────────┐
                          │ Gateway  │
                          └────┬─────┘
                               │
                               ▼
                    ┌────────────────────┐
                    │        API         │
                    │                    │
                    │ HTTP Runtime       │
                    │ Application Logic  │
                    └─────┬──────┬───────┘
                          │      │
                  ┌───────┘      └────────┐
                  ▼                       ▼
            PostgreSQL                  MinIO
                  ▲                       ▲
                  │                       │
                  │                  ┌────┘
                  │                  │
                  │             ┌────┴────┐
                  │             │ Worker  │
                  │             │ Runtime │
                  │             └────▲────┘
                  │                  │
                  │             ┌────┴────┐
                  └─────────────│  Redis  │
                                └─────────┘
```

The core service relationship is:

```text
Gateway
   │
   ▼
 API
   │
   ├── synchronous infrastructure operations
   │
   └── asynchronous job dispatch
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

The architectural distinction between API and Worker is therefore not merely organizational.

It represents two different execution models:

```text
API
└── Request-Oriented Execution

Worker
└── Job-Oriented Execution
```

Both share the same reliability philosophy and Runtime capabilities, but each adapts those capabilities to its own execution boundary.

This provides the fundamental service-level separation required for Mini-Write to evolve from a single-node Docker Compose deployment toward a more distributed architecture without collapsing application, reliability, and infrastructure responsibilities into the same layer.

```
```
