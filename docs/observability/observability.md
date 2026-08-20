# Observability

## 1. Purpose

This document defines the Observability architecture of Mini-Write.

Observability provides the capability to understand the internal operational state of the system from the signals it produces externally.

The objective is not simply to collect telemetry.

The objective is to make the system answer operational questions such as:

- Is the system healthy?
- Which component is failing?
- When did the failure begin?
- Which operation is affected?
- Which dependency is responsible?
- Is the failure transient or persistent?
- Did the system recover automatically?
- Are requests becoming slower?
- Are background jobs accumulating?
- Is infrastructure becoming saturated?
- Did a deployment introduce the problem?

The architecture therefore follows:

```text
System Behavior
      │
      ▼
Telemetry Generation
      │
      ├───────────────┐
      ▼               ▼
   Metrics          Logs
      │               │
      └───────┬───────┘
              ▼
         Collection
              │
              ▼
          Correlation
              │
              ▼
        Visualization
              │
              ▼
           Alerting
              │
              ▼
       Human Diagnosis
              │
              ▼
       Operational Action
````

Observability is therefore an operational capability spanning the application, Runtime, Worker, infrastructure, deployment, and operations layers.

---

# 2. Observability Philosophy

Mini-Write treats Observability as part of the system architecture rather than as an external monitoring add-on.

The system should produce enough evidence to explain its behavior.

The fundamental model is:

```text
Behavior
   │
   ▼
Signal
   │
   ▼
Collection
   │
   ▼
Correlation
   │
   ▼
Interpretation
   │
   ▼
Decision
```

A dashboard without reliable underlying signals is not observability.

An alert without diagnostic evidence is not sufficient operational observability.

Logs without correlation are difficult to use during incidents.

Metrics without meaningful dimensions may identify symptoms without identifying causes.

Therefore the architecture must treat:

```text
Metrics
+
Logs
+
Correlation
+
Visualization
+
Alerting
```

as one integrated system.

---

# 3. Observability Goals

The Mini-Write Observability architecture has five primary goals.

## 3.1 Health Visibility

Determine whether:

* API is available;
* Worker is available;
* infrastructure is healthy;
* dependencies are operational;
* observability infrastructure itself is functioning.

---

## 3.2 Performance Visibility

Measure:

* request latency;
* job processing latency;
* dependency latency;
* resource utilization;
* queue backlog.

---

## 3.3 Failure Visibility

Determine:

* failure rate;
* failure type;
* affected operation;
* affected dependency;
* failure duration;
* recovery behavior.

---

## 3.4 Operational Diagnosis

Allow an operator to move from:

```text
Alert
  │
  ▼
Metric
  │
  ▼
Log
  │
  ▼
Operation
  │
  ▼
Dependency
  │
  ▼
Root Cause Investigation
```

---

## 3.5 Recovery Visibility

Determine whether:

* automatic retry occurred;
* recovery succeeded;
* retry was exhausted;
* service restarted;
* deployment rollback occurred;
* system remained degraded.

---

# 4. Observability Scope

Observability spans the following architectural domains:

```text
┌─────────────────────────────────────────────┐
│                 Application                 │
│                                             │
│ API                  Worker                 │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│                  Runtime                    │
│                                             │
│ Execution Context                           │
│ Operations                                  │
│ Reliability                                 │
│ Failure Classification                      │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│              Infrastructure                 │
│                                             │
│ PostgreSQL  Redis  MinIO  Docker  Host     │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│              Observability                  │
│                                             │
│ Prometheus  Loki  Promtail  Grafana         │
│ Alertmanager                               │
└─────────────────────────────────────────────┘
```

---

# 5. Observability Signals

Mini-Write primarily uses two telemetry signal families:

```text
Metrics
Logs
```

These signals are complemented by:

```text
Health Checks
Alerts
Dashboards
Runtime Context
```

The architecture does not require every signal to carry the same information.

Each signal has a distinct responsibility.

---

# 6. Metrics

Metrics answer quantitative questions.

Examples:

```text
How many requests?
How many failures?
How long do requests take?
How many jobs are queued?
How many jobs fail?
How many retries occur?
How much CPU is being consumed?
How much memory is available?
```

Prometheus is responsible for metrics collection and evaluation.

---

# 7. Logs

Logs answer event-oriented questions.

Examples:

```text
What happened?
Which operation was executing?
Which dependency failed?
What error occurred?
Which user or execution was involved?
Did the Runtime retry?
What was the final outcome?
```

Logs are emitted as structured JSON and collected by Promtail into Loki.

---

# 8. Health Signals

Health endpoints provide direct service state.

API exposes:

```text
/health/live
/health/ready
```

Liveness answers:

```text
Is the service process alive?
```

Readiness answers:

```text
Is the service capable of serving traffic?
```

These signals are deliberately different.

---

# 9. Alert Signals

Alerts transform observed conditions into operational events.

The architecture is:

```text
Metric
  │
  ▼
Prometheus Rule
  │
  ▼
Alert
  │
  ▼
Alertmanager
  │
  ▼
Receiver
```

Alerts therefore sit above telemetry rather than replacing it.

---

# 10. Observability Architecture

The complete architecture is:

```text
                    ┌──────────────────┐
                    │   API Service    │
                    └────────┬─────────┘
                             │
                    Metrics / Logs
                             │
                             ▼
                    ┌──────────────────┐
                    │  Worker Service │
                    └────────┬─────────┘
                             │
                    Metrics / Logs
                             │
                             ▼
              ┌─────────────────────────────┐
              │      Infrastructure         │
              │ PostgreSQL Redis MinIO Host │
              └──────────────┬──────────────┘
                             │
                             ▼
                  ┌─────────────────────┐
                  │   Telemetry Layer   │
                  │                     │
                  │ Prometheus          │
                  │ Promtail            │
                  └───────┬─────┬───────┘
                          │     │
                     Metrics   Logs
                          │     │
                          ▼     ▼
                   ┌────────┐ ┌──────┐
                   │Prom.   │ │Loki  │
                   └───┬────┘ └──┬───┘
                       │          │
                       └────┬─────┘
                            ▼
                       ┌─────────┐
                       │ Grafana │
                       └────┬────┘
                            │
                            ▼
                       Operators
```

Alerting branches from Prometheus:

```text
Prometheus
    │
    ▼
Alert Rules
    │
    ▼
Alertmanager
```

---

# 11. Telemetry Flow

## 11.1 Metrics Flow

```text
Application
    │
    ▼
Prometheus Metrics Endpoint
    │
    ▼
Prometheus Scrape
    │
    ▼
Prometheus TSDB
    │
    ├──► Grafana
    │
    └──► Alert Rules
             │
             ▼
        Alertmanager
```

---

## 11.2 Logging Flow

```text
Application
    │
    ▼
JSON stdout
    │
    ▼
Docker JSON Logs
    │
    ▼
Promtail
    │
    ▼
Loki
    │
    ▼
Grafana
    │
    ▼
Operator
```

Deployment logs have an additional path:

```text
Deployment Process
       │
       ▼
/opt/deploy/logs/*.log
       │
       ▼
Promtail
       │
       ▼
Loki
```

---

# 12. Prometheus Architecture

Prometheus is the central metrics collection and alert evaluation system.

Its responsibilities include:

* scraping metrics endpoints;
* storing time-series data;
* evaluating recording/alerting rules;
* exposing metrics to Grafana;
* forwarding alerts to Alertmanager.

Prometheus is configured through:

```text
observability/Prometheus/prometheus.yml
```

and rule files under:

```text
observability/Prometheus/rules/
```

---

# 13. Prometheus Scrape Targets

The current configuration collects telemetry from:

```text
Prometheus
API
Worker
Redis Exporter
PostgreSQL Exporter
Node Exporter
cAdvisor
Loki
Alertmanager
```

Conceptually:

```text
                 Prometheus
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
       API         Worker       Host
        │            │            │
        ▼            ▼            ▼
      Redis        Redis        Docker
      Postgres     MinIO        Runtime
```

This provides visibility across multiple architectural layers.

---

# 14. Scrape Intervals

The global Prometheus configuration uses:

```text
scrape_interval: 30s
evaluation_interval: 30s
```

Application services use a more frequent:

```text
scrape_interval: 15s
```

This provides faster visibility for application behavior while maintaining a less aggressive default for other targets.

---

# 15. Metrics Architecture

Metrics are divided conceptually into:

```text
Application Metrics
Runtime Metrics
Business Metrics
Infrastructure Metrics
Container Metrics
Observability Metrics
```

---

# 16. Application Metrics

The API exposes metrics for:

* HTTP request count;
* HTTP request duration;
* in-flight requests;
* HTTP errors;
* authentication attempts;
* upload requests;
* uploaded file size.

Examples include:

```text
mw_api_http_requests_total
mw_api_http_request_duration_seconds
mw_api_http_requests_in_flight
mw_api_http_errors_total
```

These provide the basic application health signal.

---

# 17. Worker Metrics

The Worker exposes metrics related to:

* processed jobs;
* failed jobs;
* retried jobs;
* active jobs;
* queue depth;
* queue state;
* job duration.

These metrics allow operators to reason about:

```text
throughput
backlog
failure rate
processing latency
```

---

# 18. Business Metrics

Business metrics describe application-level outcomes rather than infrastructure behavior.

API examples include:

```text
mw_business_user_registrations_total
mw_business_user_logins_total
mw_business_id_uploads_total
mw_business_id_upload_success_total
mw_business_id_upload_failures_total
mw_business_jobs_enqueued_total
```

These allow operational behavior to be connected to business activity.

---

# 19. Runtime Reliability Metrics

The Runtime exposes reliability-oriented metrics such as:

```text
runtime operations
runtime retries
runtime failures
runtime operation duration
```

These are particularly important because application success alone can hide dependency instability.

For example:

```text
HTTP Success = 100%
```

does not necessarily mean:

```text
Dependency Stability = 100%
```

if successful requests frequently required retries.

---

# 20. Infrastructure Metrics

Infrastructure metrics are collected through exporters.

The current architecture includes:

```text
Node Exporter
cAdvisor
Redis Exporter
PostgreSQL Exporter
```

These provide visibility into:

```text
Host
Containers
Redis
PostgreSQL
```

MinIO and application-specific infrastructure behavior is additionally observed through service metrics and application logs where available.

---

# 21. Host Observability

Node Exporter provides host-level metrics such as:

* CPU utilization;
* memory;
* filesystem capacity;
* filesystem availability;
* other host runtime measurements.

This enables infrastructure alerts such as:

```text
MWHighCPUUsage
MWHighMemoryUsage
MWLowDiskSpace
MWNodeExporterDown
```

---

# 22. Container Observability

cAdvisor provides container-level resource visibility.

This helps answer:

```text
Which container is consuming resources?
Is resource usage increasing?
Is a container under pressure?
Does application behavior correlate with container resource usage?
```

This is important when debugging application symptoms that originate from host or container resource constraints.

---

# 23. Logging Architecture

Mini-Write uses structured JSON logging.

The API logger produces records containing fields such as:

```text
timestamp
level
service
environment
event
request_id
operation_id
user_id
error information
```

Runtime logging additionally exposes:

```text
execution_id
dependency
failure_type
attempt
retries
outcome
```

This creates structured evidence rather than unstructured text output.

---

# 24. Structured Logging Model

A typical conceptual event looks like:

```json
{
  "timestamp": "...",
  "level": "error",
  "service": "api",
  "environment": "staging",
  "event": "runtime_operation_failed",
  "request_id": "...",
  "execution_id": "...",
  "operation_id": "id_upload",
  "dependency": "minio",
  "failure_type": "dependency",
  "recoverable": true
}
```

The exact event schema varies by event.

The important architectural property is that logs contain machine-readable operational context.

---

# 25. Correlation Context

The Runtime provides:

```text
request_id
execution_id
operation_id
```

These identifiers form the core execution correlation model.

Conceptually:

```text
Request
  │
  ├── request_id
  │
  └── execution_id
          │
          ▼
      Operation
          │
          ▼
      Dependency
          │
          ▼
       Failure
```

This allows logs from different stages of one execution to be interpreted together.

---

# 26. Request ID

The API Runtime generates a request identity.

It is also exposed through:

```text
X-Request-Id
```

This allows external callers and operators to connect:

```text
HTTP Request
```

with:

```text
Application Logs
Runtime Logs
Failure Events
```

---

# 27. Execution ID

The Runtime also creates an execution identity.

The distinction is useful:

```text
request_id
=
external/request correlation

execution_id
=
Runtime execution identity
```

The execution ID allows Runtime-specific operations to be correlated even when multiple internal mechanisms participate in the execution.

---

# 28. Operation Identity

Operations have stable identifiers such as:

```text
user_login
user_register
user_profile
id_upload
health_liveness
health_readiness
```

These identifiers are used by the Runtime and observability layers.

This allows operators to ask:

```text
Which operation is failing?
```

rather than only:

```text
Which endpoint is failing?
```

---

# 29. Dependency Identity

Infrastructure operations also identify the dependency:

```text
postgresql
redis
minio
```

This enables queries such as:

```text
Failures by dependency
Retries by dependency
Latency by dependency
```

and creates a bridge between application behavior and infrastructure health.

---

# 30. Log Collection With Promtail

Promtail collects Docker container logs using:

```text
/var/lib/docker/containers/*/*-json.log
```

It also collects deployment logs from:

```text
/opt/deploy/logs/*.log
```

The Docker pipeline:

```text
Docker JSON
   │
   ▼
Parse
   │
   ▼
Extract fields
   │
   ▼
Promote safe labels
   │
   ▼
Normalize timestamp
   │
   ▼
Drop high-cardinality labels
   │
   ▼
Loki
```

---

# 31. Label Cardinality

Observability systems must control cardinality.

Promtail deliberately avoids promoting fields such as:

```text
correlation_id
job_id
deployment_version
```

to Loki labels.

These values can have very high cardinality.

Instead, stable dimensions such as:

```text
service
level
```

are promoted as labels.

This is an important production-oriented observability constraint.

---

# 32. Loki Architecture

Loki provides centralized log storage and querying.

The current configuration uses:

```text
TSDB
filesystem object storage
single replica
```

with a configured retention period.

The architecture is appropriate for the current single-node environment.

It is not equivalent to a highly available distributed logging platform.

---

# 33. Log Retention

Loki currently uses:

```text
retention_period: 168h
```

which corresponds to seven days.

This provides a bounded operational history while preventing unlimited local storage consumption.

Retention is particularly important in a single-node environment where observability storage competes with application storage.

---

# 34. Grafana

Grafana is the primary visualization layer.

It consumes:

```text
Prometheus
Loki
```

and presents:

```text
dashboards
metrics
logs
operational views
```

Grafana is therefore not the telemetry source.

It is the interpretation and visualization layer.

---

# 35. Grafana Data Sources

The current provisioning defines:

```text
Prometheus
Loki
```

Prometheus is the default data source.

Loki provides centralized log access.

The data sources are provisioned declaratively rather than configured manually through the UI.

---

# 36. Dashboard Architecture

Dashboards are organized by operational domain:

```text
System
Application
Queue
Deployment
Incidents
```

The current repository includes dashboards representing:

```text
Application Health
Queue Operations
System Overview
```

The remaining folders provide architectural space for deployment and incident dashboards.

---

# 37. System Dashboard

The System dashboard provides host/infrastructure visibility.

It should answer questions such as:

```text
Is the host healthy?
Is CPU saturated?
Is memory constrained?
Is disk space becoming critical?
Are containers consuming abnormal resources?
```

---

# 38. Application Dashboard

The Application dashboard focuses on API behavior.

It should expose:

```text
Request volume
Error rate
Latency
In-flight requests
Authentication behavior
Upload behavior
```

The dashboard should allow operators to identify symptoms before moving to logs.

---

# 39. Queue Dashboard

The Queue dashboard focuses on Worker behavior.

Important dimensions include:

```text
Queue depth
Active jobs
Processed jobs
Failed jobs
Retry count
Processing latency
```

This makes background-processing health visible independently from API health.

---

# 40. Deployment Dashboard

The Deployment dashboard is intended to correlate:

```text
Deployment
   │
   ▼
Version
   │
   ▼
Service Behavior
```

This is useful when a degradation begins immediately after a release.

Deployment logs are available through the centralized logging path.

---

# 41. Incident Dashboard

The Incident dashboard is intended to provide an incident-oriented view combining signals needed during diagnosis.

The conceptual flow is:

```text
Alert
 │
 ├── Metrics
 │
 ├── Logs
 │
 ├── Service
 │
 ├── Dependency
 │
 └── Deployment
```

This reduces the time required to navigate between unrelated monitoring views.

---

# 42. Alerting Architecture

Prometheus evaluates alerting rules defined under:

```text
observability/Prometheus/rules/
```

The current rule groups include:

```text
01-infrastructure.yml
02-api.yml
03-worker.yml
```

The architecture separates alerts by operational domain.

---

# 43. Infrastructure Alerts

Infrastructure alerts currently cover conditions such as:

```text
Node Exporter unavailable
High CPU
High memory
Low disk space
```

These detect infrastructure-level degradation.

---

# 44. API Alerts

API alerts currently cover:

```text
API unavailable
High API error rate
High API latency
```

These represent user-facing application symptoms.

---

# 45. Worker Alerts

Worker alerts currently cover:

```text
Worker unavailable
High queue backlog
High job failure rate
High job latency
High storage latency
High database latency
```

These provide visibility into asynchronous processing and its dependencies.

---

# 46. Alert Severity

Alerts currently use severity levels such as:

```text
critical
warning
info
```

Severity represents operational urgency rather than failure type.

For example:

```text
category = infrastructure
severity = critical
```

means an infrastructure condition requiring urgent attention.

---

# 47. Alertmanager

Alertmanager receives alerts from Prometheus.

Its responsibilities include:

* grouping;
* routing;
* inhibition;
* receiver selection;
* future notification integration.

The current routing model groups by:

```text
environment
category
service
```

This prevents every individual alert from being treated as an entirely independent incident.

---

# 48. Alert Grouping

For example, during an API outage several symptoms may appear:

```text
API Down
High Error Rate
High Latency
```

Grouping can prevent the operator from receiving three unrelated conceptual incidents.

Instead, the alerts can be interpreted as:

```text
API incident
```

with multiple observed symptoms.

---

# 49. Alert Inhibition

The Alertmanager configuration suppresses warning alerts when a critical alert exists for the same:

```text
service
environment
```

This reduces alert noise.

Example:

```text
API critical outage
       │
       ├── critical API alert
       │
       └── warning API degradation
                 │
                 ▼
             inhibited
```

The intent is to focus operators on the primary failure condition.

---

# 50. Observability of Observability

The monitoring system itself must be observable.

Prometheus therefore scrapes:

```text
Prometheus
Loki
Alertmanager
```

This enables detection of failures in the telemetry pipeline itself.

For example:

```text
Application Healthy
       │
       ▼
Prometheus Cannot Scrape
       │
       ▼
Monitoring Blind Spot
```

Without monitoring the monitoring layer, this condition could remain invisible.

---

# 51. Monitoring Blind Spots

A key operational risk is:

```text
System Failure
      +
Telemetry Failure
```

which can result in:

```text
No evidence
```

Therefore the observability architecture explicitly monitors its own major components.

---

# 52. Observability Failure Domains

The observability stack has several failure domains:

```text
Application Instrumentation
        │
        ▼
Metrics Endpoint
        │
        ▼
Prometheus
        │
        ▼
Alertmanager
```

and:

```text
Application Logs
        │
        ▼
Docker Logging
        │
        ▼
Promtail
        │
        ▼
Loki
        │
        ▼
Grafana
```

Failure in any stage can create partial observability.

---

# 53. Partial Observability

Observability is not binary.

For example:

```text
Prometheus DOWN
```

may mean:

```text
Metrics unavailable
```

while:

```text
Loki UP
```

means:

```text
Logs still available
```

Therefore operators should understand which signals remain trustworthy during an observability incident.

---

# 54. Observability During Incidents

The recommended diagnostic sequence is:

```text
1. Check alert
       │
       ▼
2. Check service availability
       │
       ▼
3. Check error rate
       │
       ▼
4. Check latency
       │
       ▼
5. Identify affected operation
       │
       ▼
6. Identify dependency
       │
       ▼
7. Inspect correlated logs
       │
       ▼
8. Check infrastructure
       │
       ▼
9. Check recent deployment
       │
       ▼
10. Determine recovery action
```

This sequence follows symptom → scope → cause → action.

---

# 55. Observability and Reliability

Reliability mechanisms produce telemetry.

For example:

```text
Failure
   │
   ├── classification
   ├── retry
   ├── recovery
   └── final outcome
```

Observability captures this behavior.

This creates the feedback loop:

```text
Reliability Mechanism
       │
       ▼
Telemetry
       │
       ▼
Operational Observation
       │
       ▼
Engineering Improvement
```

Observability is therefore an essential component of Continuous Improvement.

---

# 56. Observability and Runtime

The Runtime introduces a structured execution model:

```text
Request
  │
  ▼
Execution Context
  │
  ├── Identity
  ├── Operation
  ├── Policy
  ├── Reliability
  ├── Failure
  └── Metadata
```

This context is highly valuable for observability because it gives telemetry a common semantic model.

---

# 57. Observability and Failure Engineering

The Failure Model defines:

```text
failure type
origin
scope
impact
recoverability
visibility
```

Observability provides the evidence used to detect and understand these failures.

The relationship is:

```text
Failure Engineering
        │
        ▼
What should be detected?
        │
        ▼
Observability Architecture
        │
        ▼
How is it detected?
```

---

# 58. Observability and Deployment

Deployment introduces another important correlation dimension.

A common incident question is:

```text
Did the latest deployment cause this?
```

The answer requires correlating:

```text
Deployment Time
+
Version
+
Metrics
+
Logs
+
Alerts
```

This is why deployment logs are part of the centralized observability path.

---

# 59. Observability and Infrastructure

Infrastructure telemetry provides the lower layer needed to explain application symptoms.

For example:

```text
API latency ↑
      │
      ▼
Container CPU ↑
      │
      ▼
Host CPU ↑
```

or:

```text
Worker latency ↑
      │
      ▼
PostgreSQL latency ↑
```

Without infrastructure telemetry, the diagnosis would stop at the application symptom.

---

# 60. Cardinality Strategy

Observability dimensions should be chosen carefully.

Good dimensions include:

```text
service
environment
operation
dependency
status
severity
category
```

Potentially dangerous dimensions include unbounded values such as:

```text
request_id
execution_id
user_id
job_id
raw URL
error message
```

These should generally remain event/log fields rather than metric labels.

---

# 61. Metrics vs Logs

The architectural division is:

| Question                | Preferred Signal |
| ----------------------- | ---------------- |
| How many?               | Metrics          |
| How often?              | Metrics          |
| How long?               | Metrics          |
| How much resource?      | Metrics          |
| What happened?          | Logs             |
| Which request?          | Logs             |
| Which execution?        | Logs             |
| Which error?            | Logs             |
| What dependency failed? | Both             |
| Is service down?        | Metrics / Health |
| Why did it fail?        | Logs + Metrics   |

No single signal should be expected to answer every question.

---

# 62. Dashboards vs Alerts

Dashboards answer:

```text
What is happening?
```

Alerts answer:

```text
What requires attention?
```

Logs answer:

```text
What happened?
```

Metrics answer:

```text
How much / how often / how long?
```

This separation prevents dashboards from becoming overloaded with alert logic and alerts from becoming overloaded with diagnostic information.

---

# 63. Observability as a Diagnostic System

The real value of the architecture is not the number of metrics or dashboards.

It is the ability to move through a diagnostic chain:

```text
Symptom
  │
  ▼
Signal
  │
  ▼
Scope
  │
  ▼
Component
  │
  ▼
Operation
  │
  ▼
Dependency
  │
  ▼
Failure
  │
  ▼
Recovery
```

A production-grade observability system should minimize the number of undocumented jumps required to traverse this chain.

---

# 64. Example: API Incident

Suppose users report slow requests.

The observability path is:

```text
API latency alert
       │
       ▼
Grafana Application Dashboard
       │
       ▼
95th percentile latency ↑
       │
       ▼
HTTP error rate
       │
       ▼
Runtime operation metrics
       │
       ▼
Dependency = PostgreSQL
       │
       ▼
PostgreSQL latency metrics
       │
       ▼
Correlated API logs
       │
       ▼
Database failure evidence
```

This transforms an abstract symptom into an actionable diagnosis.

---

# 65. Example: Worker Incident

Suppose background processing slows down.

The diagnostic path is:

```text
Queue backlog alert
       │
       ▼
Queue Dashboard
       │
       ▼
Queue depth ↑
       │
       ▼
Job latency ↑
       │
       ▼
Job failure/retry rate
       │
       ▼
Storage / Database latency
       │
       ▼
Worker logs
       │
       ▼
Dependency diagnosis
```

The observability architecture therefore connects queue behavior to dependency behavior.

---

# 66. Example: Infrastructure Incident

Suppose the application becomes unstable.

The operator can investigate:

```text
Application Error Rate
        │
        ▼
Container Resource Usage
        │
        ▼
Host CPU / Memory
        │
        ▼
Disk Availability
        │
        ▼
Infrastructure Logs
```

This prevents application symptoms from being diagnosed in isolation.

---

# 67. Example: Deployment Incident

Suppose an incident begins immediately after deployment.

The investigation becomes:

```text
Deployment Log
      │
      ▼
Deployment Time
      │
      ▼
Application Metrics
      │
      ▼
Error Rate / Latency
      │
      ▼
Application Logs
      │
      ▼
Runtime Failure
      │
      ▼
Rollback Decision
```

This is one of the primary reasons deployment telemetry belongs in the same observability architecture.

---

# 68. Observability Security

Observability data can contain sensitive information.

Logs may contain:

```text
user identifiers
request metadata
error messages
operational details
```

Therefore observability should follow:

* minimum necessary logging;
* controlled access;
* avoidance of secrets;
* avoidance of passwords/tokens;
* controlled retention;
* bounded label cardinality.

The observability layer must never become a secondary secret store.

---

# 69. Logging Security

Sensitive values should not be logged.

Examples of values that should not appear in logs:

```text
passwords
JWT secrets
database credentials
access tokens
private keys
```

Application logging should focus on operational metadata rather than credential material.

---

# 70. Retention Strategy

Observability retention must balance:

```text
diagnostic value
+
storage cost
+
privacy
+
operational requirements
```

The current Loki retention is bounded to seven days.

Prometheus retention is governed by the deployment/storage configuration rather than by the application itself.

---

# 71. Single-Node Constraints

Mini-Write currently operates in a single-node environment.

Therefore the observability architecture has explicit limitations:

```text
single Prometheus
single Loki
single Grafana
single Alertmanager
single-node filesystem storage
```

This means observability itself is not highly available.

If the host fails:

```text
Application
+
Observability
```

may become unavailable together.

---

# 72. Why This Is Acceptable

The current architecture is intentionally designed around the project's environment rather than pretending to provide distributed production infrastructure.

The goal is:

```text
Production-oriented engineering behavior
```

within:

```text
Single-node local infrastructure
```

The architecture can later evolve toward:

```text
HA Prometheus
Distributed Loki
Remote object storage
Multiple monitoring nodes
External alert delivery
```

without changing the conceptual observability model.

---

# 73. Current Observability Components

| Component           | Responsibility                          |
| ------------------- | --------------------------------------- |
| prom-client         | application metrics instrumentation     |
| Prometheus          | metrics collection and alert evaluation |
| Node Exporter       | host metrics                            |
| cAdvisor            | container metrics                       |
| Redis Exporter      | Redis metrics                           |
| PostgreSQL Exporter | PostgreSQL metrics                      |
| Promtail            | log collection                          |
| Loki                | log storage/querying                    |
| Grafana             | visualization                           |
| Alertmanager        | alert routing/grouping/inhibition       |

---

# 74. Declarative Observability

A major architectural property is that observability configuration is stored in the repository.

Examples include:

```text
observability/Prometheus/prometheus.yml
observability/Prometheus/rules/
observability/promtail/config.yml
observability/loki/config.yml
observability/alertmanager/alertmanager.yml
observability/grafana/provisioning/
observability/grafana/dashboards/
```

This provides:

```text
version control
reproducibility
reviewability
configuration history
```

and reduces dependence on manual UI configuration.

---

# 75. Observability Provisioning

Grafana data sources, dashboard providers, and alert contact points are provisioned declaratively.

This means the monitoring environment can be reconstructed from repository configuration.

The desired model is:

```text
Git Repository
      │
      ▼
Observability Configuration
      │
      ▼
Docker Deployment
      │
      ▼
Monitoring Stack
```

rather than:

```text
Manual UI Configuration
      │
      ▼
Unknown Runtime State
```

---

# 76. Observability Change Management

Observability changes should be treated like application changes.

Examples:

```text
new metric
new alert
dashboard modification
new label
retention change
Prometheus scrape change
Loki pipeline change
```

should be:

```text
reviewed
versioned
tested
deployed
validated
```

A broken alert can be as operationally harmful as a broken application feature.

---

# 77. Alert Quality Principles

Alerts should satisfy:

```text
Actionable
Specific
Stable
Observable
Bounded
```

An alert should ideally answer:

```text
What is wrong?
Where?
How severe?
How long?
What should the operator investigate?
```

The current alert annotations include:

```text
summary
description
impact
action
```

which supports this model.

---

# 78. Alert Fatigue Prevention

The architecture attempts to limit alert fatigue through:

* severity classification;
* grouping;
* inhibition;
* meaningful thresholds;
* `for` durations;
* domain-specific rules.

For example:

```text
CPU > 90%
```

does not immediately alert.

The condition must persist for:

```text
10m
```

This reduces alerts caused by short-lived spikes.

---

# 79. Observability Validation

Observability should itself be tested.

Validation should include:

```text
Metric endpoint reachable
Prometheus scraping successfully
Logs reaching Loki
Grafana data sources available
Dashboards loading
Alerts evaluating
Alertmanager receiving alerts
```

Failure injection should also verify:

```text
Failure
   │
   ▼
Signal Generated
   │
   ▼
Signal Collected
   │
   ▼
Alert Generated
   │
   ▼
Operator Can Diagnose
```

---

# 80. Observability Definition of Done

The Observability capability is operationally meaningful when:

```text
✓ API exposes application metrics

✓ Worker exposes processing metrics

✓ Runtime exposes reliability metrics

✓ Host metrics are collected

✓ Container metrics are collected

✓ Dependency metrics are collected where exporters exist

✓ Application logs are structured

✓ Logs are centrally collected

✓ Logs are queryable

✓ Runtime identities are available for correlation

✓ Prometheus evaluates alert rules

✓ Alertmanager routes and groups alerts

✓ Grafana exposes operational dashboards

✓ Deployment logs are observable

✓ Observability components are themselves monitored

✓ High-cardinality labels are controlled

✓ Telemetry retention is bounded

✓ Observability configuration is version-controlled

✓ Failure scenarios can be diagnosed using available signals
```

---

# 81. Known Architectural Limitations

The current observability architecture intentionally has limitations.

It does not currently provide:

* distributed tracing;
* OpenTelemetry-based tracing;
* cross-service trace propagation;
* highly available telemetry storage;
* external long-term metrics storage;
* automated remediation;
* fully automated incident workflows;
* guaranteed end-to-end correlation across every signal;
* complete MinIO exporter coverage.

These are architectural extension points rather than undocumented assumptions.

---

# 82. Future Evolution

Potential future evolution includes:

```text
OpenTelemetry
     │
     ▼
Distributed Tracing
     │
     ▼
Trace ↔ Metrics ↔ Logs
```

alongside:

```text
Remote Metrics Storage
Distributed Logging
External Alert Delivery
SLO / Error Budget Monitoring
Automated Remediation
Advanced Incident Correlation
```

These should be introduced only when the project's scale and operational requirements justify the additional complexity.

---

# 83. Observability Architectural Invariants

## Invariant 1 — Every Critical Service Must Produce Observable Signals

A service without telemetry creates an operational blind spot.

## Invariant 2 — Metrics Must Remain Low Cardinality

High-cardinality identifiers belong primarily in logs/events.

## Invariant 3 — Logs Must Carry Operational Context

Logs should provide enough context to connect events to executions and operations.

## Invariant 4 — Alerts Must Be Actionable

An alert should imply an investigation or operational action.

## Invariant 5 — Dashboards Must Support Diagnosis

Dashboards should expose operationally meaningful relationships, not only visually attractive charts.

## Invariant 6 — Observability Must Be Version Controlled

Monitoring configuration is infrastructure configuration.

## Invariant 7 — Observability Must Be Observable

Failure of the monitoring system itself must be detectable.

## Invariant 8 — Telemetry Must Not Contain Secrets

Observability must not compromise application security.

---

# 84. Operational Query Model

The observability architecture should allow an operator to answer questions in this order:

```text
1. Is the system healthy?
2. Which service is affected?
3. Is the problem availability, latency, or correctness?
4. When did it start?
5. Which operation is affected?
6. Which dependency is involved?
7. Is the failure transient?
8. Did Runtime recovery occur?
9. Did recovery succeed?
10. Did a deployment precede the incident?
11. Is infrastructure contributing?
12. What action should be taken?
```

This query model represents the practical purpose of the entire observability stack.

---

# 85. Final Architecture

The Mini-Write Observability architecture can be summarized as:

```text
                         ┌──────────────────────┐
                         │      SYSTEM          │
                         │                      │
                         │ API / Worker         │
                         │ Runtime              │
                         │ Infrastructure       │
                         └──────────┬───────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
                METRICS                           LOGS
                    │                               │
                    ▼                               ▼
               Prometheus                        Promtail
                    │                               │
                    ▼                               ▼
              Time Series                           Loki
                    │                               │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                                 Grafana
                                    │
                         ┌──────────┴──────────┐
                         │                     │
                         ▼                     ▼
                    Dashboards              Diagnosis
                         │
                         ▼
                     Operator


Prometheus
    │
    ▼
Alert Rules
    │
    ▼
Alertmanager
    │
    ▼
Operational Response
```

The essential architectural chain is:

```text
System Behavior
      │
      ▼
Telemetry
      │
      ▼
Collection
      │
      ▼
Correlation
      │
      ▼
Visualization
      │
      ▼
Alerting
      │
      ▼
Diagnosis
      │
      ▼
Operational Action
      │
      ▼
Engineering Improvement
```

This is the central role of Observability in Mini-Write.

Observability is not merely the presence of Prometheus, Loki, Grafana, and Alertmanager. It is the capability to transform system behavior into reliable operational evidence and use that evidence to understand failures, validate recovery, operate the platform, and continuously improve the engineering system.

```

### الوثائق المرتبطة

- `docs/observability/metrics.md` — تفاصيل Metrics architecture وinstrumentation.
- `docs/observability/logging.md` — تفاصيل Structured Logging وLoki/Promtail.
- `docs/observability/alerting.md` — تفاصيل Alert Rules وAlertmanager.
- `docs/observability/dashboards.md` — تفاصيل Grafana dashboards.
- `docs/reliability/failure-model.md` — مصدر تعريف Failure Classification وDetection.
- `docs/reliability/runtime-reliability.md` — مصدر Runtime Reliability وRecovery telemetry.
- `docs/operations/incident-response.md` — استخدام Observability أثناء Incident Response.
```
