# Runtime Reference

## 1. Purpose

This document is the authoritative reference for the Mini-Write application Runtime.

The Runtime is the reliability-oriented execution layer introduced to provide a consistent operational model around application operations and infrastructure interactions.

It defines and coordinates:

- execution identity
- execution lifecycle
- operation identity
- reliability policy
- reliability activation
- failure classification
- retry behavior
- timeout enforcement
- recovery state
- infrastructure execution boundaries
- runtime integrity validation
- runtime observability

The Runtime does **not** replace the application framework or infrastructure clients.

Instead, it establishes a reliability boundary around them.

```text
Application Request / Worker Job
            │
            ▼
       Runtime Layer
            │
    ┌───────┼────────┐
    │       │        │
    ▼       ▼        ▼
 Operation Policy Failure
 Resolution Activation Handling
    │       │        │
    └───────┼────────┘
            ▼
   Infrastructure Boundary
            │
            ▼
       Actual Dependency
````

---

# 2. Runtime Architectural Role

The Runtime exists between the application execution model and the infrastructure dependencies.

For the API:

```text
HTTP Request
     │
     ▼
Express
     │
     ▼
Runtime
     │
     ▼
Application Operation
     │
     ▼
Infrastructure Boundary
     │
     ├── PostgreSQL
     ├── Redis
     └── MinIO
```

For the Worker:

```text
BullMQ Job
     │
     ▼
Worker Runtime
     │
     ▼
Worker Operation
     │
     ▼
Infrastructure Boundary
     │
     ├── Redis
     ├── PostgreSQL
     └── MinIO
```

The Worker Runtime follows the same architectural model as the API Runtime while being adapted to the Worker execution model.

The Runtime is therefore a **shared architectural capability**, not a framework-specific middleware feature.

---

# 3. Runtime Responsibilities

The Runtime is responsible for the following concerns.

| Responsibility | Description                                       |
| -------------- | ------------------------------------------------- |
| Identity       | Creates request/execution identity                |
| Lifecycle      | Controls execution state transitions              |
| Operation      | Identifies the logical operation being executed   |
| Policy         | Associates reliability behavior with an operation |
| Activation     | Activates reliability behavior before execution   |
| Failure        | Records and classifies failures                   |
| Retry          | Coordinates retry eligibility and attempts        |
| Timeout        | Enforces operation timeout boundaries             |
| Recovery       | Records successful recovery after retry           |
| Infrastructure | Controls dependency execution through a boundary  |
| Integrity      | Detects Runtime replacement or identity mismatch  |
| Observability  | Emits runtime metrics and structured events       |

The Runtime deliberately does not own business logic.

---

# 4. Runtime Non-Responsibilities

The Runtime does not directly own:

* user authentication business rules
* database schema logic
* object-storage business logic
* queue business logic
* HTTP routing semantics
* image-processing logic
* application-specific response formatting
* deployment orchestration

The separation is:

```text
Business Logic
     │
     ▼
Application Layer
     │
     ▼
Runtime Reliability Layer
     │
     ▼
Infrastructure
```

The Runtime controls **how an operation executes reliably**, not **what the operation means to the business**.

---

# 5. Runtime Source Layout

The API Runtime is located under:

```text
api/src/runtime/
```

The principal structure is:

```text
runtime/
├── index.js
├── runtimeAccess.js
│
├── context/
│   ├── executionContext.js
│   └── operationContext.js
│
├── middleware/
│   ├── runtimeBootstrap.js
│   ├── runtimeGuard.js
│   ├── runtimeOperationResolution.js
│   ├── runtimeStateActivation.js
│   └── runtimeFailureHandler.js
│
├── infrastructure/
│   ├── dependencies.js
│   └── infrastructureBoundary.js
│
├── reliability/
│   ├── failureClassifier.js
│   ├── policyResolver.js
│   ├── reliabilityPolicy.js
│   ├── retry.js
│   └── runtimeErrors.js
│
└── observability/
    └── reliabilityMetrics.js
```

The Worker Runtime follows the same conceptual structure with Worker-specific adaptation.

---

# 6. Runtime Entry Point

The Runtime public entry point is:

```text
runtime/index.js
```

It exposes:

```js
createExecutionContext
EXECUTION_STATES
```

This keeps the Runtime's core context construction accessible without exposing every internal implementation detail as a public API.

---

# 7. Runtime Access

The Runtime request context is accessed through:

```text
runtime/runtimeAccess.js
```

It provides:

```js
getRuntime(req)
hasRuntime(req)
```

## `hasRuntime(req)`

Determines whether a Runtime instance exists on the request.

Conceptually:

```text
Request
  │
  ├── runtime exists → true
  │
  └── runtime absent → false
```

## `getRuntime(req)`

Returns the Runtime instance.

If the request does not contain a Runtime, it throws:

```text
Runtime has not been initialized.
```

This prevents downstream components from silently operating outside the Runtime contract.

---

# 8. Execution Context

The central Runtime object is the execution context.

It is created by:

```text
context/executionContext.js
```

through:

```js
createExecutionContext()
```

The execution context contains:

```text
Identity
State
Operation
Policy
Reliability
Failure
User
Metadata
Timestamps
```

Conceptually:

```text
Execution Context
│
├── identity
│   ├── requestId
│   └── executionId
│
├── state
│
├── operation
│
├── policy
│
├── reliability
│
├── failure
│
├── user
│
├── metadata
│
└── timestamps
```

---

# 9. Execution Identity

Every Runtime execution receives two identities:

```text
requestId
executionId
```

The Runtime generates them using cryptographically random bytes.

Example structure:

```text
req_<random-id>
exec_<random-id>
```

## Request ID

Identifies the externally observable request execution.

It is also exposed through:

```http
X-Request-Id
```

## Execution ID

Identifies the internal Runtime execution.

The distinction allows the architecture to separate external request correlation from internal execution identity.

---

# 10. Backward-Compatible Request ID

The execution context currently maintains:

```js
context.requestId
```

in addition to:

```js
context.identity.requestId
```

The former exists for backward compatibility.

The authoritative identity model is:

```text
context.identity.requestId
```

New Runtime-aware code should prefer the structured identity interface.

---

# 11. Execution States

The Runtime defines four execution states:

```text
created
initialized
active
completed
```

They are represented by:

```js
EXECUTION_STATES
```

The lifecycle is:

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

There is also a valid early completion transition:

```text
INITIALIZED
   │
   ▼
COMPLETED
```

This allows execution to terminate before entering active business execution.

---

# 12. State Transition Rules

The Runtime explicitly defines legal transitions.

```text
created
  └── initialized

initialized
  ├── active
  └── completed

active
  └── completed

completed
  └── no further transitions
```

Illegal transitions throw an error.

For example:

```text
completed → active
```

is invalid.

This creates a state-machine contract rather than allowing arbitrary lifecycle mutation.

---

# 13. Lifecycle API

The execution context exposes:

```js
initialize()
activate()
complete()
```

Each operation performs a validated state transition and returns the context.

This allows controlled chaining while preserving lifecycle rules.

---

# 14. Lifecycle Timestamps

The Runtime records:

```text
createdAt
initializedAt
activatedAt
completedAt
```

These timestamps provide lifecycle timing information.

Conceptually:

```text
createdAt
   │
   ▼
initializedAt
   │
   ▼
activatedAt
   │
   ▼
completedAt
```

This allows future operational analysis to distinguish:

* context creation time
* initialization time
* active execution time
* completion time

---

# 15. Operation Context

Operations are defined through:

```text
context/operationContext.js
```

An operation contains:

```text
identity
category
characteristics
metadata
```

Example:

```js
{
  identity: {
    id: "id_upload"
  },
  category: "storage",
  characteristics: {
    requiresDatabase: true,
    requiresStorage: true,
    asynchronous: true
  }
}
```

---

# 16. Operation Identity

The current API defines these operations:

```text
user_login
user_register
user_profile
id_upload
health_liveness
health_readiness
```

These are represented by:

```js
OPERATIONS
```

Operation IDs are stable identifiers used by:

* Runtime policy resolution
* Runtime logs
* Runtime metrics
* Failure analysis
* Operational correlation

---

# 17. Operation Categories

The Runtime defines:

```text
authentication
user
storage
health
background
```

through:

```js
OPERATION_CATEGORIES
```

Categories provide a higher-level classification than operation IDs.

For example:

```text
USER_LOGIN
    │
    ▼
authentication
```

while:

```text
ID_UPLOAD
    │
    ▼
storage
```

---

# 18. Operation Characteristics

Operations can declare characteristics such as:

```text
requiresDatabase
requiresStorage
asynchronous
```

These characteristics describe operational requirements.

For example:

```text
ID_UPLOAD
├── requiresDatabase = true
├── requiresStorage = true
└── asynchronous = true
```

The Runtime does not infer these characteristics from arbitrary business code.

They are declared explicitly when the operation is resolved.

---

# 19. Operation Query Interface

An operation exposes query methods:

```js
isOperation()
isCategory()
requiresDatabase()
requiresStorage()
isAsynchronous()
getSnapshot()
```

These methods allow Runtime components to inspect an operation without depending directly on its internal object structure.

This creates a controlled Runtime interface.

---

# 20. Reliability Policy

Reliability behavior is represented by a policy.

The policy contains:

```text
identity
timeout
retry
maxRetries
recoverable
metadata
```

Example:

```text
Reliability Policy
├── identity
│   ├── id
│   └── name
├── timeout
├── retry
├── maxRetries
├── recoverable
└── metadata
```

Policies are immutable after construction.

---

# 21. Policy Construction

Policies are created through:

```text
reliability/reliabilityPolicy.js
```

using:

```js
createReliabilityPolicy()
```

The constructor validates mandatory identity information:

```text
id
name
```

and applies defaults for:

```text
timeout
retry
maxRetries
recoverable
metadata
```

---

# 22. Default Reliability Policy

The Runtime defines a default policy:

```text
id: default
name: Default Reliability Policy
timeout: 5000
retry: false
maxRetries: 0
recoverable: false
```

The default policy is used when an operation does not have a specific policy.

---

# 23. Operation Policies

The current API policy mapping includes:

| Operation          |  Timeout | Retry | Max Retries | Recoverable |
| ------------------ | -------: | ----: | ----------: | ----------: |
| `user_login`       |  5000 ms |    No |           0 |          No |
| `user_register`    |  5000 ms |    No |           0 |          No |
| `user_profile`     |  3000 ms |    No |           0 |          No |
| `id_upload`        | 10000 ms |   Yes |           2 |         Yes |
| `health_liveness`  |  1000 ms |    No |           0 |          No |
| `health_readiness` |  3000 ms |    No |           0 |          No |

The policy is resolved by operation ID.

---

# 24. Policy Resolution

Policy resolution is implemented by:

```text
reliability/policyResolver.js
```

through:

```js
resolveReliabilityPolicy(operationId)
```

The flow is:

```text
Operation ID
    │
    ▼
Policy Resolver
    │
    ├── explicit policy exists
    │       │
    │       ▼
    │   operation policy
    │
    └── no explicit policy
            │
            ▼
       default policy
```

---

# 25. Runtime Bootstrap

API Runtime initialization begins with:

```text
middleware/runtimeBootstrap.js
```

The middleware:

1. creates the execution context
2. initializes the context
3. attaches request metadata
4. sets `X-Request-Id`
5. stores the Runtime on the request
6. creates a Runtime integrity snapshot
7. registers a response completion observer

The resulting request contains:

```text
req.runtime
req.context
req.runtimeIntegrity
```

---

# 26. Request Metadata

Runtime bootstrap captures:

```text
method
path
originalUrl
protocol
hostname
ip
```

This metadata becomes part of the Runtime context.

It provides execution context without requiring each application component to reconstruct request information independently.

---

# 27. Runtime Integrity

The Runtime stores:

```text
runtime
executionId
requestId
```

inside:

```text
req.runtimeIntegrity
```

The integrity object is immutable.

Its purpose is to detect:

* Runtime replacement
* Runtime identity mismatch
* request identity mismatch

---

# 28. Runtime Guard

After bootstrap, the API executes:

```text
middleware/runtimeGuard.js
```

The guard validates:

### Runtime presence

```text
req.runtime exists
```

### Runtime state

The Runtime must be:

```text
initialized
```

### Runtime object identity

```text
req.runtime === req.runtimeIntegrity.runtime
```

### Execution identity

```text
runtime.executionId === runtimeIntegrity.executionId
```

### Request identity

```text
runtime.requestId === runtimeIntegrity.requestId
```

If any contract is violated, the guard passes a Runtime contract error to the failure handler.

---

# 29. Runtime Operation Resolution

Operation resolution is implemented by:

```text
middleware/runtimeOperationResolution.js
```

It receives an operation definition and:

1. creates an operation context
2. retrieves the Runtime
3. attaches the operation
4. resolves the reliability policy
5. attaches the policy

Conceptually:

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
Policy Resolver
 │
 ▼
Reliability Policy
 │
 ▼
Runtime
```

---

# 30. Runtime State Activation

Reliability activation is performed by:

```text
middleware/runtimeStateActivation.js
```

Before activation it verifies:

```text
Runtime exists
Policy exists
```

Then:

```text
activateReliability()
```

is called.

The Runtime must confirm:

```text
isReliabilityActivated() === true
```

before execution continues.

Finally:

```text
runtime.activate()
```

transitions execution from:

```text
initialized
```

to:

```text
active
```

---

# 31. Runtime Execution Sequence

For an API request, the normal lifecycle is:

```text
HTTP Request
    │
    ▼
runtimeBootstrap
    │
    ▼
CREATE
    │
    ▼
INITIALIZE
    │
    ▼
runtimeGuard
    │
    ▼
Operation Resolution
    │
    ▼
Policy Resolution
    │
    ▼
Reliability Activation
    │
    ▼
ACTIVE
    │
    ▼
Application Handler
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
COMPLETE
```

---

# 32. Infrastructure Boundary

Infrastructure access is centralized through:

```text
infrastructure/infrastructureBoundary.js
```

The public execution function is:

```js
executeInfrastructureOperation()
```

Its responsibility is to provide a Runtime-aware boundary around infrastructure operations.

The caller supplies:

```text
req
dependency
operation
```

---

# 33. Infrastructure Dependencies

The current dependency registry defines:

```text
postgresql
redis
minio
```

through:

```js
DEPENDENCIES
```

This creates stable dependency identifiers for:

* logs
* metrics
* failure classification
* retry behavior
* operational analysis

---

# 34. Infrastructure Execution Flow

The infrastructure execution pipeline is:

```text
Application Operation
        │
        ▼
executeInfrastructureOperation()
        │
        ▼
Runtime Retrieval
        │
        ▼
Operation Identity
        │
        ▼
Reliability Executor
        │
        ├── timeout
        ├── retry
        ├── backoff
        └── failure classification
        │
        ▼
Actual Dependency Operation
        │
        ▼
Success / Failure
```

---

# 35. Reliability Attempt Tracking

Each dependency execution registers an attempt:

```js
registerReliabilityAttempt(dependency)
```

The Runtime maintains:

```text
attempts
lastDependency
```

This allows the execution context to represent how many attempts were made and which dependency was involved.

---

# 36. Retry Tracking

When a retry occurs:

```js
registerRetry()
```

increments the retry count.

The Runtime therefore distinguishes:

```text
attempts
```

from:

```text
retries
```

For example:

```text
Initial attempt
    │
    ▼
attempt = 1
retry = 0

Failure
    │
    ▼
Retry
    │
    ▼
attempt = 2
retry = 1
```

---

# 37. Timeout Model

Timeout execution is implemented through:

```text
runWithTimeout()
```

If a policy specifies a timeout, the Runtime races:

```text
actual operation
        vs
timeout promise
```

When the timeout expires, the Runtime generates:

```text
RuntimeTimeoutError
```

with:

```text
dependency
timeoutMs
retryAttempt
```

---

# 38. Important Timeout Semantics

The current timeout implementation uses:

```js
Promise.race()
```

Therefore timeout enforcement determines when the Runtime considers an operation failed.

It does not inherently cancel the underlying JavaScript operation.

Conceptually:

```text
Operation starts
     │
     ├───────────────► underlying operation
     │
     └── timeout ────► RuntimeTimeoutError
```

The Runtime may therefore stop waiting for the operation while the underlying operation could still continue.

This distinction is important when designing future cancellation mechanisms.

---

# 39. Backoff Algorithm

Retry backoff is implemented through:

```text
calculateBackoffMs(attempt)
```

The current formula is:

```text
min(
    100 × 2^(attempt - 1),
    1000
)
```

Therefore the sequence is approximately:

```text
Attempt 1 → 100 ms
Attempt 2 → 200 ms
Attempt 3 → 400 ms
...
```

with an upper bound of:

```text
1000 ms
```

---

# 40. Retry Eligibility

A failed operation can be retried only when all relevant conditions are satisfied.

The Runtime checks:

```text
attempt <= maxRetries
AND
runtime.isRecoverable()
AND
failure classification is retryable
```

Conceptually:

```text
Failure
  │
  ▼
Classification
  │
  ├── retryable? ── no ──► fail
  │
  └── yes
        │
        ▼
   Runtime recoverable?
        │
        ├── no ──► fail
        │
        └── yes
              │
              ▼
        Retry budget?
              │
              ├── no ──► fail
              │
              └── yes
                    │
                    ▼
                  retry
```

---

# 41. Failure Classification

Failures are classified through:

```text
reliability/failureClassifier.js
```

The current failure types are:

```text
timeout
dependency
validation
authentication
authorization
internal
```

---

# 42. Transient Failure Codes

The Runtime considers these codes transient:

```text
ECONNRESET
ECONNREFUSED
EHOSTUNREACH
ENETUNREACH
EADDRNOTAVAIL
ETIMEDOUT
RUNTIME_TIMEOUT
```

Transient dependency failures are considered retryable and recoverable by the classifier.

---

# 43. Failure Classification Rules

The current classifier follows this general order:

```text
Runtime Timeout
      │
      ▼
TIMEOUT

Dependency context
      │
      ▼
DEPENDENCY

HTTP 401
      │
      ▼
AUTHENTICATION

HTTP 403
      │
      ▼
AUTHORIZATION

Other 4xx
      │
      ▼
VALIDATION

Everything else
      │
      ▼
INTERNAL
```

This ordering matters because classification is context-sensitive.

---

# 44. Failure Classification Output

A classification contains:

```text
type
recoverable
retryable
```

Example:

```js
{
  type: "dependency",
  recoverable: true,
  retryable: true
}
```

This separates:

```text
What happened?
```

from:

```text
Can the Runtime recover?
```

and:

```text
Should the Runtime retry?
```

---

# 45. Failure Registration

The execution context stores:

```text
failure.occurred
failure.error
failure.classification
```

The Runtime prevents the same execution context from registering multiple primary failures.

Once a failure is registered:

```text
hasFailure() === true
```

and subsequent calls to `registerFailure()` do not overwrite the existing primary failure.

This preserves the first failure as the primary Runtime failure signal.

---

# 46. Failure Snapshot

The Runtime provides:

```js
getFailureSnapshot()
```

The snapshot contains:

```text
occurred
error
classification
```

The error itself is reduced to safe operational fields:

```text
message
name
code
```

rather than exposing the complete Error object.

---

# 47. Recovery State

The Runtime tracks:

```text
recovered
```

through:

```js
registerRecovery()
```

Recovery is recorded when an operation succeeds after one or more retry attempts.

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

---

# 48. Recovery Eligibility

The Runtime exposes:

```js
isRecoverable()
canRecover()
getRecoverySnapshot()
```

`canRecover()` requires:

```text
failure exists
AND
policy says recoverable
AND
failure classification says recoverable
```

The resulting recovery snapshot includes:

```text
eligible
recoverable
retry
maxRetries
```

---

# 49. Runtime Snapshot

The Runtime provides:

```js
snapshot()
```

The snapshot represents the current execution state.

It contains:

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

This provides a stable diagnostic representation of the execution context.

---

# 50. User Context

The Runtime context includes:

```text
user.id
```

through:

```js
attachUser(user)
getUser()
```

This allows user identity to become part of the Runtime execution context without making the Runtime responsible for authentication itself.

The Runtime should store only the minimum identity required for operational correlation.

---

# 51. Metadata

Runtime metadata is created through:

```text
runtimeMetadata
```

and can be enriched through:

```js
attachMetadata()
```

Metadata allows contextual information to be attached without expanding the Runtime's fixed structural fields.

---

# 52. API Runtime Integration

The API integrates the Runtime at the Express middleware level.

The main request chain is:

```text
app.use(express.json())

app.use(runtimeBootstrap)
app.use(runtimeGuard)

app.use(metricsMiddleware)
```

Routes then resolve their operation and activate the Runtime.

---

# 53. API Health Operations

The API defines Runtime operations for:

```text
health_liveness
health_readiness
```

### Liveness

The liveness operation uses:

```text
timeout = 1000 ms
retry = false
```

Its purpose is to determine whether the API process is alive.

### Readiness

The readiness operation uses:

```text
timeout = 3000 ms
retry = false
requiresDatabase = true
```

Its purpose is to determine whether the API can serve requests given its required dependencies.

---

# 54. API Authentication Operations

The API defines:

```text
user_register
user_login
user_profile
```

Each route resolves its Runtime operation before invoking the controller.

This ensures that authentication and user operations execute within an explicit Runtime context.

---

# 55. API Upload Operation

The ID upload operation is:

```text
id_upload
```

Its declared characteristics are:

```text
requiresDatabase = true
requiresStorage = true
asynchronous = true
```

Its reliability policy is:

```text
timeout = 10000 ms
retry = true
maxRetries = 2
recoverable = true
```

This is currently the API operation with explicit retry/recovery behavior.

---

# 56. Infrastructure Calls in API Controllers

The API controllers invoke infrastructure operations through:

```js
executeInfrastructureOperation()
```

For example, registration uses:

```text
PostgreSQL
```

Upload uses:

```text
MinIO
PostgreSQL
Redis
```

The resulting architecture is:

```text
Controller
   │
   ▼
Runtime Infrastructure Boundary
   │
   ├── PostgreSQL
   ├── MinIO
   └── Redis
```

This prevents infrastructure calls from bypassing the Runtime reliability boundary.

---

# 57. Runtime Failure Handler

Unhandled Express errors are processed by:

```text
middleware/runtimeFailureHandler.js
```

The handler:

1. checks whether Runtime exists
2. checks whether failure was already registered
3. classifies the failure when necessary
4. registers the failure
5. completes the Runtime
6. generates a final snapshot
7. emits structured failure telemetry
8. returns the HTTP response

---

# 58. HTTP Error Mapping

Runtime timeout errors map to:

```text
HTTP 504
```

Other errors use:

```text
error.statusCode
```

or:

```text
error.status
```

and finally fall back to:

```text
HTTP 500
```

The public response for a timeout is:

```text
Runtime operation timed out.
```

while ordinary internal failures return:

```text
Internal server error.
```

---

# 59. Runtime Completion

The Runtime completion observer is attached during bootstrap:

```js
res.on('finish', ...)
```

If the execution is still:

```text
initialized
```

or:

```text
active
```

the observer transitions it to:

```text
completed
```

and emits:

```text
runtime_completed
```

This provides a final lifecycle boundary even when application code does not explicitly complete the Runtime.

---

# 60. Runtime Completion Semantics

The Runtime therefore has two principal completion paths.

### Normal / response completion

```text
Request
   │
   ▼
Application
   │
   ▼
Response
   │
   ▼
res.finish
   │
   ▼
Runtime.complete()
```

### Failure completion

```text
Error
   │
   ▼
runtimeFailureHandler
   │
   ▼
Runtime.complete()
   │
   ▼
Error response
```

---

# 61. Runtime Observability

Runtime observability is implemented through:

```text
runtime/observability/reliabilityMetrics.js
```

and the project's structured logging system.

Runtime events include:

```text
runtime_operation_started
runtime_operation_completed
runtime_operation_retry
runtime_operation_failed
runtime_failure_handled
runtime_completed
```

These events provide an operational narrative of Runtime execution.

---

# 62. Runtime Metrics

The Runtime records metrics for:

```text
operations
retries
failures
operation duration
```

The metrics are associated with dimensions such as:

```text
operation
dependency
outcome
failure_type
recoverable
```

These dimensions allow operators to answer questions such as:

```text
Which operation is failing?

Which dependency is failing?

Are failures recoverable?

How often are retries occurring?

How long do infrastructure operations take?
```

---

# 63. Runtime Log Context

Runtime infrastructure logs include:

```text
request_id
execution_id
operation_id
dependency
```

Additional fields are added for specific events.

For example, retry events may include:

```text
failure_type
attempt
next_attempt
error_message
```

Failure events may include:

```text
failure_type
recoverable
error_message
error_code
```

This creates a correlation chain:

```text
request_id
     │
     ▼
execution_id
     │
     ▼
operation_id
     │
     ▼
dependency
     │
     ▼
failure / retry / recovery
```

---

# 64. Runtime Error Lifecycle

A typical transient dependency failure follows:

```text
Dependency Operation
        │
        ▼
Error
        │
        ▼
Failure Classification
        │
        ▼
retryable?
        │
        ├── no ──► Runtime Failure
        │
        └── yes
              │
              ▼
        Runtime Recoverable?
              │
              ├── no ──► Runtime Failure
              │
              └── yes
                    │
                    ▼
                Retry
                    │
                    ▼
                 Success?
                /       \
              yes       no
               │         │
               ▼         ▼
           Recovered   next retry/failure
```

---

# 65. Runtime Contract

The Runtime establishes several contracts.

## Context Contract

Every managed execution must have a Runtime context.

## Identity Contract

Runtime identity must remain stable throughout execution.

## Lifecycle Contract

State transitions must follow the defined state machine.

## Operation Contract

An operation must expose a valid operation identity and query interface.

## Policy Contract

Reliability behavior must be represented through a policy.

## Infrastructure Contract

Managed dependency operations should pass through the infrastructure boundary.

## Failure Contract

Failures must be classified before reliability decisions are made.

---

# 66. Runtime Bypass

A Runtime bypass occurs when application code performs an infrastructure operation without using:

```text
executeInfrastructureOperation()
```

For example:

```text
Controller
   │
   └── pool.query(...)
```

without Runtime protection.

This bypasses:

```text
timeout
retry
failure classification
runtime metrics
runtime logging
```

and therefore creates an architectural reliability gap.

---

# 67. Runtime Boundary Rule

For Runtime-managed infrastructure operations:

```text
Application
     │
     ▼
Infrastructure Boundary
     │
     ▼
Dependency
```

should be preferred over:

```text
Application
     │
     ▼
Dependency directly
```

This keeps reliability behavior centralized.

---

# 68. Runtime and Business Logic Separation

The Runtime should remain independent from business decisions.

For example:

```text
"Username already exists"
```

is an application/business outcome.

The Runtime should not determine its business meaning.

By contrast:

```text
ECONNREFUSED
```

is an infrastructure failure signal that the Runtime can classify and potentially retry.

The boundary is:

```text
Business Semantics
        │
        ▼
Application Layer
        │
        ▼
Reliability Semantics
        │
        ▼
Runtime
```

---

# 69. Runtime and Dependency Ownership

The Runtime does not own PostgreSQL, Redis, or MinIO.

It owns the execution policy around calls to them.

Therefore:

```text
PostgreSQL
    └── owns database behavior

Redis
    └── owns queue/cache behavior

MinIO
    └── owns object storage behavior

Runtime
    └── owns reliability behavior around interactions
```

---

# 70. Retry Safety

A retry policy should only be enabled when repeating the operation is operationally safe.

The Runtime currently enables retry for:

```text
id_upload
```

This means the operation's underlying infrastructure interactions must be evaluated for retry safety.

Retrying a non-idempotent operation without suitable safeguards can create:

```text
duplicate writes
duplicate side effects
inconsistent state
```

Therefore:

> **Retryability is an operation-level decision, not a generic property of infrastructure errors.**

---

# 71. Current Runtime Limitation: Timeout Cancellation

The current timeout mechanism does not provide true cancellation of the underlying operation.

It provides:

```text
bounded Runtime waiting
```

rather than:

```text
physical operation cancellation
```

This distinction should be preserved in future Runtime evolution.

Where dependencies support native cancellation, future implementations can introduce cancellation propagation without changing the Runtime's conceptual contract.

---

# 72. Current Runtime Limitation: Retry Scope

The current retry executor operates around the infrastructure operation supplied to:

```text
executeInfrastructureOperation()
```

Therefore the Runtime retry boundary corresponds to the infrastructure operation boundary.

It does not automatically retry an entire business workflow.

For example:

```text
Upload workflow
 ├── storage upload
 ├── database update
 └── queue enqueue
```

is not automatically treated as one atomic retry unit.

Each infrastructure interaction is independently executed through the Runtime boundary.

This distinction is important for consistency and side-effect management.

---

# 73. Current Runtime Limitation: State Machine Scope

The current lifecycle state machine models:

```text
created
initialized
active
completed
```

It does not represent every internal reliability phase as a separate lifecycle state.

For example:

```text
retrying
recovering
failed
```

are represented through Runtime data rather than separate execution states.

This keeps the primary lifecycle state machine intentionally small.

---

# 74. Runtime Reference: Public Context Interface

The execution context currently exposes the following major interface.

### Identity

```js
getIdentity()
```

### Lifecycle

```js
initialize()
activate()
complete()
getState()
```

### Operation

```js
getOperation()
attachOperation()
```

### Policy

```js
getPolicy()
attachPolicy()
shouldRetry()
getTimeout()
getMaxRetries()
isRecoverable()
```

### Reliability

```js
activateReliability()
isReliabilityActivated()
registerReliabilityAttempt()
registerRetry()
registerRecovery()
```

### Failure

```js
hasFailure()
getFailure()
registerFailure()
getFailureSnapshot()
```

### Recovery

```js
canRecover()
getRecoverySnapshot()
```

### User

```js
getUser()
attachUser()
```

### Metadata

```js
getMetadata()
attachMetadata()
```

### Diagnostics

```js
snapshot()
```

---

# 75. Runtime Reference: Middleware Interface

The API Runtime middleware responsibilities are:

| Middleware                   | Responsibility                                |
| ---------------------------- | --------------------------------------------- |
| `runtimeBootstrap`           | Create and initialize Runtime                 |
| `runtimeGuard`               | Validate Runtime contract and integrity       |
| `runtimeOperationResolution` | Resolve operation and policy                  |
| `runtimeStateActivation`     | Activate reliability and execution            |
| `runtimeFailureHandler`      | Handle unhandled Runtime/application failures |

The intended ordering is:

```text
runtimeBootstrap
        │
        ▼
runtimeGuard
        │
        ▼
operation resolution
        │
        ▼
state activation
        │
        ▼
application execution
        │
        ▼
failure handler
```

---

# 76. Runtime Reference: Reliability Components

| Component              | Responsibility                          |
| ---------------------- | --------------------------------------- |
| `reliabilityPolicy.js` | Defines immutable reliability policies  |
| `policyResolver.js`    | Maps operation IDs to policies          |
| `failureClassifier.js` | Classifies failures                     |
| `retry.js`             | Executes timeout/retry/backoff behavior |
| `runtimeErrors.js`     | Defines Runtime-specific errors         |

These components together form the Runtime reliability engine.

---

# 77. Runtime Reference: Infrastructure Components

| Component                   | Responsibility                                                          |
| --------------------------- | ----------------------------------------------------------------------- |
| `dependencies.js`           | Defines stable dependency identifiers                                   |
| `infrastructureBoundary.js` | Executes infrastructure operations through Runtime reliability controls |

The boundary is the primary integration point between application code and Runtime reliability.

---

# 78. Runtime Reference: API Integration Points

The current API Runtime is integrated into:

```text
api/src/index.js
api/src/routes/authRoutes.js
api/src/controllers/authController.js
```

The API startup pipeline installs:

```text
runtimeBootstrap
runtimeGuard
runtimeFailureHandler
```

Routes install:

```text
runtimeOperationResolution
runtimeStateActivation
```

Controllers use:

```text
executeInfrastructureOperation
```

This creates end-to-end Runtime participation.

---

# 79. Runtime Reference: Worker Adaptation

The Worker Runtime follows the same architectural principles but adapts the execution model from HTTP requests to background jobs.

The conceptual mapping is:

| API                      | Worker                             |
| ------------------------ | ---------------------------------- |
| HTTP request             | BullMQ job                         |
| Request ID               | Job/execution correlation identity |
| Express middleware       | Worker execution lifecycle         |
| Route operation          | Job operation                      |
| HTTP response completion | Job completion                     |
| API controller           | Job processor                      |
| Infrastructure boundary  | Worker infrastructure boundary     |
| Runtime failure handler  | Worker failure handling            |
| Request lifecycle        | Job lifecycle                      |

The Worker should therefore not be treated as a copy of the API Runtime implementation.

It is a Runtime adaptation to a different execution substrate.

---

# 80. Runtime Operational Questions

The Runtime should allow operators to answer:

### Identity

```text
Which execution failed?
```

### Operation

```text
Which logical operation was executing?
```

### Dependency

```text
Which infrastructure dependency was involved?
```

### Failure

```text
What failure type occurred?
```

### Retry

```text
Was the operation retried?
How many times?
```

### Recovery

```text
Did the operation recover?
```

### Timing

```text
How long did the infrastructure operation take?
```

### Policy

```text
Which reliability policy governed the operation?
```

These questions define much of the Runtime's operational value.

---

# 81. Runtime Diagnostic Model

A Runtime incident can be reconstructed through:

```text
Request ID
    │
    ▼
Execution ID
    │
    ▼
Operation ID
    │
    ▼
Reliability Policy
    │
    ▼
Dependency
    │
    ▼
Attempt
    │
    ▼
Failure Classification
    │
    ▼
Retry
    │
    ▼
Recovery / Final Failure
```

This is the primary diagnostic chain exposed by the Runtime.

---

# 82. Runtime Design Principles

The Runtime follows these architectural principles:

## Explicitness

Operations and reliability policies are declared explicitly.

## Determinism

State transitions and retry decisions are governed by defined rules.

## Centralization

Infrastructure reliability behavior is centralized at the Runtime boundary.

## Separation of concerns

Business behavior remains outside the Runtime.

## Observability

Reliability decisions produce operational telemetry.

## Controlled mutation

Lifecycle and Runtime state changes occur through explicit interfaces.

## Failure classification before recovery

The Runtime classifies a failure before deciding whether recovery is possible.

---

# 83. Runtime Evolution Guidelines

Future Runtime changes should preserve the following boundaries:

```text
Execution Context
        │
        ├── Identity
        ├── Lifecycle
        ├── Operation
        ├── Policy
        ├── Failure
        └── Recovery

Reliability Engine
        │
        ├── Timeout
        ├── Retry
        ├── Backoff
        └── Classification

Infrastructure Boundary
        │
        └── Dependencies

Observability
        │
        ├── Metrics
        └── Logs
```

New capabilities should integrate into the appropriate boundary rather than introducing cross-layer coupling.

---

# 84. Adding a New Runtime Operation

A new operation should follow this sequence:

```text
1. Define operation ID
        │
        ▼
2. Define operation category
        │
        ▼
3. Define characteristics
        │
        ▼
4. Define reliability policy
        │
        ▼
5. Register policy in resolver
        │
        ▼
6. Resolve operation at execution boundary
        │
        ▼
7. Activate Runtime
        │
        ▼
8. Execute infrastructure calls through boundary
        │
        ▼
9. Validate observability
```

A new operation should not be considered complete until its reliability behavior is explicitly defined.

---

# 85. Adding a New Dependency

A new infrastructure dependency should follow:

```text
Dependency
    │
    ▼
Add stable dependency identifier
    │
    ▼
Integrate through infrastructure boundary
    │
    ▼
Define failure classification behavior
    │
    ▼
Define retry suitability
    │
    ▼
Define timeout requirements
    │
    ▼
Add Runtime observability
    │
    ▼
Validate operational behavior
```

The dependency should not be accessed directly from application code if it is intended to participate in Runtime reliability controls.

---

# 86. Runtime Testing Expectations

Runtime changes should verify at minimum:

### Lifecycle

```text
created → initialized → active → completed
```

### Invalid transitions

Illegal transitions must fail.

### Integrity

Runtime replacement must be detected.

### Policy

Correct operation policy must be resolved.

### Timeout

Timeout must produce `RuntimeTimeoutError`.

### Retry

Retry must occur only when classification and policy allow it.

### Backoff

Backoff must respect the configured algorithm.

### Recovery

Successful retry must mark the execution as recovered.

### Failure

Final failures must be classified and registered.

### Observability

Metrics and logs must describe the execution correctly.

---

# 87. Runtime Anti-Patterns

The following patterns violate the Runtime architecture.

## Direct infrastructure access

```text
Controller → pool.query()
```

without the Runtime boundary.

## Arbitrary retries

Implementing retry logic independently inside controllers.

## Hidden policy

Using timeout/retry values without a declared reliability policy.

## Runtime replacement

Replacing `req.runtime` after bootstrap.

## Invalid lifecycle mutation

Directly changing the Runtime state.

## Business logic inside Runtime

Embedding application-specific business decisions into reliability components.

## Silent failure

Catching infrastructure failures without registering or propagating them.

---

# 88. Runtime Security Considerations

Runtime observability must not expose sensitive information.

Runtime logs should avoid:

```text
passwords
JWT secrets
database credentials
storage credentials
authentication tokens
```

Runtime snapshots should also be treated as operational diagnostic objects and should not be serialized indiscriminately into external responses.

The Runtime's purpose is observability and reliability, not data disclosure.

---

# 89. Runtime Reference Summary

The Runtime can be understood through five layers:

```text
┌──────────────────────────────────────┐
│          Execution Context           │
│ Identity / State / Metadata / User   │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│          Operation & Policy           │
│ Operation Identity / Reliability     │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│         Reliability Engine            │
│ Timeout / Retry / Backoff / Failure  │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│       Infrastructure Boundary         │
│ PostgreSQL / Redis / MinIO           │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│          Observability                │
│ Metrics / Logs / Runtime Events      │
└──────────────────────────────────────┘
```

The central architectural rule is:

> **Every Runtime-managed execution should have an explicit identity, lifecycle, operation, reliability policy, failure model, and infrastructure boundary.**

---

# 90. Related Documentation

For the broader architecture, see:

* `docs/architecture/runtime-architecture.md`
* `docs/architecture/service-architecture.md`

For reliability concepts, see:

* `docs/reliability/reliability.md`
* `docs/reliability/failure-model.md`
* `docs/reliability/runtime-reliability.md`
* `docs/reliability/recovery.md`

For observability, see:

* `docs/observability/metrics.md`
* `docs/observability/logging.md`
* `docs/observability/alerting.md`
* `docs/observability/dashboards.md`

For operational troubleshooting, see:

* `docs/troubleshooting/runtime-issues.md`

```

### ملاحظة هندسية

هذا الملف يجب أن يبقى **Reference** وليس نسخة ثانية من `runtime-architecture.md`.

الفرق المقصود هو:

- `architecture/runtime-architecture.md` → **لماذا صُمّم Runtime بهذه الطريقة؟ وما موقعه المعماري؟**
- `reliability/runtime-reliability.md` → **ما نموذج Reliability الذي يطبقه Runtime؟**
- `reference/runtime-reference.md` → **ما هي الـ APIs والمكونات والسياسات والحالات والقواعد الفعلية التي يجب الرجوع إليها أثناء العمل؟**

وبذلك لا يتحول التوثيق إلى تكرار لنفس المعلومات في ثلاثة أماكن، بل تصبح الملفات الثلاثة طبقات مختلفة من المعرفة.
```
