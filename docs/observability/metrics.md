# Metrics

## 1. Purpose

This document defines the Metrics architecture of Mini-Write.

Metrics provide the quantitative observability signal used to measure system behavior over time.

The objective is not to expose every possible internal value.

The objective is to expose a controlled set of metrics that allows operators and engineers to answer questions such as:

- How much traffic is the system receiving?
- How many requests are succeeding or failing?
- How long are requests taking?
- How many background jobs are being processed?
- Is the Worker keeping up with the queue?
- Are jobs failing or being retried?
- Which infrastructure dependency is degrading?
- Is the Runtime performing retries or recovering from failures?
- Is the host becoming resource constrained?
- Is a recent deployment correlated with a degradation?

The Metrics architecture therefore follows:

```text
System Behavior
      │
      ▼
Metric Instrumentation
      │
      ▼
Prometheus Endpoint / Exporter
      │
      ▼
Prometheus Scrape
      │
      ▼
Time-Series Storage
      │
      ├──────────────► Grafana
      │
      └──────────────► Alert Rules
                            │
                            ▼
                       Alertmanager
````

---

# 2. Metrics Philosophy

Mini-Write treats metrics as a quantitative operational interface.

A metric should exist because it supports an operational question.

The preferred relationship is:

```text
Operational Question
        │
        ▼
Required Signal
        │
        ▼
Metric
        │
        ▼
Query
        │
        ▼
Dashboard / Alert
```

Metrics should therefore not be added merely because they are technically easy to expose.

---

# 3. Metrics Architecture

Metrics are collected from multiple architectural layers:

```text
┌───────────────────────────────────────────────┐
│                 Application                  │
│                                               │
│ API                         Worker             │
│ │                            │                │
│ └──── Application Metrics ───┴────────────┐   │
└───────────────────────────────────────────┼───┘
                                            │
┌───────────────────────────────────────────┼───┐
│                  Runtime                  │   │
│                                           │   │
│ Reliability / Failure / Retry Metrics ────┘   │
└──────────────────────────────┬────────────────┘
                               │
┌──────────────────────────────┼────────────────┐
│             Infrastructure  │                 │
│                              │                 │
│ Node Exporter                │                 │
│ cAdvisor                     │                 │
│ Redis Exporter               │                 │
│ PostgreSQL Exporter          │                 │
└──────────────────────────────┬────────────────┘
                               │
                               ▼
                         Prometheus
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
                 Grafana              Alert Rules
                                          │
                                          ▼
                                     Alertmanager
```

---

# 4. Metric Sources

The current architecture uses the following metric sources:

| Source              | Scope                 | Collection Mechanism        |
| ------------------- | --------------------- | --------------------------- |
| API                 | Application           | `/metrics`                  |
| Worker              | Background processing | `/metrics`                  |
| Runtime             | Reliability execution | API/Worker metrics registry |
| Node Exporter       | Host                  | Prometheus scrape           |
| cAdvisor            | Containers            | Prometheus scrape           |
| Redis Exporter      | Redis                 | Prometheus scrape           |
| PostgreSQL Exporter | PostgreSQL            | Prometheus scrape           |
| Prometheus          | Monitoring system     | Self-scrape                 |
| Loki                | Logging system        | Prometheus scrape           |
| Alertmanager        | Alerting system       | Prometheus scrape           |

---

# 5. Prometheus as the Metrics Authority

Prometheus is the central metrics collection system.

Its responsibilities are:

1. Discover configured targets.
2. Scrape metric endpoints.
3. Store time-series data.
4. Evaluate alerting rules.
5. Expose metrics to Grafana.
6. Provide the query interface used by operational dashboards.

The repository configuration is:

```text
observability/Prometheus/prometheus.yml
```

Metric alert rules are stored under:

```text
observability/Prometheus/rules/
```

---

# 6. Prometheus Global Configuration

The current global configuration uses:

```yaml
global:
  scrape_interval: 30s
  evaluation_interval: 30s
```

The architecture also defines:

```yaml
external_labels:
  project: mini-write
  environment: staging
```

These labels establish the deployment context of the Prometheus instance.

---

# 7. Application Scrape Frequency

API and Worker use a more frequent scrape interval:

```yaml
scrape_interval: 15s
```

This provides faster visibility into application behavior than the global 30-second interval.

The resulting model is:

```text
Infrastructure / Monitoring Targets
        │
        └── default: 30s

Application Targets
        │
        └── API / Worker: 15s
```

This is a deliberate balance between signal freshness and monitoring overhead.

---

# 8. API Metrics Endpoint

The API exposes:

```text
/metrics
```

using the Prometheus registry.

The endpoint is served through `prom-client` and exposes the metrics registered in:

```text
api/src/observability/registry.js
```

The API is scraped by Prometheus using:

```yaml
- job_name: api
  scrape_interval: 15s
  metrics_path: /metrics
  static_configs:
    - targets:
        - api:80
```

---

# 9. Worker Metrics Endpoint

The Worker exposes its own Prometheus metrics endpoint.

Prometheus currently scrapes:

```text
worker:9464
```

using:

```yaml
- job_name: worker
  scrape_interval: 15s
  metrics_path: /metrics
```

The Worker metrics represent background processing rather than HTTP traffic.

---

# 10. Metric Naming Convention

Application metrics use the `mw_` namespace.

API HTTP metrics use:

```text
mw_api_
```

Business metrics use:

```text
mw_business_
```

This provides a project-level namespace and separates application concerns.

Examples:

```text
mw_api_http_requests_total
mw_api_http_errors_total
mw_business_user_registrations_total
```

---

# 11. Metric Types

Mini-Write uses the standard Prometheus metric types according to the semantics of the measured value.

The primary types are:

```text
Counter
Gauge
Histogram
```

The selection should follow the meaning of the measurement rather than implementation convenience.

---

# 12. Counter

A Counter represents a monotonically increasing number of events.

Examples include:

```text
mw_api_http_requests_total
mw_api_http_errors_total
mw_business_user_registrations_total
mw_business_user_logins_total
```

Counters should generally be queried with functions such as:

```promql
rate(...)
```

or:

```promql
increase(...)
```

rather than interpreted directly as instantaneous rates.

---

# 13. Gauge

A Gauge represents a value that can increase and decrease.

Typical examples include:

```text
in-flight requests
active jobs
queue depth
queue state
```

Gauge values represent current state rather than accumulated events.

---

# 14. Histogram

A Histogram measures distributions.

Mini-Write uses histograms for quantities such as:

```text
HTTP request duration
job duration
upload file size
dependency operation duration
```

Histograms expose bucket series and can be queried for percentile approximations.

For example:

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(mw_api_http_request_duration_seconds_bucket[5m])
  )
)
```

---

# 15. API Traffic Metrics

The API defines:

```text
mw_api_http_requests_total
```

with labels:

```text
method
route
status_code
```

This metric answers:

* How much HTTP traffic is being received?
* Which routes receive the most traffic?
* Which status codes are being returned?
* Is traffic changing over time?

---

# 16. API Request Duration

The API defines:

```text
mw_api_http_request_duration_seconds
```

with labels:

```text
method
route
status_code
```

This metric measures request latency.

It is used to derive percentile measurements such as:

```text
P50
P95
P99
```

where appropriate.

---

# 17. API In-Flight Requests

The API defines:

```text
mw_api_http_requests_in_flight
```

This Gauge represents the number of requests currently being processed.

It is useful for detecting:

* request accumulation;
* concurrency pressure;
* abnormal traffic;
* slow downstream dependencies.

---

# 18. API Error Metrics

The API defines:

```text
mw_api_http_errors_total
```

with:

```text
method
route
status_code
error_type
```

This metric provides a dedicated error signal rather than requiring every error to be inferred from the request counter.

The distinction is useful when calculating:

```text
error rate
```

and investigating changes in error behavior.

---

# 19. API Authentication Metrics

The API defines:

```text
mw_api_auth_attempts_total
```

with:

```text
result
```

This metric represents authentication attempts and their outcomes.

The `result` dimension should remain bounded to a controlled set of values.

---

# 20. API Upload Metrics

The API defines:

```text
mw_api_upload_requests_total
```

with:

```text
result
```

This measures upload request outcomes.

The API also exposes:

```text
mw_api_upload_file_size_bytes
```

as a Histogram.

This allows operators to understand the distribution of uploaded file sizes and correlate large payloads with resource or latency behavior.

---

# 21. Business Metrics

Business metrics provide operational visibility into application behavior from a business perspective.

The API currently defines:

```text
mw_business_user_registrations_total
mw_business_user_logins_total
mw_business_id_uploads_total
mw_business_id_upload_success_total
mw_business_id_upload_failures_total
mw_business_jobs_enqueued_total
```

These metrics complement technical metrics.

For example:

```text
HTTP requests
```

may increase while:

```text
successful registrations
```

remain unchanged.

The combination reveals application-level behavior that infrastructure metrics alone cannot explain.

---

# 22. Business Metric Dimensions

Business metrics include common dimensions:

```text
service
environment
version
```

Some metrics add domain-specific labels.

Examples:

```text
reason
job_type
```

The architecture deliberately keeps these dimensions bounded.

---

# 23. Runtime Reliability Metrics

Runtime reliability introduces metrics that describe infrastructure-operation execution.

The Runtime currently uses:

```text
runtimeOperationsTotal
runtimeRetriesTotal
runtimeFailuresTotal
runtimeOperationDurationSeconds
```

These are registered against the application's Prometheus registry.

The resulting metrics represent:

```text
operation outcome
retry behavior
failure behavior
operation duration
```

---

# 24. Runtime Operation Metrics

Runtime operation execution records:

```text
success
recovered
failure
```

as outcomes.

This creates an important distinction:

```text
HTTP Success
```

versus:

```text
Infrastructure Operation Success
```

An operation may initially fail, retry, and then succeed.

The Runtime can therefore expose:

```text
outcome = recovered
```

rather than hiding the instability behind the final successful result.

---

# 25. Runtime Retry Metrics

Runtime retries are represented by:

```text
runtimeRetriesTotal
```

The metric includes dimensions for:

```text
operation
dependency
reason
```

This allows questions such as:

```text
Which dependency is causing retries?
Which operation is most affected?
What failure classification triggers retries?
```

---

# 26. Runtime Failure Metrics

Runtime failures are represented by:

```text
runtimeFailuresTotal
```

with dimensions:

```text
operation
dependency
failure_type
recoverable
```

This creates a direct relationship between:

```text
Operation
+
Dependency
+
Failure Classification
+
Recoverability
```

---

# 27. Runtime Operation Duration

The Runtime uses:

```text
runtimeOperationDurationSeconds
```

to measure infrastructure operation duration.

The metric is labeled by:

```text
operation
dependency
outcome
```

This makes dependency latency observable independently from total HTTP request latency.

---

# 28. Why Dependency Metrics Matter

Consider:

```text
HTTP P95 = 1.8s
```

This tells us the user-facing symptom.

It does not immediately explain why.

Runtime dependency metrics may reveal:

```text
PostgreSQL P95 = 1.5s
```

The diagnostic chain becomes:

```text
HTTP Latency
     │
     ▼
Runtime Operation Latency
     │
     ▼
Dependency
     │
     ▼
PostgreSQL
```

This is one of the primary architectural purposes of Runtime metrics.

---

# 29. Worker Metrics

The Worker metrics represent asynchronous processing behavior.

The current alerting architecture references metrics including:

```text
mw_worker_queue_depth
mw_worker_job_failures_total
mw_worker_jobs_processed_total
mw_worker_job_duration_seconds
mw_worker_storage_duration_seconds
mw_worker_database_duration_seconds
```

The Worker also exposes metrics for runtime processing concepts such as:

```text
active jobs
retried jobs
queue state
```

These metrics are adapted to Worker semantics rather than copied blindly from the API.

---

# 30. Queue Depth

The Worker exposes:

```text
mw_worker_queue_depth
```

This represents waiting work.

Queue depth is a state signal.

A sustained increase may indicate:

```text
arrival rate > processing rate
```

The operational concern is therefore not merely the absolute queue size but its trend and persistence.

---

# 31. Job Processing Metrics

The Worker exposes:

```text
mw_worker_jobs_processed_total
mw_worker_job_failures_total
```

These counters allow calculation of processing throughput and failure rates.

A simplified failure-rate query is:

```promql
(
  sum(rate(mw_worker_job_failures_total[5m]))
  /
  sum(rate(mw_worker_jobs_processed_total[5m]))
) * 100
```

The resulting value should be interpreted carefully when throughput is very low.

---

# 32. Job Retry Metrics

The Worker tracks retry behavior.

Retries are important because:

```text
failure
```

does not necessarily mean:

```text
final job failure
```

A job may follow:

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
```

Metrics should make this behavior visible.

---

# 33. Job Duration

The Worker exposes:

```text
mw_worker_job_duration_seconds
```

as a Histogram.

This allows calculation of processing latency percentiles.

For example:

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(mw_worker_job_duration_seconds_bucket[5m])
  )
)
```

---

# 34. Dependency Latency in Worker

The Worker also exposes dependency-specific duration metrics referenced by the alerting architecture:

```text
mw_worker_storage_duration_seconds
mw_worker_database_duration_seconds
```

These distinguish:

```text
job processing latency
```

from:

```text
dependency latency
```

This distinction is essential for diagnosis.

---

# 35. Infrastructure Metrics

Infrastructure metrics are provided by exporters.

The current architecture includes:

```text
Node Exporter
cAdvisor
Redis Exporter
PostgreSQL Exporter
```

The corresponding Prometheus jobs are:

```text
node
cadvisor
redis
postgres
```

---

# 36. Node Exporter

Node Exporter provides host-level measurements.

The alerting architecture uses metrics such as:

```text
node_cpu_seconds_total
node_memory_MemTotal_bytes
node_memory_MemAvailable_bytes
node_filesystem_avail_bytes
node_filesystem_size_bytes
```

These support infrastructure health decisions.

---

# 37. CPU Utilization

The current CPU alert derives utilization from idle CPU time:

```promql
100 -
(
  avg by(instance)
  (
    rate(node_cpu_seconds_total{mode="idle"}[5m])
  ) * 100
)
```

This is preferable to relying on an arbitrary application-level CPU metric because it measures the host's CPU state directly.

---

# 38. Memory Utilization

Memory utilization is derived from:

```text
MemTotal
-
MemAvailable
```

relative to total memory.

Conceptually:

```text
Used Memory %
=
(
  Total
  -
  Available
)
/
Total
× 100
```

This provides a host-level memory pressure signal.

---

# 39. Filesystem Availability

Disk availability is derived from:

```text
node_filesystem_avail_bytes
```

and:

```text
node_filesystem_size_bytes
```

The current infrastructure alert treats less than 10% available capacity as critical.

This is important because disk exhaustion can affect:

```text
logs
database writes
Docker
deployments
observability storage
```

simultaneously.

---

# 40. cAdvisor Metrics

cAdvisor provides container-level metrics.

These complement Node Exporter.

The distinction is:

```text
Node Exporter
    │
    └── Host perspective

cAdvisor
    │
    └── Container perspective
```

This allows resource usage to be traced from:

```text
Host
  │
  ▼
Container
  │
  ▼
Service
```

---

# 41. Redis Exporter

Redis Exporter exposes Redis operational metrics.

Prometheus scrapes:

```text
redis-exporter:9121
```

under:

```text
job_name: redis
```

These metrics provide visibility into the queue/cache dependency.

---

# 42. PostgreSQL Exporter

PostgreSQL Exporter exposes database operational metrics.

Prometheus scrapes:

```text
postgres-exporter:9187
```

under:

```text
job_name: postgres
```

This allows application symptoms to be correlated with database behavior.

---

# 43. Observability-System Metrics

The monitoring stack also exposes its own metrics.

Prometheus scrapes:

```text
prometheus:9090
```

Loki:

```text
loki:3100
```

Alertmanager:

```text
alertmanager:9093
```

This creates observability for the observability infrastructure itself.

---

# 44. Metric Labels

Labels are used to provide bounded dimensions.

Examples include:

```text
service
environment
version
method
route
status_code
operation
dependency
outcome
failure_type
recoverable
```

Labels should answer a meaningful aggregation question.

For example:

```promql
sum by (dependency) (...)
```

is useful because it allows dependency-level analysis.

---

# 45. Cardinality Management

Cardinality is a first-class design concern.

A label with an unbounded number of possible values can create a large number of time series.

Dangerous examples include:

```text
request_id
execution_id
user_id
job_id
raw error message
arbitrary URL
```

These values should normally remain in logs.

The metrics layer should prefer bounded dimensions.

---

# 46. Metrics and Correlation IDs

Runtime-generated identifiers such as:

```text
request_id
execution_id
```

are useful for logs.

They should not normally be metric labels.

The intended architecture is:

```text
Metrics
   │
   └── aggregate behavior

Logs
   │
   └── identify individual execution
```

This prevents high-cardinality metric explosion.

---

# 47. Version Dimension

Application metrics include a version dimension where configured.

This supports deployment correlation:

```text
Version A
    │
    ▼
Normal behavior

Version B
    │
    ▼
Error rate ↑
```

The version dimension therefore provides an important bridge between deployment and observability.

---

# 48. Environment Dimension

Metrics also carry environment information.

The current application registry uses:

```text
environment
```

with:

```text
NODE_ENV
```

as its source and a development fallback.

Prometheus itself additionally defines:

```text
environment: staging
```

through external labels.

This makes deployment context explicit.

---

# 49. Service Dimension

The metrics architecture identifies the originating service.

Examples:

```text
api
worker
host
postgres
redis
```

This allows dashboards and queries to aggregate telemetry across the system while preserving service boundaries.

---

# 50. Rate Calculations

Counters should generally be converted into rates for operational dashboards and alerts.

For example:

```promql
rate(mw_api_http_requests_total[5m])
```

represents request throughput.

Similarly:

```promql
rate(mw_api_http_errors_total[5m])
```

represents error throughput.

---

# 51. Error Rate

API error rate is calculated as:

```text
Error Rate
=
Errors
/
Requests
× 100
```

The current alert uses a five-minute rate window:

```promql
(
  sum(rate(mw_api_http_errors_total[5m]))
  /
  sum(rate(mw_api_http_requests_total[5m]))
) * 100
```

The alert threshold is:

```text
> 5%
for 5 minutes
```

---

# 52. Latency Percentiles

Latency is generally more useful as a distribution than as an average.

The architecture therefore uses Histogram metrics.

For example:

```text
P95 HTTP latency
```

can be derived with:

```promql
histogram_quantile(...)
```

This helps detect degraded tail latency that an average can hide.

---

# 53. Why P95 Is Used

Suppose:

```text
95 requests = 100ms
5 requests = 5s
```

The average may remain acceptable while a meaningful portion of users experience severe latency.

P95 provides a better operational signal for this type of degradation.

It is therefore used in current API and Worker alerts.

---

# 54. Queue Metrics and Throughput

Queue health should not be evaluated from queue depth alone.

The useful relationship is:

```text
Queue Depth
+
Job Arrival Rate
+
Processing Rate
+
Job Latency
```

For example:

```text
Queue Depth ↑
Processing Rate ↓
Job Latency ↑
```

is much stronger evidence of Worker degradation than:

```text
Queue Depth = 11
```

by itself.

---

# 55. Retry Metrics as Early Warning

Retries can provide an early warning before final failures increase.

Example:

```text
Retries ↑
Failures = stable
```

may indicate:

```text
Dependency becoming transiently unstable
```

while:

```text
Retries ↑
Failures ↑
```

may indicate:

```text
Recovery capacity being exhausted
```

Therefore retry metrics should be considered alongside failure metrics.

---

# 56. Recovery Metrics

Runtime execution distinguishes:

```text
success
recovered
failure
```

This is operationally valuable.

Consider:

```text
Failure → Retry → Success
```

The final user-facing result is success.

However, the infrastructure experienced degradation.

The `recovered` outcome preserves this evidence.

---

# 57. Metrics and Failure Classification

Runtime failure classification includes categories such as:

```text
timeout
dependency
validation
authentication
authorization
internal
```

Metrics can therefore expose failure behavior using:

```text
failure_type
```

This allows operators to distinguish:

```text
dependency failures
```

from:

```text
application failures
```

rather than treating all failures as equivalent.

---

# 58. Metrics and Recoverability

Runtime failure metrics include:

```text
recoverable
```

This allows a distinction between:

```text
recoverable failure
```

and:

```text
non-recoverable failure
```

This dimension is useful when evaluating whether reliability mechanisms are operating as intended.

---

# 59. Metrics and Reliability Policy

Runtime policies define values such as:

```text
timeout
retry
maxRetries
recoverable
```

Metrics provide evidence about how those policies behave in production-like execution.

For example:

```text
Policy:
retry = true
maxRetries = 2
```

can be validated operationally by observing:

```text
runtimeRetriesTotal
```

and:

```text
runtimeOperationsTotal{outcome="recovered"}
```

---

# 60. Timeout Observability

Runtime timeout failures are classified as:

```text
timeout
```

and use:

```text
RUNTIME_TIMEOUT
```

as the internal error code.

Timeouts should therefore be distinguishable from generic dependency failures.

This allows operators to ask:

```text
Are dependencies failing?
```

versus:

```text
Are dependencies responding too slowly?
```

---

# 61. Metric-to-Question Mapping

| Operational Question             | Primary Metric                         |
| -------------------------------- | -------------------------------------- |
| How much API traffic?            | `mw_api_http_requests_total`           |
| How many API errors?             | `mw_api_http_errors_total`             |
| How slow is API?                 | `mw_api_http_request_duration_seconds` |
| How many requests are active?    | `mw_api_http_requests_in_flight`       |
| How many registrations?          | `mw_business_user_registrations_total` |
| How many logins?                 | `mw_business_user_logins_total`        |
| How many uploads?                | `mw_business_id_uploads_total`         |
| How many jobs were enqueued?     | `mw_business_jobs_enqueued_total`      |
| How deep is the queue?           | `mw_worker_queue_depth`                |
| How many jobs fail?              | `mw_worker_job_failures_total`         |
| How many jobs process?           | `mw_worker_jobs_processed_total`       |
| How slow are jobs?               | `mw_worker_job_duration_seconds`       |
| How often are retries occurring? | Runtime/Worker retry metrics           |
| Which dependency is failing?     | Runtime failure metrics                |
| Which dependency is slow?        | Runtime/dependency duration metrics    |
| Is host CPU high?                | `node_cpu_seconds_total`               |
| Is host memory high?             | `node_memory_*`                        |
| Is disk running out?             | `node_filesystem_*`                    |

---

# 62. Metrics and Dashboards

Metrics are consumed by Grafana dashboards.

The major dashboard domains are:

```text
System
Application
Queue
Deployment
Incidents
```

The relationship is:

```text
Metrics
   │
   ▼
PromQL
   │
   ▼
Dashboard Panel
   │
   ▼
Operational Interpretation
```

A dashboard panel should have a clear operational purpose.

---

# 63. Metrics and Alerts

Alerts consume the same underlying Prometheus metrics used by dashboards.

For example:

```text
Metric
  │
  ├──► Dashboard
  │
  └──► Alert Rule
```

This avoids maintaining two unrelated definitions of system health.

---

# 64. Current Alert Thresholds

The current architecture contains thresholds such as:

### API

```text
API unavailable
    → 2 minutes

API error rate
    → > 5% for 5 minutes

API P95 latency
    → > 1 second for 5 minutes
```

### Worker

```text
Worker unavailable
    → 2 minutes

Queue depth
    → > 10 for 10 minutes

Job failure rate
    → > 10% for 5 minutes

Job P95 duration
    → > 5 seconds for 5 minutes

Storage P95 latency
    → > 2 seconds for 10 minutes

Database P95 latency
    → > 0.5 seconds for 10 minutes
```

### Infrastructure

```text
Node Exporter unavailable
    → 2 minutes

CPU
    → > 90% for 10 minutes

Memory
    → > 90% for 10 minutes

Disk availability
    → < 10% for 10 minutes
```

These thresholds are operational policies rather than universal industry constants.

They should evolve with observed workload behavior.

---

# 65. Threshold Design

Thresholds should be evaluated against:

```text
baseline
+
workload
+
capacity
+
failure impact
```

A threshold should not be changed merely because a different environment uses another value.

The appropriate question is:

```text
At what point does this condition represent meaningful operational degradation?
```

---

# 66. Avoiding Noisy Metrics

A metric should not become a source of operational noise.

Examples of potentially noisy signals include:

```text
short CPU spikes
temporary queue fluctuations
single transient dependency errors
```

The alerting layer therefore uses:

```text
for:
```

durations to require persistence before triggering an alert.

Metrics themselves remain raw enough to support investigation.

---

# 67. Metric Retention

Prometheus stores time-series data locally in the current single-node architecture.

The retention policy is a deployment concern rather than an application instrumentation concern.

The important architectural requirement is:

```text
Retention must be bounded.
```

Unlimited local metrics storage would eventually become an infrastructure reliability problem.

---

# 68. Metric Storage Failure

Prometheus uses persistent storage:

```text
prometheus_data
```

through the deployment configuration.

If this storage becomes unavailable:

```text
Metric ingestion
       │
       ▼
Storage failure
       │
       ▼
Potential monitoring data loss
```

This is therefore part of the infrastructure observability failure domain.

---

# 69. Monitoring the Monitoring System

Prometheus itself is scraped.

Alertmanager is scraped.

Loki is scraped.

This allows the system to detect failures in monitoring components.

However, self-monitoring cannot detect every failure.

For example:

```text
Host completely unavailable
```

can simultaneously eliminate:

```text
Application
Prometheus
Grafana
Loki
Alertmanager
```

External monitoring would be required to detect such a complete host failure.

---

# 70. Single-Node Constraint

The current Metrics architecture is intentionally designed for:

```text
single host
single Prometheus
local storage
```

Therefore it does not provide:

```text
Prometheus HA
remote write redundancy
cross-node metric replication
external long-term storage
```

These are future scaling concerns.

---

# 71. Metric Reliability

Metrics themselves are not guaranteed to be complete.

Potential causes include:

```text
service unavailable
metrics endpoint unavailable
Prometheus unavailable
network failure
exporter failure
storage failure
```

Therefore an absent metric should not automatically be interpreted as:

```text
service healthy
```

The operator must distinguish:

```text
metric = zero
```

from:

```text
metric = unavailable
```

This distinction is fundamental.

---

# 72. Zero vs Missing

For example:

```text
mw_worker_job_failures_total = 0
```

means:

```text
Metric is available and no failures were observed.
```

Whereas:

```text
mw_worker_job_failures_total
```

being absent may mean:

```text
Worker unavailable
or
Prometheus unable to scrape Worker
or
metric not registered
```

Operational dashboards and alerts should account for this distinction.

---

# 73. Metric Instrumentation Principles

Application instrumentation should follow these principles:

### 73.1 Stable Names

Metric names should not change without a migration reason.

### 73.2 Stable Semantics

A metric name should maintain one meaning.

### 73.3 Bounded Labels

Labels should have controlled cardinality.

### 73.4 Correct Metric Type

Use Counter, Gauge, or Histogram according to semantics.

### 73.5 Operational Purpose

Every metric should support a diagnostic or business question.

### 73.6 Consistent Units

Durations should use seconds.

Sizes should use bytes.

Rates should be calculated from counters.

---

# 74. Units

Mini-Write follows Prometheus conventions for metric units.

Examples:

```text
*_seconds
*_bytes
```

For example:

```text
mw_api_http_request_duration_seconds
mw_api_upload_file_size_bytes
```

This avoids ambiguity when metrics are consumed by dashboards or alert expressions.

---

# 75. Metric Naming Anti-Patterns

The following should be avoided:

```text
request_time
```

when the unit is ambiguous.

Prefer:

```text
request_duration_seconds
```

Similarly:

```text
file_size
```

should be avoided when the unit is unclear.

Prefer:

```text
file_size_bytes
```

---

# 76. Label Anti-Patterns

Avoid:

```text
request_id
user_id
execution_id
job_id
error_message
timestamp
```

as metric labels.

These are high-cardinality or effectively unbounded dimensions.

Prefer:

```text
operation
dependency
status
outcome
failure_type
```

where the value sets remain bounded.

---

# 77. Metric Lifecycle

A new metric should follow:

```text
Requirement
    │
    ▼
Operational Question
    │
    ▼
Metric Design
    │
    ▼
Instrumentation
    │
    ▼
Prometheus Exposure
    │
    ▼
Query Validation
    │
    ├──► Dashboard
    │
    └──► Alert
```

A metric should not be considered complete merely because it appears at `/metrics`.

---

# 78. Metric Validation

A new metric should be validated for:

```text
Name
Type
Unit
Labels
Cardinality
Value semantics
Scrape visibility
Query correctness
Dashboard usefulness
Alert usefulness
```

---

# 79. Runtime Metric Validation

Runtime metrics should additionally be validated against:

```text
operation
dependency
failure classification
retry behavior
recovery behavior
```

For example:

```text
Transient dependency failure
       │
       ▼
Retry
       │
       ▼
Success
```

should produce evidence consistent with:

```text
retry count ↑
recovered outcome ↑
final failure not incremented
```

for the successful recovered execution.

---

# 80. Worker Metric Validation

Worker metrics should be validated against actual queue behavior.

For example:

```text
Submit jobs
   │
   ▼
Queue depth ↑
   │
   ▼
Worker processes jobs
   │
   ▼
Queue depth ↓
```

The observed metrics should reflect this lifecycle.

Failure testing should similarly validate:

```text
job failure
+
retry
+
final outcome
```

---

# 81. Application Metric Validation

API instrumentation should be validated through representative requests:

```text
register
login
profile
upload
health
```

The expected relationship is:

```text
Request
   │
   ├── request counter
   ├── request duration
   └── error metric when applicable
```

Business metrics should additionally reflect successful or failed business outcomes.

---

# 82. Metrics During Incidents

Metrics are usually the first quantitative signal used during an incident.

The recommended progression is:

```text
1. Check service availability.
2. Check traffic.
3. Check error rate.
4. Check latency.
5. Check dependency metrics.
6. Check infrastructure metrics.
7. Inspect logs.
```

Metrics identify the shape of the incident before logs provide detailed evidence.

---

# 83. Example: API Degradation

Suppose:

```text
MWHighAPIErrorRate
```

fires.

The operator should inspect:

```text
mw_api_http_requests_total
mw_api_http_errors_total
mw_api_http_request_duration_seconds
```

Then inspect Runtime metrics:

```text
runtimeFailuresTotal
runtimeRetriesTotal
runtimeOperationDurationSeconds
```

Then determine whether a dependency is responsible.

---

# 84. Example: Dependency Failure

Suppose PostgreSQL becomes unstable.

The observable pattern may be:

```text
PostgreSQL exporter metrics
        │
        ▼
Database latency ↑
        │
        ▼
Runtime dependency failures ↑
        │
        ▼
Runtime retries ↑
        │
        ▼
API latency ↑
        │
        ▼
API errors ↑
```

Metrics therefore provide the temporal chain connecting infrastructure degradation to application symptoms.

---

# 85. Example: Worker Backlog

Suppose:

```text
mw_worker_queue_depth ↑
```

The operator should compare:

```text
queue depth
+
jobs processed
+
job duration
+
job failures
+
retry count
```

If processing throughput has dropped while job duration has increased, the problem may be execution capacity or dependency latency rather than an increase in incoming workload alone.

---

# 86. Metrics and Capacity

Metrics also provide the basis for capacity reasoning.

Important signals include:

```text
CPU
memory
in-flight requests
queue depth
job throughput
latency
```

Capacity degradation often appears as:

```text
load ↑
      │
      ▼
resource utilization ↑
      │
      ▼
latency ↑
      │
      ▼
queue/backlog ↑
      │
      ▼
failures ↑
```

This pattern should be visible through the combined metric architecture.

---

# 87. Metrics and SLO Evolution

The current architecture is not yet a complete SLO framework.

However, the available metrics provide the foundations for future SLOs.

Potential future objectives include:

```text
API availability
API latency
API error budget
Worker processing success
Worker processing latency
Queue freshness
```

SLOs should be introduced only after the underlying metric semantics and workload baselines are stable.

---

# 88. Metrics and Continuous Improvement

Metrics create a feedback loop:

```text
Production Behavior
       │
       ▼
Metrics
       │
       ▼
Trend Analysis
       │
       ▼
Engineering Decision
       │
       ▼
Architecture / Code Change
       │
       ▼
New Production Behavior
```

This makes metrics part of the engineering improvement system.

---

# 89. Current Metrics Inventory

The principal application/runtime metrics currently defined or referenced by the architecture are:

### API

```text
mw_api_http_requests_total
mw_api_http_request_duration_seconds
mw_api_http_requests_in_flight
mw_api_http_errors_total
mw_api_auth_attempts_total
mw_api_upload_requests_total
mw_api_upload_file_size_bytes
```

### Business

```text
mw_business_user_registrations_total
mw_business_user_logins_total
mw_business_id_uploads_total
mw_business_id_upload_success_total
mw_business_id_upload_failures_total
mw_business_jobs_enqueued_total
```

### Worker

```text
mw_worker_queue_depth
mw_worker_job_failures_total
mw_worker_jobs_processed_total
mw_worker_job_duration_seconds
mw_worker_storage_duration_seconds
mw_worker_database_duration_seconds
```

Additional Worker metrics cover active jobs, retries, and queue state.

### Runtime

```text
runtimeOperationsTotal
runtimeRetriesTotal
runtimeFailuresTotal
runtimeOperationDurationSeconds
```

These names refer to the instrumentation objects in the Runtime implementation; their exported Prometheus metric names are determined by the actual metric definitions.

### Infrastructure

Prometheus consumes exporter metrics including:

```text
node_cpu_seconds_total
node_memory_MemTotal_bytes
node_memory_MemAvailable_bytes
node_filesystem_avail_bytes
node_filesystem_size_bytes
```

plus the broader metric sets exposed by cAdvisor, Redis Exporter, and PostgreSQL Exporter.

---

# 90. Metrics Definition of Done

The Metrics capability is considered operationally complete when:

```text
✓ Application metrics are exposed.

✓ Worker metrics are exposed.

✓ Runtime reliability metrics are exposed.

✓ Business outcomes have dedicated metrics where operationally useful.

✓ Host metrics are collected.

✓ Container metrics are collected.

✓ Redis metrics are collected.

✓ PostgreSQL metrics are collected.

✓ Prometheus successfully scrapes configured targets.

✓ Metric names have stable semantics.

✓ Metric units are explicit.

✓ Labels have bounded cardinality.

✓ Request/execution identifiers remain primarily log correlation fields.

✓ Histograms are used for duration/distribution measurements.

✓ Counters are queried using rates/increases.

✓ Gauges represent current state.

✓ Metrics support Grafana dashboards.

✓ Metrics support alerting rules.

✓ Metric behavior has been validated against representative scenarios.

✓ Missing metrics are not confused with zero values.

✓ Monitoring-system metrics are themselves collected.
```

---

# 91. Architectural Invariants

## Invariant 1 — Metrics Must Be Operationally Meaningful

Every metric should answer a real engineering question.

## Invariant 2 — Metric Semantics Must Remain Stable

Changing the meaning of an existing metric is a breaking observability change.

## Invariant 3 — Cardinality Must Be Controlled

Unbounded identifiers belong in logs, not metric labels.

## Invariant 4 — Histograms Must Be Used for Distributions

Latency and size distributions should not be reduced to a single average.

## Invariant 5 — Counters Represent Events

Counters should represent cumulative occurrences and be converted to rates when analyzing behavior over time.

## Invariant 6 — Missing Metrics Are Not Zero

Telemetry absence must be treated as a potential observability or service failure.

## Invariant 7 — Application and Infrastructure Metrics Must Be Correlatable

Application symptoms should be traceable toward Runtime and infrastructure signals.

## Invariant 8 — Metrics Must Support Both Dashboards and Alerts

The same authoritative metric should support human visualization and automated detection where appropriate.

## Invariant 9 — Reliability Behavior Must Be Observable

Retries, failures, timeouts, and recovery must not remain invisible behind final request/job outcomes.

---

# 92. Final Metrics Model

The Mini-Write Metrics architecture can be summarized as:

```text
                    SYSTEM BEHAVIOR
                           │
             ┌─────────────┼─────────────┐
             │             │             │
             ▼             ▼             ▼
        API Metrics   Worker Metrics   Runtime Metrics
             │             │             │
             └─────────────┼─────────────┘
                           │
                           ▼
                  Infrastructure Metrics
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
       Host             Container       Dependencies
          │                │                │
          └────────────────┼────────────────┘
                           │
                           ▼
                       Prometheus
                           │
                 ┌─────────┴─────────┐
                 ▼                   ▼
              Grafana           Alert Rules
                 │                   │
                 ▼                   ▼
             Operators          Alertmanager
```

The core design principle is:

```text
Metrics should make system behavior measurable,
comparable, diagnosable, and actionable.
```

They form the quantitative foundation on which Mini-Write's dashboards, alerts, reliability analysis, incident response, and future SLO model are built.

```
```
