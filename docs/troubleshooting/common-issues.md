# Common Issues

## 1. Purpose

This document provides a practical troubleshooting guide for common Mini-Write operational and development problems.

It is intended to help an engineer move from:

```text
Observed Symptom
      │
      ▼
Initial Classification
      │
      ▼
Likely Failure Domain
      │
      ▼
Verification
      │
      ▼
Corrective Action
      │
      ▼
Validation
````

The goal is not to provide a list of arbitrary fixes.

The goal is to establish a repeatable troubleshooting process that prevents engineers from changing configuration blindly.

---

# 2. Troubleshooting Philosophy

Mini-Write is built as a layered system.

A visible failure at one layer may originate from another layer.

For example:

```text
HTTP 500
   │
   ├── API application failure
   ├── PostgreSQL failure
   ├── Redis failure
   ├── MinIO failure
   ├── Runtime failure
   ├── configuration failure
   └── deployment/environment failure
```

Therefore:

> Do not troubleshoot the symptom before identifying the failure domain.

The recommended investigation order is:

```text
Availability
    │
    ▼
Container / Process State
    │
    ▼
Network Connectivity
    │
    ▼
Dependency Health
    │
    ▼
Application Logs
    │
    ▼
Runtime / Failure Classification
    │
    ▼
Configuration
    │
    ▼
Recent Deployment / Change
```

---

# 3. Failure Domains

Common issues should first be classified into one of the following domains:

| Domain        | Examples                                     |
| ------------- | -------------------------------------------- |
| Host          | VM unavailable, disk full, memory pressure   |
| Docker        | daemon unavailable, container stopped        |
| Network       | incorrect network, unreachable service       |
| Configuration | missing or incorrect environment variable    |
| Application   | API/Worker process failure                   |
| Dependency    | PostgreSQL, Redis, or MinIO unavailable      |
| Runtime       | timeout, retry, failure classification       |
| Observability | missing metrics, logs, or alerts             |
| Deployment    | incorrect image, failed deployment state     |
| CI/CD         | runner unavailable or incorrectly configured |
| Security      | firewall or SSH configuration issue          |

---

# 4. First Response Checklist

When an unexpected problem occurs, collect the following information before changing anything:

```text
1. What is failing?
2. When did the failure begin?
3. Is the failure persistent or intermittent?
4. Which service is affected?
5. Is the failure affecting all requests or one operation?
6. Was there a recent deployment?
7. Was there a recent infrastructure/configuration change?
8. Are dependencies healthy?
9. Are metrics available?
10. Are application logs available?
```

The most important question is:

```text
What changed immediately before the failure?
```

A recent change does not prove causality, but it is an important investigation signal.

---

# 5. Establish the Current System State

Before investigating an individual service, establish whether the overall deployment is running.

Check the deployment host and Docker runtime first.

```bash
docker ps
```

Inspect all containers, including stopped containers:

```bash
docker ps -a
```

If the deployment uses the staging Compose configuration, inspect the effective service configuration:

```bash
docker compose -f /opt/deploy/compose/docker-compose.staging.yml config
```

If this command fails, investigate the Compose/configuration layer before investigating application behavior.

---

# 6. Check Service Container State

The primary services are:

```text
gateway
api
worker
postgres
redis
storage
```

The observability stack includes:

```text
prometheus
loki
promtail
alertmanager
grafana
node-exporter
cadvisor
redis-exporter
postgres-exporter
```

A stopped container is an important initial signal.

However:

> A running container does not prove that the service is healthy.

Container state and application health are different concepts.

---

# 7. Check Container Logs

For a service that is failing, inspect its logs:

```bash
docker logs <container>
```

For recent logs:

```bash
docker logs --tail 200 <container>
```

For timestamped logs:

```bash
docker logs --timestamps --tail 200 <container>
```

Examples:

```bash
docker logs --tail 200 <api-container>
docker logs --tail 200 <worker-container>
docker logs --tail 200 <postgres-container>
docker logs --tail 200 <redis-container>
```

Avoid immediately increasing log verbosity.

First determine whether the existing structured logs already contain enough information.

---

# 8. Check Runtime Logs

API Runtime failures contain structured fields such as:

```text
request_id
execution_id
operation_id
dependency
failure_type
recoverable
retries
error_message
```

Runtime-related events include:

```text
runtime_operation_started
runtime_operation_completed
runtime_operation_retry
runtime_operation_failed
runtime_failure_handled
runtime_completed
```

When investigating an API failure, these fields can be used to reconstruct the execution path.

The investigation should therefore move from:

```text
HTTP failure
    │
    ▼
request_id
    │
    ▼
execution_id
    │
    ▼
operation_id
    │
    ▼
dependency
    │
    ▼
failure classification
```

---

# 9. API Is Not Reachable

## Symptom

The API cannot be accessed through the gateway.

Possible symptoms include:

```text
connection refused
502 Bad Gateway
503 Service Unavailable
timeout
```

## Investigation

Start with container state:

```bash
docker ps -a
```

Then inspect:

```bash
docker logs <api-container>
docker logs <gateway-container>
```

Check the API health endpoints from inside the deployment network if appropriate:

```text
/health/live
/health/ready
```

The distinction is important.

### Liveness

```text
/health/live
```

answers:

> Is the API process alive?

### Readiness

```text
/health/ready
```

answers:

> Is the API capable of serving traffic considering its required dependencies?

---

# 10. API Container Is Running but Health Check Fails

A running API container can still fail its health check.

The configured container health check uses:

```text
/health/ready
```

Therefore investigate:

```text
API process
   │
   ▼
/health/ready
   │
   ▼
getSystemHealth()
   │
   ├── PostgreSQL
   ├── Redis
   └── other required checks
```

If readiness fails, do not restart the API repeatedly.

Determine which dependency is causing the readiness failure.

---

# 11. API Returns HTTP 500

An HTTP 500 response is a symptom, not a root cause.

Investigate in this order:

```text
1. API logs
2. Runtime failure logs
3. operation_id
4. dependency
5. failure_type
6. dependency health
7. recent deployment/configuration changes
```

For Runtime-managed infrastructure operations, failure classification can identify categories such as:

```text
timeout
dependency
internal
```

The classification should guide the next investigation step.

---

# 12. API Returns HTTP 504

The Runtime maps:

```text
RuntimeTimeoutError
```

to:

```text
HTTP 504
```

This indicates that the Runtime timeout boundary was reached.

Investigate:

```text
1. operation_id
2. dependency
3. configured timeout
4. operation duration
5. dependency latency
6. retry behavior
```

A timeout does not necessarily mean the dependency is completely unavailable.

It may indicate:

```text
dependency is healthy
        but
dependency response time > operation timeout
```

---

# 13. API Authentication Fails

For login failures, distinguish between:

```text
Invalid credentials
```

and:

```text
Infrastructure failure
```

An invalid username/password is an application-level authentication result.

A PostgreSQL connection failure is an infrastructure/dependency problem.

Inspect Runtime and application logs before assuming that authentication logic itself is broken.

Relevant operation:

```text
user_login
```

Relevant dependency:

```text
postgresql
```

---

# 14. User Registration Fails

Registration requires PostgreSQL.

The expected flow is:

```text
POST /api/v1/auth/register
        │
        ▼
Runtime operation resolution
        │
        ▼
user_register
        │
        ▼
PostgreSQL operation
        │
        ▼
INSERT users
```

If registration fails, investigate:

```text
API
 │
 └── PostgreSQL
```

A duplicate username is handled as an application-level condition and should not automatically be treated as infrastructure failure.

---

# 15. ID Upload Fails

ID upload is a multi-dependency operation.

The workflow involves:

```text
API
 │
 ├── MinIO
 │
 ├── PostgreSQL
 │
 └── Redis
       │
       └── Background Worker
```

The operation is:

```text
id_upload
```

and its Runtime characteristics include:

```text
requiresDatabase = true
requiresStorage = true
asynchronous = true
```

Therefore an upload failure should be decomposed into:

```text
File validation
       │
       ▼
MinIO upload
       │
       ▼
PostgreSQL update
       │
       ▼
Redis job enqueue
       │
       ▼
Worker processing
```

Do not treat all upload failures as MinIO failures.

---

# 16. Upload Succeeds but Processing Does Not Start

This is a different failure from upload failure.

If the API reports successful upload but the background processing does not happen, investigate:

```text
API
 │
 ▼
Redis enqueue
 │
 ▼
Worker
```

Check:

```text
Redis health
Queue depth
Worker availability
Worker logs
Worker metrics
```

A successful object-storage upload does not prove successful asynchronous processing.

---

# 17. Worker Is Not Processing Jobs

## Symptom

Jobs remain queued.

Start with:

```bash
docker ps -a
```

Then inspect Worker logs:

```bash
docker logs --tail 200 <worker-container>
```

Check:

```text
mw_worker_queue_depth
mw_worker_jobs_active
mw_worker_jobs_processed_total
mw_worker_job_failures_total
```

The investigation should determine whether the Worker is:

```text
down
```

or:

```text
alive but unable to process
```

or:

```text
processing too slowly
```

---

# 18. Queue Backlog Is Increasing

A queue backlog is not automatically a Worker crash.

Possible causes include:

```text
1. Worker unavailable
2. Worker concurrency too low
3. Job processing latency increased
4. Redis problems
5. PostgreSQL latency
6. MinIO latency
7. Host resource saturation
8. workload increased
```

Correlate:

```text
queue_depth
jobs_active
jobs_processed_total
job_duration
job_failures_total
CPU
memory
storage latency
database latency
```

---

# 19. Worker Is Up but Jobs Fail

If the Worker is running but job failures increase, inspect:

```text
job failure metric
Worker structured logs
dependency failures
image-processing errors
PostgreSQL
MinIO
Redis
```

A Worker process being alive does not imply successful job execution.

---

# 20. Redis Is Unavailable

Redis serves as a queue/cache dependency.

Symptoms may include:

```text
ID upload cannot enqueue jobs
Worker cannot consume jobs
readiness failures
connection errors
```

Check:

```bash
docker ps -a
docker logs --tail 200 <redis-container>
```

The Redis health check uses:

```text
redis-cli ping
```

The expected healthy response is:

```text
PONG
```

Also verify that the application and Worker are attached to the correct Docker network.

---

# 21. PostgreSQL Is Unavailable

PostgreSQL is used for persistent application state.

Symptoms may include:

```text
registration failures
login failures
readiness failures
Worker processing failures
```

Check:

```bash
docker ps -a
docker logs --tail 200 <postgres-container>
```

The Compose health check uses:

```text
pg_isready
```

Also inspect:

```text
database credentials
database name
network connectivity
disk capacity
database container state
```

---

# 22. MinIO Is Unavailable

MinIO provides object storage.

Symptoms may include:

```text
ID upload failures
Worker storage failures
storage latency alerts
```

The storage service exposes:

```text
9000
```

for its API and:

```text
9001
```

for its console.

The container health check uses:

```text
/minio/health/live
```

Investigate:

```text
container state
MinIO logs
network connectivity
credentials
persistent volume
host disk capacity
```

---

# 23. Docker Network Connectivity Failure

Mini-Write separates traffic into:

```text
frontend-network
backend-network
```

The intended topology is:

```text
Gateway
   │
   ▼
frontend-network
   │
   ▼
API
   │
   ▼
backend-network
   │
   ├── PostgreSQL
   ├── Redis
   ├── MinIO
   └── Worker
```

Observability services are also connected to the backend network according to the Compose configuration.

If a service cannot reach another service, verify network membership before changing application configuration.

Useful inspection:

```bash
docker network ls
```

and:

```bash
docker network inspect <network>
```

---

# 24. DNS Resolution Between Containers Fails

Docker Compose service names are used for internal service discovery.

Examples include:

```text
api
worker
postgres
redis
storage
prometheus
loki
alertmanager
grafana
```

If an application cannot resolve a dependency, investigate:

```text
1. Is the dependency container running?
2. Are both containers on the same Docker network?
3. Is the service name correct?
4. Did the Compose configuration change?
```

Do not replace service names with hard-coded IP addresses.

Container IP addresses are not stable deployment identities.

---

# 25. Gateway Returns 502

A 502 response usually means the gateway cannot successfully communicate with its upstream.

Investigate:

```text
Gateway
   │
   ▼
Nginx configuration
   │
   ▼
API availability
   │
   ▼
Docker network
```

Inspect:

```bash
docker logs --tail 200 <gateway-container>
docker logs --tail 200 <api-container>
```

Then verify the API container and its health state.

---

# 26. Prometheus Does Not Show API Metrics

First verify the API endpoint:

```text
/metrics
```

Then verify the API container.

Next verify Prometheus target configuration:

```text
api:80
```

and:

```text
metrics_path: /metrics
```

The Prometheus target should report as healthy.

The investigation path is:

```text
API registry
    │
    ▼
/metrics
    │
    ▼
Docker network
    │
    ▼
Prometheus scrape
    │
    ▼
Prometheus query
```

Do not begin by modifying Grafana.

Grafana is downstream of Prometheus.

---

# 27. Worker Metrics Are Missing

The Worker is scraped at:

```text
worker:9464
```

Verify:

```text
Worker container
       │
       ▼
port 9464
       │
       ▼
/metrics
       │
       ▼
Prometheus target
```

If the Worker itself is healthy but Prometheus cannot scrape it, investigate:

```text
port exposure/listening
Docker network
Worker metrics server
Prometheus configuration
```

---

# 28. Grafana Shows No Data

Grafana depends on Prometheus and Loki.

The data flow is:

```text
Application
   │
   ├── Metrics ──► Prometheus ──► Grafana
   │
   └── Logs ─────► Promtail ──► Loki ──► Grafana
```

If a dashboard is empty, determine first whether the problem is:

```text
Grafana
```

or:

```text
Prometheus/Loki
```

Check the configured datasources:

```text
Prometheus
Loki
```

Then test the datasource independently.

Do not modify dashboard queries before verifying that the datasource contains the expected data.

---

# 29. Grafana Dashboard Is Missing

Dashboards are provisioned from files.

The provisioning configuration defines providers for:

```text
System
Application
Queue
Deployment
Incidents
```

The expected filesystem structure is:

```text
/var/lib/grafana/dashboards/
├── system
├── application
├── queue
├── deployment
└── incidents
```

If a dashboard is missing, investigate:

```text
1. Dashboard JSON exists
2. Dashboard was copied into the deployment
3. Provider path is correct
4. Grafana container can read the file
5. Grafana provisioning completed successfully
```

---

# 30. Logs Are Missing from Loki

The logging flow is:

```text
Docker / Deployment Logs
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

If logs are missing:

```text
1. Check container logs directly.
2. Check Promtail state.
3. Check Promtail configuration.
4. Check Loki availability.
5. Check Promtail positions.
6. Query Loki directly through Grafana.
```

Do not assume that missing Grafana logs mean that the application stopped generating logs.

---

# 31. Promtail Cannot Read Docker Logs

Promtail requires access to:

```text
/var/lib/docker/containers
```

and the deployment Compose configuration mounts this path read-only.

If container logs are not being collected, verify:

```text
Docker log driver
Promtail container mounts
Promtail configuration
file paths
Promtail logs
```

---

# 32. Alerts Are Not Firing

The alerting pipeline is:

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

Investigate in that order.

Do not start with Alertmanager.

First determine whether Prometheus is evaluating the rule and whether its expression actually becomes true.

---

# 33. Alertmanager Receives Alerts but No External Notification

The current Alertmanager configuration defines receivers:

```text
default
critical
warning
info
```

External webhook configurations are currently commented out.

Therefore:

> The presence of an Alertmanager receiver does not imply that an external notification channel is configured.

If external notifications are required, the receiver configuration must explicitly define an appropriate notification integration.

---

# 34. Infrastructure Metrics Disappear

If host metrics disappear, investigate Node Exporter first.

The infrastructure alert:

```text
MWNodeExporterDown
```

indicates that Prometheus cannot scrape:

```text
node-exporter:9100
```

Check:

```bash
docker ps -a
docker logs --tail 200 <node-exporter-container>
```

Then inspect Prometheus targets.

---

# 35. High CPU Alert

The current threshold is:

```text
> 90%
```

for:

```text
10 minutes
```

Do not immediately restart containers.

Investigate:

```text
1. Which process consumes CPU?
2. Which container consumes CPU?
3. Is traffic elevated?
4. Is Worker processing increased?
5. Is there a retry storm?
6. Is a dependency slow?
7. Was a recent deployment made?
```

High CPU should be correlated with application and Worker metrics.

---

# 36. High Memory Alert

The current threshold is:

```text
> 90%
```

for:

```text
10 minutes
```

Investigate:

```text
Host memory
Container memory
API memory
Worker memory
Database memory
Observability stack
```

Look for:

```text
increasing memory over time
container restarts
OOM events
unusually large workload
```

A single high measurement is less informative than a sustained trend.

---

# 37. Low Disk Space

The current infrastructure alert triggers when available filesystem capacity falls below:

```text
10%
```

Possible causes include:

```text
Docker images
Docker volumes
container logs
application logs
Prometheus data
Loki data
database data
MinIO data
```

Do not delete persistent volumes as a first response.

First identify which filesystem and directory are consuming capacity.

Persistent data may be required for application correctness.

---

# 38. Deployment State Looks Incorrect

Deployment state is stored in:

```text
/opt/deploy/state/deployment_state.json
```

The initial structure is:

```json
{
  "current": {
    "api": "",
    "worker": ""
  },
  "previous": {
    "api": "",
    "worker": ""
  }
}
```

The state represents deployment image/version information.

If deployment behavior does not match the expected version, inspect:

```text
deployment state
environment file
Compose configuration
running container image
CI/CD deployment logs
```

Do not manually edit deployment state unless the operational procedure explicitly requires it.

---

# 39. Staging Environment File Is Missing

The staging environment file is:

```text
/opt/deploy/env/.env.staging
```

It is provisioned by Ansible.

If it is missing:

```text
1. Check deploy_runtime role execution.
2. Check Ansible variables.
3. Check the staging secrets source.
4. Verify file permissions.
```

The intended permissions are:

```text
0640
```

and ownership is assigned to the deployment user after bootstrap.

---

# 40. Docker Permission Denied for Deploy User

The deployment user is expected to belong to:

```text
docker
```

The Ansible GitHub Runner role explicitly validates this.

Check:

```bash
id -nG <deploy-user>
```

If `docker` is missing, investigate the Docker role and user configuration.

Remember that group membership changes may require a new login/session before they become effective for an existing shell.

Do not solve this by broadly granting unnecessary privileges.

---

# 41. GitHub Actions Runner Is Offline

The GitHub Actions runner is provisioned by Ansible.

The expected lifecycle is:

```text
Runner installation
      │
      ▼
Runner registration
      │
      ▼
systemd service
      │
      ▼
Runner active
```

Check the host service:

```bash
systemctl status actions.runner.<owner>-<repo>.<runner-name>
```

Also check:

```bash
systemctl is-active actions.runner.<owner>-<repo>.<runner-name>
```

If the service is running but GitHub reports the runner as unavailable, investigate:

```text
network connectivity
runner registration
runner credentials/token
runner service logs
```

---

# 42. Ansible Playbook Fails

The main playbook is:

```text
infra/ansible/playbooks/site.yml
```

The role sequence is:

```text
base
docker
deploy_runtime
github_runner
security_baseline
```

This order is significant because later roles depend on infrastructure established by earlier roles.

When a play fails:

```text
1. Identify the failing role.
2. Identify the failing task.
3. Determine whether the failure is idempotency-related.
4. Check variables.
5. Check target host state.
6. Re-run only after understanding the failure.
```

Do not modify unrelated roles to make an individual task pass.

---

# 43. Ansible Check Mode Behaves Differently

Some Docker tasks explicitly skip execution in check mode.

This means:

```text
ansible-playbook --check
```

does not necessarily reproduce the exact final runtime state.

For example, Docker installation/service tasks use:

```text
when: not ansible_check_mode
```

Therefore check mode should be interpreted as a configuration prediction rather than complete runtime validation.

---

# 44. UFW Blocks Required Traffic

The security baseline establishes:

```text
incoming: deny
outgoing: allow
```

and then explicitly allows required TCP ports.

If an external service becomes unreachable after security baseline application, inspect the firewall before changing application configuration.

Check:

```bash
sudo ufw status
```

Then verify whether the required port is explicitly allowed.

Do not switch the default incoming policy to `allow` as a troubleshooting shortcut.

---

# 45. SSH Access Is Lost After Hardening

SSH hardening is deployed through:

```text
/etc/ssh/sshd_config.d/99-miniwrite-hardening.conf
```

The Ansible template is validated using:

```text
/usr/sbin/sshd -t
```

If SSH behavior changes unexpectedly:

```text
1. Validate sshd configuration.
2. Inspect the generated override.
3. Check authentication method.
4. Check firewall rules.
5. Check whether the SSH service is active.
```

The security baseline intentionally controls:

```text
PasswordAuthentication
PermitRootLogin
PubkeyAuthentication
PermitEmptyPasswords
```

Do not weaken these controls without an explicit security decision.

---

# 46. Docker Compose Configuration Fails to Render

The deployment Compose file is generated from:

```text
docker-compose.staging.yml.j2
```

through Ansible.

If the generated configuration is invalid, investigate:

```text
Jinja variables
Ansible inventory
staging variables
environment references
YAML structure
```

After generation, validate the effective Compose configuration:

```bash
docker compose -f /opt/deploy/compose/docker-compose.staging.yml config
```

This catches structural configuration problems before service startup.

---

# 47. Environment Variable Is Missing

When an application behaves unexpectedly, inspect the configuration chain:

```text
Ansible variables
      │
      ▼
.env.staging
      │
      ▼
Docker Compose
      │
      ▼
Container environment
      │
      ▼
Application process
```

Do not assume that a variable defined in one layer automatically exists in another.

For sensitive values, avoid printing secrets into logs or shell history.

---

# 48. Service Restarts Repeatedly

A restart loop usually means:

```text
process starts
   │
   ▼
startup condition fails
   │
   ▼
process exits
   │
   ▼
restart policy
   │
   └──────────────► process starts again
```

Investigate:

```text
1. Container logs
2. Application startup error
3. Configuration
4. Dependency availability
5. Credentials
6. File permissions
7. Resource limits
```

Do not disable the restart policy merely to hide the symptom.

The restart policy is an operational safety mechanism.

---

# 49. Health Check Fails but Application Appears Functional

Health checks intentionally provide a narrower operational contract than general application behavior.

For example:

```text
Application process alive
```

does not necessarily mean:

```text
Application ready to receive production traffic
```

Distinguish:

```text
process state
container state
liveness
readiness
dependency health
```

A readiness failure should therefore be investigated according to its dependency contract.

---

# 50. Observability Stack Is Consuming Excessive Resources

The observability stack itself consumes CPU, memory, and disk.

Relevant components include:

```text
Prometheus
Loki
Promtail
Grafana
Alertmanager
Node Exporter
cAdvisor
Redis Exporter
PostgreSQL Exporter
```

If resource usage increases unexpectedly, determine whether the cause is:

```text
metric cardinality
log volume
retention
query load
dashboard refresh rate
container resource limits
```

Do not disable observability blindly during an incident.

Reducing observability can remove the evidence needed to understand the incident.

---

# 51. Prometheus Storage Grows Rapidly

Possible causes include:

```text
high metric cardinality
high scrape frequency
large number of time series
long retention
unexpected labels
```

Investigate metric cardinality before simply deleting Prometheus data.

Particular attention should be given to labels containing dynamic values.

---

# 52. Loki Storage Grows Rapidly

Loki is configured with:

```text
retention_period: 168h
```

which corresponds to:

```text
7 days
```

Rapid growth may still occur when log volume is unusually high.

Investigate:

```text
application log volume
container restart loops
deployment logs
label cardinality
retention configuration
```

Do not remove Loki data while an incident investigation still depends on historical logs.

---

# 53. Metric Exists but Dashboard Is Empty

This commonly indicates a query or label mismatch rather than a missing metric.

Check the raw Prometheus series first.

For example, verify:

```text
metric name
service label
environment label
instance label
job label
```

Then compare those labels with the dashboard query.

The troubleshooting sequence is:

```text
Metric exists?
     │
     ├── No ──► instrumentation/collection problem
     │
     └── Yes
          │
          ▼
     Query correct?
          │
          ├── No ──► dashboard query problem
          │
          └── Yes
                │
                ▼
          Visualization problem
```

---

# 54. Alert Exists but Does Not Trigger

An alert rule may be syntactically valid but operationally inactive.

Check:

```text
1. Metric exists.
2. Query returns data.
3. Labels match.
4. Threshold is actually exceeded.
5. `for` duration has elapsed.
6. Prometheus rule is loaded.
```

For example:

```text
queue depth > 10
```

for:

```text
10 minutes
```

does not fire immediately when queue depth reaches 11.

The condition must remain true for the configured duration.

---

# 55. False Positive Alert

If an alert fires but the system appears healthy, investigate whether the alert represents:

```text
real degradation
```

or:

```text
measurement/query problem
```

Check:

```text
metric semantics
aggregation
labels
threshold
evaluation interval
data availability
```

Do not simply increase the threshold.

Changing a threshold without understanding the signal can hide real incidents.

---

# 56. Recent Deployment Is Suspected

When a failure begins shortly after deployment, compare:

```text
previous version
current version
deployment time
first failure time
affected service
changed configuration
```

The deployment state tracks current and previous API/Worker versions.

Use this information to determine whether rollback or forward correction is appropriate.

---

# 57. Rollback Decision

Rollback should not be the automatic response to every failure.

Consider rollback when:

```text
1. Failure began immediately after deployment.
2. The affected behavior worked previously.
3. The previous version is known to be functional.
4. The failure is attributable to the deployed change.
5. Rollback risk is lower than continued operation.
```

Do not rollback blindly when the real cause is:

```text
database corruption
infrastructure failure
external dependency failure
configuration drift
host resource exhaustion
```

A rollback cannot fix those root causes.

---

# 58. Troubleshooting by Signal

A useful mapping is:

| Signal                 | First Investigation                  |
| ---------------------- | ------------------------------------ |
| HTTP 502               | Gateway → API                        |
| HTTP 503               | API readiness / dependency           |
| HTTP 500               | Application / Runtime                |
| HTTP 504               | Runtime timeout / dependency latency |
| Queue backlog          | Worker / dependencies / throughput   |
| Worker down            | Worker container/process             |
| High API latency       | API / dependencies / host            |
| High Worker latency    | Worker / storage / database          |
| High CPU               | Host / container workload            |
| High memory            | Host / container memory              |
| Low disk               | Docker/log/data usage                |
| Missing metrics        | Application → Prometheus             |
| Missing logs           | Application → Promtail → Loki        |
| Missing dashboard data | Prometheus/Loki → Grafana            |
| Missing alerts         | Prometheus rules → Alertmanager      |
| Runner offline         | systemd runner service / network     |

---

# 59. Troubleshooting by Dependency

## PostgreSQL

Investigate when:

```text
registration fails
login fails
readiness fails
Worker database operations fail
```

## Redis

Investigate when:

```text
jobs cannot be enqueued
Worker cannot consume jobs
queue behavior is abnormal
```

## MinIO

Investigate when:

```text
file upload fails
Worker storage operations fail
storage latency increases
```

## Docker

Investigate when:

```text
multiple services fail simultaneously
network connectivity breaks
containers cannot start
resource usage is abnormal
```

## Host

Investigate when:

```text
multiple unrelated services degrade
CPU is saturated
memory is exhausted
disk is nearly full
```

---

# 60. Multiple Services Fail Simultaneously

When several services fail at approximately the same time, investigate shared infrastructure before individual applications.

The likely dependency chain is:

```text
Host
 │
 ├── Docker
 │    │
 │    ├── API
 │    ├── Worker
 │    ├── PostgreSQL
 │    ├── Redis
 │    └── MinIO
 │
 └── Networking
```

Multiple simultaneous application failures are often a strong signal of:

```text
host failure
Docker failure
network failure
resource exhaustion
configuration/deployment issue
```

rather than independent application bugs.

---

# 61. One Service Fails While Others Remain Healthy

This pattern increases the probability of a service-local failure.

Investigate:

```text
application process
service configuration
service-specific dependency
recent image/version
service resource limits
service-specific logs
```

Avoid changing shared infrastructure unless evidence points to it.

---

# 62. Intermittent Failure

Intermittent failures require temporal correlation.

Collect:

```text
timestamp
request rate
latency
failure rate
dependency latency
CPU
memory
queue depth
retries
deployment events
```

The objective is to determine whether failures correlate with:

```text
traffic spikes
resource saturation
dependency instability
timeouts
retries
deployment activity
```

An intermittent failure should not be diagnosed from a single successful request.

---

# 63. Retry Storm

Retries can improve recovery from transient failures, but excessive retries can amplify load.

The Runtime retry model is intentionally policy-driven.

For operations such as:

```text
id_upload
```

retry is enabled with a bounded retry count.

The investigation should inspect:

```text
retry count
failure type
dependency
operation
latency
overall request rate
```

If retries increase while dependency latency is already high, the retry mechanism itself may contribute to load amplification.

---

# 64. Timeout Does Not Equal Cancellation

A Runtime timeout is implemented through a race between:

```text
operation promise
```

and:

```text
timeout promise
```

Therefore a timeout indicates that the Runtime stopped waiting for the operation within the configured timeout boundary.

It should not automatically be interpreted as proof that the underlying asynchronous operation was physically cancelled.

This distinction is important when investigating:

```text
duplicate writes
late responses
side effects
retry behavior
```

Operations with side effects should therefore be designed with appropriate idempotency considerations.

---

# 65. Failure Classification Appears Incorrect

Runtime failure classification considers:

```text
timeout
dependency
authentication
authorization
validation
internal
```

For dependency operations, transient error codes influence recoverability and retryability.

If classification appears incorrect, inspect:

```text
error.name
error.code
statusCode
dependency context
classification rules
```

Do not modify the retry policy merely because a failure was classified unexpectedly.

First determine whether the classification itself is correct.

---

# 66. Configuration Drift

Configuration drift occurs when the actual host state differs from the intended Ansible-managed state.

Possible examples:

```text
Docker configuration changed manually
firewall rules changed manually
service configuration changed manually
deployment directories modified
runner state changed manually
```

When drift is suspected:

```text
1. Identify the intended state.
2. Identify the actual state.
3. Determine when divergence occurred.
4. Reconcile through the infrastructure automation where appropriate.
```

Avoid treating manual host modification as the permanent solution.

---

# 67. Manual Fixes During Incidents

Manual changes may be necessary during an incident, but they create a risk of configuration drift.

Any emergency manual change should be followed by:

```text
Incident
   │
   ▼
Temporary Change
   │
   ▼
Service Recovery
   │
   ▼
Document Change
   │
   ▼
Encode Desired State
   │
   ▼
Re-run / validate automation
```

The final desired state should live in the repository whenever practical.

---

# 68. What Not to Do

Avoid the following troubleshooting patterns.

## Restart Everything

```bash
docker compose down
docker compose up -d
```

should not be the first response to an unknown problem.

It destroys useful runtime state and can make diagnosis harder.

---

## Delete Persistent Volumes

Never delete:

```text
postgres_data
redis_data
minio_data
prometheus_data
grafana_data
loki_data
alertmanager_data
```

as a generic troubleshooting step.

Persistent volumes contain state.

Deletion is a destructive operation and requires an explicit recovery decision.

---

## Disable the Firewall

Do not change:

```text
incoming deny
```

to:

```text
incoming allow
```

just to determine whether networking is involved.

Identify the specific blocked port instead.

---

## Disable Health Checks

Health checks provide operational signals.

Disabling them can hide the underlying failure rather than fix it.

---

## Remove Observability

Do not disable Prometheus, Loki, or other observability components during an investigation unless resource pressure itself is proven to be the cause and the change is controlled.

---

# 69. Minimal Evidence Collection

Before escalating an unresolved issue, collect:

```text
Timestamp:
Environment:
Affected service:
Affected operation:
Expected behavior:
Observed behavior:
Recent deployment:
Recent configuration change:
Container state:
Health state:
Relevant metric:
Relevant log event:
Runtime request_id:
Runtime execution_id:
Runtime operation_id:
Dependency:
Failure classification:
```

This converts:

```text
"It is broken"
```

into an actionable engineering incident description.

---

# 70. Escalation Criteria

Escalate the investigation when:

```text
1. Multiple independent failure domains have been ruled out.
2. The failure is reproducible but root cause remains unknown.
3. Persistent data may be at risk.
4. Security controls may be involved.
5. Recovery requires destructive action.
6. Infrastructure state may need manual modification.
7. The failure indicates an architectural reliability weakness.
```

The purpose of escalation is not to stop investigation.

It is to prevent unsafe changes when the blast radius is unclear.

---

# 71. Troubleshooting Decision Tree

The following decision tree provides a general starting point:

```text
                    Failure observed
                           │
                           ▼
                  Is the host reachable?
                     /           \
                   No             Yes
                   │               │
             Host investigation   ▼
                           Is Docker healthy?
                              /          \
                            No            Yes
                            │              │
                      Docker issue         ▼
                                  Are containers running?
                                     /          \
                                   No            Yes
                                   │              │
                             Deployment issue     ▼
                                          Are health checks passing?
                                             /          \
                                           No            Yes
                                           │              │
                                     Dependency /        ▼
                                     application   Is traffic failing?
                                                      /      \
                                                    Yes       No
                                                    │          │
                                                API/runtime   Metrics/logs
                                                investigation investigation
```

This is a starting point, not a replacement for evidence.

---

# 72. Recommended Investigation Order

For production-like incidents, use:

```text
Phase 1 — Establish Impact
    │
    ├── affected users
    ├── affected service
    └── affected operation

Phase 2 — Establish Availability
    │
    ├── host
    ├── Docker
    ├── containers
    └── health checks

Phase 3 — Establish Failure Domain
    │
    ├── application
    ├── dependency
    ├── network
    ├── configuration
    └── deployment

Phase 4 — Correlate Evidence
    │
    ├── metrics
    ├── logs
    ├── Runtime state
    └── recent changes

Phase 5 — Recover
    │
    ├── reversible action first
    ├── validate recovery
    └── preserve evidence

Phase 6 — Learn
    │
    ├── root cause
    ├── contributing factors
    ├── corrective action
    └── preventive improvement
```

---

# 73. Troubleshooting Completion Criteria

A troubleshooting investigation should not be considered complete merely because the service started working again.

A complete investigation should establish:

```text
✓ What failed
✓ Where it failed
✓ When it failed
✓ Why it failed
✓ What caused the user-visible impact
✓ How the system recovered
✓ Whether data integrity was affected
✓ Whether the failure can recur
✓ Whether observability detected it
✓ Whether the architecture should change
```

The distinction is:

```text
Recovery
```

versus:

```text
Root Cause Understanding
```

Both are required for production-grade engineering.

---

# 74. Relationship to Incident Response

This document handles common technical symptoms.

For a confirmed operational incident, follow:

```text
docs/operations/incident-response.md
```

The incident-response process should use the evidence gathered through this troubleshooting guide.

The relationship is:

```text
Common Issue
     │
     ▼
Troubleshooting
     │
     ▼
Evidence
     │
     ▼
Incident Response
     │
     ▼
Recovery
     │
     ▼
Post-Incident Improvement
```

---

# 75. Relationship to Specialized Troubleshooting

This document is the general entry point.

For specialized problems, use:

```text
docs/troubleshooting/infrastructure-issues.md
docs/troubleshooting/deployment-issues.md
docs/troubleshooting/runtime-issues.md
```

Those documents should contain deeper procedures for their respective failure domains rather than duplicating this general guide.

---

# 76. Final Principle

The primary troubleshooting rule for Mini-Write is:

> **Observe first, classify second, change third.**

The intended operational behavior is:

```text
Symptom
   │
   ▼
Evidence
   │
   ▼
Failure Domain
   │
   ▼
Hypothesis
   │
   ▼
Verification
   │
   ▼
Controlled Action
   │
   ▼
Validation
   │
   ▼
Root Cause / Preventive Improvement
```

This preserves system state, reduces unnecessary changes, and turns troubleshooting from trial-and-error into a repeatable engineering process.

```
```
