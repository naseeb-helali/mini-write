# Runtime Architecture

## 1. Purpose

This document defines the Runtime Architecture of Mini-Write.

The Runtime is the operational execution layer responsible for governing how an application operation executes under normal and abnormal conditions.

It provides a shared execution model for:

- request identity;
- execution identity;
- operation identity;
- execution lifecycle;
- reliability policy;
- failure classification;
- dependency execution;
- timeout enforcement;
- retry decisions;
- recovery tracking;
- runtime integrity;
- failure propagation;
- runtime observability.

The Runtime is not the business logic of the application.

It is an architectural control layer that surrounds application execution and provides a consistent operational contract.

---

# 2. Architectural Position

The Runtime sits between the transport/application layer and infrastructure-dependent execution.

Conceptually:

```text
┌──────────────────────────────────────────────┐
│                 Client / HTTP                │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│              Express / Routing               │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│                 Runtime Layer                │
│                                              │
│  Bootstrap                                   │
│  Guard                                       │
│  Operation Resolution                        │
│  State Activation                            │
│  Execution Context                           │
│  Reliability Policy                          │
│  Failure Classification                      │
│  Infrastructure Boundary                    │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│             Application Logic                │
│                                              │
│  Controllers                                 │
│  Services                                    │
│  Workflows                                   │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│            Infrastructure Dependencies       │
│                                              │
│ PostgreSQL │ Redis │ MinIO │ External APIs  │
└──────────────────────────────────────────────┘
````

The Runtime therefore establishes an operational boundary around application execution rather than replacing the application itself.

---

# 3. Runtime Architectural Principle

The central principle is:

> Application code performs business work; Runtime governs the operational execution of that work.

This distinction is fundamental.

For example, the registration controller is responsible for:

```text
Validate input
    │
    ▼
Hash password
    │
    ▼
Insert user
    │
    ▼
Return response
```

The Runtime is responsible for:

```text
Identify operation
    │
    ▼
Resolve reliability policy
    │
    ▼
Activate execution
    │
    ▼
Govern infrastructure execution
    │
    ├── timeout
    ├── retry
    ├── failure classification
    └── recovery tracking
```

The two concerns remain complementary.

---

# 4. Runtime Responsibilities

The Runtime owns the following responsibilities.

## 4.1 Execution Identity

Every execution receives:

* `requestId`;
* `executionId`.

These identifiers provide stable identity for the execution lifecycle.

---

## 4.2 Operation Identity

Every governed operation receives a known operation identifier.

Examples:

```text
user_login
user_register
user_profile
id_upload
health_liveness
health_readiness
```

---

## 4.3 Lifecycle Management

The Runtime controls the execution lifecycle:

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

Illegal transitions are rejected.

---

## 4.4 Reliability Policy

Each operation resolves to a Reliability Policy defining values such as:

* timeout;
* retry enabled/disabled;
* maximum retries;
* recoverability.

---

## 4.5 Failure Classification

Runtime failures are classified into categories such as:

```text
TIMEOUT
DEPENDENCY
VALIDATION
AUTHENTICATION
AUTHORIZATION
INTERNAL
```

---

## 4.6 Dependency Execution

Infrastructure operations execute through a Runtime boundary.

This creates a common location for:

* timeout enforcement;
* retry decisions;
* failure classification;
* reliability metrics;
* structured operational logging.

---

## 4.7 Runtime Integrity

The Runtime validates that:

* the Runtime exists;
* it has the expected state;
* the Runtime instance has not been replaced;
* execution identity has not changed.

---

## 4.8 Operational Observability

Runtime execution emits:

* structured logs;
* reliability metrics;
* operation outcomes;
* retry information;
* failure information;
* execution completion information.

---

# 5. Runtime Non-Responsibilities

The Runtime deliberately does not own:

* business rules;
* database schema;
* HTTP routing;
* authentication implementation;
* JWT generation;
* file validation;
* object-storage implementation;
* queue implementation;
* image processing;
* domain-specific workflows.

For example:

```text
Runtime
  └── decides how a dependency operation is governed

Storage Service
  └── decides how an object is stored
```

Likewise:

```text
Runtime
  └── decides whether a transient failure may be retried

BullMQ
  └── implements queue/job execution
```

This separation prevents the Runtime from becoming a replacement for application infrastructure.

---

# 6. Runtime Package Structure

The API Runtime is organized under:

```text
api/src/runtime/
```

The major architectural areas are:

```text
runtime/
├── context/
│   ├── executionContext.js
│   └── operationContext.js
│
├── infrastructure/
│   ├── dependencies.js
│   └── infrastructureBoundary.js
│
├── middleware/
│   ├── runtimeBootstrap.js
│   ├── runtimeGuard.js
│   ├── runtimeOperationResolution.js
│   ├── runtimeStateActivation.js
│   └── runtimeFailureHandler.js
│
├── reliability/
│   ├── failureClassifier.js
│   ├── policyResolver.js
│   ├── reliabilityPolicy.js
│   ├── retryExecutor.js
│   └── runtimeErrors.js
│
├── metadata/
│   └── runtimeMetadata.js
│
├── observability/
│   └── reliabilityMetrics.js
│
├── index.js
└── runtimeAccess.js
```

This structure separates execution context, lifecycle integration, reliability, infrastructure boundaries, and observability.

---

# 7. Runtime Execution Model

A governed HTTP request follows this conceptual pipeline:

```text
Request
   │
   ▼
Runtime Bootstrap
   │
   ▼
Execution Context Created
   │
   ▼
Runtime Initialized
   │
   ▼
Runtime Guard
   │
   ▼
Operation Resolution
   │
   ▼
Reliability Policy Resolution
   │
   ▼
Reliability Activation
   │
   ▼
Runtime ACTIVE
   │
   ▼
Application Operation
   │
   ▼
Infrastructure Boundary
   │
   ▼
Reliability Executor
   │
   ├── success
   │
   ├── retry
   │
   ├── timeout
   │
   └── failure
   │
   ▼
Response
   │
   ▼
Runtime Completion
```

This is the primary Runtime execution model.

---

# 8. Execution Context

The Execution Context is the Runtime's central state object.

It is created through:

```text
createExecutionContext()
```

The context contains several categories of state.

---

## 8.1 Identity

```text
identity
├── requestId
└── executionId
```

`requestId` identifies the request.

`executionId` identifies the Runtime execution.

Both are generated independently.

---

## 8.2 Lifecycle State

```text
state
```

Possible values:

```text
created
initialized
active
completed
```

---

## 8.3 Operation

```text
operation
```

Contains the resolved operation definition.

---

## 8.4 Reliability Policy

```text
policy
```

Contains the resolved reliability contract.

---

## 8.5 Reliability State

```text
reliability
├── activated
├── attempts
├── retries
├── lastFailureType
├── lastDependency
└── recovered
```

---

## 8.6 Failure State

```text
failure
├── occurred
├── error
└── classification
```

---

## 8.7 User State

```text
user
└── id
```

---

## 8.8 Metadata

Runtime metadata captures execution-level information without requiring business components to own it.

---

## 8.9 Timestamps

```text
timestamps
├── createdAt
├── initializedAt
├── activatedAt
└── completedAt
```

---

# 9. Execution Identity Model

The Runtime uses two identities:

```text
Request Identity
    │
    └── requestId

Execution Identity
    │
    └── executionId
```

They are deliberately separate.

The model is:

```text
HTTP Request
     │
     ├── requestId
     │
     └── executionId
```

This allows logs and operational telemetry to distinguish request correlation from Runtime execution identity.

---

# 10. Request ID Propagation

The Runtime Bootstrap exposes the generated request identifier through:

```text
X-Request-Id
```

The same identity is also attached to:

```text
req.runtime
req.context
req.runtimeIntegrity
```

This allows application and infrastructure layers to correlate execution information.

---

# 11. Runtime Integrity Model

After Runtime initialization, the request contains an integrity record:

```text
runtimeIntegrity
├── runtime
├── executionId
└── requestId
```

The Runtime Guard later validates these values.

Conceptually:

```text
Created Runtime
      │
      ▼
Integrity Snapshot
      │
      ▼
Request Pipeline
      │
      ▼
Verification
```

This provides protection against accidental Runtime replacement or identity inconsistency.

---

# 12. Runtime Lifecycle

The Runtime lifecycle is explicitly stateful.

```text
             ┌──────────────┐
             │   CREATED    │
             └──────┬───────┘
                    │ initialize
                    ▼
             ┌──────────────┐
             │ INITIALIZED  │
             └──────┬───────┘
                    │ activate
                    ▼
             ┌──────────────┐
             │    ACTIVE    │
             └──────┬───────┘
                    │ complete
                    ▼
             ┌──────────────┐
             │  COMPLETED   │
             └──────────────┘
```

The allowed transitions are:

```text
CREATED
  └── INITIALIZED

INITIALIZED
  ├── ACTIVE
  └── COMPLETED

ACTIVE
  └── COMPLETED

COMPLETED
  └── terminal
```

---

# 13. Why Explicit Lifecycle States Exist

Without explicit lifecycle state, application code could execute operations in ambiguous conditions.

For example:

```text
Operation
   │
   ▼
Reliability policy?
   │
   ▼
Runtime active?
```

The Runtime prevents this ambiguity.

A request cannot legitimately become `ACTIVE` until:

1. Runtime exists;
2. operation is resolved;
3. policy is attached;
4. reliability is activated.

This establishes deterministic execution ordering.

---

# 14. Operation Context

The Operation Context defines what operation is being executed.

An operation contains:

```text
identity
category
characteristics
metadata
```

Example:

```text
USER_REGISTER
```

belongs to:

```text
authentication
```

while:

```text
ID_UPLOAD
```

belongs to:

```text
storage
```

---

# 15. Operation Characteristics

Operations may declare characteristics such as:

```text
requiresDatabase
requiresStorage
asynchronous
```

For example:

```text
ID_UPLOAD
├── requiresDatabase: true
├── requiresStorage: true
└── asynchronous: true
```

These characteristics provide machine-readable operational context.

They allow the Runtime architecture to understand the operational nature of an operation without embedding business logic into the Runtime.

---

# 16. Operation Resolution

Operation resolution occurs through:

```text
runtimeOperationResolution
```

The route declares the operation:

```text
Route
  │
  ▼
Operation Definition
  │
  ▼
Operation Context
  │
  ▼
Runtime.attachOperation()
```

The Runtime then resolves the Reliability Policy using the operation identity.

---

# 17. Reliability Policy Model

Reliability is operation-specific.

A Reliability Policy contains:

```text
identity
├── id
└── name

timeout
retry
maxRetries
recoverable
metadata
```

This allows different operations to have different reliability characteristics.

---

# 18. Example Reliability Policies

Current policies include:

| Operation         | Timeout | Retry | Max Retries | Recoverable |
| ----------------- | ------: | ----: | ----------: | ----------: |
| User Login        |      5s |    No |           0 |          No |
| User Registration |      5s |    No |           0 |          No |
| User Profile      |      3s |    No |           0 |          No |
| ID Upload         |     10s |   Yes |           2 |         Yes |
| Health Liveness   |      1s |    No |           0 |          No |
| Health Readiness  |      3s |    No |           0 |          No |

The policy is therefore part of the operation contract.

---

# 19. Policy Resolution

Policy resolution follows:

```text
Operation ID
     │
     ▼
Policy Resolver
     │
     ├── known operation
     │       │
     │       ▼
     │    operation policy
     │
     └── unknown operation
             │
             ▼
        default policy
```

This ensures that every operation has a policy.

---

# 20. Default Policy

A default policy exists for operations without an explicit policy.

The current default is conservative:

```text
timeout: 5000ms
retry: false
maxRetries: 0
recoverable: false
```

This reflects the principle:

> Reliability behavior should be explicitly enabled rather than implicitly assumed.

---

# 21. Runtime State Activation

Once the operation and policy are attached:

```text
Runtime
  │
  ├── Operation
  │
  └── Policy
       │
       ▼
activateReliability()
       │
       ▼
ACTIVE
```

The activation middleware validates that:

* Runtime exists;
* policy exists;
* reliability activation succeeds.

Only then is the execution transitioned to `ACTIVE`.

---

# 22. Infrastructure Boundary

Application code does not execute infrastructure operations directly when those operations are governed by Runtime reliability.

Instead:

```text
Controller
    │
    ▼
executeInfrastructureOperation()
    │
    ▼
Runtime Boundary
    │
    ▼
Reliability Executor
    │
    ▼
Dependency
```

The current boundary supports:

```text
PostgreSQL
Redis
MinIO
```

through the dependency registry.

---

# 23. Dependency Registry

Dependencies are explicitly named:

```text
POSTGRESQL
REDIS
MINIO
```

This provides a controlled vocabulary for Runtime dependency execution.

Instead of arbitrary strings being distributed throughout the application, infrastructure interactions use a shared dependency model.

---

# 24. Infrastructure Execution Flow

A typical infrastructure operation follows:

```text
Application
    │
    ▼
Infrastructure Boundary
    │
    ├── Validate request
    ├── Obtain Runtime
    ├── Identify operation
    ├── Start duration timer
    ├── Emit start event
    │
    ▼
Reliability Executor
    │
    ▼
Dependency Operation
```

On success:

```text
Dependency
    │
    ▼
Success
    │
    ├── Metrics
    ├── Logs
    └── Runtime outcome
```

On failure:

```text
Dependency
    │
    ▼
Failure
    │
    ▼
Classification
    │
    ▼
Retry Decision
    │
    ├── Retry
    │
    └── Propagate
```

---

# 25. Reliability Executor

The Reliability Executor is responsible for applying the Runtime policy to an infrastructure operation.

Its conceptual algorithm is:

```text
attempt = 1

while attempt <= maxAttempts:

    execute operation with timeout

    if success:
        return success

    classify failure

    if retry is not allowed:
        propagate failure

    if failure is not retryable:
        propagate failure

    register retry

    calculate backoff

    wait

    attempt++
```

This creates a deterministic reliability execution model.

---

# 26. Timeout Model

Timeouts are implemented as an execution boundary.

Conceptually:

```text
Operation
   │
   ├───────────────┐
   │               │
   ▼               ▼
Operation       Timeout
Promise           Timer
   │               │
   └───────┬───────┘
           ▼
       Race Result
```

If the operation exceeds the configured timeout:

```text
RuntimeTimeoutError
```

is generated.

The timeout error contains:

```text
dependency
timeoutMs
retryAttempt
```

This allows timeout failures to retain operational context.

---

# 27. Timeout Does Not Automatically Cancel Work

The Runtime timeout implementation uses `Promise.race()`.

Therefore:

```text
Timeout reached
    │
    ▼
Runtime operation rejects
```

does not necessarily mean that the underlying asynchronous operation has physically stopped.

This is an important implementation characteristic.

The Runtime currently provides:

```text
execution timeout
```

rather than guaranteed:

```text
underlying operation cancellation
```

This distinction is important for future reliability evolution.

---

# 28. Failure Classification

The Runtime classifies failures using:

```text
classifyFailure()
```

The current categories are:

```text
TIMEOUT
DEPENDENCY
VALIDATION
AUTHENTICATION
AUTHORIZATION
INTERNAL
```

Classification is based on signals such as:

* error name;
* error code;
* HTTP status;
* dependency context.

---

# 29. Failure Classification Flow

```text
Error
 │
 ├── Runtime timeout?
 │       │
 │       └── TIMEOUT
 │
 ├── Dependency context?
 │       │
 │       └── DEPENDENCY
 │
 ├── 401?
 │       │
 │       └── AUTHENTICATION
 │
 ├── 403?
 │       │
 │       └── AUTHORIZATION
 │
 ├── 4xx?
 │       │
 │       └── VALIDATION
 │
 └── otherwise
         │
         └── INTERNAL
```

---

# 30. Retry Eligibility

Retry is not based solely on the presence of an error.

The Runtime evaluates:

```text
Retry Enabled?
       │
       ▼
Maximum Retries Remaining?
       │
       ▼
Runtime Recoverable?
       │
       ▼
Failure Retryable?
       │
       ▼
Retry
```

All relevant conditions must allow the retry.

This prevents indiscriminate retry behavior.

---

# 31. Retry Model

The current retry model uses bounded exponential backoff.

The calculation is conceptually:

```text
100ms
200ms
400ms
800ms
...
```

with an upper bound of:

```text
1000ms
```

This reduces immediate repeated pressure on a failing dependency.

---

# 32. Recovery Model

Recovery is recorded when an operation succeeds after at least one retry.

Conceptually:

```text
Attempt 1
   │
   ▼
Failure
   │
   ▼
Retry
   │
   ▼
Attempt 2
   │
   ▼
Success
   │
   ▼
Recovered = true
```

The Runtime records:

```text
reliability.recovered = true
```

This distinguishes:

```text
Success without failure
```

from:

```text
Success after transient failure
```

---

# 33. Failure Propagation

The Runtime does not silently absorb unrecoverable infrastructure failures.

After reliability execution is exhausted:

```text
Infrastructure Failure
      │
      ▼
Runtime Classification
      │
      ▼
Metrics / Logging
      │
      ▼
throw error
      │
      ▼
Application Error Handling
```

This preserves the original failure semantics while adding operational context.

---

# 34. Runtime Failure Handler

Unhandled application errors reach:

```text
runtimeFailureHandler
```

The handler:

1. checks Runtime availability;
2. registers the failure if necessary;
3. classifies it;
4. completes the Runtime;
5. records a final snapshot;
6. emits structured error telemetry;
7. returns an HTTP response where possible.

The conceptual path is:

```text
Unhandled Error
      │
      ▼
Runtime Failure Handler
      │
      ├── register failure
      ├── classify
      ├── complete Runtime
      ├── log
      └── respond
```

---

# 35. Failure Registration Semantics

The Runtime prevents duplicate failure registration.

If a failure already exists:

```text
hasFailure() == true
```

a later handler does not overwrite the original Runtime failure.

This preserves the first meaningful failure as the primary execution failure.

---

# 36. Runtime Completion

Runtime completion can occur through two mechanisms.

## Explicit failure completion

The failure handler completes the Runtime when an unhandled error reaches it.

## Response completion observer

The Bootstrap middleware listens to:

```text
res.on('finish')
```

and completes an execution still in:

```text
INITIALIZED
ACTIVE
```

state.

This creates a lifecycle safety net.

---

# 37. Completion Flow

```text
HTTP Response
      │
      ▼
response.finish
      │
      ▼
Runtime state?
      │
      ├── INITIALIZED → complete
      │
      ├── ACTIVE      → complete
      │
      └── COMPLETED   → no action
```

This ensures normal requests eventually reach the terminal Runtime state.

---

# 38. Runtime Snapshots

The Runtime exposes a snapshot containing:

```text
identity
state
operation
policy
reliability
failure
recovery
user
metadata
timestamps
```

The snapshot provides a consistent operational representation of the execution.

It is particularly useful for:

* failure logging;
* debugging;
* incident analysis;
* future telemetry enrichment.

---

# 39. Runtime Observability

Runtime observability is integrated directly into execution boundaries.

Important events include:

```text
runtime_operation_started
runtime_operation_completed
runtime_operation_retry
runtime_operation_failed
runtime_failure_handled
runtime_completed
```

This creates an observable lifecycle:

```text
STARTED
   │
   ├── RETRY
   │
   ├── FAILED
   │
   └── COMPLETED
```

---

# 40. Runtime Metrics

Runtime reliability metrics capture dimensions such as:

```text
operation
dependency
outcome
failure_type
recoverable
```

The metrics allow operational questions such as:

* Which dependency is failing?
* Which operation is affected?
* How often are retries occurring?
* Which failures are recoverable?
* Which operations are slow?
* Are operations succeeding only after retries?

The Runtime therefore produces operational evidence rather than only application logs.

---

# 41. Runtime and Application Observability

Runtime observability complements existing application observability.

Application layer:

```text
user_registered
user_login_success
id_upload_success
job_enqueued
```

Runtime layer:

```text
runtime_operation_started
runtime_operation_retry
runtime_operation_failed
runtime_completed
```

The distinction is:

```text
Business Observability
└── What happened to the application?

Runtime Observability
└── How did the operation execute?
```

---

# 42. Runtime and Structured Logging

Runtime logs include:

```text
request_id
execution_id
operation_id
dependency
failure_type
attempt
retry count
outcome
```

This creates a correlation chain:

```text
Request
  │
  ├── request_id
  ├── execution_id
  └── operation_id
          │
          ▼
      dependency
          │
          ▼
       outcome
```

This information can be consumed by the centralized logging architecture.

---

# 43. Runtime Guard

The Runtime Guard is a contract enforcement middleware.

It verifies:

```text
Runtime exists
Runtime state == initialized
Runtime instance is unchanged
Execution identity matches
Request identity matches
```

The guard therefore protects the Runtime contract before operation resolution.

---

# 44. Runtime Guard Position

The HTTP middleware sequence begins with:

```text
runtimeBootstrap
      │
      ▼
runtimeGuard
      │
      ▼
application middleware
```

This ensures the application pipeline cannot proceed without a valid Runtime context.

---

# 45. Route-Level Runtime Integration

Routes explicitly declare their Runtime operation.

For example:

```text
POST /register
    │
    ▼
USER_REGISTER
```

and:

```text
POST /upload-id
    │
    ▼
ID_UPLOAD
```

The route therefore becomes part of the Runtime operation contract.

---

# 46. Example: User Registration

The registration request follows:

```text
POST /api/v1/auth/register
            │
            ▼
Runtime Bootstrap
            │
            ▼
Runtime Guard
            │
            ▼
USER_REGISTER
            │
            ▼
User Registration Policy
            │
            ▼
Runtime ACTIVE
            │
            ▼
Controller
            │
            ▼
PostgreSQL Infrastructure Boundary
            │
            ▼
Reliability Executor
            │
            ▼
PostgreSQL
```

The business operation remains inside the controller while infrastructure reliability is delegated to the Runtime boundary.

---

# 47. Example: ID Upload

The ID upload operation is more reliability-sensitive.

```text
POST /api/v1/auth/upload-id
            │
            ▼
Runtime
            │
            ▼
ID_UPLOAD
            │
            ▼
Policy
timeout = 10s
retry = true
maxRetries = 2
recoverable = true
            │
            ▼
Controller
            │
      ┌─────┼─────────┐
      ▼     ▼         ▼
    MinIO PostgreSQL Redis
      │     │         │
      └─────┴─────────┘
            │
            ▼
         Worker
```

The Runtime governs each infrastructure operation independently.

---

# 48. Runtime Does Not Replace BullMQ

For Worker execution, the Runtime is conceptually above the existing Worker runtime.

The architecture is:

```text
Worker Runtime
       │
       ▼
BullMQ
       │
       ▼
Job Execution
```

The Runtime adds reliability governance without replacing BullMQ's queue semantics.

This preserves the responsibility boundary:

```text
BullMQ
└── queue and job execution

Runtime
└── operational reliability governance
```

---

# 49. Runtime Adaptation Across Services

The Runtime architecture is shared conceptually across API and Worker while being adapted to their execution models.

For API:

```text
HTTP Request
    │
    ▼
Express Middleware
    │
    ▼
Runtime
```

For Worker:

```text
BullMQ Job
    │
    ▼
Worker Runtime
    │
    ▼
Job Execution
```

The implementation may differ where the execution model requires it, but the architectural capabilities remain aligned.

---

# 50. Runtime Capability Model

The Runtime capability set can be summarized as:

```text
                 Runtime
                    │
       ┌────────────┼────────────┐
       │            │            │
       ▼            ▼            ▼
   Identity      Lifecycle    Operation
       │            │            │
       └────────────┼────────────┘
                    │
                    ▼
              Reliability
                    │
       ┌────────────┼────────────┐
       │            │            │
       ▼            ▼            ▼
    Timeout       Retry       Recovery
       │            │            │
       └────────────┼────────────┘
                    │
                    ▼
               Failure
                    │
       ┌────────────┼────────────┐
       ▼            ▼            ▼
 Classification  Handling    Propagation
                    │
                    ▼
              Observability
```

---

# 51. Runtime Architectural Boundaries

The Runtime can be divided into five major boundaries.

## Boundary 1 — Execution Context

Responsible for:

* identity;
* state;
* metadata;
* failure state;
* reliability state.

---

## Boundary 2 — Operation Resolution

Responsible for:

* operation identity;
* operation category;
* characteristics;
* policy lookup.

---

## Boundary 3 — Reliability Execution

Responsible for:

* timeout;
* retry;
* backoff;
* recovery.

---

## Boundary 4 — Infrastructure Boundary

Responsible for:

* dependency execution;
* dependency identification;
* operational metrics;
* failure propagation.

---

## Boundary 5 — Runtime Failure Handling

Responsible for:

* terminal failure registration;
* final snapshot;
* error response;
* failure telemetry.

---

# 52. Runtime Control Flow

The Runtime architecture can therefore be represented as:

```text
                    Request
                       │
                       ▼
              ┌────────────────┐
              │ Runtime        │
              │ Bootstrap      │
              └───────┬────────┘
                      │
                      ▼
              ┌────────────────┐
              │ Runtime Guard  │
              └───────┬────────┘
                      │
                      ▼
              ┌────────────────┐
              │ Operation      │
              │ Resolution     │
              └───────┬────────┘
                      │
                      ▼
              ┌────────────────┐
              │ Policy         │
              │ Resolution     │
              └───────┬────────┘
                      │
                      ▼
              ┌────────────────┐
              │ Reliability    │
              │ Activation     │
              └───────┬────────┘
                      │
                      ▼
                 Application
                      │
                      ▼
             Infrastructure Boundary
                      │
                      ▼
             Reliability Executor
                      │
             ┌────────┼────────┐
             │        │        │
             ▼        ▼        ▼
           Success  Retry    Failure
             │        │        │
             │        │        ▼
             │        │   Classification
             │        │        │
             │        │        ▼
             │        │     Propagate
             │        │
             │        └──► Backoff
             │
             ▼
          Completion
```

---

# 53. Runtime Design Principles

## 53.1 Explicitness

Runtime behavior should be explicit.

Examples:

```text
operation
policy
dependency
failure classification
```

should not be inferred implicitly from arbitrary application behavior.

---

## 53.2 Deterministic State

Lifecycle transitions are explicitly controlled.

---

## 53.3 Policy-Driven Reliability

Retry and timeout behavior are controlled by policy rather than scattered constants.

---

## 53.4 Boundary-Based Reliability

Infrastructure operations pass through a common reliability boundary.

---

## 53.5 Failure Preservation

Failures are classified and observed without being silently swallowed.

---

## 53.6 Observability by Design

Runtime execution produces telemetry as part of normal operation.

---

## 53.7 Service Adaptation

The Runtime model can be adapted to different execution models without forcing all services into identical implementation structures.

---

# 54. Current Architectural Limitations

The current Runtime is a strong operational foundation but does not yet represent a complete distributed execution platform.

Important limitations include:

### 54.1 Timeout Is Not Guaranteed Cancellation

As described earlier, timeout uses `Promise.race()` and does not necessarily terminate the underlying operation.

---

### 54.2 Retry Is Currently Dependency-Oriented

The primary retry boundary is infrastructure execution.

Business-level retries are not automatically implemented.

---

### 54.3 Runtime State Is Process-Local

Runtime context exists in the executing process/request.

It is not a distributed state store.

---

### 54.4 Runtime Does Not Provide Distributed Tracing

The current model provides correlation identifiers but is not equivalent to full OpenTelemetry distributed tracing.

---

### 54.5 Runtime Does Not Replace Queue Semantics

Worker job durability, delivery semantics, and queue coordination remain responsibilities of BullMQ/Redis.

---

# 55. Runtime Evolution Direction

The Runtime architecture provides a foundation for future capabilities such as:

```text
Cancellation
Circuit Breaker
Bulkhead Isolation
Concurrency Limits
Distributed Tracing
Deadline Propagation
Dependency Health Policies
Adaptive Retry
Rate Limiting
Resource Protection
```

These should be introduced as explicit capabilities rather than embedded ad hoc into existing Runtime components.

---

# 56. Relationship to Reliability Architecture

The Runtime is the primary execution mechanism through which Reliability Architecture becomes operational.

The relationship is:

```text
Reliability Architecture
          │
          ▼
Reliability Policies
          │
          ▼
Runtime
          │
          ▼
Infrastructure Boundary
          │
          ▼
Dependency Execution
```

The Runtime therefore acts as the enforcement layer for reliability decisions.

---

# 57. Relationship to Failure Engineering

Failure Engineering defines how failures are understood and classified.

The Runtime operationalizes that model.

```text
Failure Engineering
       │
       ▼
Failure Taxonomy
       │
       ▼
Failure Classification
       │
       ▼
Runtime Decision
       │
       ├── retry
       ├── recover
       ├── propagate
       └── observe
```

This prevents failure handling from becoming a collection of unrelated `try/catch` blocks.

---

# 58. Relationship to Observability

Runtime telemetry feeds the broader Observability architecture.

```text
Runtime
   │
   ├── Metrics
   ├── Structured Logs
   └── Execution Metadata
          │
          ▼
     Observability
          │
     ┌────┴────┐
     ▼         ▼
Prometheus    Loki
```

This enables operational analysis across:

```text
Request
   │
Operation
   │
Dependency
   │
Failure
   │
Recovery
```

---

# 59. Relationship to Operations

Operations uses Runtime telemetry to answer questions such as:

* Which operation failed?
* Which dependency caused the failure?
* Was the failure transient?
* Was a retry attempted?
* Did the retry recover the operation?
* How long did the operation take?
* Is the problem isolated to one dependency or widespread?

Runtime therefore provides operational evidence required by incident investigation.

---

# 60. Architecture Invariants

The following Runtime invariants should remain valid as the system evolves.

### Invariant 1

Every governed execution has a Runtime context.

### Invariant 2

Every governed operation has an explicit operation identity.

### Invariant 3

Every operation resolves to a Reliability Policy.

### Invariant 4

Reliability must be activated before an operation becomes `ACTIVE`.

### Invariant 5

Infrastructure operations execute through a Runtime reliability boundary.

### Invariant 6

Failures are classified before reliability decisions are made.

### Invariant 7

Retry requires explicit policy permission and a retryable failure.

### Invariant 8

Runtime failures are observable.

### Invariant 9

Unrecoverable failures remain propagatable to the application layer.

### Invariant 10

Runtime must not become the owner of business logic.

---

# 61. Operational Mental Model

When reasoning about any Runtime-governed operation, use the following model:

```text
WHO?
 │
 └── requestId / executionId

WHAT?
 │
 └── operationId

UNDER WHICH POLICY?
 │
 └── Reliability Policy

WHICH DEPENDENCY?
 │
 └── dependency identity

WHAT HAPPENED?
 │
 └── success / failure / timeout

CAN IT RECOVER?
 │
 └── classification + policy

WHAT DID RUNTIME DO?
 │
 └── retry / recover / propagate

WHAT EVIDENCE EXISTS?
 │
 ├── logs
 └── metrics
```

This is the operational mental model of Mini-Write Runtime.

---

# 62. Summary

Mini-Write Runtime provides an explicit operational execution layer around application operations.

Its architecture is built around five fundamental concepts:

```text
Execution Context
        │
        ▼
Operation
        │
        ▼
Reliability Policy
        │
        ▼
Infrastructure Boundary
        │
        ▼
Failure / Recovery
```

The Runtime establishes:

* deterministic execution lifecycle;
* stable execution identity;
* explicit operation semantics;
* policy-driven reliability;
* timeout enforcement;
* bounded retry;
* failure classification;
* recovery tracking;
* infrastructure execution boundaries;
* runtime integrity checks;
* structured operational telemetry.

The most important architectural distinction is:

```text
Application
    │
    └── performs the work

Runtime
    │
    └── governs how the work executes

Infrastructure
    │
    └── provides the dependency
```

This separation allows reliability capabilities to evolve independently from business logic while maintaining a consistent operational model across Mini-Write services.

```
```
