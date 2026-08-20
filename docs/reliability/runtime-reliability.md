# Runtime Reliability

## 1. Purpose

This document describes the Runtime Reliability architecture of Mini-Write.

Runtime Reliability is the execution-level reliability layer placed between application behavior and infrastructure interactions.

Its purpose is to ensure that application operations execute inside an explicit, controlled, observable, and policy-driven Runtime rather than relying on scattered error handling and dependency-specific behavior.

The Runtime provides the execution model for:

- execution identity;
- execution lifecycle;
- operation identity;
- reliability policy resolution;
- timeout enforcement;
- bounded retry;
- exponential backoff;
- failure classification;
- recovery tracking;
- infrastructure boundaries;
- Runtime contract enforcement;
- execution-level observability.

The architectural relationship is:

```text
Application Operation
        │
        ▼
Reliability Runtime
        │
        ▼
Infrastructure Boundary
        │
        ▼
External Dependency
````

The Runtime does not replace Express, BullMQ, PostgreSQL, Redis, MinIO, Docker, or the application itself.

It introduces a reliability control layer around execution.

---

# 2. Architectural Role

Without a dedicated Runtime layer, reliability behavior tends to become distributed across application code:

```text
Controller
 ├── timeout logic
 ├── retry logic
 ├── error classification
 ├── logging
 └── dependency handling

Worker
 ├── retry behavior
 ├── failure handling
 ├── cancellation
 └── logging
```

This creates several problems:

* inconsistent failure behavior;
* duplicated reliability mechanisms;
* hidden retry semantics;
* weak execution identity;
* poor observability;
* difficult evolution of reliability policies;
* application logic coupled to operational concerns.

Mini-Write instead establishes:

```text
Business Logic
      │
      ▼
Runtime Contract
      │
      ▼
Reliability Policy
      │
      ▼
Execution Mechanisms
      │
      ▼
Infrastructure Boundary
```

The Runtime therefore acts as an architectural control plane for execution behavior.

---

# 3. Runtime Reliability Principles

The Runtime follows several core principles.

## 3.1 Reliability Is Explicit

Reliability behavior must be visible in architecture and code.

Operations do not implicitly inherit arbitrary retry or timeout behavior.

Instead:

```text
Operation
   │
   ▼
Policy Resolution
   │
   ▼
Explicit Reliability Behavior
```

---

## 3.2 Reliability Is Operation-Aware

Different operations have different reliability requirements.

For example:

```text
Health Liveness
```

does not have the same operational characteristics as:

```text
ID Upload
```

Therefore policies are associated with operation identity rather than globally applying identical behavior.

---

## 3.3 Reliability Is Bounded

Recovery mechanisms must have limits.

The Runtime does not allow unbounded retries.

```text
Failure
   │
   ▼
Retry?
   │
   ▼
Maximum Retry Count
   │
   ▼
Final Outcome
```

This prevents recovery mechanisms from becoming failure amplifiers.

---

## 3.4 Failure Is Part of Execution State

Failure is not treated only as an exception escaping application code.

The Runtime records failure information as part of execution state.

This makes failure queryable and observable.

---

## 3.5 Unknown Failure Is Conservative

Unknown failures are not automatically retried.

The Runtime prefers:

```text
Unknown Failure
      │
      ▼
Record
      │
      ▼
Expose Evidence
      │
      ▼
Fail Safely
```

rather than:

```text
Unknown Failure
      │
      ▼
Blind Retry
```

---

## 3.6 Runtime and Business Logic Remain Separate

The Runtime owns execution reliability.

Application code owns business behavior.

This separation is fundamental to maintainability.

---

# 4. Runtime Architecture

The API Runtime is organized approximately as:

```text
api/src/runtime/
│
├── index.js
├── runtimeAccess.js
│
├── context/
│   ├── executionContext.js
│   └── operationContext.js
│
├── metadata/
│   └── runtimeMetadata.js
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
├── observability/
│   └── reliabilityMetrics.js
│
└── reliability/
    ├── reliabilityPolicy.js
    ├── policyResolver.js
    ├── failureClassifier.js
    ├── retryExecutor.js
    └── runtimeErrors.js
```

The Worker follows the same architectural pattern, adapted to BullMQ's job execution model rather than HTTP request execution.

The architectural model is therefore shared even though the integration points differ.

---

# 5. Runtime Execution Model

The central object is the Execution Context.

For the API:

```text
HTTP Request
     │
     ▼
Runtime Bootstrap
     │
     ▼
Execution Context
```

The context represents one logical execution.

Its major domains are:

```text
Execution Context
│
├── Identity
├── State
├── Operation
├── Policy
├── Reliability State
├── Failure State
├── User Context
├── Metadata
└── Timestamps
```

This provides a single execution-scoped source of Runtime state.

---

# 6. Execution Identity

Every Runtime execution receives two identifiers:

```text
requestId
executionId
```

They are generated independently using cryptographically generated random bytes.

Conceptually:

```text
Request
   │
   ├── requestId
   │
   └── executionId
```

The API also exposes the request identity through:

```text
X-Request-Id
```

This allows a client-visible failure to be correlated with internal execution evidence.

---

# 7. Request ID and Execution ID

Although both identify an execution in the current API model, they represent different architectural concepts.

## Request ID

Represents request-level correlation.

It is useful for:

* client correlation;
* HTTP logging;
* tracing a request through application logs.

## Execution ID

Represents the Runtime execution itself.

It is useful for:

* Runtime integrity;
* Runtime lifecycle evidence;
* future execution models not necessarily tied directly to HTTP.

The distinction allows the Runtime abstraction to remain broader than the transport protocol.

---

# 8. Runtime Access Contract

Application infrastructure code should not manually inspect arbitrary request properties to discover Runtime state.

Runtime access is centralized through:

```javascript
getRuntime(req)
```

and:

```javascript
hasRuntime(req)
```

`getRuntime()` enforces two requirements:

```text
Request exists
AND
Runtime exists
```

Otherwise it raises a Runtime contract error.

This creates an explicit boundary between Runtime-aware code and ordinary request state.

---

# 9. Execution Lifecycle

The Runtime implements a controlled state machine.

Current states are:

```text
CREATED
INITIALIZED
ACTIVE
COMPLETED
```

The normal lifecycle is:

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

A Runtime may also complete directly from `INITIALIZED`:

```text
INITIALIZED
     │
     ▼
COMPLETED
```

This supports executions that terminate before normal activation.

---

# 10. Allowed State Transitions

The Runtime explicitly defines allowed transitions.

```text
CREATED
   │
   └── INITIALIZED

INITIALIZED
   ├── ACTIVE
   └── COMPLETED

ACTIVE
   └── COMPLETED

COMPLETED
   └── no transition
```

Any transition outside this graph is rejected.

For example:

```text
CREATED → ACTIVE
```

is invalid.

Likewise:

```text
COMPLETED → ACTIVE
```

is invalid.

The Runtime therefore prevents execution state from becoming arbitrary.

---

# 11. Why the State Machine Matters

Without lifecycle enforcement, application execution can enter ambiguous states such as:

```text
policy attached after execution
operation replaced during execution
completed execution reactivated
reliability activated without policy
```

The state machine establishes temporal invariants.

This is especially important as reliability capabilities become more sophisticated.

---

# 12. Lifecycle Timestamps

The Runtime records:

```text
createdAt
initializedAt
activatedAt
completedAt
```

These timestamps provide lifecycle evidence.

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

They can support future measurements such as execution duration and lifecycle diagnostics.

---

# 13. Runtime Bootstrap

For the API, `runtimeBootstrap` is the entry point into Runtime execution.

The middleware:

1. creates an Execution Context;
2. transitions it to `INITIALIZED`;
3. attaches request metadata;
4. exposes the request ID;
5. attaches the Runtime to the request;
6. establishes an integrity reference;
7. registers the completion observer.

Conceptually:

```text
Incoming HTTP Request
        │
        ▼
createExecutionContext()
        │
        ▼
initialize()
        │
        ▼
attachMetadata()
        │
        ▼
req.runtime
        │
        ▼
Runtime Integrity Snapshot
```

---

# 14. Runtime Request Metadata

At bootstrap time the Runtime receives HTTP metadata such as:

```text
method
path
originalUrl
protocol
hostname
ip
```

This metadata enriches execution evidence without making the core Runtime dependent on business logic.

---

# 15. Runtime Compatibility Alias

The API currently assigns:

```javascript
req.runtime = executionContext;
req.context = executionContext;
```

`req.runtime` is the Runtime-oriented interface.

`req.context` currently provides backward compatibility for existing observability code that expects request context through `req.context`.

This compatibility relationship should not be confused with two independent Runtime instances.

Both reference the same Execution Context.

---

# 16. Runtime Integrity

Runtime creation alone is insufficient.

The API establishes an integrity snapshot:

```text
runtime instance
executionId
requestId
```

The guard later verifies these values.

Conceptually:

```text
Bootstrap
   │
   ▼
Runtime R1
   │
   ├── executionId E1
   └── requestId RQ1
   │
   ▼
Integrity Snapshot
```

Later:

```text
Runtime Guard
   │
   ├── same Runtime object?
   ├── same executionId?
   └── same requestId?
```

Any mismatch becomes a Runtime contract violation.

---

# 17. Runtime Guard

`runtimeGuard` protects the Runtime contract before application execution continues.

It verifies:

```text
Runtime Presence
        │
        ▼
Runtime State
        │
        ▼
Runtime Object Identity
        │
        ▼
Execution Identity
        │
        ▼
Request Identity
```

The expected state at this point is:

```text
INITIALIZED
```

This detects accidental or unauthorized replacement of Runtime state inside the request pipeline.

---

# 18. Operation Context

The Runtime does not reason only about generic requests.

It identifies the operation being executed.

Current API operations include:

```text
USER_LOGIN
USER_REGISTER
USER_PROFILE
ID_UPLOAD
HEALTH_LIVENESS
HEALTH_READINESS
```

Each operation is represented by an immutable Operation Context.

---

# 19. Operation Context Structure

An operation contains:

```text
identity
category
characteristics
metadata
```

Example conceptually:

```text
ID_UPLOAD
│
├── category = storage
│
└── characteristics
    ├── requiresDatabase = true
    ├── requiresStorage = true
    └── asynchronous = true
```

This creates semantic knowledge about the execution.

---

# 20. Operation Categories

Current categories include:

```text
authentication
user
storage
health
background
```

Categories allow future reliability behavior to reason about classes of operations rather than only individual identifiers.

---

# 21. Operation Query Interface

Operation Context exposes query methods such as:

```text
isOperation()
isCategory()
requiresDatabase()
requiresStorage()
isAsynchronous()
getSnapshot()
```

This prevents callers from repeatedly inspecting internal object structure.

Instead of:

```text
operation.characteristics.requiresDatabase
```

Runtime-aware components can use:

```text
operation.requiresDatabase()
```

The Operation Context therefore behaves as an architectural component rather than merely a data object.

---

# 22. Operation Immutability

Operation Contexts are frozen.

Once constructed:

```text
Operation Identity
Category
Characteristics
Metadata
```

cannot be arbitrarily modified.

This is important because reliability policy resolution depends on stable operation identity.

---

# 23. Operation Attachment

The Runtime attaches the Operation Context before execution becomes active.

The Runtime enforces:

```text
Operation must exist
Operation must satisfy interface contract
Operation cannot already be attached
Execution must not already be ACTIVE
Execution must not be COMPLETED
```

This prevents late or ambiguous operation identity.

---

# 24. Operation Resolution Middleware

For the API, routes declare their operation identity explicitly.

Conceptually:

```text
Route
  │
  ▼
runtimeOperationResolution(...)
  │
  ├── create Operation Context
  ├── attach Operation
  ├── resolve Policy
  └── attach Policy
```

This creates a declarative association between HTTP routes and Runtime behavior.

---

# 25. Example: ID Upload

The upload operation declares:

```text
Operation:
ID_UPLOAD

Category:
STORAGE

Characteristics:
requiresDatabase = true
requiresStorage = true
asynchronous = true
```

The Runtime then resolves the corresponding Reliability Policy.

The route itself does not implement timeout or retry logic.

---

# 26. Reliability Policy Model

Reliability behavior is represented by immutable Reliability Policy objects.

A policy contains:

```text
identity
timeout
retry
maxRetries
recoverable
metadata
```

Conceptually:

```text
Reliability Policy
│
├── id
├── name
├── timeout
├── retry
├── maxRetries
├── recoverable
└── metadata
```

---

# 27. Why Policies Are Separate

Reliability policy is separated from execution mechanism.

This means:

```text
Policy
=
What behavior is allowed
```

while:

```text
Executor
=
How that behavior is implemented
```

For example:

```text
retry = true
maxRetries = 2
timeout = 10000
```

describes policy.

The retry loop and timeout mechanism implement that policy.

This separation makes reliability behavior easier to evolve.

---

# 28. Current API Reliability Policies

The current policy set includes operation-specific policies.

| Operation        |  Timeout | Retry | Max Retries | Recoverable |
| ---------------- | -------: | ----- | ----------: | ----------- |
| User Login       |  5000 ms | No    |           0 | No          |
| User Register    |  5000 ms | No    |           0 | No          |
| User Profile     |  3000 ms | No    |           0 | No          |
| ID Upload        | 10000 ms | Yes   |           2 | Yes         |
| Health Liveness  |  1000 ms | No    |           0 | No          |
| Health Readiness |  3000 ms | No    |           0 | No          |

A default policy also exists:

```text
timeout = 5000 ms
retry = false
maxRetries = 0
recoverable = false
```

Unknown operation identities therefore fail toward conservative behavior rather than inheriting retry automatically.

---

# 29. Policy Resolution

Policy resolution follows:

```text
Operation ID
    │
    ▼
Policy Resolver
    │
    ├── Matching Policy
    │
    └── Default Policy
```

This keeps route/controller code independent from the policy table.

The application identifies the operation.

The Runtime determines the reliability policy.

---

# 30. Policy Attachment

After resolution, the policy is attached to the Execution Context.

The Runtime prevents multiple policy attachments.

Conceptually:

```text
Execution
   │
   ├── Operation
   │
   └── Reliability Policy
```

Once execution starts, the Runtime has enough information to make reliability decisions.

---

# 31. Reliability Activation

Attaching a policy is not equivalent to activating reliability.

The Runtime explicitly calls:

```text
activateReliability()
```

Activation requires a policy.

The sequence is:

```text
Attach Operation
      │
      ▼
Attach Policy
      │
      ▼
Activate Reliability
      │
      ▼
Activate Execution
```

This prevents execution from becoming active before reliability state is ready.

---

# 32. Runtime State Activation

`runtimeStateActivation` verifies:

```text
Runtime exists
Policy exists
```

then performs:

```text
activateReliability()
        │
        ▼
verify activation
        │
        ▼
activate()
```

Only after these conditions succeed does the application handler execute in an `ACTIVE` Runtime.

---

# 33. API Middleware Pipeline

The high-level API pipeline is:

```text
HTTP Request
     │
     ▼
express.json()
     │
     ▼
runtimeBootstrap
     │
     ▼
runtimeGuard
     │
     ▼
metricsMiddleware
     │
     ▼
Route Matching
     │
     ▼
runtimeOperationResolution
     │
     ▼
Route-Specific Middleware
     │
     ▼
runtimeStateActivation
     │
     ▼
Controller
     │
     ▼
Response
     │
     ▼
Runtime Completion
```

For protected or upload routes, route-specific middleware can include authentication or file handling before activation depending on route composition.

---

# 34. Infrastructure Boundary

Runtime Reliability becomes operationally significant when application code interacts with infrastructure.

The API uses:

```javascript
executeInfrastructureOperation()
```

as the reliability boundary around dependency operations.

Examples include:

```text
PostgreSQL query
MinIO operation
Redis queue operation
```

The intended architecture is:

```text
Controller
    │
    ▼
Infrastructure Boundary
    │
    ▼
Reliability Executor
    │
    ▼
Dependency Client
```

---

# 35. Why the Infrastructure Boundary Matters

Without this boundary:

```text
Controller
   │
   └── pool.query()
```

the Runtime cannot consistently apply:

* timeout;
* retry;
* failure classification;
* reliability metrics;
* dependency-aware logs;
* recovery tracking.

With the boundary:

```text
Controller
   │
   ▼
executeInfrastructureOperation()
   │
   ▼
pool.query()
```

the dependency interaction becomes Runtime-controlled.

---

# 36. Dependency Registry

Current API Runtime dependencies are explicitly named:

```text
POSTGRESQL
REDIS
MINIO
```

This avoids arbitrary dependency labels scattered throughout application code.

Stable dependency identity is important for:

```text
metrics
logs
failure classification
operational diagnosis
```

---

# 37. Infrastructure Execution Flow

The infrastructure boundary performs approximately:

```text
Infrastructure Operation
        │
        ▼
Validate Arguments
        │
        ▼
Acquire Runtime
        │
        ▼
Resolve Operation ID
        │
        ▼
Start Duration Measurement
        │
        ▼
Emit Operation Started
        │
        ▼
executeWithReliability()
        │
   ┌────┴─────┐
   │          │
Success     Failure
   │          │
   ▼          ▼
Metrics    Classification
Logs       Failure State
Return     Metrics
           Logs
           Propagate
```

The boundary does not silently consume terminal failures.

After recording evidence, it preserves failure propagation.

---

# 38. Reliability Executor

The core execution mechanism is:

```javascript
executeWithReliability()
```

It coordinates:

```text
Attempts
Timeout
Classification
Retry Decision
Backoff
Recovery
Final Failure
```

This keeps reliability mechanics outside business controllers.

---

# 39. Attempt Model

Every dependency execution starts with attempt `1`.

The Runtime records each attempt through:

```text
registerReliabilityAttempt()
```

Therefore:

```text
attempts
```

means total execution attempts, not merely retries.

For example:

```text
Initial attempt
+
2 retries
=
3 attempts
```

---

# 40. Timeout Enforcement

Each attempt can execute through:

```text
runWithTimeout()
```

The current implementation uses:

```javascript
Promise.race([
    operation(),
    timeoutPromise
])
```

Conceptually:

```text
Dependency Operation ─────┐
                          ├──► First completion wins
Timeout Timer ────────────┘
```

If the timeout expires first, the Runtime produces:

```text
RuntimeTimeoutError
```

---

# 41. RuntimeTimeoutError

The Runtime-specific timeout error contains:

```text
name = RuntimeTimeoutError
code = RUNTIME_TIMEOUT
dependency
timeoutMs
retryAttempt
```

This allows timeout failures to be classified consistently instead of relying on arbitrary dependency-client timeout errors.

---

# 42. Important Timeout Semantics

The current timeout implementation bounds how long the Runtime waits for an operation.

It does **not** universally cancel the underlying dependency operation.

Therefore:

```text
Runtime Timeout
≠
Guaranteed Operation Cancellation
```

This distinction is important for operations with side effects.

For example, a database or storage operation could theoretically continue after the Runtime has stopped waiting if the underlying client does not support cooperative cancellation.

Timeout safety must therefore be considered together with:

```text
Idempotency
Cancellation
Side-Effect Semantics
```

---

# 43. Failure Classification

When an attempt fails, the Runtime classifies the error.

Current types are:

```text
TIMEOUT
DEPENDENCY
VALIDATION
AUTHENTICATION
AUTHORIZATION
INTERNAL
```

Dependency-aware execution supplies dependency context to the classifier.

This allows an infrastructure error to become:

```text
DEPENDENCY
```

rather than an undifferentiated internal exception.

---

# 44. Transient Dependency Errors

Current transient codes include:

```text
ECONNRESET
ECONNREFUSED
EHOSTUNREACH
ENETUNREACH
EADDRNOTAVAIL
ETIMEDOUT
RUNTIME_TIMEOUT
```

When encountered inside a dependency context, these can be classified as:

```text
recoverable = true
retryable = true
```

The classification alone still does not authorize retry.

Policy must also allow it.

---

# 45. Retry Decision Model

Retry requires all necessary conditions to hold.

Conceptually:

```text
Retries Remaining?
       │
       AND
       │
Policy Allows Retry?
       │
       AND
       │
Runtime Recoverable?
       │
       AND
       │
Failure Retryable?
       │
       ▼
      Retry
```

In implementation terms, the decision is derived from:

```text
attempt <= maxRetries
runtime.isRecoverable()
classification.retryable
```

where `maxRetries` itself is enabled only when the Runtime policy allows retry.

---

# 46. Why Retry Is Conservative

Retry is not a generic solution to failure.

Retrying a failure can:

* duplicate side effects;
* increase dependency load;
* increase latency;
* amplify an outage;
* hide deterministic defects;
* create retry storms.

Therefore Mini-Write requires explicit policy plus failure classification.

---

# 47. Maximum Retry Semantics

Suppose:

```text
maxRetries = 2
```

The execution can perform:

```text
Attempt 1
   │
 failure
   ▼
Retry 1 → Attempt 2
   │
 failure
   ▼
Retry 2 → Attempt 3
```

Therefore:

```text
maximum attempts = 1 + maxRetries
```

For the ID Upload policy:

```text
maxRetries = 2
```

means up to three attempts for an eligible dependency operation.

---

# 48. Exponential Backoff

Retries do not occur immediately.

The Runtime calculates backoff using:

```text
100 × 2^(attempt - 1)
```

with a maximum of:

```text
1000 ms
```

Current progression is approximately:

```text
Attempt 1 failure
      │
      ▼
100 ms
      │
      ▼
Attempt 2 failure
      │
      ▼
200 ms
      │
      ▼
Attempt 3
```

For larger retry counts the delay continues growing until capped at one second.

---

# 49. Why Backoff Exists

Immediate retries can intensify dependency failure.

Without backoff:

```text
Failure
Retry
Failure
Retry
Failure
Retry
```

can produce concentrated load.

Backoff changes this to:

```text
Failure
   │
 wait
   │
Retry
   │
 wait longer
   │
Retry
```

This gives transient conditions time to recover.

---

# 50. Backoff Limitations

The current implementation provides bounded exponential backoff.

It does not currently implement documented randomized jitter.

Therefore multiple synchronized callers could theoretically retry on similar schedules.

For a larger distributed deployment, a future design may consider:

```text
Exponential Backoff
+
Jitter
```

to reduce synchronized retry behavior.

The current single-node Mini-Write architecture does not claim this capability.

---

# 51. Retry Observability

Before each eligible retry, the Runtime:

```text
registers retry state
```

and invokes the retry callback.

The infrastructure boundary then emits:

```text
runtimeRetriesTotal
```

with dimensions such as:

```text
operation
dependency
reason
```

It also emits a structured warning event:

```text
RUNTIME_OPERATION_RETRY
```

with:

```text
failure_type
attempt
next_attempt
error_message
```

Retries therefore remain visible rather than becoming hidden control flow.

---

# 52. Recovery Detection

If an operation succeeds after more than one attempt:

```text
attempt > 1
```

the Runtime records:

```text
recovered = true
```

through:

```text
registerRecovery()
```

The executor returns:

```text
result
attempts
recovered
```

This allows the infrastructure boundary to distinguish:

```text
success
```

from:

```text
recovered
```

---

# 53. Success vs Recovered

These outcomes are operationally different.

## Success

```text
Attempt 1
   │
   ▼
Success
```

## Recovered

```text
Attempt 1
   │
 Failure
   ▼
Retry
   │
   ▼
Success
```

Both may produce a successful user-facing result.

Operationally, however, recovered execution is evidence of instability.

Therefore the Runtime records the distinction.

---

# 54. Terminal Failure

If retry is not permitted or all retries are exhausted:

```text
Last Error
    │
    ▼
registerFailure()
    │
    ▼
throw Last Error
```

The Runtime does not convert terminal failure into false success.

The failure continues through the application error path.

---

# 55. Failure Registration

Runtime failure state contains:

```text
occurred
error
classification
```

`registerFailure()` also records:

```text
lastFailureType
```

inside reliability state.

Failure registration is effectively first-failure preserving:

```text
if failure already occurred
    preserve existing failure
```

This prevents later handling layers from casually overwriting the Runtime's existing failure record.

---

# 56. Failure Snapshot

The Runtime exposes a controlled failure snapshot:

```text
occurred
error
  ├── message
  ├── name
  └── code
classification
```

This creates a stable representation for Runtime consumers.

---

# 57. Recovery Eligibility

The Runtime exposes:

```text
isRecoverable()
canRecover()
getRecoverySnapshot()
```

The recovery snapshot contains:

```text
eligible
recoverable
retry
maxRetries
```

This separates:

```text
Policy permits recovery
```

from:

```text
A current failure is actually eligible for recovery
```

---

# 58. Infrastructure Success Path

When dependency execution succeeds, the boundary determines:

```text
outcome =
    recovered ? "recovered" : "success"
```

It then records:

```text
runtimeOperationsTotal
runtimeOperationDurationSeconds
```

and emits:

```text
RUNTIME_OPERATION_COMPLETED
```

with execution context.

Finally it returns the dependency result to the controller.

---

# 59. Infrastructure Failure Path

When dependency execution ultimately fails:

```text
Failure
   │
   ▼
Ensure Runtime Failure Registered
   │
   ▼
Read Failure Snapshot
   │
   ▼
runtimeFailuresTotal
   │
   ▼
runtimeOperationsTotal(outcome=failure)
   │
   ▼
duration metric
   │
   ▼
RUNTIME_OPERATION_FAILED
   │
   ▼
throw error
```

This preserves both observability and application failure semantics.

---

# 60. Runtime Failure Handler

The API terminates the Runtime error path through:

```text
runtimeFailureHandler
```

Its responsibilities include:

1. register the failure if not already registered;
2. classify previously unclassified failures;
3. complete the Runtime;
4. create a final snapshot;
5. emit failure evidence;
6. translate the failure into a controlled HTTP response.

---

# 61. Runtime Failure Completion

If Runtime state is not already:

```text
COMPLETED
```

the failure handler performs:

```text
runtime.complete()
```

This ensures failed executions reach a terminal lifecycle state.

Conceptually:

```text
ACTIVE
   │
 Failure
   ▼
COMPLETED
```

Failure and lifecycle state remain separate:

```text
state = completed
failure.occurred = true
```

This is intentional.

`COMPLETED` means execution lifecycle ended, not that execution succeeded.

---

# 62. HTTP Failure Mapping

The current API maps:

```text
RuntimeTimeoutError
        │
        ▼
HTTP 504
```

Other Runtime-propagated failures normally resolve through:

```text
error.statusCode
or
error.status
or
500
```

The generic response avoids exposing internal error details.

A Runtime timeout response becomes conceptually:

```json
{
  "error": "Runtime operation timed out.",
  "request_id": "<request-id>"
}
```

Other internal failures return a generic internal error plus the request correlation ID.

---

# 63. Why Request ID Is Returned

Returning:

```text
request_id
```

allows support or operations to correlate a user-visible failure with internal logs.

The pattern is:

```text
Client Failure
     │
     ▼
Request ID
     │
     ▼
Loki Search
     │
     ▼
Runtime Execution
     │
     ▼
Dependency / Failure Evidence
```

This improves diagnosability without exposing sensitive internal details.

---

# 64. Runtime Completion Observer

The bootstrap middleware registers:

```text
res.on("finish")
```

to observe normal response completion.

If the Runtime remains:

```text
INITIALIZED
```

or:

```text
ACTIVE
```

it transitions to:

```text
COMPLETED
```

and emits:

```text
RUNTIME_COMPLETED
```

This provides a lifecycle completion path independent of individual controllers.

---

# 65. Completion Invariant

The Runtime aims to preserve:

```text
Every initialized execution
        │
        ▼
Eventually reaches COMPLETED
```

whether the execution:

```text
succeeds
fails
recovers
terminates before activation
```

This reduces abandoned or ambiguous Runtime state.

---

# 66. Runtime Snapshot

The Runtime can expose a snapshot containing:

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

Conceptually:

```text
Runtime
   │
   ▼
snapshot()
   │
   ▼
Stable Diagnostic Representation
```

Snapshots are useful because external code does not need to reason directly about every mutable internal field.

---

# 67. Runtime Observability

Runtime Reliability produces observability at several levels.

```text
Execution
   │
   ├── Structured Logs
   ├── Reliability Metrics
   ├── Failure Snapshots
   └── Request Correlation
```

This makes reliability behavior operationally inspectable.

---

# 68. Runtime Events

Current Runtime-related events include:

```text
RUNTIME_OPERATION_STARTED
RUNTIME_OPERATION_COMPLETED
RUNTIME_OPERATION_RETRY
RUNTIME_OPERATION_FAILED
RUNTIME_FAILURE_HANDLED
RUNTIME_COMPLETED
```

These events describe different lifecycle moments.

They should not be collapsed into a single generic error event.

---

# 69. Runtime Operation Started

Before a dependency operation begins:

```text
RUNTIME_OPERATION_STARTED
```

is emitted with:

```text
request_id
execution_id
operation_id
dependency
```

This creates the starting point for dependency execution correlation.

---

# 70. Runtime Operation Completed

Successful or recovered dependency operations emit:

```text
RUNTIME_OPERATION_COMPLETED
```

with:

```text
outcome
attempts
```

Possible outcomes include:

```text
success
recovered
```

---

# 71. Runtime Operation Retry

Retry produces:

```text
RUNTIME_OPERATION_RETRY
```

with context such as:

```text
failure_type
attempt
next_attempt
error_message
```

This makes transient instability visible even when the final request succeeds.

---

# 72. Runtime Operation Failed

Terminal dependency failure produces:

```text
RUNTIME_OPERATION_FAILED
```

with:

```text
failure_type
recoverable
error_message
error_code
```

The event identifies the failure at the infrastructure boundary.

---

# 73. Runtime Failure Handled

The final API failure path emits:

```text
RUNTIME_FAILURE_HANDLED
```

including:

```text
request_id
execution_id
operation_id
state
failure_type
recoverable
reliability_activated
retries
error_message
```

This represents Runtime-level terminal handling rather than only dependency-level failure.

---

# 74. Runtime Completed

The completion observer emits:

```text
RUNTIME_COMPLETED
```

with:

```text
request_id
execution_id
operation_id
state
failure_occurred
reliability_activated
```

This creates final lifecycle evidence.

---

# 75. Reliability Metrics

The Runtime reliability layer maintains dedicated metrics for behavior such as:

```text
Runtime Operations
Runtime Retries
Runtime Failures
Runtime Operation Duration
```

The infrastructure boundary labels these metrics using dimensions such as:

```text
operation
dependency
outcome
failure_type
recoverable
reason
```

This allows reliability questions to be answered through Prometheus rather than only log inspection.

---

# 76. Metrics and Logs Serve Different Purposes

Metrics answer aggregate questions:

```text
How many retries occurred?

Which dependency fails most often?

Are failures increasing?

How often does recovery succeed?

How long are dependency operations taking?
```

Logs answer execution-specific questions:

```text
Which request failed?

Which execution retried?

What error code occurred?

Which attempt recovered?
```

The Runtime intentionally produces both.

---

# 77. Runtime and Existing Application Observability

Runtime observability does not replace existing application metrics.

For example:

```text
mw_api_http_requests_total
mw_api_http_errors_total
mw_api_http_request_duration_seconds
```

describe HTTP behavior.

Runtime reliability metrics describe execution reliability behavior.

Therefore:

```text
HTTP Metrics
     │
     ├── User-visible behavior
     │
Runtime Metrics
     │
     ├── Reliability behavior
     │
Dependency Metrics
     │
     └── Infrastructure interaction
```

Together they provide stronger diagnosis.

---

# 78. Correlation Architecture

The Runtime allows an investigation path such as:

```text
API Error Alert
      │
      ▼
HTTP Error Metric
      │
      ▼
Application Logs
      │
      ▼
request_id
      │
      ▼
Runtime Logs
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
failure_type
```

This transforms observability from isolated signals into execution-aware evidence.

---

# 79. Runtime Integration in Controllers

Business controllers do not directly implement retry loops.

Instead of:

```javascript
try {
  await dependencyCall();
} catch (...) {
  // retry
}
```

infrastructure operations are wrapped by:

```javascript
executeInfrastructureOperation({
  req,
  dependency,
  operation
})
```

The controller remains focused on application workflow.

---

# 80. Example: User Registration

Database insertion executes through:

```text
register controller
      │
      ▼
Infrastructure Boundary
      │
      ▼
PostgreSQL
```

The Runtime knows:

```text
operation = USER_REGISTER
dependency = POSTGRESQL
```

and applies the `USER_REGISTER` policy.

Current policy:

```text
timeout = 5000
retry = false
maxRetries = 0
recoverable = false
```

A dependency failure is therefore observable but not automatically retried by this policy.

---

# 81. Example: User Login

The database lookup follows the same boundary:

```text
USER_LOGIN
    │
    ▼
POSTGRESQL
```

The operation-specific policy keeps authentication behavior conservative.

A failed database dependency is not confused with:

```text
invalid credentials
```

These are different failure domains.

---

# 82. Example: ID Upload

The ID upload workflow interacts with:

```text
MinIO
PostgreSQL
Redis
```

through separate infrastructure operations.

Conceptually:

```text
ID_UPLOAD Runtime
      │
      ├── MinIO Operation
      │
      ├── PostgreSQL Operation
      │
      └── Redis Operation
```

Each operation executes under the same request-level Runtime policy but retains dependency identity.

---

# 83. ID Upload Reliability Policy

The current policy is:

```text
timeout = 10000 ms
retry = true
maxRetries = 2
recoverable = true
```

This means eligible transient infrastructure failures can be retried.

It does **not** mean every error during ID upload will be retried.

The failure classifier must still mark the error as retryable.

---

# 84. Workflow-Level Limitation

The Runtime currently protects individual infrastructure operations.

It does not automatically provide distributed transaction semantics across the entire upload workflow.

For example:

```text
MinIO succeeds
     │
     ▼
PostgreSQL succeeds
     │
     ▼
Redis fails permanently
```

The Runtime can detect and retry the Redis operation.

But if Redis ultimately fails, the Runtime does not automatically undo:

```text
MinIO write
PostgreSQL update
```

This is a workflow recovery problem.

It belongs to higher-level recovery architecture.

---

# 85. Runtime Reliability vs Workflow Reliability

The distinction is:

```text
Runtime Reliability
=
Protect individual execution and dependency interactions
```

while:

```text
Workflow Reliability
=
Preserve correctness across multi-step side effects
```

Runtime Reliability is necessary but not sufficient for complete workflow consistency.

---

# 86. API and Worker Runtime Relationship

The API and Worker use the same reliability architecture but have different execution models.

```text
                   Shared Runtime Model
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
          API Runtime               Worker Runtime
              │                         │
          HTTP Request                BullMQ Job
              │                         │
       Route Operation             Job Operation
              │                         │
       Request Lifecycle           Job Lifecycle
```

The Worker implementation is adapted to Worker semantics rather than copied blindly from Express middleware behavior.

---

# 87. Why the Worker Requires Adaptation

An HTTP request and a background job differ fundamentally.

HTTP execution has:

```text
request
response
route
HTTP status
```

BullMQ execution has:

```text
job
queue
attempt
job lifecycle
BullMQ retry semantics
```

Therefore the Runtime architecture can be transferred, but transport-specific integration cannot.

The invariant is:

```text
Same Reliability Architecture
≠
Identical Integration Code
```

---

# 88. Worker Runtime Responsibility

The Worker Runtime exists above BullMQ rather than replacing it.

Conceptually:

```text
Reliability Runtime
        │
        ▼
BullMQ Runtime
        │
        ▼
Job Processor
```

BullMQ continues to own queue mechanics.

The Reliability Runtime owns platform-specific execution reliability semantics.

This avoids duplicating queue-engine responsibilities.

---

# 89. Runtime Capability Model

The broader Runtime Reliability capability profile includes concerns such as:

```text
Timeout
Retry
Exponential Backoff
Graceful Cancellation
Idempotency
Resource Protection
Health Verification
```

Not every capability has identical implementation maturity in every execution path.

Documentation must distinguish:

```text
Architectural Capability
```

from:

```text
Mechanism Currently Implemented in a Specific Boundary
```

For example, the API infrastructure executor concretely implements timeout, retry, and backoff, while universal cancellation should not be inferred from `Promise.race()`.

---

# 90. Runtime Contract Violations

The Runtime treats architectural invariant violations differently from normal dependency failures.

Examples include:

```text
Runtime missing
Invalid Runtime state
Runtime instance changed
Execution identity mismatch
Request identity mismatch
Operation already attached
Policy already attached
Policy missing before activation
Illegal lifecycle transition
```

These indicate defects in Runtime integration or execution flow.

They are not ordinary transient infrastructure conditions.

---

# 91. Why Contract Violations Should Not Be Retried

Consider:

```text
Runtime instance changed
```

Retrying PostgreSQL does not solve this.

Likewise:

```text
Policy missing
```

is a deterministic integration defect.

Therefore:

```text
Runtime Contract Failure
        │
        ▼
Fail Fast
        │
        ▼
Produce Evidence
        │
        ▼
Correct Engineering Defect
```

is preferable to automatic retry.

---

# 92. Runtime Invariants

Several invariants govern the architecture.

## Invariant 1 — One Runtime per Execution

An execution should have one authoritative Runtime context.

---

## Invariant 2 — Stable Execution Identity

`requestId` and `executionId` must not change during execution.

---

## Invariant 3 — Operation Before Activation

An operation must be resolved before execution becomes active.

---

## Invariant 4 — Policy Before Reliability Activation

Reliability cannot activate without a policy.

---

## Invariant 5 — Reliability Before Execution Activation

Runtime reliability is activated before the execution enters `ACTIVE`.

---

## Invariant 6 — Legal State Transitions Only

Lifecycle transitions must follow the state machine.

---

## Invariant 7 — Bounded Retry

Retries must never be unbounded.

---

## Invariant 8 — Classification Before Recovery Decision

Recovery behavior must be based on failure semantics.

---

## Invariant 9 — Terminal Failure Propagates

The Runtime must not silently transform unrecovered failure into success.

---

## Invariant 10 — Execution Eventually Completes

Initialized executions should reach `COMPLETED`.

---

# 93. Runtime Reliability Decision Model

The complete decision flow is:

```text
Operation
   │
   ▼
Resolve Policy
   │
   ▼
Activate Reliability
   │
   ▼
Execute Dependency Operation
   │
   ▼
Attempt
   │
   ├──────────── Success ───────────────┐
   │                                    │
   ▼                                    │
Failure                                 │
   │                                    │
   ▼                                    │
Classify                                │
   │                                    │
   ▼                                    │
Retry Allowed?                          │
   │                                    │
 ┌─┴─┐                                  │
 │   │                                  │
No  Yes                                 │
 │   │                                  │
 │   ▼                                  │
 │ Backoff                              │
 │   │                                  │
 │   ▼                                  │
 │ Retry ───── Success ─────► Recovery  │
 │   │                                  │
 │ Failure                              │
 │   │                                  │
 │   ▼                                  │
 │ Retries Remaining?                   │
 │   │                                  │
 │   └───────────────► Retry            │
 │                                      │
 ▼                                      ▼
Register Failure                    Complete
   │                                    │
   ▼                                    │
Propagate Error                          │
   │                                    │
   ▼                                    │
Failure Handler                         │
   │                                    │
   └──────────────► Complete ◄───────────┘
```

---

# 94. Runtime Reliability and Health

Health checks themselves are represented as Runtime operations.

Current API operations include:

```text
HEALTH_LIVENESS
HEALTH_READINESS
```

with distinct policies.

This prevents health endpoints from bypassing execution semantics entirely.

However, liveness and readiness serve different purposes.

Liveness should remain lightweight.

Readiness may verify dependencies.

Runtime policy must preserve that distinction.

---

# 95. Liveness Policy

Current liveness policy:

```text
timeout = 1000 ms
retry = false
maxRetries = 0
recoverable = false
```

The liveness endpoint itself returns a simple alive response.

It should not become dependent on heavy infrastructure verification.

Otherwise a dependency failure could incorrectly make a healthy process appear dead.

---

# 96. Readiness Policy

Current readiness policy:

```text
timeout = 3000 ms
retry = false
maxRetries = 0
recoverable = false
```

The operation declares:

```text
requiresDatabase = true
```

and executes system health verification.

Readiness can therefore represent whether the service is capable of serving its expected role rather than merely whether the process exists.

---

# 97. Runtime Reliability and Security

Runtime Reliability is not a security authorization system.

However, it contributes to security-related engineering properties through:

* stable execution identity;
* controlled error exposure;
* immutable operation identity;
* Runtime integrity checks;
* bounded resource behavior;
* structured evidence.

Sensitive internals should not be returned directly through Runtime errors.

---

# 98. Runtime Reliability and Resource Protection

Bounded timeout and retry contribute to resource protection.

Without limits:

```text
Slow dependency
      │
      ▼
Requests accumulate
      │
      ▼
Resources remain occupied
      │
      ▼
Service degradation
```

Timeout introduces an execution waiting boundary.

Bounded retry prevents infinite recovery loops.

However, complete resource protection may additionally require:

```text
Concurrency limits
Queue limits
Connection pool limits
Memory limits
CPU limits
Backpressure
Circuit breaking
```

depending on future system scale.

---

# 99. Runtime Reliability and Idempotency

Retry is safe only when repeated execution has acceptable semantics.

For a read operation:

```text
SELECT ...
```

retry is often naturally safer.

For a side-effecting operation:

```text
INSERT
UPLOAD
ENQUEUE
UPDATE
```

retry may duplicate effects depending on dependency behavior and failure timing.

Therefore:

```text
Retryable Failure
        │
        ▼
Policy Allows Retry
        │
        ▼
Is Re-execution Safe?
```

is an important architectural question.

The current Runtime's retry capability should not be interpreted as universal proof of idempotency.

---

# 100. Runtime Reliability and Side Effects

Consider:

```text
Operation sent to dependency
        │
        ▼
Dependency commits side effect
        │
        X
Response lost
        │
        ▼
Runtime observes failure
        │
        ▼
Retry
```

The Runtime may not know whether the first attempt actually committed.

This is the classic ambiguous outcome problem.

Production-grade evolution may require mechanisms such as:

```text
Idempotency Keys
Unique Constraints
Transactional Outbox
Deduplication
Operation Tokens
Dependency-Specific Semantics
```

where appropriate.

---

# 101. Runtime Reliability and Cancellation

Graceful cancellation should be modeled explicitly.

A timeout can produce:

```text
Caller stops waiting
```

without necessarily producing:

```text
Dependency stops work
```

Future cancellation-capable operations should ideally support:

```text
Runtime Deadline
      │
      ▼
Cancellation Signal
      │
      ▼
Dependency Client
      │
      ▼
Underlying Operation Aborted
```

where supported.

This is stronger than the current generic timeout race.

---

# 102. Runtime Reliability and Circuit Breaking

The current Runtime implements per-execution retry behavior.

It does not imply a global circuit breaker.

A circuit breaker would introduce dependency-wide state such as:

```text
CLOSED
  │
 failures
  ▼
OPEN
  │
 recovery window
  ▼
HALF_OPEN
```

That is a different mechanism from retry.

For the current single-node architecture, circuit breaking should only be introduced when justified by observed failure behavior rather than added mechanically.

---

# 103. Runtime Reliability and Backpressure

Retry controls what happens after a failure.

Backpressure controls whether new work should be admitted when the system is overloaded.

These are different concerns.

```text
Retry
=
Re-execution after failure
```

```text
Backpressure
=
Control incoming work before overload expands
```

Worker queue depth and API in-flight requests provide signals that may support future backpressure decisions.

---

# 104. Runtime Reliability and Observability Cardinality

Runtime identifiers such as:

```text
request_id
execution_id
```

are excellent log correlation fields.

They should generally not become Prometheus metric labels because they are high-cardinality values.

Metrics should prefer bounded dimensions such as:

```text
operation
dependency
outcome
failure_type
```

while logs carry execution-specific identifiers.

This distinction protects Prometheus scalability.

---

# 105. Runtime Reliability and Logging

Structured Runtime logs use stable fields rather than free-form messages alone.

Example conceptual event:

```json
{
  "event": "runtime_operation_failed",
  "request_id": "...",
  "execution_id": "...",
  "operation_id": "id_upload",
  "dependency": "minio",
  "failure_type": "dependency",
  "recoverable": true,
  "error_code": "ECONNRESET"
}
```

This structure enables Loki filtering and incident correlation.

---

# 106. Runtime Reliability and Promtail

Application logs are emitted as JSON.

Promtail collects Docker container logs and extracts selected fields.

High-cardinality correlation fields should remain log fields rather than promoted Loki labels.

This preserves query capability without creating uncontrolled label cardinality.

---

# 107. Runtime Reliability and Alerting

Runtime failures can contribute evidence to higher-level alerts.

For example:

```text
Runtime dependency failures ↑
          │
          ▼
API HTTP errors ↑
          │
          ▼
MWHighAPIErrorRate
```

or:

```text
Worker Runtime failures ↑
          │
          ▼
Job failures ↑
          │
          ▼
MWHighJobFailureRate
```

Alerts should normally represent operational impact rather than every individual Runtime failure.

---

# 108. Runtime Reliability and Incident Diagnosis

A Runtime-aware incident investigation can follow:

```text
Alert
  │
  ▼
Affected Service
  │
  ▼
Affected Operation
  │
  ▼
Dependency
  │
  ▼
Failure Type
  │
  ▼
Retry Activity
  │
  ▼
Recovery State
  │
  ▼
Specific Execution Logs
```

This provides a much stronger diagnosis path than inspecting generic application errors.

---

# 109. Runtime Failure Scenarios

## Scenario A — Immediate Success

```text
Operation
   │
   ▼
Attempt 1
   │
   ▼
Success
```

Expected state:

```text
attempts = 1
retries = 0
recovered = false
failure.occurred = false
```

---

## Scenario B — Transient Failure and Recovery

```text
Attempt 1
   │
ECONNRESET
   │
   ▼
Classified Retryable
   │
   ▼
Backoff
   │
   ▼
Attempt 2
   │
   ▼
Success
```

Expected state:

```text
attempts = 2
retries = 1
recovered = true
failure.occurred = false
```

The transient attempt failure is observed through retry evidence, while the Runtime's terminal failure state remains clear because the execution ultimately recovered.

---

## Scenario C — Retry Exhaustion

```text
Attempt 1
   │
 failure
   ▼
Attempt 2
   │
 failure
   ▼
Attempt 3
   │
 failure
   ▼
Register Failure
```

Expected state for `maxRetries = 2`:

```text
attempts = 3
retries = 2
recovered = false
failure.occurred = true
```

---

## Scenario D — Non-Retryable Failure

```text
Attempt 1
   │
   ▼
Failure
   │
   ▼
classification.retryable = false
   │
   ▼
No Retry
   │
   ▼
Terminal Failure
```

---

## Scenario E — Policy Disables Retry

```text
Retryable Dependency Error
          │
          ▼
Policy.retry = false
          │
          ▼
No Retry
```

Failure classification alone does not override policy.

---

# 110. Runtime Validation Strategy

Runtime Reliability should be validated at multiple levels.

```text
Unit Validation
      │
      ▼
Integration Validation
      │
      ▼
Failure Injection
      │
      ▼
Operational Validation
```

---

# 111. Lifecycle Validation

Tests should verify legal transitions:

```text
CREATED → INITIALIZED
INITIALIZED → ACTIVE
ACTIVE → COMPLETED
INITIALIZED → COMPLETED
```

and reject illegal transitions.

Examples:

```text
CREATED → COMPLETED
COMPLETED → ACTIVE
ACTIVE → INITIALIZED
```

---

# 112. Integrity Validation

Tests should verify that Runtime Guard detects:

```text
missing Runtime
replaced Runtime instance
changed execution ID
changed request ID
invalid Runtime state
```

This validates the Runtime contract rather than only happy-path behavior.

---

# 113. Policy Validation

Tests should verify:

```text
known operation → expected policy
unknown operation → default policy
policy immutable
duplicate policy attachment rejected
```

---

# 114. Timeout Validation

A controlled slow operation should verify:

```text
Operation exceeds timeout
        │
        ▼
RuntimeTimeoutError
        │
        ▼
RUNTIME_TIMEOUT
        │
        ▼
TIMEOUT classification
```

The test should not incorrectly claim that the underlying operation was cancelled unless cancellation is explicitly verified.

---

# 115. Retry Validation

Tests should verify:

```text
retryable + policy enabled
→ retry
```

and:

```text
retryable + policy disabled
→ no retry
```

and:

```text
non-retryable + policy enabled
→ no retry
```

This validates the combined decision model.

---

# 116. Backoff Validation

Backoff tests should verify:

```text
Attempt 1 → 100 ms
Attempt 2 → 200 ms
Attempt 3 → 400 ms
...
Cap → 1000 ms
```

Exact timing assertions should allow reasonable scheduling tolerance.

---

# 117. Recovery Validation

A failure-then-success experiment should verify:

```text
attempts > 1
retries > 0
recovered = true
```

and confirm that observability reports the operation outcome as:

```text
recovered
```

rather than ordinary success.

---

# 118. Failure Propagation Validation

When all attempts fail:

```text
Runtime registers failure
        │
        ▼
Infrastructure boundary records evidence
        │
        ▼
Original failure propagates
        │
        ▼
Failure handler completes Runtime
```

Tests should verify that the failure is not silently swallowed.

---

# 119. Observability Validation

Runtime tests should confirm expected evidence appears in:

```text
Logs
Metrics
Runtime State
HTTP Response
```

For a retry scenario, expected evidence includes:

```text
RUNTIME_OPERATION_STARTED
RUNTIME_OPERATION_RETRY
RUNTIME_OPERATION_COMPLETED
RUNTIME_COMPLETED
```

For terminal failure:

```text
RUNTIME_OPERATION_STARTED
RUNTIME_OPERATION_FAILED
RUNTIME_FAILURE_HANDLED
```

with lifecycle completion occurring through the applicable completion path.

---

# 120. Dependency Failure Injection

Operational validation can intentionally make dependencies unavailable.

Examples:

```text
Stop PostgreSQL
Stop Redis
Stop MinIO
```

Then verify:

```text
Failure detected
      │
      ▼
Correct dependency identified
      │
      ▼
Correct classification
      │
      ▼
Policy applied
      │
      ▼
Retry behavior correct
      │
      ▼
Failure or recovery visible
```

---

# 121. Timeout Failure Injection

Artificial dependency latency can verify:

```text
Configured Runtime Timeout
          │
          ▼
Deadline Exceeded
          │
          ▼
RuntimeTimeoutError
          │
          ▼
Retry if eligible
          │
          ▼
Recovery or terminal failure
```

This is more meaningful than testing timeout helpers in isolation.

---

# 122. Runtime Anti-Patterns

## 122.1 Calling Dependencies Outside the Boundary

Avoid:

```text
Controller
   │
   ▼
Direct dependency call
```

when the operation is intended to receive Runtime reliability behavior.

This bypasses:

```text
timeout
retry
metrics
classification
recovery tracking
```

---

## 122.2 Implementing Local Retry Loops

Avoid controller-specific retry logic.

It creates competing reliability semantics.

---

## 122.3 Mutating Runtime Identity

Execution identity must remain stable.

---

## 122.4 Attaching Multiple Policies

One execution should have one authoritative Reliability Policy.

---

## 122.5 Activating Without Operation Context

Reliability decisions should remain operation-aware.

---

## 122.6 Retrying Unknown Failures

Unknown failures should remain conservative until evidence justifies classification.

---

## 122.7 Treating Timeout as Cancellation

This overstates the guarantee provided by the current implementation.

---

## 122.8 Treating Recovery as Invisible Success

Recovered operations should remain observable because they indicate underlying instability.

---

## 122.9 Putting Correlation IDs in Metrics

High-cardinality execution IDs belong in logs, not Prometheus labels.

---

# 123. Operational Interpretation

Runtime reliability evidence should be interpreted carefully.

For example:

```text
HTTP success rate = healthy
```

does not necessarily mean:

```text
Runtime completely healthy
```

because repeated transient failures may be recovered before reaching users.

A more complete view is:

```text
User-visible health
        +
Runtime retries
        +
Recovery rate
        +
Dependency latency
        +
Failure classifications
```

This can reveal degradation before an outage becomes visible.

---

# 124. Recovered Operations as Early Warning

Consider:

```text
HTTP success = 100%
```

but:

```text
Runtime retries ↑
Recovered operations ↑
```

The service is still serving users, but dependency stability is deteriorating.

Therefore recovered operations are valuable early-warning signals.

---

# 125. Reliability Escalation Pattern

A typical degradation path may look like:

```text
Dependency Latency ↑
        │
        ▼
Timeouts Begin
        │
        ▼
Retries Increase
        │
        ▼
Recoveries Increase
        │
        ▼
Retries Exhausted
        │
        ▼
Application Errors Increase
        │
        ▼
Alert Fires
```

Runtime Reliability provides evidence in the middle of this chain rather than observing only the final outage.

---

# 126. Production-Grade Evolution

The current Runtime establishes the architectural foundation for future capabilities.

Potential future evolution may include:

```text
Cancellation propagation
Idempotency enforcement
Jittered backoff
Circuit breaking
Concurrency protection
Bulkheads
Adaptive policies
Dependency health-aware admission
Deadline propagation
Workflow compensation
Distributed tracing
SLO-driven policy tuning
```

These mechanisms should only be introduced when their ownership and semantics are clear.

The Runtime architecture exists so such capabilities can be added coherently rather than scattered through application code.

---

# 127. Runtime Reliability Boundaries

It is important to state what Runtime Reliability does **not** own.

Runtime Reliability does not replace:

```text
Docker restart behavior
Deployment rollback
Database durability
Redis persistence
MinIO durability
Host recovery
Alertmanager routing
Incident response
Workflow compensation
```

Instead, it owns the execution-level reliability boundary.

The complete reliability stack is:

```text
Application Correctness
        │
        ▼
Runtime Reliability
        │
        ▼
Workflow Reliability
        │
        ▼
Service Reliability
        │
        ▼
Deployment Reliability
        │
        ▼
Infrastructure Reliability
        │
        ▼
Operational Recovery
```

---

# 128. Relationship With Failure Model

The Failure Model defines:

```text
What failure means
How failure is classified
Where failure belongs
How failure propagates
```

Runtime Reliability implements part of that model at execution level.

```text
Failure Model
      │
      ▼
Runtime Failure Classification
      │
      ▼
Reliability Decision
      │
      ▼
Execution Mechanism
```

See:

```text
docs/reliability/failure-model.md
```

for the broader failure architecture.

---

# 129. Relationship With Recovery

Runtime Reliability provides mechanisms such as:

```text
retry
backoff
execution recovery tracking
```

but system recovery extends beyond Runtime execution.

Examples include:

```text
container restart
dependency restoration
deployment rollback
workflow repair
state reconciliation
```

These belong to the broader Recovery architecture documented in:

```text
docs/reliability/recovery.md
```

---

# 130. Relationship With Observability

Runtime Reliability produces evidence consumed by the observability architecture.

```text
Runtime
   │
   ├── Metrics ─────► Prometheus
   │
   └── Logs ────────► Promtail ─► Loki
                               │
                               ▼
                            Grafana
```

Alerts then operate on higher-level operational signals.

Runtime Reliability therefore depends on Observability for operational visibility, but it remains an independent execution architecture.

---

# 131. Relationship With Operations

Operations uses Runtime evidence to answer:

```text
What operation failed?

Which dependency was involved?

Was the failure transient?

Was retry attempted?

Did recovery succeed?

Which execution was affected?

What should be investigated next?
```

Runtime Reliability therefore forms a bridge between application execution and operational diagnosis.

---

# 132. Runtime Reliability Reference Model

The architecture can be summarized as:

```text
                         EXECUTION
                             │
                             ▼
                    Runtime Bootstrap
                             │
                             ▼
                    Execution Identity
                             │
                             ▼
                    Runtime Integrity
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
                    Execution ACTIVE
                             │
                             ▼
                Infrastructure Boundary
                             │
                             ▼
                  Reliability Executor
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
           Timeout         Attempt       Classification
              │              │              │
              └──────────────┼──────────────┘
                             ▼
                      Retry Decision
                             │
                  ┌──────────┴──────────┐
                  ▼                     ▼
               Retry                 No Retry
                  │                     │
                  ▼                     │
               Backoff                  │
                  │                     │
                  ▼                     │
               Attempt                  │
                  │                     │
          ┌───────┴───────┐             │
          ▼               ▼             │
       Success          Failure ◄────────┘
          │               │
          ▼               ▼
       Recovery      Register Failure
          │               │
          ▼               ▼
      Observability    Propagation
          │               │
          └───────┬───────┘
                  ▼
             Completion
                  │
                  ▼
           Runtime Evidence
```

---

# 133. Definition of Done

Runtime Reliability is considered architecturally established when the system can answer all of the following:

```text
✓ Does every controlled execution have Runtime identity?

✓ Is Runtime lifecycle explicit?

✓ Are illegal lifecycle transitions rejected?

✓ Is Runtime integrity verified?

✓ Is the operation identified before execution?

✓ Is a Reliability Policy resolved explicitly?

✓ Is reliability activated before application execution?

✓ Are infrastructure operations executed through a defined boundary?

✓ Are timeouts bounded?

✓ Are retries bounded?

✓ Are retry decisions classification- and policy-driven?

✓ Is backoff applied between retries?

✓ Are failures classified?

✓ Are terminal failures preserved and propagated?

✓ Can recovered execution be distinguished from first-attempt success?

✓ Are attempts and retries tracked separately?

✓ Is failure state available through the Runtime?

✓ Does execution eventually reach a terminal lifecycle state?

✓ Are Runtime operations observable through metrics?

✓ Are Runtime events observable through structured logs?

✓ Can user-visible failures be correlated using request identity?

✓ Are high-cardinality execution identifiers kept out of metric labels?

✓ Are timeout and cancellation semantics distinguished?

✓ Are Runtime Reliability and workflow recovery kept architecturally separate?

✓ Are API and Worker implementations governed by the same Runtime architecture while respecting their different execution models?
```

---

# 134. Final Architecture

The Mini-Write Runtime Reliability model can ultimately be expressed as:

```text
                   APPLICATION OPERATION
                            │
                            ▼
                     EXECUTION CONTEXT
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
          Identity       Operation        State
             │              │              │
             └──────────────┼──────────────┘
                            ▼
                    RELIABILITY POLICY
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
          Timeout          Retry       Recoverability
             │              │              │
             └──────────────┼──────────────┘
                            ▼
                 INFRASTRUCTURE BOUNDARY
                            │
                            ▼
                   EXECUTION ATTEMPT
                            │
                   ┌────────┴────────┐
                   ▼                 ▼
                Success           Failure
                   │                 │
                   │                 ▼
                   │            Classification
                   │                 │
                   │          ┌──────┴──────┐
                   │          ▼             ▼
                   │       Retryable    Terminal
                   │          │             │
                   │          ▼             │
                   │       Backoff           │
                   │          │             │
                   │          ▼             │
                   │        Retry            │
                   │          │             │
                   │     ┌────┴────┐        │
                   │     ▼         ▼        │
                   │  Recovery   Failure ───┘
                   │     │         │
                   └─────┼─────────┘
                         ▼
                    OBSERVABILITY
                         │
                         ▼
                     COMPLETION
```

The central architectural principle is:

> **Every important execution should have an identity, lifecycle, operation context, explicit reliability policy, controlled infrastructure boundary, bounded failure behavior, and observable final outcome.**

Runtime Reliability therefore transforms reliability from scattered defensive code into a coherent execution architecture.

```
```
