# Operations

## 1. Purpose

This document defines the operational model of the Mini-Write platform.

It describes how the system is operated after infrastructure provisioning and application deployment, including:

- runtime ownership;
- service lifecycle;
- health verification;
- operational checks;
- observability;
- deployment verification;
- failure handling;
- incident investigation;
- operational state;
- recovery and rollback boundaries.

The purpose of this document is not to duplicate implementation details from the application, infrastructure, reliability, or observability documentation.

Instead, it answers the operational question:

> **How should an engineer operate, inspect, validate, and troubleshoot Mini-Write as a running system?**

---

# 2. Operational Model

Mini-Write is operated as a containerized multi-service application running on a provisioned staging host.

The operational architecture is:

```text
                         ┌─────────────────────┐
                         │ GitHub Repository   │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │ CI/CD               │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │ Staging Host        │
                         │                     │
                         │ Docker              │
                         │ Deployment Runtime  │
                         └──────────┬──────────┘
                                    │
                                    ▼
              ┌────────────────────────────────────────┐
              │ Application Runtime                    │
              │                                        │
              │ Gateway                                │
              │ API                                    │
              │ Worker                                 │
              │ PostgreSQL                             │
              │ Redis                                  │
              │ MinIO                                  │
              └───────────────────┬────────────────────┘
                                  │
                                  ▼
              ┌────────────────────────────────────────┐
              │ Observability Platform                 │
              │                                        │
              │ Prometheus                             │
              │ Loki                                   │
              │ Grafana                                │
              │ Alertmanager                            │
              └────────────────────────────────────────┘
````

Operations therefore span several architectural layers rather than a single service.

---

# 3. Operational Responsibilities

Operational responsibility can be divided into several domains.

| Domain        | Primary responsibility                |
| ------------- | ------------------------------------- |
| Host          | Availability and resource capacity    |
| Docker        | Container lifecycle                   |
| Application   | API and Worker behavior               |
| Dependencies  | PostgreSQL, Redis, MinIO availability |
| Deployment    | Controlled application transitions    |
| Observability | Metrics, logs, dashboards, alerts     |
| Reliability   | Failure handling and recovery         |
| Security      | Firewall and SSH baseline             |
| CI/CD         | Validated deployment execution        |

An operational investigation should identify which domain owns the observed symptom before attempting remediation.

---

# 4. Operational Boundaries

The system can be viewed through five operational boundaries.

## 4.1 Host Boundary

The host provides:

```text
CPU
Memory
Disk
Network
Operating System
Docker Engine
```

A host-level failure can affect every service simultaneously.

---

## 4.2 Container Boundary

Docker provides lifecycle isolation for the application and infrastructure services.

The container boundary includes:

```text
Image
Container
Environment
Network
Volume
Resource limits
Health check
Restart policy
```

---

## 4.3 Application Boundary

The application consists primarily of:

```text
API
Worker
```

The API serves synchronous HTTP operations.

The Worker processes asynchronous background jobs.

---

## 4.4 Dependency Boundary

Application behavior depends on:

```text
PostgreSQL
Redis
MinIO
```

A dependency failure can therefore appear as an application failure even when the application process itself remains running.

---

## 4.5 Observability Boundary

The observability platform provides evidence about the other boundaries.

```text
Application / Infrastructure
          │
          ▼
      Metrics / Logs
          │
          ▼
 Prometheus / Loki
          │
          ├──► Grafana
          │
          └──► Alertmanager
```

Observability should therefore be considered an operational dependency for diagnosis, even when it is not directly required for normal application request processing.

---

# 5. Operational State Model

The platform should be understood as moving through several operational states.

```text
Provisioned
    │
    ▼
Configured
    │
    ▼
Deployed
    │
    ▼
Healthy
    │
    ├──────────────► Degraded
    │                    │
    │                    ▼
    │                 Recovery
    │                    │
    │                    ▼
    └──────────────── Healthy
```

A deployment may technically complete while the runtime is still transitioning toward a healthy state.

Therefore operational verification must occur after deployment.

---

# 6. Runtime Layout

The deployment runtime is rooted under:

```text
/opt/deploy
```

The runtime contains several operational areas.

Conceptually:

```text
/opt/deploy/
├── compose/
├── proxy/
├── scripts/
├── state/
├── logs/
├── env/
└── metrics/
```

These directories have different operational responsibilities.

| Path       | Operational purpose               |
| ---------- | --------------------------------- |
| `compose/` | Runtime Compose configuration     |
| `proxy/`   | Nginx configuration               |
| `scripts/` | Deployment and runtime scripts    |
| `state/`   | Deployment state                  |
| `logs/`    | Deployment logs                   |
| `env/`     | Staging environment configuration |
| `metrics/` | Host textfile metrics             |

The exact permissions and ownership are defined by the infrastructure provisioning layer.

---

# 7. Service Inventory

The staging Compose topology contains the following major services.

## Application

```text
gateway
api
worker
```

## Core dependencies

```text
postgres
redis
storage
```

where `storage` represents MinIO.

## Observability

```text
prometheus
loki
promtail
alertmanager
grafana
```

## Exporters

```text
node-exporter
cadvisor
redis-exporter
postgres-exporter
```

The complete runtime therefore combines:

```text
Application
+
Dependencies
+
Observability
+
Telemetry Exporters
```

---

# 8. Service Lifecycle

The primary service lifecycle is managed through Docker Compose.

The operational lifecycle is:

```text
Image
  │
  ▼
Container Creation
  │
  ▼
Container Start
  │
  ▼
Health Verification
  │
  ▼
Running
  │
  ├── Failure
  │
  ▼
Restart / Investigation
```

Container state alone should not be used as the sole indicator of service health.

---

# 9. Restart Policy

The application and observability services use restart policies intended to automatically restart containers after certain runtime failures.

This provides basic process-level resilience.

However:

> **Automatic restart is not equivalent to recovery.**

For example:

```text
Container crashes
      │
      ▼
Docker restarts container
      │
      ▼
Application starts
      │
      ▼
Dependency still unavailable
      │
      ▼
Service remains unhealthy
```

Therefore restart behavior must be evaluated together with health checks, metrics, and logs.

---

# 10. Resource Boundaries

The Compose configuration defines resource limits for many services.

Examples include:

```text
Memory limits
CPU limits
```

These limits provide operational isolation and prevent one service from consuming unlimited host resources.

Conceptually:

```text
Host Capacity
     │
     ├── API
     ├── Worker
     ├── PostgreSQL
     ├── Redis
     ├── MinIO
     └── Observability
```

Resource saturation should therefore be investigated at both:

```text
Host level
```

and:

```text
Container level
```

---

# 11. Network Operations

The runtime uses separate Docker networks:

```text
frontend-network
backend-network
```

The intended topology is:

```text
                 ┌───────────┐
External ───────►│  Gateway  │
                 └─────┬─────┘
                       │
                frontend-network
                       │
                 ┌─────▼─────┐
                 │    API    │
                 └─────┬─────┘
                       │
                backend-network
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Redis       PostgreSQL      MinIO
          │
          ▼
       Worker
```

The backend network contains internal application dependencies and processing services.

Operational network troubleshooting should therefore first determine:

```text
Which service?
Which network?
Which direction?
Which dependency?
```

rather than treating the entire Docker network as one undifferentiated failure domain.

---

# 12. External Exposure

The gateway is intended to act as the external HTTP entry point.

The application architecture therefore distinguishes between:

```text
External access
```

and:

```text
Internal service communication
```

Operationally, unexpected external exposure should be treated as a configuration or security issue.

The exposed ports are defined by the staging Compose configuration and the host firewall configuration.

---

# 13. Health Verification

Health verification operates at multiple levels.

## Level 1 — Container

Is the container running?

## Level 2 — Health Check

Does its configured health check pass?

## Level 3 — Application

Does the application respond correctly?

## Level 4 — Dependency

Are required dependencies available?

## Level 5 — Behavioral

Is the system actually processing expected workloads?

The operational hierarchy is:

```text
Container
   │
   ▼
Health
   │
   ▼
Application
   │
   ▼
Dependencies
   │
   ▼
Behavior
```

---

# 14. API Health

The API exposes two health endpoints.

```text
/health/live
/health/ready
```

### Liveness

The liveness endpoint answers whether the API process is alive.

It is intentionally lightweight.

### Readiness

The readiness endpoint performs actual system health verification.

It is therefore more appropriate for determining whether the API is ready to serve traffic.

Operationally:

```text
Liveness
    ≠
Readiness
```

A service can be alive while not being ready.

---

# 15. Worker Health

The Worker is an asynchronous processing service.

Operational health therefore cannot be evaluated solely through HTTP-style readiness.

Important operational signals include:

```text
Worker availability
Queue depth
Jobs processed
Job failures
Job retries
Active jobs
Job duration
```

A Worker can be running while still being operationally unhealthy.

For example:

```text
Worker Process
     │
     ▼
Running
     │
     ▼
Redis unavailable
     │
     ▼
No useful processing
```

This is why Worker observability is essential.

---

# 16. Dependency Health

The primary runtime dependencies are:

```text
PostgreSQL
Redis
MinIO
```

Each has its own health verification mechanism.

The application should not be considered fully healthy if a required dependency is unavailable.

The operational dependency graph is:

```text
API
 ├── PostgreSQL
 └── Redis

Worker
 ├── Redis
 ├── PostgreSQL
 └── MinIO
```

This graph is particularly useful during incident diagnosis.

---

# 17. PostgreSQL Operations

PostgreSQL is the primary relational state store.

Operational concerns include:

```text
Availability
Connection failures
Query latency
Disk usage
Container health
Persistent volume health
```

The PostgreSQL exporter provides database-related telemetry for Prometheus.

When investigating database-related application failures, check:

```text
1. PostgreSQL container
2. PostgreSQL health
3. Exporter availability
4. Host resources
5. Application logs
6. Database-related latency metrics
```

---

# 18. Redis Operations

Redis provides caching and queue-related functionality.

Operational concerns include:

```text
Availability
Connection failures
Queue depth
Persistence
Memory consumption
Processing backlog
```

Redis is particularly important to Worker operation.

A Redis failure can therefore produce symptoms in multiple components:

```text
Redis Failure
    │
    ├──► API queue operations
    │
    └──► Worker processing
```

The operational diagnosis should therefore treat Redis as a shared dependency.

---

# 19. MinIO Operations

MinIO provides object storage functionality.

It is required by the ID upload workflow and Worker processing path.

Operational concerns include:

```text
Availability
Storage latency
Disk capacity
Object access failures
Container health
Persistent volume health
```

A MinIO problem may appear as:

```text
Upload failure
       │
       ▼
API symptom
       │
       ▼
Storage dependency problem
```

The initial application symptom should therefore not automatically be interpreted as an API defect.

---

# 20. Observability Operations

The observability platform consists of:

```text
Prometheus
Loki
Promtail
Grafana
Alertmanager
```

and the associated exporters.

Its operational flow is:

```text
Services
   │
   ├── Metrics ─────► Prometheus
   │
   └── Logs ────────► Promtail ─────► Loki
                                      │
                 ┌────────────────────┘
                 ▼
              Grafana

Prometheus
    │
    ▼
Alert Rules
    │
    ▼
Alertmanager
```

If observability fails, the application may continue operating while the operator loses visibility.

Therefore observability failures should themselves be treated as operational events.

---

# 21. Metrics Operations

Prometheus collects metrics from:

```text
API
Worker
Redis exporter
PostgreSQL exporter
Node exporter
cAdvisor
Loki
Alertmanager
Prometheus
```

Metrics provide quantitative evidence about:

```text
Availability
Traffic
Latency
Errors
Queue behavior
Resource utilization
Dependency behavior
```

When diagnosing a problem, metrics should answer:

```text
When did it start?
How large is it?
Is it increasing?
Which component is affected?
Is the condition recovering?
```

---

# 22. Logging Operations

Application services emit structured JSON logs.

The logs contain operational fields such as:

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

Runtime reliability logging also includes fields related to:

```text
dependency
failure type
retry
attempt
recovery
```

Logs are collected through Promtail and stored in Loki.

---

# 23. Correlation

Operational investigation should correlate signals instead of examining them independently.

The preferred model is:

```text
Request
  │
  ├── Request ID
  ├── Operation ID
  ├── Logs
  ├── Metrics
  └── Failure information
```

This allows an operator to move from:

```text
Metric anomaly
```

to:

```text
Relevant logs
```

and then:

```text
Specific operation / dependency
```

The runtime architecture provides request and execution identities for this purpose.

---

# 24. Alerting Operations

Prometheus evaluates alert rules for several operational categories.

Examples include:

```text
Infrastructure health
API availability
API error rate
API latency
Worker availability
Queue backlog
Worker failure rate
Worker processing latency
Storage latency
Database latency
```

Alertmanager groups and routes alerts according to:

```text
environment
category
service
severity
```

The operational purpose of alerts is to identify conditions requiring attention rather than replace investigation.

---

# 25. Alert Severity

The current alert model distinguishes at least:

```text
critical
warning
info
```

A critical condition indicates a potentially significant service or infrastructure impact.

A warning indicates degradation that may require investigation before becoming a critical incident.

Alert severity should guide prioritization but should not replace engineering judgment.

---

# 26. Operational Dashboards

Grafana provides dashboards organized into operational areas including:

```text
System
Application
Queue
Deployment
Incidents
```

The dashboards provide a visual operational interface over Prometheus and Loki data.

The intended workflow is:

```text
Alert / Symptom
      │
      ▼
Dashboard
      │
      ▼
Metric Investigation
      │
      ▼
Log Investigation
      │
      ▼
Root Cause Analysis
```

Dashboards should be used for investigation, not treated as the authoritative state themselves.

The underlying metrics and logs remain the evidence sources.

---

# 27. Deployment Operations

Deployment is a controlled operational activity.

The high-level lifecycle is:

```text
Validate
   │
   ▼
Build
   │
   ▼
Deploy
   │
   ▼
Verify
   │
   ▼
Observe
```

A successful deployment requires more than successful command execution.

Operational verification should confirm:

```text
Application health
Dependency health
Worker behavior
Observability availability
Deployment state
```

Detailed CI/CD behavior is documented separately in:

```text
docs/deployment/ci-cd.md
```

---

# 28. Deployment State

Deployment state is stored under:

```text
/opt/deploy/state/deployment_state.json
```

The state tracks:

```text
current.api
current.worker

previous.api
previous.worker
```

This allows an operator to understand the relationship between the current and previous application versions.

During a deployment incident, this state should be inspected before performing a rollback.

---

# 29. Deployment Logs

Deployment logs are maintained under:

```text
/opt/deploy/logs/deploy.log
```

Deployment logs should be used to establish:

```text
What operation was attempted?
When was it attempted?
Which step failed?
Did the deployment reach the runtime update stage?
```

Deployment logs are distinct from application logs.

This distinction is important:

```text
Deployment log
    → deployment process

Application log
    → application runtime
```

---

# 30. Operational Change Model

Operational changes should follow a controlled sequence.

```text
Change Request
      │
      ▼
Understand Current State
      │
      ▼
Identify Affected Boundary
      │
      ▼
Make Change
      │
      ▼
Validate
      │
      ▼
Observe
      │
      ▼
Record Result
```

Avoid making several unrelated changes simultaneously during an incident.

Multiple simultaneous changes make causal analysis significantly harder.

---

# 31. Operational Readiness

Before considering the staging environment operationally ready, verify:

### Infrastructure

```text
[ ] Host available
[ ] Docker available
[ ] Required directories exist
[ ] Firewall configured
[ ] SSH configuration valid
```

### Application

```text
[ ] API running
[ ] API readiness passing
[ ] Worker running
[ ] Required dependencies healthy
```

### Observability

```text
[ ] Prometheus running
[ ] Targets being scraped
[ ] Loki running
[ ] Promtail running
[ ] Grafana running
[ ] Alertmanager running
```

### Deployment

```text
[ ] Deployment state available
[ ] Deployment logs available
[ ] Current artifact identity known
```

---

# 32. Daily Operational Check

A lightweight operational check should answer:

```text
Is the host healthy?
Are the application services healthy?
Are dependencies healthy?
Is observability functioning?
Are there active critical alerts?
Is there abnormal workload behavior?
```

The check can be represented as:

```text
Host
 │
 ├── CPU
 ├── Memory
 └── Disk
       │
       ▼
Containers
       │
       ▼
Application
       │
       ▼
Dependencies
       │
       ▼
Observability
       │
       ▼
Alerts
```

---

# 33. Incident Detection

An operational incident may be detected through several channels:

```text
User-visible failure
Alertmanager alert
Grafana dashboard anomaly
Prometheus metric anomaly
Application logs
Container failure
Deployment failure
Host resource exhaustion
```

The source of detection is not necessarily the source of failure.

For example:

```text
API error alert
     │
     ▼
Investigation
     │
     ▼
PostgreSQL latency
```

The API may therefore be the symptom rather than the root cause.

---

# 34. First Response

When an incident is detected:

```text
1. Confirm the symptom.
2. Determine the affected service.
3. Determine the affected scope.
4. Determine whether the issue is ongoing.
5. Check recent deployments or changes.
6. Check dependency health.
7. Check infrastructure resources.
8. Inspect metrics.
9. Inspect logs.
10. Apply the smallest appropriate remediation.
```

The first response should prioritize stabilization over speculative root-cause changes.

---

# 35. Scope Classification

Determine whether the failure affects:

```text
Single request
Single operation
Single service
Multiple services
Entire application
Entire host
Observability only
```

A useful hierarchy is:

```text
Request
  │
  ▼
Operation
  │
  ▼
Service
  │
  ▼
Dependency
  │
  ▼
Host
```

The smallest confirmed failure scope should guide the investigation.

---

# 36. Recent Change Correlation

Recent changes should be checked early.

Relevant changes include:

```text
Application deployment
Configuration change
Infrastructure change
Docker image change
CI/CD workflow change
Observability configuration change
Host change
```

The question is:

> **Did the system behavior change immediately after a known change?**

Temporal correlation is useful evidence, but it should not automatically be treated as proof of causality.

---

# 37. Resource Exhaustion

Host resource exhaustion can affect multiple services simultaneously.

Important signals include:

```text
CPU utilization
Memory utilization
Disk availability
Container resource consumption
```

The alerting configuration includes host-level rules for high CPU, high memory, and low disk space.

Resource incidents should be investigated at both:

```text
Host level
```

and:

```text
Container level
```

---

# 38. Disk Operations

Disk capacity is particularly important because multiple services depend on persistent storage.

Potential consumers include:

```text
Docker data
PostgreSQL
Redis
MinIO
Prometheus
Loki
Grafana
Alertmanager
Application logs
Deployment logs
```

Low disk space can therefore produce secondary failures across apparently unrelated services.

For this reason, disk pressure should be treated as a potentially system-wide failure domain.

---

# 39. Container Investigation

When a service appears unhealthy, inspect:

```text
Container state
Restart count
Health status
Recent logs
Resource usage
Image identity
Network attachment
Mounted volumes
Environment configuration
```

The objective is to establish:

```text
Expected State
      vs
Observed State
```

before changing anything.

---

# 40. Dependency Investigation

When an application service is failing:

```text
API / Worker
     │
     ▼
Required Dependencies
     │
     ├── PostgreSQL
     ├── Redis
     └── MinIO
```

Check dependencies before assuming an application-level defect.

This is particularly important for:

```text
database timeout
Redis connection errors
storage failures
queue processing failures
```

---

# 41. Operational Recovery

Recovery should follow the least invasive effective action.

A general hierarchy is:

```text
Observe
  │
  ▼
Confirm
  │
  ▼
Contain
  │
  ▼
Restart / Repair
  │
  ▼
Verify
  │
  ▼
Escalate / Rollback if necessary
```

Avoid destructive actions before establishing the failure mode.

---

# 42. Restart as a Recovery Action

Restarting a container can recover transient process failures.

However, restart should not be used as the default response to every failure.

For example:

```text
Container restart
      │
      ▼
Dependency still unavailable
      │
      ▼
Failure returns
```

Repeated restart without diagnosis can hide the actual problem.

A restart should therefore be followed by verification.

---

# 43. Rollback as an Operational Action

Rollback is appropriate when evidence indicates that a recent deployment introduced the failure and the previous version is known to be healthier.

The conceptual process is:

```text
Current Deployment
       │
       ▼
Failure Correlation
       │
       ▼
Previous Version Known
       │
       ▼
Rollback
       │
       ▼
Health Verification
       │
       ▼
Observe
```

Rollback should itself be treated as a deployment and therefore requires verification.

---

# 44. Recovery vs Rollback

The distinction is:

| Action                   | Purpose                                         |
| ------------------------ | ----------------------------------------------- |
| Restart                  | Recover a failed process                        |
| Configuration correction | Remove configuration defect                     |
| Dependency recovery      | Restore required infrastructure                 |
| Runtime recovery         | Return service to healthy operation             |
| Rollback                 | Return application artifact to previous version |

These actions should not be treated as interchangeable.

---

# 45. Operational Escalation

Escalation is appropriate when:

```text
Root cause is unknown
Failure persists after safe remediation
Multiple services are affected
Host-level failure exists
Data integrity may be affected
Deployment state is uncertain
Recovery could cause additional damage
```

When escalation occurs, preserve evidence.

Useful evidence includes:

```text
Logs
Metrics
Alert details
Container state
Deployment state
Recent changes
Configuration state
Timeline
```

---

# 46. Evidence Preservation

Before destructive remediation, preserve enough information to reconstruct the incident.

At minimum record:

```text
Incident start time
Detection time
Affected services
Recent deployment
Current image versions
Container state
Relevant logs
Relevant metrics
Active alerts
Actions performed
Result of each action
```

This is particularly important when a restart or rollback may destroy transient runtime evidence.

---

# 47. Incident Timeline

A simple incident timeline should follow:

```text
T0 — Change / normal operation
T1 — First symptom
T2 — Detection
T3 — Investigation
T4 — Containment
T5 — Recovery
T6 — Verification
T7 — Resolution
```

The timeline should distinguish:

```text
Observation
```

from:

```text
Interpretation
```

For example:

```text
Observation:
API error rate increased to 12%.

Interpretation:
Possible database degradation.

```

This prevents assumptions from becoming undocumented facts.

---

# 48. Operational Verification After Recovery

Recovery is not complete immediately after the corrective action.

Verify:

```text
Application health
Dependency health
Error rate
Latency
Queue behavior
Resource utilization
Logs
Alerts
```

The system should be observed long enough to determine whether the recovery is stable.

Conceptually:

```text
Recovery Action
      │
      ▼
Immediate Health
      │
      ▼
Behavioral Health
      │
      ▼
Stable Health
```

---

# 49. Operational Anti-patterns

## 49.1 Restart Everything

Restarting every service destroys useful diagnostic information and may create additional failures.

Prefer targeted recovery.

---

## 49.2 Treat Container Status as Health

A `running` container can still be unhealthy.

Always inspect application and dependency health.

---

## 49.3 Ignore Dependencies

An API failure does not necessarily mean the API is defective.

Check PostgreSQL, Redis, and MinIO where relevant.

---

## 49.4 Change Configuration During Diagnosis Without Recording It

Untracked configuration changes make incidents harder to reproduce.

Record every operational modification.

---

## 49.5 Disable Alerts to Hide Noise

Alert noise should be investigated and corrected.

Disabling alerting without understanding the cause removes operational visibility.

---

## 49.6 Delete Persistent Data as a First Response

Database, Redis, MinIO, Prometheus, or Loki data should not be deleted merely to make a service start.

Data-destructive actions require explicit justification.

---

## 49.7 Assume the Most Visible Component Is the Root Cause

The first component reporting an error is not necessarily the component that failed.

Follow the dependency graph.

---

# 50. Observability Failure

Observability itself can fail.

Examples:

```text
Prometheus unavailable
Loki unavailable
Promtail stopped
Grafana unavailable
Alertmanager unavailable
Exporter unavailable
```

When this happens:

```text
Application
    │
    ▼
May still be running
    │
    ▼
Operational visibility degraded
```

The incident should therefore distinguish:

```text
Service failure
```

from:

```text
Visibility failure
```

A loss of observability can significantly increase operational risk even when application traffic continues normally.

---

# 51. Security Operations

Security-related operational responsibilities include:

```text
UFW firewall
SSH configuration
Runner access
Docker access
Environment secrets
Deployment permissions
Exposed ports
```

The host firewall uses a default-deny incoming policy with explicitly allowed required TCP ports.

SSH hardening is applied through:

```text
/etc/ssh/sshd_config.d/99-miniwrite-hardening.conf
```

Changes to these controls should be treated as infrastructure changes.

---

# 52. Operational Access

Operational access should follow the principle of least privilege where practical.

The deployment architecture distinguishes between:

```text
root-owned immutable runtime areas
```

and:

```text
deploy-user mutable runtime areas
```

This boundary is established during infrastructure provisioning.

The operational implication is that engineers should not modify root-owned runtime assets manually unless the operational procedure explicitly requires it.

---

# 53. Manual Changes

Manual changes to the staging host should be minimized.

The preferred model is:

```text
Desired State
      │
      ▼
Version-controlled Definition
      │
      ▼
Ansible / Deployment Automation
      │
      ▼
Host
```

Manual changes introduce configuration drift:

```text
Repository State
       ≠
Host State
```

When emergency manual changes are unavoidable, they should be documented and subsequently reconciled into the appropriate source-controlled configuration.

---

# 54. Configuration Drift

Configuration drift occurs when the runtime diverges from the intended version-controlled state.

Potential causes include:

```text
Manual edits
Emergency fixes
Untracked environment changes
Different Docker configuration
Runner modifications
Host package changes
```

The response should be:

```text
Detect
  │
  ▼
Compare
  │
  ▼
Determine intended state
  │
  ▼
Reconcile
```

Ansible provides the primary mechanism for reconciling infrastructure state.

---

# 55. Operational Change Ownership

Different changes belong to different layers.

| Change               | Primary location                           |
| -------------------- | ------------------------------------------ |
| Host package         | Ansible                                    |
| Docker installation  | Ansible                                    |
| Firewall             | Ansible                                    |
| SSH hardening        | Ansible                                    |
| Runner configuration | Ansible                                    |
| Compose topology     | Deployment runtime configuration           |
| Application behavior | Application source                         |
| Runtime reliability  | Application Runtime                        |
| Metrics              | Observability configuration/application    |
| Alerts               | Prometheus rules                           |
| Dashboards           | Grafana provisioning/dashboard definitions |

The operator should modify the correct source rather than patching the runtime arbitrarily.

---

# 56. Standard Investigation Flow

For a generic production-like incident, use:

```text
                  Incident
                     │
                     ▼
              Confirm Symptom
                     │
                     ▼
              Determine Scope
                     │
                     ▼
            Check Recent Changes
                     │
                     ▼
             Check Host Health
                     │
                     ▼
           Check Container Health
                     │
                     ▼
          Check Dependency Health
                     │
                     ▼
              Check Metrics
                     │
                     ▼
               Check Logs
                     │
                     ▼
            Identify Failure Domain
                     │
                     ▼
          Apply Minimal Remediation
                     │
                     ▼
               Verify Recovery
                     │
                     ▼
             Observe Stability
                     │
                     ▼
               Document Result
```

This sequence should be adapted to the incident rather than followed mechanically when stronger evidence already exists.

---

# 57. Operational Decision Framework

Before taking an action, ask:

### What do we know?

Observed evidence.

### What do we suspect?

Current hypothesis.

### What could this action affect?

Potential blast radius.

### Is the action reversible?

Prefer reversible actions during investigation.

### What evidence will be lost?

Important before restart, deletion, or rollback.

### How will we verify success?

Define the verification signal before executing the action.

This creates:

```text
Evidence
   │
   ▼
Hypothesis
   │
   ▼
Action
   │
   ▼
Verification
```

rather than:

```text
Symptom
   │
   ▼
Guess
   │
   ▼
Random Change
```

---

# 58. Operational Blast Radius

Every operational action has a blast radius.

Examples:

| Action               | Approximate scope          |
| -------------------- | -------------------------- |
| Inspect logs         | None                       |
| Inspect metrics      | None                       |
| Restart API          | API                        |
| Restart Worker       | Worker                     |
| Restart Redis        | API/Worker dependency      |
| Restart PostgreSQL   | API/Worker dependency      |
| Restart Docker       | Potentially entire runtime |
| Change firewall      | Host/network               |
| Reprovision host     | Entire environment         |
| Rollback application | Application release        |

Prefer the smallest action that can reasonably resolve the confirmed failure.

---

# 59. Production-oriented Thinking

Although Mini-Write operates as a local staging environment, the operational model intentionally follows production-oriented practices:

```text
Automation
Observability
Health verification
Failure isolation
Deployment traceability
Resource limits
Security boundaries
Recovery procedures
Evidence preservation
```

The purpose is to model operational engineering behavior rather than simply running containers locally.

---

# 60. Operational Maturity Model

The operational capability can be viewed progressively.

### Level 1 — Process Management

```text
Start / stop containers
```

### Level 2 — Health Management

```text
Health checks
```

### Level 3 — Observability

```text
Metrics
Logs
Dashboards
Alerts
```

### Level 4 — Reliability

```text
Timeout
Retry
Failure classification
Recovery
```

### Level 5 — Operational Feedback

```text
Deployment evidence
Incident analysis
Recovery verification
Engineering improvement
```

Mini-Write's architecture is designed around the higher levels rather than treating container startup as the complete operational model.

---

# 61. Relationship With Reliability Engineering

Operations and Reliability Engineering overlap but are not identical.

Operations answers:

> How do we operate and maintain the running system?

Reliability Engineering answers:

> How does the system behave under failure and how does it recover?

The relationship is:

```text
Operations
    │
    ├── Observe
    ├── Detect
    ├── Investigate
    ├── Operate
    └── Recover
            │
            ▼
      Reliability Mechanisms
            │
            ├── Failure Classification
            ├── Timeout
            ├── Retry
            ├── Recovery
            └── Runtime State
```

Detailed reliability architecture is documented under:

```text
docs/reliability/
```

---

# 62. Relationship With Observability

Observability provides the evidence required by operations.

```text
Operations
    │
    ▼
Questions
    │
    ├── What failed?
    ├── When?
    ├── Where?
    ├── How often?
    └── Is it recovering?
            │
            ▼
       Observability
```

Therefore operational procedures should reference observability rather than inventing separate monitoring mechanisms.

---

# 63. Relationship With Deployment

Deployment changes the operational state of the system.

Therefore:

```text
Deployment
    │
    ▼
Operational Validation
    │
    ▼
Healthy Runtime
```

and:

```text
Deployment
    │
    ▼
Failure
    │
    ▼
Incident / Recovery
```

Deployment and operations are consequently adjacent lifecycle phases.

---

# 64. Operational Documentation Map

This document is the operational entry point.

Detailed topics are documented separately:

```text
docs/operations/
├── operations.md
├── health-checks.md
└── incident-response.md
```

The separation is intentional.

### `operations.md`

Defines the general operational model.

### `health-checks.md`

Defines health verification and probe semantics.

### `incident-response.md`

Defines incident handling and response procedures.

---

# 65. Related Documentation

Operational work frequently requires the following documents:

```text
Architecture
├── docs/architecture/overview.md
├── docs/architecture/system-architecture.md
├── docs/architecture/service-architecture.md
└── docs/architecture/networking.md

Infrastructure
├── docs/infrastructure/overview.md
├── docs/infrastructure/ansible.md
├── docs/infrastructure/host-provisioning.md
├── docs/infrastructure/docker.md
└── docs/infrastructure/security-baseline.md

Deployment
├── docs/deployment/deployment.md
├── docs/deployment/configuration.md
└── docs/deployment/ci-cd.md

Reliability
├── docs/reliability/reliability.md
├── docs/reliability/failure-model.md
├── docs/reliability/runtime-reliability.md
└── docs/reliability/recovery.md

Observability
├── docs/observability/observability.md
├── docs/observability/metrics.md
├── docs/observability/logging.md
├── docs/observability/alerting.md
└── docs/observability/dashboards.md

Troubleshooting
├── docs/troubleshooting/common-issues.md
├── docs/troubleshooting/infrastructure-issues.md
├── docs/troubleshooting/deployment-issues.md
└── docs/troubleshooting/runtime-issues.md
```

---

# 66. Operational Definition of Done

The staging environment is considered operationally understood when an engineer can answer:

```text
✓ What services are running?
✓ What dependencies does each service require?
✓ Where does the runtime live?
✓ How are containers managed?
✓ How is API health verified?
✓ How is Worker health evaluated?
✓ How are dependencies checked?
✓ How are metrics collected?
✓ How are logs collected?
✓ How are alerts generated?
✓ How is deployment state tracked?
✓ How is a failed deployment investigated?
✓ How is a runtime incident investigated?
✓ What is the smallest safe recovery action?
✓ When should rollback be considered?
✓ Where is operational evidence stored?
✓ Which source-controlled definition owns each operational change?
```

---

# 67. Operational Golden Path

The normal operational lifecycle can be summarized as:

```text
                    ┌───────────────┐
                    │  Versioned    │
                    │  System       │
                    └───────┬───────┘
                            │
                            ▼
                    ┌───────────────┐
                    │   Deploy      │
                    └───────┬───────┘
                            │
                            ▼
                    ┌───────────────┐
                    │   Verify      │
                    └───────┬───────┘
                            │
                            ▼
                    ┌───────────────┐
                    │    Observe    │
                    └───────┬───────┘
                            │
                     ┌──────┴──────┐
                     │             │
                  Healthy       Degraded
                     │             │
                     ▼             ▼
                  Operate       Investigate
                                   │
                                   ▼
                                Recover
                                   │
                                   ▼
                                Verify
                                   │
                                   ▼
                                Observe
```

The core operational principle is:

> **Operate from evidence, make the smallest safe change, and verify the resulting state.**

This principle connects the infrastructure, deployment, reliability, and observability layers into a single operational discipline.

```
```
