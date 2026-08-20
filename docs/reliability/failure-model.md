# Failure Model

## 1. Purpose

This document defines the Failure Model used by the Mini-Write platform to reason about, classify, detect, contain, and recover from failures.

The Failure Model is a foundational part of the Reliability architecture.

It answers:

- What can fail?
- Where can it fail?
- What type of failure is it?
- How does the failure propagate?
- How can the failure be detected?
- Who owns the failure boundary?
- Is the failure recoverable?
- Should the operation be retried?
- What evidence should be produced?
- What happens when recovery is not possible?

The model prevents failure handling from becoming a collection of unrelated `try/catch` blocks, restart policies, alerts, and ad-hoc recovery procedures.

---

# 2. Failure Engineering Philosophy

Mini-Write treats failure as an expected property of a distributed system.

The system consists of multiple independently behaving components:

```text
API
Worker
PostgreSQL
Redis
MinIO
Docker
Host
Observability Stack
Deployment System
````

Any of these components can fail independently.

Therefore:

```text
Reliability
    ≠
Assuming components remain healthy
```

Instead:

```text
Reliability
    =
Understanding Failure
    +
Detecting Failure
    +
Containing Failure
    +
Handling Failure
    +
Recovering When Possible
```

---

# 3. Failure Lifecycle

Every important failure should be understandable through the following lifecycle:

```text
Failure
   │
   ▼
Taxonomy
   │
   ▼
Inventory
   │
   ▼
Classification
   │
   ▼
Boundary
   │
   ▼
Propagation
   │
   ▼
Detection
   │
   ▼
Handling
   │
   ▼
Recovery
   │
   ▼
Verification
   │
   ▼
Learning
```

Each stage answers a different engineering question.

---

# 4. Failure Model Architecture

The Failure Model is composed of several dimensions:

```text
Failure
  │
  ├── Origin
  ├── Duration
  ├── Scope
  ├── Operational Impact
  ├── Recoverability
  ├── Visibility
  ├── Predictability
  ├── Ownership
  ├── Architectural Layer
  └── Architectural Boundary
```

These dimensions should not be confused with the Runtime's operational `FAILURE_TYPES`.

`FAILURE_TYPES` classify the operational nature of a failure.

The Failure Model provides the broader architectural reasoning required to understand the failure.

---

# 5. Failure Taxonomy

The current Runtime failure taxonomy contains:

```text
TIMEOUT
DEPENDENCY
VALIDATION
AUTHENTICATION
AUTHORIZATION
INTERNAL
```

These represent the primary operational failure categories currently implemented by the Runtime.

---

## 5.1 TIMEOUT

A `TIMEOUT` occurs when an operation exceeds its configured execution boundary.

Example:

```text
API
 │
 ▼
PostgreSQL operation
 │
 ├── operation does not complete
 │
 ▼
Runtime timeout
```

The Runtime creates:

```text
RuntimeTimeoutError
```

with:

```text
name = RuntimeTimeoutError
code = RUNTIME_TIMEOUT
```

The current classifier marks timeout as:

```text
recoverable = true
retryable = true
```

subject to the operation's reliability policy.

---

## 5.2 DEPENDENCY

A `DEPENDENCY` failure occurs while interacting with an infrastructure dependency.

Current dependencies are:

```text
PostgreSQL
Redis
MinIO
```

Examples:

```text
PostgreSQL connection refused
Redis unavailable
MinIO unreachable
Network connection reset
Dependency operation timeout
```

Dependency failures are classified according to the underlying error characteristics.

Transient dependency failures can be retryable.

---

## 5.3 VALIDATION

A `VALIDATION` failure represents an invalid client request or operation input.

Examples include:

```text
Missing required fields
Invalid request data
Unsupported operation input
Invalid upload request
```

Validation failures are not normally recoverable through retry.

The current classifier therefore marks them as:

```text
recoverable = false
retryable = false
```

---

## 5.4 AUTHENTICATION

An `AUTHENTICATION` failure means the caller could not be authenticated.

Typical example:

```text
Invalid credentials
```

Authentication failures should not be retried by the Runtime as infrastructure failures.

Current classification:

```text
recoverable = false
retryable = false
```

---

## 5.5 AUTHORIZATION

An `AUTHORIZATION` failure occurs when an authenticated caller does not have permission to perform the requested operation.

Current classification:

```text
recoverable = false
retryable = false
```

Retrying the same authorization decision without a state change does not normally resolve the problem.

---

## 5.6 INTERNAL

`INTERNAL` is the fallback category for unexpected failures that do not match the more specific categories.

Examples may include:

```text
Unexpected application exception
Programming defect
Unexpected runtime condition
Unhandled internal failure
```

Current classification:

```text
recoverable = false
retryable = false
```

This conservative behavior prevents unknown failures from being blindly retried.

---

# 6. Failure Classification Rules

The Runtime classifier evaluates failures in an explicit order.

Conceptually:

```text
Error
 │
 ├── Runtime timeout?
 │       └── TIMEOUT
 │
 ├── Dependency context?
 │       └── DEPENDENCY
 │
 ├── HTTP 401?
 │       └── AUTHENTICATION
 │
 ├── HTTP 403?
 │       └── AUTHORIZATION
 │
 ├── HTTP 4xx?
 │       └── VALIDATION
 │
 └── Otherwise
         └── INTERNAL
```

The classification is then enriched with:

```text
recoverable
retryable
```

---

# 7. Transient Failure Codes

The Runtime currently recognizes the following error codes as transient candidates:

```text
ECONNRESET
ECONNREFUSED
EHOSTUNREACH
ENETUNREACH
EADDRNOTAVAIL
ETIMEDOUT
RUNTIME_TIMEOUT
```

These codes represent conditions where retry may plausibly succeed.

The presence of a transient error code does not automatically mean that retry must occur.

Retry still depends on:

```text
Operation Policy
+
Runtime Recoverability
+
Maximum Retry Count
+
Failure Classification
```

---

# 8. Retryability vs Recoverability

These concepts are intentionally separate.

## Retryable

Means:

> Repeating the operation may succeed.

## Recoverable

Means:

> The overall execution may be brought back to an acceptable state.

A failure can therefore be:

```text
retryable = true
recoverable = true
```

or:

```text
retryable = false
recoverable = false
```

The architecture should not assume that the two properties are always equivalent.

---

# 9. Failure Dimensions

The Runtime classification is only one part of the broader Failure Model.

Each failure should be understood through multiple dimensions.

---

## 9.1 Origin

Origin describes where the failure originates.

Possible origins include:

```text
Application
Runtime
Dependency
Infrastructure
Deployment
Configuration
Environment
External System
Operator Action
```

Example:

```text
PostgreSQL unavailable
```

has:

```text
origin = dependency
```

while:

```text
Invalid Runtime state transition
```

has:

```text
origin = runtime
```

---

## 9.2 Duration

Failures can be classified by duration.

```text
Transient
Intermittent
Persistent
Permanent
```

### Transient

Short-lived failure likely to disappear.

Example:

```text
temporary network interruption
```

### Intermittent

Failure repeatedly appears and disappears.

Example:

```text
unstable dependency connectivity
```

### Persistent

Failure remains until an intervention occurs.

Example:

```text
service continuously unavailable
```

### Permanent

Failure cannot be resolved without changing the underlying condition.

Example:

```text
invalid configuration
```

---

# 10. Failure Scope

Scope describes how much of the system is affected.

```text
Operation
Request
Component
Service
Workflow
Dependency
Host
Platform
```

Example:

```text
One PostgreSQL query
```

has a narrower scope than:

```text
PostgreSQL unavailable
```

which has a narrower scope than:

```text
Host unavailable
```

Understanding scope is essential for containment.

---

# 11. Operational Impact

Failure impact can be understood as:

```text
No Impact
Degraded
Partial Outage
Major Outage
Critical Outage
```

Examples:

### No Impact

A transient failure is successfully recovered before affecting the user.

### Degraded

API requests remain available but latency increases.

### Partial Outage

A subset of operations becomes unavailable.

### Major Outage

A major service capability becomes unavailable.

### Critical Outage

The platform or essential operational capability becomes unavailable.

---

# 12. Recoverability

Recoverability describes whether the system can return to an acceptable state.

Possible states:

```text
Automatically Recoverable
Operationally Recoverable
Manually Recoverable
Non-Recoverable
```

---

## 12.1 Automatically Recoverable

Example:

```text
Transient dependency failure
       │
       ▼
Retry
       │
       ▼
Success
```

No operator intervention is required.

---

## 12.2 Operationally Recoverable

The system can recover using established operational procedures.

Example:

```text
Container failure
       │
       ▼
Restart container
       │
       ▼
Health verification
```

---

## 12.3 Manually Recoverable

An operator must investigate and perform corrective action.

Example:

```text
Configuration regression
       │
       ▼
Identify cause
       │
       ▼
Correct configuration
       │
       ▼
Redeploy
```

---

## 12.4 Non-Recoverable

The affected execution cannot be recovered in its current form.

Example:

```text
Invalid user request
```

The correct behavior is to terminate the operation and return an appropriate failure.

---

# 13. Failure Visibility

Failures can have different levels of visibility.

```text
Explicit
Observable
Partially Observable
Hidden
```

A failure that produces:

```text
metric
+
structured log
+
alert
```

has high operational visibility.

A failure that silently changes behavior without producing evidence is operationally dangerous.

---

# 14. Predictability

Failures may be:

```text
Expected
Predictable
Unpredictable
Unknown
```

Examples:

```text
Expected:
Dependency unavailable during maintenance

Predictable:
Disk space approaching exhaustion

Unpredictable:
Unexpected application exception
```

Predictability influences whether preventive mechanisms can be introduced.

---

# 15. Ownership

Every important failure should have an identifiable owner.

Ownership can correspond to:

```text
Application
Runtime
Infrastructure
Deployment
Observability
Operations
External Dependency
```

Example:

```text
API code defect
→ Application ownership
```

while:

```text
Node Exporter unavailable
→ Observability / Infrastructure ownership
```

Ownership prevents failures from becoming organizationally ambiguous.

---

# 16. Architectural Layer

Failure location should also be identified by architectural layer.

```text
Application
Runtime
Workflow
Deployment
Infrastructure
Platform
Observability
```

This is distinct from ownership.

A failure may originate in one layer but become visible in another.

Example:

```text
PostgreSQL
   │
   ▼
Infrastructure failure
   │
   ▼
Runtime dependency failure
   │
   ▼
Application request failure
   │
   ▼
HTTP error metric
   │
   ▼
Alert
```

---

# 17. Failure Boundary Model

Mini-Write defines five primary failure boundaries:

```text
Component
Runtime
Workflow
Deployment
Platform
```

---

# 18. Component Boundary

The Component Boundary isolates failures inside an individual component.

Examples:

```text
API
Worker
PostgreSQL
Redis
MinIO
```

Responsibilities include:

```text
Local failure detection
Local state management
Local error reporting
```

The component should avoid leaking implementation-specific failures unnecessarily into unrelated components.

---

# 19. Runtime Boundary

The Runtime Boundary surrounds an individual execution.

It provides:

```text
Execution Identity
Operation Context
Reliability Policy
Failure Classification
Timeout
Retry
Recovery State
```

The Runtime therefore becomes the primary boundary for application-level execution reliability.

---

# 20. Workflow Boundary

The Workflow Boundary covers multi-step operations.

For example, the API ID upload workflow is approximately:

```text
Receive upload
     │
     ▼
Store file in MinIO
     │
     ▼
Update PostgreSQL
     │
     ▼
Enqueue Redis job
     │
     ▼
Return response
```

This workflow crosses multiple dependencies.

A failure in one step can affect the overall workflow.

Therefore workflow-level reasoning must distinguish:

```text
Step Failure
```

from:

```text
Workflow Failure
```

---

# 21. Deployment Boundary

The Deployment Boundary covers changes introduced by deployment.

Examples:

```text
New API image
New Worker image
Configuration change
Infrastructure change
Observability configuration change
```

A deployment failure can occur even when the application itself is correct.

Example:

```text
Valid API image
+
Invalid environment configuration
=
Deployment failure
```

---

# 22. Platform Boundary

The Platform Boundary is the highest operational boundary.

It includes:

```text
Host
Docker runtime
Networking
Storage
Operating system
Security controls
```

Platform failure can affect multiple services simultaneously.

Example:

```text
Host failure
   │
   ├── API unavailable
   ├── Worker unavailable
   ├── Prometheus unavailable
   └── Loki unavailable
```

This is a fundamentally different failure class from a single API exception.

---

# 23. Failure Propagation Model

Failure propagation describes how an initial failure can move through system boundaries.

The general model is:

```text
Failure Origin
      │
      ▼
Affected Component
      │
      ▼
Runtime / Workflow
      │
      ▼
Dependent Component
      │
      ▼
User / Operator Impact
```

The objective of reliability engineering is to stop propagation at the narrowest practical boundary.

---

# 24. Example: PostgreSQL Failure

Consider PostgreSQL becoming unavailable.

```text
PostgreSQL
    │
    ▼
Database Operation
    │
    ▼
Runtime Infrastructure Boundary
    │
    ▼
Dependency Failure
    │
    ▼
Application Operation
    │
    ▼
HTTP Failure
```

The failure should not automatically become:

```text
Host Failure
```

unless PostgreSQL failure is actually caused by a host-level failure.

The distinction is important for diagnosis.

---

# 25. Example: Redis Failure

Redis serves multiple roles in the platform.

A Redis failure can affect:

```text
API job enqueueing
Worker queue consumption
Background processing
```

Therefore:

```text
Redis Failure
      │
      ├── API impact
      │
      └── Worker impact
```

This demonstrates why dependency failures must be analyzed in terms of propagation rather than only local error messages.

---

# 26. Example: MinIO Failure

MinIO participates in ID upload and background processing workflows.

A MinIO failure may produce:

```text
Upload failure
```

and potentially:

```text
Worker processing failure
```

The same dependency failure can therefore affect multiple services through different workflows.

---

# 27. Example: Host Failure

A host-level failure is much broader:

```text
Host Failure
    │
    ├── Docker unavailable
    │      │
    │      ├── API unavailable
    │      ├── Worker unavailable
    │      ├── PostgreSQL unavailable
    │      ├── Redis unavailable
    │      ├── MinIO unavailable
    │      └── Observability unavailable
    │
    └── Monitoring visibility degraded
```

This is why infrastructure-level signals are necessary.

---

# 28. Failure Containment

Containment aims to prevent failure propagation from crossing unnecessary boundaries.

The conceptual rule is:

```text
Detect failure
      │
      ▼
Identify boundary
      │
      ▼
Contain locally
      │
      ▼
Propagate only necessary information
```

For example, a transient PostgreSQL connection failure should not crash unrelated services.

---

# 29. Failure Handling Categories

The Reliability architecture uses the following conceptual handling categories:

```text
Contain
Abort
Isolate
Observe
Escalate
Recover
Declare Incident
```

These are decisions rather than implementation mechanisms.

---

# 30. Contain

Containment limits the impact of a failure.

Examples:

```text
Bounded retry count
Timeout
Resource limits
Network isolation
```

The objective is:

```text
Failure
→ Controlled Scope
```

rather than:

```text
Failure
→ Unbounded Propagation
```

---

# 31. Abort

Abort terminates an execution when continuing would be unsafe or meaningless.

Examples:

```text
Invalid request
Authentication failure
Authorization failure
Non-recoverable dependency failure
```

Abort is often preferable to continuing with invalid state.

---

# 32. Isolate

Isolation separates the failing component or operation from healthy work.

Examples include:

```text
Container boundaries
Network boundaries
Service boundaries
Runtime execution boundaries
```

Isolation limits blast radius.

---

# 33. Observe

Some failures should primarily produce evidence rather than immediate recovery.

Example:

```text
Unexpected internal exception
```

The correct response may be:

```text
Record
Classify
Expose
Escalate
```

rather than blindly retrying.

---

# 34. Escalate

Escalation occurs when local handling is insufficient.

Example:

```text
Repeated dependency failure
       │
       ▼
Retries exhausted
       │
       ▼
Failure recorded
       │
       ▼
Alert
       │
       ▼
Operator investigation
```

---

# 35. Recover

Recovery attempts to return the system to an acceptable state.

Examples:

```text
Retry
Restart
Rollback
Configuration correction
Dependency restoration
```

Recovery should always be followed by verification.

---

# 36. Declare Incident

A failure becomes an incident when its operational impact requires coordinated investigation or intervention.

Examples:

```text
API unavailable
Worker unavailable
Host unavailable
Persistent database failure
Large-scale queue backlog
```

Not every individual Runtime failure should become an incident.

---

# 37. Detection Architecture

Failure detection follows:

```text
Failure
   │
   ▼
Signal Generation
   │
   ▼
Signal Collection
   │
   ▼
Signal Correlation
   │
   ▼
Failure Identification
   │
   ▼
Classification
   │
   ▼
Detection Decision
```

---

# 38. Signal Sources

Mini-Write uses multiple signal sources.

## Application Metrics

Provide:

```text
Request rate
Error rate
Latency
Business activity
```

## Runtime Metrics

Provide:

```text
Operation count
Retry count
Failure count
Operation duration
```

## Worker Metrics

Provide:

```text
Queue depth
Processed jobs
Job failures
Job retries
Job duration
```

## Host Metrics

Provide:

```text
CPU
Memory
Disk
Host availability
```

## Container Metrics

Provide:

```text
Container resource usage
Container health
Container behavior
```

## Logs

Provide execution-level evidence.

## Alerts

Provide operator notification.

---

# 39. Detection Confidence

A useful reliability principle is:

```text
One Signal
    ≠
Complete Diagnosis
```

For example:

```text
API error rate ↑
```

does not immediately prove:

```text
API code defect
```

It could be:

```text
PostgreSQL failure
Redis failure
MinIO failure
Network problem
Bad deployment
Host resource pressure
```

Therefore diagnosis should correlate multiple signals.

---

# 40. Failure Correlation

Correlation should follow the architecture.

Example:

```text
MWHighAPIErrorRate
        │
        ├── API availability
        ├── Runtime failure metrics
        ├── PostgreSQL health
        ├── Redis health
        ├── MinIO health
        ├── Host CPU
        ├── Host memory
        └── Deployment version
```

This creates a causal investigation path rather than relying on a single alert.

---

# 41. Runtime Failure State

The Runtime stores failure information in:

```text
failure:
  occurred
  error
  classification
```

This allows execution-level state to distinguish:

```text
successful execution
```

from:

```text
failed execution
```

without relying solely on HTTP status codes.

---

# 42. Failure Snapshot

The Runtime exposes a failure snapshot containing:

```text
occurred
error.message
error.name
error.code
classification
```

This provides a stable diagnostic representation.

Sensitive or unnecessary error internals should not automatically be exposed to clients.

---

# 43. Failure Registration

Failures are registered through the Runtime.

Conceptually:

```text
runtime.registerFailure(
    error,
    classification
)
```

The Runtime preserves the failure state for the execution.

This provides a centralized failure lifecycle.

---

# 44. Infrastructure Failure Handling

Infrastructure operations pass through:

```text
executeInfrastructureOperation()
```

The boundary performs:

```text
Runtime lookup
      │
      ▼
Operation identification
      │
      ▼
Reliability execution
      │
      ├── Timeout
      ├── Retry
      ├── Backoff
      └── Recovery
      │
      ▼
Failure classification
      │
      ▼
Metrics
      │
      ▼
Logs
```

This is the primary implemented failure-handling boundary for API dependency operations.

---

# 45. Failure Metrics

Runtime failure metrics distinguish:

```text
operation
dependency
failure_type
recoverable
```

This makes it possible to ask:

```text
Which operation is failing?

Which dependency is failing?

What type of failure is occurring?

Are failures recoverable?

Are failures increasing?
```

---

# 46. Failure Logs

Runtime failure logs contain operational context such as:

```text
request_id
execution_id
operation_id
dependency
failure_type
recoverable
error_message
error_code
```

This enables a transition from:

```text
Aggregate metric
```

to:

```text
Specific failed execution
```

---

# 47. Failure and HTTP Semantics

Not every internal failure should be exposed directly to clients.

The Runtime failure handler maps internal failures into controlled HTTP responses.

For example:

```text
RuntimeTimeoutError
        │
        ▼
HTTP 504
```

Other unhandled failures generally become:

```text
HTTP 500
```

The response includes the `request_id` where available.

This provides the client with a correlation reference without exposing internal implementation details.

---

# 48. Failure and State Transitions

Runtime state must remain valid even when an operation fails.

The lifecycle remains:

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

A failure does not create an uncontrolled fifth state.

Instead:

```text
ACTIVE
   │
   ▼
Failure
   │
   ▼
COMPLETED
```

The failure is represented separately through the Runtime failure state.

---

# 49. Failure Completion

The Runtime completion observer ensures that an execution is completed when the HTTP response finishes.

If an error occurs before completion, the failure handler can complete the Runtime explicitly.

This provides a consistent terminal state.

The architectural invariant is:

```text
Every initialized execution should eventually reach COMPLETED.
```

---

# 50. Failure and Recovery State

Reliability state tracks:

```text
activated
attempts
retries
lastFailureType
lastDependency
recovered
```

This makes it possible to distinguish:

```text
No failure
```

from:

```text
Failure followed by successful recovery
```

and:

```text
Failure followed by final failure
```

---

# 51. Failure Inventory

The broader Mini-Write failure inventory can be grouped into:

```text
Dependency Failures
Runtime Failures
Workflow Failures
Operational State Inconsistencies
Deployment Failures
Configuration & Environment Failures
```

These families provide a practical inventory structure.

---

# 52. Dependency Failures

Examples:

```text
PostgreSQL unavailable
Redis unavailable
MinIO unavailable
Connection reset
Connection refused
Network unreachable
Dependency timeout
```

Primary concerns:

```text
Detection
Timeout
Retry
Containment
Recovery
```

---

# 53. Runtime Failures

Examples:

```text
Runtime missing
Invalid Runtime state
Runtime identity mismatch
Runtime policy missing
Reliability activation failure
Illegal state transition
```

These are architectural contract violations.

They should not normally be treated as transient dependency failures.

---

# 54. Workflow Failures

Workflow failures occur when a multi-step operation cannot complete correctly.

Example:

```text
ID Upload
   │
   ├── MinIO success
   │
   ├── PostgreSQL success
   │
   └── Redis enqueue failure
```

The workflow is incomplete even though earlier steps succeeded.

This introduces consistency considerations.

---

# 55. Operational State Inconsistencies

Examples include:

```text
Deployment state does not match actual deployment
Service reports healthy but dependency is unavailable
Runtime state does not match expected lifecycle
Queue state does not match worker processing state
```

These failures are particularly dangerous because the system may appear healthy while its internal operational state is inconsistent.

---

# 56. Deployment Failures

Examples:

```text
Invalid image
Broken configuration
Unhealthy new version
Failed deployment
Incomplete rollout
Incorrect deployment state
```

Deployment failures must be analyzed separately from application Runtime failures because they occur across a larger boundary.

---

# 57. Configuration and Environment Failures

Examples:

```text
Missing environment variable
Invalid database configuration
Invalid Redis configuration
Invalid MinIO configuration
Incorrect port
Incorrect network configuration
Incorrect runtime policy
```

These failures are often deterministic.

Blind retry is therefore usually ineffective.

---

# 58. Failure Blast Radius

Every failure should be considered in terms of blast radius.

The conceptual hierarchy is:

```text
Operation
   ↓
Request
   ↓
Component
   ↓
Service
   ↓
Workflow
   ↓
Dependency
   ↓
Host
   ↓
Platform
```

The broader the affected scope, the more significant the operational response.

---

# 59. Blast Radius Example

Consider a single API request failing:

```text
Request
  │
  ▼
Runtime
  │
  ▼
API response
```

Blast radius:

```text
Single execution
```

Now consider PostgreSQL becoming unavailable:

```text
PostgreSQL
   │
   ├── API
   └── Worker
```

Blast radius:

```text
Multiple application capabilities
```

Now consider host failure:

```text
Host
 │
 ├── API
 ├── Worker
 ├── PostgreSQL
 ├── Redis
 ├── MinIO
 └── Observability
```

Blast radius:

```text
Entire platform
```

---

# 60. Failure Containment Principle

A failure should be contained at the smallest boundary capable of handling it.

Therefore:

```text
Request failure
→ Request boundary

Dependency failure
→ Dependency / Runtime boundary

Component failure
→ Component boundary

Deployment failure
→ Deployment boundary

Host failure
→ Platform boundary
```

This principle reduces blast radius.

---

# 61. Retry Decision

Retry should only occur when:

```text
Retry enabled
AND
Retries remain
AND
Runtime is recoverable
AND
Failure is retryable
```

Conceptually:

```text
Policy.retry
      │
      ▼
Runtime.shouldRetry()
      │
      ▼
Failure classification
      │
      ▼
classification.retryable
      │
      ▼
Remaining retries
```

If any required condition is false:

```text
Do not retry.
```

---

# 62. Failure Handling Decision Tree

The complete decision model is:

```text
Failure
   │
   ▼
Classify
   │
   ├── Validation ────────► Abort
   │
   ├── Authentication ───► Abort
   │
   ├── Authorization ────► Abort
   │
   ├── Internal ─────────► Observe + Escalate
   │
   └── Dependency/Timeout
            │
            ▼
       Recoverable?
            │
        ┌───┴───┐
        │       │
       No      Yes
        │       │
        ▼       ▼
      Abort   Retryable?
                │
            ┌───┴───┐
            │       │
           No      Yes
            │       │
            ▼       ▼
          Abort   Retry
                    │
                    ▼
                Recovered?
                  │
             ┌────┴────┐
             │         │
            Yes        No
             │         │
             ▼         ▼
          Record     Exhaust
          Recovery   Retries
                         │
                         ▼
                      Failure
```

---

# 63. Failure Verification

A failure-handling mechanism is not complete until its behavior is verified.

Verification should answer:

```text
Was the failure detected?

Was it classified correctly?

Was the expected policy applied?

Was retry attempted only when appropriate?

Was the failure contained?

Was recovery recorded?

Was the final system state healthy?

Was sufficient evidence produced?
```

---

# 64. Failure Injection

Reliability should be validated using controlled failure injection.

Examples:

```text
Stop PostgreSQL
Stop Redis
Stop MinIO
Block dependency connectivity
Introduce artificial latency
Terminate API
Terminate Worker
Fill disk
Increase CPU pressure
Deploy invalid configuration
```

The objective is not merely to create failures.

The objective is to verify the complete failure lifecycle.

---

# 65. Failure Validation Flow

A failure experiment should follow:

```text
Baseline
   │
   ▼
Inject Failure
   │
   ▼
Observe
   │
   ▼
Classify
   │
   ▼
Verify Handling
   │
   ▼
Verify Recovery
   │
   ▼
Verify Observability
   │
   ▼
Restore Environment
```

---

# 66. Failure Evidence

Useful evidence includes:

```text
Prometheus metrics
Loki logs
Grafana dashboards
Alertmanager alerts
Runtime snapshots
HTTP responses
Container state
Health endpoints
Deployment state
```

Evidence should be sufficient to reconstruct what happened.

---

# 67. Failure Diagnosis Questions

During an incident, the Failure Model should help answer:

### What failed?

```text
Component / dependency / runtime / infrastructure
```

### Where did it originate?

```text
Origin
```

### What operation was affected?

```text
Operation ID
```

### Which execution was affected?

```text
Request ID
Execution ID
```

### How did the failure propagate?

```text
Failure boundary
```

### Was it retryable?

```text
Classification
```

### Was recovery attempted?

```text
Reliability state
```

### Did recovery succeed?

```text
Recovery state
```

### What is the current impact?

```text
Metrics + health + alerts
```

---

# 68. Failure Ownership Model

Ownership should be explicit.

| Failure Domain             | Primary Ownership           |
| -------------------------- | --------------------------- |
| Business logic failure     | Application                 |
| Runtime contract violation | Runtime                     |
| Dependency availability    | Infrastructure / Dependency |
| Host resource exhaustion   | Infrastructure              |
| Deployment regression      | Deployment                  |
| Alerting failure           | Observability               |
| Incident coordination      | Operations                  |

Ownership may overlap during incidents, but a primary owner should remain identifiable.

---

# 69. Failure Severity

Severity should be determined from operational impact rather than failure type alone.

For example:

```text
DEPENDENCY failure
```

could be:

```text
Low severity
```

if one request fails and retry succeeds.

The same failure could become:

```text
Critical
```

if PostgreSQL remains unavailable and affects all application capabilities.

Therefore:

```text
Failure Type
≠
Severity
```

---

# 70. Failure Frequency

Frequency is another independent dimension.

A failure may be:

```text
Rare but severe
```

or:

```text
Frequent but low impact
```

Both matter operationally.

Example:

```text
One host outage
```

may be rare but severe.

Meanwhile:

```text
1% transient dependency failures
```

may be frequent enough to justify architectural improvement.

---

# 71. Failure Budget Thinking

Reliability decisions should eventually consider acceptable failure levels.

Examples:

```text
Error rate
Availability
Latency
Queue delay
Job failure rate
Recovery time
```

The current platform establishes observability foundations that can support more formal SLO/SLA modeling in future iterations.

---

# 72. Failure and Recovery Time

Important operational measurements include:

```text
Time to Detect
Time to Diagnose
Time to Contain
Time to Recover
Time to Verify
```

These can be represented conceptually as:

```text
TTD
 │
 ▼
TTDiagnosis
 │
 ▼
TTC
 │
 ▼
TTR
 │
 ▼
TTV
```

The architecture currently provides signals that can support these measurements, although not all are automatically calculated as dedicated metrics.

---

# 73. Failure and Data Consistency

Failures in multi-step workflows can create partial completion.

Example:

```text
MinIO upload succeeds
       │
       ▼
PostgreSQL update succeeds
       │
       ▼
Redis enqueue fails
```

The system now contains:

```text
stored file
+
database reference
-
background job
```

This is not merely an availability problem.

It is a workflow consistency problem.

Such failures should therefore be documented and handled at the workflow/recovery layer rather than treated as simple Runtime exceptions.

---

# 74. Failure and Idempotency

Failures that occur after side effects require special attention.

Example:

```text
Operation
   │
   ▼
Side effect succeeds
   │
   X
Response lost
   │
   ▼
Retry
```

Without idempotency:

```text
duplicate side effect
```

may occur.

Therefore:

```text
Retry policy
+
Failure model
+
Idempotency model
```

must eventually be considered together for side-effecting operations.

---

# 75. Failure and Cancellation

Timeout and cancellation are related but different.

```text
Timeout
=
Stop waiting after a deadline
```

while:

```text
Cancellation
=
Attempt to stop the underlying operation
```

The current Runtime primarily implements timeout semantics.

It should not be documented as providing universal operation cancellation.

---

# 76. Unknown Failures

Unknown failures should be treated conservatively.

The current fallback is:

```text
INTERNAL
recoverable = false
retryable = false
```

This is preferable to automatically retrying unknown failures because blind retries can:

```text
increase load
duplicate side effects
hide programming defects
delay failure visibility
```

Unknown failures should therefore produce evidence for future classification improvements.

---

# 77. Failure Model Evolution

The Failure Model is not static.

New failure modes should be incorporated through:

```text
Incident
   │
   ▼
Failure Analysis
   │
   ▼
New Failure Scenario
   │
   ▼
Classification
   │
   ▼
Handling Strategy
   │
   ▼
Validation
   │
   ▼
Documentation
```

This is the foundation of continuous reliability improvement.

---

# 78. Common Failure Modeling Errors

## 78.1 Treating Every Error as Internal

This destroys useful operational semantics.

Prefer:

```text
dependency
timeout
validation
authentication
authorization
internal
```

where appropriate.

---

## 78.2 Retrying Every Failure

This can amplify outages.

Retry should be policy- and classification-driven.

---

## 78.3 Equating Timeout With Cancellation

A timeout may stop waiting without stopping the underlying work.

---

## 78.4 Treating Restart as Recovery

A restart is an action.

Recovery requires:

```text
restart
+
health verification
+
functional verification
```

---

## 78.5 Using One Signal for Diagnosis

An alert rarely explains the root cause by itself.

Correlate:

```text
metrics
+
logs
+
health
+
deployment state
+
infrastructure state
```

---

## 78.6 Ignoring Workflow-Level Failures

A workflow can fail even when individual steps have succeeded.

---

## 78.7 Ignoring Blast Radius

A dependency failure affecting one operation is different from the same dependency becoming globally unavailable.

---

# 79. Failure Model Invariants

The following invariants should remain true.

### Invariant 1 — Failures Are Classified

Important failures should have an identifiable classification.

### Invariant 2 — Failures Have Boundaries

Every failure should have a meaningful architectural boundary.

### Invariant 3 — Retry Is Explicit

Retries must be policy-driven.

### Invariant 4 — Unknown Failures Are Conservative

Unknown failures must not automatically become retry storms.

### Invariant 5 — Failure State Is Observable

Important failures should produce operational evidence.

### Invariant 6 — Recovery Is Verifiable

Recovery is not complete until the resulting state is verified.

### Invariant 7 — Failure Propagation Is Controlled

A local failure should not unnecessarily become a system-wide failure.

### Invariant 8 — Failure Knowledge Evolves

New incidents should improve the Failure Model.

---

# 80. Failure Model Reference Architecture

The complete conceptual model is:

```text
                           FAILURE
                              │
             ┌────────────────┼────────────────┐
             │                │                │
             ▼                ▼                ▼
          Origin           Duration          Scope
             │                │                │
             └────────────────┼────────────────┘
                              ▼
                         Classification
                              │
                 ┌────────────┼────────────┐
                 ▼            ▼            ▼
              Type       Recoverability  Retryability
                 │            │            │
                 └────────────┼────────────┘
                              ▼
                         Failure Boundary
                              │
                 ┌────────────┼────────────┐
                 ▼            ▼            ▼
             Component      Runtime      Workflow
                 │            │            │
                 └────────────┼────────────┘
                              ▼
                          Propagation
                              │
                              ▼
                          Detection
                              │
                              ▼
                           Handling
                              │
             ┌────────────────┼────────────────┐
             ▼                ▼                ▼
          Contain           Abort            Retry
             │                │                │
             └────────────────┼────────────────┘
                              ▼
                           Recovery
                              │
                              ▼
                         Verification
                              │
                              ▼
                           Evidence
                              │
                              ▼
                     Continuous Improvement
```

---

# 81. Relationship With Other Reliability Documents

This document defines the Failure Model.

The remaining Reliability documentation specializes it.

```text
docs/reliability/
│
├── reliability.md
│      │
│      └── Overall Reliability Architecture
│
├── failure-model.md
│      │
│      └── Failure Taxonomy, Boundaries,
│          Propagation and Classification
│
├── runtime-reliability.md
│      │
│      └── Runtime Implementation
│
└── recovery.md
       │
       └── Recovery and Operational Restoration
```

The dependency relationship is:

```text
Reliability Architecture
        │
        ▼
Failure Model
        │
        ├── Runtime Reliability
        │
        └── Recovery
```

---

# 82. Definition of Done

The Failure Model is considered sufficiently established when the platform can answer:

```text
✓ What can fail?

✓ Where can it fail?

✓ What type of failure occurred?

✓ What caused or originated the failure?

✓ What is the failure scope?

✓ What is the operational impact?

✓ Is the failure transient or persistent?

✓ Is it recoverable?

✓ Is it retryable?

✓ Where should the failure be contained?

✓ How can it propagate?

✓ How can it be detected?

✓ What evidence is produced?

✓ Who owns the failure?

✓ What recovery mechanism applies?

✓ How is recovery verified?

✓ How does the failure become engineering knowledge?
```

---

# 83. Final Model

The Mini-Write Failure Model can ultimately be summarized as:

```text
                    FAILURE
                       │
                       ▼
                 UNDERSTAND IT
                       │
       ┌───────────────┼────────────────┐
       ▼               ▼                ▼
     Origin          Type             Scope
       │               │                │
       └───────────────┼────────────────┘
                       ▼
                  CLASSIFY IT
                       │
                       ▼
                  BOUND IT
                       │
                       ▼
                UNDERSTAND ITS
                 PROPAGATION
                       │
                       ▼
                  DETECT IT
                       │
                       ▼
                 HANDLE IT
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Contain        Abort        Recover
          │            │            │
          └────────────┼────────────┘
                       ▼
                 VERIFY RESULT
                       │
                       ▼
                PRODUCE EVIDENCE
                       │
                       ▼
                LEARN FROM IT
                       │
                       ▼
             IMPROVE THE SYSTEM
```

The central principle is:

> **A failure is not fully modeled until its origin, classification, boundary, propagation, detection, handling, recovery, and operational evidence are understood.**

This makes failure behavior an explicit architectural concern rather than an accidental consequence of application errors.
