# Docker

## 1. Purpose

This document describes the Docker architecture used by Mini-Write and the role Docker plays within the infrastructure layer.

It explains:

- why Docker is used;
- how Docker is installed and managed by Ansible;
- how the host Docker runtime relates to the application stack;
- how Docker Compose defines the staging workload;
- how containers are separated through networks;
- how persistent data is represented through volumes;
- how resource limits and restart policies are applied;
- how health checks participate in service readiness;
- how Docker integrates with the deployment runtime and GitHub Actions runner;
- how observability services run inside the same container platform;
- which responsibilities belong to Docker versus the application and deployment layers;
- the operational and security boundaries of the current design.

This document focuses on the **Docker infrastructure layer**.

It complements:

- [`overview.md`](./overview.md) — infrastructure architecture;
- [`infrastructure-as-code.md`](./infrastructure-as-code.md) — infrastructure-as-code model;
- [`ansible.md`](./ansible.md) — Ansible implementation;
- [`host-provisioning.md`](./host-provisioning.md) — host provisioning lifecycle.

The conceptual distinction is:

```text
infrastructure/overview.md
    → What infrastructure exists?

infrastructure-as-code.md
    → How is infrastructure represented as code?

ansible.md
    → How does Ansible implement it?

host-provisioning.md
    → How is a host prepared?

docker.md
    → How does Docker provide the container execution platform?
````

---

# 2. Docker's Role in Mini-Write

Docker is the **container execution substrate** for Mini-Write.

It provides the boundary between:

```text
Host Operating System
        │
        ▼
Docker Engine
        │
        ▼
Containers
        │
        ▼
Mini-Write Services
```

Docker therefore sits below the application runtime.

The application runtime is responsible for application behavior such as:

```text
HTTP request processing
Operation context
Reliability policy
Timeouts
Retries
Failure classification
Background job processing
```

Docker is responsible for:

```text
Container lifecycle
Process isolation
Filesystem mounts
Network attachment
Resource limits
Restart policy
Image execution
Container health checks
```

The distinction is fundamental.

---

# 3. Docker Architecture

The current Mini-Write architecture uses a single Docker host.

Conceptually:

```text
┌──────────────────────────────────────────────────────────────┐
│                     Ubuntu Staging Host                      │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Docker Engine                       │  │
│  │                                                        │  │
│  │  ┌─────────┐   ┌───────┐   ┌────────┐   ┌──────────┐ │  │
│  │  │ Gateway │   │  API  │   │ Worker │   │Postgres │ │  │
│  │  └─────────┘   └───────┘   └────────┘   └──────────┘ │  │
│  │                                                        │  │
│  │  ┌───────┐   ┌────────┐   ┌────────────┐             │  │
│  │  │ Redis │   │ MinIO  │   │Observability│             │  │
│  │  └───────┘   └────────┘   └────────────┘             │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

The current design intentionally uses a **single-node container topology**.

This is appropriate for the project's current staging and learning objectives while preserving architectural boundaries that can later map to a multi-node or Kubernetes-based environment.

---

# 4. Docker Installation

Docker is provisioned by the Ansible role:

```text
infra/ansible/roles/docker/
```

The role is responsible for establishing the host-level Docker runtime.

The installation flow is:

```text
Create APT Keyring Directory
        │
        ▼
Install Docker GPG Key
        │
        ▼
Configure Docker Repository
        │
        ▼
Update APT Cache
        │
        ▼
Install Docker Packages
        │
        ▼
Enable Docker Service
        │
        ▼
Start Docker Service
        │
        ▼
Grant Deployment User Docker Access
```

Docker is therefore not treated as a manually installed prerequisite.

It is part of the reproducible infrastructure definition.

---

# 5. Docker Repository Trust

The Docker Ansible role creates:

```text
/etc/apt/keyrings
```

and downloads the Docker repository signing key into the configured keyring path.

The repository is configured using:

```text
signed-by={{ docker_apt_keyring_path }}
```

The resulting trust relationship is:

```text
Docker Repository
       │
       ▼
Repository Signature
       │
       ▼
Configured GPG Keyring
       │
       ▼
APT Verification
       │
       ▼
Docker Package Installation
```

This keeps package trust explicit instead of relying on an unrestricted package source.

---

# 6. Docker Service Lifecycle

Docker is configured as a systemd-managed service.

The desired state is:

```text
enabled = true
state   = started
```

This means Docker should:

1. start during host boot;
2. remain available for application containers;
3. be available before CI/CD workflows attempt to deploy workloads.

The lifecycle is therefore:

```text
Host Boot
    │
    ▼
systemd
    │
    ▼
Docker Engine
    │
    ▼
Compose Services
```

Docker availability is a prerequisite for both application deployment and observability deployment.

---

# 7. Docker Access Model

The deployment user is added to the `docker` group by Ansible.

The relationship is:

```text
deploy_user
     │
     ▼
docker group
     │
     ▼
Docker access
     │
     ├── Deployment scripts
     │
     └── GitHub Actions runner
```

This allows CI/CD execution to interact with Docker without requiring every deployment command to execute as root.

However, membership in the Docker group is a privileged capability and should be treated accordingly.

---

# 8. Docker and CI/CD

The GitHub Actions self-hosted runner executes on the same host.

The intended execution chain is:

```text
GitHub Actions
       │
       ▼
Self-hosted Runner
       │
       ▼
deploy_user
       │
       ▼
Docker
       │
       ▼
Mini-Write Containers
```

This is why the provisioning process explicitly validates that the deployment user belongs to the Docker group.

A running GitHub runner without Docker access is not considered a deployment-capable runner.

---

# 9. Docker Compose as Workload Definition

The staging workload is defined through the Jinja2 template:

```text
infra/ansible/roles/deploy_runtime/templates/docker-compose.staging.yml.j2
```

Ansible renders this template to:

```text
/opt/deploy/compose/docker-compose.staging.yml
```

The relationship is:

```text
Git Repository
      │
      ▼
Compose Template
      │
      +
      │
Ansible Variables
      │
      ▼
Rendered Compose File
      │
      ▼
Docker Compose
      │
      ▼
Container Topology
```

Docker Compose therefore represents the **runtime topology**, while Ansible establishes the host and renders the topology configuration.

---

# 10. Current Container Topology

The staging Compose configuration defines the following major services:

```text
Application Layer
├── gateway
├── api
└── worker

State / Dependency Layer
├── postgres
├── redis
└── storage

Observability Layer
├── prometheus
├── loki
├── promtail
├── alertmanager
├── grafana
├── node-exporter
├── cadvisor
├── redis-exporter
└── postgres-exporter
```

This can be represented as:

```text
                    ┌─────────┐
                    │ Gateway │
                    └────┬────┘
                         │
                         ▼
                    ┌─────────┐
                    │   API   │
                    └────┬────┘
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
          PostgreSQL   Redis      MinIO
              ▲          ▲          ▲
              │          │          │
              └──────────┼──────────┘
                         │
                         ▼
                      Worker
```

Alongside this application topology:

```text
Prometheus
    │
    ├── API
    ├── Worker
    ├── Redis Exporter
    ├── PostgreSQL Exporter
    ├── Node Exporter
    ├── cAdvisor
    ├── Loki
    └── Alertmanager

Promtail
    │
    ▼
Loki
    │
    ▼
Grafana
```

---

# 11. Gateway Container

The gateway is implemented using:

```text
nginx:1.25-alpine
```

It exposes:

```text
${HTTP_PORT:-80}:80
```

and mounts the host-side Nginx configuration:

```text
{{ deploy_root }}/proxy/nginx.conf
    →
/etc/nginx/nginx.conf:ro
```

The gateway is attached only to:

```text
frontend-network
```

Its architectural role is:

```text
External Traffic
      │
      ▼
   Gateway
      │
      ▼
     API
```

The gateway therefore forms the external HTTP boundary of the application stack.

---

# 12. API Container

The API container uses the image defined by:

```text
${API_IMAGE}
```

It is attached to both:

```text
frontend-network
backend-network
```

This dual-network placement is intentional.

The API must communicate with:

```text
Gateway
```

through the frontend network, while also communicating with:

```text
PostgreSQL
Redis
```

through the backend network.

Conceptually:

```text
              frontend-network
                    │
              ┌─────┴─────┐
              │           │
           Gateway       API
                          │
                    backend-network
                          │
                    ┌─────┴─────┐
                    ▼           ▼
                 Redis      PostgreSQL
```

The API is therefore the controlled bridge between the external application path and backend dependencies.

---

# 13. Worker Container

The Worker uses:

```text
${WORKER_IMAGE}
```

and is attached only to:

```text
backend-network
```

This is an important isolation decision.

The Worker does not require direct external HTTP exposure.

Its communication path is:

```text
Worker
   │
   ├── Redis
   ├── PostgreSQL
   └── MinIO
```

The Worker therefore remains behind the backend network boundary.

---

# 14. PostgreSQL Container

PostgreSQL provides persistent application state.

It uses:

```text
postgres:15-alpine
```

and is attached to:

```text
backend-network
```

Its data is persisted through:

```text
postgres_data
```

mapped to:

```text
/var/lib/postgresql/data
```

The architecture is:

```text
PostgreSQL Container
        │
        ▼
postgres_data
        │
        ▼
Docker Host Storage
```

The database is therefore not dependent on the lifetime of an individual PostgreSQL container.

---

# 15. Redis Container

Redis provides caching and queue infrastructure.

It uses:

```text
redis:7-alpine
```

and is attached to:

```text
backend-network
```

Redis is configured with:

```text
redis-server --appendonly yes
```

which enables Redis AOF persistence.

Its data is stored in:

```text
redis_data
```

mounted at:

```text
/data
```

The application relationship is:

```text
API
 │
 ▼
Redis
 │
 ▼
Worker
```

Redis therefore serves as both an application dependency and the queue transport for background processing.

---

# 16. MinIO Container

MinIO provides object storage functionality.

The service runs:

```text
minio/minio
```

and stores data in:

```text
minio_data
```

mounted at:

```text
/data
```

The service is attached to:

```text
backend-network
```

The current configuration exposes:

```text
19000 → 9000
19001 → 9001
```

where:

```text
9000
    → MinIO API

9001
    → MinIO Console
```

These externally published ports should be treated as an explicit operational access boundary.

---

# 17. Network Architecture

The Compose topology defines two Docker bridge networks:

```text
frontend-network
backend-network
```

The intended logical model is:

```text
External
   │
   ▼
frontend-network
   │
   ▼
Gateway
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

The backend network therefore represents the internal application dependency plane.

---

# 18. Frontend Network

The frontend network is intended for components that participate in the external request path.

Currently:

```text
gateway
api
```

are attached to it.

This provides:

```text
Gateway ↔ API
```

without requiring the gateway to participate in the backend dependency network.

---

# 19. Backend Network

The backend network contains internal services.

It includes:

```text
api
worker
postgres
redis
storage
```

and the observability components that need access to internal metrics or logs.

The backend network is therefore not simply a "database network".

It is the internal service communication plane.

---

# 20. Network Isolation Model

The current isolation model can be expressed as:

```text
                External
                   │
                   ▼
            ┌─────────────┐
            │   Gateway   │
            └──────┬──────┘
                   │
            frontend-network
                   │
                   ▼
            ┌─────────────┐
            │     API     │
            └──────┬──────┘
                   │
            backend-network
                   │
       ┌───────────┼─────────────┐
       ▼           ▼             ▼
    Redis      PostgreSQL      MinIO
       ▲
       │
     Worker
```

The design reduces unnecessary network exposure.

---

# 21. `internal: true` Consideration

The backend network currently contains a commented configuration:

```yaml
# internal: true
```

If enabled, Docker would further restrict external connectivity for that network.

It is currently not enabled.

This is an important architectural choice rather than an accidental omission.

The current environment retains ordinary bridge-network connectivity, while relying on service-level network membership and host firewall rules for isolation.

If `internal: true` is enabled in the future, all workloads depending on external connectivity through the backend network must be evaluated before the change.

---

# 22. Published Ports

Not every container publishes a host port.

The current architecture intentionally exposes only selected services.

Examples include:

```text
gateway
    → HTTP

storage
    → MinIO API / Console

prometheus
    → 9090

loki
    → 3100

alertmanager
    → 9093

grafana
    → 3000
```

Internal services such as:

```text
PostgreSQL
Redis
Worker
```

do not require host-level port publishing.

Their communication occurs through Docker networks.

---

# 23. Port Publishing Versus Internal Communication

There is an important difference between:

```text
Container-to-container communication
```

and:

```text
Host-to-container communication
```

For example:

```text
API → PostgreSQL
```

should use the Docker network and PostgreSQL service identity rather than exposing PostgreSQL to the host.

Conceptually:

```text
API
 │
 │ Docker DNS / service network
 ▼
postgres:5432
```

instead of:

```text
API
 │
 ▼
Host Port
 │
 ▼
PostgreSQL
```

The former provides a smaller exposure surface.

---

# 24. Persistent Volumes

The Compose configuration defines named volumes:

```text
postgres_data
redis_data
minio_data
prometheus_data
grafana_data
loki_data
alertmanager_data
```

The logical model is:

```text
Container
    │
    ▼
Named Volume
    │
    ▼
Persistent Host Storage
```

Named volumes decouple data persistence from individual container instances.

---

# 25. Application Data Volumes

Application persistence is represented by:

```text
postgres_data
redis_data
minio_data
```

These correspond to:

```text
PostgreSQL
Redis
MinIO
```

They should be treated as workload data rather than disposable container state.

---

# 26. Observability Data Volumes

Observability persistence is represented by:

```text
prometheus_data
grafana_data
loki_data
alertmanager_data
```

This allows the observability stack to preserve its state across container recreation.

The distinction is:

```text
Container
    ≠
Persistent Data
```

Removing or recreating a container does not inherently mean that its named volume should be removed.

---

# 27. Docker Restart Policies

Most long-running services use:

```text
restart: always
```

This includes the application and observability services.

The purpose is to allow Docker to restart containers after conditions such as:

```text
Process failure
Container exit
Docker restart
Host reboot
```

The relationship is:

```text
Process Failure
      │
      ▼
Container Exit
      │
      ▼
Docker Restart Policy
      │
      ▼
Container Restart
```

However, restart policy is not equivalent to application-level recovery.

---

# 28. Restart Policy Versus Reliability

Docker's:

```text
restart: always
```

does not replace the application's Reliability Architecture.

For example:

```text
Docker
    → restarts failed container

Application Runtime
    → classifies failures

Application Runtime
    → applies timeout/retry policy

Application Runtime
    → determines recoverability
```

These are different layers.

A container restart recovers a process-level failure; it does not provide semantic recovery for an individual operation or job.

---

# 29. API Health Check

The API container defines a health check against:

```text
/health/ready
```

The check uses:

```text
curl -f http://localhost:80/health/ready
```

with:

```text
interval: 30s
timeout: 5s
retries: 3
```

This creates a relationship between:

```text
API Runtime
      │
      ▼
Readiness Endpoint
      │
      ▼
Docker Health State
```

The endpoint itself performs actual system health verification rather than merely checking process existence.

---

# 30. Worker Health Check

The Worker currently uses:

```text
node -e "process.exit(0)"
```

as its container health check.

This verifies that the container can execute a Node.js process successfully.

It does **not** verify the full Worker operational path.

Therefore the current health semantics are closer to:

```text
Container Execution Health
```

than:

```text
Worker Business Readiness
```

This distinction should remain explicit.

Worker-specific operational health is better represented through:

```text
Metrics
Queue state
Dependency health
Job processing behaviour
```

and can be strengthened later if the Worker runtime exposes a dedicated readiness mechanism.

---

# 31. Dependency Ordering

The Compose configuration uses `depends_on` with health conditions where appropriate.

For example, the API depends on:

```text
postgres
redis
```

being healthy.

The Worker depends on:

```text
redis
postgres
storage
```

being healthy.

The conceptual startup relationship is:

```text
PostgreSQL ─┐
            ├──► API
Redis ──────┘

PostgreSQL ─┐
Redis ──────┼──► Worker
MinIO ──────┘
```

This reduces the probability that application containers begin operation before required dependencies are ready.

---

# 32. Dependency Readiness Versus Availability

`depends_on` should not be interpreted as a complete distributed-systems readiness mechanism.

It primarily controls Compose startup ordering and dependency conditions.

Once the stack is running:

```text
PostgreSQL may fail
Redis may fail
MinIO may fail
```

without Docker automatically solving the application-level consequences.

Those failures belong to:

```text
Application Runtime
Reliability Architecture
Observability
Operations
```

---

# 33. Container Resource Limits

The Compose configuration defines memory and CPU limits for services.

Examples include:

```text
gateway
    mem_limit: 128m
    cpus: "0.2"

api
    mem_limit: 512m
    cpus: "0.5"

worker
    mem_limit: 1024m
    cpus: "1.0"
```

and corresponding limits for infrastructure and observability services.

This creates an explicit resource contract:

```text
Host Resources
      │
      ▼
Docker Resource Controls
      │
      ▼
Per-Service Budget
```

---

# 34. Why Resource Limits Matter

Without container-level limits, one workload could consume disproportionate host resources.

For example:

```text
Worker
   │
   ▼
High CPU / Memory Usage
   │
   ▼
Host Resource Pressure
   │
   ├── API degradation
   ├── Database degradation
   └── Observability degradation
```

Resource limits therefore act as a basic containment mechanism.

They do not guarantee performance, but they reduce uncontrolled resource consumption.

---

# 35. Worker Resource Budget

The Worker has a larger memory and CPU allocation:

```text
memory: 1024m
CPU:    1.0
```

This reflects its role as a potentially CPU- and memory-intensive background processing service.

The allocation is an infrastructure-level expression of workload characteristics.

It should not be interpreted as a guaranteed performance capacity.

---

# 36. Logging Configuration

Application containers use Docker's:

```text
json-file
```

logging driver.

The configuration limits log growth through:

```text
max-size: 10m
max-file: 3
```

The effective local retention is therefore bounded at the Docker container log layer.

Conceptually:

```text
Application stdout/stderr
        │
        ▼
Docker json-file
        │
        ├── 10 MB maximum per file
        └── 3 files retained
```

This is an important host-protection mechanism.

---

# 37. Docker Logs and Promtail

Promtail reads Docker container logs through:

```text
/var/lib/docker/containers
```

using a read-only mount.

The relationship is:

```text
Container stdout/stderr
        │
        ▼
Docker json-file
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

Therefore Docker's logging configuration is directly coupled to the observability architecture.

Changing the Docker logging driver requires evaluating the Promtail collection strategy.

---

# 38. Deployment Logs

Promtail also reads:

```text
/opt/deploy/logs/*.log
```

This provides a second log source:

```text
Container Logs
     │
     ▼
Docker
     │
     ▼
Promtail
```

and:

```text
Deployment Scripts
     │
     ▼
/opt/deploy/logs
     │
     ▼
Promtail
```

Both eventually converge on:

```text
Loki
```

---

# 39. Prometheus Container

Prometheus runs as:

```text
prom/prometheus:v2.53.0
```

and stores its data in:

```text
prometheus_data
```

The service consumes:

```text
observability/prometheus/prometheus.yml
observability/prometheus/rules/
```

through read-only mounts.

Its role is:

```text
Metrics Collection
        │
        ▼
Time-Series Storage
        │
        ▼
Alert Rule Evaluation
```

---

# 40. Loki Container

Loki runs as:

```text
grafana/loki:3.0.0
```

and stores data in:

```text
loki_data
```

Its configuration is mounted read-only.

Its role is:

```text
Log Ingestion
     │
     ▼
Log Storage
     │
     ▼
Log Query
```

---

# 41. Promtail Container

Promtail runs as:

```text
grafana/promtail:3.0.0
```

and collects:

```text
Docker container logs
Deployment logs
```

It requires read-only access to:

```text
/var/lib/docker/containers
/var/run/docker.sock
/opt/deploy/logs
```

The Docker socket mount is particularly sensitive.

Although mounted read-only, Docker socket access can represent significant control over the Docker environment depending on how it is used.

Therefore Promtail should be treated as a privileged observability component.

---

# 42. Alertmanager Container

Alertmanager runs as:

```text
prom/alertmanager:v0.28.1
```

and persists its state through:

```text
alertmanager_data
```

It receives alerts from Prometheus and applies routing/grouping/inhibition policies.

The architecture is:

```text
Prometheus
    │
    ▼
Alertmanager
    │
    ▼
Alert Routing
```

The current Alertmanager configuration defines separate receivers for:

```text
critical
warning
info
```

even though external notification integrations are currently placeholders.

---

# 43. Grafana Container

Grafana runs as:

```text
grafana/grafana:11.0.0
```

and stores its state in:

```text
grafana_data
```

Grafana consumes:

```text
Prometheus
Loki
Alertmanager
```

and provisions dashboards and data sources from the repository configuration.

The resulting observability path is:

```text
Prometheus ─────┐
                │
Loki ───────────┼──► Grafana
                │
Alertmanager ───┘
```

---

# 44. Node Exporter

Node Exporter provides host-level metrics.

It uses:

```text
prom/node-exporter:v1.8.2
```

and mounts the host filesystem read-only.

It also exposes the deployment metrics directory to its textfile collector.

The conceptual flow is:

```text
Host
 │
 ├── CPU
 ├── Memory
 ├── Filesystem
 └── Deployment Metrics
          │
          ▼
    Node Exporter
          │
          ▼
      Prometheus
```

---

# 45. cAdvisor

cAdvisor provides container-level resource metrics.

It observes:

```text
Containers
CPU
Memory
Filesystem
Runtime information
```

and exposes those metrics to Prometheus.

Its deployment requires elevated privileges and access to host runtime paths.

Therefore it is another intentionally privileged observability component.

---

# 46. Redis Exporter

Redis Exporter translates Redis operational state into Prometheus metrics.

The architecture is:

```text
Redis
  │
  ▼
Redis Exporter
  │
  ▼
Prometheus
```

The exporter connects internally through:

```text
redis://redis:6379
```

rather than requiring Redis itself to be exposed on a host port.

---

# 47. PostgreSQL Exporter

PostgreSQL Exporter performs the corresponding function for PostgreSQL.

The relationship is:

```text
PostgreSQL
     │
     ▼
Postgres Exporter
     │
     ▼
Prometheus
```

The exporter connects through the backend Docker network.

This allows database observability without publishing PostgreSQL's database port to the host.

---

# 48. Container Naming

Several observability services explicitly define container names such as:

```text
mw-prometheus
mw-loki
mw-promtail
mw-alertmanager
mw-grafana
mw-node-exporter
mw-cadvisor
mw-redis-exporter
mw-postgres-exporter
```

This provides stable human-readable names for operational inspection.

However, service-to-service communication should continue to rely on Compose service names rather than hard-coded container names wherever possible.

The distinction is:

```text
Operational Identification
    → container_name

Service Discovery
    → Compose service name
```

---

# 49. Image Version Pinning

The Compose configuration uses explicit image tags such as:

```text
nginx:1.25-alpine
redis:7-alpine
postgres:15-alpine
prom/prometheus:v2.53.0
grafana/loki:3.0.0
grafana/promtail:3.0.0
prom/alertmanager:v0.28.1
grafana/grafana:11.0.0
```

This is preferable to using:

```text
latest
```

because the infrastructure definition records an explicit expected version.

However, a mutable tag such as:

```text
redis:7-alpine
```

may still resolve to different patch releases over time.

For stronger reproducibility, future hardening can move toward immutable image digests.

---

# 50. Image Reproducibility

The strongest container reproducibility model is:

```text
Image Tag
     +
Immutable Digest
```

rather than:

```text
Mutable Tag
```

The current design provides useful version pinning but does not yet make every image cryptographically immutable through digests.

This should be considered a future infrastructure-hardening opportunity rather than a reason to obscure the current architecture.

---

# 51. Secrets and Environment Variables

The Compose configuration consumes environment variables such as:

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

The staging environment file is managed through:

```text
/opt/deploy/env/.env.staging
```

The intended flow is:

```text
Protected Configuration
        │
        ▼
.env.staging
        │
        ▼
Docker Compose
        │
        ▼
Container Environment
```

Secrets should not be hard-coded into the Compose template.

---

# 52. Environment File Ownership

The environment file is initially rendered by Ansible and later assigned controlled ownership and permissions.

The configured mode is:

```text
0640
```

This provides more protection than a world-readable environment file.

However, environment variables inside containers should still be considered sensitive because processes with sufficient container access may inspect them.

File permissions are therefore one layer of secret protection, not the complete secret-management strategy.

---

# 53. Docker Security Boundary

Docker creates several security boundaries:

```text
Host
 │
 ▼
Docker Engine
 │
 ├── Container filesystem
 ├── Network namespace
 ├── Process namespace
 └── Resource controls
```

However, containers are not equivalent to complete virtual machines.

The Docker daemon itself remains a highly privileged host component.

Therefore:

```text
Container Isolation
    ≠
Complete Security Isolation
```

The current architecture should be understood accordingly.

---

# 54. Privileged Containers

Some observability components require elevated privileges.

For example, cAdvisor uses:

```text
privileged: true
```

and host-level mounts.

This is justified by the monitoring requirement but increases the security impact of that component.

The principle is:

```text
Privilege
   ↓
Only when required
   ↓
Prefer read-only host mounts
   ↓
Keep privilege scoped to infrastructure purpose
```

---

# 55. Docker Socket Exposure

Promtail mounts:

```text
/var/run/docker.sock
```

read-only.

This allows Docker metadata and runtime information to be accessed.

The mount should nevertheless be treated as security-sensitive.

The relevant boundary is:

```text
Docker Socket
      │
      ▼
Container
      │
      ▼
Potential Docker Control Plane Visibility
```

Therefore any component receiving Docker socket access should be treated as trusted infrastructure.

---

# 56. Host Firewall and Docker

The host firewall is configured through UFW.

However, Docker networking and port publishing introduce additional considerations because Docker manipulates host networking rules.

Therefore the effective exposure model is:

```text
Internet
   │
   ▼
Host Network
   │
   ├── UFW
   │
   └── Docker Port Publishing
            │
            ▼
         Containers
```

The firewall configuration must therefore be evaluated together with Compose `ports:` declarations.

---

# 57. External Exposure Review

The safest default is:

```text
No host port
```

unless a service explicitly needs external access.

The current stack intentionally publishes several operational interfaces.

These should be reviewed according to the staging environment's access requirements.

In particular:

```text
Grafana
Prometheus
Alertmanager
Loki
MinIO API
MinIO Console
```

are operational interfaces rather than application endpoints.

Their exposure should not automatically be assumed to be equivalent to the public API.

---

# 58. Docker DNS and Service Discovery

Compose provides service-name-based communication.

For example:

```text
api
redis
postgres
storage
prometheus
loki
alertmanager
```

can be resolved through the Docker network.

This enables configuration such as:

```text
redis:6379
postgres:5432
storage:9000
prometheus:9090
loki:3100
alertmanager:9093
```

without depending on host IP addresses.

This is one of the main reasons containerized service discovery remains stable even when container instances are recreated.

---

# 59. Container Lifecycle

The lifecycle of an application container is:

```text
Image
  │
  ▼
Create
  │
  ▼
Attach Networks
  │
  ▼
Mount Volumes
  │
  ▼
Inject Environment
  │
  ▼
Start Process
  │
  ▼
Health Check
  │
  ▼
Running
```

If the process exits:

```text
Running
   │
   ▼
Exited
   │
   ▼
Restart Policy
   │
   ▼
Started Again
```

Persistent state remains in named volumes where configured.

---

# 60. Container Recreation

Container recreation should be considered a normal operational action.

For stateless services such as:

```text
gateway
api
worker
```

the container itself should be disposable.

For stateful services:

```text
postgres
redis
storage
```

the container should also be replaceable, but the persistent data volume must be preserved.

Therefore:

```text
Container
    → Replaceable

Volume
    → Stateful
```

This distinction is central to safe Docker operations.

---

# 61. Stateless Application Containers

The API and Worker should be treated as stateless compute units from the Docker perspective.

Their durable state belongs outside the container filesystem.

For example:

```text
API
 │
 ├── Code → Image
 ├── Runtime → Container
 └── Durable State → External Services

Worker
 │
 ├── Code → Image
 ├── Runtime → Container
 └── Durable State → Redis / PostgreSQL / MinIO
```

This enables application releases through image replacement rather than mutable in-container installation.

---

# 62. Stateful Infrastructure Containers

PostgreSQL, Redis, and MinIO maintain persistent state.

Their architecture is:

```text
Service Container
       │
       ▼
Named Volume
       │
       ▼
Persistent Data
```

The operational consequence is that container replacement should be separated from data lifecycle operations.

Removing a container should not imply deleting its data volume.

---

# 63. Docker and Deployment State

The deployment system maintains application version state separately from Docker's container state.

The deployment state:

```text
current.api
current.worker
previous.api
previous.worker
```

tracks application deployment versions.

Docker tracks:

```text
Container
Image
Network
Volume
Runtime State
```

These are related but not interchangeable.

The architecture is:

```text
Deployment State
      │
      ▼
Desired Application Version
      │
      ▼
Docker Image
      │
      ▼
Container
```

---

# 64. Docker and Rollback

Docker provides the primitive required for image-based rollback:

```text
Previous Image
       │
       ▼
Recreate Container
```

But Docker does not decide:

```text
When rollback is required
Which version is healthy
Why a deployment failed
Whether data is compatible
```

Those decisions belong to the deployment and operational layers.

---

# 65. Docker and Reliability Architecture

The relationship between Docker and Mini-Write Reliability can be summarized as:

```text
Infrastructure Reliability
        │
        ▼
Docker Restart / Resource / Health Controls
        │
        ▼
Application Runtime Reliability
        │
        ▼
Operation-Level Timeout / Retry / Recovery
        │
        ▼
Business Workflow Reliability
```

Each layer addresses a different failure domain.

---

# 66. Failure Domains

Docker introduces several infrastructure-level failure domains.

Examples:

```text
Docker daemon failure
Container process failure
Container network failure
Volume failure
Resource exhaustion
Image pull failure
Host filesystem failure
Host reboot
```

The application runtime introduces different domains:

```text
Dependency timeout
Transient dependency failure
Operation failure
Business validation failure
Workflow failure
```

The failure model should not collapse these into one generic "container failure".

---

# 67. Resource Exhaustion

Resource pressure can originate from:

```text
Host
Container
Process
```

The observability architecture monitors host and container resources through:

```text
Node Exporter
cAdvisor
Prometheus
Grafana
Alertmanager
```

The flow is:

```text
Host / Container
      │
      ▼
Metrics Exporter
      │
      ▼
Prometheus
      │
      ▼
Alert Rule
      │
      ▼
Alertmanager
```

This makes Docker resource constraints observable rather than invisible.

---

# 68. Docker Health Is Not System Health

A container can be:

```text
running
```

while the application is unhealthy.

Similarly, a container can pass a basic health check while a dependency is degraded.

Therefore system health should be evaluated at multiple levels:

```text
Container Health
       │
       ▼
Application Health
       │
       ▼
Dependency Health
       │
       ▼
Workflow Health
       │
       ▼
System Health
```

This is particularly important for the Worker.

---

# 69. Observability Integration

Docker is a major source of telemetry.

The current architecture collects:

```text
Container logs
Container resource metrics
Host metrics
Application metrics
Dependency metrics
```

The resulting observability pipeline is:

```text
                 ┌──► Prometheus
                 │
Containers ──────┤
                 │
                 └──► Promtail → Loki
```

with:

```text
Prometheus
    │
    ├── Grafana
    └── Alertmanager
```

Docker is therefore not isolated from observability; it is part of its data-generation layer.

---

# 70. Operational Commands

Operational inspection should generally begin with Docker's current state.

Useful inspection categories include:

```text
Container status
Image status
Network membership
Volume state
Container health
Container logs
Resource consumption
```

Typical commands include:

```bash
docker ps
docker ps -a
docker images
docker network ls
docker volume ls
docker stats
docker compose ps
docker compose logs
```

These commands should be used for diagnosis rather than as substitutes for the infrastructure-as-code source of truth.

---

# 71. Inspecting a Service

A service investigation should follow a layered sequence:

```text
1. Is the container running?
2. Is the container healthy?
3. Is the expected image running?
4. Is it attached to the correct networks?
5. Are expected volumes mounted?
6. Are environment variables available?
7. Are dependencies reachable?
8. Are application logs showing failures?
9. Are metrics showing degradation?
```

This prevents jumping immediately to container recreation without understanding the failure.

---

# 72. Container Restart as a Diagnostic Action

Restarting a container can temporarily recover a process-level problem.

However:

```text
Restart
    ≠
Root Cause Analysis
```

If a container repeatedly restarts:

```text
Container
   │
   ▼
Crash
   │
   ▼
Restart
   │
   ▼
Crash
   │
   ▼
Restart
```

the correct response is to investigate:

```text
Application logs
Configuration
Dependencies
Resource limits
Health checks
Image version
```

rather than treating repeated restarts as successful recovery.

---

# 73. Common Docker Failure Scenarios

## 73.1 Container Does Not Start

Investigate:

```text
Image availability
Environment variables
Mounts
Port conflicts
Container logs
```

---

## 73.2 Container Starts Then Exits

Investigate:

```text
Application startup
Configuration
Dependency availability
Process exit code
```

---

## 73.3 Container Is Running but Unhealthy

Investigate:

```text
Health check command
Application readiness
Dependency readiness
Internal networking
```

---

## 73.4 API Cannot Reach PostgreSQL

Investigate:

```text
backend-network membership
PostgreSQL health
service name
credentials
PostgreSQL readiness
```

---

## 73.5 Worker Cannot Reach Redis

Investigate:

```text
backend-network membership
Redis health
Redis service name
queue configuration
```

---

## 73.6 Logs Are Missing from Loki

Investigate:

```text
Docker logging driver
/var/lib/docker/containers
Promtail
Loki
Promtail pipeline configuration
```

---

# 74. Docker Configuration Ownership

The current ownership model is:

| Configuration                | Owner                    |
| ---------------------------- | ------------------------ |
| Docker installation          | Ansible                  |
| Docker daemon                | Host/systemd             |
| Compose topology             | Deployment Runtime       |
| Container image selection    | Deployment configuration |
| Network definitions          | Compose                  |
| Volume definitions           | Compose                  |
| Container resource limits    | Compose                  |
| Restart policy               | Compose                  |
| Health checks                | Compose                  |
| Application runtime behavior | Application              |
| Deployment decision          | CI/CD / deployment layer |
| Persistent data lifecycle    | Data/operations layer    |

This prevents Docker from becoming an unbounded configuration layer.

---

# 75. What Docker Should Not Own

Docker should not become responsible for:

```text
Business logic
Application reliability policy
Request-level retry decisions
Business workflow recovery
Incident classification
Deployment approval
Application data semantics
```

For example:

```text
Docker sees:
    container exited

Application sees:
    dependency timeout during ID upload

Operations sees:
    elevated ID upload failure rate

```

These are three different layers of the same event.

---

# 76. Production Evolution

The current architecture is intentionally single-node.

The Compose model can later evolve toward:

```text
Single Docker Host
        │
        ▼
Multiple Hosts
        │
        ▼
Container Orchestration
        │
        ▼
Kubernetes
```

However, the architectural boundaries already established remain useful:

```text
Service boundaries
Network boundaries
Health semantics
Resource budgets
Persistent storage boundaries
Observability
Deployment automation
```

The migration should therefore be viewed as changing the orchestration substrate rather than redesigning every application responsibility.

---

# 77. Docker to Kubernetes Mapping

The current concepts have natural future equivalents.

| Docker / Compose         | Future Kubernetes Concept                |
| ------------------------ | ---------------------------------------- |
| Service container        | Pod / Deployment                         |
| Compose service          | Kubernetes Deployment/Service            |
| Docker network           | Kubernetes Network / CNI                 |
| Named volume             | PersistentVolume / PersistentVolumeClaim |
| Environment file         | Secret / ConfigMap                       |
| Healthcheck              | Liveness / Readiness Probe               |
| Resource limits          | Resource Requests / Limits               |
| Restart policy           | Controller-managed restart               |
| Compose deployment       | Kubernetes controller                    |
| Docker service discovery | Kubernetes Service/DNS                   |

This does not mean Kubernetes is required now.

It demonstrates that the current architecture is being built with recognizable infrastructure abstractions.

---

# 78. Current Architectural Constraints

The Docker architecture intentionally operates under several constraints:

```text
Single host
Single Docker Engine
Docker Compose
Bridge networking
Local named volumes
Self-hosted CI/CD runner
No Kubernetes
No cloud infrastructure
```

These constraints define the current operational boundary.

They are not accidental implementation limitations.

---

# 79. Current Strengths

The current Docker architecture provides:

```text
Reproducible container topology
Service isolation
Network segmentation
Persistent volumes
Resource limits
Health checks
Restart policies
Centralized logging integration
Metrics integration
CI/CD integration
Infrastructure-as-code provisioning
```

These capabilities provide a strong foundation for the project's current stage.

---

# 80. Current Limitations

The current architecture also has explicit limitations.

### Single Host

A host failure affects the entire workload.

```text
Host Failure
    ↓
Entire Stack Unavailable
```

### Local Volumes

Persistent data remains tied to the host unless backed up or migrated.

### Compose Orchestration

There is no multi-node scheduling or automatic cross-host failover.

### Manual Image Lifecycle

Image promotion and rollback remain deployment-layer responsibilities.

### Limited Container Health Semantics

Some health checks, especially the Worker check, are basic process-level checks.

### Mutable Image Tags

Not every image is pinned by immutable digest.

These limitations are architectural facts and should be considered when evaluating future evolution.

---

# 81. Docker Definition of Done

The Docker infrastructure layer is considered correctly established when:

```text
Docker Engine
    ✓ Installed
    ✓ Enabled
    ✓ Running

Deployment User
    ✓ Has Docker access

Compose
    ✓ Rendered
    ✓ Valid
    ✓ Available on host

Networks
    ✓ Created correctly
    ✓ Services attached appropriately

Volumes
    ✓ Declared
    ✓ Persistent services mapped correctly

Containers
    ✓ Correct images
    ✓ Correct configuration
    ✓ Correct resource limits
    ✓ Correct restart policies

Health
    ✓ Required health checks configured

Observability
    ✓ Logs collectible
    ✓ Metrics collectible
```

---

# 82. Final Docker Architecture

The complete Docker architecture can be summarized as:

```text
┌───────────────────────────────────────────────────────────────┐
│                         Ubuntu Host                           │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                     Docker Engine                       │  │
│  │                                                         │  │
│  │   frontend-network                                     │  │
│  │        │                                                │  │
│  │   ┌────┴────┐                                           │  │
│  │   │ Gateway │                                           │  │
│  │   └────┬────┘                                           │  │
│  │        │                                                │  │
│  │      ┌─▼─┐                                              │  │
│  │      │API│                                              │  │
│  │      └─┬─┘                                              │  │
│  │        │                                                │  │
│  │   backend-network                                       │  │
│  │        │                                                │  │
│  │   ┌────┼───────────────┬──────────┐                    │  │
│  │   ▼    ▼               ▼          ▼                    │  │
│  │ Redis PostgreSQL      MinIO      Worker                 │  │
│  │   │      │              │          │                    │  │
│  │   └──────┴──────────────┴──────────┘                    │  │
│  │                                                         │  │
│  │   Observability                                         │  │
│  │   ┌──────────┐ ┌──────┐ ┌─────────────┐                │  │
│  │   │Prometheus│ │ Loki │ │ Alertmanager│                │  │
│  │   └────┬─────┘ └───┬──┘ └──────┬──────┘                │  │
│  │        │            │             │                     │  │
│  │        └────────────┼─────────────┘                     │  │
│  │                     ▼                                   │  │
│  │                  Grafana                                │  │
│  │                                                         │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  Persistent Volumes                                           │
│  ├── PostgreSQL                                               │
│  ├── Redis                                                    │
│  ├── MinIO                                                    │
│  ├── Prometheus                                               │
│  ├── Loki                                                     │
│  ├── Grafana                                                  │
│  └── Alertmanager                                             │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

---

# 83. Summary

Docker provides Mini-Write with a controlled container execution layer between the Ubuntu host and the application services.

The architecture establishes:

```text
Host
  ↓
Docker Engine
  ↓
Compose Topology
  ↓
Networks
  ↓
Containers
  ↓
Volumes
  ↓
Application + Infrastructure + Observability
```

The most important architectural boundaries are:

```text
Docker
    → container lifecycle and isolation

Compose
    → service topology

Ansible
    → host provisioning and configuration rendering

CI/CD
    → application deployment

Application Runtime
    → operation-level reliability

Observability
    → system visibility

Operations
    → incident handling and recovery
```

The current Docker implementation is deliberately single-node and Compose-based, but it already establishes the core abstractions required for a more advanced orchestration environment.

The central principle is:

> **Docker provides the execution substrate and containment boundaries; it does not become the owner of application semantics, deployment decisions, or operational recovery.**

```
```
