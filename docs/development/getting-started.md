# Getting Started

## 1. Purpose

This document is the entry point for developers who want to understand, prepare, and work with the Mini-Write repository.

It describes the minimum knowledge and environment required to begin development without requiring the developer to first understand the complete infrastructure, reliability, or observability architecture.

The intended path is:

```text
Repository
    │
    ▼
Development Environment
    │
    ▼
Dependencies
    │
    ▼
Application Services
    │
    ▼
Testing
    │
    ▼
Development Workflow
````

This document intentionally focuses on **developer onboarding**.

Detailed architecture and operational behavior are documented separately.

---

# 2. What Is Mini-Write?

Mini-Write is a production-oriented distributed application and DevOps engineering project.

Although the application itself is relatively small, the repository is intentionally structured to model concerns that exist in production systems:

* containerized services;
* Infrastructure as Code;
* CI/CD;
* service health;
* observability;
* reliability engineering;
* runtime reliability;
* failure handling;
* deployment state;
* operational validation.

The current application architecture contains the following primary services:

```text
                    Mini-Write
                        │
            ┌───────────┴───────────┐
            │                       │
            ▼                       ▼
          API                    Worker
            │                       │
            └───────────┬───────────┘
                        │
              ┌─────────┼─────────┐
              │         │         │
              ▼         ▼         ▼
          PostgreSQL  Redis     MinIO
```

The system is complemented by an observability platform:

```text
Prometheus
Loki
Grafana
Alertmanager
Node Exporter
cAdvisor
Redis Exporter
PostgreSQL Exporter
Promtail
```

---

# 3. Development Philosophy

Development should not be treated as simply modifying application code and checking whether the process starts.

The project is designed around the following engineering loop:

```text
Understand
   │
   ▼
Change
   │
   ▼
Test
   │
   ▼
Observe
   │
   ▼
Validate
   │
   ▼
Document
```

A change is considered complete only when its effect on the surrounding system is understood.

This is particularly important because application behavior is connected to:

```text
Application Code
      │
      ├── Runtime
      ├── Database
      ├── Redis
      ├── Object Storage
      ├── Observability
      └── Deployment
```

---

# 4. Repository Structure

The repository is organized around both implementation and engineering concerns.

The major areas are:

```text
mini-write/
│
├── api/
│   └── API service
│
├── worker/
│   └── Background worker
│
├── infra/
│   └── Infrastructure as Code
│
├── observability/
│   └── Observability platform
│
├── .github/
│   └── CI/CD workflows
│
├── docs/
│   └── Engineering documentation
│
├── docker-compose.yml
│   └── Runtime composition
│
└── project-level files
```

The exact repository tree may evolve as the project progresses.

The documentation hierarchy is intentionally separated from implementation code so that developers can understand the system without reading the entire repository first.

---

# 5. Prerequisites

Before starting development, the developer should have a working development environment capable of running the application dependencies.

The core requirements are:

```text
Git
Node.js
npm
Docker
Docker Compose
```

The exact supported versions should be taken from the repository's current dependency and runtime definitions rather than assumed from this document.

Where a version is explicitly pinned by the project, that project definition is authoritative.

---

# 6. Verify the Development Environment

Before working on the project, verify that the required tools are available.

### Git

```bash
git --version
```

### Node.js

```bash
node --version
```

### npm

```bash
npm --version
```

### Docker

```bash
docker --version
```

### Docker Compose

```bash
docker compose version
```

The purpose of this verification is to detect environment problems before they are confused with application problems.

---

# 7. Clone the Repository

Clone the repository into the local development environment:

```bash
git clone <repository-url>
```

Then enter the repository:

```bash
cd mini-write
```

Verify the working tree:

```bash
git status
```

A clean initial checkout should not contain unexpected local modifications.

---

# 8. Repository Orientation

Before changing code, identify the major runtime components.

Start with:

```text
api/
worker/
infra/
observability/
docs/
```

The recommended reading order is:

```text
1. README.md
       │
       ▼
2. docs/architecture/
       │
       ▼
3. docs/development/
       │
       ▼
4. Relevant service implementation
       │
       ▼
5. Relevant infrastructure configuration
```

A developer should not need to read every document before making a small application change.

The goal is to understand only the architectural context relevant to the current change.

---

# 9. Development Environment vs Staging Environment

Mini-Write distinguishes between development and staging concerns.

Conceptually:

```text
Development
    │
    ├── Fast feedback
    ├── Local iteration
    ├── Tests
    └── Debugging

Staging
    │
    ├── Provisioned host
    ├── Ansible
    ├── GitHub Actions Runner
    ├── Production-like runtime
    └── Operational validation
```

The staging infrastructure should not be treated as the developer's normal interactive development environment.

A developer should be able to reason about and test application behavior locally without modifying the staging host for every code change.

---

# 10. Dependency Installation

The API and Worker are Node.js services and maintain their own Node.js dependency definitions.

Before running either service directly, install its declared dependencies from its respective service directory.

For example:

```bash
cd api
npm install
```

and:

```bash
cd worker
npm install
```

Use the repository's existing lockfile and dependency-management conventions when available.

For reproducible installation in CI or other controlled environments, prefer the repository's lockfile-aware installation mechanism.

---

# 11. Dependency Ownership

Dependencies should be installed according to service ownership.

The conceptual model is:

```text
api/
 ├── package.json
 └── node_modules/

worker/
 ├── package.json
 └── node_modules/
```

The API and Worker are separate runtime components.

A dependency required by the API should not automatically be added to the Worker unless the Worker actually requires it.

This preserves service boundaries and prevents unnecessary coupling.

---

# 12. Application Configuration

The application depends on environment-specific configuration.

Configuration should be treated as an explicit runtime dependency rather than embedded directly in source code.

Conceptually:

```text
Source Code
     │
     +
Environment Configuration
     │
     ▼
Application Runtime
```

Examples of configuration concerns include:

```text
Database connection
Redis connection
Object storage configuration
JWT configuration
HTTP port
Application environment
Runtime policies
```

The exact variables and their authoritative definitions should be taken from:

```text
docs/reference/environment-variables.md
```

once the configuration reference is established.

---

# 13. Secrets

Secrets must not be committed to Git.

Examples include:

```text
Database passwords
JWT secrets
Object-storage credentials
Grafana credentials
GitHub authentication tokens
```

Development secrets should be provided through the intended local configuration mechanism.

The repository's infrastructure automation uses Ansible Vault for protected staging configuration.

The staging secret mechanism should not be copied into source-controlled application configuration.

---

# 14. Starting Supporting Services

The application depends on infrastructure services such as:

```text
PostgreSQL
Redis
MinIO
```

These services provide:

```text
PostgreSQL
    → persistent relational state

Redis
    → queue / cache infrastructure

MinIO
    → object storage
```

The runtime composition is defined through Docker Compose.

Before starting the API or Worker, ensure that their required dependencies are available.

---

# 15. Docker Compose

The repository contains Docker Compose configuration for running the application stack.

The Compose model establishes:

```text
Networks
Volumes
Services
Health Checks
Resource Limits
Restart Policies
```

The resulting runtime can be conceptualized as:

```text
                  Docker Compose
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
       API           Worker       Infrastructure
        │              │              │
        │              └──────┬───────┤
        │                     │       │
        ▼                     ▼       ▼
     PostgreSQL             Redis    MinIO
```

The exact Compose file used for local development should be determined from the repository's current Compose configuration.

---

# 16. Starting the Local Stack

From the repository root, the normal Compose entry point is:

```bash
docker compose up
```

For background execution:

```bash
docker compose up -d
```

The second form is useful when the developer wants to interact with the services independently.

After starting the stack, inspect service state:

```bash
docker compose ps
```

The goal is not merely to see containers in a `running` state.

Health checks and service logs should also be considered.

---

# 17. Stopping the Local Stack

To stop the Compose services without intentionally removing persistent volumes:

```bash
docker compose down
```

This is materially different from:

```bash
docker compose down -v
```

The latter can remove associated named volumes and therefore potentially destroy local persistent state.

Use volume removal only when intentionally resetting the local environment.

---

# 18. Local Persistent State

The development stack may create persistent Docker volumes for services such as:

```text
PostgreSQL
Redis
MinIO
```

This means that restarting containers does not necessarily reset application state.

For example:

```text
Container restart
      │
      ▼
Existing volume
      │
      ▼
Existing database state
```

This is useful for development but can sometimes cause confusing test results when a developer expects a completely clean environment.

---

# 19. Clean Development Environment

When a completely clean local environment is required, the developer should understand what state will be removed before performing destructive cleanup.

The distinction is:

```text
Restart containers
      │
      ▼
Preserve state

Remove containers
      │
      ▼
Usually preserve named volumes

Remove volumes
      │
      ▼
Destroy persistent local state
```

A clean reset should therefore be an intentional operation rather than the default troubleshooting action.

---

# 20. API Development

The API is the HTTP-facing application service.

Its responsibilities include:

```text
HTTP API
Authentication
User operations
ID upload
Health endpoints
Metrics endpoint
Runtime integration
Infrastructure interaction
```

The API runtime architecture introduces a reliability layer around infrastructure operations.

Conceptually:

```text
HTTP Request
     │
     ▼
Runtime Bootstrap
     │
     ▼
Runtime Guard
     │
     ▼
Operation Resolution
     │
     ▼
Reliability Policy
     │
     ▼
Infrastructure Boundary
     │
     ▼
PostgreSQL / Redis / MinIO
```

Developers modifying API behavior should preserve these architectural boundaries.

---

# 21. Worker Development

The Worker is responsible for asynchronous background processing.

Its runtime is separate from the HTTP API runtime, while following the same reliability principles adapted to Worker execution semantics.

Conceptually:

```text
API
 │
 ▼
Redis Queue
 │
 ▼
Worker
 │
 ▼
Background Processing
```

Worker changes should therefore consider:

```text
Queue semantics
Job lifecycle
Retry behavior
Failure handling
Idempotency
Processing latency
Resource consumption
```

The Worker should not be treated as merely another HTTP service.

---

# 22. Application Dependencies

The application depends on external runtime services.

The main dependency relationships are:

```text
API
 ├── PostgreSQL
 ├── Redis
 └── MinIO

Worker
 ├── PostgreSQL
 ├── Redis
 └── MinIO
```

Not every operation necessarily uses every dependency.

For example:

```text
User Login
    └── PostgreSQL

ID Upload
    ├── MinIO
    ├── PostgreSQL
    └── Redis
```

The runtime reliability layer explicitly models infrastructure dependencies so that failures can be classified and handled according to the operation policy.

---

# 23. Health Endpoints

The API exposes health probes:

```text
/health/live
/health/ready
```

They serve different purposes.

### Liveness

Liveness answers:

> Is the application process alive?

### Readiness

Readiness answers:

> Is the application capable of serving requests given its required dependencies?

This distinction is important when diagnosing container or orchestration behavior.

---

# 24. Metrics Endpoint

The API exposes:

```text
/metrics
```

The endpoint provides Prometheus-compatible metrics.

These metrics include:

```text
HTTP traffic
HTTP latency
HTTP errors
Business metrics
Runtime reliability metrics
Process metrics
```

The metrics endpoint should therefore be preserved when modifying API routing or middleware.

---

# 25. Observability During Development

Development should use observability as part of debugging rather than treating it as a staging-only concern.

The primary signals are:

```text
Logs
Metrics
Health
```

Conceptually:

```text
Application Change
      │
      ├────────► Logs
      │
      ├────────► Metrics
      │
      └────────► Health
                    │
                    ▼
              Behavioral Evidence
```

This is particularly important for reliability-related changes where an operation may appear successful while its retry, timeout, or failure behavior is incorrect.

---

# 26. Application Logs

Application services produce structured JSON logs.

The general structure includes fields such as:

```text
timestamp
level
service
environment
event
request_id
operation_id
user_id
error information
```

The purpose of structured logging is to make operational events machine-readable and correlated.

Developers should prefer structured fields over embedding important diagnostic information only inside free-form messages.

---

# 27. Request Correlation

The API runtime generates request and execution identities.

The runtime distinguishes between:

```text
requestId
executionId
```

These identifiers are part of the runtime observability model.

A request may therefore be represented conceptually as:

```text
HTTP Request
     │
     ▼
Request ID
     │
     ▼
Execution ID
     │
     ├── Operation
     ├── Dependency
     ├── Retry
     └── Failure
```

Developers adding logs to runtime-aware API paths should preserve the existing context propagation model.

---

# 28. Runtime Reliability During Development

The API runtime provides mechanisms for:

```text
Timeout
Retry
Backoff
Failure Classification
Recovery Tracking
Reliability Metrics
```

However, these capabilities are policy-driven.

For example:

```text
Operation
    │
    ▼
Reliability Policy
    │
    ├── timeout
    ├── retry
    ├── maxRetries
    └── recoverable
```

A developer should not add ad-hoc retry or timeout logic inside a controller when the behavior belongs to the Runtime Reliability layer.

---

# 29. Development Workflow

A typical development cycle is:

```text
1. Create / select branch
        │
        ▼
2. Understand relevant architecture
        │
        ▼
3. Modify implementation
        │
        ▼
4. Run focused tests
        │
        ▼
5. Run broader tests
        │
        ▼
6. Validate runtime behavior
        │
        ▼
7. Inspect logs / metrics where relevant
        │
        ▼
8. Review changes
        │
        ▼
9. Commit
```

The depth of validation should match the risk of the change.

---

# 30. Small Changes

For a localized change, the preferred workflow is:

```text
Change
 │
 ▼
Focused test
 │
 ▼
Related tests
 │
 ▼
Review diff
```

For example, a change isolated to a controller should initially be validated against the relevant controller behavior before running the complete project validation suite.

---

# 31. Cross-Cutting Changes

Changes affecting shared infrastructure should receive broader validation.

Examples include:

```text
Runtime middleware
Reliability policy
Observability
Docker Compose
Environment configuration
Database integration
Queue behavior
```

The workflow should become:

```text
Change
 │
 ├── Unit / focused tests
 │
 ├── Integration tests
 │
 ├── Runtime validation
 │
 ├── Observability validation
 │
 └── Full regression validation
```

This prevents local correctness from being mistaken for system correctness.

---

# 32. Testing

Tests are part of the development workflow rather than an afterthought.

Before executing a test command, inspect the relevant service's `package.json` to determine the project's currently defined scripts.

For example:

```bash
cat api/package.json
cat worker/package.json
```

Then execute the repository-defined test command rather than assuming a specific test runner or script name.

This keeps the documentation aligned with the actual project configuration.

---

# 33. Focused Testing

When modifying one capability, begin with the smallest relevant test scope.

Examples:

```text
Authentication change
    │
    ▼
Authentication tests

Upload change
    │
    ▼
Upload / storage / queue tests

Runtime change
    │
    ▼
Runtime tests

Worker change
    │
    ▼
Worker / queue tests
```

Focused testing provides faster feedback during development.

---

# 34. Full Validation

After focused tests pass, broader validation should be performed for changes that may affect shared behavior.

The purpose is to detect regressions across service boundaries.

A conceptual validation sequence is:

```text
Focused Tests
     │
     ▼
Service Tests
     │
     ▼
Integration Tests
     │
     ▼
Full Test Suite
     │
     ▼
Runtime Validation
```

The exact commands remain owned by the repository's actual test configuration.

---

# 35. Git Workflow

Before beginning work:

```bash
git status
```

Review the current branch:

```bash
git branch --show-current
```

After making changes:

```bash
git status
```

Review the diff:

```bash
git diff
```

The purpose is to ensure that only intended changes are included.

---

# 36. Commit Discipline

Commits should represent coherent engineering changes.

A good commit should generally answer:

```text
What changed?
Why did it change?
What architectural capability does it affect?
```

Avoid combining unrelated modifications such as:

```text
API feature
+
Ansible refactor
+
Grafana dashboard change
```

in one commit unless they are genuinely part of the same change.

---

# 37. Documentation During Development

Code changes should trigger documentation review when they change externally meaningful behavior.

Examples:

```text
New environment variable
        │
        ▼
Update configuration reference

New health endpoint
        │
        ▼
Update health documentation

Runtime policy change
        │
        ▼
Update runtime reference

Infrastructure behavior change
        │
        ▼
Update infrastructure documentation
```

Documentation is part of the engineering lifecycle.

---

# 38. Common First-Day Problems

## Docker Is Not Running

Check:

```bash
systemctl is-active docker
```

If the local environment uses Docker Desktop, verify that Docker Desktop itself is running.

---

## Containers Start but Application Is Unavailable

Do not immediately restart everything.

Inspect:

```bash
docker compose ps
```

Then inspect logs for the affected service:

```bash
docker compose logs <service>
```

Check dependency health as well.

---

## API Cannot Connect to PostgreSQL

Investigate in this order:

```text
PostgreSQL container
      │
      ▼
PostgreSQL health
      │
      ▼
Network connectivity
      │
      ▼
Connection configuration
      │
      ▼
Application logs
```

---

## Worker Is Not Processing Jobs

Investigate:

```text
Worker container
      │
      ▼
Worker health / logs
      │
      ▼
Redis availability
      │
      ▼
Queue state
      │
      ▼
Worker runtime
      │
      ▼
Job processing failure
```

---

## Local State Appears Unexpected

Remember that persistent Docker volumes may preserve:

```text
Database state
Redis state
Object storage state
```

A restart does not necessarily reset them.

---

# 39. What Developers Should Not Do

The following practices should be avoided:

### Do not commit secrets

```text
.env
Passwords
Tokens
Private keys
Production credentials
```

should not be committed.

### Do not bypass runtime architecture

Do not introduce local reliability mechanisms that duplicate the Runtime layer without understanding the existing policy model.

### Do not modify staging infrastructure manually for normal development

Use the local development environment for normal iteration.

### Do not remove persistent volumes as a generic troubleshooting step

Understand the data impact first.

### Do not ignore observability

If a change affects reliability or operational behavior, validate the corresponding logs and metrics.

### Do not assume container state equals service health

Always distinguish:

```text
running
```

from:

```text
healthy
```

---

# 40. Development Safety Boundaries

Development environments may resemble staging, but they are not interchangeable.

The following boundary should be maintained:

```text
Developer
   │
   ▼
Local Environment
   │
   ├── Code
   ├── Tests
   ├── Local Containers
   └── Local State
```

versus:

```text
Staging
   │
   ├── Provisioned Host
   ├── Ansible
   ├── Self-hosted Runner
   ├── Deployment State
   └── Operational Monitoring
```

Changes should move toward staging through the project's CI/CD and deployment process rather than through undocumented manual intervention.

---

# 41. When to Read Additional Documentation

The following documentation should be consulted according to the task.

### Understanding the system

```text
docs/architecture/overview.md
docs/architecture/system-architecture.md
docs/architecture/service-architecture.md
```

### Working with infrastructure

```text
docs/infrastructure/overview.md
docs/infrastructure/infrastructure-as-code.md
docs/infrastructure/ansible.md
docs/infrastructure/docker.md
```

### Working with runtime reliability

```text
docs/architecture/runtime-architecture.md
docs/reliability/runtime-reliability.md
```

### Working with observability

```text
docs/observability/observability.md
docs/observability/metrics.md
docs/observability/logging.md
```

### Troubleshooting

```text
docs/troubleshooting/common-issues.md
docs/troubleshooting/infrastructure-issues.md
docs/troubleshooting/runtime-issues.md
```

---

# 42. Recommended Onboarding Path

A new developer should not attempt to understand the entire repository simultaneously.

The recommended progression is:

```text
Step 1
Repository structure
        │
        ▼
Step 2
Application architecture
        │
        ▼
Step 3
Run local dependencies
        │
        ▼
Step 4
Run the application
        │
        ▼
Step 5
Run tests
        │
        ▼
Step 6
Inspect logs and health
        │
        ▼
Step 7
Make a small change
        │
        ▼
Step 8
Validate the change
        │
        ▼
Step 9
Understand affected infrastructure/runtime behavior
```

The objective is progressive system understanding.

---

# 43. Definition of Done for Local Development Setup

The development environment is considered ready when:

```text
✓ Repository cloned successfully.

✓ Git working tree is understood.

✓ Required development tools are available.

✓ Node.js dependencies can be installed.

✓ Docker is available.

✓ Docker Compose is available.

✓ Required supporting services can be started.

✓ API can be started or executed through the project's defined runtime workflow.

✓ Worker can be started or executed through the project's defined runtime workflow.

✓ Application health can be verified.

✓ Tests can be executed using the repository-defined test scripts.

✓ Developer understands where logs and metrics are exposed.

✓ Developer understands the distinction between local and staging environments.
```

---

# 44. Final Development Model

The Mini-Write development environment should be understood as a controlled feedback loop:

```text
                 Developer
                     │
                     ▼
               Source Code
                     │
                     ▼
              Local Runtime
                     │
          ┌──────────┼──────────┐
          │          │          │
          ▼          ▼          ▼
       Tests       Logs       Metrics
          │          │          │
          └──────────┼──────────┘
                     ▼
                  Evidence
                     │
                     ▼
                Engineering
                 Validation
                     │
                     ▼
                  Commit
                     │
                     ▼
                   CI/CD
                     │
                     ▼
                  Staging
```

The key principle is:

> **A developer should be able to move from repository checkout to a validated local runtime through a deterministic and understandable workflow, without requiring undocumented knowledge of the staging infrastructure.**

This document establishes the entry point.

More detailed development procedures belong to:

```text
docs/development/local-development.md
docs/development/testing.md
```

while architectural and operational decisions remain documented in their respective sections.

```
```
