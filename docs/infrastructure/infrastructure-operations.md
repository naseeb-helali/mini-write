# Infrastructure Operations

## 1. Purpose

This document defines the operational model for the Mini-Write infrastructure layer.

The purpose is to describe **how the provisioned infrastructure is operated, validated, maintained, and recovered**, rather than describing how the infrastructure is initially designed.

The infrastructure layer provides the operational foundation for the application stack:

```text
                         Mini-Write
                             │
                             ▼
                    Infrastructure Layer
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
          ▼                  ▼                  ▼
        Host              Docker            Deployment
     Operations           Runtime             Runtime
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
                             ▼
                    Running Services
````

The operational model is based on several principles:

* Infrastructure state is managed as code.
* Host configuration should be reproducible.
* Operational changes should be deterministic.
* Infrastructure failures should be observable.
* Manual intervention should be minimized.
* Changes should be validated after application.
* Infrastructure recovery should be possible without reconstructing the environment manually.
* The infrastructure layer must preserve clear ownership boundaries.

---

# 2. Infrastructure Operational Scope

Infrastructure operations cover the lifecycle of the staging host and the runtime environment deployed on it.

The current operational scope includes:

```text
Infrastructure Operations
│
├── Host
│   ├── OS packages
│   ├── Users
│   ├── SSH
│   └── Firewall
│
├── Docker
│   ├── Docker Engine
│   ├── Images
│   ├── Networks
│   ├── Volumes
│   └── Containers
│
├── Deployment Runtime
│   ├── /opt/deploy
│   ├── Compose configuration
│   ├── Environment configuration
│   ├── Deployment state
│   └── Deployment logs
│
├── CI/CD Runner
│   ├── GitHub Actions Runner
│   ├── Runner service
│   └── Docker access
│
├── Observability
│   ├── Prometheus
│   ├── Loki
│   ├── Grafana
│   ├── Alertmanager
│   └── Exporters
│
└── Validation
    ├── Configuration validation
    ├── Service health
    ├── Connectivity
    └── Idempotency
```

Application-level business operations are outside the primary scope of this document.

---

# 3. Operational Ownership Model

The infrastructure architecture separates responsibilities between infrastructure, deployment, application, and observability layers.

| Area                   | Primary Responsibility      |
| ---------------------- | --------------------------- |
| Ubuntu host            | Infrastructure              |
| APT packages           | Infrastructure              |
| SSH                    | Infrastructure              |
| UFW                    | Infrastructure              |
| Docker Engine          | Infrastructure              |
| Docker networks        | Infrastructure / Deployment |
| Docker volumes         | Deployment runtime          |
| Compose topology       | Deployment                  |
| Application containers | Application / Deployment    |
| GitHub Runner          | Infrastructure / CI/CD      |
| Prometheus             | Observability               |
| Loki                   | Observability               |
| Grafana                | Observability               |
| Alertmanager           | Observability               |
| Application health     | Application                 |
| Runtime reliability    | Application runtime         |
| Deployment state       | Deployment runtime          |

The important principle is that infrastructure operations should not silently become application operations.

---

# 4. Infrastructure Lifecycle

The infrastructure lifecycle is:

```text
Plan
 │
 ▼
Provision
 │
 ▼
Validate
 │
 ▼
Operate
 │
 ▼
Observe
 │
 ▼
Maintain
 │
 ├───────────────┐
 │               │
 ▼               ▼
Remediate      Evolve
 │               │
 └───────┬───────┘
         ▼
      Validate
```

Infrastructure is therefore not considered complete when Ansible finishes.

The infrastructure must remain in a known and observable state during its operational lifetime.

---

# 5. Infrastructure as Code as the Operational Source of Truth

The authoritative infrastructure configuration resides in:

```text
infra/ansible/
```

The primary provisioning entry point is:

```text
infra/ansible/playbooks/site.yml
```

The playbook applies the infrastructure roles in the following order:

```text
base
  │
  ▼
docker
  │
  ▼
deploy_runtime
  │
  ▼
github_runner
  │
  ▼
security_baseline
```

This ordering establishes dependencies between infrastructure capabilities.

Conceptually:

```text
Base OS
   │
   ▼
Docker Runtime
   │
   ▼
Deployment Runtime
   │
   ▼
CI/CD Runner
   │
   ▼
Security Baseline
```

---

# 6. Operational Principle: Desired State

Infrastructure operations are based on desired state rather than imperative repair commands.

The model is:

```text
Desired Infrastructure State
            │
            ▼
       Ansible Roles
            │
            ▼
       Current Host
            │
            ▼
      State Reconciliation
```

Ansible should determine whether the host differs from the declared configuration and apply only the required changes.

This makes the infrastructure operational model repeatable.

---

# 7. Ansible Execution

The main provisioning operation is executed through the site playbook.

The conceptual command is:

```bash
ansible-playbook -i <inventory> infra/ansible/playbooks/site.yml
```

The exact inventory and vault invocation depend on the repository's environment-specific configuration.

The operational principle is:

```text
Inventory
+
Variables
+
Vault
+
Roles
        │
        ▼
     site.yml
        │
        ▼
     Host State
```

---

# 8. Check Mode

Before applying potentially disruptive infrastructure changes, Ansible check mode can be used:

```bash
ansible-playbook \
  -i <inventory> \
  infra/ansible/playbooks/site.yml \
  --check
```

Check mode provides an approximation of the changes Ansible intends to make.

It should be treated as a planning and safety mechanism rather than a complete substitute for actual execution.

Some modules or runtime-dependent operations may behave differently under check mode.

The important operational distinction is:

```text
Check Mode
    │
    ▼
Expected Changes

Actual Run
    │
    ▼
Real Host State
```

Both may be required for high-confidence changes.

---

# 9. Idempotency

Idempotency is a core infrastructure operational requirement.

After the host reaches its intended state:

```text
First execution
    │
    ▼
Infrastructure converges
    │
    ▼
Second execution
    │
    ▼
No unnecessary changes
```

A healthy repeated run should produce no unexpected changes.

This property is particularly important because infrastructure may be reapplied during:

* recovery;
* host replacement;
* configuration changes;
* deployment preparation;
* maintenance;
* disaster recovery.

---

# 10. Infrastructure Convergence

Infrastructure convergence means that repeated execution moves the host toward the same desired state.

For example:

```text
Host State A
   │
   │ Ansible
   ▼
Host State B
   │
   │ Ansible
   ▼
Desired State
   │
   │ Ansible
   ▼
Desired State
```

The last execution should therefore become effectively a no-op when no configuration has changed.

---

# 11. Host Maintenance

Host maintenance includes activities such as:

```text
APT package updates
Docker package updates
Security configuration changes
SSH configuration changes
Filesystem maintenance
Docker resource cleanup
Runner maintenance
Infrastructure configuration changes
```

Host maintenance should preferably be performed through Ansible whenever the change belongs to the declared infrastructure state.

Manual changes should be reserved for:

* emergency recovery;
* temporary diagnosis;
* actions not yet represented in infrastructure code.

A manual change should subsequently be reflected in the authoritative configuration if it is intended to become permanent.

---

# 12. Package Management

The `base` role performs:

```text
APT package index update
        │
        ▼
Installed package upgrade
        │
        ▼
Required base package installation
```

This establishes the basic operating-system environment.

Operationally, package changes can have broader consequences than their immediate task suggests.

For example:

```text
OS Package Update
      │
      ├── service restart
      ├── library change
      ├── kernel update
      └── behavior change
```

Therefore major host upgrades should be validated against the running Mini-Write stack.

---

# 13. Docker Runtime Operations

Docker is the primary container runtime.

The operational dependency chain is:

```text
Ubuntu
  │
  ▼
Docker Engine
  │
  ├── Networks
  ├── Volumes
  ├── Images
  └── Containers
```

Docker operations therefore affect the application runtime directly.

The infrastructure operator should distinguish between:

```text
Docker Engine problem
```

and:

```text
Container/application problem
```

before applying remediation.

---

# 14. Docker Service Validation

The Docker daemon must be running before application services can operate.

The expected state is:

```text
Docker service
     │
     ├── enabled
     └── active
```

A basic host-level check is:

```bash
systemctl is-active docker
```

The expected result is:

```text
active
```

If Docker is inactive, container-level diagnosis should normally be postponed until the Docker runtime itself is restored.

---

# 15. Container Runtime Validation

After Docker is healthy, inspect the application stack:

```bash
docker compose ps
```

The operational question is not merely:

> Are containers running?

It is:

> Are the required services running and passing their intended health checks?

A useful hierarchy is:

```text
Docker daemon
      │
      ▼
Container exists
      │
      ▼
Container running
      │
      ▼
Health check passing
      │
      ▼
Service operational
```

These are different states.

---

# 16. Docker Networks

The deployment Compose configuration defines:

```text
frontend-network
backend-network
```

The operational model is:

```text
External Traffic
      │
      ▼
Frontend Network
      │
      ▼
API
      │
      ▼
Backend Network
      │
 ┌────┼───────────────┐
 ▼    ▼               ▼
Redis PostgreSQL     Storage
```

Operational troubleshooting should therefore consider network membership before assuming that a service itself is unavailable.

---

# 17. Docker Volumes

Persistent service state is stored through named Docker volumes.

The current deployment defines volumes for:

```text
PostgreSQL
Redis
MinIO
Prometheus
Grafana
Loki
Alertmanager
```

Conceptually:

```text
Container
   │
   ▼
Named Volume
   │
   ▼
Persistent State
```

A container recreation does not necessarily imply data loss.

However:

```text
Container deletion
    ≠
Volume deletion
```

and operators must understand which operation is being performed before removing Docker resources.

---

# 18. Persistent Data Safety

Persistent volumes represent state that may be required for recovery.

Before destructive Docker operations such as:

```bash
docker compose down -v
```

the operator must understand that the `-v` option can remove named volumes associated with the Compose project.

This can result in data loss.

Therefore:

```text
docker compose down
```

and:

```text
docker compose down -v
```

must be treated as materially different operational actions.

---

# 19. Docker Image Operations

Application services use versioned image references.

Operationally, image lifecycle includes:

```text
Pull
 │
 ▼
Verify
 │
 ▼
Run
 │
 ▼
Replace old container
```

Images should not be deleted simply to solve an application failure unless disk pressure or another concrete reason requires cleanup.

The preferred diagnostic sequence is:

```text
Container failure
    │
    ▼
Inspect logs
    │
    ▼
Inspect health
    │
    ▼
Inspect image
    │
    ▼
Inspect configuration
```

rather than immediately removing the image or container.

---

# 20. Deployment Runtime

The deployment runtime is rooted at:

```text
/opt/deploy
```

It contains operational state and configuration used by the deployment system.

The important directories are:

```text
/opt/deploy
├── compose/
├── env/
├── logs/
├── metrics/
├── scripts/
└── state/
```

These directories have different ownership and mutability requirements.

---

# 21. Immutable and Mutable Runtime Areas

The deployment runtime distinguishes between immutable infrastructure artifacts and mutable operational state.

Conceptually:

```text
/opt/deploy
│
├── Immutable
│   ├── compose/
│   ├── proxy/
│   └── scripts/
│
└── Mutable
    ├── state/
    ├── logs/
    ├── env/
    └── metrics/
```

This separation is operationally important.

Immutable configuration should be controlled by infrastructure automation.

Mutable state must remain writable by the appropriate operational identity.

---

# 22. Deployment State

Deployment state is maintained in:

```text
/opt/deploy/state/deployment_state.json
```

The state structure records:

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

The intended operational meaning is:

```text
current
    │
    └── versions currently deployed

previous
    │
    └── versions previously deployed
```

This provides the foundation for deployment history and rollback operations.

The state file should therefore not be casually deleted or overwritten.

---

# 23. Deployment Logs

Deployment operations write to:

```text
/opt/deploy/logs/deploy.log
```

This log is part of the operational evidence for deployment activities.

The log lifecycle is:

```text
Deployment
    │
    ▼
Deployment Script
    │
    ▼
deploy.log
    │
    ▼
Promtail
    │
    ▼
Loki
    │
    ▼
Grafana / Incident Investigation
```

This creates a connection between deployment operations and observability.

---

# 24. Deployment Environment

The staging runtime environment is stored at:

```text
/opt/deploy/env/.env.staging
```

The file contains runtime configuration consumed by the Compose stack.

It is intentionally permission-restricted.

Operationally, environment configuration should be treated as sensitive infrastructure state.

Changes should therefore be:

```text
Controlled
Auditable
Validated
```

rather than performed casually on the running host.

---

# 25. Infrastructure and CI/CD Runner

The GitHub Actions self-hosted runner is part of the infrastructure layer.

Its operational chain is:

```text
GitHub
   │
   ▼
Workflow
   │
   ▼
Self-hosted Runner
   │
   ▼
Deployment User
   │
   ▼
Docker
   │
   ▼
Mini-Write Runtime
```

The runner service must remain available for CI/CD operations.

A runner outage therefore does not necessarily mean that the application itself is down.

This distinction is important during incident diagnosis.

---

# 26. GitHub Runner Validation

The runner service is expected to be active.

The infrastructure validation checks:

```text
systemd service
       │
       ▼
active
```

and verifies that the deployment user has Docker access.

The operational chain is therefore:

```text
Runner Active
      +
Docker Access
      +
Deployment Runtime Exists
      │
      ▼
Deployment Capability Available
```

Failure of any one of these conditions can prevent deployment even if the application itself is healthy.

---

# 27. Infrastructure Health Model

Infrastructure health should be evaluated across multiple layers.

```text
Layer 1 — Host
    │
    ├── OS
    ├── CPU
    ├── Memory
    ├── Disk
    └── Network
         │
         ▼
Layer 2 — Docker
    │
    ├── Docker daemon
    ├── Networks
    ├── Volumes
    └── Containers
         │
         ▼
Layer 3 — Deployment
    │
    ├── Compose configuration
    ├── Environment
    ├── State
    └── Scripts
         │
         ▼
Layer 4 — Services
    │
    ├── API
    ├── Worker
    ├── PostgreSQL
    ├── Redis
    └── MinIO
```

A failure at a lower layer can manifest as failures at higher layers.

---

# 28. Infrastructure Observability

Infrastructure operations are integrated with the observability stack.

The major signals are:

```text
Metrics
Logs
Health Checks
Alerts
```

The data flow is:

```text
Host / Containers
       │
       ├──────────► Node Exporter
       │
       ├──────────► cAdvisor
       │
       └──────────► Promtail
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
          Prometheus               Loki
             │                       │
             └───────────┬───────────┘
                         ▼
                      Grafana
```

Alertmanager provides the alert routing layer for Prometheus alerts.

---

# 29. Host Metrics

Node Exporter provides host-level metrics.

These include signals such as:

```text
CPU utilization
Memory utilization
Filesystem utilization
System availability
```

The infrastructure alerting rules include:

```text
MWNodeExporterDown
MWHighCPUUsage
MWHighMemoryUsage
MWLowDiskSpace
```

These alerts provide early indicators of infrastructure degradation.

---

# 30. Container Metrics

cAdvisor provides container-level resource metrics.

This helps distinguish:

```text
Host resource exhaustion
```

from:

```text
Individual container resource pressure
```

The diagnostic hierarchy becomes:

```text
Host CPU high
      │
      ▼
Check container CPU
      │
      ▼
Identify dominant workload
      │
      ▼
Investigate service behavior
```

This is more useful than treating host resource saturation as an isolated infrastructure problem.

---

# 31. Infrastructure Alerts

The current infrastructure alerting model includes:

| Alert                | Condition                        | Severity |
| -------------------- | -------------------------------- | -------- |
| `MWNodeExporterDown` | Node Exporter unavailable        | Critical |
| `MWHighCPUUsage`     | CPU > 90% for 10m                | Warning  |
| `MWHighMemoryUsage`  | Memory > 90% for 10m             | Warning  |
| `MWLowDiskSpace`     | Available filesystem space < 10% | Critical |

These alerts should be interpreted as operational signals rather than automatic proof of root cause.

---

# 32. Alert Interpretation

An alert represents:

```text
Observed condition
```

not:

```text
Confirmed root cause
```

For example:

```text
MWHighCPUUsage
```

means that host CPU utilization is sustained above the configured threshold.

It does not by itself establish whether the cause is:

```text
API traffic
Worker processing
Docker overhead
Unexpected workload
System process
```

The operator should correlate the alert with metrics and logs.

---

# 33. Infrastructure Incident Investigation

A standard investigation should move from lower infrastructure layers upward.

Recommended sequence:

```text
1. Host
   │
   ├── CPU
   ├── Memory
   ├── Disk
   └── Network
   │
   ▼
2. Docker
   │
   ├── daemon
   ├── containers
   ├── networks
   └── volumes
   │
   ▼
3. Service
   │
   ├── health
   ├── logs
   └── metrics
   │
   ▼
4. Application / Runtime
```

This prevents premature application-level debugging when the actual problem is infrastructure-level.

---

# 34. Host Resource Incident

When CPU or memory usage is high:

```text
Alert
 │
 ▼
Confirm host metric
 │
 ▼
Inspect containers
 │
 ▼
Identify resource consumer
 │
 ▼
Inspect service behavior
 │
 ▼
Determine whether load is expected
```

For example:

```bash
docker stats
```

can be used to identify containers consuming significant CPU or memory.

The command is diagnostic and should not itself be treated as remediation.

---

# 35. Disk Pressure Incident

Low disk space is particularly important because it can affect:

```text
Docker
Logs
PostgreSQL
Prometheus
Loki
Deployments
```

A disk incident should therefore be investigated before the filesystem reaches exhaustion.

A useful sequence is:

```text
Disk Alert
   │
   ▼
Filesystem usage
   │
   ▼
Large directories
   │
   ├── Docker
   ├── Logs
   ├── Volumes
   └── Deployment artifacts
   │
   ▼
Determine retention / cleanup action
```

Destructive cleanup should not be performed before identifying whether the data is operationally required.

---

# 36. Docker Resource Cleanup

Docker resources can accumulate over time.

Potential sources include:

```text
Unused images
Stopped containers
Unused networks
Build cache
Unused volumes
```

Cleanup must distinguish between disposable resources and persistent application state.

The most dangerous category is persistent volumes because they may contain:

```text
Database state
Queue state
Object storage data
Observability state
```

Therefore volume cleanup requires explicit confirmation of data ownership and recovery requirements.

---

# 37. Service Restart Policy

The Compose stack uses restart policies for the core services.

The intended behavior is:

```text
Container exits
     │
     ▼
Docker restart policy
     │
     ▼
Container restarted
```

This provides automatic recovery from certain process-level failures.

However, restart policy does not prove that the service is healthy.

The complete operational model remains:

```text
Restart
  +
Health Check
  +
Metrics
  +
Logs
```

---

# 38. Health Checks

Health checks provide service-level validation.

Examples include:

```text
API
    /health/ready

Redis
    redis-cli ping

PostgreSQL
    pg_isready

MinIO
    /minio/health/live
```

Health checks should be interpreted as service-specific contracts.

A container being `running` does not necessarily mean its health check is passing.

---

# 39. Infrastructure Change Management

Infrastructure changes should follow:

```text
Change Request
      │
      ▼
Understand Impact
      │
      ▼
Modify Infrastructure Code
      │
      ▼
Review
      │
      ▼
Check / Validate
      │
      ▼
Apply
      │
      ▼
Operational Validation
      │
      ▼
Document if Required
```

Changes should not normally be made directly on the host and forgotten.

The host is a runtime instance of the infrastructure definition.

---

# 40. Configuration Drift

Configuration drift occurs when:

```text
Actual Host State
       ≠
Declared Infrastructure State
```

Examples include:

```text
Manual firewall rule
Manual SSH change
Manual package installation
Manual permission change
Manual Docker configuration
```

Drift is operationally dangerous because future Ansible execution may overwrite or conflict with manual changes.

The preferred remediation is:

```text
Detect Drift
   │
   ▼
Understand Cause
   │
   ▼
Encode Desired State
   │
   ▼
Reapply Ansible
   │
   ▼
Validate
```

---

# 41. Manual Emergency Changes

Emergency manual changes may be necessary when automation cannot be executed.

Examples:

```text
Broken SSH configuration
Severe disk pressure
Docker daemon failure
Network misconfiguration
Failed deployment automation
```

The operational rule is:

```text
Emergency manual change
        │
        ▼
Restore service
        │
        ▼
Document change
        │
        ▼
Encode permanent state in Ansible
        │
        ▼
Reconcile host
```

Temporary emergency state should not become the permanent source of truth.

---

# 42. Recovery from Host Configuration Failure

If infrastructure configuration becomes invalid, recovery should follow the lowest-risk path.

Example:

```text
Configuration failure
        │
        ▼
Determine affected layer
        │
        ├── SSH
        ├── UFW
        ├── Docker
        └── Deployment
        │
        ▼
Restore minimum access
        │
        ▼
Correct infrastructure code
        │
        ▼
Reapply Ansible
        │
        ▼
Validate complete stack
```

The first objective is not to restore every service immediately.

It is to restore the infrastructure control plane required to safely recover the remaining layers.

---

# 43. Host Replacement

Because infrastructure is represented as code, the intended recovery model supports rebuilding the staging host.

Conceptually:

```text
New Ubuntu Host
       │
       ▼
Ansible
       │
       ├── Base
       ├── Docker
       ├── Deployment Runtime
       ├── GitHub Runner
       └── Security Baseline
       │
       ▼
Operational Infrastructure
       │
       ▼
Application Deployment
```

This is one of the primary benefits of Infrastructure as Code.

The infrastructure should not depend on undocumented manual configuration accumulated over time.

---

# 44. Host Replacement and Persistent Data

Host replacement introduces a critical distinction:

```text
Infrastructure
```

versus:

```text
Persistent Application Data
```

Recreating the host does not automatically recreate:

```text
PostgreSQL data
Redis state
MinIO objects
Prometheus history
Grafana state
Loki data
```

Therefore host replacement and data recovery are separate operational processes.

A complete disaster recovery procedure must account for both.

---

# 45. Backup Boundary

The infrastructure code establishes persistent volumes but does not by itself constitute a backup system.

The following should therefore not be confused:

```text
Docker Volume
    ≠
Backup
```

A volume provides persistence across container recreation.

A backup provides an independent recovery copy.

This distinction is especially important for:

```text
PostgreSQL
MinIO
Redis
```

and any other state whose loss would affect application continuity.

---

# 46. Operational Recovery Hierarchy

Recovery should generally proceed from infrastructure foundations upward:

```text
1. Host
   │
   ▼
2. Network
   │
   ▼
3. Docker
   │
   ▼
4. Persistent Storage
   │
   ▼
5. Deployment Runtime
   │
   ▼
6. Application Services
   │
   ▼
7. Observability
   │
   ▼
8. Functional Validation
```

The exact ordering may change during a specific incident, but the dependency relationships should remain understood.

---

# 47. Infrastructure Validation After Change

Every meaningful infrastructure change should be followed by validation appropriate to the affected layer.

For example:

### SSH change

```text
sshd -t
+
new SSH session
```

### Firewall change

```text
UFW status
+
required connectivity
```

### Docker change

```text
systemctl status docker
+
docker info
```

### Compose change

```text
docker compose config
+
docker compose ps
+
health checks
```

### Deployment runtime change

```text
filesystem validation
+
permissions
+
required files
```

The validation depth should match the change risk.

---

# 48. Compose Configuration Validation

Before applying a significant Compose configuration change, the rendered configuration should be validated.

The conceptual operation is:

```bash
docker compose config
```

This helps detect:

```text
Invalid YAML
Invalid interpolation
Missing configuration
Incorrect service structure
```

before the stack is restarted.

The important distinction is:

```text
Configuration Valid
      ≠
Service Healthy
```

Both must be validated.

---

# 49. Operational Readiness

Infrastructure is operationally ready when:

```text
Host
  ✓ accessible
  ✓ secure
  ✓ resource state acceptable

Docker
  ✓ daemon active
  ✓ networks available
  ✓ volumes available

Deployment
  ✓ configuration present
  ✓ environment present
  ✓ state present
  ✓ scripts available

CI/CD
  ✓ runner registered
  ✓ runner service active
  ✓ Docker access available

Application
  ✓ containers running
  ✓ health checks passing

Observability
  ✓ metrics available
  ✓ logs available
  ✓ alerts evaluated
```

This represents operational readiness as a system property rather than a single service status.

---

# 50. Infrastructure Operational Checklist

## Before Infrastructure Changes

```text
[ ] Identify affected infrastructure layer
[ ] Identify dependencies
[ ] Review current state
[ ] Review Ansible role
[ ] Check whether change affects SSH or firewall
[ ] Check whether persistent data is involved
[ ] Validate intended configuration
```

## During Change

```text
[ ] Apply through Ansible where possible
[ ] Avoid unnecessary manual changes
[ ] Monitor command output
[ ] Monitor service state
[ ] Avoid destructive Docker operations unless required
```

## After Change

```text
[ ] Verify host accessibility
[ ] Verify Docker daemon
[ ] Verify container state
[ ] Verify health checks
[ ] Verify required network connectivity
[ ] Verify observability
[ ] Verify deployment capability
[ ] Run idempotency validation when appropriate
```

---

# 51. Troubleshooting Decision Tree

A generic infrastructure incident can be approached through:

```text
Is the host reachable?
       │
   ┌───┴───┐
   │       │
  Yes      No
   │       │
   ▼       ▼
Docker?   Host / Network
   │
   ├── No ──► Docker investigation
   │
   └── Yes
        │
        ▼
Containers present?
        │
        ├── No ──► Deployment investigation
        │
        └── Yes
             │
             ▼
         Healthy?
             │
       ┌─────┴─────┐
       │           │
      Yes          No
       │           │
       ▼           ▼
    Service     Service logs /
    operation   dependencies
```

This decision tree intentionally moves from infrastructure prerequisites toward service-level diagnosis.

---

# 52. Common Operational Misconceptions

## 52.1 Container Running Means Service Healthy

False.

A process can remain alive while the service is unable to perform its intended function.

---

## 52.2 Restarting a Container Fixes the Root Cause

Not necessarily.

Restarting may temporarily clear:

```text
Memory leak
Connection state
Transient runtime failure
```

but it does not explain why the failure occurred.

---

## 52.3 Recreating a Container Deletes Its Data

Not necessarily.

Named volumes can persist independently of containers.

---

## 52.4 Removing Volumes Is a Normal Cleanup Operation

False.

Volume removal can destroy persistent state.

---

## 52.5 Ansible Success Means Infrastructure Is Healthy

False.

Ansible confirms that its tasks completed according to the module behavior.

It does not automatically prove:

```text
Application health
Network reachability
Business functionality
Observability correctness
```

---

## 52.6 UFW Alone Defines the Complete Network Security Model

False.

Docker networking and published ports also affect exposure.

The effective network posture is a combination of:

```text
Host Firewall
+
Docker Networking
+
Published Ports
+
Service Bindings
```

---

# 53. Operational Anti-Patterns

The following patterns should be avoided.

## 53.1 Permanent Manual Configuration

```text
SSH into host
   │
   ▼
Edit configuration manually
   │
   ▼
Forget to update Ansible
```

This creates configuration drift.

---

## 53.2 Blind Container Restart

```text
Failure
   │
   ▼
docker restart
   │
   ▼
No investigation
```

This may hide recurring infrastructure problems.

---

## 53.3 Destructive Docker Cleanup

```text
Disk full
   │
   ▼
docker system prune -a --volumes
```

without first understanding which data is persistent.

This can turn a resource problem into a data-loss incident.

---

## 53.4 Changing Firewall Rules Without Connectivity Validation

A firewall change can accidentally block:

```text
SSH
Application traffic
Monitoring
Deployment
```

Therefore firewall changes require explicit validation.

---

## 53.5 Changing SSH Without a Recovery Path

SSH is the administrative control plane.

Changing it without testing a new session can create an avoidable lockout.

---

# 54. Operational Documentation Boundary

This document describes **how infrastructure is operated**.

Other documentation owns related but distinct concerns:

```text
docs/architecture/
    → Why the infrastructure fits into the system architecture

docs/infrastructure/infrastructure-as-code.md
    → Infrastructure-as-Code design

docs/infrastructure/ansible.md
    → Ansible implementation

docs/infrastructure/host-provisioning.md
    → Host creation and provisioning

docs/infrastructure/docker.md
    → Docker architecture and runtime

docs/infrastructure/security-baseline.md
    → Host security controls

docs/deployment/
    → Application deployment lifecycle

docs/operations/
    → Service operations and incident management

docs/observability/
    → Metrics, logs, alerts, dashboards
```

This separation prevents infrastructure operations from becoming a duplicate of every other document.

---

# 55. Operational Invariants

The following invariants define the intended infrastructure operating model.

### Infrastructure State

```text
The host should be reproducible from Infrastructure as Code.
```

### Configuration

```text
The declared configuration is the authoritative desired state.
```

### Idempotency

```text
Repeated application should converge without unnecessary changes.
```

### Security

```text
Administrative access must remain controlled and recoverable.
```

### Docker

```text
Docker Engine is a critical infrastructure dependency.
```

### Persistence

```text
Persistent data must not be treated as disposable container state.
```

### Observability

```text
Infrastructure failures should produce observable signals.
```

### Recovery

```text
Infrastructure recovery must not depend exclusively on undocumented manual state.
```

---

# 56. Definition of Done

Infrastructure operations are considered mature for the current Mini-Write scope when:

```text
✓ Infrastructure is reproducible through Ansible.

✓ Host configuration converges toward declared state.

✓ Repeated Ansible execution is idempotent.

✓ Docker Engine is managed as an explicit infrastructure dependency.

✓ Deployment runtime is represented under /opt/deploy.

✓ Deployment configuration, state, logs, and metrics have explicit operational roles.

✓ GitHub Actions Runner is treated as an infrastructure capability.

✓ Docker networks and persistent volumes are understood operationally.

✓ Host and container health are observable.

✓ Infrastructure alerts exist for critical host conditions.

✓ Infrastructure changes have corresponding validation procedures.

✓ Emergency manual changes can be reconciled back into Infrastructure as Code.

✓ Host replacement is conceptually possible without reconstructing the environment manually.

✓ Persistent data is recognized as a separate recovery concern from infrastructure recreation.

✓ Infrastructure troubleshooting proceeds from lower-level dependencies toward higher-level services.
```

---

# 57. Final Operational Model

The Mini-Write infrastructure operational architecture can be summarized as:

```text
                    Infrastructure as Code
                             │
                             ▼
                    ┌─────────────────┐
                    │     Ansible     │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   Ubuntu Host   │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
            SSH             UFW          Docker
              │                             │
              │                    ┌────────┼────────┐
              │                    │        │        │
              │                    ▼        ▼        ▼
              │                 Networks Volumes Containers
              │                             │        │
              └──────────────┬──────────────┘        │
                             │                       │
                             ▼                       ▼
                    Deployment Runtime       Running Services
                             │                       │
                  ┌──────────┼──────────┐            │
                  │          │          │            │
                  ▼          ▼          ▼            │
               Compose      State      Logs          │
                  │                                 │
                  └────────────────┬────────────────┘
                                   │
                                   ▼
                             Observability
                                   │
                  ┌────────────────┼────────────────┐
                  │                │                │
                  ▼                ▼                ▼
              Prometheus         Loki           Grafana
                  │                │                │
                  └────────────────┼────────────────┘
                                   │
                                   ▼
                             Alertmanager
                                   │
                                   ▼
                         Operational Response
```

The central operational principle is:

> **Infrastructure is treated as a continuously managed system, not as a one-time provisioning artifact.**

Provisioning establishes the initial state.
Ansible maintains the desired state.
Docker executes the runtime.
Observability exposes operational state.
Validation verifies behavior.
Operations maintain and recover the system when reality diverges from the intended state.

```
```
