# Logging

## 1. Purpose

This document defines the Logging architecture of Mini-Write.

Logging provides the detailed, event-oriented observability signal required to understand individual executions, failures, state transitions, operational actions, and application behavior.

Where Metrics answer:

> "What is happening, and how often?"

Logs answer:

> "What exactly happened, to which execution, and with what context?"

The Logging architecture therefore complements the Metrics architecture:

```text
                    System Behavior
                          │
             ┌────────────┴────────────┐
             │                         │
             ▼                         ▼
          Metrics                    Logs
             │                         │
             ▼                         ▼
        Aggregated              Individual Events
        Behavior                  + Context
             │                         │
             ▼                         ▼
        Prometheus                  Loki
             │                         │
             └────────────┬────────────┘
                          ▼
                       Grafana
````

The objective is to provide enough structured evidence to reconstruct an operational event without turning logs into an uncontrolled source of high-cardinality telemetry.

---

# 2. Logging Philosophy

Mini-Write uses **structured logging** rather than unstructured human-oriented text.

The fundamental log model is:

```text
Event
  +
Context
  +
Outcome
  +
Error Information
  +
Operational Metadata
```

A log entry should therefore describe a meaningful event rather than simply print arbitrary diagnostic text.

For example:

```json
{
  "timestamp": "2026-08-16T10:00:00.000Z",
  "level": "error",
  "service": "api",
  "environment": "staging",
  "event": "runtime_operation_failed",
  "request_id": "req_...",
  "execution_id": "exec_...",
  "operation_id": "id_upload",
  "dependency": "minio",
  "failure_type": "dependency",
  "recoverable": true,
  "error_message": "..."
}
```

The exact runtime values vary, but the architectural principle remains constant.

---

# 3. Why Structured Logging Is Used

Structured logging provides several operational advantages.

### 3.1 Machine Processability

Logs can be parsed by Loki and queried by Grafana.

### 3.2 Consistent Context

Common fields can be correlated across different events.

### 3.3 Incident Investigation

Operators can reconstruct an execution lifecycle.

### 3.4 Automation

Fields such as `level`, `service`, and `event` can be used for filtering and analysis.

### 3.5 Separation of Concerns

Metrics provide aggregate behavior while logs provide execution-level evidence.

---

# 4. Logging Architecture

The current logging pipeline is:

```text
┌──────────────────────┐
│ API / Worker         │
│                      │
│ Structured Logger    │
└──────────┬───────────┘
           │
           │ JSON to stdout
           ▼
┌──────────────────────┐
│ Docker Container     │
│ JSON Log Driver      │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Promtail             │
│                      │
│ Parse Docker JSON    │
│ Parse Log JSON       │
│ Extract Fields       │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Loki                 │
│                      │
│ Log Storage          │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Grafana              │
│                      │
│ Log Exploration      │
│ Dashboard Queries    │
└──────────────────────┘
```

This architecture deliberately separates:

```text
Application Logging
        │
        ▼
Log Collection
        │
        ▼
Log Storage
        │
        ▼
Log Exploration
```

---

# 5. Application Logging

The application logger is implemented in:

```text
api/src/observability/logger.js
```

The Worker contains the corresponding adapted implementation.

The logger provides three primary methods:

```javascript
logger.info(...)
logger.warn(...)
logger.error(...)
```

These methods represent the primary application-level logging interface.

Application code should use the logger rather than writing arbitrary output directly whenever the message represents an operational event.

---

# 6. Logger Implementation

The logger constructs a structured object:

```javascript
const logEntry = {
  timestamp: new Date().toISOString(),
  level,
  service: SERVICE_NAME,
  environment: ENVIRONMENT,
  ...payload
};
```

The object is serialized using:

```javascript
console.log(JSON.stringify(logEntry));
```

The resulting output is therefore JSON Lines-style structured logging.

Conceptually:

```text
Application Event
      │
      ▼
Structured Object
      │
      ▼
JSON Serialization
      │
      ▼
stdout
```

---

# 7. Standard Log Fields

The current logger automatically provides:

```text
timestamp
level
service
environment
```

These are foundational fields.

### `timestamp`

Identifies when the event was emitted.

### `level`

Identifies the event severity:

```text
info
warn
error
```

### `service`

Identifies the originating service.

Current services include:

```text
api
worker
```

### `environment`

Identifies the execution environment.

The application logger derives this from:

```text
NODE_ENV
```

with a development fallback.

---

# 8. Event Field

Application events use the:

```text
event
```

field.

The event vocabulary is centralized in:

```text
api/src/observability/events.js
```

This prevents arbitrary event strings from spreading throughout the application.

Examples include:

```text
request_started
request_completed
request_failed
user_registered
user_registration_failed
user_login_success
user_login_failed
id_upload_started
id_upload_success
id_upload_failed
job_enqueued
```

Runtime events include:

```text
runtime_operation_started
runtime_operation_completed
runtime_operation_retry
runtime_operation_failed
runtime_failure_handled
runtime_completed
```

---

# 9. Event Taxonomy

The event vocabulary is organized around operational domains.

```text
Events
│
├── Request Lifecycle
│   ├── request_started
│   ├── request_completed
│   └── request_failed
│
├── Authentication
│   ├── user_registered
│   ├── user_registration_failed
│   ├── user_login_success
│   └── user_login_failed
│
├── Upload Workflow
│   ├── id_upload_started
│   ├── id_upload_success
│   ├── id_upload_failed
│   └── job_enqueued
│
├── Authorization
│   ├── access_denied
│   └── invalid_token
│
├── Internal Failures
│   ├── database_error
│   ├── storage_error
│   └── internal_error
│
└── Runtime Reliability
    ├── runtime_operation_started
    ├── runtime_operation_completed
    ├── runtime_operation_retry
    ├── runtime_operation_failed
    ├── runtime_failure_handled
    └── runtime_completed
```

This taxonomy provides a common vocabulary for operational investigation.

---

# 10. Request Context

Request-level context is constructed in:

```text
api/src/observability/logContext.js
```

The primary context fields are:

```text
request_id
operation_id
user_id
```

The context helpers include:

```javascript
buildRequestContext(req)
buildUserContext(req, userId)
buildOperationContext(req, operationId, userId)
```

These functions provide consistent correlation fields to application logs.

---

# 11. Request ID

The Runtime generates a request identity:

```text
req_<random-value>
```

The generated request ID is available through:

```text
req.runtime.getIdentity().requestId
```

and is also preserved through the compatibility field:

```text
req.runtime.requestId
```

The API exposes the request ID to the caller using:

```text
X-Request-Id
```

This establishes an important relationship:

```text
HTTP Response
      │
      └── X-Request-Id
              │
              ▼
           Logs
              │
              ▼
        Runtime Execution
```

An operator can therefore use the request ID as a bridge between the external request and internal logs.

---

# 12. Execution ID

The Runtime additionally generates:

```text
executionId
```

The execution ID identifies the Runtime execution context associated with the request.

This is distinct from the request ID.

The conceptual distinction is:

```text
request_id
    │
    └── External/request correlation

execution_id
    │
    └── Runtime execution identity
```

Runtime-specific logs use both values.

---

# 13. Operation ID

Operations are explicitly represented by the Runtime.

Examples include:

```text
user_login
user_register
user_profile
id_upload
health_liveness
health_readiness
```

The Runtime resolves the operation before application execution begins.

Runtime logs therefore include:

```text
operation_id
```

where appropriate.

This allows logs to be queried by semantic operation rather than only by URL.

---

# 14. User Context

Some application events include:

```text
user_id
```

through `buildOperationContext()`.

This is useful for application-level troubleshooting.

However, user identifiers must be handled carefully because they can have privacy and cardinality implications.

They should not automatically become Loki labels or Prometheus labels.

They should remain structured log fields unless there is a specific, justified operational requirement.

---

# 15. Runtime Logging

Runtime logging provides operational evidence around reliability execution.

The Runtime logs:

```text
operation start
operation completion
retry
operation failure
runtime failure handling
runtime completion
```

This provides a lifecycle such as:

```text
Operation Started
      │
      ▼
Execution Attempt
      │
      ├───────────────┐
      │               │
      ▼               ▼
   Success          Failure
      │               │
      │               ▼
      │             Retry
      │               │
      │               ▼
      │          Next Attempt
      │               │
      └───────┬───────┘
              ▼
       Operation Completed
```

---

# 16. Runtime Operation Start

`runtime_operation_started` is emitted when an infrastructure operation enters the Runtime boundary.

The event contains context such as:

```text
request_id
execution_id
operation_id
dependency
```

This allows the beginning of an infrastructure interaction to be identified.

---

# 17. Runtime Operation Completion

`runtime_operation_completed` is emitted when the infrastructure operation completes successfully.

The log includes:

```text
outcome
attempts
```

The outcome can distinguish:

```text
success
recovered
```

This is important because a recovered operation is not equivalent operationally to an operation that succeeded on its first attempt.

---

# 18. Runtime Retry Logging

When an operation is retried, the Runtime emits:

```text
runtime_operation_retry
```

The event includes information such as:

```text
failure_type
attempt
next_attempt
error_message
dependency
operation_id
request_id
execution_id
```

The resulting sequence can therefore be reconstructed:

```text
Attempt 1
   │
   ▼
Failure
   │
   ▼
runtime_operation_retry
   │
   ▼
Attempt 2
```

---

# 19. Runtime Failure Logging

When an infrastructure operation ultimately fails, the Runtime emits:

```text
runtime_operation_failed
```

The log contains information such as:

```text
failure_type
recoverable
error_message
error_code
dependency
operation_id
request_id
execution_id
```

This creates a structured failure record.

---

# 20. Runtime Failure Handling

The global Runtime failure handler emits:

```text
runtime_failure_handled
```

The event includes:

```text
request_id
execution_id
operation_id
state
failure_type
recoverable
reliability_activated
retries
error_message
```

This event represents the Runtime's final failure-handling boundary.

It is distinct from the original infrastructure failure.

---

# 21. Runtime Completion

The Runtime completion observer emits:

```text
runtime_completed
```

when the HTTP response finishes and the Runtime is still in:

```text
initialized
```

or:

```text
active
```

state.

The event includes:

```text
request_id
execution_id
operation_id
state
failure_occurred
reliability_activated
```

This gives the logging system a terminal lifecycle event.

---

# 22. Runtime Logging Lifecycle

A normal successful execution may therefore look conceptually like:

```text
runtime_operation_started
        │
        ▼
runtime_operation_completed
        │
        ▼
runtime_completed
```

A recovered execution may look like:

```text
runtime_operation_started
        │
        ▼
runtime_operation_retry
        │
        ▼
runtime_operation_completed
        │
        ▼
runtime_completed
```

A terminal failure may look like:

```text
runtime_operation_started
        │
        ▼
runtime_operation_retry
        │
        ▼
runtime_operation_failed
        │
        ▼
runtime_failure_handled
```

This lifecycle is useful during incident reconstruction.

---

# 23. Application Failure Logging

Application controllers also emit domain-specific events.

For example, registration logs:

```text
user_registered
user_registration_failed
```

Login logs:

```text
user_login_success
user_login_failed
```

Upload logs:

```text
id_upload_started
id_upload_success
id_upload_failed
```

This creates a distinction between:

```text
technical failure
```

and:

```text
business/application outcome
```

---

# 24. Authentication Logging

Login failures include structured reasons such as:

```text
user_not_found
invalid_password
```

These reasons are stored as fields rather than embedded in an arbitrary text message.

For example:

```json
{
  "event": "user_login_failed",
  "operation_id": "login",
  "username": "...",
  "reason": "user_not_found"
}
```

The actual implementation should be evaluated carefully for sensitive-data exposure before being used in a production environment.

---

# 25. Registration Logging

Successful registration logs include:

```text
event
request_id
operation_id
user_id
username
```

Duplicate-user failures include:

```text
event
request_id
operation_id
username
reason
```

Other registration failures include:

```text
error_message
```

This allows operators to distinguish expected business failures from unexpected server failures.

---

# 26. Upload Workflow Logging

The upload workflow generates multiple operational events:

```text
id_upload_started
        │
        ▼
Storage Upload
        │
        ▼
Database Update
        │
        ▼
Job Enqueued
        │
        ▼
id_upload_success
```

Failures are logged as:

```text
id_upload_failed
```

This provides visibility across the multi-dependency workflow.

---

# 27. Dependency Context

Infrastructure operations explicitly identify their dependency.

Current dependency identifiers are:

```text
postgresql
redis
minio
```

This field appears in Runtime infrastructure logs.

The resulting diagnostic relationship is:

```text
request_id
     +
execution_id
     +
operation_id
     +
dependency
     +
failure_type
```

This is substantially more useful than a generic:

```text
"database failed"
```

message.

---

# 28. Error Information

Errors are logged using structured fields such as:

```text
error_message
error_code
failure_type
```

Runtime failures also retain the classification:

```text
timeout
dependency
validation
authentication
authorization
internal
```

This enables filtering and aggregation in Loki without parsing natural-language messages.

---

# 29. Error Message vs Error Classification

These fields serve different purposes.

### `error_message`

Answers:

> What did the underlying error say?

### `failure_type`

Answers:

> How does the Runtime classify the failure operationally?

For example:

```text
error_message:
"connect ECONNREFUSED ..."

failure_type:
"dependency"
```

The first is diagnostic detail.

The second is operational classification.

---

# 30. Logging Levels

The current logger supports:

```text
info
warn
error
```

### INFO

Used for normal lifecycle and successful operational events.

Examples:

```text
runtime_operation_started
runtime_operation_completed
user_registered
user_login_success
id_upload_success
```

### WARN

Used for abnormal but non-terminal conditions.

Examples:

```text
runtime_operation_retry
user_login_failed
duplicate registration
```

### ERROR

Used for failures requiring investigation or representing unsuccessful execution.

Examples:

```text
runtime_operation_failed
runtime_failure_handled
id_upload_failed
```

---

# 31. Log Levels Are Not Failure Classification

Log severity and failure classification are separate concepts.

For example:

```text
level = error
failure_type = dependency
```

is different from:

```text
level = error
failure_type = timeout
```

Similarly:

```text
level = warn
failure_type = dependency
```

could represent a transient condition that is being retried.

The two dimensions should not be conflated.

---

# 32. Logging to stdout

Application logs are written to:

```text
stdout
```

rather than directly to files inside the application container.

This is consistent with container-oriented logging architecture.

The flow is:

```text
Application
    │
    ▼
stdout
    │
    ▼
Docker logging
    │
    ▼
Promtail
```

This avoids coupling the application to a local filesystem logging implementation.

---

# 33. Docker Log Collection

Promtail reads Docker container JSON logs from:

```text
/var/lib/docker/containers/*/*-json.log
```

The relevant configuration is:

```text
observability/promtail/config.yml
```

Promtail uses:

```yaml
- docker: {}
```

to parse the Docker JSON log envelope.

This is followed by parsing the application log payload itself.

---

# 34. Promtail Pipeline

The current Docker log pipeline is:

```text
Docker JSON Log
      │
      ▼
docker parser
      │
      ▼
JSON application fields
      │
      ▼
Field extraction
      │
      ▼
Safe labels
      │
      ▼
Timestamp normalization
      │
      ▼
High-cardinality label removal
      │
      ▼
Loki
```

This is an important separation between:

```text
log fields
```

and:

```text
Loki labels
```

---

# 35. JSON Field Extraction

Promtail extracts:

```text
level
service
correlation_id
job_id
deployment_version
```

from the structured JSON log payload.

The purpose is to make selected fields available to the processing pipeline.

Not every extracted field becomes a Loki label.

---

# 36. Loki Labels

The current Promtail configuration promotes:

```text
level
service
```

to Loki labels.

This is a deliberate cardinality control mechanism.

The resulting conceptual Loki stream is:

```text
{service="api", level="error"}
```

rather than:

```text
{
  service="api",
  level="error",
  request_id="...",
  execution_id="...",
  user_id="...",
  job_id="..."
}
```

The latter would produce unnecessary cardinality.

---

# 37. High-Cardinality Field Protection

Promtail explicitly drops:

```text
correlation_id
job_id
deployment_version
```

from the label set.

This demonstrates the intended architectural rule:

```text
Useful for search
        ≠
Useful as a Loki label
```

A field may remain part of the log payload while not becoming an indexed label.

---

# 38. Important Correlation Field Consideration

The current Promtail configuration extracts:

```text
correlation_id
job_id
deployment_version
```

while the current API Runtime logging model primarily uses:

```text
request_id
execution_id
operation_id
```

and the logger does not automatically generate a field named:

```text
correlation_id
```

Therefore these concepts should not be assumed to be identical.

The current architecture effectively has two generations of correlation terminology:

```text
Existing Promtail expectations
        │
        ├── correlation_id
        ├── job_id
        └── deployment_version

Current Runtime context
        │
        ├── request_id
        ├── execution_id
        └── operation_id
```

This is an important documentation and implementation consideration.

Future logging evolution should establish an explicit canonical correlation model rather than silently treating these fields as interchangeable.

---

# 39. Timestamp Handling

Application logs generate:

```text
timestamp
```

using:

```javascript
new Date().toISOString()
```

Promtail then normalizes the timestamp using:

```yaml
- timestamp:
    source: timestamp
    format: RFC3339
```

The result is a consistent event timestamp in Loki.

The intended model is:

```text
Application Timestamp
        │
        ▼
Promtail Timestamp Parsing
        │
        ▼
Loki Event Time
```

---

# 40. Deployment Logs

Promtail also collects deployment logs from:

```text
/opt/deploy/logs/*.log
```

These logs are assigned:

```text
service: deployment
environment: staging
job: deployment
```

This extends the logging architecture beyond application services.

The overall log domains therefore include:

```text
Application
Worker
Infrastructure / Container
Deployment
```

---

# 41. Loki

Loki is the centralized log storage system.

The current configuration is:

```text
observability/loki/config.yml
```

Loki listens on:

```text
3100
```

and uses filesystem-backed storage.

The current architecture is:

```text
Promtail
    │
    ▼
Loki
    │
    ▼
Filesystem
```

---

# 42. Loki Storage

The current Loki configuration uses:

```text
filesystem
```

for object storage.

The chunk directory is:

```text
/loki/chunks
```

This is appropriate for the project's current single-node environment.

It does not provide distributed log storage or cross-node redundancy.

---

# 43. Loki Retention

The current retention period is:

```text
168h
```

which corresponds to:

```text
7 days
```

The retention policy is enabled through the Loki compactor.

The model is:

```text
Logs
  │
  ▼
Loki
  │
  ▼
7-day retention
  │
  ▼
Automatic expiration
```

This prevents unbounded local log growth.

---

# 44. Loki Ingestion Limits

The current configuration defines:

```text
ingestion_rate_mb: 8
ingestion_burst_size_mb: 16
```

These limits protect Loki against uncontrolled ingestion.

They should be evaluated against the expected workload as the system evolves.

---

# 45. Loki Query Limits

The current configuration defines:

```text
max_entries_limit_per_query: 5000
```

This limits the amount of log data returned by an individual query.

This protects the monitoring system from excessively expensive queries.

---

# 46. Grafana as the Log Exploration Layer

Grafana consumes Loki logs through the provisioned Loki datasource.

The datasource is:

```text
Loki
```

with:

```text
uid: loki
```

and:

```text
url: http://loki:3100
```

Grafana therefore provides the primary operator interface for log exploration.

---

# 47. Logging and Metrics Relationship

Metrics and logs are complementary.

```text
Metrics
  │
  ├── detect abnormal behavior
  │
  └── quantify impact

Logs
  │
  ├── explain individual events
  │
  └── reconstruct execution
```

For example:

```text
Metric:
API error rate = 12%

        │
        ▼

Logs:
runtime_operation_failed
dependency=postgresql
failure_type=dependency
```

The metric identifies the problem.

The logs provide evidence about its cause.

---

# 48. Logging and Runtime Relationship

The Runtime provides a structured context model:

```text
request
execution
operation
policy
reliability
failure
metadata
```

Logging consumes selected portions of this context.

The relationship is:

```text
Runtime Context
      │
      ├── request_id
      ├── execution_id
      ├── operation_id
      ├── dependency
      ├── failure_type
      ├── retry count
      └── recoverability
             │
             ▼
        Structured Log
```

This makes Runtime the semantic source for reliability execution context.

---

# 49. Logging and Failure Classification

Failure classification is generated by:

```text
api/src/runtime/reliability/failureClassifier.js
```

The current categories include:

```text
timeout
dependency
validation
authentication
authorization
internal
```

These classifications are propagated into Runtime failure logs.

This ensures that failure analysis does not depend exclusively on parsing arbitrary exception messages.

---

# 50. Logging and Retry Behavior

A retry sequence should be visible through explicit events.

Example:

```text
runtime_operation_started
        │
        ▼
runtime_operation_retry
        │
        ▼
runtime_operation_retry
        │
        ▼
runtime_operation_completed
```

This makes transient instability observable even when the final operation succeeds.

Without retry logging, the system could appear completely healthy while silently experiencing increasing dependency instability.

---

# 51. Logging and Recovery

Recovery is represented through the operation completion outcome:

```text
outcome: recovered
```

The corresponding log sequence can therefore show:

```text
Failure
   │
   ▼
Retry
   │
   ▼
Success
   │
   ▼
Recovered Outcome
```

This complements the Runtime recovery state.

---

# 52. Logging and Incident Response

During an incident, logs should normally be investigated after the scope and symptoms are identified through metrics.

A useful workflow is:

```text
1. Detect abnormal metric.
        │
        ▼
2. Identify affected service.
        │
        ▼
3. Identify time window.
        │
        ▼
4. Query logs.
        │
        ▼
5. Filter by service / level / event.
        │
        ▼
6. Correlate using request_id.
        │
        ▼
7. Correlate with execution_id.
        │
        ▼
8. Identify operation / dependency.
        │
        ▼
9. Classify failure.
        │
        ▼
10. Determine remediation.
```

---

# 53. Example Incident Investigation

Suppose the API error rate increases.

Metrics show:

```text
mw_api_http_errors_total ↑
```

The operator identifies:

```text
service = api
```

Then Loki is queried for:

```text
level = error
service = api
```

The logs reveal:

```text
runtime_operation_failed
dependency = postgresql
failure_type = dependency
```

The operator can then narrow the investigation to PostgreSQL rather than inspecting the entire application.

---

# 54. Request-Level Investigation

For an individual failed request:

```text
Client
  │
  ▼
X-Request-Id
  │
  ▼
request_id
  │
  ▼
Runtime logs
  │
  ▼
execution_id
  │
  ▼
operation_id
  │
  ▼
dependency / failure
```

This creates an operational path from external observation to internal cause.

---

# 55. What Should Be Logged

The logging architecture should prioritize:

```text
Lifecycle events
Business outcomes
Reliability events
Dependency failures
Retry events
Recovery events
Security-relevant operational events
Deployment events
```

Logs should contain enough context to answer:

```text
What happened?
When?
Where?
Which service?
Which operation?
Which dependency?
What was the outcome?
Was it recoverable?
Was a retry attempted?
```

---

# 56. What Should Not Be Logged

Sensitive or unnecessary information should not be logged.

In particular, avoid logging:

```text
passwords
JWT secrets
database credentials
API keys
access tokens
private keys
raw authentication secrets
```

Request bodies should not automatically be logged because they may contain sensitive information.

---

# 57. Username and User ID Considerations

The current API logs:

```text
username
user_id
```

in selected application events.

This can be useful during development and operational troubleshooting, but it introduces privacy and data-retention considerations.

A production-grade evolution should explicitly classify:

```text
user_id
username
```

as sensitive operational data and define:

```text
retention
access control
redaction
query policy
```

before exposing them broadly.

---

# 58. Error Message Safety

Raw `error.message` is currently logged in several locations.

This is useful diagnostically, but raw errors can potentially contain:

```text
connection information
filesystem paths
query fragments
credentials
internal topology
```

Therefore error messages should be treated as potentially sensitive.

The preferred future pattern is:

```text
Structured Safe Error Context
+
Controlled Diagnostic Details
```

rather than blindly exposing every underlying exception string.

---

# 59. Logging Cardinality

Loki labels must remain low-cardinality.

The current architecture promotes:

```text
service
level
```

as labels.

Fields such as:

```text
request_id
execution_id
operation_id
user_id
job_id
```

should generally remain inside the structured log payload.

This distinction is critical:

```text
Loki Label
    │
    └── Low-cardinality stream identity

Log Field
    │
    └── Event-specific searchable context
```

---

# 60. Why Request IDs Should Not Be Loki Labels

A request ID may be unique for every request.

If it became a Loki label:

```text
request_id=req_001
request_id=req_002
request_id=req_003
...
```

the number of streams would grow rapidly.

This would increase memory, indexing, and operational overhead.

The correct pattern is:

```text
{service="api", level="error"}
```

followed by filtering/searching the structured field:

```text
request_id
```

---

# 61. Logging Volume

Logging should be proportional to operational value.

Excessive logging can cause:

```text
storage growth
network traffic
query cost
noise
alert fatigue
```

Insufficient logging causes:

```text
poor incident reconstruction
```

The target is therefore:

```text
High information density
+
Controlled volume
```

---

# 62. INFO Logging Discipline

`INFO` should represent meaningful lifecycle or business events.

It should not be used for:

```text
every variable
every function call
every loop iteration
```

The current Runtime logging model follows event-oriented logging rather than arbitrary execution tracing.

---

# 63. WARN Logging Discipline

`WARN` should indicate a condition that is abnormal but does not necessarily represent terminal failure.

Examples:

```text
retry
invalid login
duplicate registration
```

Warnings should not become a replacement for metrics.

If a warning occurs thousands of times, the corresponding aggregate behavior should generally be represented through a metric as well.

---

# 64. ERROR Logging Discipline

`ERROR` should indicate a failure that requires operational attention or represents unsuccessful execution.

It should not be used for expected user input errors unless those errors have genuine operational significance.

For example:

```text
invalid password
```

may be an expected business event and is currently represented as a warning.

This distinction prevents normal application behavior from appearing as infrastructure failure.

---

# 65. Deployment Logging

Deployment operations generate logs under:

```text
/opt/deploy/logs/
```

Promtail collects these files using:

```text
job: deployment
service: deployment
environment: staging
```

Deployment logs should provide evidence about:

```text
deployment start
deployment version
deployment outcome
service state
deployment failures
rollback activity
```

where those events are implemented by the deployment system.

---

# 66. Deployment and Application Correlation

A useful incident investigation pattern is:

```text
Deployment Event
       │
       ▼
Version Change
       │
       ▼
Metric Degradation
       │
       ▼
Application Error Logs
       │
       ▼
Runtime Failure
```

The existing observability architecture contains the building blocks for this correlation.

The exact deployment-version propagation should remain consistent across deployment logs, application logs, and metrics.

---

# 67. Logging Storage Boundary

The logging architecture currently has:

```text
Application
    │
    ▼
Docker logs
    │
    ▼
Promtail
    │
    ▼
Loki
    │
    ▼
Filesystem
```

The application itself does not own long-term log storage.

This separation allows the application logging implementation to remain independent from the storage backend.

---

# 68. Logging Failure Modes

Logging itself has failure modes.

### Application Failure

The application may stop producing logs.

### Docker Logging Failure

Container logs may become unavailable.

### Promtail Failure

Logs may remain locally available but stop reaching Loki.

### Loki Failure

Promtail may be unable to push logs.

### Storage Failure

Loki may fail to persist logs.

### Query Failure

Logs may exist but be unavailable through Grafana.

Therefore:

```text
No visible log
```

does not necessarily mean:

```text
No event occurred
```

---

# 69. Observability Failure vs Application Failure

A critical distinction is:

```text
Application failure
```

versus:

```text
Observability failure
```

For example:

```text
API is healthy
Promtail is down
```

means:

```text
Application = healthy
Logging pipeline = degraded
```

Conversely:

```text
API is down
Prometheus still available
Loki still available
```

means:

```text
Application = failed
Observability = available
```

The monitoring architecture must preserve this distinction.

---

# 70. Log Retention Trade-Off

The current seven-day retention period balances:

```text
incident investigation
+
local storage limitations
```

Longer retention would provide more historical context but increase:

```text
storage requirements
backup requirements
query scope
operational cost
```

The retention policy should therefore evolve with the project's operational requirements.

---

# 71. Single-Node Logging Architecture

The current Loki architecture is designed for:

```text
single host
single Loki instance
filesystem storage
replication_factor = 1
```

It does not provide:

```text
Loki HA
distributed storage
cross-node replication
external object storage
```

This is consistent with the project's current infrastructure scope.

---

# 72. Logging and Security

Logs are part of the system's security boundary.

Anyone with access to Loki may potentially access:

```text
request context
user context
error details
operational topology
deployment information
```

Therefore production operation should enforce appropriate access control around:

```text
Grafana
Loki
Promtail
log storage
```

Logging should be considered a data-access surface rather than merely a debugging utility.

---

# 73. Logging and Compliance

If Mini-Write evolves to process real sensitive user information, the logging architecture must explicitly define:

```text
data classification
retention
redaction
access control
auditability
deletion requirements
```

The current implementation provides structured logging but does not constitute a complete compliance logging architecture.

---

# 74. Logging Query Strategy

Operators should prefer narrow queries.

A typical investigation starts with:

```text
service
+
time range
+
level
```

and then adds:

```text
event
+
operation_id
+
request_id
+
dependency
+
failure_type
```

This is more efficient than retrieving large volumes of raw logs.

---

# 75. Example Query Progression

Conceptually:

```text
1. service="api"
        │
        ▼
2. level="error"
        │
        ▼
3. event="runtime_operation_failed"
        │
        ▼
4. dependency="postgresql"
        │
        ▼
5. request_id="..."
```

This progressively reduces the search space.

---

# 76. Log Correlation Model

The current intended correlation chain is:

```text
Request
  │
  ├── request_id
  │
  └── execution_id
          │
          ▼
      operation_id
          │
          ▼
      dependency
          │
          ▼
      failure_type
          │
          ▼
      outcome
```

This model allows an individual execution to be reconstructed from multiple log events.

---

# 77. Logging and Traceability

Mini-Write does not currently implement a distributed tracing system such as OpenTelemetry tracing.

Therefore:

```text
request_id
execution_id
operation_id
```

provide the primary application-level correlation mechanism.

These identifiers should not be described as equivalent to distributed tracing spans.

If distributed tracing is introduced later, the current correlation fields can become part of a broader telemetry correlation model.

---

# 78. Relationship to Distributed Tracing

The observability layers can evolve toward:

```text
Metrics
   │
   ├── aggregate behavior
   │
Logs
   │
   ├── structured events
   │
Traces
   │
   └── distributed execution path
```

The current architecture intentionally implements Metrics and Logs without requiring a tracing backend.

---

# 79. Logging Validation

The logging pipeline should be validated end-to-end:

```text
Application Event
      │
      ▼
stdout
      │
      ▼
Docker JSON Log
      │
      ▼
Promtail
      │
      ▼
Field Extraction
      │
      ▼
Loki
      │
      ▼
Grafana
```

Validation should confirm that:

```text
✓ Event is emitted
✓ JSON is valid
✓ timestamp is parsed
✓ service is present
✓ level is present
✓ event is present
✓ request_id is preserved
✓ execution_id is preserved where applicable
✓ operation_id is preserved where applicable
✓ dependency is preserved where applicable
✓ error classification is preserved
✓ high-cardinality fields are not promoted to labels
✓ log is searchable in Loki
```

---

# 80. Runtime Logging Validation

A successful Runtime operation should produce evidence of:

```text
start
completion
runtime completion
```

A retrying operation should additionally produce:

```text
retry
```

A failed operation should produce:

```text
failure
failure handling
```

This should be validated through controlled failure scenarios.

---

# 81. Example: Successful Operation

Expected conceptual sequence:

```text
runtime_operation_started
        │
        ▼
runtime_operation_completed
        │
        ▼
runtime_completed
```

Important fields should remain consistent:

```text
request_id
execution_id
operation_id
```

---

# 82. Example: Recovered Operation

Expected conceptual sequence:

```text
runtime_operation_started
        │
        ▼
runtime_operation_retry
        │
        ▼
runtime_operation_completed
        │
        ▼
runtime_completed
```

The completion event should indicate:

```text
outcome = recovered
```

where applicable.

---

# 83. Example: Terminal Failure

Expected conceptual sequence:

```text
runtime_operation_started
        │
        ▼
runtime_operation_failed
        │
        ▼
runtime_failure_handled
```

The final event should preserve:

```text
failure_type
recoverable
retries
request_id
execution_id
operation_id
```

---

# 84. Logging Invariants

## Invariant 1 — Logs Are Structured

Operational logs must be machine-readable.

## Invariant 2 — Event Vocabulary Is Controlled

Events should use the centralized event taxonomy.

## Invariant 3 — Context Is Consistent

Correlation fields should use consistent names and semantics.

## Invariant 4 — Logs Must Not Contain Secrets

Passwords, tokens, credentials, and cryptographic secrets must never be logged.

## Invariant 5 — Loki Labels Must Be Low Cardinality

Unique execution identifiers belong in log fields, not labels.

## Invariant 6 — Runtime Reliability Events Must Be Observable

Retries, failures, and recoveries must produce sufficient evidence for diagnosis.

## Invariant 7 — Logs and Metrics Are Complementary

Logs should not replace aggregate metrics.

## Invariant 8 — Missing Logs Are Not Proof of No Event

The logging pipeline itself can fail.

## Invariant 9 — Retention Must Be Bounded

Local log storage must not grow indefinitely.

---

# 85. Current Logging Components

The primary logging components are:

```text
Application Logger
    │
    └── api/src/observability/logger.js

Event Taxonomy
    │
    └── api/src/observability/events.js

Log Context
    │
    └── api/src/observability/logContext.js

Runtime Logging
    │
    ├── runtimeBootstrap.js
    ├── infrastructureBoundary.js
    └── runtimeFailureHandler.js

Collection
    │
    └── observability/promtail/config.yml

Storage
    │
    └── observability/loki/config.yml

Visualization
    │
    └── Grafana / Loki datasource
```

The Worker contains the corresponding service-adapted observability implementation.

---

# 86. Logging Definition of Done

The Logging capability is considered operationally complete when:

```text
✓ API emits structured JSON logs.

✓ Worker emits structured JSON logs.

✓ Logs contain timestamp, level, service, and environment.

✓ Application events use a controlled event vocabulary.

✓ Runtime events are explicitly logged.

✓ Request correlation is available.

✓ Runtime execution correlation is available.

✓ Operation correlation is available.

✓ Dependency context is available for infrastructure operations.

✓ Failure classification is available.

✓ Retry behavior is observable.

✓ Recovery behavior is observable.

✓ Application logs are collected from Docker.

✓ Promtail parses Docker logs.

✓ Promtail parses application JSON.

✓ Loki receives application logs.

✓ Deployment logs are collected.

✓ Loki retention is bounded.

✓ High-cardinality fields are not promoted to Loki labels.

✓ Grafana can query Loki.

✓ Logging can support incident reconstruction.

✓ Logging does not intentionally expose secrets.

✓ Logging behavior has been validated end-to-end.
```

---

# 87. Current Architectural Limitation

The current implementation contains a terminology mismatch between the fields expected by the Promtail pipeline:

```text
correlation_id
job_id
deployment_version
```

and the primary Runtime correlation model:

```text
request_id
execution_id
operation_id
```

This should be treated as an architectural evolution item rather than silently ignored.

The future canonical model should explicitly define:

```text
Request Correlation
Runtime Execution Correlation
Background Job Correlation
Deployment Correlation
```

and map each concept consistently across:

```text
Application
Runtime
Worker
Promtail
Loki
Grafana
Metrics
Deployment
```

---

# 88. Final Logging Model

The Mini-Write Logging architecture can be summarized as:

```text
                     APPLICATION / RUNTIME
                              │
                              ▼
                    Structured Log Event
                              │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼
          Event + Context             Error + Outcome
                │                           │
                └─────────────┬─────────────┘
                              ▼
                           stdout
                              │
                              ▼
                     Docker JSON Logs
                              │
                              ▼
                          Promtail
                              │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼
          Field Extraction           Label Filtering
                │                           │
                └─────────────┬─────────────┘
                              ▼
                             Loki
                              │
                              ▼
                           Grafana
                              │
                ┌─────────────┴─────────────┐
                ▼                           ▼
         Incident Analysis          Operational Search
```

The core principle is:

```text
Logs should preserve enough structured context
to reconstruct what happened,
without turning the logging system itself
into an uncontrolled source of cardinality,
storage growth, or sensitive-data exposure.
```

Logging therefore forms the **event-level evidence layer** of Mini-Write's observability architecture, complementing Metrics as the aggregate quantitative layer and Runtime context as the execution-level semantic layer.

```
```
