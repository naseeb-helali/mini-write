# 🚀 Deployment Architecture & Runtime Operations — Mini-Write

---

## 🧠 1. Overview

Mini-Write implements a production-oriented deployment architecture designed to simulate real-world service delivery and operational runtime management.

The deployment system focuses on:

- Controlled releases
- Runtime reproducibility
- Safe rollback mechanisms
- Health-aware deployments
- Infrastructure isolation
- Operational resilience

The goal is not merely to "run containers".

The goal is to model how modern systems are safely deployed, validated, and operated in production-like environments.

---

## 🎯 2. Deployment Philosophy

The deployment architecture is designed around the following principles:

| Principle | Purpose |
|---|---|
| Immutable deployment | Prevent runtime drift |
| Runtime validation | Detect broken releases early |
| Controlled deployment flow | Reduce operational risk |
| Failure recovery | Restore service quickly |
| Infrastructure reproducibility | Ensure consistent runtime behavior |
| Operational safety | Prevent deployment corruption |

---

## 🏗️ 3. Runtime Architecture

````
GitHub Actions
      ↓
Self-Hosted Runner
      ↓
deploy.sh
      ↓
Docker Compose Runtime
      ↓
Health Validation
      ↓
Deployment Success / Rollback
````

---

## 🖥️ 4. Runtime Environment Model

The deployment runtime is hosted on:

```text id="wvx9x6"
Ubuntu VM (VMware-based)
```

---

### 🔷 Design Goal

The environment is intentionally designed to simulate:

* Persistent runtime infrastructure
* Cloud-like deployment workflows
* Long-running services
* Infrastructure ownership

without requiring public cloud infrastructure costs.

---

### 🔥 Engineering Perspective

This environment is not intended to replicate cloud providers perfectly.

Instead, it simulates the operational realities of:

* Deployment automation
* Runtime management
* Infrastructure control
* Failure handling
* Service orchestration

within realistic engineering constraints.

---

## 📁 5. Deployment Runtime Structure

```text id="kh76nh"
/opt/deploy
├── deploy.sh
├── rollback.sh
├── deployment_state.json
├── docker-compose.staging.yml
├── .env.staging
├── proxy/
│   └── nginx.conf
└── logs/
    └── deploy.log
```

---

## 🧠 6. Why `/opt/deploy`?

The deployment directory acts as:

> A dedicated operational runtime boundary.

It separates:

* Runtime infrastructure
* Deployment logic
* Environment configuration
* Operational state

from:

* Application source code
* CI pipeline execution context

---

### 🔥 Important Architectural Clarification

Although the deployment assets originate from the repository itself, the runtime environment intentionally models:

* Operational separation
* Deployment ownership
* Infrastructure lifecycle management

This mirrors how deployment runtimes are managed in production systems.

---

## ⚙️ 7. Deployment Execution Flow

---

### 🔷 High-Level Deployment Sequence

```text
Pipeline Trigger
      ↓
Image Build & Push
      ↓
Environment Generation
      ↓
deploy.sh Execution
      ↓
Image Pull
      ↓
Container Startup
      ↓
Runtime Health Validation
      ↓
Success / Rollback
```

---

## 🛡️ 8. Deployment Locking Strategy

---

### 🎯 Problem

Concurrent deployments can cause:

* Runtime corruption
* Partial deployments
* Inconsistent service states

---

### ✅ Solution

Deployment locking is implemented using:

```bash id="8rkr1v"
/var/lock/deploy.lock
```

---

### 🔷 Behavior

Before deployment starts:

* The script checks for an active lock.
* If found, deployment is aborted.

---

### 🔥 Engineering Benefit

This guarantees:

* Serialized deployments
* Runtime consistency
* Safe operational state transitions

---

## 🔐 9. Environment Validation

---

### 🎯 Problem

Missing runtime variables can cause:

* Broken containers
* Partial startup
* Undefined behavior

---

### ✅ Solution

`deploy.sh` validates critical environment variables before deployment execution.

---

### 🔷 Validated Variables

Examples:

* POSTGRES_USER
* POSTGRES_PASSWORD
* REDIS_PASSWORD
* JWT_SECRET

---

### 🔥 Engineering Benefit

This prevents invalid runtime activation before infrastructure changes occur.

---

## 📦 10. Immutable Runtime Deployment

---

### 🔷 Deployment Inputs

The deployment script receives:

```bash id="v0n8m"
NEW_API
NEW_WORKER
```

Each represents:

> A specific immutable container image.

---

### 🔥 Why This Matters

Deployments become:

* Traceable
* Reproducible
* Rollback-safe

because runtime state references exact image versions.

---

## 🔁 11. Deployment State Tracking

---

### 🎯 Objective

Track runtime deployment history safely.

---

### 🔷 State File

```text id="c5dyvc"
deployment_state.json
```

Stores:

* Current deployed images
* Previous deployed images

---

### 🔷 Example Structure

```json id="jlwm3u"
{
  "current": {
    "api": "...",
    "worker": "..."
  },
  "previous": {
    "api": "...",
    "worker": "..."
  }
}
```

---

### 🔥 Engineering Benefit

This enables:

* Safe rollback targeting
* Runtime recovery
* Deployment traceability

without requiring external orchestration systems.

---

## 🚀 12. Deployment Runtime Execution

---

### 🔷 Image Pull

```bash id="6j1y1h"
docker compose pull
```

Ensures the runtime retrieves:

* Latest immutable release images
* Registry-backed deployment artifacts

---

### 🔷 Runtime Startup

```bash id="h71uv5"
docker compose up -d --remove-orphans
```

---

### 🔷 Why `--remove-orphans`?

Prevents:

* Legacy containers
* Runtime drift
* Abandoned services

---

## 🧪 13. Health-Based Deployment Validation

---

### 🎯 Objective

Ensure deployment success is based on:

> Actual runtime readiness rather than container startup alone.

---

### 🔷 Validation Endpoint

```text id="1vgh6x"
/health/ready
```

---

### 🔷 Validation Strategy

The deployment system repeatedly checks:

```text id="8tmyqj"
HTTP 200
```

within a controlled retry window.

---

### 🔷 Retry Model

| Setting | Value |
| ------- | ----- |
| Retries | 12    |
| Delay   | 5s    |

---

### 🔥 Why This Matters

Containers can appear "running" while:

* Dependencies are unavailable
* Initialization is incomplete
* Runtime state is invalid

The health validation layer prevents false-positive deployments.

---

## 🔄 14. Rollback Architecture

---

## 🎯 Objective

Recover safely from failed runtime activation.

---

### 🔷 Rollback Trigger

Rollback occurs when:

* Health validation fails
* Runtime startup becomes unstable
* Deployment consistency cannot be verified

---

### 🔷 Rollback Execution

```bash id="sp2jml"
./rollback.sh
```

---

### 🔷 Rollback Process

```text
Load Previous Images
      ↓
Export Runtime Variables
      ↓
docker compose up -d
      ↓
Restore Previous Runtime State
```

---

## 🔥 Engineering Benefit

This creates:

* Controlled failure recovery
* Fast operational restoration
* Safer deployment experimentation

---

## ⚖️ 15. Rollback Trade-offs

The rollback strategy prioritizes:

| Priority          | Result                       |
| ----------------- | ---------------------------- |
| Simplicity        | Easier operational debugging |
| Fast recovery     | Reduced downtime             |
| Stateful recovery | Safer runtime restoration    |

---

### 🔷 Accepted Limitation

Rollback currently restores:

* Container runtime state

but not:

* Database schema migrations
* Data-level rollback

---

### 🔥 Why This Is Acceptable

The current system intentionally avoids destructive schema evolution.

Future production-grade evolution may introduce:

* Migration versioning
* Backward-compatible schemas
* Transactional migration workflows

---

## 🌐 16. Runtime Network Architecture

---

### 🔷 Network Isolation Strategy

Two dedicated Docker networks are used:

| Network          | Purpose                 |
| ---------------- | ----------------------- |
| frontend-network | Public-facing services  |
| backend-network  | Internal infrastructure |

---

### 🔷 Public Exposure Model

Only:

```text id="lxnlvc"
Gateway (Nginx)
```

is externally exposed.

---

### 🔥 Security Benefit

This prevents direct external access to:

* PostgreSQL
* Redis
* Worker services

---

## 📦 17. Persistent Data Strategy

---

### 🔷 Named Volumes

Persistent runtime data is stored using Docker volumes.

Examples:

* PostgreSQL data
* Redis persistence
* MinIO object storage

---

### 🔥 Engineering Benefit

This allows:

* Container recreation
* Runtime replacement
* Service restarts

without losing operational state.

---

## ⚙️ 18. Service Runtime Governance

---

### 🔷 Resource Constraints

Services enforce:

* Memory limits
* CPU limits

Examples:

| Service | Memory | CPU |
| ------- | ------ | --- |
| gateway | 128MB  | 0.2 |
| api     | 512MB  | 0.5 |
| worker  | 1024MB | 1.0 |

---

### 🔥 Why This Matters

This simulates production orchestration behavior where:

* Services compete for resources
* Resource exhaustion must be controlled
* Runtime isolation improves stability

---

## 🧠 19. Service Isolation Model

---

### 🔷 API Service

Characteristics:

* Stateless
* Front-facing
* Lightweight
* Fast-response oriented

---

### 🔷 Worker Service

Characteristics:

* Background execution
* CPU-intensive processing
* Infrastructure-isolated

---

### 🔥 Engineering Benefit

This separation allows:

* Independent scaling
* Failure isolation
* Better resource management

---

## 🗄️ 20. Infrastructure Services

---

### 🔷 PostgreSQL

Acts as:

> Source of truth for system state.

Includes:

* Health validation
* Persistent storage
* Transactional consistency

---

### 🔷 Redis

Acts as:

> Queue coordination layer.

Configured with:

```text id="k5fcv2"
Append Only File (AOF)
```

to improve durability.

---

### 🔷 MinIO

Acts as:

> S3-compatible object storage layer.

Supports:

* Local infrastructure simulation
* Cloud portability
* Persistent object management

---

## 📜 21. Operational Logging

---

### 🔷 Deployment Logs

Deployment events are stored in:

```text id="zg8jfu"
/opt/deploy/logs/deploy.log
```

---

### 🔷 Container Logging

Docker JSON logging is configured with:

* Log rotation
* File limits
* Size constraints

---

### 🔥 Engineering Benefit

This prevents:

* Unlimited log growth
* Disk exhaustion
* Runtime instability

---

## 🔒 22. Runtime Security Characteristics

---

### 🔷 Security Controls

Implemented protections include:

* Network isolation
* Gateway-only exposure
* Environment-based secret injection
* Read-only Nginx configuration mount
* Health-aware startup ordering

---

### 🔷 Infrastructure Boundary

Internal services remain inaccessible externally unless explicitly exposed.

---

## ⚖️ 23. Trade-offs & Operational Constraints

| Decision                       | Benefit             | Trade-off                 |
| ------------------------------ | ------------------- | ------------------------- |
| Docker Compose                 | Simplicity          | Limited orchestration     |
| Single VM runtime              | Low cost            | No true distributed nodes |
| Manual deployment scripts      | Operational clarity | Less abstraction          |
| Local infrastructure ownership | Full control        | Self-managed maintenance  |

---

## 🔮 24. Future Evolution

The deployment architecture is intentionally designed to evolve toward:

* Kubernetes orchestration
* Rolling deployments
* Horizontal autoscaling
* Service discovery
* Distributed networking
* GitOps workflows
* Progressive delivery
* Automated observability

---

## 🧠 25. Engineering Summary

This deployment system demonstrates:

* Production-minded operational thinking
* Runtime safety mechanisms
* Infrastructure-aware deployment workflows
* Health-validated delivery
* Failure recovery architecture
* Controlled runtime management

---

> 🔥 The deployment architecture was designed not merely to run containers,
> but to simulate how modern production systems are safely operated, validated, and recovered in real-world DevOps environments.