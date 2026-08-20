# Networking Architecture

## 1. Purpose

This document defines the networking architecture of Mini-Write.

It describes:

- network topology;
- traffic boundaries;
- Docker network segmentation;
- service-to-service communication;
- externally exposed ports;
- internal service connectivity;
- ingress flow;
- observability traffic;
- network isolation boundaries;
- dependency communication paths;
- security implications;
- current limitations;
- evolution toward multi-node/container orchestration.

The purpose is to make the network behavior of Mini-Write explicit and understandable without requiring the reader to reconstruct it from `docker-compose.staging.yml`.

---

# 2. Networking Model

Mini-Write currently runs on a single staging host using Docker Compose.

The networking architecture therefore has two major layers:

```text
┌───────────────────────────────────────────────────────┐
│                    Host Network                       │
│                                                       │
│   External / Host Traffic                            │
│             │                                         │
│             ▼                                         │
│        Docker Published Ports                         │
│             │                                         │
│      ┌──────┴──────────────────────────┐              │
│      │                                 │              │
│      ▼                                 ▼              │
│ frontend-network                  backend-network    │
│      │                                 │              │
│      ▼                                 ▼              │
│   Gateway / API             Application + Infra       │
│                              + Observability           │
└───────────────────────────────────────────────────────┘
````

The architecture uses Docker bridge networks to create logical Layer-4 communication boundaries between service groups.

The two primary application networks are:

```text
frontend-network
backend-network
```

---

# 3. Network Topology

The high-level topology is:

```text
                         External Client
                               │
                               │ HTTP
                               ▼
                      Host Published Port
                               │
                               ▼
                         ┌──────────┐
                         │ Gateway  │
                         │  Nginx   │
                         └────┬─────┘
                              │
                     frontend-network
                              │
                              ▼
                           ┌─────┐
                           │ API │
                           └──┬──┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼
             backend-network      backend-network
                    │                   │
                    ▼                   ▼
               PostgreSQL             Redis
                    │                   │
                    │                   │
                    └────────┬──────────┘
                             │
                             ▼
                          Worker
```

The observability platform is also attached primarily to `backend-network`.

---

# 4. Docker Networks

Mini-Write defines two Docker bridge networks.

## 4.1 `frontend-network`

```yaml
frontend-network:
  driver: bridge
```

Its primary purpose is to provide connectivity between:

* Gateway;
* API.

The intended traffic model is:

```text
Gateway
   │
   ▼
API
```

The Worker and primary infrastructure services do not need to participate in this network.

---

## 4.2 `backend-network`

```yaml
backend-network:
  driver: bridge
```

Its purpose is to provide connectivity between application services and infrastructure services.

It contains services such as:

* API;
* Worker;
* PostgreSQL;
* Redis;
* MinIO;
* Prometheus;
* Loki;
* Promtail;
* Alertmanager;
* Grafana;
* Node Exporter;
* cAdvisor;
* Redis Exporter;
* PostgreSQL Exporter.

The intended model is:

```text
             backend-network
                    │
       ┌────────────┼─────────────┐
       │            │             │
       ▼            ▼             ▼
      API         Worker      Infrastructure
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
                PostgreSQL      Redis          MinIO
```

---

# 5. Network Membership

The service network membership is intentionally asymmetric.

| Service             | frontend-network | backend-network |
| ------------------- | ---------------: | --------------: |
| Gateway             |              Yes |              No |
| API                 |              Yes |             Yes |
| Worker              |               No |             Yes |
| PostgreSQL          |               No |             Yes |
| Redis               |               No |             Yes |
| MinIO               |               No |             Yes |
| Prometheus          |               No |             Yes |
| Loki                |               No |             Yes |
| Promtail            |               No |             Yes |
| Alertmanager        |               No |             Yes |
| Grafana             |               No |             Yes |
| Node Exporter       |               No |             Yes |
| cAdvisor            |               No |             Yes |
| Redis Exporter      |               No |             Yes |
| PostgreSQL Exporter |               No |             Yes |

This produces an important architectural property:

```text
Gateway
   │
   │ frontend
   ▼
  API
   │
   │ backend
   ▼
Infrastructure
```

The Gateway is not directly attached to the backend network.

---

# 6. Network Segmentation Principle

The network architecture follows the principle:

> A service should be connected only to the networks required for its responsibilities.

The API is the exception that intentionally participates in both application-facing and backend communication:

```text
frontend-network
       │
       ▼
      API
       │
       ▼
backend-network
```

This allows the API to act as the application boundary between external HTTP traffic and internal infrastructure.

---

# 7. API Network Position

The API is a dual-network service.

```text
              frontend-network
                     │
                     ▼
                  ┌─────┐
                  │ API │
                  └──┬──┘
                     │
              backend-network
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
    PostgreSQL      Redis        MinIO
```

This is intentional.

The API requires:

* frontend connectivity for Gateway traffic;
* backend connectivity for infrastructure operations.

The API therefore forms a controlled boundary between the two network domains.

---

# 8. Gateway Network Position

The Gateway is connected only to `frontend-network`.

```text
External
   │
   ▼
Host
   │
   ▼
Gateway
   │
frontend-network
   │
   ▼
API
```

The Gateway does not need direct connectivity to:

* PostgreSQL;
* Redis;
* MinIO;
* Worker;
* Prometheus;
* Loki.

This reduces the Gateway's network reachability.

---

# 9. Worker Network Position

The Worker is connected only to `backend-network`.

```text
              backend-network
                     │
                     ▼
                  Worker
                 /      \
                /        \
               ▼          ▼
            Redis      PostgreSQL
                         │
                         │
                         ▼
                       MinIO
```

The Worker has no direct external HTTP ingress path.

Its communication model is internal:

```text
Redis → Worker
Worker → PostgreSQL
Worker → MinIO
```

---

# 10. Service Discovery

Docker Compose provides service-name-based network discovery.

Services communicate using their Compose service names rather than hard-coded host IP addresses.

Examples:

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

For example, the API can reach PostgreSQL through the service name:

```text
postgres
```

and Redis through:

```text
redis
```

Similarly, the Worker reaches object storage through:

```text
storage
```

This means the application architecture is not coupled to dynamically assigned container IP addresses.

---

# 11. Internal Port Model

Container-to-container communication uses the service's container port.

For example:

```text
API
  └── port 80

Redis
  └── port 6379

PostgreSQL
  └── port 5432

MinIO
  ├── port 9000
  └── port 9001
```

When two containers communicate on the same Docker network, the host-published port is generally not required.

For example:

```text
API → PostgreSQL:5432
API → Redis:6379
API → storage:9000
Worker → Redis:6379
Worker → PostgreSQL:5432
Worker → storage:9000
```

The communication path remains inside Docker networking.

---

# 12. External Port Publishing

The current Compose configuration publishes several container ports onto the host.

The primary published ports include:

| Service      | Host Port | Container Port | Purpose                  |
| ------------ | --------: | -------------: | ------------------------ |
| Gateway      |      `80` |           `80` | HTTP application ingress |
| MinIO        |   `19000` |         `9000` | Object Storage API       |
| MinIO        |   `19001` |         `9001` | MinIO Console            |
| Prometheus   |    `9090` |         `9090` | Metrics UI/API           |
| Loki         |    `3100` |         `3100` | Log API                  |
| Alertmanager |    `9093` |         `9093` | Alert management         |
| Grafana      |    `3000` |         `3000` | Observability UI         |

The Worker does not publish an external application port.

The PostgreSQL service does not publish a host port in the provided Compose configuration.

Redis does not publish a host port either.

This is an important distinction:

```text
Published Port
     ≠
Container Port
```

A service can listen on a container port without exposing that port to the host.

---

# 13. Primary Ingress Path

The primary application ingress path is:

```text
Client
  │
  │ HTTP
  ▼
Host:80
  │
  ▼
Gateway
  │
  │ frontend-network
  ▼
API:80
```

The Gateway is therefore the intended external entry point for application HTTP traffic.

The API should not be considered the primary external ingress boundary.

---

# 14. Gateway-to-API Communication

The Gateway proxies requests to the API.

Conceptually:

```text
Client
  │
  ▼
Nginx
  │
  │ HTTP
  ▼
API
```

This boundary allows the Gateway to provide infrastructure-level HTTP concerns while the API remains responsible for application behavior.

The separation is:

```text
Gateway
├── ingress
├── proxying
└── external boundary

API
├── authentication
├── application logic
├── Runtime
├── health
└── application observability
```

---

# 15. API-to-PostgreSQL Traffic

The API communicates with PostgreSQL through the backend network.

```text
API
 │
 │ PostgreSQL protocol
 │ port 5432
 ▼
PostgreSQL
```

The API does not require PostgreSQL to be externally published.

This provides an important isolation property:

```text
External Client
      │
      X
      │
PostgreSQL
```

The database is reachable by services attached to the backend network rather than by arbitrary external clients.

---

# 16. API-to-Redis Traffic

The API uses Redis for queue-related operations.

```text
API
 │
 │ Redis protocol
 │ port 6379
 ▼
Redis
```

The connection remains internal to `backend-network`.

The API's asynchronous workflow therefore follows:

```text
HTTP Request
     │
     ▼
API
     │
     ▼
Redis / BullMQ
     │
     ▼
Worker
```

---

# 17. Worker-to-Redis Traffic

The Worker consumes jobs from Redis/BullMQ.

```text
Worker
   │
   │ Redis
   ▼
Redis
```

This is the primary control path for asynchronous job execution.

The Worker does not need to receive external HTTP requests to process jobs.

---

# 18. API-to-MinIO Traffic

The API uses MinIO for object storage.

```text
API
 │
 │ S3-compatible API
 │ port 9000
 ▼
MinIO
```

This communication remains within `backend-network`.

The API therefore does not need to access the host-published MinIO port for normal service-to-service operations.

---

# 19. Worker-to-MinIO Traffic

The Worker may access the stored object through MinIO.

```text
Worker
   │
   │ S3-compatible API
   ▼
MinIO
```

This is part of the asynchronous processing workflow.

The resulting path is:

```text
Client
  │
  ▼
API
  │
  ├── MinIO
  │
  └── Redis
          │
          ▼
        Worker
          │
          ▼
        MinIO
```

---

# 20. API-to-Worker Network Relationship

There is no direct API-to-Worker network dependency for job dispatch.

The logical communication path is:

```text
API
 │
 ▼
Redis
 │
 ▼
Worker
```

This creates a queue-mediated communication boundary.

Therefore:

```text
API does not need:
Worker IP
Worker HTTP endpoint
Worker published port
```

The integration depends on the queue contract rather than on direct network reachability.

---

# 21. Observability Network

The observability platform is attached to the backend network.

Its communication graph is approximately:

```text
                       backend-network
                              │
       ┌──────────────────────┼────────────────────────┐
       │                      │                        │
       ▼                      ▼                        ▼
   Prometheus                Loki                 Alertmanager
       │                      ▲                        ▲
       │                      │                        │
       │                  Promtail                    │
       │                                               │
       ├─────────────── metrics ───────────────────────┤
       │
       ├── API
       ├── Worker
       ├── Redis Exporter
       ├── PostgreSQL Exporter
       ├── Node Exporter
       └── cAdvisor
                             
                    Grafana
                   /       \
                  ▼         ▼
             Prometheus    Loki
```

---

# 22. Prometheus Scrape Network

Prometheus uses pull-based collection.

It reaches targets through Docker networking.

Examples:

```text
Prometheus → api:80/metrics
Prometheus → worker:9464/metrics
Prometheus → redis-exporter:9121/metrics
Prometheus → postgres-exporter:9187/metrics
Prometheus → node-exporter:9100/metrics
Prometheus → cadvisor:8080/metrics
Prometheus → loki:3100/metrics
Prometheus → alertmanager:9093/metrics
```

The important architectural principle is:

```text
Application
    │
    │ exposes metrics
    ▼
Prometheus
    │
    │ scrapes
    ▼
Metrics Storage
```

The applications do not actively push their Prometheus metrics to Prometheus.

---

# 23. Loki and Promtail Network

Promtail collects logs and pushes them to Loki.

```text
Docker Logs
     │
     ▼
Promtail
     │
     │ HTTP
     ▼
Loki
```

The configured destination is:

```text
http://loki:3100/loki/api/v1/push
```

Promtail also reads deployment logs from:

```text
/opt/deploy/logs/*.log
```

Therefore log collection has two source categories:

```text
Docker Container Logs
        +
Deployment Logs
        │
        ▼
    Promtail
        │
        ▼
       Loki
```

---

# 24. Grafana Network

Grafana acts as a visualization and query client.

It accesses:

```text
Grafana
   ├── Prometheus
   └── Loki
```

The configured endpoints are:

```text
http://prometheus:9090
http://loki:3100
```

The communication remains internal to the backend network.

The user-facing Grafana UI is exposed through the host's published port:

```text
Host:3000 → Grafana:3000
```

Therefore the architecture distinguishes:

```text
User → Grafana UI
```

from:

```text
Grafana → Prometheus/Loki
```

---

# 25. Alerting Network

Prometheus sends alerts to Alertmanager.

```text
Prometheus
    │
    │ HTTP
    ▼
Alertmanager
```

Grafana also provisions an Alertmanager contact point.

The intended observability path is therefore:

```text
Metrics
   │
   ▼
Prometheus
   │
   │ alert rules
   ▼
Alertmanager
   │
   ▼
Notification Receiver
```

The current configuration defines the alert routing architecture but does not configure an external notification integration.

---

# 26. Network-Level Health Dependencies

Health checks use service-local or internal network communication.

Examples include:

```text
Gateway → API health
API → PostgreSQL
API → Redis
Worker → Redis
Worker → PostgreSQL
Worker → MinIO
```

The health model should therefore be interpreted in the context of network reachability.

A service can be:

```text
Process: UP
Network dependency: DOWN
Operational capability: DEGRADED
```

For example:

```text
API process running
       │
       ▼
PostgreSQL unreachable
       │
       ▼
Readiness / application operations degraded
```

---

# 27. Network Failure Domains

The network architecture creates several logical failure domains.

## 27.1 External Ingress Failure

```text
Client
  X
Gateway
```

Impact:

* external HTTP traffic unavailable.

---

## 27.2 Frontend Network Failure

```text
Gateway
  X
API
```

Impact:

* Gateway cannot reach API.

---

## 27.3 Backend Network Failure

```text
API
 X
PostgreSQL / Redis / MinIO
```

Impact:

* infrastructure-dependent application operations fail.

---

## 27.4 Queue Communication Failure

```text
API
 X
Redis
 X
Worker
```

Impact:

* asynchronous job dispatch or consumption is affected.

---

## 27.5 Observability Network Failure

```text
Applications
      X
Prometheus / Loki
```

Impact:

* telemetry collection becomes incomplete even if application functionality remains available.

This distinction is important:

> Observability failure does not necessarily equal application failure.

---

# 28. Network Security Boundary

The intended security model is:

```text
Internet / External Network
          │
          ▼
       Gateway
          │
          ▼
        API
          │
          ▼
    Backend Services
```

The architecture attempts to minimize direct exposure of infrastructure services.

In particular:

```text
PostgreSQL
Redis
Worker
```

do not have host-published ports in the provided staging Compose configuration.

This means they are not directly reachable through host port mappings.

---

# 29. Important Current Limitation: `backend-network` Is Not Docker-Internal

The Compose configuration contains:

```yaml
backend-network:
  driver: bridge
  # internal: true
```

The `internal: true` option is currently commented out.

Therefore the backend network is logically segmented from the frontend network, but it is **not configured as a fully Docker-internal network**.

This distinction is important.

The current architecture provides:

```text
Network membership isolation
```

but not the strongest possible:

```text
egress isolation
```

The commented configuration indicates an architectural intention to consider stronger backend isolation in a future evolution.

---

# 30. Why `internal: true` Is Not Automatically Enabled

Enabling:

```yaml
internal: true
```

would change the network's egress behavior.

That can affect services that require outbound connectivity, such as:

* image initialization;
* dependency access;
* external integrations;
* package or artifact retrieval;
* observability integrations.

Therefore enabling it should be treated as an architectural change rather than as a harmless security toggle.

Before enabling it, every backend service requiring external communication must be identified.

---

# 31. Host-Level Network Boundary

Docker networking exists inside the staging host.

The host itself is protected by the security baseline.

The current architecture therefore has two network control layers:

```text
External Network
       │
       ▼
Host Firewall / UFW
       │
       ▼
Docker Published Ports
       │
       ▼
Docker Networks
       │
       ▼
Containers
```

UFW determines which host ports are reachable at the host firewall layer.

Docker networking determines which containers can communicate internally.

These are different controls.

---

# 32. UFW and Container Networking

UFW should not be treated as a replacement for Docker network segmentation.

The controls operate at different levels.

```text
UFW
└── Host ingress policy

Docker Network
└── Container connectivity

Application Authentication
└── Application authorization
```

A secure architecture therefore requires all relevant layers to cooperate.

---

# 33. Port Exposure Principle

The architecture distinguishes between ports that are required externally and ports that are only required internally.

### External/application ingress

```text
80
```

### Observability administration

```text
3000
9090
9093
```

### Object storage administration/API

```text
19000
19001
```

### Internal-only service ports

```text
5432
6379
```

The actual exposure policy is determined by the Docker Compose port mappings and host firewall configuration.

A container listening on a port does not automatically mean that the port is externally reachable.

---

# 34. Network Addressing

The application does not rely on fixed container IP addresses.

Instead:

```text
Service Name
     │
     ▼
Docker DNS
     │
     ▼
Container IP
```

This allows containers to be recreated without requiring application configuration changes.

For example:

```text
redis
postgres
storage
api
worker
```

are stable service identities even when their underlying container IP addresses change.

---

# 35. Network Dependency Graph

The complete application dependency graph can be represented as:

```text
                           Client
                             │
                             ▼
                          Gateway
                             │
                             ▼
                            API
                      ┌──────┼──────┐
                      │      │      │
                      ▼      ▼      ▼
                  PostgreSQL Redis  MinIO
                      ▲      ▲      ▲
                      │      │      │
                      │      │      │
                      └──── Worker ──┘
                             │
                             ▼
                           Redis
```

A more precise representation of the asynchronous path is:

```text
Client
  │
  ▼
Gateway
  │
  ▼
API
  │
  ├──────────────► PostgreSQL
  │
  ├──────────────► MinIO
  │
  └──────────────► Redis
                         │
                         ▼
                       Worker
                         │
                 ┌───────┴───────┐
                 ▼               ▼
            PostgreSQL         MinIO
```

---

# 36. Observability Dependency Graph

Observability is logically attached to the backend network:

```text
API ────────────────┐
Worker ─────────────┤
Redis ──────────────┤
PostgreSQL ─────────┤
Host ───────────────┤
Containers ─────────┤
                    ▼
                Prometheus
                    │
                    ▼
               Alertmanager


Docker Logs ───────► Promtail
                       │
                       ▼
                      Loki
                       ▲
                       │
                    Grafana
                       ▲
                       │
                   Prometheus
```

This makes observability a consumer of service telemetry rather than a dependency of core application execution.

---

# 37. Network Observability

Network behavior itself is observable indirectly through:

* Prometheus target availability;
* service health checks;
* application errors;
* dependency failures;
* container metrics;
* host metrics;
* structured logs.

For example:

```text
Prometheus target DOWN
        │
        ▼
MWAPIDown
        │
        ▼
Investigate:
  ├── API container
  ├── Docker network
  ├── API process
  └── Prometheus connectivity
```

This makes network failures part of the broader Failure Engineering and Observability model.

---

# 38. Network Failure Handling

Network failures are classified at the Runtime dependency boundary when they affect application operations.

Relevant transient network errors include:

```text
ECONNRESET
ECONNREFUSED
EHOSTUNREACH
ENETUNREACH
EADDRNOTAVAIL
ETIMEDOUT
```

These can be classified as dependency failures and, where policy permits, become retry candidates.

The conceptual path is:

```text
Network Failure
      │
      ▼
Infrastructure Boundary
      │
      ▼
Failure Classification
      │
      ▼
Retry Decision
      │
      ├── Retry
      │
      └── Propagate Failure
```

Network reliability is therefore connected to the Runtime reliability architecture.

---

# 39. Timeout and Network Boundaries

Network operations must not be allowed to wait indefinitely.

The Runtime applies operation-specific timeout policies.

For example, an operation may have:

```text
timeout = 5000ms
```

or:

```text
timeout = 10000ms
```

The timeout boundary is:

```text
Application Operation
       │
       ▼
Reliability Executor
       │
       ├── operation
       │
       └── timeout
```

If the timeout expires:

```text
RuntimeTimeoutError
       │
       ▼
Failure Classification
       │
       ▼
Retry / Propagation
```

This protects the application from indefinite dependency waits.

---

# 40. Network and Asynchronous Reliability

The asynchronous path introduces an additional network dependency:

```text
API → Redis → Worker
```

A Redis connectivity failure can therefore produce two different effects.

### Producer side

```text
API
 │
 X
Redis
```

The API cannot enqueue the job.

### Consumer side

```text
Worker
 │
 X
Redis
```

The Worker cannot consume or coordinate jobs normally.

The same infrastructure dependency can therefore affect different service roles in different ways.

---

# 41. Network Isolation and Blast Radius

The network topology reduces unnecessary communication paths.

For example, Gateway is not connected directly to:

```text
PostgreSQL
Redis
MinIO
Worker
```

Therefore a compromise or misconfiguration at the Gateway layer does not automatically provide direct Docker-network access to all backend services.

The intended blast-radius structure is:

```text
Gateway
   │
   ▼
API
   │
   ▼
Backend
```

rather than:

```text
Gateway ─────────► Everything
```

---

# 42. Current Single-Host Constraint

The current networking architecture is optimized for a single Docker host.

All containers communicate through local Docker bridge networking:

```text
Single Host
│
├── frontend-network
│
└── backend-network
```

This means the current network topology does not provide native cross-host service networking.

If services are moved to multiple hosts, the network architecture must evolve.

---

# 43. Future Multi-Node Evolution

A future distributed deployment may replace local bridge networking with an orchestrator-managed network.

Conceptually:

```text
Current

Host
 └── Docker bridge networks
       ├── frontend
       └── backend
```

Future:

```text
Cluster
 └── Orchestrated Network
       ├── Gateway
       ├── API instances
       ├── Worker instances
       └── Infrastructure services
```

The important point is that the logical boundaries should survive the physical network change.

For example:

```text
Current:
API → Redis → Worker

Future:
API instances → Shared Queue → Worker pool
```

The communication model remains conceptually identical.

---

# 44. Kubernetes / Overlay Evolution

In a future multi-node architecture, Docker bridge networks may be replaced by:

* Kubernetes CNI networking;
* Docker overlay networking;
* another cluster-level networking implementation.

The current architecture already separates:

```text
Frontend communication
```

from:

```text
Backend communication
```

which provides a conceptual basis for future constructs such as:

```text
Ingress
NetworkPolicy
Service
ClusterIP
Internal Service
```

The current Compose architecture should therefore be understood as a single-host implementation of broader logical network boundaries.

---

# 45. Network Architecture Invariants

The following invariants should remain valid as the system evolves.

### Invariant 1

External application traffic enters through the Gateway.

```text
External → Gateway → API
```

### Invariant 2

Worker remains an internal processing service.

```text
Queue → Worker
```

### Invariant 3

Infrastructure services are not unnecessarily externally exposed.

### Invariant 4

Application-to-infrastructure communication occurs through internal service connectivity.

### Invariant 5

API-to-Worker asynchronous communication remains queue-mediated.

### Invariant 6

Observability services remain consumers of application telemetry rather than dependencies of application business execution.

### Invariant 7

Network segmentation should reduce unnecessary blast radius.

---

# 46. Common Networking Failure Scenarios

## 46.1 Gateway Cannot Reach API

```text
Client
  │
  ▼
Gateway
  │
  X
API
```

Possible causes:

* API container stopped;
* API health failure;
* frontend network failure;
* incorrect upstream configuration;
* Docker DNS failure;
* port mismatch.

---

## 46. API Cannot Reach PostgreSQL

```text
API
 │
 X
PostgreSQL
```

Possible causes:

* PostgreSQL unavailable;
* backend network failure;
* database startup delay;
* connection configuration error;
* resource exhaustion.

---

## 46. API Cannot Reach Redis

```text
API
 │
 X
Redis
```

Possible effects:

* asynchronous jobs cannot be enqueued;
* upload workflow may fail;
* queue-based processing becomes unavailable.

---

## 46. Worker Cannot Reach Redis

```text
Worker
 │
 X
Redis
```

Possible effects:

* jobs are not consumed;
* queue backlog grows;
* processing throughput drops.

---

## 46. Worker Cannot Reach MinIO

```text
Worker
 │
 X
MinIO
```

Possible effects:

* object-processing jobs fail;
* retries may occur according to the Worker Runtime policy;
* queue failure rate increases.

---

## 46. Prometheus Cannot Reach API

```text
Prometheus
 │
 X
API /metrics
```

The API may still serve users successfully.

The immediate impact is observability degradation rather than necessarily application outage.

---

# 47. Troubleshooting Sequence

When diagnosing networking failures, use the following order.

```text
1. Host
   │
   ▼
2. Container state
   │
   ▼
3. Network membership
   │
   ▼
4. Docker DNS/service name
   │
   ▼
5. Container port
   │
   ▼
6. Service health
   │
   ▼
7. Application configuration
   │
   ▼
8. Runtime / dependency failure
```

This prevents application-level debugging before basic network reachability has been established.

---

# 48. Network Troubleshooting Questions

For any failed communication, answer:

### 1. Is the source container running?

```text
Source → RUNNING?
```

### 2. Is the destination container running?

```text
Destination → RUNNING?
```

### 3. Are both containers on a common network?

```text
Source ─── Network ─── Destination
```

### 4. Does Docker DNS resolve the service name?

```text
service-name → container address
```

### 5. Is the destination listening on the expected container port?

### 6. Is the application actually accepting the connection?

### 7. Is the failure a timeout or immediate connection refusal?

These questions help distinguish:

```text
Network Reachability
```

from:

```text
Service Availability
```

and:

```text
Application Failure
```

---

# 49. Networking and Security Layers

Networking security should be understood as a layered model:

```text
┌────────────────────────────────────┐
│ Application Authentication         │
├────────────────────────────────────┤
│ Application Authorization          │
├────────────────────────────────────┤
│ Runtime Failure / Execution Guard  │
├────────────────────────────────────┤
│ Docker Network Segmentation        │
├────────────────────────────────────┤
│ Host Firewall / UFW                │
├────────────────────────────────────┤
│ Host / VM Boundary                 │
└────────────────────────────────────┘
```

No single layer is sufficient by itself.

For example:

```text
Network Reachability
       ≠
Authorization
```

A reachable service must still enforce its own application-level security requirements.

---

# 50. Architectural Trade-offs

## 50.1 Bridge Networks

### Advantages

* simple;
* native Docker Compose support;
* service-name discovery;
* suitable for single-host deployment;
* low operational complexity.

### Limitations

* host-local;
* not a multi-node network;
* weaker abstraction than cluster networking;
* network isolation is limited compared with mature orchestration platforms.

---

## 50.2 Published Ports

### Advantages

* simple external access;
* easy local administration;
* useful for observability interfaces.

### Risks

* increases host attack surface;
* can expose administrative interfaces unnecessarily;
* requires firewall discipline.

Therefore published ports should be minimized.

---

# 51. Security-Sensitive Exposures

The following interfaces deserve particular attention when the system is deployed outside a trusted staging environment:

```text
Grafana       :3000
Prometheus    :9090
Alertmanager  :9093
MinIO API     :19000
MinIO Console :19001
```

These interfaces are operational/admin surfaces rather than normal public application endpoints.

In a production architecture they should generally be protected through an appropriate access boundary such as:

```text
VPN
Private Network
Authenticated Gateway
Network Policy
Restricted Firewall Rule
```

rather than being treated as ordinary public application endpoints.

---

# 52. Network Architecture and Deployment

The network configuration is materialized through:

```text
infra/ansible/
└── roles/
    └── deploy_runtime/
        └── templates/
            └── docker-compose.staging.yml.j2
```

Ansible deploys the generated Compose configuration to the staging host.

Therefore the networking architecture is part of the Infrastructure-as-Code lifecycle:

```text
Ansible
   │
   ▼
Compose Configuration
   │
   ▼
Docker Networks
   │
   ▼
Service Connectivity
```

Changes to networking should therefore be treated as infrastructure changes rather than ad-hoc container configuration.

---

# 53. Relationship to Infrastructure Documentation

This document defines the **architectural networking model**.

Implementation-specific infrastructure details belong in:

* [Infrastructure Overview](../infrastructure/overview.md)
* [Infrastructure as Code](../infrastructure/infrastructure-as-code.md)
* [Ansible](../infrastructure/ansible.md)
* [Docker](../infrastructure/docker.md)
* [Security Baseline](../infrastructure/security-baseline.md)

The distinction is:

```text
Architecture
└── Why the network is structured this way

Infrastructure
└── How the network is provisioned

Operations
└── How the network is monitored and recovered
```

---

# 54. Final Architecture

The current Mini-Write networking architecture can be summarized as:

```text
                         EXTERNAL
                            │
                            ▼
                    ┌──────────────┐
                    │ Host / UFW   │
                    └──────┬───────┘
                           :80
                            │
                            ▼
                    ┌──────────────┐
                    │    Gateway   │
                    │    Nginx     │
                    └──────┬───────┘
                           │
                  ┌────────▼─────────┐
                  │ frontend-network │
                  └────────┬─────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │     API      │
                    └──────┬───────┘
                           │
                  ┌────────▼─────────┐
                  │ backend-network  │
                  └────────┬─────────┘
                           │
          ┌────────────────┼──────────────────┐
          │                │                  │
          ▼                ▼                  ▼
     PostgreSQL          Redis              MinIO
          ▲                ▲                  ▲
          │                │                  │
          │                │                  │
          └────────────┬───┴───────┬──────────┘
                       │           │
                       ▼           ▼
                    Worker      Observability
                       │           │
                       │      ┌────┼────────────┐
                       │      │    │            │
                       │      ▼    ▼            ▼
                       │ Prometheus Loki     Alertmanager
                       │      │    │            │
                       │      └────┴─────┬──────┘
                       │                ▼
                       │             Grafana
                       │
                       └── backend-network
```

The core architectural principles are:

1. **Gateway is the primary external ingress boundary.**
2. **API is the dual-network application boundary.**
3. **Worker is an internal asynchronous processing service.**
4. **PostgreSQL, Redis, and MinIO are backend infrastructure services.**
5. **API-to-Worker communication is queue-mediated through Redis/BullMQ.**
6. **Backend services are not unnecessarily exposed through host ports.**
7. **Observability services consume application and infrastructure telemetry through the backend network.**
8. **Docker service discovery uses service names rather than fixed container IPs.**
9. **Host firewall and Docker network segmentation provide different security controls.**
10. **The current network is single-host and bridge-based, while its logical boundaries are designed to survive future migration to multi-node networking.**

The networking architecture therefore provides the communication foundation for the higher-level service, reliability, observability, and operational architectures without coupling those concerns directly to container IP addresses or a particular future orchestration platform.

```
```
