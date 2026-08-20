# Deployment Issues

## 1. Purpose

This document provides troubleshooting procedures for failures occurring during or immediately after deployment of Mini-Write.

It focuses on the deployment lifecycle:

```text
Source
  │
  ▼
CI Validation
  │
  ▼
Deployment Trigger
  │
  ▼
Deployment Preparation
  │
  ▼
Runtime Configuration
  │
  ▼
Docker Compose
  │
  ▼
Container Startup
  │
  ▼
Health Verification
  │
  ▼
Deployment State Update
  │
  ▼
Operational Validation
````

The objective is not simply to make the deployment command succeed.

A deployment is considered successful only when:

* the intended version is actually deployed,
* required services are running,
* health checks pass,
* dependencies are reachable,
* observability confirms the resulting state,
* and deployment state accurately represents the deployed system.

This document complements:

* `docs/deployment/deployment.md`
* `docs/deployment/configuration.md`
* `docs/deployment/ci-cd.md`
* `docs/infrastructure/infrastructure-operations.md`
* `docs/troubleshooting/common-issues.md`
* `docs/troubleshooting/infrastructure-issues.md`
* `docs/troubleshooting/runtime-issues.md`

---

# 2. Deployment Troubleshooting Model

Deployment failures should be classified before corrective action.

```text
Deployment Failure
       │
       ├── CI / Validation
       │
       ├── Connectivity
       │
       ├── Configuration
       │
       ├── Artifact / Image
       │
       ├── Infrastructure
       │
       ├── Compose
       │
       ├── Container Startup
       │
       ├── Dependency Readiness
       │
       ├── Health Verification
       │
       ├── State Management
       │
       └── Post-Deployment Validation
```

A deployment failure should therefore be described as:

```text
Failure
→ Stage
→ Component
→ Evidence
→ Root Cause
→ Corrective Action
→ Validation
```

Avoid treating every failed deployment as a generic "Docker problem."

---

# 3. Deployment State Model

Deployment state tracks the relationship between the currently deployed and previously deployed versions.

The deployment state template is:

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

The conceptual model is:

```text
previous
   │
   │ deployment
   ▼
current
```

For example:

```text
previous:
  api:    version-A
  worker: version-A

current:
  api:    version-B
  worker: version-B
```

The exact version representation depends on the deployment mechanism.

The state file must describe the actual deployment state rather than the desired state alone.

---

# 4. First Response to a Failed Deployment

Do not immediately retry the deployment.

First establish:

```text
What deployment was attempted?
What version was intended?
What version was previously deployed?
Which component failed?
At which deployment stage did it fail?
Did the deployment modify the running system?
Is the system currently healthy?
```

Collect:

```bash
docker ps -a
docker images
docker compose ps
```

Inspect relevant logs:

```bash
docker compose logs --tail 200
```

Also inspect deployment logs under:

```text
/opt/deploy/logs/
```

The exact deployment command should follow the repository's deployment workflow.

---

# 5. Deployment Failed Before Any Runtime Change

This is the safest failure class.

Typical examples:

```text
CI validation failure
configuration validation failure
Ansible failure
image build failure
artifact retrieval failure
authentication failure
```

The desired state is normally still:

```text
previous deployment
```

Do not perform rollback operations if the deployment never changed the running system.

First establish whether any deployment mutation actually occurred.

---

# 6. Deployment Failed After Runtime Mutation

This is more serious.

Possible sequence:

```text
Old Version
    │
    ▼
Deployment starts
    │
    ▼
Some resources changed
    │
    ▼
Deployment fails
    │
    ▼
Mixed / partially deployed state
```

At this point, do not assume that the previous version remains fully operational.

Inspect:

```bash
docker compose ps
docker ps -a
```

Then determine:

```text
API version
Worker version
dependency state
container state
health state
deployment state
```

The objective is to establish the actual system state before deciding whether to continue, repair, or roll back.

---

# 7. CI Pipeline Fails Before Deployment

A CI failure should normally prevent deployment.

Typical failure categories:

```text
test failure
lint failure
build failure
configuration validation
workflow syntax
runner availability
dependency installation
```

The first question is:

> Did the deployment stage actually execute?

If not, deployment troubleshooting should not begin at Docker runtime.

Investigate the failed CI stage first.

---

# 8. Self-Hosted Runner Is Offline

The deployment pipeline depends on the configured self-hosted GitHub Actions runner.

If the runner is unavailable:

```text
GitHub Actions
      │
      ▼
Runner unavailable
      │
      ▼
Deployment cannot execute
```

Check the runner service on the host.

Inspect:

```bash
systemctl list-units --type=service | grep actions.runner
```

Then:

```bash
systemctl status <runner-service>
```

Inspect logs:

```bash
journalctl -u <runner-service> --since "30 minutes ago"
```

Runner troubleshooting is covered in greater detail in:

```text
docs/troubleshooting/infrastructure-issues.md
```

---

# 9. Deployment Cannot Connect to the Target Host

If deployment execution requires SSH or Ansible connectivity, validate connectivity before investigating application services.

Test the Ansible inventory:

```bash
ansible-inventory --graph
```

Then test connectivity:

```bash
ansible all -m ping
```

Classify the failure:

```text
Host unavailable
SSH unavailable
Authentication failure
Privilege escalation failure
Inventory error
Network failure
```

Do not modify application configuration until target-host connectivity is proven.

---

# 10. Ansible Deployment Task Fails

When an Ansible task fails, identify:

```text
play
role
task
target host
module
variable
changed state
error message
```

Use increased verbosity when the initial output is insufficient:

```bash
ansible-playbook ... -vv
```

or:

```bash
ansible-playbook ... -vvv
```

The correct response is to determine why the desired state could not be applied.

Do not blindly rerun the playbook until the cause is understood.

---

# 11. Ansible Fails Because of Existing State

Deployment automation may encounter state left behind by:

```text
previous deployment
manual modification
interrupted deployment
partial provisioning
configuration drift
```

Inspect the actual host state before changing it.

Examples:

```text
directory already exists
container already exists
network already exists
configuration differs
service already running
```

Existing state is not automatically an error.

The important question is whether the state conforms to the desired deployment state.

---

# 12. Deployment Configuration Is Missing

A deployment may fail because required configuration is absent.

Typical sources include:

```text
environment files
deployment templates
Compose configuration
Ansible variables
runtime configuration
secrets
```

The investigation should distinguish:

```text
missing
```

from:

```text
present but invalid
```

and:

```text
present but inconsistent with the selected deployment
```

Do not commit secrets into repository configuration merely to make a deployment succeed.

---

# 13. Environment Variable Is Missing

A missing environment variable can produce failures during:

```text
container startup
application initialization
database connection
Redis connection
MinIO connection
JWT configuration
observability initialization
```

Inspect the deployment configuration source and compare it with:

```text
docs/reference/environment-variables.md
```

The reference document should be treated as the authoritative documentation of expected configuration.

Do not expose secret values while collecting evidence.

Record only:

```text
variable name
present / absent
expected behavior
```

---

# 14. Environment Configuration Is Inconsistent

A deployment may contain all required variables but still fail because values are inconsistent.

Examples:

```text
API points to incorrect database host
Worker points to incorrect Redis host
API and Worker use incompatible queue configuration
observability endpoint differs from deployment network
```

Investigate configuration relationships rather than individual variables in isolation.

The relevant model is:

```text
Configuration
      │
      ├── API
      ├── Worker
      ├── PostgreSQL
      ├── Redis
      ├── MinIO
      └── Observability
```

---

# 15. Image Build Failure

If an image cannot be built, determine whether the failure is:

```text
dependency installation
Dockerfile
source code
network access
base image
build context
filesystem
resource exhaustion
```

Inspect the exact build error.

Do not modify the deployment runtime to compensate for a failed image build.

A failed build means the artifact required by the deployment does not yet exist in a usable form.

---

# 16. Image Pull or Retrieval Failure

If deployment depends on retrieving an image, investigate:

```text
registry connectivity
authentication
image name
tag
architecture
network availability
```

Verify the exact image reference expected by the deployment.

Do not replace a failed image reference with an arbitrary `latest` tag.

Version selection must remain deterministic.

---

# 17. Wrong Image Version Deployed

A deployment can technically succeed while deploying the wrong artifact.

Verify:

```bash
docker images
docker inspect <container>
```

Compare the running image with the intended deployment version.

The important distinction is:

```text
Deployment command succeeded
```

versus:

```text
Correct artifact is running
```

Only the second represents a successful deployment.

---

# 18. Container Starts With the Wrong Configuration

A container can use the correct image while receiving incorrect runtime configuration.

Symptoms include:

```text
application starts
but connects to wrong dependency
health checks fail
requests fail
worker cannot process jobs
```

Inspect the container configuration using Docker inspection facilities.

Do not expose sensitive environment values in logs or incident records.

---

# 19. Docker Compose Deployment Fails

If Compose fails, first distinguish:

```text
configuration parsing
```

from:

```text
resource creation
```

from:

```text
container startup
```

The failure stages are different:

```text
Compose file
    │
    ▼
Configuration parsing
    │
    ▼
Network / volume creation
    │
    ▼
Container creation
    │
    ▼
Container startup
    │
    ▼
Health
```

Investigate the first failed stage.

---

# 20. Compose Configuration Is Invalid

Validate the Compose configuration before changing running services.

The objective is to establish:

```text
syntax valid
service definitions valid
network definitions valid
volume definitions valid
environment references valid
```

A Compose parsing failure should normally be fixed before any runtime intervention.

---

# 21. Network Creation Fails During Deployment

If required Compose networks cannot be created:

```text
frontend-network
backend-network
```

inspect existing Docker networks.

```bash
docker network ls
```

Then:

```bash
docker network inspect <network>
```

Possible causes include:

```text
name conflict
network corruption
Docker daemon issue
partial previous deployment
configuration drift
```

Do not manually create alternative networks with unrelated names unless the architecture explicitly requires it.

---

# 22. Volume Creation or Mounting Fails

If a service fails because a volume cannot be mounted:

```text
container
   │
   ▼
volume
   │
   ▼
host filesystem
```

Investigate each layer.

Check:

```bash
docker volume ls
docker volume inspect <volume>
df -h
df -i
```

If persistent data is involved, do not delete the volume as a generic troubleshooting step.

---

# 23. API Fails to Start After Deployment

Inspect:

```bash
docker compose ps
docker compose logs --tail 300 api
```

Classify the failure:

```text
configuration
dependency initialization
database initialization
storage initialization
application startup
port binding
resource exhaustion
```

The API startup process includes initialization of:

```text
PostgreSQL-related state
Object Storage
HTTP server
metrics endpoint
```

Therefore an API startup failure may originate from a dependency.

---

# 24. Worker Fails to Start After Deployment

Inspect:

```bash
docker compose ps
docker compose logs --tail 300 worker
```

Classify:

```text
Redis connectivity
queue initialization
runtime initialization
configuration
application startup
resource exhaustion
```

Do not assume that a Worker startup failure is caused by the Worker application itself.

Redis and network availability must be checked first.

---

# 25. PostgreSQL Fails After Deployment

Inspect:

```bash
docker compose logs --tail 300 postgres
```

Then verify:

```text
container state
health state
volume
filesystem
network
configuration
```

A PostgreSQL startup failure should be treated as a high-impact dependency issue because API and Worker behavior may depend on it.

---

# 26. Redis Fails After Deployment

Inspect:

```bash
docker compose logs --tail 300 redis
```

Then verify:

```text
Redis container
volume
network
memory
configuration
```

Redis availability is particularly relevant to background job processing.

A Redis failure can therefore manifest as:

```text
API job enqueue failures
Worker processing failures
queue backlog
Worker unavailability
```

---

# 27. MinIO Fails After Deployment

Inspect:

```bash
docker compose logs --tail 300 minio
```

Verify:

```text
storage volume
filesystem
network
configuration
health
```

MinIO failure can propagate into:

```text
ID upload failure
Worker processing failure
storage latency
background job failure
```

---

# 28. API Is Running but Readiness Fails

A running container does not imply a ready application.

Mini-Write exposes:

```text
/health/live
/health/ready
```

Liveness answers:

```text
Is the service alive?
```

Readiness answers a stronger question:

```text
Can the service operate with its required dependencies?
```

If liveness passes but readiness fails:

```text
API process
   │
   ├── alive
   │
   └── dependency readiness failure
```

Investigate the dependency identified by the readiness response and application logs.

---

# 29. API Liveness Fails After Deployment

If:

```text
/health/live
```

fails, investigate the API process itself before investigating higher-level traffic routing.

Check:

```bash
docker compose ps api
docker compose logs --tail 300 api
```

Possible causes:

```text
process stopped
container restart loop
port issue
application startup failure
resource exhaustion
```

---

# 30. Worker Is Running but Jobs Are Not Processing

A successful container startup does not prove operational readiness.

Investigate:

```text
Redis
queue connectivity
queue depth
Worker logs
Worker concurrency
job failures
runtime failures
```

The operational model is:

```text
API
 │
 └── enqueue
       │
       ▼
     Redis
       │
       ▼
    Worker
       │
       ▼
  Job processing
```

A failure at any point can present as a Worker deployment problem.

---

# 31. Deployment Causes Queue Backlog

A deployment may temporarily or permanently affect Worker throughput.

Check:

```text
queue depth
jobs processed
job failures
job duration
Worker availability
Redis availability
```

If backlog increases immediately after deployment, correlate it with:

```text
Worker version
Worker startup
Worker concurrency
runtime configuration
dependency latency
```

Do not simply increase concurrency without understanding the resource impact.

---

# 32. Deployment Causes Increased API Error Rate

Use the API observability signals:

```text
mw_api_http_requests_total
mw_api_http_errors_total
mw_api_http_request_duration_seconds
```

Correlate error-rate changes with:

```text
deployment timestamp
API version
dependency health
host resources
application logs
```

The key question is:

> Did the deployment introduce the condition, or did the deployment coincide with an unrelated infrastructure failure?

Temporal correlation alone is not sufficient proof of causation.

---

# 33. Deployment Causes Increased Latency

Investigate:

```text
API p95 latency
Worker p95 job duration
database latency
storage latency
host CPU
host memory
queue depth
```

A deployment-related latency increase may result from:

```text
application behavior
resource contention
dependency degradation
configuration change
retry activity
```

Use observability data to identify the actual bottleneck.

---

# 34. Health Checks Pass but Deployment Is Still Incorrect

Health checks are necessary but not sufficient.

A deployment may satisfy:

```text
container running
health check passing
```

while still having:

```text
wrong version
wrong configuration
missing functionality
incorrect routing
incorrect deployment state
```

Therefore post-deployment validation should include both:

```text
technical health
```

and:

```text
deployment correctness
```

---

# 35. Deployment State Was Not Updated

If deployment completed but the deployment state remains unchanged, investigate the state-update stage.

The state should represent:

```text
current = actually deployed version
previous = version displaced by the deployment
```

Do not manually update the file merely to make it appear consistent.

First establish whether the deployment itself actually completed successfully.

---

# 36. Deployment State Says Current but Runtime Is Different

This is a state-integrity problem.

Example:

```text
deployment_state.json
  current.api = version-B
```

while the running API actually uses:

```text
version-A
```

The state file is now misleading.

Treat this as deployment-state drift.

Correct sequence:

```text
Actual runtime
      │
      ▼
Determine actual deployed version
      │
      ▼
Determine deployment history
      │
      ▼
Reconcile state
      │
      ▼
Validate
```

Never overwrite state based only on the intended deployment target.

---

# 37. Partial API / Worker Deployment

Mini-Write tracks API and Worker independently in deployment state.

Therefore a deployment can produce:

```text
API    → new version
Worker → previous version
```

or:

```text
API    → previous version
Worker → new version
```

This is not automatically an error.

The important question is whether the resulting combination is architecturally compatible.

If compatibility is not established, treat the system as a potentially inconsistent deployment state.

---

# 38. API Updated but Worker Failed

Example:

```text
API    → version-B
Worker → version-A
```

First determine:

```text
Is API operational?
Is Worker operational?
Can API enqueue jobs?
Can Worker process existing jobs?
Are queue/job contracts compatible?
```

If compatibility is uncertain, do not continue deploying unrelated changes.

The recovery decision should be based on the known compatibility boundary.

---

# 39. Worker Updated but API Failed

Example:

```text
API    → version-A
Worker → version-B
```

Investigate whether Worker version-B is compatible with the API still serving version-A.

If not, restore a consistent deployment state.

The principle is:

> A deployment is a system-level state transition, not merely a collection of independent container updates.

---

# 40. Deployment Interrupted

An interrupted deployment can leave:

```text
old containers
new containers
new images
old images
partial configuration
partial state updates
```

Do not immediately repeat the deployment.

First collect:

```bash
docker compose ps
docker ps -a
docker images
```

Then inspect:

```text
deployment logs
container logs
deployment state
```

The objective is to determine exactly how far the deployment progressed.

---

# 41. Deployment Command Was Interrupted During Container Replacement

If the deployment was interrupted during service replacement:

```text
old service
   │
   ▼
replacement starts
   │
   X interruption
```

the resulting runtime may be neither the old nor new intended state.

Validate:

```text
API
Worker
dependencies
networks
volumes
health
```

Then choose one controlled recovery path:

```text
complete deployment
```

or:

```text
restore previous known-good deployment
```

Avoid repeatedly alternating between versions.

---

# 42. Deployment Succeeds but Old Containers Remain

Inspect:

```bash
docker ps -a
```

Determine whether old containers are:

```text
obsolete
required
part of another Compose project
```

Do not remove containers solely because they look old.

First establish ownership and whether they belong to the active deployment.

---

# 43. Deployment Leaves Orphaned Resources

Possible leftovers include:

```text
containers
networks
images
volumes
```

Orphaned resources should be investigated before cleanup.

The question is:

```text
Is this resource unused?
```

not:

```text
Is this resource old?
```

This distinction protects persistent state.

---

# 44. Deployment Causes Port Conflict

A new container may fail because a previous process or container owns the required port.

Inspect:

```bash
sudo ss -lntp
docker ps
```

Then determine:

```text
who owns the port
why it owns the port
whether it belongs to the current deployment
```

Do not kill processes blindly.

---

# 45. Deployment Causes Network Conflict

If a Compose network cannot be created or attached:

```text
docker network ls
docker network inspect <network>
```

Check for:

```text
name collision
stale network
incorrect Compose project
manual network
```

The recovery should restore the architecture defined by the deployment configuration.

---

# 46. Deployment Causes Volume Conflict

A volume conflict requires special care.

Determine:

```text
volume name
volume owner
mount point
data type
persistent importance
```

Never execute volume deletion as a generic deployment cleanup action.

For databases and object storage, a volume may contain the primary persistent state of the system.

---

# 47. Deployment Fails Because of Disk Space

Check:

```bash
df -h
df -i
docker system df
```

Potential consumers:

```text
Docker images
container logs
deployment artifacts
database data
object storage
Prometheus data
Loki data
```

The recovery should preserve required persistent state.

Do not use destructive pruning until the data-retention implications are understood.

---

# 48. Deployment Fails Because of Memory

Check:

```bash
free -h
docker stats
```

Possible causes:

```text
image build
container startup
database startup
Worker processing
observability services
```

If memory pressure is caused by Worker concurrency or workload, address the workload rather than treating the deployment system itself as defective.

---

# 49. Deployment Fails Because of Configuration Drift

If the host was manually modified after provisioning, deployment may encounter unexpected state.

Examples:

```text
manual Docker changes
manual firewall changes
manual files under /opt/deploy
manual service configuration
manual containers
```

Compare:

```text
desired infrastructure state
```

with:

```text
actual host state
```

Use Ansible to reconcile managed infrastructure where appropriate.

---

# 50. Deployment Succeeds but Observability Is Missing

A deployment is not fully validated if observability cannot confirm the resulting state.

Check:

```text
Prometheus
Loki
Promtail
Grafana
Alertmanager
exporters
```

For API and Worker specifically, verify:

```text
metrics endpoint
service scrape target
logs
health state
```

Observability failures should be separated from application failures.

For example:

```text
API healthy
Prometheus cannot scrape API
```

means:

```text
application healthy
observability path unhealthy
```

not necessarily:

```text
API unhealthy
```

---

# 51. Deployment Succeeds but Alerts Appear

Alerts immediately after deployment may indicate:

```text
real regression
expected transient behavior
deployment-induced resource pressure
stale alert
observability configuration problem
```

Correlate:

```text
alert timestamp
deployment timestamp
service version
metrics
logs
health checks
```

Do not automatically suppress the alert merely because a deployment occurred.

---

# 52. Deployment Rollback Decision

Rollback should be considered when:

```text
new version causes confirmed service degradation
recovery is faster through the previous known-good version
current state cannot be stabilized safely
```

Rollback should not be automatic merely because:

```text
a deployment step failed
```

if the running system remains healthy and the failed step can be safely corrected.

---

# 53. Rollback Preconditions

Before rollback, establish:

```text
previous version is known
previous artifact is available
previous configuration is available
persistent data compatibility is understood
API/Worker compatibility is understood
rollback will not destroy state
```

A rollback is itself a deployment.

Therefore it must be treated as a controlled state transition.

---

# 54. Rollback Validation

After rollback:

```text
[ ] Previous API version is running
[ ] Previous Worker version is running
[ ] Required dependencies are healthy
[ ] API liveness passes
[ ] API readiness passes
[ ] Worker is operational
[ ] Queue processing resumes
[ ] Metrics are available
[ ] Logs are available
[ ] No new critical alerts
[ ] Deployment state reflects reality
```

Rollback is incomplete until the resulting system is operationally validated.

---

# 55. Do Not Roll Back Persistent Data Blindly

Application artifacts and persistent data do not necessarily have symmetrical rollback semantics.

For example:

```text
Application version
       ↓
Database schema
       ↓
Persistent data
```

A newer deployment may have changed persistent state in a way that cannot safely be reversed by merely restoring an older container image.

Therefore:

> Never assume that application rollback implies data rollback.

Database migration compatibility must be considered explicitly.

---

# 56. Deployment Verification

A successful deployment should be verified across multiple dimensions.

## 56.1 Artifact

```text
Correct version deployed
```

## 56.2 Runtime

```text
Containers running
```

## 56.3 Health

```text
Liveness passing
Readiness passing
```

## 56.4 Dependencies

```text
PostgreSQL healthy
Redis healthy
MinIO healthy
```

## 56.5 Workflow

```text
API requests succeed
Jobs enqueue
Worker processes jobs
```

## 56.6 Observability

```text
Metrics available
Logs available
Alerts operational
```

## 56.7 State

```text
Deployment state matches runtime
```

---

# 57. Post-Deployment Smoke Validation

At minimum, validate:

```text
API availability
API liveness
API readiness
authentication path
ID upload path where appropriate
job enqueue path
Worker processing
metrics endpoint
logs
```

The exact smoke-test commands belong to the deployment and testing procedures.

The important principle is that validation must cross service boundaries.

---

# 58. Deployment Verification Matrix

| Layer      | Validation                          |
| ---------- | ----------------------------------- |
| Artifact   | Correct image/version               |
| Host       | Reachable and healthy               |
| Docker     | Engine operational                  |
| Network    | Required networks available         |
| Volumes    | Required persistent volumes mounted |
| API        | Running                             |
| Worker     | Running                             |
| PostgreSQL | Healthy                             |
| Redis      | Healthy                             |
| MinIO      | Healthy                             |
| Liveness   | Passing                             |
| Readiness  | Passing                             |
| Metrics    | Scrapeable                          |
| Logs       | Available                           |
| Alerts     | No unexpected critical alerts       |
| State      | Current/previous state accurate     |

---

# 59. Deployment Failure Severity

Deployment failures can be classified as follows.

## Level 1 — Pre-Deployment Failure

The deployment did not modify the running system.

Examples:

```text
CI failure
build failure
validation failure
runner failure
```

Risk:

```text
low
```

---

## Level 2 — Partial Deployment With Healthy Runtime

Some deployment actions occurred, but the production/staging runtime remains healthy.

Examples:

```text
image updated
unused resource created
state update failed
```

Risk:

```text
moderate
```

---

## Level 3 — Partial Deployment With Degraded Runtime

The system is running but functionality is impaired.

Examples:

```text
API degraded
Worker degraded
queue backlog
dependency unavailable
```

Risk:

```text
high
```

---

## Level 4 — Deployment-Induced Outage

The deployment causes a significant service outage.

Examples:

```text
API unavailable
Worker unavailable
critical dependency unavailable
```

Risk:

```text
critical
```

At this point, incident-response procedures should be activated.

---

# 60. Deployment Troubleshooting Decision Tree

```text
Deployment failed
       │
       ▼
Did deployment execute?
       │
   ┌───┴───┐
  No       Yes
  │         │
CI/runner   ▼
issue     Did runtime change?
             │
         ┌───┴───┐
        No       Yes
        │         │
   Pre-deploy     ▼
   failure     Is runtime healthy?
                   │
               ┌───┴───┐
              Yes      No
               │        │
               ▼        ▼
          State/config  Incident
          reconciliation response
               │        │
               └────┬───┘
                    ▼
             Determine actual
             deployed versions
                    │
                    ▼
             Validate API/Worker
                    │
                    ▼
             Validate dependencies
                    │
                    ▼
             Validate observability
                    │
                    ▼
             Validate deployment state
```

---

# 61. Common Deployment Anti-Patterns

## 61.1 Blind Retry

```text
deployment fails
     ↓
run deployment again
     ↓
fails again
     ↓
run again
```

This can hide the actual failure and increase state divergence.

---

## 61.2 Restart Everything

```text
docker compose restart
```

may temporarily hide symptoms without addressing the root cause.

Use restarts only when evidence supports them.

---

## 61.3 Delete Volumes

Deleting volumes is one of the highest-risk deployment troubleshooting actions.

Never use it as a generic recovery mechanism.

---

## 61.4 Disable Health Checks

Health checks are evidence.

Removing them makes the system less observable and can hide real failures.

---

## 61.5 Disable Firewall

Turning off UFW may appear to solve connectivity problems while creating a security regression.

Identify the actual traffic path instead.

---

## 61.6 Deploy `latest`

Using an ambiguous image tag makes deployment state less deterministic.

Deployments should use explicit, traceable versions.

---

## 61.7 Manually Edit Deployment State

Changing `deployment_state.json` without reconciling runtime state creates false operational information.

The state file should reflect reality.

---

## 61.8 Fix the Host Manually and Forget Automation

A manual fix can restore service but leave infrastructure drift.

The permanent correction should be represented in:

```text
Ansible
Docker Compose
deployment configuration
or another authoritative source
```

---

# 62. Evidence Preservation

For failed or degraded deployments, preserve:

```text
Deployment identifier:
Requested version:
Previous version:
Current runtime version:
Deployment timestamp:
Failure timestamp:
Failed stage:
CI logs:
Ansible output:
Compose output:
Container status:
Container logs:
Health results:
Prometheus metrics:
Loki logs:
Deployment state:
Infrastructure changes:
Recovery actions:
```

Do not include:

```text
passwords
tokens
private keys
secret values
```

---

# 63. Root Cause Analysis

A deployment incident should distinguish:

```text
Trigger
```

from:

```text
Root Cause
```

Example:

```text
Trigger:
API became unavailable after deployment.

Intermediate failure:
API container entered restart loop.

Root cause:
Invalid runtime configuration caused startup failure.
```

The root cause is not:

```text
"API was down."
```

That is the impact.

---

# 64. Deployment Corrective Action

Corrective actions should operate at the appropriate layer.

```text
Wrong artifact
    → CI/CD or artifact selection

Wrong configuration
    → deployment configuration

Infrastructure drift
    → Ansible

Compose topology error
    → Docker Compose configuration

Application startup defect
    → application/runtime implementation

Missing validation
    → CI/CD or deployment verification

Incorrect state tracking
    → deployment state mechanism
```

This prevents operational workarounds from becoming permanent architecture.

---

# 65. Deployment Incident Closure Criteria

A deployment incident can be closed only when:

```text
[ ] Root cause identified
[ ] Runtime restored
[ ] Correct versions verified
[ ] API validated
[ ] Worker validated
[ ] Dependencies validated
[ ] Observability validated
[ ] Deployment state reconciled
[ ] No unexpected critical alerts
[ ] Corrective action identified
[ ] Permanent fix represented in source of truth
```

---

# 66. Final Deployment Principle

A deployment is a controlled transition:

```text
Known Good State
       │
       ▼
Deployment
       │
       ▼
New State
       │
       ▼
Verification
       │
       ├── Healthy → Accept
       │
       └── Unhealthy
              │
              ├── Repair
              │
              └── Rollback
```

The essential operational rule is:

> **Never infer deployment success from command completion alone. Verify the resulting system state.**

The deployment system must therefore maintain a consistent relationship between:

```text
Source
  ↓
Artifact
  ↓
Configuration
  ↓
Infrastructure
  ↓
Runtime
  ↓
Health
  ↓
Observability
  ↓
Deployment State
```

A deployment is successful only when these layers agree about what is running and the resulting system is operationally healthy.

```
```
