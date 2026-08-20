# Testing

## 1. Purpose

This document defines the testing strategy and validation model for Mini-Write.

Testing in Mini-Write is not limited to verifying that individual functions return expected values.

The project is a distributed, containerized system composed of:

- API;
- Worker;
- PostgreSQL;
- Redis;
- MinIO;
- Runtime Reliability;
- deployment infrastructure;
- observability components.

Therefore, the testing strategy must validate both:

1. **local correctness** — whether an individual component behaves correctly;
2. **system correctness** — whether components continue to behave correctly when integrated.

The testing model is consequently layered:

```text
Unit
  │
  ▼
Component
  │
  ▼
Integration
  │
  ▼
Runtime / Reliability
  │
  ▼
End-to-End
  │
  ▼
Operational Validation
````

Each layer answers a different engineering question.

---

# 2. Testing Philosophy

The testing strategy follows five principles.

## 2.1 Test Behavior, Not Implementation

Tests should validate externally meaningful behavior rather than coupling themselves unnecessarily to internal implementation details.

For example:

```text
Preferred:

request
  │
  ▼
expected HTTP behavior
```

rather than:

```text
controller
  │
  ▼
internal function A
  │
  ▼
internal function B
```

unless those internal functions have independent behavior that requires direct testing.

---

## 2.2 Test Failure Paths Explicitly

A production-oriented system cannot be validated only through successful execution.

Tests must consider:

```text
Success
Failure
Timeout
Dependency failure
Invalid input
Authentication failure
Authorization failure
Retry
Retry exhaustion
Recovery
State inconsistency
```

The absence of a happy-path failure in testing does not imply reliability.

---

## 2.3 Test at the Lowest Useful Layer

A failure should ideally be detected by the cheapest test capable of detecting it.

The preferred hierarchy is:

```text
Unit test
   │
   └── if sufficient → stop

Component test
   │
   └── if dependency interaction matters

Integration test
   │
   └── if service interaction matters

End-to-End test
   │
   └── if system behavior matters
```

This reduces test execution time while preserving meaningful coverage.

---

## 2.4 Keep Tests Deterministic

Tests should produce the same result when executed repeatedly under the same conditions.

Avoid unnecessary dependencies on:

* real time;
* random state;
* external services;
* network availability;
* developer-specific configuration;
* persistent local state.

When nondeterminism is unavoidable, it should be isolated and explicitly controlled.

---

## 2.5 Tests Are an Engineering Contract

Tests should protect architectural behavior.

For Mini-Write, important contracts include:

```text
Runtime lifecycle
Operation resolution
Reliability policy activation
Failure classification
Retry behavior
Health semantics
Infrastructure boundaries
Queue processing
Observability behavior
```

A test suite should therefore prevent architectural regressions, not merely increase line coverage.

---

# 3. Testing Layers

Mini-Write uses the following conceptual testing layers:

```text
┌─────────────────────────────────────────┐
│ Operational Validation                  │
│ deployment / health / observability     │
├─────────────────────────────────────────┤
│ End-to-End Testing                      │
│ complete user/system workflows          │
├─────────────────────────────────────────┤
│ Runtime Reliability Testing             │
│ timeout / retry / recovery / failure    │
├─────────────────────────────────────────┤
│ Integration Testing                     │
│ API ↔ PostgreSQL / Redis / MinIO        │
├─────────────────────────────────────────┤
│ Component Testing                       │
│ service-level behavior                  │
├─────────────────────────────────────────┤
│ Unit Testing                            │
│ isolated functions / modules             │
└─────────────────────────────────────────┘
```

These layers are complementary.

One layer must not be treated as a replacement for all others.

---

# 4. Unit Testing

## 4.1 Purpose

Unit tests validate isolated pieces of application logic.

Typical targets include:

* pure functions;
* validation logic;
* transformation functions;
* failure classifiers;
* policy calculations;
* backoff calculations;
* Runtime state rules.

A unit test should ideally have:

```text
Arrange
  │
  ▼
Act
  │
  ▼
Assert
```

with minimal external dependencies.

---

# 5. Runtime Unit Testing

The Runtime layer is especially suitable for unit testing because many of its responsibilities are deterministic.

Examples include:

```text
createExecutionContext()
createOperationContext()
createReliabilityPolicy()
classifyFailure()
calculateBackoffMs()
```

Runtime lifecycle transitions should be tested explicitly.

For example:

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

Invalid transitions should also be tested.

Examples:

```text
created → active
active → initialized
completed → active
completed → completed
```

These transitions should be rejected according to the Runtime contract.

---

# 6. Failure Classification Testing

The failure classifier is a critical reliability boundary.

It maps raw failures into operational categories.

The expected conceptual behavior is:

```text
Error
  │
  ▼
Classification
  │
  ├── timeout
  ├── dependency
  ├── validation
  ├── authentication
  ├── authorization
  └── internal
```

Tests should verify both:

```text
classification.type
```

and:

```text
classification.recoverable
classification.retryable
```

For example, a transient dependency error should not accidentally become an internal non-retryable error.

---

# 7. Reliability Policy Testing

Reliability policies determine how operations behave under abnormal conditions.

Tests should verify that operation identifiers resolve to the expected policies.

For example:

```text
user_login
    │
    ▼
User Login Policy
    │
    ├── timeout
    ├── retry
    ├── maxRetries
    └── recoverable
```

The test should ensure that an accidental policy change does not silently alter the reliability characteristics of a critical operation.

---

# 8. Backoff Testing

Retry backoff is deterministic and should therefore be tested independently.

The expected conceptual sequence is:

```text
Attempt 1
   │
   ▼
100ms

Attempt 2
   │
   ▼
200ms

Attempt 3
   │
   ▼
400ms
```

with the implementation's maximum backoff bound respected.

Tests should verify:

* initial delay;
* exponential progression;
* upper bound;
* behavior for invalid or boundary attempt numbers.

The test should validate the contract rather than rely on actually sleeping for the full delay.

---

# 9. Component Testing

Component tests validate a larger unit of behavior while still maintaining a relatively narrow scope.

Examples:

```text
API authentication flow
API upload controller
Worker job processor
health service
queue service
storage service
```

A component test may use mocks or controlled dependencies where appropriate.

The objective is to verify the component's responsibility without requiring the complete system.

---

# 10. API Testing

The API should be tested at multiple levels.

### Route-level behavior

Validate:

```text
HTTP method
HTTP status
response structure
input validation
authentication
authorization
```

### Runtime integration

Validate:

```text
runtimeBootstrap
runtimeGuard
runtimeOperationResolution
runtimeStateActivation
runtimeFailureHandler
```

### Dependency interaction

Validate operations involving:

```text
PostgreSQL
Redis
MinIO
```

The test strategy should therefore distinguish between:

```text
HTTP behavior
Runtime behavior
Infrastructure behavior
```

---

# 11. Authentication Testing

Authentication-related tests should cover at least:

```text
Successful registration
Duplicate username
Missing registration fields
Successful login
Unknown user
Invalid password
Missing credentials
JWT generation
Protected route access
Invalid token
```

The important distinction is between:

```text
Authentication failure
```

and:

```text
Infrastructure failure
```

For example, invalid credentials should not be treated as a database outage.

---

# 12. Upload Workflow Testing

The ID upload workflow crosses multiple boundaries.

Conceptually:

```text
HTTP Request
     │
     ▼
Authentication
     │
     ▼
File Validation
     │
     ▼
MinIO Upload
     │
     ▼
PostgreSQL Update
     │
     ▼
Redis Queue
     │
     ▼
Worker
```

Tests should therefore cover both individual stages and the integrated workflow.

Important cases include:

```text
No file
Invalid file
Successful upload
Storage failure
Database failure
Queue failure
Partial workflow failure
```

---

# 13. Integration Testing

Integration tests validate actual interactions between application components and their dependencies.

They should be used when mocks would hide important behavior.

Examples:

```text
API ↔ PostgreSQL
API ↔ Redis
API ↔ MinIO
Worker ↔ Redis
Worker ↔ PostgreSQL
Worker ↔ MinIO
```

The objective is to verify:

```text
Connection
Protocol
Configuration
Serialization
Persistence
Error behavior
```

---

# 14. Database Integration Testing

PostgreSQL integration tests should verify behavior that cannot be reliably established through mocks.

Examples:

```text
Table initialization
User insertion
Duplicate constraint
User lookup
User update
Transaction behavior where applicable
Database failure handling
```

The test should use an isolated database state.

Tests should not depend on data left behind by previous test executions.

---

# 15. Redis Integration Testing

Redis integration tests should validate:

```text
Connection
Queue creation
Job insertion
Job retrieval
Queue state
Failure behavior
```

For Worker functionality, Redis integration is particularly important because queue semantics are part of the application's actual runtime behavior.

---

# 16. Object Storage Integration Testing

MinIO integration tests should validate:

```text
Bucket access
Object upload
Object retrieval where applicable
Object naming
Storage failure
Authentication / credentials
```

A mocked storage service can verify controller behavior, but only an integration test can validate the actual object-storage interaction.

---

# 17. Worker Testing

Worker testing should account for its asynchronous nature.

The Worker should be tested at three levels:

```text
Job Logic
   │
   ▼
Queue Integration
   │
   ▼
End-to-End Processing
```

Unit-level tests validate processing logic.

Integration tests validate Redis/BullMQ interaction.

End-to-end tests validate the complete workflow from job creation to completion.

---

# 18. Worker Job Lifecycle

A representative Worker job lifecycle is:

```text
Job Created
    │
    ▼
Queued
    │
    ▼
Claimed
    │
    ▼
Processing
    │
    ├───────────────┐
    │               │
    ▼               ▼
Success           Failure
    │               │
    ▼               ▼
Completed       Retry / Failed
```

Tests should verify the intended behavior at each relevant transition.

---

# 19. Runtime Reliability Testing

Runtime Reliability requires dedicated tests.

The core scenarios are:

```text
Successful operation
Timeout
Retryable failure
Non-retryable failure
Retry exhaustion
Recovery
```

The test model is:

```text
Operation
   │
   ▼
Runtime Policy
   │
   ▼
Execution
   │
   ├── Success
   │
   └── Failure
         │
         ▼
     Classification
         │
         ▼
     Retry Decision
         │
      ┌──┴──┐
      ▼     ▼
    Retry   Fail
      │
      ▼
   Backoff
      │
      ▼
 Next Attempt
```

---

# 20. Timeout Testing

Timeout behavior must be tested independently of normal failure handling.

The expected contract is:

```text
Operation
   │
   ▼
Timeout exceeded
   │
   ▼
RuntimeTimeoutError
   │
   ▼
Failure Classification
   │
   ▼
Retry decision
```

Tests should verify:

* timeout error type;
* timeout code;
* dependency metadata;
* timeout value;
* retry eligibility;
* final HTTP behavior where applicable.

A timeout must not silently become an ordinary internal error.

---

# 21. Retry Testing

Retry behavior should verify:

```text
Retry enabled
Retry disabled
Maximum retries
Retryable classification
Non-retryable classification
Retry counter
Attempt counter
Recovery state
```

For an operation with:

```text
maxRetries = 2
```

the expected maximum number of attempts is:

```text
Initial attempt
   +
2 retries
   =
3 attempts
```

Tests should explicitly assert this distinction.

---

# 22. Retry Exhaustion

A retryable failure that persists beyond the configured retry limit must eventually fail.

The expected sequence is:

```text
Attempt 1
   │
   ▼
Failure
   │
   ▼
Retry

Attempt 2
   │
   ▼
Failure
   │
   ▼
Retry

Attempt 3
   │
   ▼
Failure
   │
   ▼
Final Failure
```

The test must verify that the Runtime does not continue indefinitely.

---

# 23. Recovery Testing

Recovery is different from success.

A successful first attempt is:

```text
attempt 1 → success
```

Recovery is:

```text
attempt 1 → failure
attempt 2 → success
```

The Runtime must record the latter as a recovered execution where the architecture defines that behavior.

Tests should verify:

```text
attempts
retries
recovered
failure state
operation outcome
metrics
```

---

# 24. Failure Propagation Testing

The infrastructure boundary should not silently consume failures.

The expected behavior is:

```text
Dependency Failure
       │
       ▼
Runtime Classification
       │
       ▼
Runtime State
       │
       ▼
Infrastructure Boundary
       │
       ▼
Caller
```

Tests should verify that the original failure remains available to the caller unless the architecture explicitly defines a transformation.

This prevents reliability infrastructure from hiding business-level failures.

---

# 25. Runtime State Testing

Runtime state should be tested as a state machine.

Valid transitions:

```text
CREATED
   │
   ▼
INITIALIZED
   │
   ├─────────────┐
   ▼             ▼
ACTIVE        COMPLETED
   │
   ▼
COMPLETED
```

Invalid transitions should produce explicit failures.

Testing the state machine protects the Runtime against lifecycle corruption.

---

# 26. Runtime Guard Testing

The Runtime Guard protects the Runtime contract.

Tests should verify failures when:

```text
Runtime is missing
Runtime state is invalid
Runtime instance has changed
Execution identity has changed
Request identity has changed
```

The guard is therefore not merely defensive programming.

It is an architectural integrity boundary.

---

# 27. Health Check Testing

Health checks have different semantic purposes.

## Liveness

The liveness probe answers:

> Is the application process alive?

## Readiness

The readiness probe answers:

> Can the application currently serve requests requiring its dependencies?

Tests should preserve this distinction.

A PostgreSQL outage should not necessarily cause:

```text
/health/live → DOWN
```

if the process itself remains alive.

It may instead cause:

```text
/health/live  → 200
/health/ready → 503
```

depending on the implemented health semantics.

---

# 28. Observability Testing

Observability is part of the system contract.

Tests should verify instrumentation where it is operationally important.

Examples:

```text
HTTP request counter
HTTP request duration
HTTP errors
Business counters
Runtime operation counters
Runtime retries
Runtime failures
Runtime duration
```

A code change that removes required instrumentation may therefore constitute a regression even when application functionality still works.

---

# 29. Logging Testing

Structured logs should be validated where they are part of an operational contract.

Important fields may include:

```text
timestamp
level
service
environment
request_id
execution_id
operation_id
dependency
failure_type
```

Tests should avoid asserting the entire serialized log line when only a subset of fields constitutes the contract.

Prefer semantic assertions such as:

```text
event == runtime_operation_failed
operation_id == id_upload
failure_type == dependency
```

rather than exact formatting of the entire JSON document.

---

# 30. Metrics Testing

Metrics tests should verify:

```text
Metric exists
Metric has expected name
Metric has expected labels
Metric changes after expected event
Metric does not use uncontrolled high-cardinality labels
```

For example, request identifiers should generally not become Prometheus labels.

This protects the monitoring system from cardinality explosions.

---

# 31. Alert Testing

Alert rules should be treated as executable operational knowledge.

A useful alert test verifies:

```text
Condition
   │
   ▼
PromQL expression
   │
   ▼
Threshold
   │
   ▼
for duration
   │
   ▼
Alert
```

The test should also verify the semantic metadata:

```text
severity
category
service
environment
```

where those labels are part of the alerting contract.

---

# 32. End-to-End Testing

End-to-End tests validate complete workflows.

A representative Mini-Write workflow is:

```text
Client
  │
  ▼
API
  │
  ├── PostgreSQL
  ├── MinIO
  └── Redis
          │
          ▼
        Worker
          │
          ├── PostgreSQL
          └── MinIO
```

An E2E test should verify the final observable outcome rather than merely intermediate calls.

---

# 33. Example End-to-End Workflow

A representative ID upload test may validate:

```text
1. Register user
2. Authenticate user
3. Upload ID
4. API stores object
5. API updates database
6. API enqueues job
7. Worker receives job
8. Worker processes job
9. Final state is persisted
```

The test should fail if any required stage breaks.

This is fundamentally different from a controller unit test.

---

# 34. Test Isolation

Tests must avoid unintended coupling through shared state.

Potential shared state includes:

```text
Database records
Redis queues
Object storage objects
Environment variables
Filesystem files
Global module state
Prometheus registries
```

Tests should clean up or isolate the state they create.

The preferred model is:

```text
Test
  │
  ▼
Known Initial State
  │
  ▼
Execution
  │
  ▼
Assertions
  │
  ▼
Cleanup
```

---

# 35. Test Data

Test data should be explicit and deterministic.

Avoid relying on:

```text
Existing local database records
Developer-specific users
Manually uploaded objects
Previously created queue jobs
```

A test should create the data it requires whenever practical.

This makes failures reproducible.

---

# 36. Test Naming

Test names should describe behavior.

Prefer:

```text
should reject duplicate username
should classify ECONNRESET as retryable dependency failure
should stop retrying after maxRetries
should mark execution as recovered after successful retry
```

Avoid vague names such as:

```text
test login
test runtime
test upload
```

A good test name communicates the contract being protected.

---

# 37. Test Organization

Tests should remain close to the component they validate when that matches the existing project convention.

Conceptually:

```text
api/
├── src/
└── tests/

worker/
├── src/
└── tests/
```

The exact directory structure is determined by the repository's implementation.

The important principle is that test ownership should remain clear.

---

# 38. Mocking Strategy

Mocks are useful when they isolate the behavior under test.

Use mocks for:

```text
External side effects
Unrelated dependencies
Rare failure conditions
Deterministic simulation
```

Do not mock an entire dependency when the interaction with that dependency is itself what needs to be tested.

For example:

```text
Unit test:
controller + mocked PostgreSQL

Integration test:
controller + real PostgreSQL
```

Both tests provide value because they answer different questions.

---

# 39. Avoiding Over-Mocking

Excessive mocking can produce false confidence.

For example:

```text
Application
   │
   ▼
Mock PostgreSQL
   │
   ▼
Test passes
```

does not prove that:

```text
Application
   │
   ▼
Real PostgreSQL
```

will work.

Therefore:

```text
Mocking
  =
Isolation technique

Integration testing
  =
Interaction verification
```

They are not interchangeable.

---

# 40. Test Environment Variables

Tests should explicitly control the environment they require.

Avoid depending on a developer's shell state.

The test environment should define appropriate values for:

```text
NODE_ENV
Database configuration
Redis configuration
MinIO configuration
JWT configuration
Runtime configuration
```

Secrets used exclusively for tests must never be real production secrets.

---

# 41. Testing Environment Configuration

Configuration itself can introduce failures.

Tests should verify important configuration assumptions where practical.

Examples:

```text
Required variable exists
Port is valid
Database URL is valid
Runtime policy is loaded
Dependency endpoint is reachable
```

Configuration failures should be distinguishable from application logic failures.

---

# 42. Test Execution Strategy

Testing should be progressive.

A developer should not immediately execute the entire test suite after every minor change.

Recommended sequence:

```text
Changed code
    │
    ▼
Focused test
    │
    ▼
Affected component tests
    │
    ▼
Integration tests
    │
    ▼
Full suite
    │
    ▼
E2E / operational validation
```

This provides rapid feedback while preserving final confidence.

---

# 43. Before Opening a Pull Request

Before submitting a change for review, validate:

```text
✓ Relevant unit tests
✓ Relevant component tests
✓ Relevant integration tests
✓ Runtime tests when applicable
✓ E2E tests when applicable
✓ No test pollution
✓ No secrets
✓ No unintended changes
```

The exact CI commands are defined by the repository's CI workflow and package scripts.

Do not invent alternative commands when an authoritative repository command exists.

---

# 44. Testing Changes to Infrastructure

Infrastructure changes require a different validation model.

Examples:

```text
Ansible role
Docker Compose
Network configuration
Security baseline
Deployment scripts
```

The validation sequence should be:

```text
Syntax
  │
  ▼
Static Validation
  │
  ▼
Idempotency
  │
  ▼
Execution
  │
  ▼
Runtime Verification
```

Infrastructure correctness cannot be established solely by syntax validation.

---

# 45. Ansible Testing

Ansible changes should be validated at multiple levels.

At minimum:

```text
YAML validity
Task validity
Variable resolution
Check mode where supported
Actual execution
Post-execution state
```

A particularly important property is idempotency:

```text
First execution
    │
    ▼
System converges
    │
    ▼
Second execution
    │
    ▼
No unnecessary changes
```

Idempotency is a core requirement of Infrastructure as Code.

---

# 46. Docker Compose Testing

Compose changes should be validated for:

```text
YAML validity
Service definitions
Networks
Volumes
Environment references
Health checks
Dependencies
Port mappings
Resource constraints
```

After deployment, verify actual runtime state.

For example:

```bash
docker compose ps
```

and inspect affected service logs.

---

# 47. Security Testing

Security-related changes should be validated as behavior.

Examples:

```text
Firewall policy
SSH configuration
Authentication
Authorization
Secret handling
Container permissions
Network exposure
```

A security configuration that is syntactically valid but operationally ineffective is still a failed implementation.

---

# 48. Regression Testing

Every bug fix should result in a regression test when practical.

The workflow is:

```text
Bug
 │
 ▼
Reproduce
 │
 ▼
Write failing test
 │
 ▼
Fix
 │
 ▼
Test passes
 │
 ▼
Regression protection
```

This converts an incident or defect into permanent engineering knowledge.

---

# 49. Failure Injection Testing

Reliability mechanisms require controlled failures.

Examples:

```text
Stop Redis
Stop PostgreSQL
Stop MinIO
Introduce connection refusal
Introduce delayed operation
Force retryable error
Force non-retryable error
```

The objective is to validate the system's actual response.

A failure-injection test should define:

```text
Failure
Expected detection
Expected classification
Expected handling
Expected observable signals
Expected final state
```

---

# 50. Testing Recovery

Recovery testing should verify that the system behaves correctly after a dependency becomes available again.

Example:

```text
Redis available
    │
    ▼
Operation starts
    │
    ▼
Redis failure
    │
    ▼
Retry / failure
    │
    ▼
Redis restored
    │
    ▼
Next operation succeeds
```

Recovery is not complete merely because the dependency container is running again.

The application must also be able to use the dependency successfully.

---

# 51. Testing Operational Readiness

Before a feature is considered complete, relevant operational behavior should be validated.

Questions include:

```text
Can the service be monitored?
Can failures be detected?
Can logs be correlated?
Can health be verified?
Can dependency failures be identified?
Can retry behavior be observed?
Can an operator distinguish failure domains?
```

This extends testing beyond functional correctness.

---

# 52. Test Coverage

Coverage is useful but should not be treated as the primary quality metric.

A high line-coverage percentage can still miss:

```text
Failure paths
State transitions
Dependency failures
Race conditions
Integration defects
Operational regressions
```

The more important question is:

> Are the important behavioral and architectural contracts protected?

Coverage should therefore support engineering judgment rather than replace it.

---

# 53. Test Flakiness

A flaky test is a reliability problem in the development system.

Potential causes include:

```text
Shared state
Timing assumptions
Race conditions
Network dependence
Uncontrolled retries
Random test data
Improper cleanup
Order dependence
```

A flaky test should not simply be retried until it passes.

The correct process is:

```text
Flaky Test
   │
   ▼
Reproduce
   │
   ▼
Identify nondeterminism
   │
   ▼
Remove dependency
   │
   ▼
Verify stability
```

---

# 54. Test Performance

Test speed affects developer feedback.

Tests should therefore be divided conceptually into:

```text
Fast
 └── Unit / focused tests

Medium
 └── Component / integration tests

Slow
 └── E2E / infrastructure / operational tests
```

Fast tests should provide the earliest feedback.

Slow tests should be reserved for boundaries that genuinely require them.

---

# 55. Local Test Workflow

The recommended local workflow is:

```text
┌──────────────────────────────┐
│ Modify Code                  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Run Focused Tests            │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Run Component Tests          │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Run Integration Tests        │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Run Runtime / Failure Tests  │
│ where applicable             │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Run E2E                      │
│ where applicable             │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Review Evidence              │
└──────────────┬───────────────┘
               │
               ▼
             Commit
```

---

# 56. Definition of Done for Testing

A change is not considered sufficiently tested merely because the relevant unit test passes.

The required validation level depends on the change.

## Small isolated logic change

```text
✓ Unit tests
✓ Relevant regression tests
```

## API behavior change

```text
✓ Unit/component tests
✓ API integration tests
✓ Relevant endpoint validation
```

## Database / Redis / MinIO change

```text
✓ Unit/component tests
✓ Integration tests
✓ Failure-path validation
```

## Runtime Reliability change

```text
✓ Runtime unit tests
✓ Policy tests
✓ Failure classification tests
✓ Retry tests
✓ Timeout tests where relevant
✓ Recovery tests where relevant
✓ Integration validation
```

## Worker workflow change

```text
✓ Job-level tests
✓ Queue integration
✓ Dependency integration
✓ End-to-end workflow validation where relevant
```

## Infrastructure change

```text
✓ Syntax/static validation
✓ Idempotency validation
✓ Actual execution
✓ Post-execution verification
```

## Observability change

```text
✓ Instrumentation validation
✓ Collection validation
✓ Query validation
✓ Alert/dashboard validation where relevant
```

---

# 57. Testing as an Engineering Feedback Loop

Testing should ultimately form a feedback loop:

```text
Change
  │
  ▼
Test
  │
  ▼
Evidence
  │
  ▼
Failure?
  │
 ┌┴─────────────┐
 │              │
Yes             No
 │              │
 ▼              ▼
Diagnose       Validate
 │              │
 ▼              ▼
Fix            Review
 │              │
 └──────┬───────┘
        ▼
      Commit
        │
        ▼
        CI
```

The purpose of the testing system is therefore not simply to produce a green test result.

It is to provide reliable evidence that a change preserves the system's behavioral, architectural, and operational contracts.

---

# 58. Final Testing Model

Mini-Write's testing strategy can be summarized as:

```text
                    System Change
                         │
                         ▼
                 ┌───────────────┐
                 │ Unit Tests    │
                 └───────┬───────┘
                         │
                         ▼
                 ┌───────────────┐
                 │ Component     │
                 │ Tests         │
                 └───────┬───────┘
                         │
                         ▼
                 ┌───────────────┐
                 │ Integration   │
                 │ Tests         │
                 └───────┬───────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ Runtime Reliability  │
              │ Failure / Recovery   │
              └──────────┬───────────┘
                         │
                         ▼
                 ┌───────────────┐
                 │ End-to-End    │
                 │ Tests         │
                 └───────┬───────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ Operational         │
              │ Validation          │
              └──────────┬───────────┘
                         │
                         ▼
                    CI Validation
                         │
                         ▼
                       Staging
```

The central principle is:

> **Testing in Mini-Write validates not only whether code works, but whether the system continues to satisfy its architectural, reliability, integration, and operational contracts under both normal and abnormal conditions.**

```
```
