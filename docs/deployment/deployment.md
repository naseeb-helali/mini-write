# Deployment

## 1. Purpose

This document defines the deployment model of Mini-Write and explains how application releases move from the source repository to the staging runtime.

The deployment architecture is designed around several principles:

- reproducibility;
- deterministic deployment behavior;
- separation between infrastructure provisioning and application deployment;
- immutable application artifacts;
- persistent runtime state;
- controlled configuration;
- health-based validation;
- rollback awareness;
- operational observability.

The deployment system therefore consists of more than simply starting Docker containers.

It is a lifecycle:

```text
Source
  │
  ▼
Build
  │
  ▼
Artifact
  │
  ▼
CI Validation
  │
  ▼
Deployment
  │
  ▼
Runtime
  │
  ▼
Health Verification
  │
  ▼
Operational Observation
````

---

# 2. Deployment Scope

Mini-Write currently operates as a staging-oriented deployment on a single provisioned Linux host.

The deployment environment consists of:

```text
GitHub Repository
       │
       ▼
GitHub Actions
       │
       ▼
Self-Hosted Runner
       │
       ▼
Staging Host
       │
       ▼
Docker Compose Runtime
       │
       ├── Gateway
       ├── API
       ├── Worker
       ├── PostgreSQL
       ├── Redis
       ├── MinIO
       │
       └── Observability Platform
```

The infrastructure host itself is provisioned through Ansible.

This creates two related but distinct lifecycles:

```text
Infrastructure Lifecycle
        │
        ▼
Host Provisioning
        │
        ▼
Runtime Foundation
```

and:

```text
Application Lifecycle
        │
        ▼
Build
        │
        ▼
Deploy
        │
        ▼
Verify
```

These lifecycles should not be conflated.

---

# 3. Deployment Architecture

The deployment architecture has four major layers:

```text
┌─────────────────────────────────────────────┐
│ Source / CI Layer                           │
│ GitHub + GitHub Actions                     │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│ Deployment Control Layer                    │
│ Self-hosted runner + deployment scripts    │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│ Runtime Infrastructure Layer                │
│ Docker + Compose + host filesystem          │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│ Application / Service Layer                 │
│ Gateway / API / Worker / dependencies       │
└─────────────────────────────────────────────┘
```

The deployment mechanism is therefore intentionally layered.

The CI system should not need to recreate the complete operating-system infrastructure for every application deployment.

---

# 4. Infrastructure Provisioning vs Application Deployment

Mini-Write separates:

### Infrastructure provisioning

Responsible for creating and configuring the host.

Implemented through Ansible roles such as:

```text
base
docker
deploy_runtime
github_runner
security_baseline
```

### Application deployment

Responsible for updating application artifacts and bringing the runtime to the desired application state.

The distinction is:

```text
Ansible
   │
   ├── Host configuration
   ├── Docker installation
   ├── Runtime filesystem
   ├── Runner installation
   └── Security baseline
```

versus:

```text
Deployment workflow
   │
   ├── Application artifact
   ├── Runtime configuration
   ├── Compose deployment
   ├── Health verification
   └── Deployment state
```

This separation allows infrastructure to remain relatively stable while application releases change frequently.

---

# 5. Staging Host

The staging host is the execution environment for the deployed system.

Ansible prepares the host before application deployment.

The host contains the deployment root:

```text
/opt/deploy/
```

The deployment runtime is organized into distinct areas for configuration, scripts, state, logs, metrics, and Compose configuration.

Conceptually:

```text
/opt/deploy/
│
├── compose/
├── proxy/
├── scripts/
├── state/
├── logs/
├── env/
└── metrics/
```

The exact runtime layout is controlled by Ansible variables and role templates.

The important architectural distinction is between:

```text
Immutable Runtime Artifacts
```

and:

```text
Mutable Runtime State
```

---

# 6. Application Artifacts

Application containers are deployed using image references rather than building the application directly inside the running container.

The Compose deployment uses image variables such as:

```text
API_IMAGE
WORKER_IMAGE
```

This establishes the following deployment model:

```text
Source Code
    │
    ▼
Build
    │
    ▼
Container Image
    │
    ▼
Image Reference
    │
    ▼
Compose Deployment
```

The image therefore represents a deployable application artifact.

This is preferable to coupling production-like execution to source-tree state on the host.

---

# 7. Deployment Configuration

The staging Compose configuration is generated from an Ansible template:

```text
infra/ansible/roles/deploy_runtime/
└── templates/
    └── docker-compose.staging.yml.j2
```

The rendered file is deployed to:

```text
/opt/deploy/compose/docker-compose.staging.yml
```

This means the effective deployment configuration is generated from Infrastructure as Code rather than being manually assembled on the host.

The template defines:

* networks;
* persistent volumes;
* application services;
* infrastructure dependencies;
* observability services;
* health checks;
* restart policies;
* resource limits;
* logging configuration.

---

# 8. Runtime Services

The deployment includes the application runtime and its supporting infrastructure.

## Application services

```text
Gateway
API
Worker
```

## Stateful dependencies

```text
PostgreSQL
Redis
MinIO
```

## Observability services

```text
Prometheus
Loki
Promtail
Alertmanager
Grafana
Node Exporter
cAdvisor
Redis Exporter
PostgreSQL Exporter
```

The resulting runtime is therefore a complete application platform rather than only the API and Worker containers.

---

# 9. Container Startup Dependencies

The Compose configuration defines health-aware dependencies for services where startup ordering matters.

For example, the API depends on:

```text
PostgreSQL
Redis
```

and the Worker depends on:

```text
Redis
PostgreSQL
MinIO
```

The deployment model therefore distinguishes between:

```text
Container Started
```

and:

```text
Dependency Ready
```

This distinction is important because process startup does not necessarily mean that a service is ready to accept requests.

---

# 10. Health-Based Deployment

Health checks are part of deployment verification.

The API exposes:

```text
/health/live
/health/ready
```

The deployment runtime uses readiness information to determine whether dependencies required by the API are available.

Conceptually:

```text
Container Running
      │
      ▼
Application Started
      │
      ▼
Readiness Check
      │
      ├── Healthy ──► Deployment can proceed
      │
      └── Unhealthy ─► Deployment requires investigation
```

Health verification should therefore be treated as deployment evidence rather than merely a container configuration feature.

---

# 11. Deployment State

Mini-Write maintains deployment state in:

```text
/opt/deploy/state/deployment_state.json
```

The initial state is represented by:

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

The state model provides two important concepts:

```text
current
previous
```

This establishes a foundation for tracking the currently deployed application artifacts and the immediately preceding deployment.

Conceptually:

```text
Previous Release
      │
      ▼
Current Release
```

The deployment state should be treated as operational state, not as the authoritative source of application source code.

---

# 12. Deployment State Semantics

The deployment state exists to answer questions such as:

```text
What API artifact is currently deployed?
What Worker artifact is currently deployed?
What was deployed immediately before it?
What release should be considered for rollback?
```

The state therefore supports deployment traceability.

A deployment should not modify state merely because an attempt was initiated.

The state should represent an actual deployment outcome.

This distinction is important:

```text
Deployment Attempt
        ≠
Successful Deployment
```

---

# 13. Persistent Data

Application state is separated from container lifecycle through Docker volumes.

The Compose deployment defines persistent volumes for:

```text
postgres_data
redis_data
minio_data
prometheus_data
grafana_data
loki_data
alertmanager_data
```

The conceptual model is:

```text
Container
   │
   ├── Ephemeral filesystem
   │
   └── Persistent volume
             │
             ▼
        Durable state
```

Removing or recreating a container should therefore not inherently imply deleting the application's persistent data.

---

# 14. Application Release vs Persistent State

Application deployment and state persistence have different lifecycles.

```text
Application Image
    │
    ▼
Replaceable
```

while:

```text
Database / Queue / Object Storage
    │
    ▼
Persistent
```

This distinction is fundamental to safe deployment.

A deployment mechanism must therefore avoid treating all runtime resources as disposable in the same way.

---

# 15. Configuration Management

The staging environment file is provisioned by Ansible:

```text
/opt/deploy/env/.env.staging
```

The source template is:

```text
infra/ansible/roles/deploy_runtime/templates/env.staging.j2
```

The file is created with restricted permissions and later assigned to the deployment user.

The deployment model therefore separates:

```text
Application Image
```

from:

```text
Environment Configuration
```

This allows the same application artifact to be configured differently across environments.

---

# 16. Secrets

Sensitive deployment values are provided to Ansible through the staging secrets mechanism referenced by:

```text
infra/ansible/playbooks/site.yml
```

The playbook loads:

```text
../vault/staging-secrets.yml
```

Sensitive values should not be committed to the repository in plaintext.

Deployment logs should also avoid exposing credentials.

The GitHub Runner registration process follows the same principle by suppressing sensitive task output using Ansible's `no_log` behavior where credentials or registration tokens are involved.

---

# 17. Deployment Scripts

Deployment scripts are installed under:

```text
/opt/deploy/scripts/
```

Runtime modules are installed under the configured runtime subdirectory beneath this path.

These scripts provide the operational execution layer between the CI system and the Docker Compose runtime.

The architecture can therefore be viewed as:

```text
GitHub Actions
      │
      ▼
Deployment Script
      │
      ▼
Deployment Runtime
      │
      ▼
Docker Compose
```

The scripts should remain deterministic and should expose failures rather than silently continuing after an unsuccessful deployment operation.

---

# 18. Deployment Logs

Deployment activity is persisted under:

```text
/opt/deploy/logs/
```

The deployment runtime bootstraps:

```text
/opt/deploy/logs/deploy.log
```

This provides a persistent operational record independent of the lifecycle of the deployment process itself.

Deployment logs are also integrated into the project's observability architecture through Promtail.

Conceptually:

```text
Deployment
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
Grafana
```

This makes deployment activity observable alongside application and infrastructure events.

---

# 19. Deployment Workflow

The logical deployment workflow is:

```text
┌──────────────────────┐
│ Source Change        │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ CI Validation        │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Build Image          │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Publish / Reference  │
│ Deployable Artifact  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Deployment Execution │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Compose Runtime      │
│ Update               │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Health Verification  │
└──────────┬───────────┘
           │
       ┌───┴────┐
       │        │
     Pass      Fail
       │        │
       ▼        ▼
  Deployment   Failure
  Accepted     Handling
```

The exact CI commands and release triggers are defined by the repository's workflow configuration and should remain the authoritative source for CI execution details.

---

# 20. Deployment Ordering

Deployment ordering is important because services have dependencies.

The conceptual dependency graph is:

```text
                 ┌─────────────┐
                 │ PostgreSQL  │
                 └──────┬──────┘
                        │
                 ┌──────┴──────┐
                 │             │
                 ▼             ▼
               API           Worker
                 │             │
                 │             │
                 └──────┬──────┘
                        │
                        ▼
                      Gateway
```

Redis and MinIO participate in the relevant application paths.

The Compose health conditions provide part of the startup coordination.

Deployment logic should nevertheless verify final system health rather than assuming that dependency ordering alone proves successful deployment.

---

# 21. Gateway Deployment

Nginx acts as the external gateway.

The deployment system renders:

```text
/opt/deploy/proxy/nginx.conf
```

from:

```text
nginx.conf.j2
```

The gateway exposes the HTTP entry point while the application services remain behind the internal container networking model.

Conceptually:

```text
External Client
      │
      ▼
    Nginx
      │
      ▼
     API
```

This provides a controlled boundary between external traffic and internal application services.

---

# 22. Deployment Networking

The Compose runtime separates application traffic into:

```text
frontend-network
backend-network
```

The gateway and API participate in the frontend network.

The API and internal dependencies participate in the backend network.

The Worker is connected to the backend network.

The resulting model is:

```text
                    External
                       │
                       ▼
                  ┌─────────┐
                  │ Gateway │
                  └────┬────┘
                       │
                frontend-network
                       │
                       ▼
                  ┌─────────┐
                  │   API   │
                  └────┬────┘
                       │
                backend-network
             ┌─────────┼─────────┐
             ▼         ▼         ▼
          PostgreSQL Redis      MinIO
             ▲         ▲         ▲
             │         │         │
             └─────────┴────┬────┘
                            ▼
                         Worker
```

This network separation is part of the deployment security model.

---

# 23. Resource Constraints

The Compose deployment defines resource limits for application and infrastructure services.

Examples include:

```text
memory limits
CPU limits
```

These constraints prevent a single container from being allowed to consume unlimited host resources under normal configured conditions.

Resource constraints are particularly relevant for:

```text
API
Worker
PostgreSQL
Redis
Observability services
```

The Worker receives a larger resource allocation because background processing may be computationally heavier than request handling.

---

# 24. Restart Behavior

Core runtime services use restart policies intended to keep the service running after recoverable container-level interruptions.

However:

```text
Container restart
    ≠
Application recovery
```

A container may restart successfully while the application remains unable to serve traffic because a dependency is unavailable or configuration is invalid.

Therefore restart policy is only one layer of deployment resilience.

It must be combined with:

```text
health checks
observability
failure detection
operational response
```

---

# 25. Deployment Verification

A deployment should be considered successful only after the relevant runtime conditions have been verified.

Verification should include, where applicable:

```text
Container state
Service health
API liveness
API readiness
Worker availability
Dependency health
Metrics availability
Log availability
```

Conceptually:

```text
Deployment Completed
        │
        ▼
Runtime Verification
        │
        ├── Containers healthy
        ├── API ready
        ├── Worker observable
        ├── Dependencies reachable
        └── Metrics available
```

A successful Compose command alone is insufficient evidence.

---

# 26. Application Verification

For the API, verification should distinguish:

```text
Liveness
```

from:

```text
Readiness
```

The deployment should confirm that the API process is alive and that the service can satisfy its required dependency checks.

For the Worker, verification should include its process availability and metrics endpoint.

The Worker's ability to process jobs should be validated separately when the deployment validation scope requires functional verification.

---

# 27. Observability Verification

A deployment should not be considered operationally complete if the application is running but invisible to the observability platform.

The deployment architecture therefore provides:

```text
API
 │
 └── /metrics
       │
       ▼
   Prometheus

Worker
 │
 └── /metrics
       │
       ▼
   Prometheus

Containers / Host
 │
 ├── Node Exporter
 └── cAdvisor

Logs
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

The deployment verification process should therefore include observability checks where appropriate.

---

# 28. Deployment Failure

A deployment can fail at several layers.

## Infrastructure failure

```text
Host unavailable
Docker unavailable
Filesystem unavailable
Firewall / SSH problem
```

## Deployment control failure

```text
Runner unavailable
Deployment script failure
Configuration generation failure
```

## Application artifact failure

```text
Image unavailable
Incorrect image
Application startup failure
```

## Dependency failure

```text
PostgreSQL unavailable
Redis unavailable
MinIO unavailable
```

## Runtime failure

```text
Health check failure
Application crash
Worker failure
```

The deployment system should preserve enough evidence to distinguish these failure domains.

---

# 29. Failed Deployment Handling

When deployment verification fails, the system should not simply report:

```text
deployment failed
```

The investigation should determine:

```text
Where did deployment fail?
What artifact was being deployed?
Which service failed?
Was the failure detected during startup or after startup?
Was the previous release still available?
What does the deployment state record?
What do logs and metrics show?
```

This is why deployment state, logs, health checks, and observability are all part of the deployment architecture.

---

# 30. Rollback Model

Mini-Write maintains `current` and `previous` deployment references as the foundation for rollback-aware deployment.

The conceptual rollback model is:

```text
Current Release
      │
      ▼
Failure Detected
      │
      ▼
Identify Previous Release
      │
      ▼
Restore Previous Artifact
      │
      ▼
Redeploy
      │
      ▼
Verify Health
```

Rollback should not be considered complete until the restored release has been health-checked.

A rollback that only changes an image reference without verification does not establish recovery.

---

# 31. Rollback and Data Compatibility

Application rollback is not always equivalent to database rollback.

For example:

```text
Application Release A
       │
       ▼
Database Schema Change
       │
       ▼
Application Release B
```

Rolling the application back to A does not automatically revert the database schema.

Therefore future deployment evolution must explicitly consider:

```text
Backward-compatible migrations
Forward-compatible migrations
Application rollback
Data rollback
```

This is an important constraint on production-grade deployment design.

---

# 32. Idempotency

Infrastructure provisioning should be idempotent.

Running the Ansible provisioning process multiple times should converge the host toward the same desired state rather than continuously modifying it.

The deployment runtime should also avoid unnecessary destructive operations.

The desired model is:

```text
Desired State
     │
     ▼
Deployment
     │
     ▼
Actual State
     │
     ▼
Reconciliation
     │
     ▼
Desired State
```

This property is especially important when deployment automation is retried after partial failures.

---

# 33. Deployment Safety Boundaries

Deployment automation should preserve several safety boundaries.

### Configuration boundary

Do not overwrite sensitive configuration unnecessarily.

### Data boundary

Do not destroy persistent volumes as part of ordinary application deployment.

### State boundary

Do not corrupt deployment state when a deployment fails midway.

### Artifact boundary

Do not silently replace a release with an unverified artifact.

### Verification boundary

Do not mark a deployment successful before health validation.

These boundaries reduce the blast radius of deployment failures.

---

# 34. Deployment and Reliability

Deployment is directly connected to the project's Reliability architecture.

Reliability mechanisms protect runtime execution.

Deployment reliability protects transitions between runtime versions.

The relationship is:

```text
Deployment Reliability
        │
        ▼
Correct Artifact
        │
        ▼
Correct Configuration
        │
        ▼
Correct Startup
        │
        ▼
Health Verification
        │
        ▼
Runtime Reliability
```

A reliable application cannot compensate for an unsafe deployment process.

---

# 35. Deployment and Observability

Deployment events should be correlated with application behavior.

A useful operational timeline is:

```text
Deployment Started
       │
       ▼
New Version Started
       │
       ▼
Health Check
       │
       ▼
Traffic
       │
       ▼
Errors / Latency / Failures
```

This allows operators to answer questions such as:

```text
Did the incident begin after a deployment?
Which version was deployed?
Which service changed?
Did error rate increase after deployment?
Did dependency failures appear after the release?
```

This is one of the primary reasons deployment state and observability are integrated.

---

# 36. Deployment Traceability

Every deployment should be traceable to a source artifact.

At minimum, the deployment model should allow correlation between:

```text
Source Commit
      │
      ▼
Build
      │
      ▼
Container Image
      │
      ▼
Deployment
      │
      ▼
Runtime Version
```

The exact versioning convention is determined by the CI/CD implementation and should remain consistent across API and Worker artifacts.

The objective is reproducibility rather than relying on mutable tags whose meaning can change over time.

---

# 37. Deployment Reproducibility

A deployment should be reproducible from repository-controlled definitions plus the required protected secrets and external artifacts.

The major sources of deployment configuration are:

```text
Ansible
Docker Compose template
Environment configuration
Deployment scripts
Container images
CI/CD workflow
```

Manual host modifications should not become required hidden deployment dependencies.

If a deployment only works because an operator manually changed something on the host, that configuration belongs in Infrastructure as Code or deployment configuration.

---

# 38. Manual Changes

Manual production-like changes to the staging host should be treated cautiously.

A manual change creates the possibility of:

```text
Configuration drift
```

where:

```text
Repository definition
        ≠
Actual host state
```

The correct long-term solution is to encode the required state in the appropriate automation layer.

---

# 39. Deployment Security

Deployment security includes:

```text
SSH hardening
Firewall rules
Protected secrets
Runner authentication
Restricted filesystem permissions
Container isolation
Network segmentation
```

The Ansible `security_baseline` role establishes the host-level security foundation.

The deployment process must not bypass those controls merely to simplify deployment.

---

# 40. Deployment Permissions

Deployment-related filesystem paths are deliberately separated by ownership and mutability.

The architecture distinguishes:

```text
Immutable runtime directories
```

from:

```text
Mutable runtime directories
```

The deployment user owns paths that need operational mutation, while configuration and runtime definitions can remain root-owned where appropriate.

This limits unnecessary write access.

---

# 41. Deployment Observability Evidence

Useful deployment evidence includes:

```text
Deployment log
Deployment state
Container status
Container logs
Health endpoint responses
Prometheus target status
Application metrics
Worker metrics
Host metrics
Grafana dashboards
Alert state
```

These evidence sources should be used together during deployment validation.

No single source provides complete deployment confidence.

---

# 42. Deployment Lifecycle

The complete deployment lifecycle can be summarized as:

```text
┌───────────────────────┐
│ Source Change         │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ CI Validation         │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ Build Artifact        │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ Select Release        │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ Execute Deployment    │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ Start / Update        │
│ Runtime Services      │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│ Health Verification   │
└───────────┬───────────┘
            │
       ┌────┴─────┐
       │          │
       ▼          ▼
    Success     Failure
       │          │
       ▼          ▼
 Update State   Diagnose
       │          │
       ▼          ▼
 Operational   Rollback /
 Runtime       Remediation
```

---

# 43. Deployment Definition of Done

A deployment should be considered complete when:

```text
✓ Correct application artifacts are selected
✓ Required configuration is available
✓ Deployment executes successfully
✓ Containers reach the expected runtime state
✓ API liveness is healthy
✓ API readiness is healthy
✓ Worker is available
✓ Required dependencies are healthy
✓ Persistent state remains intact
✓ Deployment state reflects the successful release
✓ Deployment logs are available
✓ Metrics remain observable
✓ Relevant logs are available
✓ No unexpected critical alerts are active
```

The exact verification depth depends on the scope of the deployment.

---

# 44. Deployment Model Summary

Mini-Write uses a layered deployment architecture:

```text
                 Git Repository
                       │
                       ▼
                GitHub Actions
                       │
                       ▼
             Self-Hosted Runner
                       │
                       ▼
              Deployment Runtime
                       │
                       ▼
                 Docker Compose
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
        API          Worker      Gateway
          │            │
          └──────┬─────┘
                 │
       ┌─────────┼─────────┐
       ▼         ▼         ▼
   PostgreSQL  Redis      MinIO
                 │
                 ▼
          Observability
                 │
       ┌─────────┼─────────┐
       ▼         ▼         ▼
   Prometheus   Loki     Grafana
```

The architecture separates:

```text
Infrastructure
Application Artifacts
Configuration
Persistent State
Deployment Control
Runtime Verification
Observability
```

This separation allows Mini-Write to evolve from a simple Docker-based deployment toward more advanced deployment platforms without discarding the underlying operational principles.

---

# 45. Architectural Principle

The central deployment principle is:

> **A deployment is not successful because a command completed successfully; it is successful when the intended application state has been established, verified, observable, and traceable on the target runtime.**

```
```
