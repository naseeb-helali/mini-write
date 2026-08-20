# Metrics Reference

## 1. Purpose

This document is the authoritative reference for the metrics exposed by Mini-Write.

It describes:

- metric naming conventions
- metric ownership
- metric types
- labels
- metric sources
- Prometheus collection
- application metrics
- business metrics
- Runtime reliability metrics
- Worker metrics
- infrastructure metrics
- how metrics are used operationally

This document is a **reference document**.

It defines what metrics exist and how they should be interpreted.

It does not replace:

- `docs/observability/metrics.md` for the overall metrics architecture
- `docs/observability/observability.md` for the broader observability model
- `docs/observability/alerting.md` for alert conditions
- Grafana dashboard documentation for visualization behavior

---

# 2. Metrics Architecture

Mini-Write uses Prometheus-compatible metrics throughout the system.

The high-level flow is:

```text
Application / Infrastructure
          │
          ▼
      Metric Source
          │
          ▼
      Prometheus Registry
          │
          ▼
       /metrics
          │
          ▼
       Prometheus
          │
     ┌────┴─────┐
     ▼          ▼
   Grafana   Alert Rules
````

For infrastructure components, exporters provide the metrics:

```text
PostgreSQL ──► postgres-exporter ──► Prometheus
Redis ───────► redis-exporter ─────► Prometheus
Host ────────► node-exporter ──────► Prometheus
Containers ──► cAdvisor ───────────► Prometheus
```

---

# 3. Metric Naming Convention

Application metrics use the following general structure:

```text
mw_<domain>_<metric_name>
```

API metrics use:

```text
mw_api_*
```

Business metrics use:

```text
mw_business_*
```

Worker metrics use:

```text
mw_worker_*
```

The `mw_` prefix identifies metrics belonging to Mini-Write.

This reduces naming collisions with other Prometheus metrics.

---

# 4. Metric Types

Mini-Write uses the standard Prometheus metric types.

## Counter

A Counter represents a monotonically increasing event count.

Examples:

```text
mw_api_http_requests_total
mw_api_http_errors_total
mw_business_user_logins_total
mw_worker_job_failures_total
```

Counters should normally be queried using:

```promql
rate(...)
```

or:

```promql
increase(...)
```

rather than interpreted directly as a current rate.

---

## Gauge

A Gauge represents a value that can increase or decrease.

Examples include:

```text
mw_api_http_requests_in_flight
mw_worker_jobs_active
mw_worker_queue_depth
```

Gauges are generally used for current state.

---

## Histogram

A Histogram records distributions of observed values.

Mini-Write uses Histograms for:

* HTTP request duration
* upload file size
* Runtime operation duration
* Worker job duration
* Worker dependency operation duration

Histograms expose bucket series ending in:

```text
_bucket
```

as well as:

```text
_count
_sum
```

They can be used with:

```promql
histogram_quantile(...)
```

to estimate latency percentiles.

---

# 5. API Metrics Registry

The API uses:

```text
api/src/observability/registry.js
```

as its Prometheus registry.

The registry uses:

```text
prom-client
```

and collects default Node.js/process metrics.

The default metrics use the prefix:

```text
mw_
```

The registry also defines default labels:

```text
service
environment
version
```

---

# 6. API Default Labels

API application metrics are associated with:

```text
service=api
environment=<NODE_ENV>
version=<APP_VERSION>
```

The defaults are:

```text
environment=development
version=1.0.0
```

when the corresponding environment variables are not provided.

The intended production/staging deployment should provide explicit environment and application version values.

---

# 7. API Traffic Metrics

Source:

```text
api/src/observability/metrics.js
```

## `mw_api_http_requests_total`

### Type

```text
Counter
```

### Purpose

Counts HTTP requests handled by the API.

### Labels

```text
method
route
status_code
```

### Example dimensions

```text
method=GET
route=/health/live
status_code=200
```

### Operational meaning

This metric represents API traffic volume.

It can be used to calculate:

* request rate
* traffic trends
* request volume by endpoint
* request volume by HTTP status

### Example query

```promql
sum(rate(mw_api_http_requests_total[5m]))
```

---

# 8. API Request Duration

## `mw_api_http_request_duration_seconds`

### Type

```text
Histogram
```

### Purpose

Measures HTTP request duration in seconds.

### Labels

```text
method
route
status_code
```

### Buckets

The configured buckets are:

```text
0.005
0.01
0.025
0.05
0.1
0.25
0.5
1
2.5
5
10
```

These represent:

```text
5 ms
10 ms
25 ms
50 ms
100 ms
250 ms
500 ms
1 s
2.5 s
5 s
10 s
```

### Operational meaning

This metric is used to understand API latency distribution.

The API alerting model currently uses the 95th percentile.

### Example

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(mw_api_http_request_duration_seconds_bucket[5m])
  )
)
```

---

# 9. API In-Flight Requests

## `mw_api_http_requests_in_flight`

### Type

```text
Gauge
```

### Purpose

Tracks the number of HTTP requests currently being processed.

### Labels

None.

### Operational meaning

A sustained increase may indicate:

* increased traffic
* slow downstream dependencies
* application saturation
* blocked operations
* resource pressure

This metric should normally be interpreted together with request rate and latency.

---

# 10. API HTTP Errors

## `mw_api_http_errors_total`

### Type

```text
Counter
```

### Purpose

Counts failed HTTP requests.

### Labels

```text
method
route
status_code
error_type
```

### Operational meaning

This is one of the primary API reliability metrics.

It is used to calculate the API error rate.

### Current alerting usage

The API alerting rule considers the ratio:

```promql
sum(rate(mw_api_http_errors_total[5m]))
/
sum(rate(mw_api_http_requests_total[5m]))
```

An alert is triggered when the calculated error percentage remains above:

```text
5%
```

for:

```text
5 minutes
```

---

# 11. API Authentication Attempts

## `mw_api_auth_attempts_total`

### Type

```text
Counter
```

### Purpose

Counts authentication attempts.

### Labels

```text
result
```

### Possible semantic results

The exact values depend on the instrumentation that records the metric.

The metric should therefore be interpreted according to the emitting code rather than assuming a fixed result vocabulary.

### Operational use

Useful for:

* authentication traffic
* authentication failure analysis
* security-oriented dashboards
* detecting unusual authentication patterns

---

# 12. API Upload Requests

## `mw_api_upload_requests_total`

### Type

```text
Counter
```

### Purpose

Counts upload requests.

### Labels

```text
result
```

### Operational use

Useful for understanding:

* upload traffic
* upload success/failure distribution
* workload entering the asynchronous processing pipeline

---

# 13. API Upload File Size

## `mw_api_upload_file_size_bytes`

### Type

```text
Histogram
```

### Purpose

Records uploaded file sizes in bytes.

### Buckets

The configured buckets are:

```text
100 KB
500 KB
1 MB
5 MB
10 MB
25 MB
50 MB
100 MB
```

More precisely, the implementation defines:

```text
100 * 1024
500 * 1024
1024 * 1024
5 * 1024 * 1024
10 * 1024 * 1024
25 * 1024 * 1024
50 * 1024 * 1024
100 * 1024 * 1024
```

### Operational use

This metric helps identify:

* changes in upload workload
* unusually large files
* storage pressure
* processing workload changes

---

# 14. Business Metrics

Business metrics are implemented in:

```text
api/src/observability/businessMetrics.js
```

They use Prometheus Counters backed by the shared API registry.

The common labels are:

```text
service
environment
version
```

Additional metric-specific labels may be added.

---

# 15. User Registrations

## `mw_business_user_registrations_total`

### Type

```text
Counter
```

### Purpose

Counts successful user registrations.

### Additional labels

None.

### Common labels

```text
service
environment
version
```

### Operational meaning

Represents successful registration events rather than all registration attempts.

---

# 16. User Logins

## `mw_business_user_logins_total`

### Type

```text
Counter
```

### Purpose

Counts successful user logins.

### Additional labels

None.

### Operational meaning

Represents successful authentication events.

It should not be interpreted as total login attempts.

---

# 17. ID Upload Attempts

## `mw_business_id_uploads_total`

### Type

```text
Counter
```

### Purpose

Counts ID upload attempts.

### Operational meaning

Represents upload workload entering the API.

---

# 18. Successful ID Uploads

## `mw_business_id_upload_success_total`

### Type

```text
Counter
```

### Purpose

Counts successful ID upload operations.

### Operational use

Can be compared against:

```text
mw_business_id_uploads_total
```

to understand upload success behavior.

---

# 19. Failed ID Uploads

## `mw_business_id_upload_failures_total`

### Type

```text
Counter
```

### Labels

```text
reason
```

plus common business labels:

```text
service
environment
version
```

### Purpose

Counts failed ID upload operations categorized by failure reason.

### Example query

```promql
sum by (reason) (
  rate(mw_business_id_upload_failures_total[5m])
)
```

---

# 20. Background Jobs Enqueued

## `mw_business_jobs_enqueued_total`

### Type

```text
Counter
```

### Labels

```text
job_type
```

plus:

```text
service
environment
version
```

### Purpose

Counts background jobs submitted by the API.

### Current usage

The ID upload workflow records:

```text
job_type=id_card_processing
```

This metric connects API workload with Worker workload.

---

# 21. API Runtime Reliability Metrics

The Runtime infrastructure boundary uses metrics provided by:

```text
api/src/runtime/observability/reliabilityMetrics.js
```

The infrastructure boundary currently records metrics for:

* Runtime operations
* Runtime retries
* Runtime failures
* Runtime operation duration

The Runtime metric implementation is the authoritative source for the exact metric names and label definitions.

The architectural dimensions are:

```text
operation
dependency
outcome
failure_type
recoverable
```

---

# 22. Runtime Operation Metrics

The Runtime tracks operation execution outcomes.

The implementation records:

```text
success
recovered
failure
```

as operation outcomes.

Conceptually:

```text
Runtime Operation
      │
      ├── success
      ├── recovered
      └── failure
```

This distinction is important.

A recovered operation is not equivalent to an operation that succeeded on its first attempt.

---

# 23. Runtime Retry Metrics

Runtime retry events are recorded with dimensions including:

```text
operation
dependency
reason
```

The Runtime also records:

```text
attempt
next_attempt
```

in structured retry logs.

This allows operators to distinguish:

```text
successful first attempt
```

from:

```text
successful after recovery
```

---

# 24. Runtime Failure Metrics

Runtime failures are associated with:

```text
operation
dependency
failure_type
recoverable
```

The failure classification types currently include:

```text
timeout
dependency
validation
authentication
authorization
internal
```

The `recoverable` dimension indicates whether the failure was classified as recoverable.

---

# 25. Runtime Operation Duration

The Runtime measures infrastructure operation duration through a Histogram.

The measurement begins before:

```text
executeWithReliability()
```

and ends when the operation reaches:

```text
success
recovered
failure
```

The outcome is attached to the duration observation.

This allows latency analysis by outcome.

---

# 26. Runtime Metric Interpretation

Runtime metrics should not be interpreted as simple application request metrics.

For example:

```text
API request
   │
   ├── PostgreSQL operation
   ├── MinIO operation
   └── Redis operation
```

can produce multiple Runtime operation measurements for a single HTTP request.

Therefore:

```text
HTTP request count ≠ Runtime operation count
```

The two metric families describe different layers.

---

# 27. Worker Metrics

The Worker exposes its own Prometheus metrics through:

```text
/metrics
```

and is scraped by Prometheus at:

```text
worker:9464
```

The Worker metrics cover the background processing lifecycle.

The principal Worker metric families include:

```text
mw_worker_jobs_processed_total
mw_worker_job_failures_total
mw_worker_jobs_retried_total
mw_worker_jobs_active
mw_worker_queue_depth
mw_worker_queue_paused
mw_worker_job_duration_seconds
```

The Worker also exposes dependency-oriented processing metrics used by the alerting layer.

---

# 28. Worker Processed Jobs

## `mw_worker_jobs_processed_total`

### Type

```text
Counter
```

### Purpose

Counts jobs processed by the Worker.

### Operational use

Used to calculate:

* processing throughput
* job success/failure ratios
* workload trends

---

# 29. Worker Job Failures

## `mw_worker_job_failures_total`

### Type

```text
Counter
```

### Purpose

Counts failed Worker jobs.

### Operational use

This metric is used to calculate Worker job failure rate.

The current alerting rule compares:

```promql
sum(rate(mw_worker_job_failures_total[5m]))
```

against:

```promql
sum(rate(mw_worker_jobs_processed_total[5m]))
```

and alerts when the resulting percentage exceeds:

```text
10%
```

for:

```text
5 minutes
```

---

# 30. Worker Job Retries

## `mw_worker_jobs_retried_total`

### Type

```text
Counter
```

### Purpose

Counts Worker job retry activity.

### Operational use

Useful for identifying:

* transient dependency instability
* repeated job failures
* workload amplification caused by retries

Retry count should be interpreted alongside:

```text
job failures
processed jobs
job duration
```

---

# 31. Active Worker Jobs

## `mw_worker_jobs_active`

### Type

```text
Gauge
```

### Purpose

Represents the number of jobs currently being processed.

### Operational use

Useful for understanding:

* current Worker concurrency
* processing saturation
* workload pressure

---

# 32. Worker Queue Depth

## `mw_worker_queue_depth`

### Type

```text
Gauge
```

### Purpose

Represents the current number of waiting jobs in the Worker queue.

### Operational meaning

A growing queue indicates that incoming work is exceeding processing capacity.

### Current alert

The alerting system considers:

```promql
sum(mw_worker_queue_depth) > 10
```

for:

```text
10 minutes
```

as a high queue backlog condition.

---

# 33. Worker Queue Paused State

## `mw_worker_queue_paused`

### Type

```text
Gauge`
```

### Purpose

Represents the queue paused state.

The metric should be interpreted according to the Worker instrumentation semantics.

A paused queue is operationally significant because jobs may remain queued without normal processing progress.

---

# 34. Worker Job Duration

## `mw_worker_job_duration_seconds`

### Type

```text
Histogram
```

### Purpose

Measures Worker job processing duration in seconds.

### Operational use

The current alerting model calculates the 95th percentile:

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(
      mw_worker_job_duration_seconds_bucket[5m]
    )
  )
)
```

The alert threshold is:

```text
5 seconds
```

for:

```text
5 minutes
```

---

# 35. Worker Dependency Metrics

The Worker observability model includes dependency-oriented duration metrics.

The alerting configuration references:

```text
mw_worker_storage_duration_seconds
mw_worker_database_duration_seconds
```

These metrics are Histograms representing dependency operation duration.

---

# 36. Worker Storage Duration

## `mw_worker_storage_duration_seconds`

### Type

```text
Histogram
```

### Purpose

Measures object-storage operation duration.

### Current alert threshold

The 95th percentile is considered problematic when it exceeds:

```text
2 seconds
```

for:

```text
10 minutes
```

The metric is used primarily to detect MinIO/object-storage latency affecting Worker processing.

---

# 37. Worker Database Duration

## `mw_worker_database_duration_seconds`

### Type

```text
Histogram
```

### Purpose

Measures Worker database operation duration.

### Current alert threshold

The 95th percentile is considered problematic when it exceeds:

```text
0.5 seconds
```

for:

```text
10 minutes
```

The metric is used to identify PostgreSQL latency affecting background processing.

---

# 38. Prometheus Collection

Prometheus is configured in:

```text
observability/Prometheus/prometheus.yml
```

The global configuration uses:

```yaml
scrape_interval: 30s
evaluation_interval: 30s
```

Application services override the scrape interval to:

```text
15s
```

---

# 39. API Scrape Configuration

Prometheus scrapes:

```text
api:80
```

using:

```text
/metrics
```

The Prometheus job name is:

```text
api
```

and the labels include:

```text
service=api
layer=application
```

---

# 40. Worker Scrape Configuration

Prometheus scrapes:

```text
worker:9464
```

using:

```text
/metrics
```

The Prometheus job name is:

```text
worker
```

and the labels include:

```text
service=worker
layer=application
```

---

# 41. Infrastructure Metrics

Infrastructure metrics are collected through exporters.

The current Prometheus targets are:

| Job        | Target                   | Layer          |
| ---------- | ------------------------ | -------------- |
| `redis`    | `redis-exporter:9121`    | infrastructure |
| `postgres` | `postgres-exporter:9187` | infrastructure |
| `node`     | `node-exporter:9100`     | runtime        |
| `cadvisor` | `cadvisor:8080`          | runtime        |

These metrics are not application-defined Mini-Write metrics, but they are part of the project's operational metrics surface.

---

# 42. Node Exporter Metrics

Node Exporter provides host-level metrics.

The alerting configuration currently uses:

```text
node_cpu_seconds_total
node_memory_MemTotal_bytes
node_memory_MemAvailable_bytes
node_filesystem_avail_bytes
node_filesystem_size_bytes
```

These metrics support:

* CPU utilization
* memory utilization
* filesystem capacity

---

# 43. CPU Utilization

The infrastructure alert calculates CPU utilization approximately as:

```promql
100 -
(
  avg by(instance)
  (
    rate(node_cpu_seconds_total{mode="idle"}[5m])
  ) * 100
)
```

The alert threshold is:

```text
> 90%
```

for:

```text
10 minutes
```

---

# 44. Memory Utilization

Memory utilization is calculated from:

```text
node_memory_MemTotal_bytes
node_memory_MemAvailable_bytes
```

Conceptually:

```text
used memory =
MemTotal - MemAvailable
```

The alert threshold is:

```text
> 90%
```

for:

```text
10 minutes
```

---

# 45. Filesystem Capacity

Available filesystem percentage is calculated from:

```text
node_filesystem_avail_bytes
node_filesystem_size_bytes
```

The current rule excludes:

```text
tmpfs
overlay
squashfs
ramfs
```

The alert triggers when available capacity falls below:

```text
10%
```

for:

```text
10 minutes
```

---

# 46. Container Metrics

cAdvisor provides container-level resource metrics.

Prometheus collects these through:

```text
cadvisor:8080
```

with:

```text
job=cadvisor
service=containers
layer=runtime
```

These metrics complement Node Exporter:

```text
Node Exporter
    └── host-level resource state

cAdvisor
    └── container-level resource state
```

---

# 47. Prometheus Self-Monitoring

Prometheus itself is scraped through:

```text
localhost:9090
```

with:

```text
job=prometheus
service=prometheus
```

This allows the monitoring system to observe its own availability and operational state.

---

# 48. Loki Metrics

Loki is also configured as a Prometheus scrape target:

```text
loki:3100
```

with:

```text
job=loki
service=loki
layer=observability
```

These are observability-system metrics rather than application metrics.

---

# 49. Alertmanager Metrics

Alertmanager is scraped through:

```text
alertmanager:9093
```

with:

```text
job=alertmanager
service=alertmanager
layer=observability
```

This allows monitoring of the alerting subsystem itself.

---

# 50. Metric Labels

Labels provide dimensions for querying metrics.

Mini-Write uses several classes of labels.

## Application identity

```text
service
environment
version
```

## HTTP dimensions

```text
method
route
status_code
```

## Error dimensions

```text
error_type
failure_type
recoverable
```

## Runtime dimensions

```text
operation
dependency
outcome
```

## Business dimensions

```text
result
reason
job_type
```

Labels should represent stable, bounded dimensions.

---

# 51. Cardinality Considerations

Prometheus labels must not contain unbounded identifiers.

The architecture therefore avoids using values such as:

```text
request_id
execution_id
user_id
job_id
correlation_id
```

as general-purpose Prometheus labels.

These identifiers belong in logs and traces/correlation mechanisms rather than metric labels.

The project explicitly applies this principle in the Promtail pipeline by removing high-cardinality fields from Loki labels.

---

# 52. Route Label Consideration

The API HTTP metrics use:

```text
route
```

rather than arbitrary request URLs.

This distinction is important.

Metrics should represent normalized route identities such as:

```text
/api/v1/auth/login
```

rather than dynamically generated URLs containing identifiers.

Otherwise metric cardinality could grow with request volume.

---

# 53. Metric-to-Log Correlation

Metrics and logs serve different purposes.

Metrics answer:

```text
How often?
How much?
How long?
How many?
```

Logs answer:

```text
What exactly happened?
Which execution?
Which dependency?
Which failure?
```

For example:

```text
Metric:
mw_api_http_errors_total
```

can identify an increase in failures.

Logs can then be used to investigate:

```text
request_id
execution_id
operation_id
dependency
failure_type
error_message
```

The operational flow is therefore:

```text
Metric anomaly
      │
      ▼
Identify affected service
      │
      ▼
Identify operation/dependency
      │
      ▼
Query structured logs
      │
      ▼
Reconstruct execution
```

---

# 54. Metric-to-Alert Relationship

Metrics are the raw signals.

Prometheus alert rules convert selected metric conditions into operational alerts.

The current alert families include:

```text
Infrastructure
API
Worker
```

Examples:

```text
API down
API high error rate
API high latency

Worker down
Queue backlog high
Worker job failure rate high
Worker job latency high
Storage latency high
Database latency high

Node exporter down
High CPU
High memory
Low disk
```

---

# 55. Metric Thresholds

The current operational thresholds include:

| Metric Condition             | Threshold | Duration |
| ---------------------------- | --------: | -------: |
| API error rate               |      > 5% |       5m |
| API p95 latency              |      > 1s |       5m |
| Worker queue depth           |      > 10 |      10m |
| Worker job failure rate      |     > 10% |       5m |
| Worker p95 job duration      |      > 5s |       5m |
| Worker p95 storage duration  |      > 2s |      10m |
| Worker p95 database duration |    > 0.5s |      10m |
| Host CPU                     |     > 90% |      10m |
| Host memory                  |     > 90% |      10m |
| Filesystem available         |     < 10% |      10m |
| API target availability      |      down |       2m |
| Worker target availability   |      down |       2m |
| Node Exporter availability   |      down |       2m |

These thresholds belong to the current staging/production-oriented alert configuration and should not be interpreted as universal capacity limits.

---

# 56. Avoiding Misinterpretation

A metric should always be interpreted in context.

For example:

```text
High CPU
```

does not automatically mean:

```text
Application failure
```

Likewise:

```text
High queue depth
```

does not automatically mean:

```text
Worker failure
```

The correct interpretation requires correlation with:

```text
traffic
latency
failure rate
resource utilization
dependency latency
processing throughput
```

---

# 57. Useful PromQL Patterns

## Request Rate

```promql
sum(rate(mw_api_http_requests_total[5m]))
```

## API Error Rate

```promql
(
  sum(rate(mw_api_http_errors_total[5m]))
  /
  sum(rate(mw_api_http_requests_total[5m]))
) * 100
```

## API p95 Latency

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(mw_api_http_request_duration_seconds_bucket[5m])
  )
)
```

## Worker Throughput

```promql
sum(rate(mw_worker_jobs_processed_total[5m]))
```

## Worker Failure Rate

```promql
(
  sum(rate(mw_worker_job_failures_total[5m]))
  /
  sum(rate(mw_worker_jobs_processed_total[5m]))
) * 100
```

## Queue Depth

```promql
sum(mw_worker_queue_depth)
```

## Worker p95 Job Duration

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(mw_worker_job_duration_seconds_bucket[5m])
  )
)
```

---

# 58. Counter Reset Consideration

Counters reset when the emitting process restarts.

Therefore:

```text
mw_api_http_requests_total
```

should not be interpreted as a persistent lifetime count across process restarts when queried directly from the current Prometheus series.

For operational analysis use:

```promql
rate(...)
```

or:

```promql
increase(...)
```

Prometheus handles counter-reset semantics for these functions.

---

# 59. Histogram Interpretation

Histogram buckets represent cumulative observations.

For example:

```text
metric_bucket{le="1"}
```

represents observations less than or equal to one second.

Percentiles should therefore be calculated using:

```promql
histogram_quantile()
```

over appropriately aggregated `_bucket` series.

Care must be taken not to average independently calculated percentiles across instances.

---

# 60. Metric Ownership

The metric ownership model is:

| Metric Domain             | Primary Owner                |
| ------------------------- | ---------------------------- |
| HTTP traffic              | API                          |
| HTTP latency              | API                          |
| HTTP errors               | API                          |
| Business operations       | API                          |
| Runtime reliability       | Runtime                      |
| Job processing            | Worker                       |
| Queue state               | Worker                       |
| Host resources            | Node Exporter                |
| Container resources       | cAdvisor                     |
| PostgreSQL infrastructure | PostgreSQL Exporter          |
| Redis infrastructure      | Redis Exporter               |
| Monitoring system         | Prometheus/Loki/Alertmanager |

Ownership matters because the source of a metric determines where instrumentation changes should be made.

---

# 61. Metrics and Reliability

Metrics are an important part of the Reliability architecture.

The primary reliability signals are:

```text
Availability
Error rate
Latency
Retry rate
Failure rate
Queue backlog
Dependency latency
Resource saturation
```

The Runtime adds a lower-level execution view:

```text
Operation
Dependency
Attempt
Failure classification
Recovery
Duration
```

Together they provide both:

```text
Service-level reliability
```

and:

```text
Execution-level reliability
```

---

# 62. Metrics and Continuous Improvement

Metrics provide the feedback signal for future engineering improvements.

The feedback loop is:

```text
Metric
  │
  ▼
Observation
  │
  ▼
Anomaly / Trend
  │
  ▼
Investigation
  │
  ▼
Root Cause
  │
  ▼
Engineering Change
  │
  ▼
New Measurement
```

Therefore metrics are not merely dashboard data.

They are part of the project's operational feedback system.

---

# 63. Adding a New Metric

A new application metric should follow this process:

```text
1. Define the operational question
        │
        ▼
2. Determine metric type
        │
        ▼
3. Define bounded labels
        │
        ▼
4. Choose stable metric name
        │
        ▼
5. Register metric
        │
        ▼
6. Instrument the relevant code
        │
        ▼
7. Expose through Prometheus registry
        │
        ▼
8. Validate collection
        │
        ▼
9. Add dashboard usage if necessary
        │
        ▼
10. Add alert only if actionable
```

A metric should not be added merely because the value is available.

There should be a clear operational question it answers.

---

# 64. Adding a New Label

Before adding a label, verify:

```text
Is the value bounded?
Is it stable?
Is it operationally useful?
Will it create a large number of time series?
Can the same information be obtained from logs?
```

Do not add:

```text
request_id
execution_id
user_id
job_id
file_name
error_message
```

as general metric labels.

These are high-cardinality or potentially sensitive values.

---

# 65. Metrics Validation Checklist

A new or modified metric should be validated for:

### Naming

```text
Does the metric follow the project naming convention?
```

### Type

```text
Is Counter/Gauge/Histogram appropriate?
```

### Labels

```text
Are labels bounded and meaningful?
```

### Registration

```text
Is the metric registered with the correct registry?
```

### Collection

```text
Does Prometheus successfully scrape it?
```

### Semantics

```text
Does the metric actually represent what its name says?
```

### Reset behavior

```text
Is it safe across process restarts?
```

### Cardinality

```text
Could this create excessive time series?
```

### Operational usefulness

```text
Does it answer a real operational question?
```

---

# 66. Current Metrics Reference Map

The current application metric families can be summarized as:

```text
Mini-Write Metrics
│
├── API
│   ├── HTTP traffic
│   ├── HTTP duration
│   ├── HTTP in-flight
│   ├── HTTP errors
│   ├── authentication
│   ├── uploads
│   └── upload size
│
├── Business
│   ├── registrations
│   ├── logins
│   ├── ID uploads
│   └── jobs enqueued
│
├── Runtime
│   ├── operations
│   ├── retries
│   ├── failures
│   └── operation duration
│
└── Worker
    ├── jobs processed
    ├── job failures
    ├── job retries
    ├── active jobs
    ├── queue depth
    ├── queue state
    ├── job duration
    ├── storage duration
    └── database duration
```

Infrastructure and observability-system metrics are collected separately through exporters and native Prometheus-compatible endpoints.

---

# 67. Authoritative Sources

The metric definitions originate from the following implementation/configuration sources:

```text
api/src/observability/metrics.js
api/src/observability/registry.js
api/src/observability/businessMetrics.js
api/src/runtime/observability/reliabilityMetrics.js
worker/src/.../metrics implementation
observability/Prometheus/prometheus.yml
observability/Prometheus/rules/*.yml
```

The Prometheus configuration defines collection targets.

The application metric modules define application-level instrumentation.

The alert rules define operational interpretation of selected metrics.

---

# 68. Related Documentation

For the metrics architecture:

```text
docs/observability/metrics.md
```

For the broader observability architecture:

```text
docs/observability/observability.md
```

For alerting behavior:

```text
docs/observability/alerting.md
```

For dashboard usage:

```text
docs/observability/dashboards.md
```

For Runtime metrics semantics:

```text
docs/reference/runtime-reference.md
```

For configuration:

```text
docs/reference/configuration-reference.md
docs/reference/environment-variables.md
```

---

# 69. Final Reference Model

Mini-Write's metrics system should be understood as a layered measurement architecture:

```text
                    ┌─────────────────────┐
                    │      Grafana        │
                    │ Dashboards / Views  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │     Prometheus      │
                    │ Query / Rules / DB  │
                    └──────────┬──────────┘
                               │
             ┌─────────────────┼─────────────────┐
             │                 │                 │
             ▼                 ▼                 ▼
        API / Worker       Exporters       Observability
          Metrics          Infrastructure     Metrics
             │                 │                 │
             ▼                 ▼                 ▼
        Application        Host / DB /      Prometheus /
        Instrumentation    Redis / Docker   Loki / Alertmanager
```

At the application layer:

```text
Traffic
   │
   ├── Latency
   ├── Errors
   ├── Business Events
   ├── Queue Workload
   └── Runtime Reliability
```

At the infrastructure layer:

```text
CPU
Memory
Disk
Containers
PostgreSQL
Redis
```

The resulting metric model provides the quantitative foundation required to observe system behavior, detect reliability degradation, investigate incidents, and evaluate the effect of engineering changes.

```
```
