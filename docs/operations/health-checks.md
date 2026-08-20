# Health Checks

## 1. Purpose

This document defines the health-check model used by the Mini-Write platform.

It explains:

- what "healthy" means at each architectural layer;
- the difference between liveness and readiness;
- how API health is exposed;
- how Worker health is evaluated;
- how infrastructure dependencies are verified;
- how Prometheus participates in health monitoring;
- how operators should interpret health failures;
- how health checks should be used during deployment, operations, and incidents.

The purpose is to establish a consistent operational answer to:

> **Is the system alive, ready, and actually capable of performing its intended work?**

---

# 2. Health Is Not a Single Signal

A running process is not necessarily a healthy service.

Mini-Write therefore treats health as a layered property:

```text
                    System Health
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
       Host Health   Service Health   Dependency Health
          │              │              │
          │              │              │
          ▼              ▼              ▼
       Resources       Liveness       PostgreSQL
       Docker          Readiness      Redis
       Network                        MinIO
          │              │              │
          └──────────────┼──────────────┘
                         ▼
                  Behavioral Health
                         │
                         ▼
                  Operational Health
````

A service should therefore not be declared healthy based only on:

```text
container == running
```

or:

```text
process == alive
```

---

# 3. Health Model

Mini-Write uses five practical health dimensions:

| Dimension         | Question                                         |
| ----------------- | ------------------------------------------------ |
| Process health    | Is the process running?                          |
| Liveness          | Is the service alive?                            |
| Readiness         | Can the service safely serve its responsibility? |
| Dependency health | Are required dependencies available?             |
| Behavioral health | Is the system actually performing useful work?   |

These dimensions are complementary.

---

# 4. Health Hierarchy

The operational hierarchy is:

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
Liveness
  │
  ▼
Readiness
  │
  ▼
Dependency Health
  │
  ▼
Behavioral Health
```

Failure at a lower layer can invalidate higher layers.

For example:

```text
PostgreSQL unavailable
        │
        ▼
API readiness degraded
        │
        ▼
Application functionality degraded
```

However, the reverse is not necessarily true.

An API can be alive even when PostgreSQL is unavailable.

---

# 5. Liveness vs Readiness

The most important distinction in the health model is:

```text
Liveness ≠ Readiness
```

### Liveness

Answers:

> Is the application process alive and capable of responding to a basic health request?

### Readiness

Answers:

> Is the application currently ready to provide its required functionality?

This distinction prevents a dependency failure from being incorrectly interpreted as a process failure.

---

# 6. API Health Endpoints

The API exposes two dedicated health endpoints:

```text
GET /health/live
GET /health/ready
```

They represent different operational contracts.

```text
/health/live
     │
     ▼
Process / application liveness

/health/ready
     │
     ▼
Application readiness
     │
     ▼
System dependency verification
```

---

# 7. Liveness Probe

The API liveness endpoint is:

```text
GET /health/live
```

The route is associated with the runtime operation:

```text
health_liveness
```

and belongs to:

```text
health
```

operation category.

The runtime reliability policy for liveness is:

```text
timeout: 1000ms
retry: false
maxRetries: 0
recoverable: false
```

The endpoint itself returns:

```json
{
  "status": "UP",
  "message": "Service is alive"
}
```

with HTTP status:

```text
200 OK
```

---

# 8. Liveness Semantics

The liveness probe is intentionally lightweight.

It does not perform a complete dependency verification.

Therefore:

```text
/health/live = 200
```

means approximately:

> The API process is alive and capable of executing the liveness endpoint.

It does **not** mean:

> PostgreSQL, Redis, MinIO, and the complete application workflow are healthy.

---

# 9. Why Liveness Must Remain Lightweight

A liveness probe should not normally depend on external infrastructure.

Consider:

```text
PostgreSQL failure
      │
      ▼
Liveness depends on PostgreSQL
      │
      ▼
Liveness fails
      │
      ▼
Container restarted
      │
      ▼
PostgreSQL still unavailable
      │
      ▼
Repeated restarts
```

This creates a restart loop without addressing the dependency failure.

The Mini-Write liveness endpoint avoids this design.

---

# 10. Readiness Probe

The API readiness endpoint is:

```text
GET /health/ready
```

The route is associated with:

```text
health_readiness
```

and:

```text
health
```

operation category.

The runtime operation definition indicates:

```text
requiresDatabase: true
```

The readiness policy is:

```text
timeout: 3000ms
retry: false
maxRetries: 0
recoverable: false
```

---

# 11. Readiness Semantics

The readiness endpoint calls:

```text
getSystemHealth()
```

The result determines the HTTP response.

If:

```text
health.status === "UP"
```

the endpoint returns:

```text
HTTP 200
```

with the health result.

Otherwise it returns:

```text
HTTP 503
```

with the health result.

An unexpected exception produces:

```text
HTTP 500
```

with:

```json
{
  "status": "DOWN",
  "error": "<error message>"
}
```

---

# 12. Readiness State Model

The readiness semantics can therefore be represented as:

```text
                  Readiness Request
                         │
                         ▼
                  getSystemHealth()
                         │
              ┌──────────┴──────────┐
              │                     │
          status=UP             status!=UP
              │                     │
              ▼                     ▼
          HTTP 200               HTTP 503
              │                     │
              └──────────┬──────────┘
                         │
                    Unexpected
                      exception
                         │
                         ▼
                     HTTP 500
```

---

# 13. Health Status Interpretation

The HTTP response should be interpreted together with the returned body.

### `200 OK`

Indicates:

```text
Application health verification succeeded.
```

### `503 Service Unavailable`

Indicates:

```text
The application is alive enough to answer,
but the required system health condition is not satisfied.
```

### `500 Internal Server Error`

Indicates:

```text
The health-check execution itself encountered
an unexpected failure.
```

---

# 14. Runtime Integration

Health endpoints are not bypassing the Runtime architecture.

The request flow is:

```text
HTTP Request
     │
     ▼
runtimeBootstrap
     │
     ▼
Execution Context Created
     │
     ▼
runtimeGuard
     │
     ▼
runtimeOperationResolution
     │
     ▼
Operation Attached
     │
     ▼
Reliability Policy Attached
     │
     ▼
runtimeStateActivation
     │
     ▼
Reliability Activated
     │
     ▼
Execution Activated
     │
     ▼
Health Handler
```

This ensures health operations participate in the same runtime lifecycle as other API operations.

---

# 15. Runtime Health Lifecycle

For a normal health request:

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

The Runtime Completion Observer also ensures that an incomplete request context is completed when the HTTP response finishes.

Therefore health requests contribute to the Runtime lifecycle and its operational telemetry.

---

# 16. Health Operation Identity

Health operations have explicit identities:

```text
health_liveness
health_readiness
```

This is important because health traffic should be distinguishable from business traffic.

For example:

```text
API traffic
 ├── user_login
 ├── user_register
 ├── user_profile
 ├── id_upload
 ├── health_liveness
 └── health_readiness
```

This allows runtime logs and telemetry to identify the source of an operation.

---

# 17. Health Operation Policies

The current health reliability policies are intentionally conservative.

## Liveness

```text
timeout = 1s
retry = false
maxRetries = 0
recoverable = false
```

## Readiness

```text
timeout = 3s
retry = false
maxRetries = 0
recoverable = false
```

This is appropriate for health probes because retrying a health probe internally can hide the actual health state and increase probe latency.

---

# 18. Worker Health

The Worker does not use the API's HTTP liveness/readiness model as its primary operational health mechanism.

The Worker is an asynchronous processing runtime.

Its health must therefore be evaluated using its operational behavior.

Important Worker signals include:

```text
Worker availability
Queue depth
Active jobs
Processed jobs
Failed jobs
Retried jobs
Job duration
```

The Worker health model is therefore:

```text
Worker Process
     │
     ▼
Metrics Endpoint
     │
     ▼
Prometheus
     │
     ├── Availability
     ├── Queue behavior
     ├── Processing behavior
     └── Failure behavior
```

---

# 19. Worker Availability

Prometheus monitors the Worker through:

```text
job="worker"
```

The configured target is:

```text
worker:9464
```

with:

```text
metrics_path: /metrics
```

The corresponding alert is:

```text
MWWorkerDown
```

Its condition is:

```promql
up{job="worker"} == 0
```

for:

```text
2 minutes
```

This indicates that Prometheus cannot scrape the Worker metrics endpoint.

---

# 20. Worker Availability Is Not Complete Worker Health

A Worker scrape target being available does not prove that jobs are being processed correctly.

For example:

```text
Worker process
     │
     ▼
/metrics available
     │
     ▼
Prometheus sees UP
     │
     ▼
Queue processing may still be degraded
```

Therefore Worker availability must be combined with behavioral metrics.

---

# 21. Queue Health

Queue health is represented by:

```text
mw_worker_queue_depth
```

A growing queue can indicate:

```text
Insufficient processing capacity
Worker degradation
Redis problems
Slow job execution
Dependency latency
```

The current alert is:

```text
MWQueueBacklogHigh
```

with:

```promql
sum(mw_worker_queue_depth) > 10
```

for:

```text
10 minutes
```

---

# 22. Queue Health Interpretation

A queue backlog should be interpreted as a trend rather than a single instantaneous value.

For example:

```text
Queue depth:
2 → 4 → 7 → 12 → 18 → 27
```

is more concerning than:

```text
Queue depth:
2 → 12 → 3
```

The first indicates sustained processing pressure.

The second may represent a temporary burst that the Worker successfully absorbed.

---

# 23. Worker Processing Health

Worker processing health is measured through:

```text
mw_worker_jobs_processed_total
mw_worker_job_failures_total
mw_worker_jobs_retried_total
mw_worker_jobs_active
mw_worker_queue_depth
mw_worker_job_duration_seconds
```

These metrics allow operators to distinguish:

```text
Worker unavailable
```

from:

```text
Worker available but ineffective
```

---

# 24. Worker Failure Rate

The current Worker alert:

```text
MWHighJobFailureRate
```

evaluates the relationship between failed and processed jobs.

The threshold is:

```text
> 10%
```

for:

```text
5 minutes
```

The operational meaning is:

> Background processing reliability is degraded.

Investigation should then move toward:

```text
Worker logs
Image processing
PostgreSQL
MinIO
Redis
Host resources
```

---

# 25. Worker Processing Latency

The Worker exposes job-duration histogram metrics.

The alert:

```text
MWHighJobLatency
```

evaluates the 95th percentile.

The threshold is:

```text
P95 > 5 seconds
```

for:

```text
5 minutes
```

High processing latency can indicate:

```text
CPU pressure
Storage latency
Database latency
Image-processing degradation
Dependency degradation
```

---

# 26. Dependency Health

The primary dependencies are:

```text
PostgreSQL
Redis
MinIO
```

Their operational relationship is:

```text
API
 ├── PostgreSQL
 ├── Redis
 └── MinIO

Worker
 ├── Redis
 ├── PostgreSQL
 └── MinIO
```

Not every operation depends on every dependency.

Therefore dependency health should be evaluated in the context of the affected operation.

---

# 27. PostgreSQL Health

PostgreSQL is monitored through:

```text
postgres-exporter
```

Prometheus target:

```text
postgres-exporter:9187
```

Operational checks should consider:

```text
Exporter availability
Database container health
Connection failures
Database latency
Host resources
Disk capacity
Persistent volume health
```

A PostgreSQL exporter being available does not necessarily prove every application query is healthy.

---

# 28. Redis Health

Redis is monitored through:

```text
redis-exporter
```

Prometheus target:

```text
redis-exporter:9121
```

Redis health is particularly important to the Worker because queue processing depends on Redis.

Operational investigation should therefore correlate:

```text
Redis health
+
Worker availability
+
Queue depth
+
Job processing
```

---

# 29. MinIO Health

MinIO is a required storage dependency for the upload and background-processing workflows.

Its operational health should be evaluated through:

```text
Container state
Application behavior
Worker storage metrics
Logs
Host storage
```

The Worker exposes storage-operation latency metrics, and the current alert:

```text
MWHighStorageLatency
```

fires when the 95th percentile storage latency exceeds:

```text
2 seconds
```

for:

```text
10 minutes
```

---

# 30. Database Latency Health

The Worker exposes database-operation duration metrics.

The alert:

```text
MWHighDatabaseLatency
```

fires when:

```text
P95 > 0.5 seconds
```

for:

```text
10 minutes
```

This is a behavioral health signal rather than a simple process availability signal.

A database can therefore be:

```text
UP
```

while still being operationally degraded because its latency is excessive.

---

# 31. Host Health

Host health is monitored through Node Exporter.

Prometheus target:

```text
node-exporter:9100
```

Important host health dimensions include:

```text
CPU
Memory
Disk
Filesystem
```

The current infrastructure alerts include:

```text
MWNodeExporterDown
MWHighCPUUsage
MWHighMemoryUsage
MWLowDiskSpace
```

---

# 32. CPU Health

The current alert threshold is:

```text
CPU utilization > 90%
```

for:

```text
10 minutes
```

Sustained CPU pressure can affect:

```text
API latency
Worker processing
Database performance
Observability services
Docker responsiveness
```

CPU should therefore be correlated with service-level symptoms.

---

# 33. Memory Health

The current memory alert threshold is:

```text
Memory utilization > 90%
```

for:

```text
10 minutes
```

High memory pressure may result in:

```text
OOM events
Container termination
Performance degradation
Swap pressure
```

Memory investigation should include both host and container-level consumption.

---

# 34. Disk Health

The current infrastructure alert fires when available filesystem capacity falls below:

```text
10%
```

for:

```text
10 minutes
```

Disk pressure is especially important because persistent data is used by:

```text
PostgreSQL
MinIO
Prometheus
Loki
Docker
```

A disk incident can therefore create apparently unrelated service failures.

---

# 35. Prometheus Target Health

Prometheus exposes the standard target availability signal:

```text
up
```

A target value of:

```text
1
```

generally means Prometheus successfully scraped the target.

A value of:

```text
0
```

means the scrape failed.

This is useful for detecting:

```text
Service unavailable
Exporter unavailable
Network connectivity failure
Metrics endpoint failure
```

However:

> `up == 1` does not prove application correctness.

---

# 36. Target Health vs Service Health

This distinction is critical.

```text
Prometheus Target Health
        │
        ▼
Can Prometheus scrape metrics?
```

while:

```text
Service Health
        │
        ▼
Can the service perform its intended responsibility?
```

Therefore:

```text
up == 1
```

is evidence of telemetry endpoint availability, not complete service correctness.

---

# 37. Observability Health

The observability stack itself has health signals.

Prometheus monitors:

```text
Prometheus
Loki
Alertmanager
API
Worker
Exporters
```

The relevant targets include:

```text
job="prometheus"
job="loki"
job="alertmanager"
job="api"
job="worker"
job="redis"
job="postgres"
job="node"
job="cadvisor"
```

Loss of an observability component can reduce diagnostic capability even when application services remain healthy.

---

# 38. Health Check Failure Classification

Operationally, health failures can be grouped into:

```text
1. Process failure
2. Container failure
3. Network failure
4. Dependency failure
5. Resource failure
6. Application failure
7. Behavioral degradation
8. Observability failure
```

The classification should be based on evidence.

---

# 39. Example: API Container Down

Observed:

```text
up{job="api"} == 0
```

Investigation:

```text
Prometheus
   │
   ▼
API target unavailable
   │
   ▼
Container state
   │
   ├── stopped
   ├── restarting
   └── running
```

If the container is stopped, inspect:

```text
Container logs
Exit code
Restart history
Recent deployment
Configuration
```

The initial symptom is:

```text
API unavailable
```

but the root cause may be:

```text
Application startup
Configuration
Dependency
Image
Host resource
```

---

# 40. Example: API Liveness Passes, Readiness Fails

Observed:

```text
/health/live  → 200
/health/ready → 503
```

Interpretation:

```text
API process is alive
        │
        ▼
Readiness condition is not satisfied
```

The next investigation should focus on the health dependencies rather than restarting the API immediately.

This is one of the primary reasons for maintaining separate liveness and readiness semantics.

---

# 41. Example: Worker Is UP but Queue Grows

Observed:

```text
up{job="worker"} == 1
```

but:

```text
mw_worker_queue_depth
```

continues increasing.

Interpretation:

```text
Worker process is reachable
        │
        ▼
Worker is not keeping up with workload
```

Investigate:

```text
Job duration
Job failure rate
Retries
CPU
Memory
Redis
PostgreSQL
MinIO
```

This is a behavioral degradation rather than a simple availability failure.

---

# 42. Example: High Storage Latency

Observed:

```text
MWHighStorageLatency
```

Possible chain:

```text
Worker
   │
   ▼
Storage operation slow
   │
   ├── MinIO
   ├── Network
   ├── Host disk
   └── Resource pressure
```

The correct response is not automatically to restart the Worker.

First establish whether the storage dependency or host is responsible.

---

# 43. Example: Host Disk Pressure

Observed:

```text
MWLowDiskSpace
```

Potential impact:

```text
Host disk pressure
      │
      ├── Docker
      ├── PostgreSQL
      ├── MinIO
      ├── Loki
      └── Prometheus
```

This is potentially a system-wide failure domain.

The incident should therefore be treated with higher scope than a single application-container failure.

---

# 44. Health Checks During Deployment

Health verification is mandatory after deployment.

The minimum sequence is:

```text
Deployment
   │
   ▼
Container state
   │
   ▼
API liveness
   │
   ▼
API readiness
   │
   ▼
Worker availability
   │
   ▼
Dependency health
   │
   ▼
Prometheus targets
   │
   ▼
Logs / errors
```

A deployment should not be considered operationally successful merely because the deployment command exits successfully.

---

# 45. Health Checks During Rollback

Rollback requires the same verification process as deployment.

```text
Rollback
   │
   ▼
Container state
   │
   ▼
API liveness
   │
   ▼
API readiness
   │
   ▼
Worker
   │
   ▼
Dependencies
   │
   ▼
Metrics
   │
   ▼
Logs
```

Rollback success means:

> The system returned to an acceptable operational state.

It does not merely mean:

> The previous image was started.

---

# 46. Health Checks During Incidents

During an incident, health checks should establish three states:

```text
Before remediation
        │
        ▼
During remediation
        │
        ▼
After remediation
```

This makes it possible to determine whether the action actually changed system behavior.

---

# 47. Health Check Frequency

Different health signals have different operational time scales.

| Signal          | Typical interpretation       |
| --------------- | ---------------------------- |
| Liveness        | Immediate process state      |
| Readiness       | Immediate service capability |
| Prometheus `up` | Scrape availability          |
| CPU / memory    | Sustained resource pressure  |
| Queue depth     | Workload pressure            |
| Error rate      | Behavioral degradation       |
| Latency         | Performance degradation      |

The alerting rules intentionally use `for` windows to avoid treating every transient fluctuation as an incident.

---

# 48. Avoiding False Positives

A health system should distinguish:

```text
Transient anomaly
```

from:

```text
Sustained degradation
```

For example:

```text
CPU > 90%
```

for a few seconds does not necessarily indicate a sustained infrastructure problem.

The infrastructure alert therefore requires:

```text
10 minutes
```

of sustained violation.

Similarly, service availability alerts require:

```text
2 minutes
```

before triggering.

---

# 49. Health Signal Correlation

A strong operational diagnosis uses multiple signals.

Example:

```text
API latency ↑
       │
       ├── CPU ↑
       ├── PostgreSQL latency ↑
       └── Worker normal
```

This points toward a likely database/resource issue rather than a general application outage.

Another example:

```text
Worker queue depth ↑
       │
       ├── Worker UP
       ├── Job latency ↑
       └── MinIO latency ↑
```

This points toward storage-related processing degradation.

---

# 50. Health Check Decision Tree

```text
Is the host available?
       │
       ├── NO ──► Host incident
       │
       └── YES
             │
             ▼
      Is container running?
             │
        ┌────┴────┐
        NO        YES
        │          │
        ▼          ▼
   Container     Is service
    incident     reachable?
                     │
                ┌────┴────┐
                NO        YES
                │          │
                ▼          ▼
             Service     Is it ready?
             incident        │
                         ┌───┴───┐
                         NO      YES
                         │        │
                         ▼        ▼
                    Dependency   Check
                    / config    behavior
                    issue          │
                                   ▼
                              Healthy /
                              Degraded
```

This is a diagnostic model rather than an automated decision procedure.

---

# 51. Health Verification Checklist

## Host

```text
[ ] Host reachable
[ ] Docker available
[ ] CPU within expected range
[ ] Memory within expected range
[ ] Disk capacity sufficient
```

## Containers

```text
[ ] Required containers running
[ ] No unexpected restart loops
[ ] Health checks passing where configured
```

## API

```text
[ ] /health/live returns 200
[ ] /health/ready returns 200
[ ] No abnormal error rate
[ ] Latency within expected range
```

## Worker

```text
[ ] Worker metrics endpoint reachable
[ ] Prometheus reports worker UP
[ ] Queue depth acceptable
[ ] Job failure rate acceptable
[ ] Job latency acceptable
[ ] No abnormal retry behavior
```

## Dependencies

```text
[ ] PostgreSQL healthy
[ ] Redis healthy
[ ] MinIO healthy
```

## Observability

```text
[ ] Prometheus healthy
[ ] Targets being scraped
[ ] Loki healthy
[ ] Promtail running
[ ] Grafana available
[ ] Alertmanager available
```

---

# 52. Health Verification After a Configuration Change

After changing configuration:

```text
1. Verify container startup.
2. Verify API liveness.
3. Verify API readiness.
4. Verify Worker availability.
5. Verify dependencies.
6. Verify Prometheus targets.
7. Inspect logs for configuration errors.
8. Verify expected behavior.
```

Configuration validity is therefore both:

```text
syntactic
```

and:

```text
operational
```

A configuration can be syntactically valid while still causing runtime degradation.

---

# 53. Health Verification After Infrastructure Changes

Infrastructure changes require broader verification.

Examples:

```text
Firewall change
Docker change
Host provisioning
SSH change
Filesystem change
Resource change
Network change
```

Verification should include:

```text
Host
   │
   ▼
Docker
   │
   ▼
Networks
   │
   ▼
Containers
   │
   ▼
Application
   │
   ▼
Observability
```

---

# 54. Health and Runtime Reliability

API health requests participate in the Runtime reliability architecture.

The Runtime maintains:

```text
Execution identity
Execution state
Operation
Reliability policy
Failure state
Reliability state
Timestamps
```

Therefore a failed health operation can produce runtime failure evidence just like another runtime operation.

This makes health verification part of the broader reliability architecture rather than an isolated endpoint implementation.

---

# 55. Health and Failure Classification

Runtime failures are classified into categories including:

```text
timeout
dependency
validation
authentication
authorization
internal
```

For example:

```text
Health operation timeout
        │
        ▼
RuntimeTimeoutError
        │
        ▼
TIMEOUT classification
```

The Runtime failure handler can then record the failure and expose an appropriate HTTP response.

---

# 56. Health and Observability

Health verification produces evidence across:

```text
HTTP
Runtime
Metrics
Logs
Alerts
```

The operational model is:

```text
Health Request
      │
      ├── HTTP response
      │
      ├── Runtime state
      │
      ├── Runtime logs
      │
      └── Metrics
```

This allows an operator to investigate not only whether a health check failed, but also how and why it failed.

---

# 57. What Health Checks Do Not Guarantee

A successful health check does not guarantee:

```text
Every API endpoint works
Every database query succeeds
Every upload succeeds
Every Worker job succeeds
No latent performance problem exists
No future failure will occur
```

Health checks provide bounded evidence about specific operational conditions.

They should therefore be interpreted within their declared scope.

---

# 58. Health Check Design Principles

Mini-Write follows these principles:

### 1. Liveness should be lightweight

Avoid dependency-heavy liveness checks.

### 2. Readiness should represent service capability

Readiness may verify required dependencies.

### 3. Health should be observable

Health states should be visible through metrics and logs where appropriate.

### 4. Health should be bounded

A health check should have a predictable timeout.

### 5. Health should not create failure amplification

Health checks should not create unnecessary retries or restart loops.

### 6. Process health is not behavioral health

A running process can still be operationally degraded.

### 7. Dependency failures should remain distinguishable

Do not hide a dependency failure behind a generic service failure.

---

# 59. Operational Definition of Healthy

For the API:

```text
Healthy
=
Process alive
+
Liveness passing
+
Readiness passing
+
Required dependencies functioning
+
No significant behavioral degradation
```

For the Worker:

```text
Healthy
=
Process available
+
Metrics endpoint reachable
+
Queue processing active
+
Failure rate acceptable
+
Processing latency acceptable
+
Required dependencies functioning
```

For the host:

```text
Healthy
=
Host available
+
Docker operational
+
CPU acceptable
+
Memory acceptable
+
Disk capacity acceptable
+
Network functional
```

For the observability platform:

```text
Healthy
=
Metrics collection functioning
+
Logs flowing
+
Dashboards available
+
Alert evaluation functioning
```

---

# 60. Health Status Is Contextual

There is no single global boolean representing the health of the entire platform.

Instead:

```text
Host Health
      +
API Health
      +
Worker Health
      +
Dependency Health
      +
Observability Health
      +
Behavioral Health
```

form the operational health picture.

The system should therefore be evaluated as a set of related health domains.

---

# 61. Standard Health Investigation

When asked:

> "Is Mini-Write healthy?"

the operator should follow:

```text
1. Host
2. Docker
3. Application containers
4. API liveness
5. API readiness
6. Worker availability
7. Queue behavior
8. PostgreSQL
9. Redis
10. MinIO
11. Prometheus targets
12. Loki / Promtail
13. Alertmanager
14. Current alerts
15. Recent errors
16. Recent deployments
```

The answer should then be expressed with scope.

For example:

```text
API: Healthy
Worker: Degraded
PostgreSQL: Healthy
Redis: Healthy
MinIO: Healthy
Host: Healthy
Observability: Healthy

Overall:
Application operational but Worker processing degraded.
```

This is more useful than simply stating:

```text
System: DOWN
```

---

# 62. Health Check Definition of Done

Health verification is considered complete when an operator can determine:

```text
✓ Whether the host is healthy
✓ Whether required containers are running
✓ Whether the API is alive
✓ Whether the API is ready
✓ Whether required dependencies are available
✓ Whether the Worker is reachable
✓ Whether the Worker is processing work
✓ Whether queues are healthy
✓ Whether processing failures are increasing
✓ Whether processing latency is increasing
✓ Whether storage is healthy
✓ Whether database performance is healthy
✓ Whether Prometheus can scrape required targets
✓ Whether logs are flowing
✓ Whether active alerts exist
✓ Whether a health failure is isolated or systemic
```

---

# 63. Final Health Model

The complete Mini-Write health model is:

```text
                         ┌──────────────────┐
                         │      HOST        │
                         │ CPU / RAM / Disk │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │     DOCKER       │
                         │ Containers/Net   │
                         └────────┬─────────┘
                                  │
                  ┌───────────────┴───────────────┐
                  ▼                               ▼
          ┌───────────────┐               ┌───────────────┐
          │      API      │               │    WORKER     │
          │               │               │               │
          │ Liveness      │               │ Availability  │
          │ Readiness     │               │ Queue         │
          │ Latency       │               │ Jobs          │
          │ Errors        │               │ Failures      │
          └───────┬───────┘               │ Latency       │
                  │                       └───────┬───────┘
                  │                               │
                  └───────────────┬───────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │      DEPENDENCIES       │
                    │                         │
                    │ PostgreSQL              │
                    │ Redis                   │
                    │ MinIO                   │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │     OBSERVABILITY       │
                    │                         │
                    │ Prometheus              │
                    │ Loki / Promtail         │
                    │ Grafana                 │
                    │ Alertmanager            │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │   OPERATIONAL HEALTH    │
                    │                         │
                    │ Alive                   │
                    │ Ready                   │
                    │ Functional              │
                    │ Observable              │
                    │ Recoverable              │
                    └─────────────────────────┘
```

The central operational principle is:

> **A healthy system is not merely a system whose processes are running; it is a system whose required services are available, whose dependencies are functioning, whose workloads are progressing, and whose operators retain sufficient visibility to verify all of the above.**

```
```
