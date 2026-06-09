# 🚀 CI/CD Pipeline Architecture — Mini-Write

---

## 🧠 1. Overview

Mini-Write implements a production-oriented CI/CD pipeline designed to simulate real-world DevOps delivery workflows.

The pipeline is built around a core engineering principle:

> Every code change must pass through automated quality, security, build, and deployment validation before reaching the runtime environment.

The goal of this pipeline is not merely automation.

It is to establish:

- Delivery consistency
- Deployment safety
- Operational reproducibility
- Failure visibility
- Controlled runtime promotion

---

## 🎯 2. CI/CD Philosophy

The pipeline is designed with the following principles:
| Principle | Purpose |
|---|---|
| Shift-left validation | Detect issues early |
| Immutable delivery | Prevent deployment drift |
| Fail-fast strategy | Stop unsafe deployments immediately |
| Environment reproducibility | Ensure predictable runtime behavior |
| Deployment safety | Reduce operational risk |
| Infrastructure-aware delivery | Align CI/CD with runtime architecture |

---

## 🏗️ 3. Pipeline Architecture

````
Developer Push
      ↓
GitHub Actions
      ↓
Quality Validation
      ↓
Security Validation
      ↓
Container Build
      ↓
GHCR Image Registry
      ↓
Deployment Runtime
      ↓
Health Validation
      ↓
Deployment Success / Rollback
````

---

## ⚙️ 4. Pipeline Workflow Design

The CI/CD pipeline is implemented using GitHub Actions and consists of four primary stages:

| Stage    | Responsibility                       |
| -------- | ------------------------------------ |
| Quality  | Validate code quality & testing      |
| Security | Validate dependency safety           |
| Build    | Create immutable container artifacts |
| Deploy   | Safely release containers to runtime |

---

## 🔍 5. Trigger Strategy

The pipeline is triggered on:

```yaml
on:
  push:
    branches: [main]
  pull_request:
```

---

### 🔷 Why This Matters

#### Push to Main

Represents:

* Delivery intent
* Release candidate generation
* Runtime deployment workflow

---

#### Pull Request Validation

Represents:

* Pre-merge verification
* Team-oriented engineering workflow
* Early defect detection

---

## 🧪 6. Quality Stage

---

### 🎯 Objective

Prevent low-quality code from progressing through the delivery pipeline.

---

### 🔷 Pipeline Actions

Each service is validated independently:

```yaml
strategy:
  matrix:
    service: [api, worker]
```

---

### 🔷 Why Matrix Strategy?

This enables:

* Parallel validation
* Service isolation
* Faster execution
* Independent failure visibility

---

### 🔷 Quality Checks

#### 1. Dependency Installation

```bash
npm ci
```

#### Why `npm ci` instead of `npm install`?

| npm ci          | npm install             |
| --------------- | ----------------------- |
| Deterministic   | Potential drift         |
| Lockfile strict | Can modify dependencies |
| CI optimized    | Dev-oriented            |

---

#### 2. Lint Validation

```bash
npm run lint
```

Purpose:

* Enforce code consistency
* Prevent unsafe patterns
* Improve maintainability

---

#### 3. Automated Testing

```bash
npm test -- --coverage
```

The pipeline validates:

* Functional correctness
* Middleware behavior
* Worker processing logic
* Failure scenarios

---

### 🔷 Coverage Gate

Coverage is enforced automatically:

```javascript
if(pct < 70) process.exit(1)
```

---

### 🔥 Engineering Benefit

This transforms testing into:

> A mandatory delivery contract rather than optional validation.

---

## 🔐 7. Security Stage

---

### 🎯 Objective

Prevent vulnerable dependencies from reaching runtime environments.

---

### 🔷 Security Validation

```bash
npm audit --audit-level=high
```

---

### 🔷 Security Philosophy

The pipeline blocks deployments when:

* High-severity vulnerabilities exist
* Dependency risk becomes unacceptable

---

### 🔥 Why This Matters

This simulates real-world DevSecOps workflows where:

* Supply-chain security
* Dependency governance
* Continuous vulnerability scanning

are mandatory operational requirements.

---

## 📦 8. Build Stage

---

### 🎯 Objective

Generate immutable deployable artifacts.

---

### 🔷 Build System

Docker Buildx is used for container builds:

```yaml
docker/setup-buildx-action
```

---

### 🔷 Benefits

| Feature                | Benefit            |
| ---------------------- | ------------------ |
| Layer caching          | Faster builds      |
| Multi-platform support | Future scalability |
| Modern build engine    | Better performance |

---

## 🏷️ 9. Immutable Image Tagging

Containers are tagged using:

```yaml
${{ github.sha }}
```

---

### 🔷 Why SHA-based Tagging?

Using commit SHA guarantees:

* Immutable deployments
* Precise rollback targets
* Full deployment traceability

---

### 🔥 Engineering Benefit

This eliminates:

* "latest tag drift"
* Unclear deployment states
* Version ambiguity

---

## 🗂️ 10. Container Registry Strategy

Built images are pushed to:

```text
GitHub Container Registry (GHCR)
```

---

### 🔷 Why GHCR?

| Benefit                      | Reason                    |
| ---------------------------- | ------------------------- |
| Native GitHub integration    | Simplified authentication |
| Centralized artifact storage | Cleaner delivery flow     |
| Immutable artifact history   | Deployment traceability   |

---

## 🖥️ 11. Self-Hosted Runner Architecture

---

### 🎯 Design Goal

Simulate cloud-hosted deployment execution while maintaining full local infrastructure ownership.

---

### 🔷 Runner Model

The GitHub Actions runner is hosted on:

```text
Ubuntu VM (VMware)
```

---

### 🔷 Why Self-Hosted Runner?

#### Engineering Motivation

The objective was to simulate:

* Remote deployment execution
* Infrastructure ownership
* Runtime control
* Persistent deployment environments

without requiring public cloud costs.

---

### 🔷 Key Benefits

| Capability                | Benefit                      |
| ------------------------- | ---------------------------- |
| Persistent runtime        | Stateful deployment testing  |
| Docker access             | Real deployment execution    |
| Full environment control  | Operational flexibility      |
| Infrastructure simulation | Cloud-like workflows locally |

---

### 🔥 Important Architectural Note

The environment intentionally prioritizes:

> Operational thinking and delivery engineering mindset over cloud-provider dependency.

The purpose is not to imitate cloud platforms perfectly.

The purpose is to simulate:

* CI/CD operational behavior
* Deployment workflows
* Runtime management
* Infrastructure responsibility

under realistic engineering constraints.

---

## 🚀 12. Deployment Stage

---

### 🎯 Objective

Deploy validated artifacts safely into the staging runtime environment.

---

### 🔷 Deployment Flow

```text
GHCR Images
    ↓
deploy.sh
    ↓
Docker Compose Runtime
    ↓
Health Validation
    ↓
Success / Rollback
```

---

## ⚙️ 13. Deployment Modes

The pipeline supports two deployment strategies:

| Mode  | Purpose                     |
| ----- | --------------------------- |
| local | Local self-hosted execution |
| ssh   | Remote VM deployment        |

---

### 🔷 Local Deployment

```yaml
DEPLOY_MODE: local
```

Deployment executes directly on the runner host.

---

### 🔷 SSH Deployment

Uses:

* SCP for environment transfer
* SSH for remote execution

---

### 🔥 Why This Matters

This abstraction allows the deployment system to evolve from:

```text
Single-host runtime
```

to:

```text
Remote infrastructure deployment
```

without redesigning the CI/CD architecture.

---

## 🔐 14. Secret Management

Secrets are managed through:

```text
GitHub Actions Secrets
```

---

### 🔷 Protected Values

Examples:

* Database credentials
* Redis password
* JWT secret
* MinIO credentials

---

### 🔷 Security Benefit

This prevents:

* Hardcoded secrets
* Repository exposure
* Credential leakage

---

## 🧪 15. Runtime Health Validation

After deployment, the system validates:

```text
/health/ready
```

---

### 🔷 Validation Logic

Deployment is considered successful only if:

```text
HTTP 200
```

is returned within the retry window.

---

### 🔥 Engineering Benefit

This transforms deployment into:

> Verified runtime activation rather than blind container startup.

---

## 🔁 16. Rollback Strategy

---

### 🎯 Objective

Recover safely from failed deployments.

---

### 🔷 State Tracking

Deployment versions are stored in:

```text
deployment_state.json
```

---

### 🔷 Rollback Flow

```text
Deployment Failure
      ↓
Previous Image Retrieval
      ↓
docker compose up
      ↓
Runtime Recovery
```

---

### 🔥 Why This Matters

The system supports:

* Stateful deployment recovery
* Immutable rollback targets
* Failure containment

---

## 🛡️ 17. Deployment Safety Mechanisms

---

### 🔷 Deployment Lock

```bash
/var/lock/deploy.lock
```

Purpose:

* Prevent concurrent deployments
* Avoid deployment corruption
* Ensure serialized runtime changes

---

### 🔷 Environment Validation

The deployment script validates required environment variables before deployment execution.

---

### 🔥 Engineering Benefit

This prevents:

* Broken runtime states
* Partial deployments
* Misconfigured environments

---

## 📊 18. Operational Characteristics

| Capability                         | Status |
| ---------------------------------- | ------ |
| Automated Quality Gates            | ✅      |
| Automated Security Validation      | ✅      |
| Immutable Builds                   | ✅      |
| Self-Hosted Deployment             | ✅      |
| Health-Based Deployment Validation | ✅      |
| Rollback Support                   | ✅      |
| Runtime Isolation                  | ✅      |
| Deployment Locking                 | ✅      |

---

## ⚖️ 19. Trade-offs & Limitations

| Decision                  | Benefit            | Trade-off                  |
| ------------------------- | ------------------ | -------------------------- |
| Self-hosted runner        | Full control       | Manual maintenance         |
| Docker Compose deployment | Simplicity         | Limited orchestration      |
| Local VM infrastructure   | Cost efficiency    | Not true distributed cloud |
| SHA-based images          | Immutable releases | Registry growth over time  |

---

## 🔮 20. Future Evolution

The current CI/CD architecture is intentionally designed to evolve toward:

* Kubernetes deployment
* GitOps workflows
* Progressive delivery
* Canary deployments
* Observability integration
* DevSecOps policy enforcement
* Infrastructure-as-Code pipelines

---

## 🧠 21. Engineering Summary

This pipeline demonstrates:

* Production-oriented delivery engineering
* Infrastructure-aware CI/CD design
* Safe deployment practices
* Immutable artifact strategy
* Operational reliability thinking

---

> 🔥 The goal was not merely to automate deployment,
> but to simulate how modern production delivery systems are engineered in real-world DevOps environments.
