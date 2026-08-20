# Dashboards

## 1. Purpose

This document defines the Dashboard architecture of Mini-Write.

Dashboards provide the visual operational interface for the observability system.

They do not replace:

- Prometheus
- Loki
- Alertmanager
- application metrics
- runtime telemetry
- infrastructure exporters

Instead, dashboards consume those signals and organize them into views that allow an operator to:

- understand current system health
- identify degradation
- locate affected services
- correlate infrastructure and application behavior
- investigate operational incidents
- validate deployments and recovery

The architectural relationship is:

```text
                    ┌─────────────────────┐
                    │       System        │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
           Metrics           Logs           Runtime
              │                │                │
              ▼                ▼                ▼
         Prometheus          Loki        Application Signals
              │                │                │
              └────────────────┼────────────────┘
                               ▼
                           Grafana
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
          System View     Application View   Queue View
              │                │                │
              └────────────────┼────────────────┘
                               ▼
                           Operator
````

---

# 2. Dashboard Philosophy

Mini-Write follows an **operational dashboard** model rather than treating dashboards as collections of arbitrary charts.

A dashboard should answer an operational question.

Examples:

```text
Is the host healthy?

Is the API available?

Is the API error rate increasing?

Is API latency degrading?

Is the Worker processing jobs?

Is the queue accumulating work?

Are infrastructure dependencies becoming slow?

What changed during the incident?
```

The objective is therefore:

```text
Raw Telemetry
      │
      ▼
Operational Signals
      │
      ▼
Dashboard
      │
      ▼
Human Decision
```

A dashboard is useful only when it helps an operator make that decision.

---

# 3. Grafana as the Visualization Layer

Grafana is the visualization layer of the Mini-Write observability architecture.

The Grafana service is deployed through the infrastructure Compose configuration and exposes:

```text
3000
```

Its persistent data is stored in:

```text
grafana_data
```

The dashboard definitions themselves are version-controlled under:

```text
observability/grafana/dashboards/
```

This separates:

```text
Dashboard Definition
```

from:

```text
Grafana Runtime State
```

---

# 4. Dashboard Architecture

The current dashboard organization is:

```text
observability/
└── grafana/
    ├── dashboards/
    │   ├── application/
    │   │   └── application-health.json
    │   │
    │   ├── deployment/
    │   │
    │   ├── incidents/
    │   │
    │   ├── queue/
    │   │   └── queue-operations.json
    │   │
    │   └── system/
    │       └── system-overview.json
    │
    └── provisioning/
        ├── alerting/
        │   └── contact-points.yml
        │
        ├── dashboards/
        │   └── dashbords.yml
        │
        └── datasources/
            └── datasources.yml
```

The architectural categories are:

```text
System
Application
Queue
Deployment
Incidents
```

The first three currently contain implemented dashboard definitions.

The Deployment and Incidents categories are provisioned as extension points for future dashboards.

---

# 5. Dashboard Categories

The dashboard model separates operational concerns into different views.

```text
System
  │
  └── Host and infrastructure health

Application
  │
  └── API/application behavior

Queue
  │
  └── Worker and asynchronous processing

Deployment
  │
  └── Deployment history and state

Incidents
  │
  └── Incident-focused operational investigation
```

This prevents a single dashboard from becoming an unmanageable collection of unrelated metrics.

---

# 6. System Dashboard

The System dashboard is represented by:

```text
observability/grafana/dashboards/system/system-overview.json
```

Its purpose is to provide a high-level view of the host and infrastructure execution environment.

The dashboard belongs to the:

```text
System
```

Grafana folder.

Its primary signal sources are infrastructure metrics collected by:

* Node Exporter
* cAdvisor
* Prometheus
* infrastructure exporters

The system-level view should answer:

```text
Is the execution environment healthy?

Is the host under resource pressure?

Are containers consuming excessive resources?

Is the infrastructure approaching a capacity boundary?
```

---

# 7. System Dashboard Scope

The system view operates at the infrastructure layer.

Conceptually:

```text
Host
 │
 ├── CPU
 ├── Memory
 ├── Filesystem
 ├── Containers
 └── Runtime Resources
```

This is intentionally different from the Application dashboard.

The System dashboard explains:

```text
Where the application is running
```

while the Application dashboard explains:

```text
How the application is behaving
```

---

# 8. Application Dashboard

The Application dashboard is represented by:

```text
observability/grafana/dashboards/application/application-health.json
```

Its purpose is to provide the operational health view of the API service.

It belongs to the:

```text
Application
```

Grafana folder.

The dashboard is based primarily on API metrics exposed through:

```text
/metrics
```

and collected by Prometheus.

---

# 9. Application Dashboard Model

The API dashboard should be understood through three major dimensions:

```text
Availability
Performance
Errors
```

Conceptually:

```text
                API Health
                    │
       ┌────────────┼────────────┐
       ▼            ▼            ▼
 Availability   Performance    Errors
       │            │            │
       ▼            ▼            ▼
     Up/Down       Latency      Error Rate
```

This corresponds closely to the API alerting model.

---

# 10. Application Availability

The Application dashboard provides visibility into API availability through the API Prometheus target.

The underlying signal is associated with:

```text
job="api"
```

and the Prometheus:

```text
up
```

metric.

This provides the visual counterpart to:

```text
MWAPIDown
```

The dashboard therefore allows an operator to determine whether an API availability alert corresponds to:

* sustained service unavailability
* a recent interruption
* a scrape problem
* a broader infrastructure issue

---

# 11. Application Error Visibility

The API exposes HTTP error telemetry through:

```text
mw_api_http_errors_total
```

The dashboard can therefore visualize error behavior over time.

The operational question is:

```text
Are failures isolated,
or is the service experiencing systemic degradation?
```

A useful interpretation is:

```text
Low error rate
    │
    ▼
Normal operation

Increasing error rate
    │
    ▼
Potential degradation

Sustained high error rate
    │
    ▼
Incident investigation
```

---

# 12. Application Latency

API request duration is represented by:

```text
mw_api_http_request_duration_seconds
```

which is a Histogram.

This enables percentile-based analysis such as:

```text
p50
p95
p99
```

where supported by the dashboard queries.

The dashboard should therefore allow the operator to distinguish:

```text
normal latency
```

from:

```text
tail latency degradation
```

rather than relying only on average request duration.

---

# 13. Why Latency and Error Rate Belong Together

Latency and error rate often provide complementary evidence.

For example:

```text
Error Rate ↑
Latency   ↑
```

may indicate:

```text
dependency degradation
resource saturation
application overload
```

Whereas:

```text
Error Rate ↑
Latency   normal
```

may indicate:

```text
validation failures
authentication failures
application logic errors
```

Dashboards should therefore be interpreted as correlated signals rather than isolated charts.

---

# 14. Business Signals in the Application Dashboard

The API also exposes business metrics such as:

```text
mw_business_user_registrations_total
mw_business_user_logins_total
mw_business_id_uploads_total
mw_business_id_upload_success_total
mw_business_id_upload_failures_total
mw_business_jobs_enqueued_total
```

These metrics provide business-level context.

For example:

```text
HTTP requests
      │
      ▼
Application traffic
      │
      ▼
Business operations
      │
      ├── registrations
      ├── logins
      ├── uploads
      └── jobs
```

This allows an operator to distinguish infrastructure health from actual application activity.

---

# 15. Queue Dashboard

The Worker dashboard is represented by:

```text
observability/grafana/dashboards/queue/queue-operations.json
```

It belongs to the:

```text
Queue
```

Grafana folder.

Although the folder is named `queue`, the dashboard represents the broader asynchronous processing subsystem.

Its primary focus is:

```text
Worker
  +
Queue
  +
Processing
  +
Dependencies
```

---

# 16. Queue Dashboard Scope

The Queue dashboard is designed around the Worker execution model.

Conceptually:

```text
                    Redis Queue
                        │
                        ▼
                 ┌─────────────┐
                 │   Worker    │
                 └──────┬──────┘
                        │
             ┌──────────┼──────────┐
             ▼          ▼          ▼
         Processed   Failed     Retried
             │          │          │
             └──────────┼──────────┘
                        ▼
                    Processing
                    Performance
```

---

# 17. Queue Depth

The Worker exposes:

```text
mw_worker_queue_depth
```

This represents pending work in the queue.

Queue depth is one of the most important leading indicators in the asynchronous subsystem.

Conceptually:

```text
Queue Depth
     │
     ├── Stable
     │      → processing keeps pace
     │
     ├── Increasing
     │      → incoming work exceeds capacity
     │
     └── Rapidly increasing
            → possible processing incident
```

This signal corresponds directly to:

```text
MWQueueBacklogHigh
```

---

# 18. Worker Throughput

The Worker exposes processing metrics including:

```text
mw_worker_jobs_processed_total
```

This can be converted into a processing rate using PromQL.

For example:

```promql
rate(mw_worker_jobs_processed_total[5m])
```

The resulting signal represents Worker throughput.

This should be considered alongside queue depth.

---

# 19. Queue Depth and Throughput Correlation

Queue health cannot be determined from queue depth alone.

Consider:

```text
Queue depth ↑
Throughput ↑
```

This may represent a temporary traffic spike.

But:

```text
Queue depth ↑
Throughput ↓
```

is much more concerning.

Therefore:

```text
Queue Health
    =
Queue Depth
    +
Processing Throughput
```

is a more useful operational model than either metric alone.

---

# 20. Worker Failure Rate

Worker failure telemetry includes:

```text
mw_worker_job_failures_total
```

This provides visibility into processing correctness.

A useful operational relationship is:

```text
Jobs Processed
      +
Jobs Failed
      +
Jobs Retried
```

Together these provide a more complete picture of Worker behavior.

---

# 21. Worker Retry Behavior

The Worker runtime architecture includes reliability mechanisms such as:

* retry
* timeout
* exponential backoff
* failure classification
* recovery

The Queue dashboard can therefore become an important place for observing reliability behavior.

A typical sequence is:

```text
Job
 │
 ▼
Failure
 │
 ▼
Retry
 │
 ▼
Recovery
```

or:

```text
Job
 │
 ▼
Failure
 │
 ▼
Retry
 │
 ▼
Failure
 │
 ▼
Final Failure
```

These are operationally different outcomes.

---

# 22. Job Processing Latency

The Worker exposes:

```text
mw_worker_job_duration_seconds
```

which allows percentile-based analysis.

The corresponding alert:

```text
MWHighJobLatency
```

uses the 95th percentile.

The dashboard provides the visual context necessary to determine whether increased latency is:

```text
isolated
```

or:

```text
systemic
```

---

# 23. Dependency Latency

The Worker observability model also contains dependency-specific duration metrics such as:

```text
mw_worker_storage_duration_seconds
mw_worker_database_duration_seconds
```

These metrics allow the Queue dashboard to move from:

```text
Worker is slow
```

toward:

```text
Worker is slow because a dependency is slow
```

This is an important step in reducing mean time to diagnosis.

---

# 24. Storage Dependency View

Storage latency is represented by:

```text
mw_worker_storage_duration_seconds
```

and is associated with the MinIO dependency.

The corresponding alert is:

```text
MWHighStorageLatency
```

The dashboard can therefore correlate:

```text
Job Latency
      │
      ▼
Storage Latency
      │
      ▼
MinIO Health
```

---

# 25. Database Dependency View

Database latency is represented by:

```text
mw_worker_database_duration_seconds
```

and is associated with PostgreSQL operations.

The corresponding alert is:

```text
MWHighDatabaseLatency
```

This allows the operator to investigate:

```text
Worker slowdown
      │
      ▼
Database latency
      │
      ▼
PostgreSQL resource / query behavior
```

---

# 26. Deployment Dashboard

The provisioning architecture defines a:

```text
Deployment
```

dashboard folder:

```text
/var/lib/grafana/dashboards/deployment
```

However, the current repository structure does not contain an implemented dashboard JSON under:

```text
observability/grafana/dashboards/deployment/
```

Therefore Deployment Dashboard functionality should currently be treated as:

```text
Provisioned extension point
```

rather than an implemented dashboard.

---

# 27. Intended Deployment Dashboard

A future deployment dashboard can correlate:

```text
Deployment
    │
    ├── version
    ├── deployment time
    ├── current API image
    ├── current Worker image
    ├── previous versions
    ├── deployment failures
    └── rollback state
```

with:

```text
Application Health
    │
    ├── error rate
    ├── latency
    └── availability
```

This would enable deployment-related questions such as:

```text
Did the incident start after the deployment?

Which version is currently running?

Did the deployment change application behavior?

Was the previous version healthier?
```

---

# 28. Incidents Dashboard

The provisioning architecture also defines:

```text
Incidents
```

as a Grafana folder.

The current repository structure does not contain an implemented dashboard JSON under:

```text
observability/grafana/dashboards/incidents/
```

Therefore this is also currently an extension point.

The intended purpose is to provide an incident-oriented view combining:

```text
Alerts
+
Metrics
+
Logs
+
Runtime Signals
+
Deployment Context
```

---

# 29. Incident Dashboard Model

A future incident dashboard should provide a timeline similar to:

```text
Incident Timeline
───────────────────────────────────────────────>

Deployment
     │
     ▼
Metric Degradation
     │
     ▼
Alert Firing
     │
     ▼
Runtime Failures
     │
     ▼
Dependency Symptoms
     │
     ▼
Recovery
```

This would make Grafana an operational investigation workspace rather than merely a monitoring display.

---

# 30. Grafana Dashboard Provisioning

Dashboards are provisioned through:

```text
observability/grafana/provisioning/dashboards/dashbords.yml
```

The provisioning configuration defines five providers:

```text
mini-write-system
mini-write-application
mini-write-queue
mini-write-deployment
mini-write-incidents
```

Each provider maps to a corresponding Grafana folder.

---

# 31. System Provider

The System provider points to:

```text
/var/lib/grafana/dashboards/system
```

and provisions into:

```text
System
```

folder.

Configuration includes:

```yaml
disableDeletion: true
allowUiUpdates: false
```

This establishes the repository as the authoritative source for the dashboard definition.

---

# 32. Application Provider

The Application provider points to:

```text
/var/lib/grafana/dashboards/application
```

and provisions into:

```text
Application
```

folder.

The main dashboard currently provided here is:

```text
application-health.json
```

---

# 33. Queue Provider

The Queue provider points to:

```text
/var/lib/grafana/dashboards/queue
```

and provisions into:

```text
Queue
```

folder.

The implemented dashboard is:

```text
queue-operations.json
```

---

# 34. Deployment Provider

The Deployment provider points to:

```text
/var/lib/grafana/dashboards/deployment
```

and provisions into:

```text
Deployment
```

folder.

The directory currently serves as a future extension point.

---

# 35. Incidents Provider

The Incidents provider points to:

```text
/var/lib/grafana/dashboards/incidents
```

and provisions into:

```text
Incidents
```

folder.

The directory currently serves as a future extension point.

---

# 36. Immutable Dashboard Definitions

The dashboard provisioning configuration uses:

```yaml
disableDeletion: true
```

and:

```yaml
allowUiUpdates: false
```

This establishes an important governance model.

The intended flow is:

```text
Developer
    │
    ▼
Dashboard JSON
    │
    ▼
Git
    │
    ▼
Deployment
    │
    ▼
Grafana
```

rather than:

```text
Operator
    │
    ▼
Edit dashboard in UI
    │
    ▼
Runtime-only state
```

The repository remains the authoritative source.

---

# 37. Dashboard Update Interval

The providers use:

```yaml
updateIntervalSeconds: 30
```

Grafana therefore checks the provisioned dashboard sources periodically.

This supports configuration-driven dashboard updates without requiring manual recreation.

---

# 38. Datasource Architecture

The dashboards depend primarily on two Grafana datasources:

```text
Prometheus
Loki
```

These are provisioned through:

```text
observability/grafana/provisioning/datasources/datasources.yml
```

---

# 39. Prometheus Datasource

The Prometheus datasource is:

```text
name: Prometheus
uid: prometheus
```

with:

```text
url: http://prometheus:9090
```

It is configured as the default datasource.

This datasource provides:

```text
metrics
alert-related queries
time-series data
infrastructure telemetry
application telemetry
Worker telemetry
```

---

# 40. Loki Datasource

The Loki datasource is:

```text
name: Loki
uid: loki
```

with:

```text
url: http://loki:3100
```

It provides access to:

```text
application logs
Worker logs
infrastructure logs
deployment logs
runtime logs
```

This is essential for incident investigation.

---

# 41. Dashboard-to-Datasource Relationship

The architecture is:

```text
                 Grafana
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
      Prometheus             Loki
          │                   │
          ▼                   ▼
       Metrics               Logs
          │                   │
          └─────────┬─────────┘
                    ▼
                Dashboard
```

The combination allows an operator to move from:

```text
"What is happening?"
```

to:

```text
"Why is it happening?"
```

---

# 42. Dashboard and Alert Relationship

Dashboards and alerts are complementary.

The alert provides:

```text
Detection
```

while the dashboard provides:

```text
Context
```

For example:

```text
MWHighAPIErrorRate
        │
        ▼
Application Dashboard
        │
        ├── request rate
        ├── error rate
        ├── latency
        └── service health
        │
        ▼
Loki
        │
        ▼
Runtime / application logs
```

---

# 43. Dashboard and Alert Boundaries

Not every dashboard metric needs to produce an alert.

For example:

```text
request volume
```

may be highly useful operationally without representing a failure condition.

Likewise:

```text
CPU utilization
```

may be useful for diagnosis even when it remains below an alert threshold.

Therefore:

```text
Dashboard Metric ≠ Alert Rule
```

A dashboard provides observability context; an alert provides an operational trigger.

---

# 44. Dashboard Design Layers

A production-oriented dashboard should generally progress from high-level status toward diagnostic detail.

The conceptual hierarchy is:

```text
Layer 1 — Health
    │
    ▼
Layer 2 — Symptoms
    │
    ▼
Layer 3 — Performance
    │
    ▼
Layer 4 — Dependencies
    │
    ▼
Layer 5 — Diagnostic Evidence
```

For example:

```text
API
 │
 ├── UP/DOWN
 │
 ├── Error Rate
 │
 ├── Latency
 │
 ├── Database / Redis / Storage behavior
 │
 └── Logs
```

---

# 45. Avoiding Dashboard Overload

A dashboard should not attempt to display every available metric.

The existence of a metric does not imply that it belongs on a dashboard.

A metric should be included when it contributes to one of:

```text
health assessment
capacity assessment
performance diagnosis
failure diagnosis
dependency diagnosis
business interpretation
```

This keeps dashboards operationally meaningful.

---

# 46. Dashboard Time Windows

Dashboard interpretation depends strongly on the selected time range.

Useful windows include:

```text
Last 15 minutes
Last 1 hour
Last 6 hours
Last 24 hours
```

Short windows are useful for:

```text
incident response
real-time degradation
```

Longer windows are useful for:

```text
trend analysis
capacity analysis
deployment comparison
```

---

# 47. Dashboard Variables

Where practical, dashboard queries should avoid hard-coding unnecessary dimensions.

Potential future variables include:

```text
service
instance
environment
operation
dependency
```

Variables should be introduced only when they improve investigation.

Too many variables create cognitive overhead.

---

# 48. Cardinality Considerations

Dashboard queries must respect metric cardinality.

High-cardinality dimensions such as:

```text
request_id
execution_id
job_id
correlation_id
```

should not be used as Prometheus metric labels merely to make dashboards more detailed.

Those identifiers belong primarily in logs and traces/context.

The intended separation is:

```text
Prometheus
    → aggregate operational behavior

Loki
    → individual execution evidence
```

---

# 49. Metrics and Logs Complementarity

Consider an API incident.

Prometheus may show:

```text
Error Rate = 18%
p95 Latency = 2.3s
```

The dashboard establishes:

```text
The service is degraded.
```

Loki can then show:

```text
runtime_operation_failed
dependency=postgresql
failure_type=dependency
```

This establishes:

```text
A likely dependency-related failure is occurring.
```

The two systems therefore serve different levels of evidence.

---

# 50. Dashboard Operational Workflow

During normal operation:

```text
System Dashboard
      │
      ▼
Application Dashboard
      │
      ▼
Queue Dashboard
```

During an incident:

```text
Alert
 │
 ▼
Relevant Dashboard
 │
 ▼
Identify symptom
 │
 ▼
Compare dependencies
 │
 ▼
Open Loki
 │
 ▼
Inspect runtime evidence
 │
 ▼
Determine cause
```

---

# 51. Example: API Incident

Suppose:

```text
MWHighAPIErrorRate
```

fires.

The operator should:

```text
1. Open Application dashboard.

2. Confirm the error-rate increase.

3. Inspect request volume.

4. Inspect API latency.

5. Determine whether the degradation is isolated
   or systemic.

6. Inspect infrastructure/system dashboard.

7. Inspect dependency behavior.

8. Query Loki for the affected time window.

9. Inspect Runtime failure classification.

10. Determine remediation.
```

The dashboard is therefore one component of the incident workflow.

---

# 52. Example: Worker Incident

Suppose:

```text
MWQueueBacklogHigh
```

fires.

The operator should:

```text
1. Open Queue dashboard.

2. Inspect queue depth.

3. Compare queue depth with processing throughput.

4. Inspect job failure rate.

5. Inspect job latency.

6. Inspect retry behavior.

7. Inspect storage latency.

8. Inspect database latency.

9. Inspect Worker logs.

10. Determine whether processing capacity,
    dependency health, or application behavior
    is responsible.
```

---

# 53. Example: Host Incident

Suppose:

```text
MWHighCPUUsage
```

fires.

The operator should:

```text
1. Open System dashboard.

2. Confirm sustained CPU saturation.

3. Inspect memory pressure.

4. Inspect container resource consumption.

5. Identify the dominant workload.

6. Compare with application and Worker activity.

7. Inspect recent deployment or workload changes.

8. Determine whether capacity or abnormal workload
   is responsible.
```

---

# 54. Dashboard Governance

Dashboard definitions should be treated as operational configuration.

They should therefore be:

```text
version controlled
reviewed
validated
tested
deployed through automation
```

Changes to dashboards should be explainable through Git history.

This provides:

```text
auditability
reproducibility
rollback capability
change visibility
```

---

# 55. Dashboard Naming

Current dashboard filenames follow a descriptive naming model:

```text
application-health.json
queue-operations.json
system-overview.json
```

This is preferable to names such as:

```text
dashboard1.json
new-dashboard.json
test.json
```

because the filename itself communicates the dashboard's operational purpose.

---

# 56. Dashboard Ownership

Each dashboard should have an explicit architectural scope.

Current ownership boundaries are:

```text
system-overview
    → Host / infrastructure

application-health
    → API / application behavior

queue-operations
    → Worker / queue / asynchronous processing

deployment
    → Deployment lifecycle

incidents
    → Cross-system incident investigation
```

This prevents responsibility overlap.

---

# 57. Current Implementation Status

The current dashboard architecture can be summarized as:

| Dashboard Area | Provisioned | Implemented |
| -------------- | ----------: | ----------: |
| System         |         Yes |         Yes |
| Application    |         Yes |         Yes |
| Queue          |         Yes |         Yes |
| Deployment     |         Yes |          No |
| Incidents      |         Yes |          No |

The distinction between **provisioned** and **implemented** is intentional.

The provisioning layer already establishes the future structure, while actual dashboard content can be added incrementally.

---

# 58. Dashboard Reliability Considerations

Dashboards themselves depend on the observability stack.

A dashboard may appear empty because:

```text
Prometheus is unavailable
```

or:

```text
the target is not being scraped
```

or:

```text
the metric does not exist
```

or:

```text
the selected time range contains no data
```

or:

```text
the datasource is unavailable
```

Therefore an empty dashboard should never immediately be interpreted as:

```text
No system activity
```

The operator must first validate the datasource and metric pipeline.

---

# 59. Dashboard Validation

Dashboard validation should include:

```text
✓ Grafana starts successfully.

✓ Prometheus datasource is available.

✓ Loki datasource is available.

✓ Dashboard provisioning succeeds.

✓ Dashboard appears in the expected folder.

✓ Panels return data.

✓ PromQL expressions reference existing metrics.

✓ Time-series units are correct.

✓ Legends identify meaningful dimensions.

✓ Thresholds correspond to operational intent.

✓ Dashboard behavior remains correct after deployment.
```

---

# 60. Dashboard Failure Modes

Possible dashboard failures include:

```text
invalid dashboard JSON
missing datasource
incorrect datasource UID
invalid PromQL
renamed metrics
missing metrics
incorrect time units
broken provisioning path
dashboard not mounted
Grafana provisioning failure
```

Dashboard validation must therefore be part of observability deployment validation.

---

# 61. Dashboard Provisioning Path

The deployment chain is:

```text
Repository
    │
    ▼
observability/grafana/dashboards/
    │
    ▼
Ansible
    │
    ▼
/opt/deploy/compose/observability/
    │
    ▼
Docker Compose volume
    │
    ▼
/var/lib/grafana/dashboards/
    │
    ▼
Grafana Provisioning
    │
    ▼
Grafana Dashboard
```

This makes dashboard deployment reproducible.

---

# 62. Relationship with Infrastructure as Code

Dashboard configuration is part of the broader infrastructure reproducibility model.

The dashboard itself is not manually created on the host.

Instead:

```text
Dashboard JSON
      │
      ▼
Git Repository
      │
      ▼
Ansible Deployment
      │
      ▼
Grafana
```

This means the observability interface is reproducible together with the rest of the platform.

---

# 63. Relationship with CI/CD

Dashboard changes should follow the same engineering lifecycle as other repository changes:

```text
Change
  │
  ▼
Git Commit
  │
  ▼
Validation
  │
  ▼
CI
  │
  ▼
Deployment
  │
  ▼
Grafana
```

This avoids undocumented operational changes being introduced directly through the Grafana UI.

---

# 64. Dashboard and Deployment Correlation

A future Deployment dashboard should connect deployment state with application telemetry.

The intended model is:

```text
Deployment Version
       │
       ▼
Deployment Time
       │
       ▼
Application Metrics
       │
       ├── Error Rate
       ├── Latency
       └── Availability
```

This enables operators to distinguish:

```text
pre-existing degradation
```

from:

```text
deployment-induced degradation
```

---

# 65. Dashboard and Reliability Architecture

The Reliability Runtime produces execution-level signals such as:

```text
operation
dependency
failure_type
recoverable
retries
recovery
duration
```

These signals provide the diagnostic layer beneath high-level dashboards.

The architectural hierarchy is:

```text
Dashboard
   │
   ▼
Service-level symptom
   │
   ▼
Runtime-level evidence
   │
   ▼
Dependency-level evidence
```

This is especially important for API and Worker incidents.

---

# 66. Dashboard as an Operational Interface

The dashboard should not be treated as the source of truth.

The source of truth remains the underlying telemetry.

Therefore:

```text
Metrics
Logs
Runtime State
Alerts
Deployment State
```

are authoritative signals.

Grafana is the interface that makes those signals easier for humans to consume.

---

# 67. Current Dashboard Architecture Summary

Mini-Write currently provides three implemented operational dashboards:

```text
System
    └── system-overview.json

Application
    └── application-health.json

Queue
    └── queue-operations.json
```

and two provisioned future areas:

```text
Deployment
    └── future dashboard

Incidents
    └── future dashboard
```

These dashboards consume:

```text
Prometheus
Loki
```

through Grafana's provisioned datasources.

---

# 68. Operational Dashboard Model

The complete model is:

```text
                       Mini-Write
                           │
            ┌──────────────┼──────────────┐
            │              │              │
            ▼              ▼              ▼
        Application    Infrastructure    Worker
            │              │              │
            ▼              ▼              ▼
         Metrics        Metrics         Metrics
            │              │              │
            └──────────────┼──────────────┘
                           ▼
                       Prometheus
                           │
                           ▼
                        Grafana
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
      System          Application           Queue
     Dashboard        Dashboard           Dashboard
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                           ▼
                         Alert
                           │
                           ▼
                      Investigation
                           │
                           ▼
                          Loki
                           │
                           ▼
                    Runtime Evidence
```

---

# 69. Definition of Done

The Dashboard capability is considered operationally complete when:

```text
✓ Grafana is deployed reproducibly.

✓ Prometheus is provisioned as a datasource.

✓ Loki is provisioned as a datasource.

✓ Dashboard definitions are version-controlled.

✓ Dashboard provisioning is automated.

✓ System dashboard is available.

✓ Application dashboard is available.

✓ Queue dashboard is available.

✓ Dashboard folders reflect architectural boundaries.

✓ Dashboard panels reference valid telemetry.

✓ Dashboard queries use appropriate aggregation.

✓ Dashboard metrics are interpretable.

✓ Dashboard time ranges support incident investigation.

✓ Dashboards can be recreated from repository state.

✓ Dashboard changes are reviewable through Git.

✓ Dashboard availability is validated after deployment.
```

---

# 70. Final Dashboard Model

The Mini-Write Dashboard architecture can be summarized as:

```text
                         Telemetry
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
          Metrics          Logs         Runtime
             │              │              │
             ▼              ▼              ▼
        Prometheus         Loki       Application
             │              │           Runtime
             └──────────────┼──────────────┘
                            ▼
                         Grafana
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
          System       Application        Queue
             │              │              │
             └──────────────┼──────────────┘
                            ▼
                       Operator
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
          Detect         Diagnose       Validate
```

The core architectural principle is:

> **Dashboards are the human-facing operational view of the observability system, not an independent monitoring mechanism.**

Prometheus provides the quantitative system signals, Loki provides detailed log evidence, Runtime telemetry provides execution context, Alertmanager provides notification orchestration, and Grafana brings these signals together into operational views.

The current implementation establishes the **System, Application, and Queue** dashboard surfaces while deliberately reserving **Deployment** and **Incidents** as structured extension points for future observability maturity.

```
```
