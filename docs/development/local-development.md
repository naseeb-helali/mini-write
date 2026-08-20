# Local Development

## 1. Purpose

This document defines the standard workflow for developing and validating Mini-Write locally.

It complements:

- [`docs/development/getting-started.md`](./getting-started.md)
- [`docs/development/testing.md`](./testing.md)
- [`docs/architecture/overview.md`](../architecture/overview.md)
- [`docs/architecture/system-architecture.md`](../architecture/system-architecture.md)
- [`docs/architecture/service-architecture.md`](../architecture/service-architecture.md)
- [`docs/architecture/runtime-architecture.md`](../architecture/runtime-architecture.md)

The purpose is to establish a predictable local development environment without coupling normal development activities to the staging infrastructure.

The local environment is intended to support:

- application development;
- dependency integration;
- debugging;
- automated testing;
- runtime validation;
- observability validation;
- controlled failure testing.

---

# 2. Local Development Model

Mini-Write is composed of multiple cooperating runtime components.

The local development environment should therefore be understood as a **distributed local runtime**, not simply as an API process.

The conceptual model is:

```text
                         Local Development
                                │
             ┌──────────────────┼──────────────────┐
             │                  │                  │
             ▼                  ▼                  ▼
            API              Worker          Infrastructure
             │                  │                  │
             │                  └───────┬──────────┤
             │                          │          │
             └──────────────┬───────────┘          │
                            │                      │
                            ▼                      ▼
                         Redis                PostgreSQL
                            │
                            │
                            ▼
                           MinIO
````

The exact set of services started for a particular development task depends on the dependency requirements of that task.

---

# 3. Local vs Staging

Local development and staging have different responsibilities.

## Local

Local development optimizes for:

* fast feedback;
* controlled experimentation;
* debugging;
* isolated changes;
* repeatable testing.

## Staging

Staging optimizes for:

* deployment validation;
* infrastructure validation;
* CI/CD validation;
* operational behavior;
* production-like runtime conditions.

The distinction is:

```text
Local
  │
  ├── Developer controlled
  ├── Frequent changes
  ├── Debugging
  └── Disposable state

Staging
  │
  ├── Infrastructure controlled
  ├── Automated deployment
  ├── Operational validation
  └── Persistent environment
```

A developer should not require direct modification of the staging host during ordinary application development.

---

# 4. Local Environment Architecture

The local environment can be divided into four logical layers.

```text
┌──────────────────────────────────────────────┐
│              Development Layer               │
│                                              │
│  Source Code / Editor / Git / Test Runner    │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│                Application Layer             │
│                                              │
│                 API / Worker                 │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│              Dependency Layer                │
│                                              │
│       PostgreSQL / Redis / MinIO             │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│             Observability Layer              │
│                                              │
│       Metrics / Logs / Health Signals        │
└──────────────────────────────────────────────┘
```

Not every development task requires every layer to be active.

For example, a pure unit-test change may require neither Docker nor external dependencies.

An integration change will normally require the relevant infrastructure services.

---

# 5. Source Code Layout

The primary application components are:

```text
api/
worker/
```

Infrastructure and platform configuration are separated:

```text
infra/
observability/
```

Documentation is maintained independently:

```text
docs/
```

The root-level Compose configuration provides the containerized runtime composition.

---

# 6. Choosing a Development Mode

Before starting services, identify what kind of work is being performed.

## Mode A — Pure Application Logic

Use when working on code that does not require external infrastructure.

Typical examples:

```text
Input validation
Pure utility functions
Business logic
Transformation logic
Unit-level runtime logic
```

Preferred approach:

```text
Source Code
    │
    ▼
Focused Tests
```

There is no need to start the entire stack.

---

## Mode B — Application + Infrastructure

Use when the change interacts with:

```text
PostgreSQL
Redis
MinIO
```

Typical examples:

```text
Authentication persistence
ID upload
Queue integration
Storage operations
Database operations
```

Preferred approach:

```text
Application
    │
    ├── PostgreSQL
    ├── Redis
    └── MinIO
```

---

## Mode C — Full Runtime Validation

Use when validating:

```text
Health checks
Metrics
Logs
Runtime reliability
Container behavior
Observability
Service interaction
```

The broader local stack should be started so that the behavior can be observed as an integrated system.

---

# 7. Preparing the Local Environment

Start by verifying the repository state:

```bash
git status
```

Verify the required runtime tools:

```bash
node --version
npm --version
docker --version
docker compose version
```

If any required tool is unavailable, resolve the environment problem before debugging application behavior.

This prevents environment failures from being misclassified as application failures.

---

# 8. Installing Application Dependencies

The API and Worker maintain separate Node.js dependency definitions.

Install dependencies from the relevant service directory.

For API development:

```bash
cd api
npm install
```

For Worker development:

```bash
cd worker
npm install
```

Return to the repository root when working with the complete stack:

```bash
cd ..
```

When the repository provides lockfiles, use the lockfile-aware installation mechanism appropriate for the project's package-management workflow.

---

# 9. Configuration

Local configuration must be provided through the project's intended environment configuration mechanism.

The application should not require source-code modifications to change:

```text
Database connection
Redis connection
Object storage connection
JWT configuration
HTTP ports
Environment identity
```

The authoritative list of supported configuration variables belongs in:

```text
docs/reference/environment-variables.md
```

The local-development document describes how configuration is consumed; it does not redefine the complete configuration reference.

---

# 10. Local Secrets

Local secrets must remain outside version control.

Examples include:

```text
Database passwords
JWT secrets
MinIO credentials
Application secrets
Administrative credentials
```

A developer should verify the repository's `.gitignore` and local configuration conventions before creating local secret files.

Never use real production credentials for ordinary local development.

---

# 11. Starting Infrastructure Dependencies

When application code requires external dependencies, start the required infrastructure services through Docker Compose.

From the repository root:

```bash
docker compose up -d
```

Verify the resulting containers:

```bash
docker compose ps
```

The important distinction is:

```text
Container running
        ≠
Service healthy
        ≠
Application dependency fully usable
```

A service should therefore be validated through its health state and, when necessary, through application-level connectivity.

---

# 12. Reading Compose State

The first diagnostic command after starting the stack should normally be:

```bash
docker compose ps
```

This provides the initial view of:

* service state;
* container state;
* published ports;
* health status where configured.

If a service is unhealthy or repeatedly restarting, do not immediately restart the entire environment.

Inspect the affected service first.

---

# 13. Service Logs

To inspect a specific service:

```bash
docker compose logs <service>
```

For example:

```bash
docker compose logs api
```

```bash
docker compose logs worker
```

For real-time logs:

```bash
docker compose logs -f <service>
```

For multiple services:

```bash
docker compose logs -f api worker
```

The goal is to identify the failure domain before modifying the environment.

---

# 14. Dependency Failure Isolation

When an application service fails to start, investigate dependencies in dependency order.

For the API:

```text
API
 │
 ├── PostgreSQL
 ├── Redis
 └── MinIO
```

For the Worker:

```text
Worker
 │
 ├── Redis
 ├── PostgreSQL
 └── MinIO
```

A failure should therefore be investigated as:

```text
Application Failure
       │
       ▼
Dependency Availability
       │
       ▼
Network Connectivity
       │
       ▼
Configuration
       │
       ▼
Application Logic
```

This avoids changing application code to compensate for an infrastructure problem.

---

# 15. Starting the API Independently

The API can be developed independently when its required infrastructure dependencies are available.

From the API directory:

```bash
cd api
```

Inspect the available scripts:

```bash
cat package.json
```

Use the repository-defined development or start script rather than assuming a script name.

For example, if the project defines a development script:

```bash
npm run <defined-script>
```

The actual script name is owned by `api/package.json`.

This approach prevents the documentation from becoming coupled to an implementation detail that may change.

---

# 16. Starting the Worker Independently

The same principle applies to the Worker.

From the Worker directory:

```bash
cd worker
```

Inspect its scripts:

```bash
cat package.json
```

Then use the repository-defined script:

```bash
npm run <defined-script>
```

The Worker requires its relevant runtime dependencies, particularly Redis for queue processing.

---

# 17. API Runtime During Local Development

The API is not merely an Express application.

Requests pass through the Runtime layer before reaching the relevant operation.

The effective request path is conceptually:

```text
HTTP Request
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
Route
     │
     ▼
runtimeOperationResolution
     │
     ▼
runtimeStateActivation
     │
     ▼
Controller
     │
     ▼
Infrastructure Boundary
     │
     ▼
Dependency
```

This architecture must be preserved when debugging or modifying request processing.

---

# 18. Runtime Context

Each API request receives a Runtime execution context.

The context contains information such as:

```text
request identity
execution identity
execution state
operation
reliability policy
reliability state
failure state
user context
metadata
timestamps
```

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

The Runtime enforces legal state transitions.

A developer should therefore not manually manipulate Runtime state from application code unless that behavior belongs explicitly to the Runtime architecture.

---

# 19. Operation Resolution

API operations are explicitly represented through the Runtime operation model.

Examples include:

```text
user_register
user_login
user_profile
id_upload
health_liveness
health_readiness
```

An operation is resolved before Runtime reliability is activated.

Conceptually:

```text
Route
  │
  ▼
Operation Definition
  │
  ▼
Reliability Policy
  │
  ▼
Runtime Activation
  │
  ▼
Controller
```

When adding a new reliability-sensitive operation, the developer should evaluate whether the operation requires:

* a new operation identifier;
* a category;
* characteristics;
* a reliability policy;
* additional observability.

---

# 20. Infrastructure Boundaries

Infrastructure operations should pass through the Runtime infrastructure boundary where the Runtime architecture requires it.

The boundary provides a common execution model for:

```text
PostgreSQL
Redis
MinIO
```

Conceptually:

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
    ├── Retry
    └── Recovery Tracking
    │
    ▼
Dependency
```

This prevents each controller from implementing independent reliability semantics.

---

# 21. Local Reliability Testing

Reliability behavior should be tested deliberately.

Examples include:

```text
Dependency unavailable
Dependency connection refused
Operation timeout
Transient failure
Retry
Retry exhaustion
Non-retryable failure
Recovery after retry
```

The important model is:

```text
Failure
   │
   ▼
Classification
   │
   ▼
Retry Decision
   │
   ├── Retry
   │     │
   │     ▼
   │   Backoff
   │     │
   │     ▼
   │   Next Attempt
   │
   └── Fail
```

Do not add arbitrary retry loops inside business logic to simulate reliability behavior.

Reliability behavior should remain aligned with the Runtime policy model.

---

# 22. Testing Dependency Failures Locally

A controlled dependency failure can be simulated by stopping the relevant dependency.

For example:

```bash
docker compose stop redis
```

Then observe the application's behavior.

After the experiment:

```bash
docker compose start redis
```

The purpose is to verify:

```text
Failure Detection
Failure Classification
Error Propagation
Retry Behavior
Recovery Behavior
Observability
```

Such experiments should be performed only in the local environment.

---

# 23. Testing API Health

The API exposes:

```text
/health/live
/health/ready
```

The liveness endpoint represents process-level availability.

The readiness endpoint performs dependency-oriented health verification.

When testing locally, validate the distinction:

```text
Process alive
      │
      ▼
/health/live
```

versus:

```text
Required dependencies available
      │
      ▼
/health/ready
```

A dependency failure should not automatically be interpreted as a process failure.

---

# 24. Testing Metrics

The API exposes:

```text
/metrics
```

When the API is running, inspect the endpoint through the local HTTP interface configured by the environment.

The output should contain Prometheus-compatible metrics.

Runtime-related behavior can be validated by looking for the corresponding runtime metrics after:

* successful operations;
* failed operations;
* retries;
* dependency failures.

The observability architecture is documented in:

```text
docs/observability/
```

---

# 25. Local Logging

API and Worker logs are structured JSON logs.

A useful development log should make it possible to determine:

```text
What happened?
Where did it happen?
Which service?
Which request?
Which operation?
Which dependency?
Which failure?
```

For Runtime-aware API operations, request and execution identities provide correlation.

When adding logs, preserve the existing structured logging convention.

Avoid introducing diagnostic information exclusively as unstructured text when it can be represented as a structured field.

---

# 26. Debugging Through Evidence

A production-oriented development workflow should avoid relying solely on assumptions.

Use observable evidence:

```text
             Failure
                │
       ┌────────┼────────┐
       ▼        ▼        ▼
      Logs    Metrics   Health
       │        │        │
       └────────┼────────┘
                ▼
          Failure Domain
```

For example, if an API request is slow:

```text
HTTP latency
    │
    ▼
API logs
    │
    ▼
Runtime operation
    │
    ▼
Dependency
    │
    ▼
Database / Redis / MinIO
```

This is more reliable than changing application code based only on the visible symptom.

---

# 27. Working With Persistent Local State

The Compose environment uses persistent volumes for stateful services.

Conceptually:

```text
PostgreSQL ──► postgres_data
Redis      ──► redis_data
MinIO      ──► minio_data
```

Therefore:

```bash
docker compose down
```

does not necessarily mean:

```text
Clean application state
```

Persistent volumes can survive container recreation.

This is intentional because state persistence is part of the runtime model.

---

# 28. Resetting Local State

A destructive reset should be performed only when intentionally required.

The conceptual operation is:

```text
Containers
   +
Persistent Volumes
   │
   ▼
Local State Reset
```

Removing volumes can destroy:

* database records;
* Redis state;
* uploaded objects;
* other persistent local data.

Therefore, before using destructive Compose cleanup, verify that the local data can be safely discarded.

---

# 29. Reproducing a Clean Environment

When a bug appears state-dependent, reproduce it using a clean local environment.

The investigation should distinguish between:

```text
Code defect
Configuration defect
Persistent-state defect
Dependency-state defect
Environment defect
```

A useful diagnostic sequence is:

```text
Existing State
     │
     ▼
Reproduce
     │
     ▼
Reset State
     │
     ▼
Reproduce Again
     │
     ▼
Compare Behavior
```

This can identify defects that are caused by stale local state rather than source code.

---

# 30. Development With the Worker Queue

The Worker is asynchronous.

The typical local workflow is:

```text
Client
  │
  ▼
API
  │
  ▼
Redis Queue
  │
  ▼
Worker
  │
  ▼
Processing
```

When debugging an asynchronous operation, inspect all stages.

Do not stop at:

```text
API returned 200
```

A successful API response may mean only that the job was successfully enqueued.

The actual background operation must be validated separately.

---

# 31. Debugging Asynchronous Workflows

For an asynchronous workflow, investigate:

```text
1. Was the request accepted?
2. Was the infrastructure operation successful?
3. Was the job enqueued?
4. Did Redis receive the job?
5. Did the Worker consume it?
6. Did processing succeed?
7. Was the resulting state persisted?
8. Were failures observable?
```

The effective workflow is:

```text
Request
  │
  ▼
Upload
  │
  ▼
Database Update
  │
  ▼
Queue Enqueue
  │
  ▼
Worker
  │
  ▼
Processing
  │
  ▼
Final State
```

Each stage represents a possible failure boundary.

---

# 32. Local Observability Stack

When full observability is required, the project provides the observability platform defined under:

```text
observability/
```

The platform includes:

```text
Prometheus
Loki
Grafana
Alertmanager
Promtail
Node Exporter
cAdvisor
Redis Exporter
PostgreSQL Exporter
```

The local Compose environment may expose these services according to the active Compose configuration.

Do not assume that every observability component must be started for every development task.

---

# 33. Observability Development Scenarios

Use the observability stack when developing or validating:

```text
Metric instrumentation
Logging changes
Alert rules
Dashboard queries
Runtime reliability metrics
Infrastructure metrics
Service health
```

For a simple controller unit test, starting Grafana and Loki provides little value.

For an observability change, however, they become part of the validation environment.

---

# 34. Local Development and Infrastructure Code

Application development and Infrastructure as Code should remain conceptually separated.

Application changes normally occur in:

```text
api/
worker/
```

Infrastructure changes occur in:

```text
infra/
```

Observability platform configuration occurs in:

```text
observability/
```

A developer should modify infrastructure configuration only when the requirement actually belongs to infrastructure.

For example:

```text
New API endpoint
    → API code

New runtime policy
    → Runtime code

New Docker service
    → Compose / infrastructure

New Prometheus alert
    → Observability rules

New Grafana dashboard
    → Observability dashboards
```

This preserves ownership boundaries.

---

# 35. Local Docker Development

Docker is useful for reproducing the service topology and dependency environment.

The local container model includes concerns such as:

```text
Networks
Volumes
Health Checks
Resource Limits
Restart Policies
Service Dependencies
```

When debugging a containerized service, distinguish between:

```text
Application process
Container
Docker network
Dependency
Host
```

A failure in one layer does not automatically imply a failure in another.

---

# 36. Container Networking

Services communicate through Docker networks rather than through assumptions about localhost.

For example:

```text
API ─────────► PostgreSQL
 │
 ├───────────► Redis
 │
 └───────────► MinIO
```

Inside the Compose network, service names are used as network identities.

Therefore, application configuration should use the appropriate Compose service address rather than assuming that a dependency is running on the developer's host loopback interface.

---

# 37. Local Port Mapping

Published ports provide host-level access to selected container services.

The correct ports are defined by the active Compose configuration.

Developers should inspect:

```bash
docker compose ps
```

rather than assuming that every internal service port is directly exposed to the host.

This distinction matters:

```text
Container-to-container port
        ≠
Host-published port
```

---

# 38. Development Workflow for API Changes

A recommended API workflow is:

```text
1. Read the relevant controller / route.
2. Identify the Runtime operation.
3. Identify dependencies used by the operation.
4. Make the smallest required change.
5. Run focused tests.
6. Start required local dependencies.
7. Run the API.
8. Exercise the affected endpoint.
9. Inspect logs.
10. Inspect metrics when relevant.
11. Validate health.
12. Run broader tests.
13. Review the Git diff.
```

This keeps implementation and operational validation connected.

---

# 39. Development Workflow for Worker Changes

A recommended Worker workflow is:

```text
1. Identify the queue and job lifecycle.
2. Identify dependency interactions.
3. Identify Worker Runtime behavior.
4. Make the smallest required change.
5. Run focused tests.
6. Start Redis and required dependencies.
7. Start the Worker.
8. Produce a representative job.
9. Observe job processing.
10. Inspect Worker logs.
11. Inspect queue metrics.
12. Validate failure behavior if relevant.
13. Run broader tests.
14. Review the Git diff.
```

The asynchronous nature of Worker execution makes end-to-end validation particularly important.

---

# 40. Development Workflow for Runtime Changes

Runtime changes have a larger blast radius.

A change to:

```text
executionContext
runtimeBootstrap
runtimeGuard
runtimeOperationResolution
runtimeStateActivation
failureClassifier
policyResolver
retryExecutor
infrastructureBoundary
```

can affect multiple API operations.

The recommended workflow is:

```text
Runtime Change
     │
     ▼
Focused Runtime Tests
     │
     ▼
Affected Operation Tests
     │
     ▼
Infrastructure Failure Tests
     │
     ▼
Observability Validation
     │
     ▼
Full Regression
```

Runtime changes should not be validated only through the happy path.

---

# 41. Development Workflow for Observability Changes

For changes to metrics, logs, alerts, or dashboards:

```text
Change Instrumentation
       │
       ▼
Generate Representative Event
       │
       ▼
Verify Raw Signal
       │
       ▼
Verify Collection
       │
       ▼
Verify Query
       │
       ▼
Verify Visualization / Alert
```

For example, adding a metric should not be considered complete merely because the application compiles.

The metric must be:

```text
registered
   │
   ▼
updated
   │
   ▼
exported
   │
   ▼
scraped
```

where applicable.

---

# 42. Troubleshooting Method

When local development fails, use a structured investigation.

## Step 1 — Identify the Failure Layer

Determine whether the problem belongs to:

```text
Code
Runtime
Configuration
Container
Network
Dependency
Host
Observability
```

## Step 2 — Gather Evidence

Inspect:

```text
docker compose ps
docker compose logs
application logs
health endpoints
metrics
```

## Step 3 — Reproduce

Determine whether the failure is:

```text
Always reproducible
Intermittent
State-dependent
Environment-dependent
```

## Step 4 — Isolate

Reduce the system to the smallest failing path.

## Step 5 — Change One Variable

Avoid changing multiple configuration or code paths simultaneously.

## Step 6 — Revalidate

Confirm that the original behavior changed for the expected reason.

---

# 43. Common Local Development Failure Patterns

## Container Is Running but Application Is Unavailable

Check:

```text
Container status
Health status
Application logs
Published port
Application listening port
```

---

## API Starts but Requests Fail

Check:

```text
Runtime initialization
Operation resolution
Reliability policy
Dependency connectivity
Controller logs
```

---

## API Returns Success but Background Work Does Not Complete

Check:

```text
Redis
Queue
Worker
Worker logs
Job metrics
```

---

## Retries Do Not Occur

Check:

```text
Operation policy
retry enabled
maxRetries
recoverable
failure classification
```

Do not assume that a transient dependency failure automatically results in a retry.

Retry behavior is policy- and classification-dependent.

---

## Health Readiness Fails

Check:

```text
Required dependency
Dependency health
Connection configuration
Application health service
```

Do not interpret readiness failure as necessarily meaning that the application process has crashed.

---

# 44. Avoiding Configuration Drift

Local configuration should remain understandable and reproducible.

Avoid undocumented changes such as:

```text
Manual container configuration
Manual dependency installation inside containers
Undocumented environment variables
Local source modifications used only to make the stack start
```

If a configuration change is genuinely required by the project, it should be represented in the appropriate repository configuration and documented.

---

# 45. Avoiding Environment-Specific Code

Application code should not contain development-only workarounds merely because they simplify local execution.

Avoid patterns such as:

```text
if (development) {
    bypass reliability;
}
```

or:

```text
if (local) {
    skip dependency verification;
}
```

unless the behavior is an explicit architectural requirement.

The local environment should expose the same fundamental application semantics while allowing development-specific configuration where appropriate.

---

# 46. Reproducibility

A local environment should be reproducible from repository-controlled configuration.

The target model is:

```text
Repository
     +
Declared Dependencies
     +
Environment Configuration
     +
Docker Compose
     │
     ▼
Repeatable Local Runtime
```

Manual undocumented setup steps should be minimized.

If a developer needs a special manual step to make the system work, that step should be investigated rather than silently becoming part of the development process.

---

# 47. Local Development and CI

Local validation should approximate the checks performed by CI where practical.

The relationship is:

```text
Developer
    │
    ▼
Local Tests
    │
    ▼
Git Commit
    │
    ▼
CI
    │
    ▼
Staging
```

Local success does not guarantee CI success.

CI may additionally validate:

* clean installation;
* reproducibility;
* repository state;
* automated tests;
* build behavior;
* deployment-related constraints.

Therefore, CI remains an independent validation boundary.

---

# 48. Before Committing

Before committing a change:

```bash
git status
```

Review:

```bash
git diff
```

Confirm:

```text
No unintended files
No secrets
No generated artifacts that should not be committed
No unrelated changes
```

Then run the appropriate tests.

For larger changes, also validate the relevant runtime behavior.

---

# 49. Stopping the Development Environment

When development is complete, stop the local stack:

```bash
docker compose down
```

Do not automatically remove volumes unless local persistent state is intentionally being discarded.

If the environment is expected to remain available for continued development, leaving the stack running may be appropriate.

---

# 50. Local Development Completion Criteria

A development task should be considered locally validated when the relevant criteria have been satisfied.

For an application change:

```text
✓ Code compiles / loads.
✓ Focused tests pass.
✓ Relevant service tests pass.
✓ Required dependencies work.
✓ Relevant endpoint / workflow works.
✓ Logs contain expected behavior.
✓ Runtime behavior is correct where applicable.
✓ Metrics remain valid where applicable.
✓ No unintended regressions are observed.
```

For a Runtime Reliability change:

```text
✓ Happy path works.
✓ Failure classification works.
✓ Retry behavior is correct where enabled.
✓ Retry limits are respected.
✓ Timeout behavior is correct.
✓ Failure propagation remains intact.
✓ Recovery state is correct.
✓ Runtime metrics are emitted.
✓ Runtime logs remain correlated.
```

For an observability change:

```text
✓ Signal is generated.
✓ Signal is collected.
✓ Signal is queryable.
✓ Labels remain appropriate.
✓ Cardinality is controlled.
✓ Dashboard / alert behavior is correct where applicable.
```

---

# 51. Final Local Development Model

The complete local development lifecycle is:

```text
                    Repository
                        │
                        ▼
                 Local Configuration
                        │
                        ▼
                  Dependencies
                        │
                        ▼
              ┌───────────────────┐
              │ Application       │
              │ API / Worker      │
              └─────────┬─────────┘
                        │
            ┌───────────┼───────────┐
            ▼           ▼           ▼
          Tests       Health       Runtime
            │           │           │
            └───────────┼───────────┘
                        ▼
                  Observability
                        │
                        ▼
                     Evidence
                        │
                        ▼
                    Validation
                        │
                        ▼
                      Commit
                        │
                        ▼
                       CI
```

The central principle is:

> **Local development should provide a reproducible environment in which application behavior, infrastructure dependencies, Runtime Reliability, and observability can be developed and validated independently and together.**

The local environment is therefore not merely a place to run the application. It is the first controlled validation boundary before a change enters CI/CD and staging.

```
```
