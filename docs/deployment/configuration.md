# Deployment Configuration

## 1. Purpose

This document defines how deployment configuration is structured, sourced, rendered, protected, and consumed by the Mini-Write staging runtime.

The objective is to make deployment configuration:

- explicit;
- reproducible;
- environment-aware;
- separated from application artifacts;
- protected when sensitive;
- observable;
- maintainable;
- resistant to configuration drift.

Mini-Write treats configuration as a first-class deployment concern.

The deployment model therefore separates:

```text
Application Artifact
        │
        ├── Container Image
        │
        ▼
Runtime Configuration
        │
        ├── Environment Variables
        ├── Compose Configuration
        ├── Proxy Configuration
        ├── Runtime Scripts
        └── Infrastructure Configuration
````

The same application artifact should be capable of operating under different environment configurations without requiring the application image itself to be rebuilt merely because configuration changed.

---

# 2. Configuration Architecture

Mini-Write configuration is distributed across several layers.

```text
┌──────────────────────────────────────────────┐
│ Ansible Variables / Vault                    │
│ Infrastructure & protected deployment input  │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│ Ansible Templates                            │
│ .j2 configuration definitions                │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│ Rendered Host Configuration                  │
│ /opt/deploy/...                              │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│ Docker Compose Runtime                      │
│ Environment + service configuration           │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│ Application / Infrastructure Services       │
└──────────────────────────────────────────────┘
```

This creates a clear distinction between:

```text
Configuration Source
```

and:

```text
Rendered Runtime Configuration
```

The host should consume the rendered configuration rather than requiring an operator to manually construct it.

---

# 3. Configuration Sources

The primary configuration sources are:

```text
infra/ansible/
    ├── playbooks/
    ├── roles/
    └── vault/

observability/
    ├── Prometheus/
    ├── loki/
    ├── promtail/
    ├── alertmanager/
    └── grafana/
```

Application-specific configuration is also defined within the API and Worker source trees where appropriate.

The important architectural rule is that each configuration belongs to the layer that owns the behavior it controls.

For example:

```text
Host configuration
    → Ansible

Docker runtime configuration
    → Compose template

Application runtime configuration
    → Environment variables

Observability configuration
    → observability/

Security configuration
    → Ansible security role
```

---

# 4. Configuration Ownership

Configuration ownership follows responsibility boundaries.

| Configuration                | Primary Owner                          |
| ---------------------------- | -------------------------------------- |
| Ubuntu package configuration | Ansible                                |
| Docker installation          | Ansible                                |
| Host security baseline       | Ansible                                |
| SSH hardening                | Ansible                                |
| Deployment directories       | Ansible                                |
| Compose runtime definition   | Ansible template                       |
| Nginx configuration          | Ansible template                       |
| Deployment scripts           | Ansible templates                      |
| Staging environment          | Ansible template + protected variables |
| Prometheus configuration     | Observability configuration            |
| Prometheus rules             | Observability configuration            |
| Loki configuration           | Observability configuration            |
| Promtail configuration       | Observability configuration            |
| Alertmanager configuration   | Observability configuration            |
| Grafana provisioning         | Observability configuration            |
| Application runtime behavior | Application code                       |
| Application secrets          | Protected configuration                |

This prevents configuration from becoming an unstructured collection of unrelated environment files.

---

# 5. Infrastructure Configuration

Infrastructure-level configuration is controlled by Ansible.

The main playbook is:

```text
infra/ansible/playbooks/site.yml
```

The playbook loads staging secrets through:

```yaml
vars_files:
  - ../vault/staging-secrets.yml
```

and applies the infrastructure roles:

```yaml
roles:
  - base
  - docker
  - deploy_runtime
  - github_runner
  - security_baseline
```

The configuration flow is therefore:

```text
site.yml
   │
   ├── Variables
   ├── Vault values
   │
   ▼
Ansible Roles
   │
   ▼
Templates / Tasks
   │
   ▼
Staging Host
```

---

# 6. Ansible Variables

Ansible variables provide the abstraction layer between deployment logic and environment-specific values.

Examples of variables used by the deployment roles include:

```text
base_packages
docker_packages
docker_apt_keyring_path
deploy_user
deploy_root
deploy_directories
runtime_subdirectory
deploy_scripts
deploy_runtime_modules
immutable_runtime_dirs
mutable_runtime_dirs
deployment_state_file
github_runner_install_dir
github_runner_download_url
github_runner_repo_url
github_runner_name
github_runner_labels
security_allowed_tcp_ports
```

The exact values are environment-specific and should not be hard-coded into tasks when they represent deployment policy or environment configuration.

---

# 7. Protected Configuration

Sensitive values are separated from ordinary infrastructure configuration.

The staging playbook references:

```text
infra/ansible/vault/staging-secrets.yml
```

The vault is responsible for protected values such as credentials and authentication material.

The architecture is:

```text
                 Ansible
                    │
          ┌─────────┴─────────┐
          │                   │
          ▼                   ▼
    Normal Variables      Vault Secrets
          │                   │
          └─────────┬─────────┘
                    ▼
             Rendered Config
                    │
                    ▼
              Runtime Host
```

Secrets must not be embedded directly into source-controlled templates unless the value itself is non-sensitive.

---

# 8. Environment Configuration

The staging environment file is:

```text
/opt/deploy/env/.env.staging
```

Its source template is:

```text
infra/ansible/roles/deploy_runtime/templates/env.staging.j2
```

Ansible creates this file only when it does not already exist:

```yaml
- name: Check staging env file
  ansible.builtin.stat:
    path: "{{ deploy_root }}/env/.env.staging"
  register: env_file

- name: Bootstrap staging env file
  ansible.builtin.template:
    src: env.staging.j2
    dest: "{{ deploy_root }}/env/.env.staging"
  when: not env_file.stat.exists
```

This behavior is important because the environment file represents mutable deployment state.

Infrastructure provisioning should not unnecessarily overwrite runtime configuration that may have been intentionally established on the host.

---

# 9. Environment File Permissions

The staging environment file is initially created with:

```text
0640
```

and is subsequently assigned to:

```text
owner: deploy_user
group: deploy_user
```

The resulting security model intentionally avoids making environment configuration world-readable.

Conceptually:

```text
.env.staging
    │
    ├── contains runtime configuration
    ├── may contain sensitive values
    │
    ▼
restricted filesystem permissions
```

This is especially important because Docker Compose consumes this file directly.

---

# 10. Docker Compose Configuration

The staging Compose definition is generated from:

```text
infra/ansible/roles/deploy_runtime/templates/docker-compose.staging.yml.j2
```

and rendered to:

```text
/opt/deploy/compose/docker-compose.staging.yml
```

The Compose template defines:

```text
networks
volumes
services
healthchecks
restart policies
resource limits
logging configuration
environment references
observability services
```

The template therefore represents the deployment topology rather than merely a list of containers.

---

# 11. Environment Variable Substitution

The Compose configuration uses environment variables for deployment-specific values.

Examples include:

```text
HTTP_PORT
API_IMAGE
WORKER_IMAGE
POSTGRES_USER
POSTGRES_DB
POSTGRES_PASSWORD
MINIO_ROOT_USER
MINIO_ROOT_PASSWORD
GRAFANA_ADMIN_PASSWORD
```

The pattern is:

```text
.env.staging
      │
      ▼
Docker Compose
      │
      ▼
Container Environment
```

This separates the Compose service definition from environment-specific values.

---

# 12. Application Images

Application images are configured through:

```text
API_IMAGE
WORKER_IMAGE
```

The Compose file references them as:

```yaml
api:
  image: ${API_IMAGE}
```

and:

```yaml
worker:
  image: ${WORKER_IMAGE}
```

This is an important separation:

```text
Compose Definition
       ≠
Application Version
```

The Compose definition describes how the service runs.

The image reference identifies which application artifact runs.

---

# 13. Runtime Configuration vs Build Configuration

Mini-Write distinguishes between:

### Build-time configuration

Values required to construct an artifact.

### Runtime configuration

Values required when executing the artifact.

The preferred model is:

```text
Source
   │
   ▼
Build
   │
   ▼
Immutable Image
   │
   ▼
Runtime Configuration
   │
   ▼
Running Container
```

Secrets and environment-specific operational values should generally belong to the runtime layer rather than being embedded into the image.

---

# 14. API Runtime Configuration

The API receives runtime configuration through its environment.

The Compose configuration explicitly sets:

```yaml
environment:
  - NODE_ENV=production
```

and loads additional values through:

```yaml
env_file:
  - /opt/deploy/env/.env.staging
```

The API therefore obtains configuration from:

```text
NODE_ENV
+
.env.staging
```

Application code consumes these values through `process.env`.

Examples include:

```text
HTTP_PORT
JWT_SECRET
JWT_EXPIRY
database configuration
storage configuration
Redis configuration
```

The exact application environment contract should remain documented in the environment-variable reference.

---

# 15. Worker Runtime Configuration

The Worker follows the same general configuration model as the API.

The Worker receives:

```yaml
env_file:
  - /opt/deploy/env/.env.staging
```

and its service-specific runtime behavior is configured through environment variables.

The Worker may additionally require configuration related to:

```text
queue
Redis
PostgreSQL
object storage
worker concurrency
runtime reliability
```

The Worker-specific environment contract should remain aligned with the Worker implementation rather than duplicating API assumptions.

---

# 16. Gateway Configuration

Nginx configuration is rendered by Ansible.

The source template is:

```text
infra/ansible/roles/deploy_runtime/templates/nginx.conf.j2
```

and the resulting file is:

```text
/opt/deploy/proxy/nginx.conf
```

The Gateway consumes this configuration through a read-only bind mount:

```yaml
volumes:
  - /opt/deploy/proxy/nginx.conf:/etc/nginx/nginx.conf:ro
```

The read-only mount establishes an explicit configuration boundary:

```text
Host Configuration
       │
       ▼
nginx.conf
       │
       ▼
Read-only Container Mount
       │
       ▼
Nginx
```

---

# 17. Runtime Networks

The Compose configuration defines:

```text
frontend-network
backend-network
```

The configuration of network membership is part of the deployment topology.

The external-facing path is:

```text
Client
  │
  ▼
Gateway
  │
  ▼
API
```

while internal dependencies are connected through the backend network.

Network membership should therefore be treated as deployment configuration with security implications, not merely as Docker syntax.

---

# 18. Persistent Volumes

The deployment configuration defines named Docker volumes:

```text
postgres_data
redis_data
minio_data
prometheus_data
grafana_data
loki_data
alertmanager_data
```

These are mapped to stable names:

```text
miniwrite_postgres_data
miniwrite_redis_data
miniwrite_minio_data
miniwrite_prometheus_data
miniwrite_grafana_data
miniwrite_loki_data
miniwrite_alertmanager_data
```

The purpose is to decouple persistent state from container identity.

For example:

```text
PostgreSQL Container
       │
       ▼
miniwrite_postgres_data
```

Recreating the PostgreSQL container does not inherently recreate the database data.

---

# 19. Resource Configuration

Runtime resource constraints are part of Compose configuration.

Examples include:

```yaml
mem_limit: 512m
cpus: "0.5"
```

Different services receive different limits according to their operational role.

For example:

```text
Gateway       → lightweight
API           → moderate
Worker        → heavier
Redis         → moderate
PostgreSQL    → moderate
Observability → individually constrained
```

Resource limits are therefore part of the runtime contract.

Changing them can alter system behavior and should be treated as an architectural configuration change rather than a cosmetic modification.

---

# 20. Health Check Configuration

Health checks are defined directly in the Compose service configuration.

Examples:

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

The configuration establishes:

```text
Process State
    │
    ▼
Health Check
    │
    ▼
Service Health
```

Health check configuration should remain consistent with the actual runtime contract exposed by each service.

---

# 21. Restart Configuration

Core services use:

```yaml
restart: always
```

This configuration establishes container-level restart behavior.

It should not be interpreted as a complete recovery mechanism.

Instead:

```text
Restart Policy
     +
Health Check
     +
Observability
     +
Reliability Runtime
```

forms the broader runtime resilience model.

---

# 22. Logging Configuration

Application containers use Docker's JSON logging driver.

The deployment configuration limits retained log volume:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

The objective is to prevent uncontrolled Docker log growth.

The resulting path is:

```text
Container stdout/stderr
        │
        ▼
Docker JSON logs
        │
        ▼
Promtail
        │
        ▼
Loki
```

This configuration is therefore simultaneously:

* runtime configuration;
* storage protection;
* observability configuration.

---

# 23. Observability Configuration

Observability configuration is maintained separately from application source.

The main structure is:

```text
observability/
├── Prometheus/
├── loki/
├── promtail/
├── alertmanager/
└── grafana/
```

The deployment role synchronizes this configuration into:

```text
/opt/deploy/compose/observability/
```

through the Ansible `copy` task.

This creates:

```text
Repository Observability Configuration
             │
             ▼
         Ansible
             │
             ▼
      /opt/deploy/compose/
             │
             ▼
      Observability Containers
```

---

# 24. Prometheus Configuration

The Prometheus configuration defines:

```text
scrape interval
evaluation interval
external labels
rule files
Alertmanager target
scrape jobs
```

The main jobs include:

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

The deployment configuration therefore determines what operational signals are collected from the platform.

---

# 25. Prometheus Rules

Alert rules are stored under:

```text
observability/Prometheus/rules/
```

Current rule groups cover areas such as:

```text
infrastructure
API
Worker
```

These rules convert metrics into operational signals.

Conceptually:

```text
Metric
  │
  ▼
PromQL Rule
  │
  ▼
Alert
  │
  ▼
Alertmanager
```

Alert thresholds are therefore configuration with direct operational consequences.

---

# 26. Loki Configuration

Loki configuration defines the log storage and retention behavior.

Important configuration concepts include:

```text
schema
storage
retention
ingestion limits
query limits
compaction
```

The current configuration uses filesystem-backed storage appropriate to the single-node deployment model.

The retention policy is configured for a finite period rather than unlimited log retention.

---

# 27. Promtail Configuration

Promtail is configured to collect:

```text
Docker container logs
Deployment logs
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
```

This configuration is important because logging configuration directly affects Loki storage volume and query performance.

---

# 28. High-Cardinality Configuration

Promtail explicitly avoids promoting fields such as:

```text
correlation_id
job_id
deployment_version
```

into Loki labels.

This is an intentional configuration decision.

High-cardinality labels can cause excessive series creation.

The configuration therefore separates:

```text
Searchable structured field
```

from:

```text
Indexed Loki label
```

This distinction is important for observability scalability.

---

# 29. Alertmanager Configuration

Alertmanager configuration defines:

```text
routing
grouping
receiver selection
repeat intervals
inhibition
```

Alerts are grouped by:

```text
environment
category
service
```

and routed according to severity.

The current model distinguishes:

```text
critical
warning
info
```

This configuration determines how alert signals are organized before external notification integrations are added.

---

# 30. Grafana Datasource Configuration

Grafana datasources are provisioned automatically.

The configured datasources are:

```text
Prometheus
Loki
```

Prometheus is configured as the default datasource.

The configuration points Grafana to the internal Compose services:

```text
http://prometheus:9090
http://loki:3100
```

This means Grafana does not depend on host-exposed ports to communicate with the observability backend.

---

# 31. Grafana Dashboard Configuration

Grafana dashboards are provisioned from files.

The configured folders include:

```text
System
Application
Queue
Deployment
Incidents
```

The dashboard provider configuration disables UI-based updates:

```yaml
allowUiUpdates: false
```

and enables file-based provisioning.

This establishes the repository as the source of truth for dashboard definitions.

The model is:

```text
Git
 │
 ▼
Dashboard JSON
 │
 ▼
Ansible
 │
 ▼
Grafana
```

rather than:

```text
Operator
   │
   ▼
Manual Grafana Editing
```

---

# 32. Configuration Immutability

Configuration has different mutability levels.

### Immutable or controlled configuration

Examples:

```text
Compose topology
Prometheus scrape jobs
Alert rules
Grafana provisioning
Loki configuration
Promtail pipelines
```

These should normally be changed through Git and deployment automation.

### Mutable runtime state

Examples:

```text
deployment_state.json
deployment logs
persistent databases
queues
object storage
```

These should not be treated as ordinary source-controlled configuration.

This distinction prevents runtime state from being confused with declarative configuration.

---

# 33. Configuration Drift

Configuration drift occurs when:

```text
Repository Configuration
        ≠
Host Configuration
```

Examples include:

```text
manually modified Compose file
manually modified Nginx configuration
manually modified Prometheus rules
manually modified environment configuration
```

Drift is dangerous because future provisioning or deployment may produce unexpected behavior.

The preferred correction is:

```text
Detect Drift
    │
    ▼
Identify Intended State
    │
    ▼
Update Source Configuration
    │
    ▼
Re-provision
    │
    ▼
Verify
```

Manual changes should not become permanent undocumented state.

---

# 34. Configuration Change Lifecycle

A configuration change should follow a controlled lifecycle:

```text
Configuration Change
        │
        ▼
Identify Owner
        │
        ▼
Modify Source
        │
        ▼
Validate Syntax
        │
        ▼
Review
        │
        ▼
Deploy
        │
        ▼
Verify Runtime
        │
        ▼
Observe
```

The appropriate validation depends on the configuration type.

Examples:

```text
YAML
    → syntax validation

Prometheus
    → configuration validation

Nginx
    → nginx configuration test

Docker Compose
    → Compose configuration validation

Ansible
    → syntax / check mode

Grafana
    → provisioning validation
```

---

# 35. Configuration Validation

Configuration should be validated before being considered deployable.

The principle is:

```text
Parseable
    ≠
Correct
```

For example, valid YAML can still contain:

```text
incorrect endpoint
wrong port
invalid service name
incorrect label
wrong environment value
```

Therefore validation should include both:

```text
Syntax Validation
```

and, where possible:

```text
Semantic / Runtime Validation
```

---

# 36. Configuration and Secrets

Sensitive configuration requires a stricter lifecycle.

The preferred flow is:

```text
Secret Source
     │
     ▼
Ansible Vault / Protected CI Secret
     │
     ▼
Template Rendering
     │
     ▼
Restricted Runtime File
     │
     ▼
Container Environment
```

Secrets should not be exposed through:

```text
Git commits
debug output
deployment logs
container image layers
public documentation
```

The deployment process should also avoid unnecessary secret propagation.

---

# 37. Secret Exposure Boundaries

Secrets can cross several boundaries:

```text
Vault
  │
  ▼
Ansible
  │
  ▼
Rendered Environment File
  │
  ▼
Docker Compose
  │
  ▼
Container
```

Each boundary increases the potential exposure surface.

Therefore:

* use `no_log` where sensitive task output may appear;
* restrict environment file permissions;
* avoid logging secret values;
* avoid embedding secrets into images;
* avoid placing secrets in dashboard definitions;
* avoid placing secrets into source-controlled configuration.

---

# 38. Configuration and CI/CD

CI/CD should provide artifact and deployment inputs without becoming the permanent owner of infrastructure configuration.

The intended separation is:

```text
Git Repository
    │
    ├── Application source
    ├── Infrastructure code
    ├── Deployment templates
    └── Observability configuration
             │
             ▼
          CI/CD
             │
             ▼
      Deployment Execution
```

The CI system orchestrates the deployment.

It should not silently invent configuration that is absent from the repository's declared architecture.

---

# 39. Environment Separation

The deployment architecture should support environment-specific configuration without duplicating application logic.

Conceptually:

```text
                  Application Image
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
      Development     Staging     Production
          │             │             │
       Config A       Config B       Config C
```

The application artifact remains conceptually independent from the environment.

The current project explicitly operates with a staging deployment model.

Future environments should therefore extend the configuration model rather than introduce unrelated configuration mechanisms.

---

# 40. Configuration Precedence

When multiple configuration mechanisms exist, precedence must be explicit.

A useful conceptual hierarchy is:

```text
Application Defaults
        │
        ▼
Environment Configuration
        │
        ▼
Deployment-specific Values
        │
        ▼
Runtime Environment
```

However, precedence must always follow the actual behavior of the application, Docker Compose, and Ansible implementation.

Documentation should never claim a precedence rule that is not implemented.

---

# 41. Configuration Defaults

Defaults are useful when they provide safe behavior.

Examples include Compose defaults such as:

```text
HTTP_PORT:-80
```

A default should satisfy:

```text
Safe
Predictable
Environment-appropriate
Non-destructive
```

Defaults should not silently hide missing critical configuration.

For security-sensitive values, requiring explicit configuration is generally preferable to silently selecting an insecure default.

---

# 42. Configuration Naming

Configuration names should describe the behavior they control.

Examples:

```text
API_IMAGE
WORKER_IMAGE
GRAFANA_ADMIN_PASSWORD
POSTGRES_DB
POSTGRES_USER
POSTGRES_PASSWORD
MINIO_ROOT_USER
MINIO_ROOT_PASSWORD
```

Names should be:

* stable;
* explicit;
* consistent;
* service-oriented;
* free of unnecessary ambiguity.

Changing an environment variable name is a compatibility change because application code and deployment configuration may both depend on it.

---

# 43. Configuration Versioning

Configuration changes are version-controlled with the project source.

This provides:

```text
History
Review
Diffs
Rollback reference
Traceability
```

A configuration change should therefore be associated with a commit.

The operational question becomes:

```text
Which configuration was active?
```

rather than:

```text
What did someone manually configure on the host?
```

---

# 44. Configuration and Deployment State

Configuration and deployment state are related but different.

```text
Configuration
    → describes how the system should run
```

while:

```text
Deployment State
    → records what was deployed
```

For example:

```text
API_IMAGE = registry/...:vX
```

is configuration.

Whereas:

```text
current.api = registry/...:vX
```

is deployment state.

This distinction is important for deployment traceability and rollback.

---

# 45. Configuration and Runtime Reliability

Reliability behavior itself may be influenced by configuration.

For example, the API Runtime contains policies for:

```text
timeout
retry
maxRetries
recoverable
```

These are currently represented in application runtime policy definitions rather than the deployment environment.

This is an intentional distinction:

```text
Deployment Configuration
        │
        ▼
Infrastructure / Environment Behavior
```

versus:

```text
Runtime Reliability Policy
        │
        ▼
Application Execution Behavior
```

The two should not be merged merely because both contain configurable values.

---

# 46. Configuration and Security Baseline

Security configuration exists at multiple layers.

### Host layer

Managed by:

```text
security_baseline
```

Examples:

```text
UFW
SSH hardening
root login policy
password authentication policy
public key authentication
```

### Container layer

Managed through:

```text
Compose
```

Examples:

```text
network isolation
read-only configuration mounts
resource limits
service exposure
```

### Application layer

Managed by:

```text
application configuration
```

Examples:

```text
JWT configuration
database credentials
storage credentials
```

Security configuration should therefore be reviewed across all layers rather than assuming that host hardening alone provides deployment security.

---

# 47. Configuration and Networking

Network configuration is part of the deployment security boundary.

The Compose configuration determines:

```text
Which service can reach which network
Which ports are exposed to the host
Which services remain internal
```

For example, the backend network is used by internal application dependencies.

Network configuration should therefore be changed only with awareness of:

```text
service dependencies
security implications
observability requirements
failure propagation
```

---

# 48. Configuration and Observability

Every important configuration change should have an observable effect where appropriate.

Examples:

```text
Resource limit change
    → host/container metrics

Alert threshold change
    → alert behavior

Log pipeline change
    → Loki ingestion

Scrape configuration change
    → Prometheus targets

Dashboard change
    → Grafana visualization
```

Configuration should therefore be evaluated not only by whether the service starts, but also by whether the resulting operational behavior is visible.

---

# 49. Configuration Failure Modes

Common configuration failure modes include:

### Missing variable

```text
Required environment variable absent
```

### Invalid variable

```text
Value has incorrect format
```

### Wrong service reference

```text
api:80
```

configured incorrectly relative to the actual service.

### Secret mismatch

```text
Application credential
        ≠
Dependency credential
```

### Configuration drift

```text
Repository
        ≠
Host
```

### Stale configuration

A previously rendered configuration remains active after the intended source configuration changed.

### Configuration collision

Two layers attempt to define the same behavior with different values.

---

# 50. Configuration Troubleshooting

When a configuration-related failure occurs, investigate in this order:

```text
1. Identify the affected service
2. Identify the configuration source
3. Inspect rendered configuration
4. Verify environment variables
5. Verify service dependencies
6. Validate configuration syntax
7. Inspect container logs
8. Inspect health checks
9. Inspect Prometheus metrics
10. Compare repository state with host state
```

The key question is:

```text
Where did the effective configuration come from?
```

rather than simply:

```text
What configuration exists in Git?
```

---

# 51. Configuration Change Safety

Before changing configuration, determine:

```text
What component owns it?
What depends on it?
Is it sensitive?
Is it persistent?
Is restart required?
Is the change backward-compatible?
How will the change be verified?
How will it be rolled back?
```

A configuration change should have a clear rollback path.

For example:

```text
Old Configuration
       │
       ▼
New Configuration
       │
       ▼
Validation
       │
   ┌───┴───┐
   │       │
 Success  Failure
   │       │
   ▼       ▼
Keep     Restore
```

---

# 52. Configuration Documentation Rules

Configuration documentation should describe:

1. **What the value controls**
2. **Who owns it**
3. **Where it is defined**
4. **Where it is rendered**
5. **Who consumes it**
6. **Whether it is sensitive**
7. **Whether a restart is required**
8. **How it is validated**
9. **What failure looks like**
10. **How it is safely changed**

This prevents the documentation from becoming a simple list of variable names without operational meaning.

---

# 53. Configuration Reference Boundary

This document explains the configuration architecture and lifecycle.

It does not attempt to become the complete variable catalogue.

The authoritative detailed variable reference belongs to:

```text
docs/reference/environment-variables.md
```

Similarly:

```text
docs/reference/configuration-reference.md
```

should provide the consolidated configuration reference across infrastructure, deployment, runtime, and observability.

This separation keeps this document architectural rather than turning it into an unmaintainable dump of configuration values.

---

# 54. Configuration Definition of Done

A configuration change is considered complete when:

```text
✓ Correct configuration owner is identified
✓ Source configuration is updated
✓ Sensitive values remain protected
✓ Syntax is validated
✓ Configuration is rendered correctly
✓ Runtime consumes the intended values
✓ Required services start correctly
✓ Health checks remain healthy
✓ Observability remains functional
✓ No unintended configuration drift is introduced
✓ Change is traceable to version-controlled source
✓ Rollback path is understood
```

---

# 55. Configuration Model Summary

Mini-Write uses a layered configuration architecture:

```text
                 Source Control
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Ansible      Compose      Observability
       Variables    Templates    Configuration
          │            │            │
          └────────────┼────────────┘
                       ▼
                Rendered Runtime
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Host         Containers    Services
       Config       Config        Config
                       │
                       ▼
                 Runtime Behavior
```

The central rule is:

> **Configuration is a versioned, owned, validated deployment input that must produce predictable runtime behavior without embedding environment-specific state into immutable application artifacts.**

```
```
