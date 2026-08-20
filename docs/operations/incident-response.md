# Incident Response

## 1. Purpose

This document defines the operational incident-response process for the Mini-Write platform.

It establishes a consistent method for:

- detecting incidents;
- validating whether an alert represents a real failure;
- determining incident scope;
- identifying the affected component or failure domain;
- containing the failure;
- restoring service;
- validating recovery;
- documenting the incident;
- extracting engineering knowledge for future improvement.

The objective is not merely to restore a failed process.

The objective is to restore the platform to a known and acceptable operational state while preserving enough evidence to understand what happened.

---

# 2. Incident Definition

An incident is an operational condition that causes, or has a credible risk of causing, a degradation of the platform's intended behavior.

Examples include:

- API unavailability;
- API readiness failure;
- sustained API error rate;
- excessive API latency;
- Worker unavailability;
- sustained queue backlog;
- elevated Worker job failure rate;
- excessive Worker processing latency;
- PostgreSQL degradation;
- Redis degradation;
- MinIO degradation;
- host resource exhaustion;
- filesystem capacity exhaustion;
- observability failure;
- deployment-induced service degradation.

An incident does not necessarily require complete system outage.

A system can be operational while still experiencing a partial incident.

---

# 3. Incident vs Alert

An alert is a signal.

An incident is an operational condition requiring investigation or action.

Therefore:

```text
Alert
  │
  ▼
Validation
  │
  ├── False / transient
  │
  └── Real condition
          │
          ▼
       Incident
````

For example:

```text
MWHighCPUUsage
```

does not automatically mean:

```text
Application outage
```

It means:

> The host has sustained CPU utilization above the configured threshold.

The operator must determine the actual impact.

---

# 4. Incident Management Principles

Mini-Write follows these principles.

## 4.1 Stabilize Before Optimizing

During an active incident, the first objective is to stabilize the system.

Do not begin large architectural changes while the platform is unstable.

---

## 4.2 Evidence Before Assumptions

Do not conclude:

```text
"PostgreSQL is broken."
```

because:

```text
API requests are failing.
```

Instead collect evidence:

```text
API metrics
+
Runtime logs
+
PostgreSQL metrics
+
Container state
+
Host metrics
```

Then establish the failure relationship.

---

## 4.3 Scope Before Remediation

Before changing anything, determine:

```text
What is affected?
What is not affected?
```

A Worker-only incident should not automatically trigger an API restart.

---

## 4.4 Prefer Reversible Actions

During an incident, prefer actions that can be undone.

Examples:

```text
Restart affected container
Rollback deployment
Restore previous configuration
Temporarily isolate a failing dependency
```

Avoid irreversible changes unless necessary.

---

## 4.5 Preserve Evidence

Incident remediation must not unnecessarily destroy evidence.

Before restarting or deleting containers, collect relevant:

```text
logs
metrics
container state
exit codes
configuration state
deployment state
timestamps
```

---

## 4.6 Validate Recovery

An action is not considered successful because the command completed.

Recovery must be verified through observable system behavior.

```text
Remediation
    │
    ▼
Health verification
    │
    ▼
Behavior verification
    │
    ▼
Recovery confirmed
```

---

# 5. Incident Lifecycle

The standard incident lifecycle is:

```text
Detection
   │
   ▼
Validation
   │
   ▼
Classification
   │
   ▼
Scoping
   │
   ▼
Diagnosis
   │
   ▼
Containment
   │
   ▼
Recovery
   │
   ▼
Verification
   │
   ▼
Closure
   │
   ▼
Post-Incident Learning
```

These stages should not be skipped merely because the incident appears simple.

---

# 6. Incident Detection

Incidents can be detected through several channels.

## 6.1 Prometheus Alerts

Prometheus evaluates the configured alert rules.

Current application and infrastructure alerts include:

```text
MWAPIDown
MWHighAPIErrorRate
MWHighAPILatency

MWWorkerDown
MWQueueBacklogHigh
MWHighJobFailureRate
MWHighJobLatency
MWHighStorageLatency
MWHighDatabaseLatency

MWNodeExporterDown
MWHighCPUUsage
MWHighMemoryUsage
MWLowDiskSpace
```

---

## 6.2 Health Checks

Health endpoints provide direct application evidence.

API:

```text
GET /health/live
GET /health/ready
```

A readiness failure is particularly important because it indicates that the API process may still be alive while its required operational conditions are not satisfied.

---

## 6.3 Logs

Logs provide event-level evidence.

Relevant Runtime events include:

```text
runtime_operation_started
runtime_operation_completed
runtime_operation_retry
runtime_operation_failed
runtime_failure_handled
runtime_completed
```

Application events include:

```text
user_registered
user_registration_failed
user_login_success
user_login_failed
id_upload_started
id_upload_success
id_upload_failed
job_enqueued
```

---

## 6.4 Metrics

Metrics provide aggregate behavioral evidence.

Examples:

```text
HTTP request rate
HTTP error rate
HTTP latency
Worker queue depth
Worker job failure rate
Worker job latency
Storage latency
Database latency
Runtime operation failures
Runtime retries
```

---

# 7. Initial Incident Validation

When an alert is received, first determine whether the condition is real.

A basic validation sequence is:

```text
Alert
 │
 ▼
Check alert state
 │
 ▼
Check Prometheus target
 │
 ▼
Check service/container
 │
 ▼
Check health endpoint if available
 │
 ▼
Check recent logs
 │
 ▼
Confirm impact
```

Do not immediately restart the service.

---

# 8. Incident Classification

Each incident should be classified by:

```text
Component
Failure domain
Severity
Impact
Duration
Detection source
Likely cause
Current state
```

A useful classification structure is:

```text
Host
Infrastructure
API
Worker
PostgreSQL
Redis
MinIO
Observability
Deployment
Configuration
Network
```

---

# 9. Incident Scope

Determine whether the incident is:

### Local

One operation or endpoint is affected.

Example:

```text
ID upload failing
```

while:

```text
login = healthy
profile = healthy
health = healthy
```

---

### Component-level

An entire service is affected.

Example:

```text
API unavailable
```

---

### Dependency-level

Multiple services are affected because they share a dependency.

Example:

```text
PostgreSQL unavailable
       │
       ├── API database operations fail
       └── Worker database operations fail
```

---

### Platform-level

The underlying host or infrastructure affects multiple services.

Example:

```text
Host disk exhaustion
       │
       ├── PostgreSQL
       ├── MinIO
       ├── Loki
       ├── Docker
       └── application services
```

---

# 10. Incident Severity

Severity should reflect operational impact rather than merely the alert name.

## Critical

Use when the platform or a major responsibility is unavailable.

Examples:

```text
API completely unavailable
Host unavailable
Critical infrastructure failure
System-wide data-path failure
```

---

## Warning

Use when the system remains available but is materially degraded.

Examples:

```text
High API latency
High API error rate
Queue backlog
High Worker failure rate
High CPU
High memory
High dependency latency
```

---

## Informational

Use for conditions that require awareness but do not currently represent material service degradation.

---

# 11. Incident Record

Every meaningful incident should have a record containing at least:

```text
Incident ID
Date / Time
Detected at
Affected component
Severity
Detection source
Observed symptoms
Impact
Initial hypothesis
Evidence
Actions taken
Recovery time
Root cause
Corrective actions
```

The incident record should distinguish facts from hypotheses.

For example:

```text
Fact:
API returned HTTP 503.

Hypothesis:
PostgreSQL may be unavailable.

Evidence:
PostgreSQL connection attempts are failing with ECONNREFUSED.
```

---

# 12. Initial Triage

The first triage should answer five questions:

```text
1. What is failing?
2. When did it start?
3. Who or what is affected?
4. Is the failure getting worse?
5. What changed immediately before the failure?
```

These questions establish the initial failure boundary.

---

# 13. Establish the Timeline

Determine:

```text
T0 = first observable symptom
T1 = alert triggered
T2 = investigation started
T3 = remediation started
T4 = service recovered
T5 = recovery verified
```

The timeline is important for correlating the incident with:

```text
deployment
configuration change
infrastructure change
traffic change
dependency failure
resource exhaustion
```

---

# 14. Recent Change Analysis

Always inspect recent changes early in the investigation.

Potential changes include:

```text
Application deployment
Worker deployment
Docker image update
Configuration change
Environment variable change
Ansible execution
Infrastructure change
Prometheus configuration
Alert rule modification
Host change
```

The key question is:

> What changed between the last known healthy state and the first known unhealthy state?

---

# 15. API Incident Response

When the API is suspected, follow:

```text
API alert
   │
   ▼
Prometheus target
   │
   ▼
Container state
   │
   ▼
/health/live
   │
   ▼
/health/ready
   │
   ▼
API logs
   │
   ▼
Runtime failure logs
   │
   ▼
Dependency health
```

---

# 16. API Down

If:

```text
MWAPIDown
```

is firing, verify:

```text
up{job="api"}
```

Then inspect:

```text
docker container state
restart count
exit code
container logs
```

If the container is running, verify:

```text
/health/live
/health/ready
```

If the container is stopped or restarting, determine why before restarting it repeatedly.

---

# 17. API High Error Rate

For:

```text
MWHighAPIErrorRate
```

investigate:

```text
HTTP status distribution
Runtime failure logs
Application logs
Database connectivity
Redis connectivity
MinIO behavior
Recent deployment
```

The important distinction is:

```text
High errors
```

versus:

```text
High errors caused by one dependency
```

versus:

```text
High errors caused by application logic
```

---

# 18. API High Latency

For:

```text
MWHighAPILatency
```

inspect:

```text
P95 latency
request rate
error rate
CPU
memory
PostgreSQL latency
Redis behavior
MinIO latency
recent deployments
```

Do not assume the API itself is computationally slow.

Latency is often a downstream symptom.

---

# 19. API Readiness Failure

If:

```text
/health/live = 200
```

but:

```text
/health/ready = 503
```

the initial conclusion should be:

```text
API process is alive.
Readiness conditions are not satisfied.
```

Investigate the dependencies used by the readiness check.

Avoid unnecessary API restarts unless evidence indicates that the API process itself is unhealthy.

---

# 20. Worker Incident Response

Worker incidents require a different diagnostic model because the Worker performs asynchronous processing.

Start with:

```text
Worker availability
   │
   ▼
Queue depth
   │
   ▼
Active jobs
   │
   ▼
Processed jobs
   │
   ▼
Failure rate
   │
   ▼
Retry behavior
   │
   ▼
Job latency
   │
   ▼
Dependency latency
```

---

# 21. Worker Down

For:

```text
MWWorkerDown
```

verify:

```text
up{job="worker"}
```

then inspect:

```text
Worker container
restart state
exit code
logs
Redis connectivity
recent deployment
```

The primary question is:

> Is the Worker process unavailable, or is only its metrics endpoint unavailable?

---

# 22. Worker Queue Backlog

For:

```text
MWQueueBacklogHigh
```

inspect:

```text
queue depth
jobs active
jobs processed
job duration
job failures
retries
Redis
CPU
memory
MinIO
PostgreSQL
```

A queue backlog can be caused by:

```text
Worker capacity reduction
Slow dependencies
Job failures
Retry amplification
Redis problems
Host resource pressure
Sudden workload increase
```

---

# 23. Worker Job Failure Rate

For:

```text
MWHighJobFailureRate
```

inspect:

```text
job failure logs
failure classification
dependency failures
image-processing errors
storage errors
database errors
retry behavior
```

The goal is to determine whether failures are:

```text
transient
```

or:

```text
systematic
```

---

# 24. Worker High Latency

For:

```text
MWHighJobLatency
```

correlate:

```text
Job duration
CPU
Memory
Storage latency
Database latency
Queue depth
```

If:

```text
job latency ↑
storage latency ↑
```

then storage becomes a stronger hypothesis.

If:

```text
job latency ↑
CPU ↑
storage latency normal
database latency normal
```

then compute pressure becomes more likely.

---

# 25. PostgreSQL Incident Response

When PostgreSQL is suspected, inspect:

```text
postgres-exporter
database container
database logs
connection failures
database latency
host CPU
host memory
disk capacity
```

Also determine whether the problem affects:

```text
API only
Worker only
Both
```

This helps establish the failure boundary.

---

# 26. Redis Incident Response

Redis is particularly important because it supports asynchronous processing.

When Redis is suspected:

```text
Redis exporter
Redis container
Redis logs
Worker connectivity
Queue depth
Job processing
API queue operations
```

A Redis failure can manifest as:

```text
Worker degradation
Queue backlog
Job enqueue failures
```

rather than as a direct Redis outage visible to users.

---

# 27. MinIO Incident Response

For storage-related incidents inspect:

```text
MinIO container
storage logs
Worker storage latency
API upload failures
host disk
filesystem
network
```

Correlate:

```text
ID upload failures
+
storage latency
+
Worker processing latency
```

to establish whether MinIO is actually the failure source.

---

# 28. Host Resource Incident Response

For:

```text
MWHighCPUUsage
MWHighMemoryUsage
MWLowDiskSpace
```

inspect:

```text
Host metrics
Docker containers
Container resource usage
Recent deployments
Large logs
Docker storage
PostgreSQL storage
MinIO storage
Loki storage
```

The host is a shared failure domain.

Therefore host incidents should be treated as potentially broader than application incidents.

---

# 29. Low Disk Space Response

For:

```text
MWLowDiskSpace
```

the first objective is to prevent further resource exhaustion.

Inspect:

```text
filesystem usage
Docker images
Docker volumes
container logs
Loki storage
Prometheus storage
PostgreSQL data
MinIO data
deployment artifacts
```

Do not delete persistent application data simply to recover disk space.

Determine ownership and retention requirements before cleanup.

---

# 30. Observability Incident

An observability incident occurs when the application may remain operational but the ability to monitor or diagnose it is degraded.

Examples:

```text
Prometheus unavailable
Loki unavailable
Promtail stopped
Grafana unavailable
Alertmanager unavailable
Exporter unavailable
```

The priority is to restore visibility without confusing:

```text
monitoring failure
```

with:

```text
application failure
```

---

# 31. Prometheus Failure

If Prometheus is unavailable:

```text
Real-time alert evaluation
        ↓
        degraded
```

and:

```text
Historical metrics visibility
        ↓
        degraded
```

The operator should use alternative evidence:

```text
service health endpoints
container state
logs
Docker inspection
direct service checks
```

until Prometheus is restored.

---

# 32. Loki / Promtail Failure

If log collection is unavailable:

```text
Application may still be healthy
```

but:

```text
Incident diagnosis becomes weaker
```

Verify:

```text
Promtail container
Loki container
Docker log paths
Loki connectivity
disk capacity
```

Preserve local container logs until centralized collection is restored.

---

# 33. Alertmanager Failure

If Alertmanager is unavailable:

```text
Prometheus
    │
    ▼
Alert evaluation may continue
    │
    ▼
Notification delivery is degraded
```

Therefore Alertmanager failure should not automatically be interpreted as application failure.

---

# 34. Deployment-Related Incident

If an incident begins immediately after deployment, classify deployment as a leading hypothesis.

Compare:

```text
Previous version
        │
        ▼
Deployment
        │
        ▼
Current version
```

Verify:

```text
container image
configuration
health checks
API behavior
Worker behavior
dependencies
metrics
logs
```

If the previous version was known healthy and the current version introduced the failure, rollback becomes a strong containment option.

---

# 35. Rollback Decision

Rollback should be considered when:

```text
The failure correlates strongly with a recent deployment
AND
The previous version is known or strongly believed to be healthy
AND
Rollback is lower risk than continued investigation on the current version
```

Rollback is not proof of root cause.

It is a containment and recovery action.

---

# 36. Configuration-Related Incident

Configuration failures may include:

```text
Missing environment variable
Invalid value
Wrong dependency address
Incorrect port
Invalid credentials
Incorrect timeout
Incorrect runtime policy
```

Investigate:

```text
effective configuration
deployment configuration
environment variables
container environment
recent configuration changes
```

Do not expose secrets while collecting evidence.

---

# 37. Runtime Failure Investigation

API Runtime failures should be investigated through:

```text
request_id
execution_id
operation_id
dependency
failure_type
retries
attempts
```

For example:

```text
request_id:
req_...

execution_id:
exec_...

operation_id:
id_upload

dependency:
minio

failure_type:
dependency

retries:
2
```

This creates a traceable operational path through the request.

---

# 38. Runtime Failure Interpretation

Runtime failure classification includes:

```text
TIMEOUT
DEPENDENCY
VALIDATION
AUTHENTICATION
AUTHORIZATION
INTERNAL
```

A dependency failure with a transient error code may be retryable.

For example:

```text
ECONNRESET
ECONNREFUSED
EHOSTUNREACH
ENETUNREACH
ETIMEDOUT
RUNTIME_TIMEOUT
```

However, retry behavior must be interpreted together with the operation's reliability policy.

---

# 39. Retry Amplification

Retries are a recovery mechanism, but excessive retries can worsen an incident.

Example:

```text
Dependency degraded
      │
      ▼
Requests fail
      │
      ▼
Retries increase traffic
      │
      ▼
Dependency becomes more overloaded
      │
      ▼
More failures
```

Therefore inspect:

```text
retry count
failure rate
dependency health
queue growth
request volume
```

when diagnosing reliability incidents.

---

# 40. Containment

Containment aims to prevent the incident from expanding.

Possible containment actions include:

```text
Stop a restart loop
Rollback a deployment
Restart a clearly unhealthy component
Temporarily isolate a failing dependency
Reduce workload where possible
Stop a destructive operational action
Preserve affected data
Protect remaining healthy services
```

Containment must be proportional to the failure scope.

---

# 41. Recovery

Recovery restores normal operation.

Typical sequence:

```text
Contain
  │
  ▼
Apply remediation
  │
  ▼
Service starts
  │
  ▼
Health checks
  │
  ▼
Dependency checks
  │
  ▼
Behavior verification
  │
  ▼
Recovery confirmed
```

---

# 42. Recovery Verification

A recovery is not confirmed by:

```text
container running
```

alone.

For API recovery verify:

```text
/health/live = 200
/health/ready = 200
Prometheus target = UP
Error rate normal
Latency normal
```

For Worker recovery verify:

```text
Worker target = UP
Queue depth stabilizing
Jobs processing
Failure rate normalizing
Latency normalizing
```

For host recovery verify:

```text
CPU acceptable
Memory acceptable
Disk sufficient
Required containers stable
```

---

# 43. Recovery Stability Window

Immediately after recovery, continue observing the affected component.

A service that appears healthy for a few seconds may still be unstable.

Look for:

```text
restart loops
repeated errors
queue growth
latency regression
resource exhaustion
repeated dependency failures
```

Recovery should therefore be treated as:

```text
service restored
+
stable behavior observed
```

---

# 44. Incident Closure Criteria

An incident may be closed when:

```text
[ ] Immediate impact is resolved
[ ] Affected services are healthy
[ ] Dependencies are healthy
[ ] Error rates have returned to acceptable levels
[ ] Latency has stabilized
[ ] Worker queue is stable
[ ] No restart loop exists
[ ] Monitoring is functioning
[ ] Relevant evidence has been preserved
[ ] Root cause is known or explicitly documented as unknown
[ ] Follow-up actions have been recorded
```

---

# 45. Root Cause

Root cause analysis should answer:

> What condition ultimately caused the observed failure?

Do not confuse:

```text
symptom
```

with:

```text
root cause
```

Example:

```text
Symptom:
API returned 500.

Intermediate cause:
PostgreSQL operation failed.

Root cause:
Host filesystem exhaustion caused PostgreSQL write failures.
```

The root cause should be expressed at the deepest level supported by evidence.

---

# 46. Contributing Factors

An incident can have multiple contributing factors.

Example:

```text
Root cause:
Host disk exhaustion.

Contributing factors:
- insufficient retention
- large container logs
- insufficient disk alert margin
- no automated cleanup
```

This distinction is important because fixing only the immediate root cause may not prevent recurrence.

---

# 47. Five-Whys Example

### Problem

Worker jobs are failing.

### Why?

Because storage operations are timing out.

### Why?

Because MinIO operations are slow.

### Why?

Because host disk performance is degraded.

### Why?

Because the host filesystem is nearly full.

### Why?

Because storage retention and cleanup are insufficient.

The incident therefore exposes a broader operational improvement opportunity.

---

# 48. Post-Incident Review

A meaningful incident review should contain:

```text
Summary
Impact
Timeline
Detection
Technical diagnosis
Root cause
Contributing factors
Containment
Recovery
What worked
What failed
What was missing
Corrective actions
Preventive actions
```

The purpose is improvement, not blame.

---

# 49. Corrective vs Preventive Actions

## Corrective

Fix the specific failure.

Example:

```text
Restart failed Worker
```

## Preventive

Reduce the probability of recurrence.

Example:

```text
Improve Worker dependency timeout policy
```

## Detection Improvement

Reduce detection time.

Example:

```text
Add a more specific alert for sustained queue growth.
```

## Diagnostic Improvement

Reduce investigation time.

Example:

```text
Improve runtime log correlation.
```

---

# 50. Incident Metrics

Useful operational metrics include:

```text
MTTD
Mean Time To Detect

MTTA
Mean Time To Acknowledge

MTTR
Mean Time To Recover

Incident frequency

Repeat incident frequency

False alert frequency
```

These measurements help evaluate the effectiveness of the operational architecture.

---

# 51. MTTD

Mean Time To Detect measures:

```text
First failure
     │
     ▼
Detection
```

A high MTTD may indicate:

```text
insufficient observability
missing alerts
incorrect thresholds
missing health checks
```

---

# 52. MTTR

Mean Time To Recover measures:

```text
Detection
    │
    ▼
Recovery
```

A high MTTR may indicate:

```text
weak diagnostics
unclear runbooks
poor failure isolation
difficult rollback
insufficient automation
```

---

# 53. Incident Evidence Model

The preferred evidence chain is:

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
Runtime Context
 │
 ▼
Dependency Evidence
 │
 ▼
Failure Classification
 │
 ▼
Root Cause
```

Not every incident will contain every layer, but investigations should move toward stronger evidence rather than speculation.

---

# 54. Correlation During Investigation

Use common identifiers where available:

```text
request_id
execution_id
operation_id
dependency
job_id
```

Be aware that high-cardinality identifiers such as correlation IDs and job IDs are intentionally not promoted as persistent Loki labels by the current Promtail configuration.

They should therefore be treated as log fields rather than indexed labels.

---

# 55. Incident Communication

Incident communication should be concise and factual.

A useful status format is:

```text
Status:
Investigating / Contained / Recovering / Resolved

Impact:
<what is affected>

Observed:
<verified symptoms>

Current hypothesis:
<explicitly marked as hypothesis>

Action:
<what is being done>

Next verification:
<what will be checked>
```

Avoid presenting an unverified hypothesis as fact.

---

# 56. Example Incident Update

```text
Status: Investigating

Impact:
Background ID processing is delayed.

Observed:
Worker is reachable, but queue depth has remained above threshold.
Job latency is elevated.

Evidence:
MWQueueBacklogHigh is firing.
MWHighJobLatency is firing.
Worker target remains UP.

Current hypothesis:
Processing latency may be related to storage operations.

Action:
Inspect MinIO health and Worker storage latency.

Next verification:
Compare storage latency with job-duration behavior.
```

---

# 57. Incident Anti-Patterns

Avoid:

### Restarting everything

```text
"Something is wrong → restart all containers."
```

This destroys useful evidence and can expand the blast radius.

---

### Treating `UP` as healthy

```text
Prometheus target UP
```

does not mean:

```text
Application fully healthy
```

---

### Treating alerts as root causes

```text
MWHighAPILatency
```

is a symptom, not necessarily the cause.

---

### Changing multiple variables simultaneously

If several changes are made at once, determining which change solved the incident becomes difficult.

---

### Ignoring recent deployments

Deployment correlation should always be considered.

---

### Ignoring dependencies

Application failures often originate below the application layer.

---

### Closing immediately after restart

A restart can temporarily hide the underlying problem.

---

# 58. Incident Response Decision Tree

```text
                    Incident Detected
                           │
                           ▼
                   Is the signal real?
                    │              │
                   NO             YES
                    │              │
                    ▼              ▼
                 Close          Determine scope
                                    │
                     ┌──────────────┼──────────────┐
                     ▼              ▼              ▼
                   Host          Service       Dependency
                     │              │              │
                     └──────────────┼──────────────┘
                                    ▼
                              Collect evidence
                                    │
                                    ▼
                             Establish cause
                                    │
                                    ▼
                               Contain
                                    │
                                    ▼
                               Remediate
                                    │
                                    ▼
                               Verify health
                                    │
                                    ▼
                              Verify behavior
                                    │
                           ┌────────┴────────┐
                           │                 │
                       Stable            Unstable
                           │                 │
                           ▼                 ▼
                        Close          Continue response
                           │
                           ▼
                    Post-Incident Review
```

---

# 59. Standard Incident Checklist

## Detection

```text
[ ] Alert identified
[ ] Alert time recorded
[ ] Affected component identified
```

## Validation

```text
[ ] Prometheus signal checked
[ ] Health endpoint checked
[ ] Container state checked
[ ] Logs checked
```

## Diagnosis

```text
[ ] Failure scope established
[ ] Recent changes checked
[ ] Dependencies checked
[ ] Host resources checked
[ ] Runtime evidence checked
```

## Containment

```text
[ ] Blast radius limited
[ ] Evidence preserved
[ ] Reversible action selected
```

## Recovery

```text
[ ] Remediation completed
[ ] API health verified if affected
[ ] Worker health verified if affected
[ ] Dependencies verified
[ ] Metrics normalized
[ ] Logs checked
```

## Closure

```text
[ ] Recovery stable
[ ] Impact recorded
[ ] Root cause documented
[ ] Contributing factors documented
[ ] Corrective actions documented
[ ] Preventive actions documented
```

---

# 60. Incident Response and Reliability Architecture

Incident response is the operational realization of the platform's Reliability Engineering model.

The relationship is:

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
Handling
  │
  ▼
Recovery
  │
  ▼
Evidence
  │
  ▼
Learning
```

The Runtime architecture provides failure context at the application-operation level.

The Observability architecture provides system-level evidence.

The Operations layer connects these signals into an actionable response process.

---

# 61. Incident Response and Continuous Improvement

Every meaningful incident is a source of engineering knowledge.

The final stage is therefore:

```text
Incident
   │
   ▼
Analysis
   │
   ▼
Knowledge
   │
   ▼
Engineering Improvement
```

Possible improvements include:

```text
New health check
New metric
New alert
Better alert threshold
Better runtime classification
Improved retry policy
Improved timeout
Improved logging
Improved dashboard
Improved deployment validation
Improved rollback procedure
Infrastructure improvement
Documentation improvement
```

An incident that is merely closed can recur.

An incident that produces engineering learning can improve the platform.

---

# 62. Definition of Done

An incident-response process is considered effective when an operator can:

```text
✓ Detect the incident
✓ Validate the signal
✓ Establish the failure boundary
✓ Determine affected services
✓ Correlate metrics and logs
✓ Identify recent changes
✓ Investigate dependencies
✓ Contain the failure
✓ Apply a reversible remediation where possible
✓ Restore service
✓ Verify recovery
✓ Confirm stability
✓ Document the incident
✓ Identify root cause
✓ Record contributing factors
✓ Create corrective actions
✓ Create preventive actions
```

---

# 63. Final Operational Model

The Mini-Write incident-response model is:

```text
                    ┌─────────────────────┐
                    │       DETECT        │
                    │ Alerts / Health /   │
                    │ Metrics / Logs      │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      VALIDATE       │
                    │ Is the condition    │
                    │ actually occurring? │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │       SCOPE         │
                    │ Host / Service /    │
                    │ Dependency / System │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      DIAGNOSE       │
                    │ Metrics + Logs +    │
                    │ Runtime + Changes   │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      CONTAIN        │
                    │ Limit blast radius  │
                    │ Preserve evidence   │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │       RECOVER       │
                    │ Remediate / Rollback│
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      VERIFY         │
                    │ Health + Behavior + │
                    │ Stability           │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │       CLOSE         │
                    │ Impact + Root Cause │
                    │ + Evidence          │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      IMPROVE        │
                    │ Corrective +        │
                    │ Preventive Actions  │
                    └─────────────────────┘
```

The central operational principle is:

> **An incident is not resolved when a process starts running again. It is resolved when the affected responsibility has been restored, the recovery has been verified through independent operational evidence, the system has remained stable, and the failure has been converted into actionable engineering knowledge.**

```
```
