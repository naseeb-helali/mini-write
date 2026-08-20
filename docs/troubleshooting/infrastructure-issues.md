# Infrastructure Issues

## 1. Purpose

This document provides infrastructure-focused troubleshooting procedures for Mini-Write.

It covers failures originating in or propagated through the infrastructure layer, including:

- Host availability
- Operating system state
- Docker Engine
- Docker networking
- Container runtime
- Persistent storage
- UFW firewall
- SSH hardening
- Ansible-managed infrastructure
- GitHub Actions self-hosted runner
- Infrastructure resource exhaustion
- Infrastructure observability exporters

This document intentionally does not replace:

- `docs/troubleshooting/common-issues.md` — general troubleshooting entry point
- `docs/troubleshooting/deployment-issues.md` — deployment-specific failures
- `docs/troubleshooting/runtime-issues.md` — Runtime-specific failures
- `docs/operations/incident-response.md` — incident-management procedure

---

# 2. Infrastructure Troubleshooting Model

Mini-Write infrastructure is layered.

```text
Physical / Virtual Host
        │
        ▼
Operating System
        │
        ├── Filesystem
        ├── Memory
        ├── CPU
        ├── Network
        ├── SSH
        └── Firewall
        │
        ▼
Docker Engine
        │
        ├── Networks
        ├── Volumes
        ├── Images
        └── Containers
        │
        ▼
Application Infrastructure
        │
        ├── API
        ├── Worker
        ├── PostgreSQL
        ├── Redis
        └── MinIO
        │
        ▼
Observability Infrastructure
        │
        ├── Prometheus
        ├── Loki
        ├── Promtail
        ├── Grafana
        ├── Alertmanager
        └── Exporters
````

Troubleshooting should normally proceed from the lower layers upward.

A failure at a lower layer can invalidate all higher-layer observations.

For example:

```text
Host filesystem full
       │
       ▼
Docker cannot write
       │
       ▼
Container fails
       │
       ▼
API unavailable
       │
       ▼
Gateway returns 502/503
```

Therefore, an API failure does not necessarily imply an API defect.

---

# 3. Infrastructure Evidence Collection

Before modifying infrastructure, collect the current state.

At minimum:

```text
Host:
Docker:
Networks:
Containers:
Volumes:
Filesystem:
Memory:
CPU:
Firewall:
SSH:
Ansible state:
Runner state:
Recent deployment:
```

Useful commands include:

```bash
hostname
uptime
df -h
free -h
docker info
docker ps -a
docker network ls
docker volume ls
```

For a serious incident, preserve this evidence before performing destructive actions.

---

# 4. Host Is Unreachable

## 4.1 Symptoms

Typical symptoms:

```text
SSH unavailable
API unavailable
Worker unavailable
Prometheus unavailable
all containers appear unavailable
```

## 4.2 First Classification

Determine whether the problem is:

```text
VM unavailable
        │
        ├── network unreachable
        ├── operating system unavailable
        └── SSH unavailable
```

If the host itself cannot be reached, container-level troubleshooting is premature.

## 4.3 Investigation

Verify the VM state through the local virtualization environment.

If the VM is running, verify network connectivity from the client.

Then investigate SSH.

The key distinction is:

```text
Host unreachable
```

versus:

```text
Host reachable but SSH unavailable
```

These are different failure domains.

---

# 5. SSH Unavailable

## 5.1 Symptoms

The host is running but SSH connections fail.

Possible causes:

```text
sshd stopped
firewall blocking SSH
incorrect SSH configuration
authentication failure
network configuration
```

## 5.2 Investigation

If console access is available:

```bash
systemctl status ssh
```

Validate the SSH daemon configuration:

```bash
sudo sshd -t
```

Inspect the generated hardening configuration:

```bash
sudo cat /etc/ssh/sshd_config.d/99-miniwrite-hardening.conf
```

Check firewall state:

```bash
sudo ufw status
```

Check listening sockets:

```bash
sudo ss -lntp
```

The investigation should establish whether the failure occurs at:

```text
Network
   │
   ▼
Firewall
   │
   ▼
sshd
   │
   ▼
Authentication
```

---

# 6. SSH Hardening Causes Access Failure

Mini-Write applies SSH hardening through Ansible.

The security baseline controls settings including:

```text
PasswordAuthentication
PermitRootLogin
PubkeyAuthentication
PermitEmptyPasswords
```

If SSH access fails after infrastructure provisioning:

1. Do not immediately weaken SSH security.
2. Obtain console access if available.
3. Validate `sshd` syntax.
4. Inspect the generated configuration.
5. Verify authentication method.
6. Verify firewall rules.
7. Correct the intended infrastructure configuration.

The correct recovery principle is:

> Restore the intended secure configuration rather than bypassing the security baseline.

---

# 7. Docker Engine Is Unavailable

## 7.1 Symptoms

Examples:

```text
docker ps fails
containers disappear
Compose commands fail
multiple services unavailable
```

Check:

```bash
systemctl status docker
```

Then:

```bash
systemctl is-active docker
```

If Docker is inactive:

```bash
sudo systemctl start docker
```

Do not restart Docker repeatedly without checking the reason for failure.

Inspect recent service logs:

```bash
journalctl -u docker --since "30 minutes ago"
```

---

# 8. Docker Daemon Starts but Containers Cannot Run

Investigate:

```bash
docker info
```

Then inspect:

```bash
docker ps -a
```

Check for:

```text
storage driver errors
filesystem problems
network initialization errors
permission errors
resource exhaustion
```

Also inspect:

```bash
df -h
df -i
free -h
```

A Docker failure caused by filesystem exhaustion must be resolved at the host layer.

---

# 9. Docker Storage Exhaustion

Docker can consume significant storage through:

```text
images
containers
container logs
volumes
build cache
```

Inspect usage:

```bash
docker system df
```

For more detail:

```bash
docker system df -v
```

Do not immediately execute:

```bash
docker system prune -a
```

because aggressive pruning can remove images required for recovery and may increase deployment time.

First identify what is consuming space.

---

# 10. Host Filesystem Is Full

Check:

```bash
df -h
```

Also check inode exhaustion:

```bash
df -i
```

A filesystem can report sufficient bytes while having no free inodes.

If a filesystem is full, identify the source:

```bash
sudo du -xhd1 / 2>/dev/null | sort -h
```

Then inspect relevant directories.

Typical candidates include:

```text
/var/lib/docker
/opt/deploy
/var/log
```

Persistent application data requires additional care.

Do not delete database, Redis, MinIO, Prometheus, or Loki data as a generic cleanup operation.

---

# 11. Docker Container Is Stopped

Inspect:

```bash
docker ps -a
```

For the affected container:

```bash
docker inspect <container>
```

Inspect logs:

```bash
docker logs --tail 200 <container>
```

Classify the stop reason:

```text
application exit
configuration error
dependency failure
health failure
resource exhaustion
manual stop
Docker failure
```

The correct action depends on this classification.

---

# 12. Container Restart Loop

A restart loop generally indicates:

```text
Container starts
      │
      ▼
Initialization
      │
      ▼
Failure
      │
      ▼
Process exits
      │
      ▼
Restart policy
      │
      └──────────► Start again
```

Investigate:

```bash
docker inspect <container>
docker logs --tail 300 <container>
```

Do not disable the restart policy merely to make the container remain stopped.

The restart policy is often correctly exposing a persistent startup failure.

---

# 13. Container Health Is Unhealthy

A container can be:

```text
running
```

while being:

```text
unhealthy
```

Inspect:

```bash
docker inspect <container>
```

Look at:

```text
State
Health
Healthcheck
```

The correct investigation sequence is:

```text
Container running?
      │
      ▼
Health check passing?
      │
      ▼
Health check command valid?
      │
      ▼
Application dependency healthy?
```

Do not remove health checks merely because they report a failure.

---

# 14. Docker Network Does Not Exist

List networks:

```bash
docker network ls
```

The Mini-Write architecture uses:

```text
frontend-network
backend-network
```

If a required network is missing, determine why.

Possible causes:

```text
Compose stack not deployed
network manually removed
deployment partially failed
Compose project changed
```

The preferred recovery is to restore the network through the deployment mechanism rather than manually constructing a permanent alternative.

---

# 15. Container Cannot Reach Another Container

Inspect network membership:

```bash
docker network inspect <network>
```

Verify that both services belong to the expected network.

The intended application topology is:

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
   ├── Worker
   ├── PostgreSQL
   ├── Redis
   └── MinIO
```

If API cannot reach PostgreSQL, for example, verify:

```text
API ∈ backend-network
PostgreSQL ∈ backend-network
PostgreSQL service name
PostgreSQL listening port
```

Do not replace Docker DNS names with container IP addresses.

---

# 16. Docker DNS Resolution Failure

Docker Compose service discovery relies on service names.

Examples:

```text
postgres
redis
storage
worker
api
```

From the affected container, test DNS resolution where appropriate.

For example:

```bash
docker exec <api-container> getent hosts postgres
```

If DNS resolution fails:

```text
1. Check network membership.
2. Check service name.
3. Check Docker network state.
4. Check Docker daemon.
```

Container IP addresses should not become application configuration.

---

# 17. Port Binding Conflict

A service may fail to start because another process already occupies the required host port.

Inspect listening ports:

```bash
sudo ss -lntp
```

For Docker mappings:

```bash
docker ps
```

Look for conflicts such as:

```text
host_port -> container_port
```

Do not change exposed ports arbitrarily.

First determine which service owns the conflicting port and whether the conflict represents configuration drift.

---

# 18. UFW Blocks Required Traffic

Check:

```bash
sudo ufw status verbose
```

The security baseline uses:

```text
default deny incoming
default allow outgoing
```

Required ports are explicitly allowed.

If a service is unreachable:

```text
Client
  │
  ▼
Host firewall
  │
  ▼
Docker
  │
  ▼
Container
```

Determine where the connection is blocked.

Do not disable UFW globally as a diagnostic shortcut.

---

# 19. Docker Traffic and UFW

Docker networking has its own packet-filtering behavior.

Therefore:

> A UFW rule and Docker-published port are not necessarily equivalent from a packet-routing perspective.

When investigating firewall-related Docker connectivity:

```text
1. Identify the traffic path.
2. Determine whether traffic is host-local or externally exposed.
3. Check UFW rules.
4. Check Docker port publishing.
5. Check container network membership.
```

Avoid introducing broad firewall exceptions without understanding the resulting exposure.

---

# 20. CPU Saturation

Check:

```bash
top
```

or:

```bash
htop
```

Then inspect Docker usage:

```bash
docker stats
```

Correlate host CPU with:

```text
API traffic
Worker processing
queue depth
retry activity
database activity
observability queries
```

High CPU can originate from:

```text
application workload
Worker processing
retry amplification
database activity
Prometheus
Loki
Grafana queries
```

Do not assume the container consuming CPU is necessarily the root cause.

---

# 21. Memory Pressure

Check:

```bash
free -h
```

Then:

```bash
docker stats
```

Look for:

```text
memory growth
OOM events
container restarts
swap activity
```

Check kernel messages where appropriate:

```bash
dmesg | grep -i -E 'oom|out of memory'
```

Sustained memory pressure should be investigated as a capacity or application behavior problem, not simply solved by repeated restarts.

---

# 22. OOM Kill

If a container repeatedly disappears or restarts, check whether it was killed because of memory exhaustion.

Inspect:

```bash
docker inspect <container>
```

and host logs:

```bash
dmesg | grep -i oom
```

Possible remediation:

```text
increase available host memory
reduce workload
fix memory leak
adjust container resource policy
reduce concurrency
```

The correct remediation depends on the evidence.

---

# 23. High Worker Resource Usage

Worker resource usage can increase with:

```text
queue backlog
job concurrency
large files
image-processing workload
retry storms
storage latency
```

Correlate:

```text
CPU
memory
jobs_active
queue_depth
job_duration
job_failures
```

Reducing Worker concurrency may be appropriate when host saturation is proven.

However, it should be treated as a controlled capacity decision rather than an arbitrary fix.

---

# 24. PostgreSQL Container Is Unhealthy

Check:

```bash
docker ps
docker inspect <postgres-container>
docker logs --tail 300 <postgres-container>
```

The PostgreSQL health check uses `pg_isready`.

Investigate:

```text
database process
database configuration
credentials
filesystem
memory
disk
network
```

If the database cannot start because the filesystem is full, the root cause is infrastructure capacity rather than PostgreSQL configuration.

---

# 25. Redis Container Is Unhealthy

Check:

```bash
docker logs --tail 200 <redis-container>
```

Verify:

```text
Redis process
persistent volume
memory
network
configuration
```

Then verify the health endpoint from the container environment where appropriate:

```bash
docker exec <redis-container> redis-cli ping
```

Expected:

```text
PONG
```

---

# 26. MinIO Container Is Unhealthy

Inspect:

```bash
docker logs --tail 200 <minio-container>
docker inspect <minio-container>
```

The MinIO health endpoint is:

```text
/minio/health/live
```

Investigate:

```text
process
storage path
persistent volume
disk capacity
permissions
network
credentials
```

Do not delete the MinIO volume as a troubleshooting shortcut.

---

# 27. Persistent Volume Problem

List volumes:

```bash
docker volume ls
```

Inspect a volume:

```bash
docker volume inspect <volume>
```

Mini-Write uses persistent state for services including:

```text
PostgreSQL
Redis
MinIO
Prometheus
Loki
Grafana
Alertmanager
```

Persistent volume troubleshooting must answer:

```text
Is the volume mounted?
Is the expected data present?
Is the filesystem writable?
Is the data required for recovery?
```

Deleting a persistent volume is a destructive recovery operation.

---

# 28. Volume Mount Permission Failure

A service may start but fail to write to a mounted directory.

Investigate:

```bash
docker inspect <container>
```

Determine:

```text
host path
container path
UID/GID
filesystem permissions
read-only/read-write mode
```

Then inspect the host path.

Avoid changing permissions to `777` as a generic fix.

The correct permissions should match the service's intended security model.

---

# 29. Deployment Directory Problems

Mini-Write deployment state is under:

```text
/opt/deploy
```

Important areas include:

```text
/opt/deploy/compose
/opt/deploy/env
/opt/deploy/state
/opt/deploy/logs
```

If deployment infrastructure behaves unexpectedly, verify:

```bash
sudo find /opt/deploy -maxdepth 2 -type d
```

and inspect relevant files.

Changes to `/opt/deploy` should preferably be produced by Ansible or the deployment workflow.

---

# 30. Deployment State File Is Missing

The deployment state file is:

```text
/opt/deploy/state/deployment_state.json
```

Its structure tracks:

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

If the state file is missing or malformed:

1. Determine whether deployment initialization completed.
2. Inspect Ansible execution.
3. Inspect deployment logs.
4. Verify the state directory.
5. Restore state through the intended automation path.

Do not invent version values manually.

Deployment state is operational data and must correspond to actual deployed versions.

---

# 31. Ansible Cannot Connect to Host

Verify inventory configuration first.

Typical checks:

```bash
ansible-inventory --graph
```

Then test connectivity:

```bash
ansible all -m ping
```

If the connection fails, classify it:

```text
DNS/IP problem
SSH problem
authentication problem
privilege escalation problem
host unavailable
```

Do not modify the playbook before proving that the target host itself is reachable.

---

# 32. Ansible Privilege Escalation Failure

If tasks requiring elevated privileges fail, investigate:

```text
become configuration
sudo availability
target user privileges
sudo policy
```

The failure may appear as:

```text
permission denied
sudo password required
become failed
```

Do not solve this by running every Ansible task as root without understanding the intended privilege boundary.

---

# 33. Ansible Role Fails

The infrastructure is organized into roles such as:

```text
base
docker
deploy_runtime
github_runner
security_baseline
```

When a role fails, identify:

```text
role
task
target
variable
current host state
```

Use verbose output when required:

```bash
ansible-playbook ... -vv
```

For deeper diagnosis:

```bash
ansible-playbook ... -vvv
```

Verbosity should be increased when evidence is insufficient, not by default for every execution.

---

# 34. Ansible Idempotency Problem

A properly designed infrastructure role should converge toward the intended state.

If running the playbook repeatedly continues to report changes:

```text
first run → changed
second run → changed
third run → changed
```

investigate the task causing repeated mutation.

Common causes:

```text
unstable generated content
incorrect file ownership
timestamp-dependent templates
command-based tasks without idempotency
service state not modeled
```

Do not simply ignore repeated changes.

Persistent non-idempotency indicates infrastructure drift or automation design weakness.

---

# 35. Docker Installation Is Incomplete

The Docker role establishes:

```text
Docker Engine
Docker service
deployment user access
```

If Docker is installed but inaccessible:

```bash
docker --version
docker info
```

Then inspect group membership:

```bash
id -nG <deploy-user>
```

If the `docker` group is missing, investigate the Ansible Docker role.

A new login may be required after group membership changes.

---

# 36. GitHub Actions Runner Is Offline

The self-hosted runner depends on:

```text
Host
 │
 ├── Docker
 ├── Network
 └── systemd
       │
       ▼
GitHub Actions Runner
```

Check the runner service:

```bash
systemctl list-units --type=service | grep actions.runner
```

Then:

```bash
systemctl status <runner-service>
```

Inspect service logs:

```bash
journalctl -u <runner-service> --since "30 minutes ago"
```

Classify:

```text
service stopped
registration problem
network problem
authentication/token problem
filesystem problem
permission problem
```

---

# 37. Runner Service Starts but Cannot Execute Jobs

Investigate:

```text
runner user
docker group membership
working directory
Docker availability
network connectivity
GitHub connectivity
```

The runner needs the permissions necessary to execute the repository's CI/CD workflow.

Do not grant unrestricted privileges beyond what the runner requires.

---

# 38. Runner Cannot Access Docker

Check:

```bash
docker info
```

as the runner user.

Then:

```bash
id -nG <runner-user>
```

The runner user is expected to have the required Docker access through group membership.

If Docker works for an administrator but not the runner:

```text
administrator context
        │
        ▼
Docker works

runner context
        │
        ▼
Docker denied
```

This is usually a user/group/permission boundary issue rather than a Docker daemon issue.

---

# 39. Node Exporter Is Down

The infrastructure alert:

```text
MWNodeExporterDown
```

means Prometheus cannot scrape:

```text
node-exporter:9100
```

Investigate:

```bash
docker ps -a
docker logs --tail 200 <node-exporter-container>
```

Then verify:

```text
container running
port 9100
network membership
Prometheus target
```

If Node Exporter is down, host observability is degraded even if the application remains healthy.

---

# 40. cAdvisor Is Down

cAdvisor provides container-level metrics.

If its target is unavailable:

```text
container resource visibility
```

may be lost even though:

```text
node-exporter
```

continues to work.

Investigate:

```text
cAdvisor container
Docker socket access
filesystem mounts
Prometheus target
```

Do not confuse cAdvisor failure with Docker failure.

Docker may continue operating normally.

---

# 41. Redis Exporter Is Down

Redis itself can remain healthy while its exporter fails.

Distinguish:

```text
Redis service health
```

from:

```text
Redis observability health
```

Check:

```text
redis
redis-exporter
Prometheus target
```

A missing exporter affects visibility, not necessarily Redis availability.

---

# 42. PostgreSQL Exporter Is Down

Similarly:

```text
PostgreSQL healthy
```

does not imply:

```text
PostgreSQL metrics available
```

Check:

```text
postgres
postgres-exporter
Prometheus target
```

Investigate exporter credentials and network access before modifying PostgreSQL itself.

---

# 43. Prometheus Cannot Scrape Infrastructure Targets

Inspect Prometheus targets through the Prometheus UI.

Expected targets include:

```text
prometheus
api
worker
redis
postgres
node
cadvisor
loki
alertmanager
```

If one target is down:

```text
1. Check target container.
2. Check target port.
3. Check Docker network.
4. Check metrics endpoint.
5. Check Prometheus configuration.
```

If all targets fail simultaneously, investigate Prometheus, Docker networking, or the host before individual exporters.

---

# 44. Loki Cannot Be Reached

Check:

```bash
docker ps -a
docker logs --tail 200 <loki-container>
```

Verify the configured port:

```text
3100
```

Promtail sends logs to:

```text
http://loki:3100/loki/api/v1/push
```

Therefore investigate:

```text
Loki running
       │
       ▼
backend network
       │
       ▼
DNS resolution
       │
       ▼
port 3100
```

---

# 45. Promtail Cannot Send Logs

Check:

```bash
docker logs --tail 200 <promtail-container>
```

Then verify:

```text
Docker log files accessible
Promtail positions file
Loki reachable
Promtail configuration valid
```

The Docker log path is:

```text
/var/lib/docker/containers/*/*-json.log
```

Promtail also collects deployment logs from:

```text
/opt/deploy/logs/*.log
```

Missing logs may therefore originate from either source.

---

# 46. Grafana Infrastructure Problem

If Grafana is unavailable:

```bash
docker ps -a
docker logs --tail 200 <grafana-container>
```

Then verify:

```text
port
container state
datasource configuration
dashboard provisioning
filesystem permissions
```

Grafana failure does not necessarily mean that observability data is lost.

Prometheus and Loki may continue collecting data independently.

---

# 47. Alertmanager Infrastructure Problem

Check:

```bash
docker ps -a
docker logs --tail 200 <alertmanager-container>
```

Verify:

```text
port 9093
configuration
Prometheus connectivity
receiver configuration
```

If Alertmanager is down, Prometheus can still collect metrics and evaluate rules, but alert delivery is impaired.

---

# 48. Multiple Infrastructure Components Fail

When:

```text
API
Worker
PostgreSQL
Redis
MinIO
Prometheus
```

all become unavailable simultaneously, investigate the shared infrastructure layers first.

Priority:

```text
Host
  │
  ▼
Docker
  │
  ▼
Docker networking
  │
  ▼
Filesystem / resources
```

Do not independently restart every application service.

---

# 49. Host Disk Full and Multiple Services Fail

This is a common infrastructure cascade:

```text
Disk capacity exhausted
        │
        ├── Docker cannot write
        ├── PostgreSQL cannot write
        ├── MinIO cannot write
        ├── Loki cannot write
        └── deployment cannot write
                 │
                 ▼
          Multiple services fail
```

The correct response is to identify the disk consumer first.

Recovery should preserve persistent application data.

---

# 50. Host Memory Exhaustion and Multiple Services Fail

The cascade can be:

```text
Memory pressure
      │
      ▼
OOM
      │
      ├── API restart
      ├── Worker restart
      ├── database instability
      └── observability degradation
```

Investigate host-level memory pressure before treating each restart as an independent application problem.

---

# 51. Infrastructure Recovery Priority

When several infrastructure layers are affected, use this order:

```text
1. Host availability
2. Network availability
3. Docker Engine
4. Persistent storage
5. Core dependencies
6. API / Worker
7. Observability
8. CI/CD runner
```

The exact order can change according to incident evidence.

The principle is:

> Restore the lowest failed dependency first.

---

# 52. Recovery Actions by Risk

Prefer actions with lower blast radius.

### Low Risk

```text
inspect logs
inspect metrics
inspect container state
inspect network state
validate configuration
```

### Moderate Risk

```text
restart one unhealthy container
restart one service
re-run idempotent Ansible configuration
```

### High Risk

```text
restart Docker Engine
modify firewall rules
modify SSH configuration
delete Docker resources
change persistent storage
delete volumes
rebuild infrastructure
```

High-risk actions require evidence and an explicit recovery decision.

---

# 53. Infrastructure Recovery Validation

After corrective action, validate at every affected layer.

Example:

```text
Docker
  │
  ├── Engine healthy
  ├── Network healthy
  └── Containers running
          │
          ▼
Application
  │
  ├── Liveness
  └── Readiness
          │
          ▼
Dependencies
  │
  ├── PostgreSQL
  ├── Redis
  └── MinIO
          │
          ▼
Observability
  │
  ├── Prometheus
  ├── Loki
  └── Grafana
```

Do not consider recovery complete merely because a container restarted.

---

# 54. Infrastructure Validation Checklist

After infrastructure recovery:

```text
[ ] Host reachable
[ ] SSH operational
[ ] UFW state correct
[ ] Docker Engine active
[ ] Required Docker networks present
[ ] Required containers running
[ ] Health checks passing
[ ] Persistent volumes mounted
[ ] PostgreSQL healthy
[ ] Redis healthy
[ ] MinIO healthy
[ ] API healthy
[ ] Worker healthy
[ ] Prometheus scraping
[ ] Loki receiving logs
[ ] Alertmanager reachable
[ ] Grafana reachable
[ ] GitHub Actions runner online
```

---

# 55. Infrastructure Changes After an Incident

If the root cause was caused by missing or incorrect infrastructure configuration, fix the source of truth.

Preferred sequence:

```text
Incident
   │
   ▼
Root Cause
   │
   ▼
Infrastructure Definition
   │
   ▼
Ansible / Compose / Configuration
   │
   ▼
Validation
   │
   ▼
Deployment
```

Avoid leaving a manual host modification as the permanent fix.

---

# 56. Infrastructure Drift Detection

The intended infrastructure state is represented by:

```text
infra/ansible
docker-compose configuration
deployment templates
security baseline
```

The actual state exists on the host.

Troubleshooting should compare:

```text
Desired State
      │
      ▼
Actual State
      │
      ▼
Drift
```

Examples:

```text
desired Docker service enabled
actual Docker service disabled
```

or:

```text
desired UFW rule exists
actual rule missing
```

or:

```text
desired deployment directory exists
actual directory missing
```

Drift should be corrected through automation when practical.

---

# 57. When to Re-run Ansible

Re-run Ansible when:

```text
configuration drift is confirmed
infrastructure state is incomplete
a managed resource is missing
security baseline needs reconciliation
deployment runtime state must be restored
```

Do not re-run the entire infrastructure stack repeatedly without identifying the failed layer.

A targeted, evidence-driven reconciliation is safer.

---

# 58. When Not to Re-run Ansible

Do not automatically re-run infrastructure automation when the failure is clearly:

```text
application logic
runtime failure
database data corruption
temporary dependency outage
application-level timeout
```

Automation is not a universal recovery mechanism.

Use it when the desired infrastructure state itself is the problem.

---

# 59. Infrastructure Incident Evidence

For an unresolved infrastructure incident, record:

```text
Incident timestamp:
Host:
Environment:
Affected infrastructure layer:
Affected services:
Docker state:
Network state:
Filesystem state:
CPU state:
Memory state:
Firewall state:
SSH state:
Ansible state:
Relevant logs:
Relevant alerts:
Recent infrastructure change:
Recent deployment:
Recovery action:
Recovery result:
Root cause:
Preventive action:
```

This information should feed the incident-response process.

---

# 60. Infrastructure Troubleshooting Decision Tree

```text
Infrastructure failure
        │
        ▼
Is host reachable?
   │             │
  No            Yes
   │             │
Host/VM          ▼
investigation   Is SSH available?
                  │
             ┌────┴────┐
            No         Yes
            │           │
        SSH/firewall    ▼
        investigation  Is Docker healthy?
                         │
                    ┌────┴────┐
                   No         Yes
                   │           │
             Docker/host      ▼
             investigation   Are networks healthy?
                               │
                          ┌────┴────┐
                         No         Yes
                         │           │
                     Network         ▼
                    investigation  Are containers healthy?
                                      │
                                 ┌────┴────┐
                                No         Yes
                                │           │
                         Container/dependency
                                      │
                                      ▼
                              Is infrastructure
                              observability healthy?
                                      │
                                 ┌────┴────┐
                                No         Yes
                                │           │
                          Observability   Investigate
                          infrastructure  application/
                          investigation   runtime layer
```

---

# 61. Final Infrastructure Principle

Infrastructure troubleshooting should preserve the following hierarchy:

```text
Host
  ↓
Operating System
  ↓
Security / Network
  ↓
Docker
  ↓
Networks / Volumes
  ↓
Core Dependencies
  ↓
Application Services
  ↓
Observability
```

The most important operational rule is:

> **Do not repair a higher layer before verifying that the lower layers it depends on are healthy.**

Infrastructure troubleshooting is therefore not primarily about restarting services.

It is about determining:

```text
What failed?
      ↓
At which infrastructure boundary?
      ↓
What depended on that boundary?
      ↓
How did the failure propagate?
      ↓
What is the smallest safe corrective action?
      ↓
How do we verify that the intended infrastructure state has been restored?
```

A successful recovery is only the first outcome.

The final outcome should be a system whose infrastructure state is:

```text
known
repeatable
observable
recoverable
and represented by automation
```

```
```
