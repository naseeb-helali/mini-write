# Environment Variables Reference

## 1. Purpose

This document is the authoritative reference for environment variables used by Mini-Write services and deployment infrastructure.

It answers four questions:

1. Which environment variables exist?
2. Which component consumes each variable?
3. What is the purpose and sensitivity of each variable?
4. Where is the variable supplied during deployment?

This document intentionally does **not** contain actual secret values.

The configuration model is:

```text
Environment Variables
        │
        ├── Application Configuration
        │
        ├── Infrastructure Configuration
        │
        ├── Deployment Configuration
        │
        └── Observability Configuration
                 │
                 ▼
          Running Services
````

---

# 2. Configuration Principles

Mini-Write uses environment variables to separate runtime configuration from application source code.

The intended model is:

```text
Source Code
    │
    └── defines behavior

Environment
    │
    └── defines environment-specific values

Secrets
    │
    └── provides sensitive credentials

Deployment
    │
    └── injects configuration

Runtime
    │
    └── consumes configuration
```

Environment variables should therefore not be treated as a generic storage mechanism.

Each variable should have a clearly defined owner and consumer.

---

# 3. Variable Classification

Environment variables are classified into four major categories:

| Category       | Purpose                                         |
| -------------- | ----------------------------------------------- |
| Application    | Controls application runtime behavior           |
| Infrastructure | Provides dependency connection/configuration    |
| Deployment     | Controls deployment/image selection             |
| Observability  | Establishes telemetry identity/configuration    |
| Security       | Provides authentication credentials and secrets |

Some variables belong to more than one operational concern.

For example:

```text
APP_VERSION
```

is an application variable but also becomes part of observability identity.

---

# 4. Variable Lifecycle

The general lifecycle is:

```text
Variable Definition
        │
        ▼
Environment / Secret Source
        │
        ▼
Deployment Configuration
        │
        ▼
Docker Container
        │
        ▼
process.env
        │
        ▼
Application / Infrastructure Client
```

The value should be validated at the appropriate consumption boundary.

---

# 5. API Environment Variables

The API consumes environment variables through `process.env`.

The currently identified API variables are:

| Variable           | Consumer | Required | Secret | Purpose                                 |
| ------------------ | -------- | -------: | -----: | --------------------------------------- |
| `NODE_ENV`         | API      |       No |     No | Runtime environment identity            |
| `APP_VERSION`      | API      |       No |     No | Application version identity            |
| `HTTP_PORT`        | API      |       No |     No | HTTP listening port                     |
| `JWT_SECRET`       | API      |      Yes |    Yes | JWT signing secret                      |
| `JWT_EXPIRY`       | API      |      Yes |     No | JWT expiration configuration            |
| Database variables | API      |      Yes |   Some | PostgreSQL connection/configuration     |
| Redis variables    | API      |      Yes |   Some | Redis connection/configuration          |
| MinIO variables    | API      |      Yes |   Some | Object-storage connection/configuration |

The exact dependency-specific variable names must remain aligned with the database, Redis, and storage client implementations.

---

# 6. `NODE_ENV`

### Purpose

Defines the Node.js application environment.

### Consumer

```text
API
Worker
```

### Example

```bash
NODE_ENV=production
```

### Default

The API observability implementation falls back to:

```text
development
```

when `NODE_ENV` is not defined.

### Sensitivity

```text
Non-secret
```

### Operational impact

`NODE_ENV` affects environment identity used by application observability.

It is therefore important that the value accurately represents the environment in which the service is running.

---

# 7. `APP_VERSION`

### Purpose

Identifies the running application version.

### Consumer

```text
API
Worker
Observability
```

### Example

```bash
APP_VERSION=1.0.0
```

### Default

The current API observability implementation uses:

```text
1.0.0
```

when `APP_VERSION` is not defined.

### Sensitivity

```text
Non-secret
```

### Operational impact

The value is included in application telemetry identity.

This allows operators to correlate:

```text
Version
    │
    ├── Metrics
    ├── Logs
    └── Deployment
```

and answer questions such as:

```text
Did the observed behavior begin after a new application version was deployed?
```

---

# 8. `HTTP_PORT`

### Purpose

Defines the port on which the API HTTP server listens.

### Consumer

```text
API
```

### Current fallback

```text
80
```

The API implementation uses:

```js
const PORT = process.env.HTTP_PORT || 80;
```

### Example

```bash
HTTP_PORT=80
```

### Sensitivity

```text
Non-secret
```

### Operational impact

The value must remain consistent with the container networking configuration.

The relationship is:

```text
HTTP_PORT
    │
    ▼
API process
    │
    ▼
Container port
    │
    ▼
Gateway / health checks / Prometheus
```

A mismatch can cause:

* failed health checks
* failed Prometheus scraping
* gateway connectivity failures
* service startup appearing successful while traffic cannot reach the API

---

# 9. `JWT_SECRET`

### Purpose

Provides the secret used to sign JWT authentication tokens.

### Consumer

```text
API authentication layer
```

### Sensitivity

```text
SECRET
```

### Example

```bash
JWT_SECRET=<secret-value>
```

The actual value must never be committed to Git.

### Security requirements

The value should:

* be sufficiently random
* be stored outside source control
* not appear in logs
* not appear in metrics
* not appear in dashboard definitions
* not be exposed through error responses

### Operational impact

Changing the signing secret can invalidate previously issued tokens.

Therefore:

```text
JWT_SECRET change
       │
       ▼
Previously signed tokens
       │
       ▼
May no longer validate
```

This should be treated as a security-sensitive operational change.

---

# 10. `JWT_EXPIRY`

### Purpose

Defines JWT token expiration behavior.

### Consumer

```text
API authentication layer
```

The API passes the configured value to the JWT implementation:

```js
{
  expiresIn: process.env.JWT_EXPIRY
}
```

### Sensitivity

```text
Non-secret
```

although the value influences security behavior.

### Operational impact

A shorter expiration:

```text
Security ↑
Session lifetime ↓
```

A longer expiration:

```text
Session convenience ↑
Token exposure window ↑
```

Therefore this variable should be treated as a security-relevant configuration value.

---

# 11. Database Configuration

The API and Worker depend on PostgreSQL.

The deployment environment therefore supplies PostgreSQL connection configuration.

The Docker Compose deployment explicitly consumes:

```text
POSTGRES_USER
POSTGRES_PASSWORD
POSTGRES_DB
```

These values are used by the PostgreSQL service itself and by dependent services.

---

# 12. `POSTGRES_USER`

### Purpose

Defines the PostgreSQL database user.

### Consumer

```text
PostgreSQL
API / database clients
PostgreSQL exporter
```

### Sensitivity

```text
Non-secret
```

although it should still be treated as infrastructure configuration.

### Example

```bash
POSTGRES_USER=miniwrite
```

The actual configured value is environment-specific.

---

# 13. `POSTGRES_PASSWORD`

### Purpose

Defines the PostgreSQL authentication password.

### Consumer

```text
PostgreSQL
API
PostgreSQL exporter
```

### Sensitivity

```text
SECRET
```

### Security requirements

The value must not be:

* committed to Git
* printed in logs
* included in metrics
* included in dashboards
* exposed through error messages

The PostgreSQL exporter currently constructs its connection string from the PostgreSQL environment variables.

Therefore accidental exposure of this variable can expose database credentials.

---

# 14. `POSTGRES_DB`

### Purpose

Defines the PostgreSQL database name.

### Consumer

```text
PostgreSQL
API
PostgreSQL exporter
```

### Sensitivity

```text
Non-secret
```

### Operational impact

The database name must be consistent across the PostgreSQL server and clients.

The health check uses:

```text
POSTGRES_USER
POSTGRES_DB
```

to verify PostgreSQL readiness.

---

# 15. PostgreSQL Configuration Relationship

The core PostgreSQL configuration is:

```text
POSTGRES_USER
        │
        ├──────────────┐
        │              │
POSTGRES_PASSWORD   POSTGRES_DB
        │              │
        └──────┬───────┘
               ▼
          PostgreSQL
               │
       ┌───────┴────────┐
       ▼                ▼
      API          PostgreSQL Exporter
```

A mismatch between the values consumed by PostgreSQL and its clients can produce:

```text
Authentication failures
Connection failures
Health-check failures
Exporter failures
```

---

# 16. Redis Configuration

Redis is used by Mini-Write as a queue/cache infrastructure dependency.

The API and Worker therefore require Redis connection configuration.

The exact variable names are defined by the Redis client implementation and deployment configuration.

The configuration domain includes:

```text
Redis host
Redis port
Redis authentication, if enabled
Redis connection parameters
```

These values should be documented here once their concrete variable names are established by the client implementation.

The architectural rule is:

```text
Application
    │
    ▼
Redis configuration
    │
    ▼
Redis client
    │
    ▼
Redis service
```

---

# 17. MinIO Configuration

MinIO provides object-storage functionality.

The Docker Compose deployment explicitly consumes:

```text
MINIO_ROOT_USER
MINIO_ROOT_PASSWORD
```

and passes them to the MinIO service.

---

# 18. `MINIO_ROOT_USER`

### Purpose

Defines the MinIO root/admin username.

### Consumer

```text
MinIO
```

and indirectly the application storage configuration.

### Sensitivity

```text
Sensitive
```

The username should not be considered equivalent to a password, but it is still infrastructure authentication material.

### Security

It must not be unnecessarily exposed through logs or telemetry.

---

# 19. `MINIO_ROOT_PASSWORD`

### Purpose

Defines the MinIO root/admin password.

### Consumer

```text
MinIO
```

### Sensitivity

```text
SECRET
```

The value must be stored outside source control.

It must never be placed in:

```text
Git
logs
metrics
dashboards
alert annotations
```

---

# 20. MinIO Configuration Relationship

The storage configuration follows:

```text
MINIO_ROOT_USER
        │
MINIO_ROOT_PASSWORD
        │
        ▼
      MinIO
        │
        ▼
 Storage Service
        │
        ▼
       API
       Worker
```

The Worker and API should use application-level storage credentials/configuration rather than embedding credentials directly into source code.

---

# 21. `API_IMAGE`

### Purpose

Defines the Docker image used by the API service.

### Consumer

```text
Docker Compose
API deployment
```

The staging Compose configuration contains:

```yaml
image: ${API_IMAGE}
```

### Example

```bash
API_IMAGE=mini-write-api:<version>
```

### Sensitivity

```text
Non-secret
```

### Operational impact

Changing `API_IMAGE` changes the application artifact deployed to the environment.

Therefore:

```text
API_IMAGE change
       │
       ▼
New API artifact
       │
       ▼
New runtime behavior
```

This variable is therefore deployment-critical.

---

# 22. `WORKER_IMAGE`

### Purpose

Defines the Docker image used by the Worker service.

### Consumer

```text
Docker Compose
Worker deployment
```

The staging Compose configuration contains:

```yaml
image: ${WORKER_IMAGE}
```

### Example

```bash
WORKER_IMAGE=mini-write-worker:<version>
```

### Sensitivity

```text
Non-secret
```

### Operational impact

Changing `WORKER_IMAGE` changes the background-processing implementation.

It may therefore affect:

```text
Queue throughput
Job failure rate
Processing latency
Resource consumption
Dependency load
```

---

# 23. `GRAFANA_ADMIN_PASSWORD`

### Purpose

Defines the Grafana administrator password.

### Consumer

```text
Grafana
```

The Docker Compose configuration supplies:

```text
GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
```

### Sensitivity

```text
SECRET
```

### Security requirements

The value must not be committed to Git.

It must also not be exposed through:

```text
logs
metrics
dashboards
configuration screenshots
repository examples
```

---

# 24. `GRAFANA_ADMIN_PASSWORD` Security Boundary

The configuration flow is:

```text
GRAFANA_ADMIN_PASSWORD
        │
        ▼
Docker Compose
        │
        ▼
Grafana container
        │
        ▼
Grafana authentication
```

The variable should not be consumed by application services.

This maintains a clear security boundary between:

```text
Application Credentials
```

and:

```text
Observability Platform Credentials
```

---

# 25. Docker Compose Variables

The staging Compose template uses variable interpolation for deployment configuration.

Known variables include:

```text
API_IMAGE
WORKER_IMAGE
HTTP_PORT
POSTGRES_USER
POSTGRES_PASSWORD
POSTGRES_DB
MINIO_ROOT_USER
MINIO_ROOT_PASSWORD
GRAFANA_ADMIN_PASSWORD
```

The configuration pattern is:

```yaml
${VARIABLE}
```

or, where a default exists:

```yaml
${VARIABLE:-default}
```

For example:

```yaml
"${HTTP_PORT:-80}:80"
```

means:

```text
HTTP_PORT configured
    │
    ├── yes → use configured value
    │
    └── no  → use 80
```

---

# 26. Environment File

The staging deployment creates:

```text
/opt/deploy/env/.env.staging
```

through the Ansible `deploy_runtime` role.

The Docker Compose template references this file for services that require application/dependency environment configuration.

The intended flow is:

```text
Ansible
   │
   ▼
.env.staging
   │
   ▼
Docker Compose
   │
   ▼
Containers
```

This provides a stable deployment-level configuration boundary.

---

# 27. `.env.staging` Ownership

The staging environment file is managed by the deployment infrastructure.

The Ansible deployment role:

1. Checks whether the file exists.
2. Creates it from `env.staging.j2` if absent.
3. Applies controlled ownership and permissions.

The resulting file is configured with:

```text
owner: deploy user
group: deploy user
mode: 0640
```

The restrictive mode is intentional because the file can contain secrets.

---

# 28. Secret Configuration Boundary

The intended architecture is:

```text
Git Repository
    │
    ├── Templates
    ├── Variable definitions
    └── Configuration structure
             │
             ▼
      Secret / Environment Source
             │
             ▼
       .env.staging
             │
             ▼
        Docker Compose
             │
             ▼
          Services
```

The repository should never require real secret values to reproduce the configuration model.

---

# 29. Ansible Variables

Ansible itself uses variables for infrastructure configuration.

Examples visible in the infrastructure implementation include:

```text
deploy_root
deploy_user
deploy_directories
deploy_scripts
deploy_runtime_modules
runtime_subdirectory
deployment_state_file
immutable_runtime_dirs
mutable_runtime_dirs
```

Docker configuration additionally uses variables such as:

```text
docker_apt_keyring_path
docker_packages
```

The GitHub Runner role uses variables including:

```text
github_runner_install_dir
github_runner_download_url
github_runner_archive_path
github_runner_api_url
github_runner_pat
github_runner_repo_url
github_runner_name
github_runner_labels
github_runner_disable_update
github_owner
github_repo
```

These are Ansible variables rather than application environment variables.

---

# 30. Ansible Secrets

The staging playbook loads:

```text
infra/ansible/vault/staging-secrets.yml
```

through:

```yaml
vars_files:
  - ../vault/staging-secrets.yml
```

This establishes a separate secret-management boundary for infrastructure automation.

Sensitive Ansible values should therefore be handled through Ansible Vault rather than committed as plaintext.

A key distinction is:

```text
Ansible variables
        ≠
Container environment variables
```

They can participate in the same deployment process but belong to different configuration layers.

---

# 31. GitHub Runner Configuration

The GitHub Actions self-hosted runner is configured through Ansible variables.

Important configuration areas include:

```text
Runner installation directory
Runner download URL
Registration API
Repository URL
Runner name
Runner labels
Update policy
GitHub authentication token
```

The registration token/PAT is sensitive.

The Ansible implementation explicitly uses:

```text
no_log: true
```

for sensitive runner registration operations.

This prevents credentials from being unnecessarily written into Ansible output.

---

# 32. Security Configuration

Security-related configuration is primarily managed through Ansible.

Examples include:

```text
security_allowed_tcp_ports
security_disable_password_auth
security_disable_root_login
security_enable_pubkey_auth
security_disable_empty_passwords
```

These values control the host security baseline.

They should therefore be treated as security-sensitive configuration even when they are not secrets.

For example:

```text
security_disable_password_auth
```

changes the authentication surface of the host.

---

# 33. Firewall Configuration

The security baseline consumes:

```text
security_allowed_tcp_ports
```

to configure UFW.

The configuration flow is:

```text
security_allowed_tcp_ports
          │
          ▼
         UFW
          │
          ▼
 Host network exposure
```

Changing this value can expose or block infrastructure services.

Therefore firewall configuration changes require operational validation.

---

# 34. SSH Configuration

SSH hardening is controlled by:

```text
security_disable_password_auth
security_disable_root_login
security_enable_pubkey_auth
security_disable_empty_passwords
```

These values are rendered into:

```text
/etc/ssh/sshd_config.d/99-miniwrite-hardening.conf
```

The resulting configuration is validated using:

```text
/usr/sbin/sshd -t
```

before the SSH service is restarted.

This is an example of configuration validation at the infrastructure boundary.

---

# 35. Observability Environment Identity

The observability stack has configuration values that identify:

```text
project
environment
service
layer
```

Prometheus currently defines:

```yaml
external_labels:
  project: mini-write
  environment: staging
```

Scrape targets additionally receive service/layer labels.

These values are not necessarily environment variables.

They are configuration values managed by observability configuration files.

Therefore:

```text
Observability configuration
        ≠
Environment variable configuration
```

but both contribute to environment identity.

---

# 36. Configuration Versus Static Configuration Files

Not every configuration value should become an environment variable.

Mini-Write deliberately keeps structural configuration in files such as:

```text
prometheus.yml
loki/config.yml
promtail/config.yml
alertmanager.yml
Grafana provisioning files
Ansible task files
Docker Compose templates
Runtime policy definitions
```

Environment variables should primarily represent values that need to vary independently from the artifact or deployment structure.

The distinction is:

```text
Environment Variable
    → variable runtime value

Configuration File
    → structural/system configuration
```

---

# 37. Recommended Environment Variable Naming

Environment variables should follow a consistent naming convention:

```text
UPPERCASE_SNAKE_CASE
```

Examples:

```text
HTTP_PORT
NODE_ENV
APP_VERSION
POSTGRES_USER
POSTGRES_PASSWORD
POSTGRES_DB
API_IMAGE
WORKER_IMAGE
```

Names should communicate the semantic meaning of the value rather than the implementation detail that happens to consume it.

---

# 38. Required Versus Optional Variables

A variable should be classified as:

```text
Required
Optional
Optional with safe default
```

For example:

```text
HTTP_PORT
    → Optional with default 80

NODE_ENV
    → Optional with default development

APP_VERSION
    → Optional with default 1.0.0

JWT_SECRET
    → Required for secure authentication
```

A production deployment should not rely on development-oriented defaults for security-sensitive configuration.

---

# 39. Secret Variables

The following currently identified variables contain or can contain secret material:

```text
JWT_SECRET
POSTGRES_PASSWORD
MINIO_ROOT_PASSWORD
GRAFANA_ADMIN_PASSWORD
github_runner_pat
```

The GitHub Runner value is an Ansible variable rather than a container environment variable, but it belongs to the same broader secret-management concern.

Secret values must never be included in this document.

---

# 40. Non-Secret but Security-Relevant Variables

Some variables are not secrets but still influence security.

Examples:

```text
JWT_EXPIRY
POSTGRES_USER
MINIO_ROOT_USER
security_disable_password_auth
security_disable_root_login
security_enable_pubkey_auth
```

These values should be reviewed as security configuration even when their values can safely be stored in Git.

---

# 41. Configuration Validation Matrix

| Variable / Domain          | Validation Boundary                 |
| -------------------------- | ----------------------------------- |
| `HTTP_PORT`                | API startup / container networking  |
| `JWT_SECRET`               | API authentication configuration    |
| `JWT_EXPIRY`               | JWT configuration                   |
| PostgreSQL variables       | PostgreSQL + database client        |
| MinIO variables            | MinIO + storage client              |
| `API_IMAGE`                | Docker deployment                   |
| `WORKER_IMAGE`             | Docker deployment                   |
| `GRAFANA_ADMIN_PASSWORD`   | Grafana startup                     |
| Ansible security variables | Ansible + host validation           |
| Runtime policies           | Runtime policy construction         |
| Prometheus configuration   | Prometheus configuration validation |
| Alert rules                | Prometheus rule evaluation          |
| Grafana provisioning       | Grafana startup/provisioning        |

---

# 42. Configuration Failure Modes

Environment-variable failures generally fall into these categories.

## 42.1 Missing Variable

```text
Variable absent
      │
      ▼
Application receives undefined
      │
      ▼
Startup or runtime failure
```

---

## 42.2 Incorrect Value

```text
Variable exists
      │
      ▼
Invalid value
      │
      ▼
Unexpected runtime behavior
```

---

## 42.3 Wrong Environment

```text
Staging service
      │
      ▼
Production configuration
      │
      ▼
Environment mismatch
```

This can be significantly more dangerous than a missing value.

---

## 42.4 Secret Exposure

```text
Secret
   │
   ├── Git
   ├── Logs
   ├── Metrics
   └── Error response
          │
          ▼
      Credential leak
```

---

## 42.5 Propagation Failure

```text
Correct value exists
       │
       ▼
Deployment layer
       │
       X
       │
Container does not receive it
```

The source configuration can therefore be correct while the running service is incorrect.

---

# 43. Configuration Troubleshooting Procedure

When an environment-variable problem is suspected:

### Step 1 — Identify the consumer

Determine whether the variable is consumed by:

```text
API
Worker
PostgreSQL
Redis
MinIO
Grafana
Docker
Ansible
```

### Step 2 — Identify the source

Determine where the value originates:

```text
Ansible variable
.env.staging
CI/CD
Docker Compose interpolation
system environment
```

### Step 3 — Verify propagation

Confirm:

```text
source
  ↓
deployment
  ↓
container
  ↓
process
```

### Step 4 — Verify behavior

Check:

```text
logs
health checks
metrics
application behavior
```

### Step 5 — Check for configuration drift

Compare:

```text
Declared configuration
        vs
Running configuration
```

---

# 44. Configuration Security Rules

The following rules are mandatory for environment variables containing secrets:

1. Never commit real values to Git.
2. Never print secrets in application logs.
3. Never include secrets in metrics labels.
4. Never include secrets in Prometheus annotations.
5. Never include secrets in Grafana dashboards.
6. Never expose secrets through HTTP responses.
7. Restrict filesystem permissions on secret-bearing environment files.
8. Rotate credentials when compromise is suspected.
9. Review configuration changes involving authentication material.
10. Keep secret management separate from ordinary documentation.

---

# 45. Configuration Documentation Rules

When a new environment variable is introduced, update this document with:

```text
Variable name
Consumer
Purpose
Required/optional status
Default
Secret classification
Operational impact
Validation boundary
```

For example:

```text
VARIABLE
    │
    ├── Consumer
    ├── Purpose
    ├── Required?
    ├── Default
    ├── Secret?
    ├── Operational impact
    └── Validation
```

This prevents undocumented configuration from becoming hidden operational coupling.

---

# 46. Environment Variable Reference Table

The currently established variable inventory is summarized below.

| Variable                 | Consumer             |                       Required | Default                                             |    Secret | Primary Role             |
| ------------------------ | -------------------- | -----------------------------: | --------------------------------------------------- | --------: | ------------------------ |
| `NODE_ENV`               | API / Worker         |                             No | `development` in current API observability defaults |        No | Environment identity     |
| `APP_VERSION`            | API / Worker         |                             No | `1.0.0` in current API observability defaults       |        No | Version identity         |
| `HTTP_PORT`              | API / Compose        |                             No | `80`                                                |        No | HTTP port                |
| `JWT_SECRET`             | API                  |                            Yes | None                                                |       Yes | JWT signing              |
| `JWT_EXPIRY`             | API                  |                            Yes | None                                                |        No | JWT lifetime             |
| `POSTGRES_USER`          | PostgreSQL / clients |                            Yes | Environment-specific                                |        No | DB user                  |
| `POSTGRES_PASSWORD`      | PostgreSQL / clients |                            Yes | Environment-specific                                |       Yes | DB password              |
| `POSTGRES_DB`            | PostgreSQL / clients |                            Yes | Environment-specific                                |        No | DB name                  |
| `MINIO_ROOT_USER`        | MinIO                |                            Yes | Environment-specific                                | Sensitive | MinIO root user          |
| `MINIO_ROOT_PASSWORD`    | MinIO                |                            Yes | Environment-specific                                |       Yes | MinIO root password      |
| `API_IMAGE`              | Compose              | Yes for image-based deployment | None                                                |        No | API artifact             |
| `WORKER_IMAGE`           | Compose              | Yes for image-based deployment | None                                                |        No | Worker artifact          |
| `GRAFANA_ADMIN_PASSWORD` | Grafana              |                            Yes | None                                                |       Yes | Grafana admin credential |

---

# 47. Variables Requiring Implementation-Level Verification

Some configuration domains are known to exist but their exact environment-variable names should be verified against their consuming source files before being declared as concrete variables.

This applies particularly to:

```text
Redis client configuration
MinIO client configuration
Worker-specific environment variables
```

The documentation must not invent variable names merely because a dependency requires such configuration.

The correct workflow is:

```text
Consumer implementation
        │
        ▼
Identify process.env usage
        │
        ▼
Confirm variable name
        │
        ▼
Document variable
```

This keeps the reference synchronized with the actual implementation.

---

# 48. Environment Variable Governance

Environment variables are part of the platform's operational contract.

A variable should not be introduced casually because every new variable creates another configuration dependency:

```text
New Variable
     │
     ├── source
     ├── deployment propagation
     ├── validation
     ├── documentation
     ├── testing
     └── operational ownership
```

Therefore new environment variables should be introduced only when configuration cannot be represented more appropriately through an existing configuration mechanism.

---

# 49. Final Configuration Model

The Mini-Write environment-variable architecture can be summarized as:

```text
                    Environment
                        │
        ┌───────────────┼────────────────┐
        │               │                │
        ▼               ▼                ▼
   Application     Infrastructure    Observability
        │               │                │
        ▼               ▼                ▼
   process.env       Ansible         Compose / Config
        │               │                │
        └───────────────┼────────────────┘
                        ▼
                   Deployment
                        │
                        ▼
                   Containers
                        │
                        ▼
                    Services
                        │
                        ▼
                    Runtime
                        │
                        ▼
                  Observability
```

The governing principle is:

> **Environment variables provide runtime-specific values; configuration files define structural behavior; Ansible establishes the infrastructure environment; Docker propagates deployment configuration; and services consume only the configuration belonging to their responsibility boundary.**

This separation keeps configuration understandable, reproducible, auditable, and maintainable as the platform evolves.

```
```
