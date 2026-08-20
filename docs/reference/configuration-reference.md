# Configuration Reference

## 1. Purpose

This document is the authoritative reference for how Mini-Write configuration is structured, where configuration is defined, how it is supplied to services, and which configuration domains affect system behavior.

The purpose of this document is not to reproduce every configuration file.

Instead, it defines the configuration model and provides a navigable reference to the major configuration surfaces of the platform.

Mini-Write follows a configuration model based on:

```text
Repository Configuration
        │
        ├── Infrastructure Configuration
        ├── Application Configuration
        ├── Observability Configuration
        ├── Deployment Configuration
        └── Runtime Configuration
                │
                ▼
        Docker / Ansible
                │
                ▼
        Running Services
````

Configuration should remain:

* explicit
* reproducible
* version-controlled where appropriate
* environment-aware
* separated from secrets
* consumed consistently by the runtime

---

# 2. Configuration Architecture

Mini-Write configuration is distributed across several architectural layers.

```text
                    Configuration
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
       ▼                 ▼                 ▼
 Infrastructure      Application      Observability
       │                 │                 │
       ▼                 ▼                 ▼
    Ansible          Node.js ENV      Prometheus/Loki
    Docker           Runtime          Grafana
    Compose          Policies         Alertmanager
       │                 │                 │
       └─────────────────┼─────────────────┘
                         ▼
                    Deployment
                         │
                         ▼
                  Running Platform
```

Each layer has a different responsibility.

---

# 3. Configuration Domains

The major configuration domains are:

| Domain         | Primary Responsibility                  |
| -------------- | --------------------------------------- |
| Infrastructure | Host and platform configuration         |
| Docker         | Container execution configuration       |
| Application    | API and Worker behavior                 |
| Runtime        | Reliability and execution policies      |
| Deployment     | Release and deployment behavior         |
| Observability  | Metrics, logs, alerts, dashboards       |
| Security       | Security-related platform behavior      |
| Environment    | Environment-specific values and secrets |

These domains should not be collapsed into a single configuration mechanism.

---

# 4. Configuration Sources

The repository contains several classes of configuration sources.

Typical locations include:

```text
mini-write/
│
├── api/
│   └── ...
│
├── worker/
│   └── ...
│
├── infra/
│   └── ansible/
│
├── observability/
│   ├── Prometheus/
│   ├── loki/
│   ├── promtail/
│   ├── alertmanager/
│   └── grafana/
│
├── docker-compose.yml
│
└── ...
```

The exact file responsible for a setting depends on the configuration domain.

---

# 5. Version-Controlled Configuration

Configuration that defines architecture or reproducible platform behavior should normally be version-controlled.

Examples include:

```text
Docker Compose configuration
Ansible roles
Prometheus configuration
Prometheus alert rules
Loki configuration
Promtail configuration
Alertmanager configuration
Grafana provisioning
Grafana dashboard definitions
Runtime reliability policies
```

This provides:

```text
Reproducibility
      +
Auditability
      +
Reviewability
      +
Rollback
```

---

# 6. Environment-Specific Configuration

Values that vary between environments should not be hard-coded into application logic.

Mini-Write uses environment variables for runtime configuration.

Examples visible in the application implementation include:

```text
NODE_ENV
APP_VERSION
HTTP_PORT
JWT_SECRET
JWT_EXPIRY
```

The application uses:

```js
process.env
```

to consume these values.

Environment-specific configuration should therefore be supplied by the deployment environment rather than embedded directly into source code.

---

# 7. Secrets

Secrets must be treated separately from ordinary configuration.

Examples include:

```text
JWT_SECRET
database credentials
Redis credentials
object-storage credentials
other authentication credentials
```

Secrets must not be committed to Git.

The repository should contain configuration structure and references to required variables, but not actual production secret values.

A useful separation is:

```text
Repository
    │
    ├── configuration structure
    ├── defaults
    └── required variable definitions
             │
             ▼
Environment
    │
    └── secret values
```

---

# 8. Application Configuration

The API and Worker are Node.js services and consume configuration through environment variables.

The application configuration controls areas such as:

```text
Network binding
Environment identity
Application version
Authentication
Database connectivity
Redis connectivity
Object storage connectivity
Worker behavior
```

The exact configuration consumed by each component should be documented in:

```text
docs/reference/environment-variables.md
```

This document should be treated as the architectural overview of configuration rather than the complete environment-variable catalog.

---

# 9. API Configuration

The API exposes HTTP configuration through:

```js
process.env.HTTP_PORT
```

with the application implementation providing a fallback:

```text
80
```

Therefore the effective API port follows:

```text
HTTP_PORT
    │
    ├── configured
    │      → use configured value
    │
    └── absent
           → use 80
```

The API also consumes:

```text
NODE_ENV
APP_VERSION
JWT_SECRET
JWT_EXPIRY
```

and infrastructure connection configuration used by the database, Redis, and object-storage clients.

---

# 10. Worker Configuration

The Worker has its own runtime configuration because its execution model differs from the API.

Worker-specific configuration includes areas such as:

```text
Redis connection
Queue configuration
Worker concurrency
Object storage
Database
Runtime behavior
```

The Worker runtime should not be configured by copying API configuration blindly.

The configuration model is shared conceptually but adapted to the Worker execution environment.

---

# 11. Application Environment Identity

The application observability layer uses:

```text
NODE_ENV
APP_VERSION
```

to establish environment and version identity.

For example, the metrics registry uses:

```js
environment: process.env.NODE_ENV || 'development'
version: process.env.APP_VERSION || '1.0.0'
```

This information is attached to application telemetry.

Therefore environment and version configuration are not merely application settings; they also affect observability.

---

# 12. Configuration and Observability

Configuration affects the identity of telemetry.

The application registry establishes labels including:

```text
service
environment
version
```

For the API:

```text
service = api
```

For the Worker, the corresponding implementation is adapted to:

```text
service = worker
```

This enables queries and dashboards to distinguish telemetry belonging to different services and environments.

---

# 13. Docker Configuration

Docker Compose defines the container-level execution environment.

Its responsibilities include:

```text
services
networks
volumes
ports
environment
dependencies
container configuration
monitoring services
```

The Compose architecture separates the application network into:

```text
frontend-network
backend-network
```

and defines persistent volumes for stateful services such as:

```text
postgres_data
redis_data
minio_data
```

The observability stack also has its own persistent/service configuration as defined by the Compose deployment.

---

# 14. Docker Environment Injection

The general configuration flow is:

```text
Environment / Deployment Configuration
              │
              ▼
       Docker Compose
              │
              ▼
       Container Environment
              │
              ▼
        Node.js process
              │
              ▼
          process.env
```

This allows the same application image to operate with different configuration values without changing application source code.

---

# 15. Ansible Configuration

Ansible is the infrastructure-as-code mechanism used by Mini-Write.

Infrastructure configuration is organized under:

```text
infra/ansible/
```

The architecture includes roles such as:

```text
base
deploy_runtime
docker
github_runner
security_baseline
```

These roles are responsible for different infrastructure concerns rather than placing the entire host configuration into a single automation unit.

---

# 16. Ansible and Application Configuration

Ansible should be understood as the mechanism that establishes the deployment environment.

Conceptually:

```text
Ansible
   │
   ├── Host
   ├── Docker
   ├── Deployment directories
   ├── Security baseline
   └── Runtime prerequisites
          │
          ▼
      Docker Compose
          │
          ▼
       Services
```

Ansible therefore establishes the conditions under which application configuration is consumed.

---

# 17. Deployment State Configuration

The deployment system maintains deployment state using:

```text
deployment_state.json
```

or its template:

```text
deployment_state.json.j2
```

The current template has the following logical structure:

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

This represents two deployment generations:

```text
current
   │
   ├── api
   └── worker

previous
   │
   ├── api
   └── worker
```

The purpose is to preserve deployment-version state independently for the API and Worker.

---

# 18. Configuration Versus Deployment State

Deployment state should not be confused with application configuration.

Configuration answers:

```text
How should the service run?
```

Deployment state answers:

```text
What version is currently deployed?
What version was deployed previously?
```

Therefore:

```text
Configuration
    ≠
Deployment State
```

They interact during deployment but represent different concepts.

---

# 19. Runtime Configuration

The Reliability Runtime contains configuration that determines operational behavior for individual operations.

Runtime policies include parameters such as:

```text
timeout
retry
maxRetries
recoverable
```

The API currently defines operation-specific policies.

For example:

```text
user_login
user_register
user_profile
id_upload
health_liveness
health_readiness
```

Each operation can resolve to a dedicated reliability policy.

---

# 20. Default Runtime Policy

The Runtime defines a default policy:

```text
id: default
name: Default Reliability Policy
timeout: 5000
retry: false
maxRetries: 0
recoverable: false
```

The default policy provides a safe fallback when an operation does not have a dedicated policy.

The resolution model is:

```text
Operation ID
     │
     ▼
Policy Resolver
     │
     ├── known operation
     │       → operation policy
     │
     └── unknown / missing
             → default policy
```

---

# 21. Operation-Specific Runtime Configuration

The current API Runtime defines policies including:

| Operation          |  Timeout | Retry | Max Retries | Recoverable |
| ------------------ | -------: | ----: | ----------: | ----------: |
| `user_login`       |  5000 ms |    No |           0 |          No |
| `user_register`    |  5000 ms |    No |           0 |          No |
| `user_profile`     |  3000 ms |    No |           0 |          No |
| `id_upload`        | 10000 ms |   Yes |           2 |         Yes |
| `health_liveness`  |  1000 ms |    No |           0 |          No |
| `health_readiness` |  3000 ms |    No |           0 |          No |

These values represent Runtime reliability policy rather than infrastructure configuration.

---

# 22. Retry Configuration

Retry behavior is controlled by the resolved Runtime policy.

When enabled, the Runtime determines:

```text
retry enabled
max retries
failure retryability
```

The retry executor also applies exponential backoff.

The current backoff calculation is bounded by:

```text
100 ms
200 ms
400 ms
...
maximum 1000 ms
```

The actual retry decision depends on both:

```text
Policy
+
Failure Classification
```

Therefore setting:

```text
retry = true
```

does not mean every failure is retried.

---

# 23. Timeout Configuration

Runtime timeout is configured per operation.

For example:

```text
Health Liveness
    → 1000 ms

Health Readiness
    → 3000 ms

User Login
    → 5000 ms

User Registration
    → 5000 ms

User Profile
    → 3000 ms

ID Upload
    → 10000 ms
```

Timeout behavior is implemented by the Runtime rather than by individual controllers.

This centralizes timeout semantics.

---

# 24. Failure Classification Configuration

Runtime failure classification defines categories such as:

```text
timeout
dependency
validation
authentication
authorization
internal
```

Transient dependency error codes include:

```text
ECONNRESET
ECONNREFUSED
EHOSTUNREACH
ENETUNREACH
EADDRNOTAVAIL
ETIMEDOUT
RUNTIME_TIMEOUT
```

Classification determines whether a failure is:

```text
recoverable
retryable
```

This configuration is part of Runtime behavior and should therefore be changed carefully.

---

# 25. Infrastructure Dependencies

The Runtime identifies infrastructure dependencies through:

```text
POSTGRESQL
REDIS
MINIO
```

These are represented by:

```text
DEPENDENCIES
```

in:

```text
api/src/runtime/infrastructure/dependencies.js
```

The dependency identity is used by the infrastructure boundary and reliability subsystem.

---

# 26. Infrastructure Operation Configuration

Infrastructure operations pass through:

```text
executeInfrastructureOperation()
```

This creates a standardized execution boundary around operations involving:

```text
PostgreSQL
Redis
MinIO
```

The boundary connects configuration and Runtime behavior:

```text
Application Operation
        │
        ▼
Infrastructure Boundary
        │
        ▼
Dependency
        │
        ▼
Reliability Policy
        │
        ├── Timeout
        ├── Retry
        └── Failure Classification
```

---

# 27. Prometheus Configuration

Prometheus configuration is located under:

```text
observability/Prometheus/
```

The main configuration file is:

```text
prometheus.yml
```

It defines:

```text
scrape interval
evaluation interval
external labels
rule files
Alertmanager integration
scrape targets
```

The global configuration currently uses:

```text
scrape_interval: 30s
evaluation_interval: 30s
```

---

# 28. Prometheus Environment Identity

Prometheus defines external labels:

```yaml
project: mini-write
environment: staging
```

These labels establish the monitoring-system identity.

This is distinct from the application environment labels.

The architectural model is:

```text
Prometheus
    │
    └── environment = staging

Application
    │
    └── NODE_ENV = configured application environment
```

These values should be kept semantically consistent.

If they diverge intentionally, the reason should be documented.

---

# 29. Prometheus Scrape Configuration

The current Prometheus configuration monitors:

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

The main application targets are:

```text
api:80
worker:9464
```

The API exposes:

```text
/metrics
```

and the Worker exposes its metrics endpoint on its configured metrics port.

---

# 30. Prometheus Rule Configuration

Alert rules are stored under:

```text
observability/Prometheus/rules/
```

Current rule groups include:

```text
01-infrastructure.yml
02-api.yml
03-worker.yml
```

These rules define operational thresholds for:

```text
host availability
CPU
memory
disk
API availability
API error rate
API latency
Worker availability
queue backlog
job failure rate
job latency
storage latency
database latency
```

---

# 31. Loki Configuration

Loki configuration is located at:

```text
observability/loki/config.yml
```

The current architecture uses:

```text
filesystem
```

storage with:

```text
retention_period: 168h
```

which corresponds to:

```text
7 days
```

Loki therefore provides short-term centralized log retention appropriate for the current local/staging-oriented deployment.

---

# 32. Promtail Configuration

Promtail configuration is located at:

```text
observability/promtail/config.yml
```

Promtail collects:

```text
Docker container logs
deployment logs
```

and sends them to:

```text
http://loki:3100/loki/api/v1/push
```

The Docker log pipeline parses:

```text
Docker JSON
```

and extracts fields such as:

```text
level
service
correlation_id
job_id
deployment_version
```

Only selected low-cardinality fields are promoted to Loki labels.

---

# 33. Log Label Configuration

Promtail promotes:

```text
level
service
```

as labels.

High-cardinality fields such as:

```text
correlation_id
job_id
deployment_version
```

are explicitly removed from the label set.

This is an important configuration constraint because Loki label cardinality directly affects operational cost and query performance.

The design is:

```text
Structured Log Fields
        │
        ├── low cardinality
        │       → labels
        │
        └── high cardinality
                → log fields
```

---

# 34. Alertmanager Configuration

Alertmanager configuration is located at:

```text
observability/alertmanager/alertmanager.yml
```

The current routing model separates alerts by:

```text
critical
warning
info
```

The route groups alerts by:

```text
environment
category
service
```

This prevents every alert from becoming an isolated notification.

---

# 35. Alertmanager Inhibition

The configuration suppresses warning alerts when a critical alert exists for the same:

```text
service
environment
```

The intended model is:

```text
Critical Incident
       │
       ├── Critical alert
       │
       └── Related warning alerts
                 │
                 ▼
              inhibited
```

This reduces alert noise during larger incidents.

---

# 36. Grafana Datasource Configuration

Grafana datasources are provisioned through:

```text
observability/grafana/provisioning/datasources/datasources.yml
```

The current datasources are:

```text
Prometheus
Loki
```

Prometheus is configured as the default datasource.

---

# 37. Grafana Dashboard Configuration

Dashboard providers are defined in:

```text
observability/grafana/provisioning/dashboards/dashbords.yml
```

The configured folders are:

```text
System
Application
Queue
Deployment
Incidents
```

Dashboard provisioning uses:

```text
disableDeletion: true
allowUiUpdates: false
```

This makes the repository-managed dashboard definition authoritative.

---

# 38. Configuration Ownership

Configuration ownership should follow the architectural boundary of the setting.

| Configuration         | Owner                |
| --------------------- | -------------------- |
| Host configuration    | Ansible              |
| Docker execution      | Docker Compose       |
| API runtime values    | API environment      |
| Worker runtime values | Worker environment   |
| Reliability policy    | Runtime              |
| Metrics collection    | Prometheus           |
| Logs collection       | Promtail             |
| Log storage           | Loki                 |
| Alert routing         | Alertmanager         |
| Visualization         | Grafana              |
| Dashboard definitions | Git repository       |
| Deployment state      | Deployment subsystem |

This prevents configuration responsibilities from becoming ambiguous.

---

# 39. Configuration Precedence

Configuration should be interpreted according to the mechanism that owns it.

A simplified model is:

```text
Architecture Defaults
        │
        ▼
Application Defaults
        │
        ▼
Environment Configuration
        │
        ▼
Container Environment
        │
        ▼
Runtime
```

However, not every configuration domain follows this exact precedence.

For example, a Runtime reliability policy is resolved by application code rather than by Docker environment variables.

Therefore precedence must always be understood within the configuration domain.

---

# 40. Configuration and Defaults

Defaults are useful when they represent safe operational behavior.

Examples include:

```text
HTTP_PORT → 80
NODE_ENV → development
APP_VERSION → 1.0.0
```

Runtime also defines a default reliability policy.

Defaults should not silently replace required production configuration.

In particular, security-sensitive values should not receive insecure implicit defaults.

---

# 41. Configuration Validation

Configuration should be validated at the boundary where it is consumed.

Examples:

```text
Application
    → validate required environment values

Runtime
    → validate policy structure

Ansible
    → validate infrastructure assumptions

Prometheus
    → validate configuration and rules

Grafana
    → validate datasource and dashboard provisioning
```

A configuration failure should be detected as early as practical.

---

# 42. Configuration Change Lifecycle

Configuration changes should follow the same engineering lifecycle as code changes:

```text
Configuration Change
        │
        ▼
Git
        │
        ▼
Review
        │
        ▼
Validation
        │
        ▼
Deployment
        │
        ▼
Runtime Verification
        │
        ▼
Observability Validation
```

Configuration should therefore not be treated as an informal operational artifact.

---

# 43. Safe Configuration Changes

A safe configuration change should identify:

```text
What changes?
Why does it change?
Which component consumes it?
What behavior changes?
What is the failure mode?
How can the change be verified?
How can it be rolled back?
```

For example, increasing a Worker timeout should consider:

```text
Worker processing latency
queue backlog
resource consumption
job retry behavior
downstream dependency behavior
```

rather than changing the value in isolation.

---

# 44. Configuration and Reliability

Configuration is directly connected to reliability.

Examples:

```text
Timeout
   → limits operation duration

Retry
   → controls transient failure recovery

Max retries
   → bounds retry amplification

Worker concurrency
   → controls processing parallelism

Log retention
   → controls operational evidence lifetime

Scrape interval
   → controls monitoring resolution
```

Therefore configuration changes can alter system reliability characteristics.

---

# 45. Configuration and Scalability

Configuration also affects scalability.

Examples include:

```text
Worker concurrency
```

which affects processing capacity:

```text
Concurrency ↑
    │
    ├── throughput may increase
    ├── CPU usage may increase
    ├── memory usage may increase
    └── dependency load may increase
```

Similarly:

```text
retry count ↑
```

may increase dependency load during incidents.

Configuration should therefore be evaluated as part of system behavior rather than as isolated constants.

---

# 46. Configuration and Security

Security-sensitive configuration includes:

```text
authentication secrets
database credentials
storage credentials
service credentials
JWT signing configuration
```

These values must:

* remain outside Git
* be injected securely
* have controlled permissions
* not appear in logs
* not be exposed through metrics
* not be embedded in dashboard definitions

The configuration system must preserve the boundary between:

```text
Configuration Metadata
```

and:

```text
Secret Material
```

---

# 47. Configuration and Observability

Configuration changes should be observable whenever they can materially change runtime behavior.

For example:

```text
Worker concurrency
timeout
retry policy
application version
deployment version
```

should be correlated with operational telemetry where practical.

This allows operators to answer:

```text
Did configuration change before the incident?
```

rather than investigating metrics in isolation.

---

# 48. Configuration Documentation Rules

When introducing a new configuration value, its documentation should include:

```text
Name
Purpose
Owner
Type
Default
Required/Optional
Valid range
Consumer
Security sensitivity
Operational impact
Example
```

For environment variables, the detailed catalog belongs in:

```text
docs/reference/environment-variables.md
```

For metrics, the detailed catalog belongs in:

```text
docs/reference/metrics-reference.md
```

For Runtime configuration, the detailed architecture belongs in:

```text
docs/reference/runtime-reference.md
```

This separation prevents this document from becoming an unstructured configuration dump.

---

# 49. Configuration Troubleshooting

When a configuration-related failure occurs, investigation should proceed from source to consumer.

```text
1. Identify the affected component.

2. Identify the configuration domain.

3. Identify the configuration source.

4. Verify the value supplied to the deployment layer.

5. Verify the container receives the expected value.

6. Verify the application consumes the value.

7. Verify runtime behavior.

8. Verify resulting telemetry.
```

The critical distinction is:

```text
Configured value
      ≠
Consumed value
      ≠
Observed behavior
```

All three should be validated.

---

# 50. Common Configuration Failure Classes

Typical failure classes include:

### Missing configuration

```text
Required variable not supplied.
```

### Invalid configuration

```text
Value exists but violates expected format or range.
```

### Configuration drift

```text
Runtime configuration differs from repository definition.
```

### Environment mismatch

```text
Configuration describes one environment
while the service operates in another.
```

### Secret exposure

```text
Sensitive value appears in repository,
logs, metrics, or dashboards.
```

### Configuration propagation failure

```text
Correct value exists in the source
but never reaches the running container.
```

---

# 51. Configuration Drift

Configuration drift is particularly important in a production-oriented environment.

The desired state is:

```text
Git
  │
  ▼
Infrastructure Automation
  │
  ▼
Deployment Environment
  │
  ▼
Running Services
```

If the host is manually modified:

```text
Running Environment
        │
        X
        │
Git
```

the repository is no longer a reliable representation of the deployed system.

This is why infrastructure and observability configuration are managed as code.

---

# 52. Configuration Reproducibility

A clean deployment should be reconstructable from:

```text
Repository
+
Environment-specific values
+
Secrets
```

without depending on undocumented manual changes.

The target model is:

```text
Known Source
     │
     ▼
Automation
     │
     ▼
Deterministic Configuration
     │
     ▼
Reproducible Runtime
```

---

# 53. Configuration Reference Map

The major configuration surfaces are:

```text
docs/
│
├── infrastructure/
│   ├── infrastructure-as-code.md
│   ├── ansible.md
│   ├── host-provisioning.md
│   ├── docker.md
│   └── security-baseline.md
│
├── deployment/
│   ├── deployment.md
│   ├── configuration.md
│   └── ci-cd.md
│
├── observability/
│   ├── observability.md
│   ├── metrics.md
│   ├── logging.md
│   ├── alerting.md
│   └── dashboards.md
│
└── reference/
    ├── configuration-reference.md
    ├── environment-variables.md
    ├── runtime-reference.md
    └── metrics-reference.md
```

Each document has a distinct role.

---

# 54. Configuration Documentation Boundaries

This document answers:

```text
Where does configuration live?
What configuration domains exist?
Who owns each domain?
How do configuration domains interact?
```

`environment-variables.md` answers:

```text
Which environment variables exist?
What does each variable mean?
Which service consumes it?
Is it required?
Does it contain a secret?
```

`runtime-reference.md` answers:

```text
How does Runtime configuration work?
Which operations have policies?
What are the reliability parameters?
```

`deployment/configuration.md` answers:

```text
How is configuration supplied during deployment?
```

This separation is intentional.

---

# 55. Configuration Governance Principles

Mini-Write configuration follows these principles:

### 1. Configuration as Code

Architectural configuration should be version-controlled.

### 2. Explicit Ownership

Every configuration domain should have a clear owner.

### 3. Environment Separation

Environment-specific values should not be embedded in application source.

### 4. Secret Separation

Secrets must not be stored with ordinary repository configuration.

### 5. Reproducibility

The platform should be reconstructable from declared configuration.

### 6. Validation

Configuration should be validated before and after deployment.

### 7. Observability

Important configuration changes should be diagnosable through telemetry.

### 8. Minimal Implicit Behavior

Defaults should be explicit and safe.

---

# 56. Final Configuration Model

The complete Mini-Write configuration architecture is:

```text
                         Git Repository
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
   Infrastructure        Application         Observability
   Configuration         Configuration       Configuration
          │                   │                   │
          ▼                   ▼                   ▼
       Ansible           Environment       Prometheus/Loki
       Compose           Variables         Grafana/Alertmanager
          │                   │                   │
          └───────────────────┼───────────────────┘
                              ▼
                         Deployment
                              │
                              ▼
                      Container Runtime
                              │
                              ▼
                       Running Services
                              │
                              ▼
                         Telemetry
                              │
                              ▼
                    Operational Feedback
```

The fundamental rule is:

> **Configuration defines intended system behavior; deployment automation makes that configuration reproducible; Runtime consumes operational policies; and Observability provides evidence of the resulting behavior.**

Configuration should therefore be treated as an architectural contract rather than a collection of environment variables and static files.

```
```
