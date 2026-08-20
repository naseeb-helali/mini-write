# Runtime Issues

## 1. Purpose

This document provides troubleshooting guidance for failures occurring inside the application runtime layer of Mini-Write.

It focuses on runtime behavior after the infrastructure and deployment layers have successfully started the application components.

The runtime layer is responsible for providing a consistent execution model around application operations, including:

- execution identity
- execution lifecycle
- operation resolution
- reliability policy resolution
- reliability activation
- failure classification
- timeout handling
- retry execution
- recovery tracking
- infrastructure-operation boundaries
- runtime observability
- runtime failure propagation

The runtime architecture exists in both the API and Worker components.

The implementation is adapted to the execution model of each component, but the architectural responsibility is equivalent:

```text
Application Component
        │
        ▼
Component Runtime
        │
        ├── Execution Context
        ├── Operation Context
        ├── Reliability Policy
        ├── Reliability Execution
        ├── Failure Classification
        ├── Recovery
        └── Runtime Observability
````

This document should be used together with:

* `docs/architecture/runtime-architecture.md`
* `docs/reliability/reliability.md`
* `docs/reliability/failure-model.md`
* `docs/reliability/runtime-reliability.md`
* `docs/reliability/recovery.md`
* `docs/reference/runtime-reference.md`
* `docs/troubleshooting/common-issues.md`
* `docs/troubleshooting/deployment-issues.md`

---

# 2. Runtime Troubleshooting Philosophy

Runtime troubleshooting should begin with the runtime contract rather than immediately modifying application code.

The primary question is:

> Which runtime invariant was violated?

The runtime can be viewed as a sequence:

```text
Runtime Creation
      │
      ▼
Initialization
      │
      ▼
Guard Validation
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
Operation Execution
      │
      ▼
Failure / Recovery
      │
      ▼
Completion
```

A failure should therefore be localized to one of these stages.

---

# 3. Runtime Failure Classification

Runtime failures generally fall into the following categories:

```text
Runtime Issue
    │
    ├── Runtime Initialization
    │
    ├── Runtime Integrity
    │
    ├── Operation Resolution
    │
    ├── Policy Resolution
    │
    ├── Reliability Activation
    │
    ├── Infrastructure Boundary
    │
    ├── Timeout
    │
    ├── Retry
    │
    ├── Failure Classification
    │
    ├── Recovery
    │
    ├── Completion
    │
    └── Runtime Observability
```

Do not assume that an error thrown during a business operation is automatically a runtime implementation defect.

The runtime may be correctly detecting and propagating an application or dependency failure.

---

# 4. First Runtime Diagnostic

When a runtime issue occurs, establish:

```text
Request / Job identity
Operation
Runtime state
Reliability policy
Dependency
Failure classification
Retry count
Recovery state
Final outcome
```

For the API, useful runtime identifiers include:

```text
request_id
execution_id
operation_id
```

For runtime logs, inspect events such as:

```text
runtime_operation_started
runtime_operation_retry
runtime_operation_completed
runtime_operation_failed
runtime_failure_handled
runtime_completed
```

The exact available fields depend on the execution path.

---

# 5. Runtime Identity

Each API execution context creates:

```text
requestId
executionId
```

The request ID is also exposed through:

```text
X-Request-Id
```

Runtime identity exists to correlate a single execution across:

```text
request
→ runtime
→ operation
→ dependency operation
→ failure
→ completion
```

If these identifiers disappear or change unexpectedly during one execution, treat this as a runtime integrity issue.

---

# 6. Runtime Context Is Missing

A runtime-dependent execution expects:

```text
req.runtime
```

to exist.

If runtime access reports:

```text
Runtime Contract Violation: Runtime is missing.
```

the execution reached a runtime-dependent component without having passed through runtime initialization.

For API requests, verify the middleware ordering in the application bootstrap.

The expected conceptual order is:

```text
runtimeBootstrap
      │
      ▼
runtimeGuard
      │
      ▼
application middleware / routes
```

A runtime consumer must not execute before runtime initialization.

---

# 7. Runtime Guard Failure

The API runtime guard validates:

```text
runtime presence
runtime state
runtime identity
runtime integrity
```

A guard failure should be treated as a contract violation rather than a normal application failure.

Possible causes include:

```text
middleware ordering change
runtime middleware removed
runtime object replaced
runtime identity modified
unexpected middleware path
test setup bypassing runtime initialization
```

Do not bypass the guard merely to make the request succeed.

The guard exists to enforce runtime architecture.

---

# 8. Invalid Initial Runtime State

The runtime guard expects the execution context to be in:

```text
initialized
```

before the next runtime lifecycle stage.

The lifecycle is:

```text
created
   │
   ▼
initialized
   │
   ▼
active
   │
   ▼
completed
```

If the guard observes another state, investigate the transition that occurred before the guard.

Do not manually mutate the state to `initialized`.

The correct fix is to restore the lifecycle transition that should have produced that state.

---

# 9. Illegal Runtime State Transition

The execution context enforces allowed transitions.

```text
created
   └── initialized

initialized
   ├── active
   └── completed

active
   └── completed

completed
   └── none
```

An error such as:

```text
Illegal execution transition: X -> Y
```

means that runtime lifecycle code attempted an unsupported transition.

This is a runtime contract violation.

Investigate:

```text
who invoked the transition
current state
requested state
execution path
whether completion was already triggered
```

Do not simply remove the state validation.

---

# 10. Runtime Completion Happens Too Early

A runtime execution should not transition to:

```text
completed
```

while an operation still requires the runtime.

If completion occurs prematurely, inspect:

```text
response lifecycle
error handling
middleware ordering
asynchronous execution
explicit complete() calls
```

For API requests, the runtime completion observer is attached to the response lifecycle.

Therefore, investigate whether completion is being triggered by:

```text
response finish
runtime failure handling
another explicit lifecycle operation
```

The goal is to ensure that completion represents actual execution completion.

---

# 11. Runtime Completion Happens More Than Once

The runtime lifecycle does not allow:

```text
completed → completed
```

If duplicate completion attempts appear, identify the competing completion paths.

Typical candidates include:

```text
normal response completion
runtime failure handler
explicit application completion
```

The solution is not to make `complete()` silently accept invalid transitions.

Instead, establish which component owns completion for that execution path.

---

# 12. Operation Resolution Failure

Operations are resolved using definitions such as:

```text
USER_LOGIN
USER_REGISTER
USER_PROFILE
ID_UPLOAD
HEALTH_LIVENESS
HEALTH_READINESS
```

Each operation contains:

```text
identity
category
characteristics
metadata
```

If operation resolution fails, verify:

```text
operation definition exists
operation ID is valid
category is valid
middleware is attached to the correct route
runtime is initialized
```

An operation should be attached before reliability activation.

---

# 13. Operation Cannot Be Attached

The execution context rejects operation attachment when:

```text
execution is already active
execution is already completed
another operation is already attached
operation does not satisfy the required interface
```

If this occurs, inspect middleware ordering.

The intended sequence is:

```text
Runtime Initialization
        │
        ▼
Operation Resolution
        │
        ▼
Policy Resolution
        │
        ▼
Reliability Activation
```

Do not attach another operation to an already resolved execution.

---

# 14. Operation Definition Is Invalid

An operation must expose:

```text
identity.id
isOperation()
isCategory()
getSnapshot()
```

If validation rejects an operation definition, inspect the operation context construction.

The runtime should fail explicitly rather than silently accepting malformed operation metadata.

---

# 15. Reliability Policy Is Missing

Runtime state activation requires a reliability policy.

If the runtime reports:

```text
Runtime Contract Violation: Reliability policy is missing.
```

investigate the operation-resolution stage.

The expected sequence is:

```text
Operation
   │
   ▼
Policy Resolver
   │
   ▼
Runtime.attachPolicy()
   │
   ▼
Reliability Activation
```

Possible causes:

```text
operation resolution bypassed
policy resolver not called
invalid operation definition
middleware ordering problem
```

---

# 16. Wrong Reliability Policy

Each supported operation may have its own policy.

Examples include:

```text
user_login
user_register
user_profile
id_upload
health_liveness
health_readiness
```

Policies define properties such as:

```text
timeout
retry
maxRetries
recoverable
```

If runtime behavior does not match the expected policy, verify the operation ID first.

A wrong operation ID can produce a valid but incorrect policy.

This is especially important because the resolver falls back to the default policy for unknown operation IDs.

---

# 17. Default Policy Is Being Used Unexpectedly

The default policy is used when:

```text
operation ID is missing
```

or:

```text
operation ID is not present in the policy mapping
```

If an operation unexpectedly behaves as though it has no retry or a different timeout, inspect:

```text
operation.identity.id
policy resolver mapping
operation definition
```

Do not immediately modify the default policy.

First determine why the expected operation-specific policy was not selected.

---

# 18. Reliability Activation Failure

Reliability activation requires:

```text
policy attached
```

before:

```text
activateReliability()
```

If activation fails, inspect:

```text
policy resolution
runtime state
operation resolution
middleware ordering
```

A runtime that has not activated reliability should not be treated as equivalent to a fully initialized runtime.

---

# 19. Infrastructure Boundary Is Not Available

Infrastructure operations are executed through:

```text
executeInfrastructureOperation()
```

The boundary obtains the runtime from the request.

If runtime access fails there, verify:

```text
request exists
runtime exists
runtime guard executed
operation context exists
```

The infrastructure boundary is intentionally coupled to the runtime because dependency failures, retries, timing, and observability must remain associated with the current execution.

---

# 20. Infrastructure Operation Fails Without Runtime Context

If application code invokes the infrastructure boundary outside a valid runtime execution, the operation cannot reliably participate in:

```text
runtime identity
policy
retry
timeout
failure classification
runtime metrics
```

Do not bypass the runtime boundary by directly calling the dependency merely to avoid the error.

Instead determine whether the operation genuinely belongs inside the runtime-controlled execution model.

---

# 21. Runtime Timeout

A runtime timeout produces:

```text
RuntimeTimeoutError
```

with:

```text
code = RUNTIME_TIMEOUT
```

and metadata including:

```text
dependency
timeoutMs
retryAttempt
```

For API HTTP handling, the runtime failure handler maps this error to:

```text
HTTP 504
```

The first diagnostic question is:

> Which operation and dependency exceeded the configured runtime timeout?

---

# 22. Timeout Does Not Necessarily Stop the Underlying Operation

The runtime timeout implementation uses a race between:

```text
operation()
```

and:

```text
timeoutPromise
```

Therefore, a timeout means that the runtime stopped waiting for the operation within the configured timeout.

It does not automatically imply that the underlying JavaScript operation has been forcibly cancelled.

This distinction is operationally important.

```text
Runtime timeout
      │
      ├── caller stops waiting
      │
      └── underlying operation may still be executing
```

Do not describe runtime timeout as guaranteed cancellation unless the underlying operation explicitly supports cancellation.

---

# 23. Timeout Occurs Too Frequently

If timeout failures increase, correlate:

```text
operation
dependency
configured timeout
actual duration
host resource usage
dependency latency
retry behavior
```

Possible causes include:

```text
dependency degradation
host resource pressure
network latency
incorrect timeout policy
application regression
```

Do not simply increase the timeout.

A larger timeout can hide dependency degradation and increase resource occupancy.

---

# 24. Retry Is Not Occurring

Retries occur only when the runtime conditions allow them.

The effective conditions include:

```text
retry enabled
attempts remain
runtime is recoverable
failure classification is retryable
```

For example, a policy may define:

```text
retry: true
maxRetries: 2
recoverable: true
```

but a validation or authentication failure should still not be retried if its classification is non-retryable.

Investigate:

```text
policy
failure classification
attempt number
recoverability
```

---

# 25. Retry Happens for the Wrong Failure

If a non-transient failure is retried, inspect the failure classifier.

The classifier distinguishes categories including:

```text
timeout
dependency
validation
authentication
authorization
internal
```

Retryability is derived from the classification.

A dependency operation is retryable only for recognized transient failure codes.

Do not broaden retryability merely because a dependency failed.

---

# 26. Retry Happens Too Many Times

The runtime tracks:

```text
attempts
retries
maxRetries
```

The execution loop allows:

```text
attempt <= maxRetries
```

with the initial attempt occurring before any retry.

Therefore:

```text
maxRetries = 0
```

means one execution attempt with no retry.

```text
maxRetries = 2
```

means up to three total attempts:

```text
attempt 1
   │
   ├── failure
   ▼
attempt 2
   │
   ├── failure
   ▼
attempt 3
```

If more attempts occur, inspect the retry executor and runtime state.

---

# 27. Retry Backoff Appears Incorrect

The retry executor calculates backoff using:

```text
100ms
200ms
400ms
...
```

with an upper limit of:

```text
1000ms
```

If retry timing appears abnormal, verify:

```text
attempt number
calculateBackoffMs()
```

Do not replace exponential backoff with immediate retries merely to increase throughput.

Immediate retries can amplify dependency failures.

---

# 28. Retry Does Not Recover the Operation

A retry is considered a recovery when:

```text
attempt > 1
```

and the operation eventually succeeds.

The runtime records:

```text
recovered = true
```

and:

```text
registerRecovery()
```

If the operation succeeds after retry but recovery is not reflected in runtime state, inspect:

```text
retry executor
runtime recovery registration
execution result
```

---

# 29. Runtime Reports Failure After Successful Recovery

A correctly recovered operation should not remain in a final failed state merely because an earlier attempt failed.

If this occurs, inspect:

```text
registerFailure()
registerRecovery()
retry loop
final execution result
```

The important distinction is:

```text
transient attempt failure
```

versus:

```text
final operation failure
```

Runtime state should preserve enough information to distinguish these outcomes.

---

# 30. Failure Is Classified as `internal`

The default classification is:

```text
internal
```

when the error does not match a more specific classification rule.

If an expected dependency failure appears as `internal`, determine whether the dependency context was supplied to the classifier.

Infrastructure operations classify failures with:

```text
dependency
```

context.

If classification occurs outside that boundary, the same error may receive a different classification.

---

# 31. Dependency Failure Is Not Retryable

A dependency failure is not automatically transient.

The classifier checks recognized transient codes such as:

```text
ECONNRESET
ECONNREFUSED
EHOSTUNREACH
ENETUNREACH
EADDRNOTAVAIL
ETIMEDOUT
RUNTIME_TIMEOUT
```

If the actual error code is not recognized, the dependency failure may be:

```text
recoverable: false
retryable: false
```

Do not add a new transient code without establishing that it represents a retry-safe condition.

---

# 32. Authentication or Authorization Failures Are Retried

Authentication and authorization failures are explicitly classified as non-retryable.

```text
401 → authentication
403 → authorization
```

These failures normally represent a deterministic condition rather than a transient dependency problem.

If retries occur for these errors, investigate whether:

```text
error classification
dependency context
retry policy
```

is being incorrectly applied.

---

# 33. Validation Errors Are Retried

HTTP 4xx errors other than the explicit authentication and authorization cases are classified as:

```text
validation
```

and are not retryable.

If such failures are retried, inspect the error object and classification path.

Do not solve this by increasing the maximum retry count.

---

# 34. Failure Is Registered More Than Once

The runtime intentionally avoids replacing an already registered failure.

If:

```text
runtime.hasFailure()
```

is already true, subsequent failure registration should not replace the original runtime failure.

This is important because an execution may traverse:

```text
infrastructure failure
      │
      ▼
application catch
      │
      ▼
runtime failure handler
```

The first meaningful runtime failure should remain available for diagnosis.

---

# 35. Runtime Failure Handler Is Not Executed

For API requests, the runtime failure handler is part of the Express error-handling path.

If an unhandled error reaches the application but does not produce the expected runtime failure behavior, inspect middleware ordering.

The handler must remain after the route handlers that can propagate errors.

Conceptually:

```text
Routes
  │
  ▼
runtimeFailureHandler
```

Do not register it as ordinary middleware.

Its Express signature is intentionally:

```text
(error, req, res, next)
```

---

# 36. Runtime Failure Handler Returns the Wrong Status

Runtime timeout errors are mapped to:

```text
504
```

Other errors use:

```text
error.statusCode
```

or:

```text
error.status
```

with:

```text
500
```

as the fallback.

If the returned status is unexpected, inspect the error object before modifying the handler.

The goal is to determine whether the status originates from:

```text
application error
runtime timeout
dependency error
default runtime handling
```

---

# 37. Headers Were Already Sent

The runtime failure handler checks:

```text
res.headersSent
```

If headers have already been sent, it delegates to:

```text
next(error)
```

This prevents the runtime from attempting to send a second HTTP response.

If this occurs frequently, investigate:

```text
response lifecycle
async error propagation
duplicate response handling
route behavior
```

Do not simply remove the `headersSent` check.

---

# 38. Runtime Error Response Is Missing Request ID

API runtime failures should expose the request ID when available.

If it is missing, inspect:

```text
runtime initialization
runtime identity
runtime attachment
failure handler access
```

A missing request ID reduces incident correlation quality.

---

# 39. Runtime Integrity Identity Mismatch

The runtime guard stores immutable integrity references:

```text
runtime
executionId
requestId
```

It later verifies that these values still correspond to the current runtime.

If the error is:

```text
Runtime Contract Violation: Execution identity mismatch.
```

or:

```text
Runtime Contract Violation: Request identity mismatch.
```

investigate code that mutates or replaces runtime identity.

Runtime identity should be treated as execution metadata, not application state.

---

# 40. Runtime Object Was Replaced

The guard verifies:

```text
Object.is(runtime, req.runtimeIntegrity.runtime)
```

A failure indicates that:

```text
req.runtime
```

is no longer the same runtime object created during initialization.

Potential causes include:

```text
middleware mutation
test fixture mutation
application middleware replacement
incorrect request context handling
```

Do not solve this by updating `runtimeIntegrity` after the replacement.

That would defeat the integrity mechanism.

---

# 41. Operation Metadata Is Missing

Operation metadata can describe:

```text
requiresDatabase
requiresStorage
asynchronous
```

If runtime behavior depends on these characteristics but they are missing, inspect the operation definition attached to the route or execution.

For example, `ID_UPLOAD` explicitly declares:

```text
requiresDatabase: true
requiresStorage: true
asynchronous: true
```

If runtime or future reliability logic relies on these characteristics, they must remain accurate.

---

# 42. Infrastructure Metrics Are Missing

The infrastructure boundary records runtime metrics including:

```text
runtimeOperationsTotal
runtimeRetriesTotal
runtimeFailuresTotal
runtimeOperationDurationSeconds
```

If logs show infrastructure execution but metrics do not reflect it, investigate:

```text
metric registration
registry
metric labels
execution path
metric endpoint
Prometheus scraping
```

Separate:

```text
metric not generated
```

from:

```text
metric generated but not scraped
```

These are different failure domains.

---

# 43. Runtime Metrics Cause Errors

Runtime metrics use labels such as:

```text
operation
dependency
outcome
failure_type
recoverable
```

If metric calls produce errors, inspect label completeness and consistency.

Every invocation must provide the labels expected by the metric definition.

Do not introduce high-cardinality values such as:

```text
request_id
execution_id
user_id
error_message
```

as metric labels.

These belong in logs and runtime context, not metric dimensions.

---

# 44. Runtime Logs Are Missing

Runtime logs are emitted through the application's structured logger.

Important runtime events include:

```text
runtime_operation_started
runtime_operation_retry
runtime_operation_completed
runtime_operation_failed
runtime_failure_handled
runtime_completed
```

If application execution succeeds but runtime logs are absent, determine whether:

```text
runtime path was actually used
logger was invoked
container stdout is available
Promtail is collecting logs
Loki is receiving logs
```

Do not assume a logging failure is a runtime execution failure.

---

# 45. Runtime Logs Exist but Cannot Be Correlated

Correlation should primarily use:

```text
request_id
execution_id
operation_id
```

For dependency operations, logs also include:

```text
dependency
```

If correlation is incomplete, inspect the context-building path.

Avoid adding arbitrary correlation identifiers independently in each application layer.

The runtime should remain the authoritative execution identity.

---

# 46. Runtime Metadata Is Incorrect

The API runtime bootstrap enriches runtime metadata with request information including:

```text
method
path
originalUrl
protocol
hostname
ip
```

If this metadata is incorrect, determine whether the issue occurs:

```text
before metadata collection
during metadata attachment
during request mutation
during logging
```

Do not duplicate metadata generation in every downstream component.

---

# 47. User Context Is Missing

The runtime execution context supports user information:

```text
user.id
```

If an authenticated operation is expected to carry user context but it is absent, inspect the authentication flow and runtime context attachment.

This should be distinguished from:

```text
runtime identity
```

because user identity and execution identity have different responsibilities.

---

# 48. ID Upload Runtime Failures

The ID upload path combines several dependencies:

```text
HTTP request
   │
   ▼
authentication
   │
   ▼
storage
   │
   ▼
PostgreSQL
   │
   ▼
Redis
   │
   ▼
background processing
```

The operation uses a reliability policy with:

```text
timeout: 10000ms
retry: true
maxRetries: 2
recoverable: true
```

If upload failures occur, identify the failing dependency before changing runtime policy.

Possible failure boundaries include:

```text
MinIO
PostgreSQL
Redis
```

---

# 49. Upload Retry Creates Unexpected Side Effects

Retries are safe only when the retried operation is safe to repeat.

This is particularly important for operations that:

```text
upload data
write database state
enqueue jobs
```

A runtime retry does not automatically make an operation idempotent.

If an operation can produce duplicate side effects, investigate idempotency requirements before increasing retries.

The distinction is:

```text
retryable failure
```

versus:

```text
safe-to-repeat operation
```

They are related but not identical.

---

# 50. Database Operation Repeated After Timeout

A database operation may exceed the runtime timeout while the underlying database operation has not necessarily stopped.

A retry can therefore create:

```text
attempt 1 still executing
       │
       └── runtime timeout
              │
              ▼
          attempt 2
```

This is an important operational risk.

Before enabling aggressive retries around slow operations, evaluate:

```text
operation cancellation
idempotency
database transaction behavior
duplicate side effects
connection behavior
```

---

# 51. Redis Operation Repeated After Timeout

The same principle applies to Redis-backed operations.

If a runtime timeout occurs, determine whether the underlying operation may still be executing before allowing repeated attempts.

For queue operations, investigate:

```text
duplicate enqueue
job identity
queue semantics
BullMQ behavior
```

Do not assume that a runtime retry automatically guarantees exactly-once behavior.

---

# 52. Runtime Failure Differs Between API and Worker

API and Worker use the same architectural runtime model but operate under different execution semantics.

API execution is generally:

```text
request
→ operation
→ response
→ completion
```

Worker execution is generally:

```text
job
→ operation
→ processing
→ completion / failure
```

Therefore, troubleshooting should preserve the shared runtime principles while respecting component-specific lifecycle behavior.

Do not force HTTP assumptions onto Worker execution.

---

# 53. Worker Runtime Appears Healthy but Jobs Fail

Separate:

```text
Worker process health
```

from:

```text
job execution health
```

A Worker can remain running while individual jobs fail.

Investigate:

```text
job failure metrics
job duration
queue depth
runtime failure classification
dependency failures
Worker logs
```

The runtime failure of one job does not necessarily imply Worker process failure.

---

# 54. Worker Runtime Retry Loop

For Worker operations, determine:

```text
job identity
attempt
configured policy
failure classification
retry count
final outcome
```

Do not confuse:

```text
runtime retry
```

with:

```text
BullMQ job retry
```

They operate at different architectural layers.

When both exist, establish which layer performed the retry.

---

# 55. Runtime Retry vs Queue Retry

A Worker may have reliability mechanisms at more than one level:

```text
Queue / BullMQ
       │
       ▼
Worker Runtime
       │
       ▼
Business Operation
```

A failure can therefore potentially be retried by:

```text
runtime
```

and later:

```text
queue mechanism
```

This must be considered carefully because combined retries can multiply attempts.

Before changing retry policy, determine which retry layer is responsible for the observed behavior.

---

# 56. Runtime Failure Is Correct but Application Handles It Incorrectly

A runtime can correctly classify and propagate a failure while application code catches it and returns an inappropriate response.

Example:

```text
Dependency failure
      │
      ▼
Runtime classifies failure
      │
      ▼
Application catches error
      │
      ▼
Application returns generic response
```

When this occurs, inspect both:

```text
runtime behavior
```

and:

```text
application error handling
```

Do not automatically modify runtime classification when the actual issue is response handling.

---

# 57. Runtime Error Is Swallowed

A runtime-controlled operation should preserve failure propagation when the operation cannot recover.

If application code does:

```text
catch(error)
   → log
   → continue
```

the runtime may never receive the actual failure.

This can produce misleading observability:

```text
application encountered failure
```

but:

```text
runtime reports success
```

When runtime success conflicts with application logs, inspect error propagation.

---

# 58. Runtime Reports Failure but Application Continues

The reverse condition can also occur.

If runtime registers a failure but application code continues execution as though the operation succeeded, investigate the contract between:

```text
runtime failure state
```

and:

```text
application control flow
```

Runtime failure state is diagnostic and reliability state; application control flow still needs explicit error handling.

Do not assume that registering a failure automatically interrupts JavaScript execution.

---

# 59. Runtime Snapshot Appears Incomplete

The runtime snapshot contains information about:

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

If an expected field is missing, determine whether:

```text
field was never attached
```

or:

```text
field was attached after snapshot generation
```

or:

```text
snapshot intentionally exposes a reduced representation
```

Do not modify the snapshot merely to duplicate data already available through runtime interfaces.

---

# 60. Reliability Counters Are Inconsistent

The runtime tracks:

```text
attempts
retries
recovered
lastFailureType
lastDependency
```

The expected relationship is:

```text
attempts >= 1
retries <= attempts - 1
```

for an executed infrastructure operation.

For example:

```text
1 attempt
0 retries
```

or:

```text
3 attempts
2 retries
recovered = true
```

If these values are inconsistent, inspect:

```text
retry loop
registerReliabilityAttempt()
registerRetry()
registerRecovery()
```

---

# 61. Runtime Timeout Is Classified as Internal

Timeouts should be recognized through:

```text
RuntimeTimeoutError
```

or:

```text
RUNTIME_TIMEOUT
```

If a runtime timeout appears as:

```text
internal
```

inspect:

```text
error.name
error.code
classifier invocation
```

Do not add ad hoc timeout detection at every application layer.

---

# 62. Runtime Policy Has No Timeout

A policy may explicitly use:

```text
timeout = null
```

In that case the runtime does not impose a timeout through `runWithTimeout()`.

This is different from:

```text
timeout configuration missing accidentally
```

Before changing the policy, establish whether the operation is intentionally designed without a runtime timeout.

---

# 63. Runtime Policy Has an Unexpected Timeout

When an operation times out unexpectedly, verify:

```text
operation ID
resolved policy ID
timeout value
execution path
```

Do not infer the policy from the operation name alone.

The runtime resolves policies by operation identity.

---

# 64. Runtime Reliability Is Disabled

If:

```text
isReliabilityActivated()
```

is false during an operation that should be runtime-controlled, inspect:

```text
runtimeStateActivation
policy attachment
middleware ordering
```

A reliability policy being attached is not the same as reliability being activated.

The expected transition is:

```text
policy attached
      │
      ▼
activateReliability()
      │
      ▼
reliability activated
      │
      ▼
runtime active
```

---

# 65. Runtime Operation Starts but Never Completes

If a runtime operation has:

```text
runtime_operation_started
```

but no corresponding:

```text
runtime_operation_completed
```

or:

```text
runtime_operation_failed
```

investigate:

```text
hung dependency
timeout behavior
uncaught asynchronous execution
process termination
logging failure
```

This is especially important when the runtime timeout is expected to provide an upper bound.

---

# 66. Runtime Operation Fails Without Failure Metrics

When an infrastructure operation fails, the runtime should record failure metrics including:

```text
operation
dependency
failure_type
recoverable
```

If logs show:

```text
runtime_operation_failed
```

but metrics do not increase, determine whether the issue is:

```text
metric instrumentation
```

or:

```text
Prometheus collection
```

Use the metrics endpoint and Prometheus target status to separate these cases.

---

# 67. Runtime Operation Duration Is Missing

Runtime operation duration is measured through:

```text
runtimeOperationDurationSeconds
```

If duration data is absent, inspect whether:

```text
startTimer()
```

was invoked and whether the timer was observed on:

```text
success
failure
```

Duration measurement should cover both successful and failed operations.

---

# 68. Runtime Logs Show the Wrong Operation

If:

```text
operation_id
```

is unexpected, inspect operation attachment rather than changing the logger.

The operation ID originates from:

```text
runtime.getOperation()
```

The correct diagnostic path is:

```text
route/job
   │
   ▼
operation definition
   │
   ▼
operation context
   │
   ▼
runtime attachment
   │
   ▼
runtime logs
```

---

# 69. Runtime Failure Has No Dependency

A failure may legitimately have:

```text
dependency = null
```

if it did not originate from an infrastructure dependency boundary.

Do not force every runtime failure into a dependency category.

For dependency-related failures, verify that the failure was classified with dependency context.

---

# 70. Runtime Recovery Is Not Possible

A failure may be technically recoverable in theory but not recoverable under the current runtime policy.

The runtime recovery decision depends on:

```text
runtime failure
policy recoverability
failure classification recoverability
```

The effective condition is represented by:

```text
canRecover()
```

Do not equate:

```text
failure classification says recoverable
```

with:

```text
runtime will definitely retry
```

Policy and execution conditions still matter.

---

# 71. Runtime Failure Classification and Policy Disagree

Example:

```text
classification:
  retryable = true
```

while:

```text
policy:
  retry = false
```

The result is:

```text
no retry
```

This is intentional policy enforcement.

Troubleshooting should therefore inspect both dimensions:

```text
Failure classification
        +
Reliability policy
        =
Runtime decision
```

---

# 72. Runtime Troubleshooting With Prometheus

Use Prometheus to determine whether the problem is isolated or systemic.

Useful runtime metrics include:

```text
runtime operation count
runtime retry count
runtime failure count
runtime operation duration
```

Correlate them with:

```text
API request metrics
Worker job metrics
dependency metrics
host metrics
```

The objective is to answer:

```text
Is runtime failure increasing?
Which operation?
Which dependency?
Which failure type?
Is recovery succeeding?
Is latency increasing?
```

---

# 73. Runtime Troubleshooting With Loki

Runtime logs provide execution-level context.

Search by:

```text
request_id
execution_id
operation_id
dependency
failure_type
```

A useful investigation sequence is:

```text
runtime_operation_started
        │
        ▼
runtime_operation_retry
        │
        ▼
runtime_operation_completed
```

or:

```text
runtime_operation_started
        │
        ▼
runtime_operation_failed
        │
        ▼
runtime_failure_handled
```

This allows the execution path to be reconstructed.

---

# 74. Runtime Troubleshooting Workflow

Use the following sequence:

```text
1. Identify execution
        │
        ▼
2. Identify operation
        │
        ▼
3. Identify runtime state
        │
        ▼
4. Identify policy
        │
        ▼
5. Identify dependency
        │
        ▼
6. Inspect failure classification
        │
        ▼
7. Inspect retry behavior
        │
        ▼
8. Inspect recovery
        │
        ▼
9. Inspect final state
        │
        ▼
10. Correlate metrics and logs
```

This prevents troubleshooting from becoming trial-and-error configuration changes.

---

# 75. Runtime Diagnostic Matrix

| Symptom                     | First Investigation                       |
| --------------------------- | ----------------------------------------- |
| Runtime missing             | Middleware initialization/order           |
| Invalid runtime state       | Lifecycle transition                      |
| Identity mismatch           | Runtime mutation/integrity                |
| Operation missing           | Operation resolution                      |
| Policy missing              | Policy resolver                           |
| Wrong timeout               | Operation → policy mapping                |
| No retry                    | Policy + failure classification           |
| Too many retries            | Retry executor + maxRetries               |
| Wrong retry                 | Failure classification                    |
| Timeout                     | Dependency duration + timeout policy      |
| Failure classified internal | Error + classifier context                |
| Failure not propagated      | Application error handling                |
| Failure registered twice    | Runtime failure lifecycle                 |
| Missing runtime metrics     | Instrumentation vs Prometheus             |
| Missing runtime logs        | Logger vs log pipeline                    |
| Missing completion          | Async execution / timeout / process state |
| API 504                     | Runtime timeout                           |
| Worker job repeatedly fails | Job retry vs runtime retry                |
| Recovery not recorded       | Retry executor + runtime state            |

---

# 76. Runtime Incident Evidence

For a runtime incident, capture:

```text
Component:
Execution ID:
Request ID / Job ID:
Operation:
Policy:
Runtime State:
Dependency:
Failure Type:
Error Code:
Timeout:
Attempts:
Retries:
Recovered:
Start Time:
Failure Time:
Completion Time:
Relevant Metrics:
Relevant Logs:
Deployment Version:
```

Never include secret values.

---

# 77. Runtime Recovery Decision Tree

```text
Runtime failure
      │
      ▼
Is failure classified?
      │
   ┌──┴──┐
  No     Yes
  │       │
classify  ▼
        Is retry enabled?
             │
          ┌──┴──┐
         No     Yes
         │       │
         ▼       ▼
      propagate  Is failure retryable?
                     │
                  ┌──┴──┐
                 No     Yes
                 │       │
                 ▼       ▼
              propagate  Attempts remain?
                            │
                         ┌──┴──┐
                        No     Yes
                        │       │
                        ▼       ▼
                     propagate retry
                              │
                              ▼
                         success?
                          │    │
                         No   Yes
                         │     │
                         ▼     ▼
                      failure recovered
```

---

# 78. Runtime Troubleshooting Anti-Patterns

## 78.1 Disable Runtime Guard

Do not disable runtime integrity validation to make an execution continue.

---

## 78.2 Increase Retries Immediately

More retries do not fix:

```text
validation failures
authentication failures
authorization failures
non-idempotent operations
persistent dependency failures
```

---

## 78.3 Increase Timeout Without Diagnosis

A timeout may be protecting the system from:

```text
hung dependency
resource exhaustion
unbounded execution
```

Increasing it blindly can increase resource consumption.

---

## 78.4 Catch and Ignore Runtime Errors

Swallowing errors can make runtime observability report a false success.

---

## 78.5 Treat Every Dependency Failure as Retryable

Retryability is a classification decision, not a generic property of dependencies.

---

## 78.6 Confuse Runtime Retry With Queue Retry

For Worker execution, determine which layer performed the retry before modifying either mechanism.

---

## 78.7 Add High-Cardinality Runtime Labels

Do not put:

```text
request_id
execution_id
job_id
user_id
error_message
```

into Prometheus labels.

Use structured logs for execution-level identity.

---

# 79. Runtime Issue Closure Criteria

A runtime issue is considered resolved only when:

```text
[ ] Failure cause identified
[ ] Runtime invariant restored
[ ] Correct operation resolved
[ ] Correct reliability policy confirmed
[ ] Failure classification verified
[ ] Retry behavior verified
[ ] Recovery behavior verified
[ ] Final runtime state verified
[ ] Metrics verified
[ ] Logs verified
[ ] Application behavior verified
[ ] No hidden failure remains
```

For Worker issues additionally verify:

```text
[ ] Job processing resumed
[ ] Queue behavior is normal
[ ] Runtime retry and queue retry are understood
```

For API issues additionally verify:

```text
[ ] HTTP response behavior is correct
[ ] Liveness passes
[ ] Readiness passes
[ ] Request correlation is available
```

---

# 80. Final Runtime Principle

Runtime troubleshooting should preserve the distinction between:

```text
Application Failure
Dependency Failure
Runtime Failure
Infrastructure Failure
Observability Failure
```

These layers interact but are not interchangeable.

The correct diagnostic model is:

```text
Application Operation
        │
        ▼
Runtime Context
        │
        ▼
Reliability Policy
        │
        ▼
Infrastructure Boundary
        │
        ▼
Dependency
        │
        ▼
Failure Classification
        │
        ▼
Retry / Recovery Decision
        │
        ▼
Runtime Outcome
        │
        ▼
Observability
```

The fundamental operational rule is:

> **Do not change runtime reliability behavior until the failing execution path, operation, policy, dependency, failure classification, and recovery decision have been established from evidence.**

A healthy runtime is not one that never encounters failures.

A healthy runtime is one that:

```text
detects failure
      ↓
classifies it
      ↓
applies the correct policy
      ↓
recovers when safe
      ↓
propagates when recovery is not possible
      ↓
records the execution
      ↓
leaves the system in a known state
```

That behavior is the basis for diagnosing runtime failures without introducing secondary reliability problems.

```
```
