# Recovery

## 1. Purpose

This document defines the Recovery architecture of Mini-Write.

Recovery describes how the system responds after an execution has entered a degraded or failed state and how it attempts to return the affected execution, service, or infrastructure to an acceptable operational state.

Recovery is broader than retry.

A retry is one Runtime mechanism:

```text
Failure
   │
   ▼
Retry
````

Recovery is the broader process:

```text
Failure
   │
   ▼
Detection
   │
   ▼
Classification
   │
   ▼
Containment
   │
   ▼
Recovery Decision
   │
   ├── Retry
   ├── Restart
   ├── Reprocess
   ├── Rollback
   ├── Reconcile
   ├── Repair
   └── Escalate
   │
   ▼
Verification
   │
   ▼
Recovered / Degraded / Failed
```

The purpose of this document is therefore to establish:

* recovery boundaries;
* recovery responsibilities;
* Runtime-level recovery;
* service-level recovery;
* infrastructure recovery;
* deployment recovery;
* workflow recovery;
* recovery verification;
* recovery observability;
* recovery limitations;
* future recovery evolution.

---

# 2. Recovery Philosophy

Mini-Write treats recovery as an explicit engineering capability.

The system must not assume:

```text
Failure
  =
Automatic Recovery
```

Instead:

```text
Failure
   │
   ▼
Understand Failure
   │
   ▼
Determine Recovery Eligibility
   │
   ▼
Select Recovery Mechanism
   │
   ▼
Execute Recovery
   │
   ▼
Verify Result
```

This distinction is important because not every failure is recoverable.

Some failures require:

* retry;
* service restart;
* deployment rollback;
* state reconciliation;
* manual intervention;
* incident escalation.

---

# 3. Recovery Is Not One Mechanism

Recovery exists at multiple architectural layers.

```text
Application Workflow
        │
        ▼
Runtime Execution
        │
        ▼
Service Process
        │
        ▼
Container
        │
        ▼
Host
        │
        ▼
Deployment
        │
        ▼
Infrastructure
```

Each layer has different recovery mechanisms.

Therefore recovery must not be implemented as one global mechanism.

---

# 4. Recovery Layers

Mini-Write recovery can be modeled as:

```text
Layer 1 — Operation Recovery
Layer 2 — Runtime Recovery
Layer 3 — Workflow Recovery
Layer 4 — Service Recovery
Layer 5 — Container Recovery
Layer 6 — Deployment Recovery
Layer 7 — Infrastructure Recovery
Layer 8 — Operational Recovery
```

The layers are complementary rather than interchangeable.

---

# 5. Recovery Responsibility Matrix

| Recovery Layer | Primary Failure              | Recovery Mechanism          | Typical Owner       |
| -------------- | ---------------------------- | --------------------------- | ------------------- |
| Operation      | transient dependency failure | retry/backoff               | Runtime             |
| Runtime        | invalid execution state      | fail safely / terminate     | Runtime             |
| Workflow       | partial multi-step operation | compensation/reconciliation | Application         |
| Service        | process failure              | restart/redeploy            | Operations          |
| Container      | container failure            | container restart           | Docker / Operations |
| Deployment     | bad release                  | rollback                    | Deployment          |
| Infrastructure | host/dependency failure      | repair/reprovision          | Infrastructure      |
| Operational    | unresolved incident          | incident response           | Operator            |

This separation prevents recovery mechanisms from crossing architectural boundaries without justification.

---

# 6. Recovery State Model

Recovery should be considered a lifecycle rather than a single boolean.

Conceptually:

```text
NORMAL
  │
  ▼
DEGRADED
  │
  ▼
FAILURE_DETECTED
  │
  ▼
RECOVERY_ELIGIBLE
  │
  ▼
RECOVERING
  │
  ├──────────────► RECOVERED
  │
  ├──────────────► DEGRADED
  │
  └──────────────► FAILED
```

The system may also transition directly:

```text
FAILURE_DETECTED
       │
       ▼
FAILED
```

when no safe recovery mechanism exists.

---

# 7. Recovery Outcomes

Every recovery attempt should conceptually produce one of three outcomes.

## 7.1 Recovered

The original operational condition has returned to an acceptable state.

```text
Failure
   │
Recovery
   │
   ▼
Healthy
```

---

## 7.2 Degraded

The system remains functional but not fully healthy.

Example:

```text
Dependency latency elevated
        │
        ▼
Service still responding
        │
        ▼
DEGRADED
```

---

## 7.3 Failed

Recovery did not restore the required condition.

```text
Failure
   │
Recovery Attempt
   │
Failure
   │
▼
FAILED
```

This distinction is important for incident management.

---

# 8. Recovery Eligibility

A failure is recoverable only when the system has a safe and meaningful recovery mechanism.

The decision is:

```text
Failure
   │
   ▼
Classify
   │
   ▼
Can Recover?
   │
 ┌─┴─┐
 │   │
Yes  No
 │   │
 ▼   ▼
Recovery
       Escalate
```

Recovery eligibility depends on:

* failure type;
* failure scope;
* operation semantics;
* retry policy;
* side-effect behavior;
* dependency characteristics;
* current system state;
* available recovery mechanisms.

---

# 9. Recovery Must Be Bounded

Recovery mechanisms must not become infinite loops.

For example:

```text
Failure
   │
Retry
   │
Failure
   │
Retry
   │
Failure
   │
Retry
   │
...
```

is not recovery.

It is uncontrolled persistence of failure.

Mini-Write therefore uses bounded recovery mechanisms.

---

# 10. Runtime-Level Recovery

The first recovery layer is the Runtime.

Runtime recovery addresses execution-level failures such as:

* transient dependency errors;
* timeout;
* retryable infrastructure failure.

The primary mechanism is:

```text
Retry
+
Exponential Backoff
```

---

# 11. Runtime Recovery Flow

The Runtime recovery path is:

```text
Operation
   │
   ▼
Attempt
   │
   ▼
Failure
   │
   ▼
Failure Classification
   │
   ▼
Retry Policy Check
   │
   ▼
Retryable?
   │
 ┌─┴─┐
 │   │
Yes  No
 │   │
 ▼   ▼
Backoff  Terminal Failure
 │
 ▼
Retry
 │
 └──────► Attempt
```

The Runtime never retries indefinitely.

---

# 12. Retry Is Recovery, but Recovery Is Not Retry

This distinction is fundamental.

```text
Retry
=
repeat the same execution
```

while:

```text
Recovery
=
restore acceptable operational state
```

For example:

```text
PostgreSQL connection reset
```

may be recoverable through retry.

But:

```text
corrupted database state
```

requires a completely different recovery mechanism.

---

# 13. Runtime Recovery Example

Suppose an ID upload performs a MinIO operation.

```text
ID_UPLOAD
   │
   ▼
MinIO
   │
   ▼
ECONNRESET
```

The Runtime classifies the failure as a retryable dependency failure.

The configured policy permits retry.

Therefore:

```text
Attempt 1
   │
   ▼
Failure
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

The Runtime marks the operation as recovered.

---

# 14. Recovery Evidence

A recovered operation should not disappear from operational evidence.

The system should preserve:

```text
attempts
retries
failure_type
dependency
operation
recovered
```

This allows operators to distinguish:

```text
clean success
```

from:

```text
success after instability
```

---

# 15. Recovery and Observability

Recovery depends heavily on observability.

The recovery system should expose:

```text
Recovery Attempt
      │
      ├── Metrics
      ├── Logs
      ├── Events
      └── Final Outcome
```

Without recovery evidence, operators cannot determine whether the system is:

```text
healthy
```

or merely:

```text
successfully hiding repeated transient failures
```

---

# 16. Recovery Metrics

The Runtime currently provides metrics for:

* runtime operations;
* retries;
* failures;
* operation duration.

These allow recovery behavior to be inferred.

For example:

```text
Retries ↑
+
Recovered Operations ↑
```

can indicate dependency instability even when application error rate remains low.

---

# 17. Recovery and Failure Classification

Recovery decisions depend on classification.

The Runtime distinguishes failure categories such as:

```text
TIMEOUT
DEPENDENCY
VALIDATION
AUTHENTICATION
AUTHORIZATION
INTERNAL
```

Not all categories are recoverable.

A simplified model is:

```text
Failure Type       Default Recovery
------------------------------------
TIMEOUT            Conditional
DEPENDENCY         Conditional
VALIDATION         No
AUTHENTICATION     No
AUTHORIZATION      No
INTERNAL           Usually No
```

The actual decision remains policy-driven.

---

# 18. Recovery and Policy

Recovery requires both:

```text
Failure Semantics
+
Reliability Policy
```

For example:

```text
Dependency failure
+
retryable = true
+
policy.retry = true
+
retries remaining
```

results in:

```text
Retry
```

Whereas:

```text
Dependency failure
+
policy.retry = false
```

results in:

```text
Terminal Failure
```

---

# 19. Recovery and Idempotency

Safe recovery frequently depends on idempotency.

Consider:

```text
Upload
   │
   ▼
Object stored
   │
   X
Response lost
   │
   ▼
Runtime sees failure
```

If the Runtime blindly retries:

```text
Upload again
```

the system may create duplicate side effects.

Therefore recovery of side-effecting operations may require:

* idempotency keys;
* unique constraints;
* deterministic object identifiers;
* deduplication;
* transactional coordination.

The current Runtime does not universally provide these guarantees.

---

# 20. Ambiguous Outcomes

One of the most important recovery problems is:

```text
Did the operation fail
or
did the response fail?
```

Example:

```text
Client
  │
  ▼
MinIO
  │
  ▼
Write succeeds
  │
  X
Response lost
  │
  ▼
Runtime sees timeout
```

The Runtime cannot always distinguish:

```text
operation failed
```

from:

```text
operation succeeded but result was not observed
```

Therefore retrying may be dangerous.

This is why recovery policy must consider operation semantics.

---

# 21. Workflow Recovery

Runtime recovery protects individual dependency operations.

Workflow recovery protects multi-step business operations.

For example:

```text
ID Upload Workflow
       │
       ├── Store Object
       │
       ├── Persist Metadata
       │
       └── Enqueue Processing Job
```

Failure can occur between any two steps.

---

# 22. Partial Workflow Failure

Consider:

```text
Store Object
     │
     ▼
Success
     │
     ▼
Persist Metadata
     │
     ▼
Success
     │
     ▼
Enqueue Job
     │
     ▼
Failure
```

The system is now partially completed.

A simple retry of the final operation may be sufficient if it is idempotent.

Otherwise the workflow needs reconciliation or compensation.

---

# 23. Compensation

Compensation attempts to reverse previously completed side effects.

Conceptually:

```text
Step 1 ── Success
Step 2 ── Success
Step 3 ── Failure
             │
             ▼
        Compensation
             │
             ├── Undo Step 2
             └── Undo Step 1
```

Compensation is not automatically provided by the Runtime.

It belongs to workflow-level architecture.

---

# 24. Reconciliation

When compensation is unsafe or impossible, reconciliation may be preferable.

Reconciliation means:

```text
Actual State
    │
    ▼
Expected State
    │
    ▼
Detect Difference
    │
    ▼
Repair Difference
```

For example:

```text
Object exists
Database record missing
```

may be detected and repaired by a reconciliation process.

---

# 25. Recovery of Asynchronous Work

Worker processing introduces a different recovery model.

A job may:

```text
start
process partially
fail
retry
```

BullMQ already provides queue-level retry capabilities.

The Worker Runtime must therefore avoid blindly duplicating BullMQ's retry semantics.

The architectural model is:

```text
Reliability Runtime
        │
        ▼
BullMQ
        │
        ▼
Job Retry / Attempt Mechanics
```

The Runtime should add reliability semantics where they are not already owned by BullMQ.

---

# 26. Worker Recovery Boundary

For Worker execution:

```text
Queue
 │
 ▼
BullMQ Job
 │
 ▼
Worker Runtime
 │
 ▼
Job Operation
 │
 ▼
Infrastructure Boundary
 │
 ▼
Dependency
```

Recovery may therefore happen at multiple levels:

```text
Dependency Retry
+
Runtime Recovery
+
BullMQ Job Retry
```

These mechanisms must not create uncontrolled multiplicative retries.

---

# 27. Retry Multiplication Problem

Suppose:

```text
BullMQ:
3 attempts
```

and Runtime:

```text
2 retries
```

A single logical job could theoretically produce:

```text
3 × 3 = 9 dependency executions
```

depending on how the mechanisms interact.

This can create unexpected load.

Therefore Worker Runtime integration must explicitly define ownership of retry behavior.

---

# 28. Recovery Ownership Rule

A useful architectural rule is:

> One layer should own a given recovery decision.

For example:

```text
Dependency transient failure
        │
        ▼
Runtime owns dependency retry
```

while:

```text
Job permanently fails
        │
        ▼
BullMQ owns job reprocessing
```

This avoids competing recovery controllers.

---

# 29. Service Recovery

Runtime recovery cannot solve process-level failures.

For example:

```text
Node.js process crashes
```

means:

```text
Runtime no longer exists
```

The recovery boundary has moved upward.

Service recovery therefore belongs to:

* container lifecycle;
* deployment system;
* operations.

---

# 30. Container Recovery

Docker can restart failed containers according to configured restart behavior.

The recovery path is:

```text
Process Failure
     │
     ▼
Container Exits
     │
     ▼
Docker Detects Exit
     │
     ▼
Container Restart
     │
     ▼
Service Bootstrap
     │
     ▼
Health Verification
```

Runtime recovery cannot operate while the process itself is dead.

---

# 31. Container Recovery Limitations

Container restart does not automatically guarantee:

```text
state correctness
dependency recovery
workflow completion
data consistency
```

For example:

```text
Worker crashes after object upload
```

A restarted Worker may be healthy while the workflow remains incomplete.

Therefore process recovery must be distinguished from workflow recovery.

---

# 32. Service Recovery

A service may become unhealthy without crashing.

Examples:

```text
API process alive
but database unavailable
```

or:

```text
Worker process alive
but queue processing stalled
```

Service recovery may require:

```text
restart
redeploy
dependency restoration
configuration correction
manual intervention
```

Health checks and observability provide evidence for these decisions.

---

# 33. Health Verification After Recovery

Restarting a component is not equivalent to recovery.

Correct recovery requires:

```text
Restart
   │
   ▼
Health Verification
   │
   ▼
Operational Verification
```

For example:

```text
Container running
```

is weaker than:

```text
Container running
+
readiness succeeds
+
metrics endpoint available
+
dependency connectivity restored
```

---

# 34. Readiness as Recovery Verification

Readiness is particularly useful after service recovery.

The process:

```text
Container Restarted
      │
      ▼
Application Started
      │
      ▼
Readiness Check
      │
   ┌──┴──┐
   ▼     ▼
Ready  Not Ready
   │       │
   ▼       ▼
Traffic  Investigate
```

This prevents a restarted but unusable service from being treated as fully recovered.

---

# 35. Infrastructure Recovery

Infrastructure failures may affect multiple services.

Examples:

```text
Host failure
Docker failure
Disk exhaustion
Network failure
PostgreSQL failure
Redis failure
MinIO failure
```

The recovery scope therefore expands beyond a single application operation.

---

# 36. Host Recovery

The host is the foundational runtime environment for the current deployment.

If the VM becomes unavailable:

```text
Host Failure
   │
   ▼
All Containers Unavailable
   │
   ▼
All Application Services Unavailable
```

Runtime and application-level mechanisms cannot recover from this.

Recovery requires host-level intervention:

```text
VM restart
Host repair
Infrastructure reprovisioning
```

---

# 37. Disk Recovery

Low disk space is particularly important because it can affect:

```text
Docker
Loki
PostgreSQL
MinIO
deployment artifacts
application logs
```

The infrastructure alert:

```text
MWLowDiskSpace
```

provides an early warning.

Recovery may include:

```text
Identify disk consumers
   │
   ▼
Remove safe unused artifacts
   │
   ▼
Reduce unnecessary log retention
   │
   ▼
Restore capacity
   │
   ▼
Verify services
```

Automatic deletion should be conservative because data directories must not be treated like disposable build artifacts.

---

# 38. Database Recovery

Database recovery is outside the Runtime's retry mechanism.

A database outage may initially trigger:

```text
Runtime dependency failure
```

but persistent database failure requires infrastructure or operational recovery.

The escalation can be:

```text
Database Error
   │
   ▼
Runtime Retry
   │
   ▼
Still Failing
   │
   ▼
Service Degradation
   │
   ▼
Alert
   │
   ▼
Database Recovery
```

---

# 39. Redis Recovery

Redis may affect:

* background job queues;
* application dependencies;
* asynchronous processing.

A transient connection failure may be Runtime-recoverable.

A persistent Redis outage requires service or infrastructure recovery.

For Worker:

```text
Redis Failure
   │
   ▼
Job Processing Degraded
   │
   ▼
Queue Backlog
   │
   ▼
MWQueueBacklogHigh
```

This creates an operational recovery path.

---

# 40. Object Storage Recovery

MinIO is a critical dependency for file processing.

A transient MinIO failure may be retried at Runtime level.

Persistent MinIO failure may require:

```text
MinIO recovery
disk recovery
network recovery
container restart
```

After recovery, object storage operations should be verified before declaring the Worker fully recovered.

---

# 41. Deployment Recovery

Deployment recovery handles failures introduced by a release.

Typical sequence:

```text
Deploy
  │
  ▼
Health Verification
  │
  ▼
Failure Detected
  │
  ▼
Rollback
  │
  ▼
Previous Version
  │
  ▼
Health Verification
```

Rollback is a deployment recovery mechanism, not Runtime recovery.

---

# 42. Deployment Failure vs Runtime Failure

These failures must remain distinct.

Runtime failure:

```text
Current version
+
dependency operation failed
```

Deployment failure:

```text
new version
+
system behavior degraded
```

The first may be recoverable by retry.

The second may require rollback.

---

# 43. Recovery Verification After Rollback

A rollback is not complete merely because the previous image is running.

Verification should include:

```text
Container health
API readiness
Worker availability
Dependency connectivity
Metrics collection
Log flow
Critical application behavior
```

Only then should the deployment be considered recovered.

---

# 44. Infrastructure as Code and Recovery

Ansible provides reproducibility for infrastructure state.

This creates an important recovery capability:

```text
Known Configuration
        │
        ▼
Ansible
        │
        ▼
Reconstruct Host State
```

If infrastructure drift or host corruption occurs, Infrastructure as Code reduces the amount of manual reconstruction required.

---

# 45. Reprovisioning

Reprovisioning should be treated differently from restart.

```text
Restart
=
reuse existing environment
```

while:

```text
Reprovision
=
reconstruct environment from declared configuration
```

Reprovisioning is stronger but potentially more disruptive.

It is therefore an escalation mechanism.

---

# 46. Recovery Hierarchy

A practical recovery hierarchy is:

```text
Level 1
Retry Operation

Level 2
Recover Workflow

Level 3
Restart Service

Level 4
Restart Container

Level 5
Rollback Deployment

Level 6
Repair Infrastructure

Level 7
Reprovision Infrastructure

Level 8
Manual Incident Recovery
```

The system should prefer the lowest-cost safe recovery mechanism capable of resolving the failure.

---

# 47. Recovery Escalation

The escalation principle is:

```text
Local Recovery
      │
      ▼
Service Recovery
      │
      ▼
Deployment Recovery
      │
      ▼
Infrastructure Recovery
      │
      ▼
Manual Intervention
```

Do not escalate unnecessarily.

For example:

```text
single ECONNRESET
```

does not justify:

```text
host reprovisioning
```

---

# 48. Recovery Storms

Recovery mechanisms themselves can create load.

For example:

```text
Dependency outage
      │
      ├── API retries
      ├── Worker retries
      ├── BullMQ retries
      └── operator restarts
```

can amplify the outage.

Therefore recovery must be:

* bounded;
* coordinated;
* observable;
* ownership-aware.

---

# 49. Retry Storm Prevention

Current protections include:

```text
bounded retries
exponential backoff
operation-specific policy
failure classification
```

Potential future protections include:

```text
jitter
circuit breakers
bulkheads
adaptive retry budgets
global dependency limits
```

These should be introduced based on actual operational requirements.

---

# 50. Recovery and Resource Exhaustion

Recovery mechanisms consume resources.

Retries consume:

```text
CPU
connections
memory
network
dependency capacity
```

Therefore a recovery policy must consider:

```text
Recovery Benefit
vs
Recovery Cost
```

A retry that saves one operation but overloads an already failing dependency is not successful recovery at system level.

---

# 51. Recovery and Backpressure

Recovery should cooperate with backpressure.

For example:

```text
Worker queue grows
      │
      ▼
Processing latency increases
      │
      ▼
Dependency overloaded
      │
      ▼
Retries increase
```

Blind retry can worsen the queue.

A mature system may eventually need:

```text
Retry
+
Backpressure
+
Concurrency Control
```

as one coordinated mechanism.

---

# 52. Recovery and Alerting

Recovery-aware alerting should distinguish:

```text
Recovered condition
```

from:

```text
Persistent failure
```

For example:

```text
Temporary dependency failure
       │
       ▼
Runtime retry
       │
       ▼
Recovery
```

may require no incident.

But:

```text
Retries
   │
   ▼
Retry exhaustion
   │
   ▼
HTTP errors
   │
   ▼
Alert
```

represents operational impact.

---

# 53. Recovery and Incident Response

When automated recovery fails, the incident process begins.

The general flow is:

```text
Detection
   │
   ▼
Automated Recovery
   │
   ▼
Recovery Successful?
   │
 ┌─┴─┐
 │   │
Yes  No
 │   │
 ▼   ▼
Close  Incident
       │
       ▼
       Investigate
       │
       ▼
       Contain
       │
       ▼
       Repair
       │
       ▼
       Verify
       │
       ▼
       Resolve
```

See:

```text
docs/operations/incident-response.md
```

for the operational incident process.

---

# 54. Recovery Verification

Recovery must be verified against the original failure condition.

If the failure was:

```text
API unavailable
```

verification should test:

```text
API availability
```

If the failure was:

```text
Worker queue stalled
```

verification should test:

```text
Worker availability
+
queue processing
```

If the failure was:

```text
database unreachable
```

verification should test:

```text
database connectivity
+
application dependency behavior
```

---

# 55. Recovery Verification Is Layered

Verification should progress from infrastructure to application behavior.

```text
Host
  │
  ▼
Container
  │
  ▼
Process
  │
  ▼
Readiness
  │
  ▼
Dependency
  │
  ▼
Application Operation
  │
  ▼
Workflow
```

A lower-level success does not automatically prove higher-level recovery.

---

# 56. Recovery Evidence

A recovery event should ideally preserve:

```text
failure identity
failure type
affected service
affected operation
recovery mechanism
attempt count
recovery duration
final state
verification result
```

This creates an auditable recovery history.

---

# 57. Recovery Duration

Recovery time should be observable.

Conceptually:

```text
Recovery Start
      │
      ▼
Recovery Actions
      │
      ▼
Verification
      │
      ▼
Recovery Complete
```

The elapsed duration contributes to operational metrics such as:

```text
MTTR
```

when the recovery represents an operational incident.

---

# 58. Recovery and MTTR

Runtime retries generally operate below incident-level MTTR.

For example:

```text
Dependency failure
   │
   ▼
100 ms backoff
   │
   ▼
Retry succeeds
```

does not normally constitute an operational incident.

But:

```text
Service outage
   │
   ▼
Restart
   │
   ▼
Rollback
   │
   ▼
Incident resolution
```

contributes to recovery-time analysis.

Therefore recovery duration must be interpreted at the correct architectural layer.

---

# 59. Recovery and SLOs

Recovery behavior directly influences service availability and latency.

For example:

```text
Successful retry
```

may preserve availability but increase latency.

Therefore:

```text
Availability
+
Latency
+
Recovery Rate
```

should be evaluated together.

A system that technically returns successful responses but spends most of its time recovering from dependency failures is not operationally healthy.

---

# 60. Recovery Decision Table

| Condition                    | Recovery                        | Escalation                    |
| ---------------------------- | ------------------------------- | ----------------------------- |
| transient dependency error   | Runtime retry                   | none if recovered             |
| timeout + retryable policy   | retry/backoff                   | terminal failure if exhausted |
| validation error             | no retry                        | application handling          |
| authentication failure       | no retry                        | client/auth handling          |
| authorization failure        | no retry                        | authorization handling        |
| Runtime contract violation   | fail safely                     | engineering investigation     |
| process crash                | container/service restart       | operations                    |
| bad deployment               | rollback                        | deployment investigation      |
| host failure                 | host recovery/reprovisioning    | infrastructure                |
| partial workflow             | compensation/reconciliation     | workflow investigation        |
| persistent dependency outage | service/infrastructure recovery | incident response             |

---

# 61. Recovery Anti-Patterns

## 61.1 Infinite Retry

```text
Failure → Retry → Failure → Retry → ...
```

Never acceptable.

---

## 61.2 Retry Everything

Not all errors are transient.

---

## 61.3 Restart Everything

Restarting healthy components can increase blast radius.

---

## 61.4 Rollback Everything

Rollback is appropriate for deployment-induced failures, not arbitrary dependency outages.

---

## 61.5 Treat Restart as Recovery

A process can restart while the underlying problem remains.

---

## 61.6 Ignore Partial State

A successful restart does not repair incomplete workflows.

---

## 61.7 Hide Recovery

Recovered operations must remain observable.

---

## 61.8 Multiple Retry Controllers

Avoid:

```text
Runtime retry
+
BullMQ retry
+
application retry
+
dependency-client retry
```

without explicit coordination.

---

# 62. Recovery Architecture in Mini-Write

The complete model is:

```text
                         FAILURE
                            │
                            ▼
                    Failure Detection
                            │
                            ▼
                   Failure Classification
                            │
                            ▼
                    Recovery Eligibility
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
          Runtime        Workflow        Service
          Recovery       Recovery        Recovery
             │              │              │
          Retry          Compensate      Restart
          Backoff         Reconcile       Redeploy
             │              │              │
             └──────────────┼──────────────┘
                            ▼
                    Deployment Recovery
                            │
                            ▼
                   Infrastructure Recovery
                            │
                            ▼
                    Recovery Verification
                            │
                 ┌──────────┼──────────┐
                 ▼          ▼          ▼
             Recovered    Degraded    Failed
                 │          │          │
                 ▼          ▼          ▼
               Close     Observe    Escalate
```

---

# 63. Recovery Ownership Model

The most important architectural ownership rule is:

```text
Runtime
    owns execution recovery

Application Workflow
    owns workflow consistency

BullMQ
    owns queue/job retry mechanics

Docker
    owns container lifecycle

Deployment
    owns release recovery

Ansible / Infrastructure
    owns infrastructure reconstruction

Operations
    owns incident recovery
```

No layer should silently assume ownership of another layer's recovery responsibility.

---

# 64. Current Recovery Capabilities

Mini-Write currently establishes concrete recovery mechanisms in the following areas:

### Runtime

* bounded retry;
* exponential backoff;
* timeout;
* failure classification;
* recovery tracking;
* terminal failure propagation.

### Service / Container

* container lifecycle management;
* health/readiness verification;
* operational restart capability.

### Infrastructure

* Infrastructure as Code;
* reproducible host configuration;
* infrastructure observability;
* infrastructure health alerts.

### Deployment

* controlled deployment process;
* health verification;
* rollback as a recovery strategy.

### Operations

* structured incident response;
* observability-driven diagnosis.

---

# 65. Capabilities Not Yet Implied

The architecture must not claim capabilities that are not actually implemented.

The current system does not universally provide:

* distributed transactions;
* automatic workflow compensation;
* universal idempotency;
* guaranteed cancellation of timed-out operations;
* circuit breakers;
* jittered retry;
* automatic dependency failover;
* automatic infrastructure remediation;
* automatic incident resolution.

These remain potential future capabilities.

---

# 66. Recovery Evolution Path

Recovery can evolve progressively.

### Level 1 — Bounded Runtime Recovery

```text
Timeout
Retry
Backoff
Failure Classification
```

### Level 2 — Workflow Recovery

```text
Idempotency
Compensation
Reconciliation
```

### Level 3 — Service Recovery

```text
Restart
Health Verification
Dependency Recovery
```

### Level 4 — Deployment Recovery

```text
Automated Validation
Rollback
Release Health
```

### Level 5 — Resilience Controls

```text
Circuit Breaking
Bulkheads
Backpressure
Adaptive Recovery
```

### Level 6 — Advanced Operational Recovery

```text
Automated Remediation
SLO-Aware Recovery
Recovery Automation
Failure Learning
```

The architecture should evolve according to observed operational needs rather than speculative complexity.

---

# 67. Recovery Engineering Invariants

The Recovery architecture follows these invariants.

## Invariant 1 — Recovery Must Have an Owner

Every recovery mechanism belongs to a specific architectural layer.

## Invariant 2 — Recovery Must Be Bounded

No recovery mechanism should continue indefinitely.

## Invariant 3 — Recovery Must Be Observable

Successful recovery should not erase evidence of degradation.

## Invariant 4 — Recovery Must Preserve Correctness

Recovery must not restore availability by corrupting business state.

## Invariant 5 — Recovery Must Respect Failure Semantics

A validation failure must not be treated like a network timeout.

## Invariant 6 — Recovery Must Be Verified

A recovery action is not equivalent to a recovered system.

## Invariant 7 — Recovery Must Not Amplify Failure

Recovery traffic must not overwhelm an already failing dependency.

## Invariant 8 — Recovery Layers Must Not Compete

Multiple independent recovery controllers must not create uncontrolled retry or restart loops.

---

# 68. Recovery Validation Strategy

Recovery should be validated through controlled failure experiments.

Examples include:

```text
Dependency unavailable
Dependency slow
Connection reset
Worker failure
API process failure
Container restart
Host resource exhaustion
Deployment regression
Partial workflow failure
```

For each experiment:

```text
Inject Failure
      │
      ▼
Observe Detection
      │
      ▼
Observe Recovery Decision
      │
      ▼
Observe Recovery Action
      │
      ▼
Observe Verification
      │
      ▼
Confirm Final State
```

---

# 69. Recovery Experiment Example

A PostgreSQL outage experiment:

```text
1. Stop PostgreSQL
2. Execute database-dependent operation
3. Observe Runtime failure
4. Observe classification
5. Observe retry behavior if policy permits
6. Confirm terminal failure if dependency remains unavailable
7. Restore PostgreSQL
8. Execute operation again
9. Verify successful execution
10. Verify metrics and logs
```

This validates the complete recovery path rather than only individual functions.

---

# 70. Recovery Verification Checklist

A recovery implementation should be considered operationally valid only when:

```text
✓ Failure is detected

✓ Failure is classified

✓ Recovery eligibility is determined

✓ Correct recovery layer is selected

✓ Recovery is bounded

✓ Recovery action is observable

✓ Recovery does not duplicate unsafe side effects

✓ Final state is verified

✓ Recovered execution is distinguishable from clean execution

✓ Terminal failure is propagated when recovery fails

✓ Higher-level escalation occurs when necessary

✓ Recovery does not create an uncontrolled retry/restart loop
```

---

# 71. Relationship With Runtime Reliability

Runtime Reliability defines the execution-level recovery mechanism.

Recovery architecture defines the larger system-level context in which that mechanism operates.

```text
Recovery
   │
   └── Runtime Recovery
           │
           ├── Timeout
           ├── Retry
           ├── Backoff
           └── Recovery Tracking
```

See:

```text
docs/reliability/runtime-reliability.md
```

for the detailed Runtime implementation model.

---

# 72. Relationship With Failure Model

Recovery begins after failure has been detected and classified.

The dependency is therefore:

```text
Failure Model
      │
      ▼
Failure Classification
      │
      ▼
Recovery Decision
      │
      ▼
Recovery Mechanism
```

The Failure Model determines what the failure means.

Recovery determines what can safely be done about it.

---

# 73. Relationship With Operations

Recovery that cannot complete automatically becomes an operational concern.

```text
Automated Recovery
      │
      ▼
Successful?
   ┌──┴──┐
   │     │
 Yes     No
 │       │
 ▼       ▼
Close   Incident
        Response
```

Operational recovery is therefore the final escalation layer.

---

# 74. Final Recovery Model

The Mini-Write recovery architecture can be summarized as:

```text
                         FAILURE
                            │
                            ▼
                      DETECTION
                            │
                            ▼
                    CLASSIFICATION
                            │
                            ▼
                    RECOVERY DECISION
                            │
             ┌──────────────┼──────────────┐
             │              │              │
             ▼              ▼              ▼
          RETRY         COMPENSATE      RESTART
             │              │              │
          Runtime        Workflow        Service
             │              │              │
             └──────────────┼──────────────┘
                            ▼
                         VERIFY
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
         RECOVERED       DEGRADED        FAILED
             │              │              │
             ▼              ▼              ▼
           CLOSE         OBSERVE        ESCALATE
```

The central principle is:

> **Recovery is not the act of trying again; it is the controlled process of restoring an acceptable operational state while preserving correctness, bounding recovery cost, maintaining observability, and escalating when automated mechanisms are insufficient.**

For Mini-Write, this means that Runtime retry is only the first recovery layer. A production-oriented reliability architecture must also account for workflow consistency, service restart, deployment rollback, infrastructure reconstruction, recovery verification, and operational escalation.

```
```
