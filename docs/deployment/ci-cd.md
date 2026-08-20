# CI/CD

## 1. Purpose

This document describes the Continuous Integration and Continuous Deployment (CI/CD) architecture used by Mini-Write.

The objective of the CI/CD system is not merely to automate commands. It provides a controlled path from a version-controlled change to a validated deployment on the staging infrastructure.

The deployment flow is designed around the following principles:

- **Automate repeatable operations**
- **Validate before deployment**
- **Use version-controlled deployment logic**
- **Separate build artifacts from runtime configuration**
- **Use a controlled deployment environment**
- **Preserve deployment traceability**
- **Fail safely**
- **Verify the resulting runtime state**

The high-level lifecycle is:

```text
Developer Change
      │
      ▼
Git Commit / Pull Request
      │
      ▼
CI Validation
      │
      ├── Failure ──► Stop
      │
      ▼
Build / Artifact Preparation
      │
      ▼
Deployment Execution
      │
      ▼
Staging Runtime
      │
      ▼
Health / Operational Validation
      │
      ├── Failure ──► Deployment Failure Handling
      │
      ▼
Successful Deployment
````

---

# 2. CI/CD Architecture

Mini-Write uses GitHub Actions as the CI/CD orchestration layer.

The repository contains the workflow definition under:

```text
.github/workflows/
```

The workflow is responsible for orchestrating the deployment lifecycle.

The deployment target is a controlled staging host running the Mini-Write runtime.

The architectural relationship is:

```text
┌──────────────────────┐
│ GitHub Repository    │
│                      │
│ Source               │
│ Tests                │
│ Dockerfiles          │
│ Ansible              │
│ Deployment Scripts   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ GitHub Actions       │
│                      │
│ CI/CD Orchestration  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Self-hosted Runner   │
│                      │
│ Mini-Write Staging   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Deployment Runtime   │
│                      │
│ Docker Compose       │
│ API                  │
│ Worker               │
│ Infrastructure       │
│ Observability        │
└──────────────────────┘
```

The runner is therefore part of the deployment architecture rather than merely an arbitrary execution machine.

---

# 3. Continuous Integration vs Continuous Deployment

The pipeline contains two conceptually different responsibilities.

## Continuous Integration

CI answers:

> **Is this change technically valid and safe enough to proceed?**

Typical validation concerns include:

```text
Source integrity
        │
        ▼
Dependency installation
        │
        ▼
Tests
        │
        ▼
Build validation
        │
        ▼
Artifact validation
```

CI should fail before deployment when the change does not satisfy the project's validation requirements.

---

## Continuous Deployment

CD answers:

> **Can the validated change be introduced into the staging runtime and verified successfully?**

The deployment lifecycle is approximately:

```text
Validated Change
      │
      ▼
Artifact Selection / Build
      │
      ▼
Deployment Preparation
      │
      ▼
Runtime Update
      │
      ▼
Health Verification
      │
      ▼
Operational Verification
```

The distinction is important because a successful build does not necessarily imply a successful deployment.

---

# 4. Source of Truth

The CI/CD system itself is version-controlled.

The workflow definition is stored in the repository rather than being manually configured only through the GitHub UI.

This creates the following relationship:

```text
Git Repository
      │
      ├── Application Source
      ├── Tests
      ├── Dockerfiles
      ├── Ansible
      ├── Deployment Scripts
      ├── Observability Configuration
      └── CI/CD Workflow
```

The repository therefore contains both:

```text
what the application is
```

and:

```text
how the application is validated and deployed
```

This is essential for reproducibility.

---

# 5. Self-hosted Runner

Mini-Write uses a GitHub Actions self-hosted runner for staging deployment.

The runner operates on the controlled Mini-Write staging host.

The runner is identified using labels that distinguish it from unrelated runners.

The architectural path is:

```text
GitHub Actions
      │
      ▼
Runner Selection
      │
      ▼
Mini-Write Staging Runner
      │
      ▼
Local Docker / Deployment Environment
```

This model provides the workflow with direct access to the deployment environment without introducing an external cloud deployment platform.

---

# 6. Why a Self-hosted Runner Is Used

The self-hosted runner provides several characteristics relevant to the project's architecture:

### Environment proximity

Deployment commands execute within the environment that hosts the staging runtime.

### Reproducibility

The runner environment itself is provisioned through Infrastructure as Code.

### Operational realism

The project simulates a production-oriented deployment workflow without depending on a cloud provider.

### Controlled access

The deployment execution environment is explicitly associated with the staging infrastructure.

However, the self-hosted runner also introduces a security boundary that must be treated carefully.

A compromised workflow can potentially execute commands on the runner host.

Therefore:

```text
Repository Trust
      │
      ▼
Workflow Execution
      │
      ▼
Runner Privileges
      │
      ▼
Infrastructure Impact
```

must be considered part of the security model.

---

# 7. Runner Provisioning

The runner is not treated as an undocumented manually configured machine.

Its installation and registration are automated through Ansible.

The relevant infrastructure role is:

```text
infra/ansible/roles/github_runner/
```

The role is responsible for concerns including:

```text
Runner dependencies
Runner installation directory
Runner download
Runner registration
Runner labels
Runner service
Runner service startup
Docker access validation
Deployment runtime validation
```

This creates:

```text
Ansible
   │
   ▼
Runner Installation
   │
   ▼
Runner Service
   │
   ▼
GitHub Actions
```

The CI/CD system therefore depends on infrastructure provisioning rather than undocumented host state.

---

# 8. Runner Identity and Selection

The runner is associated with the Mini-Write staging environment through its labels.

The workflow should target the intended runner using those labels rather than assuming that any available self-hosted runner is suitable.

Conceptually:

```text
Workflow Job
     │
     ▼
Required Runner Labels
     │
     ▼
Mini-Write Staging Runner
```

This prevents a deployment job from accidentally executing against an incompatible machine.

---

# 9. Deployment Environment Boundary

The staging host is both:

```text
CI execution environment
```

and:

```text
deployment target
```

This is a deliberate architectural simplification for the project's local production-oriented simulation.

It should not be interpreted as a universal recommendation for larger production systems.

In a larger environment, CI execution and production deployment targets are commonly separated.

For Mini-Write, the model remains intentionally constrained:

```text
GitHub
   │
   ▼
Self-hosted Runner
   │
   ├── Docker
   ├── Compose
   ├── Deployment Scripts
   └── Staging Runtime
```

---

# 10. CI Validation Boundary

CI should provide an early validation boundary before modifying the running staging environment.

The principle is:

```text
Invalid Change
     │
     ▼
CI
     │
     X
 Deployment
```

rather than:

```text
Invalid Change
     │
     ▼
Deployment
     │
     ▼
Broken Runtime
```

The exact validation commands are defined by the workflow and project tooling.

The documentation intentionally does not duplicate individual shell commands here because the workflow file is the executable source of truth.

---

# 11. Test Execution

Automated tests belong to the CI validation phase.

The logical flow is:

```text
Source Change
      │
      ▼
Install Dependencies
      │
      ▼
Run Tests
      │
      ├── Failure ──► Pipeline Stops
      │
      ▼
Continue
```

Tests are therefore a deployment gate.

A deployment should not proceed merely because source code can be built.

---

# 12. Build Validation

Application artifacts must be validated before being considered deployable.

For containerized services, this includes validating the corresponding Docker build process.

The conceptual pipeline is:

```text
Application Source
      │
      ▼
Docker Build
      │
      ├── Failure ──► Stop
      │
      ▼
Container Artifact
```

The resulting image becomes the deployment artifact consumed by the runtime.

This establishes an important separation:

```text
Source Code
    ≠
Container Image
    ≠
Running Container
```

Each represents a different lifecycle state.

---

# 13. Artifact Identity

Deployment should use an identifiable application artifact.

The staging Compose configuration references:

```text
API_IMAGE
WORKER_IMAGE
```

rather than hard-coding a specific application version directly into the Compose topology.

This allows the deployment process to select the artifact independently from the runtime topology.

Conceptually:

```text
Build
  │
  ▼
Image Identity
  │
  ▼
Deployment Configuration
  │
  ▼
Compose
  │
  ▼
Running Service
```

The image identity is therefore an important part of deployment traceability.

---

# 14. Deployment Configuration Boundary

CI/CD should not recreate infrastructure configuration independently of Ansible.

The architecture separates responsibilities:

```text
Ansible
   │
   ├── Host provisioning
   ├── Docker installation
   ├── Security baseline
   ├── Runner provisioning
   └── Deployment filesystem
```

while:

```text
Deployment Scripts / Compose
   │
   ├── Application deployment
   ├── Container lifecycle
   └── Runtime update
```

and:

```text
CI/CD
   │
   ├── Orchestration
   ├── Validation
   └── Deployment triggering
```

This prevents the CI workflow from becoming a second, conflicting Infrastructure as Code system.

---

# 15. Deployment Runtime

The deployment runtime is rooted under:

```text
/opt/deploy
```

The deployment role creates a structured runtime layout containing areas such as:

```text
/opt/deploy/compose
/opt/deploy/proxy
/opt/deploy/scripts
/opt/deploy/state
/opt/deploy/logs
/opt/deploy/env
/opt/deploy/metrics
```

CI/CD interacts with this runtime through the deployment mechanisms already provisioned by Ansible.

The intended relationship is:

```text
CI/CD
  │
  ▼
Deployment Scripts
  │
  ▼
/opt/deploy
  │
  ▼
Docker Compose
  │
  ▼
Application Runtime
```

---

# 16. Deployment State

The deployment system maintains deployment state through:

```text
/opt/deploy/state/deployment_state.json
```

The initial state structure is:

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

The purpose of this state is to preserve knowledge about the currently deployed and previously deployed application artifacts.

Conceptually:

```text
Previous Version
      │
      ▼
Current Version
```

This information is useful for:

* deployment verification;
* deployment history;
* rollback decisions;
* operational troubleshooting.

Deployment state is runtime state and should not be confused with source-controlled configuration.

---

# 17. Deployment Lifecycle

A deployment should be understood as a state transition.

```text
Current Runtime
      │
      ▼
Deployment Preparation
      │
      ▼
New Artifact
      │
      ▼
Runtime Update
      │
      ▼
Health Verification
      │
   ┌──┴──┐
   │     │
Success Failure
   │     │
   ▼     ▼
New     Recovery /
State   Rollback Path
```

The deployment process must therefore preserve enough information to determine what changed.

---

# 18. Health Verification

Deployment completion is not equivalent to command completion.

For example:

```text
docker compose up
```

returning successfully does not prove that:

```text
API
Worker
PostgreSQL
Redis
MinIO
Observability
```

are all operating correctly.

The deployment verification boundary therefore extends beyond process creation.

---

# 19. Application Health Checks

The API exposes:

```text
/health/live
/health/ready
```

The distinction is:

### Liveness

Answers:

> Is the API process alive?

### Readiness

Answers:

> Is the API capable of serving requests with its required dependencies available?

The Compose configuration uses the readiness endpoint for the API health check.

This allows deployment validation to distinguish between:

```text
Process exists
```

and:

```text
Service is operationally ready
```

---

# 20. Worker Verification

The Worker also participates in runtime health verification and exposes operational metrics.

Deployment verification should therefore consider:

```text
Worker availability
Redis connectivity
Queue processing
Job activity
Worker metrics
```

A Worker container being `running` is not sufficient evidence that background processing is healthy.

The operational verification model should include both:

```text
Infrastructure State
```

and:

```text
Application Behavior
```

---

# 21. Deployment Observability

Every deployment should remain observable after execution.

The platform provides several signals:

```text
Metrics
Logs
Health Checks
Alerts
Dashboards
Deployment State
```

The relationship is:

```text
Deployment
    │
    ▼
Runtime Change
    │
    ├── Metrics
    ├── Logs
    ├── Health
    └── Alerts
```

This is important because a deployment can technically succeed while introducing a latent operational failure.

---

# 22. Deployment Failure

A failed deployment can occur at several layers:

```text
CI Failure
    │
    ├── Test failure
    ├── Build failure
    └── Validation failure

Deployment Failure
    │
    ├── Script failure
    ├── Compose failure
    ├── Container startup failure
    └── Configuration failure

Runtime Failure
    │
    ├── Health failure
    ├── Dependency failure
    ├── Application failure
    └── Resource failure
```

These should not be treated as the same failure class.

The first question during an incident should be:

> **At which deployment lifecycle boundary did the failure occur?**

---

# 23. Deployment Failure Containment

The pipeline should fail as early as possible.

The preferred sequence is:

```text
Validation Failure
      │
      ▼
Stop Pipeline
```

before:

```text
Runtime Mutation
```

Once runtime mutation has started, failures must be contained and diagnosed using the deployment and reliability mechanisms.

This creates two broad safety zones:

```text
Pre-deployment validation
```

and:

```text
Post-deployment runtime validation
```

---

# 24. Deployment and Reliability

CI/CD is not the reliability layer itself.

Instead, it is one participant in the overall reliability architecture.

The relationship is:

```text
CI/CD
  │
  ├── Prevent invalid changes
  │
  ▼
Deployment
  │
  ├── Controlled runtime transition
  │
  ▼
Reliability Runtime
  │
  ├── Runtime failure handling
  ├── Timeout
  ├── Retry
  ├── Recovery
  └── Failure classification
```

This distinction is important.

CI/CD reduces the probability of introducing invalid changes.

Runtime Reliability manages failures that occur during execution.

---

# 25. Deployment and Observability

Observability provides the evidence required to determine whether a deployment changed system behavior.

Relevant signals include:

```text
API request error rate
API latency
Worker failure rate
Worker queue depth
Worker processing latency
Host CPU
Host memory
Host disk
Container health
Infrastructure exporter availability
```

A deployment should therefore be considered operationally validated only when the resulting runtime remains within its expected behavior.

---

# 26. Deployment and Alerts

Prometheus evaluates operational rules after deployment.

Examples include alerts for:

```text
API unavailable
Worker unavailable
High API error rate
High API latency
High Worker failure rate
High queue backlog
High Worker latency
Host CPU pressure
Host memory pressure
Low disk space
```

The relationship is:

```text
Deployment
     │
     ▼
Runtime
     │
     ▼
Metrics
     │
     ▼
Prometheus Rules
     │
     ▼
Alertmanager
```

This provides a post-deployment feedback mechanism.

---

# 27. CI/CD and Infrastructure as Code

Infrastructure provisioning and application deployment are separate lifecycle concerns.

### Infrastructure lifecycle

```text
Ansible
   │
   ▼
Host
   │
   ├── Docker
   ├── Runner
   ├── Security
   └── Deployment Runtime
```

### Application lifecycle

```text
CI/CD
   │
   ▼
Application Artifact
   │
   ▼
Deployment Runtime
   │
   ▼
Containers
```

This separation allows the host to be provisioned independently from application releases.

---

# 28. Reproducibility

A successful deployment should be reproducible.

The intended chain is:

```text
Version-controlled source
        │
        ▼
Version-controlled workflow
        │
        ▼
Version-controlled infrastructure
        │
        ▼
Known artifact
        │
        ▼
Known runtime configuration
        │
        ▼
Known deployment procedure
```

The less deployment behavior depends on undocumented host state, the more reproducible the system becomes.

---

# 29. Idempotency

Deployment infrastructure should prefer idempotent operations.

Ansible is used for infrastructure provisioning because repeated execution should converge toward the intended host state.

Similarly, deployment operations should avoid assuming that:

```text
container does not exist
directory does not exist
runner is not installed
configuration does not exist
```

Instead, deployment logic should explicitly account for the existing runtime state.

This is especially important for:

* repeated deployments;
* CI retries;
* runner reconnection;
* infrastructure reprovisioning.

---

# 30. CI/CD Security Boundary

The CI/CD system has privileged access to the staging environment.

Therefore the following assets are security-sensitive:

```text
GitHub workflow
Self-hosted runner
Runner credentials
GitHub tokens
Ansible secrets
Docker access
Deployment scripts
Environment files
```

The runner's Docker access is particularly significant because membership in the Docker group can provide highly privileged control over the host.

Therefore:

```text
Workflow
    │
    ▼
Runner
    │
    ▼
Docker Access
    │
    ▼
Host Impact
```

must be treated as a privileged execution path.

---

# 31. Secret Handling in CI/CD

Secrets must remain outside ordinary source-controlled workflow configuration.

The deployment architecture separates:

```text
Non-sensitive configuration
```

from:

```text
Sensitive credentials
```

The CI/CD pipeline should avoid printing secrets to logs.

Where a deployment operation handles sensitive values, logging should be minimized and sensitive Ansible operations should use mechanisms such as:

```yaml
no_log: true
```

where appropriate.

---

# 32. Workflow Changes

A modification to the CI/CD workflow is itself an infrastructure/deployment change.

It can affect:

```text
what code is tested
what code is deployed
where deployment runs
what privileges are available
what secrets are accessible
what validation gates exist
```

Therefore workflow changes require the same engineering discipline as application changes.

A workflow modification should be reviewed for:

```text
Correctness
Security
Failure behavior
Runner targeting
Secret exposure
Idempotency
Rollback implications
```

---

# 33. Pipeline Failure Semantics

A CI/CD pipeline should make failure visible.

The preferred behavior is:

```text
Stage Failure
     │
     ▼
Non-zero result
     │
     ▼
Pipeline failure
     │
     ▼
Deployment blocked / marked failed
```

Silent continuation is dangerous when a failed step can leave the deployment in an undefined state.

Each stage should therefore have a clear answer to:

> What happens if this operation fails?

---

# 34. Deployment Verification Strategy

Verification should occur at multiple levels.

## Level 1 — Process

```text
Container running
```

## Level 2 — Health

```text
Health check passing
```

## Level 3 — Application

```text
API / Worker behaving correctly
```

## Level 4 — Dependency

```text
PostgreSQL
Redis
MinIO
```

available where required.

## Level 5 — Observability

```text
Prometheus
Loki
Grafana
Alertmanager
```

remain functional.

The complete model is:

```text
Process
   │
   ▼
Health
   │
   ▼
Application
   │
   ▼
Dependencies
   │
   ▼
Observability
```

---

# 35. Deployment Completion Criteria

A deployment should be considered successful only when the relevant conditions are satisfied:

```text
✓ CI validation passed
✓ Required artifact exists
✓ Deployment command completed
✓ Containers reached expected state
✓ Application health checks pass
✓ Worker is operational
✓ Required dependencies are healthy
✓ Metrics remain available
✓ Logs remain available
✓ No immediate critical alert indicates failure
✓ Deployment state reflects the new artifact
```

A green CI job alone is therefore insufficient.

---

# 36. Rollback Model

Rollback should be treated as a controlled deployment transition.

The conceptual model is:

```text
Current Version
      │
      ▼
New Version
      │
      ├── Healthy ──► Keep
      │
      └── Unhealthy
              │
              ▼
        Previous Version
```

The deployment state file provides the foundation for identifying the previous API and Worker artifacts.

Rollback implementation must preserve the same configuration and verification principles as normal deployment.

---

# 37. Rollback Is Not the Same as Recovery

Rollback addresses:

> **The newly deployed version is unsuitable; restore the previous version.**

Recovery addresses:

> **The running system encountered an operational failure and needs to return to a healthy state.**

Therefore:

```text
Rollback
    → deployment lifecycle mechanism
```

while:

```text
Recovery
    → runtime reliability mechanism
```

They complement one another but should not be conflated.

---

# 38. Deployment Traceability

A deployment should allow an operator to answer:

```text
What version was deployed?
When was it deployed?
Which API image was used?
Which Worker image was used?
Which configuration was active?
Did health checks pass?
Did the runtime remain healthy afterward?
```

The architecture supports this through the combination of:

```text
Git history
+
CI/CD execution
+
Image identity
+
Deployment state
+
Logs
+
Metrics
+
Health checks
```

This is the minimum useful chain for investigating deployment-related incidents.

---

# 39. Operational Feedback Loop

CI/CD does not terminate at deployment.

The complete lifecycle is:

```text
Code Change
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
Observability
    │
    ▼
Operational Feedback
    │
    ▼
Engineering Change
    │
    └──────────────► CI
```

This establishes the foundation for Continuous Improvement.

Deployment results become operational evidence that can inform future engineering changes.

---

# 40. Common CI/CD Failure Modes

## 40.1 CI Failure

Possible causes:

```text
test failure
dependency failure
build failure
validation failure
```

Expected response:

```text
Fix change
→ rerun CI
→ deploy only after validation passes
```

---

## 40.2 Runner Failure

Possible causes:

```text
runner service stopped
runner unavailable
Docker unavailable
runner registration problem
host failure
```

Investigation begins at:

```text
GitHub Actions
   │
   ▼
Runner
   │
   ▼
Host
```

---

## 40.3 Deployment Script Failure

Possible causes:

```text
invalid configuration
missing image
permission failure
Docker failure
filesystem failure
```

The deployment state should be inspected before attempting another deployment.

---

## 40.4 Container Startup Failure

Possible causes:

```text
invalid environment
dependency unavailable
application startup failure
image problem
port conflict
```

Investigation should include:

```text
docker compose state
container logs
health checks
environment configuration
dependency health
```

---

## 40.5 Post-deployment Failure

The deployment command may succeed while the application later becomes unhealthy.

This is why post-deployment validation and observability are mandatory parts of the deployment lifecycle.

---

# 41. CI/CD Troubleshooting Sequence

When a deployment fails, follow the lifecycle rather than jumping directly into application logs.

```text
1. Identify failed pipeline stage
        │
        ▼
2. Determine whether runtime was modified
        │
        ▼
3. Inspect deployment output
        │
        ▼
4. Inspect Docker Compose state
        │
        ▼
5. Inspect service logs
        │
        ▼
6. Check health endpoints
        │
        ▼
7. Check dependencies
        │
        ▼
8. Check Prometheus
        │
        ▼
9. Check Loki
        │
        ▼
10. Compare current/previous deployment state
```

This ordering reduces unnecessary investigation.

---

# 42. CI/CD Change Checklist

Before merging a CI/CD change:

```text
[ ] Workflow syntax is valid
[ ] Correct runner is targeted
[ ] Required permissions are understood
[ ] Secrets are not exposed
[ ] Validation gates remain intact
[ ] Deployment ordering remains correct
[ ] Failure behavior is understood
[ ] Existing deployment behavior is preserved
[ ] Rollback implications are understood
[ ] Post-deployment verification remains available
```

---

# 43. Deployment Change Checklist

Before deploying an application change:

```text
[ ] Source change committed
[ ] CI validation passed
[ ] Application artifact built successfully
[ ] Artifact identity is known
[ ] Required runtime configuration exists
[ ] Dependencies are available
[ ] Deployment state is understood
[ ] Deployment procedure is known
[ ] Verification criteria are defined
[ ] Rollback path is known
```

---

# 44. Post-deployment Checklist

After deployment:

```text
[ ] API container is healthy
[ ] API readiness endpoint succeeds
[ ] Worker is operational
[ ] Redis is healthy
[ ] PostgreSQL is healthy
[ ] MinIO is healthy
[ ] Prometheus is scraping application metrics
[ ] Loki is receiving logs
[ ] Grafana remains operational
[ ] No unexpected critical alert is active
[ ] Deployment state reflects the new artifacts
```

---

# 45. Architectural Boundaries

The CI/CD architecture can be summarized as five boundaries.

### Boundary 1 — Source

```text
Git Repository
```

Owns:

```text
code
tests
workflow
infrastructure definitions
configuration
```

### Boundary 2 — Validation

```text
GitHub Actions
```

Owns:

```text
CI validation
artifact preparation
deployment orchestration
```

### Boundary 3 — Execution

```text
Self-hosted Runner
```

Owns:

```text
execution of deployment operations
```

### Boundary 4 — Runtime

```text
Docker / Compose
```

Owns:

```text
service lifecycle
networking
volumes
resource limits
health checks
```

### Boundary 5 — Operations

```text
Prometheus
Loki
Grafana
Alertmanager
```

Owns:

```text
visibility
detection
analysis
alerting
```

---

# 46. End-to-End CI/CD Model

The complete Mini-Write deployment architecture is:

```text
                         ┌───────────────────┐
                         │ Git Repository    │
                         │                   │
                         │ Source            │
                         │ Tests             │
                         │ Dockerfiles       │
                         │ Ansible           │
                         │ Workflow          │
                         └─────────┬─────────┘
                                   │
                                   ▼
                         ┌───────────────────┐
                         │ GitHub Actions    │
                         │                   │
                         │ CI Validation     │
                         │ Build             │
                         │ Deployment        │
                         └─────────┬─────────┘
                                   │
                                   ▼
                         ┌───────────────────┐
                         │ Self-hosted       │
                         │ Runner            │
                         └─────────┬─────────┘
                                   │
                                   ▼
                    ┌────────────────────────────┐
                    │ Deployment Runtime         │
                    │                            │
                    │ /opt/deploy                │
                    │ Docker Compose             │
                    │ Runtime Configuration      │
                    └─────────────┬──────────────┘
                                  │
                                  ▼
             ┌────────────────────────────────────────┐
             │ Application Runtime                    │
             │                                        │
             │ Gateway                                │
             │ API                                    │
             │ Worker                                 │
             │ PostgreSQL                             │
             │ Redis                                  │
             │ MinIO                                  │
             └──────────────────┬─────────────────────┘
                                │
                                ▼
             ┌────────────────────────────────────────┐
             │ Observability                          │
             │                                        │
             │ Prometheus                             │
             │ Loki                                   │
             │ Grafana                                │
             │ Alertmanager                            │
             └──────────────────┬─────────────────────┘
                                │
                                ▼
                       Operational Feedback
                                │
                                └──────────────►
                                   Engineering
                                   Improvement
```

---

# 47. Design Principles

The CI/CD architecture follows these principles.

## 47.1 Validate Before Mutate

The pipeline should detect invalid changes before modifying the running environment.

## 47.2 Infrastructure Is Versioned

Runner and host configuration should be reproducible through Infrastructure as Code.

## 47.3 Configuration Is Separated From Artifacts

Environment-specific configuration should not unnecessarily become part of immutable application images.

## 47.4 Deployment Is Observable

A deployment must leave enough evidence to determine its outcome.

## 47.5 Runtime Health Is More Important Than Command Success

A successful deployment command does not prove application health.

## 47.6 Failure Must Be Explicit

Pipeline and deployment failures should stop or clearly fail the relevant lifecycle stage rather than silently continuing.

## 47.7 Deployment State Is Preserved

Current and previous artifact identities should remain available for operational reasoning and rollback.

## 47.8 CI/CD Is Not the Reliability Layer

CI/CD prevents and controls deployment failures.

Runtime Reliability handles failures during execution.

---

# 48. Relationship With Other Documentation

This document defines the CI/CD architecture.

Related documentation:

```text
docs/deployment/deployment.md
    → Deployment lifecycle and execution model

docs/deployment/configuration.md
    → Runtime and deployment configuration

docs/infrastructure/infrastructure-as-code.md
    → Infrastructure reproducibility

docs/infrastructure/ansible.md
    → Ansible architecture

docs/infrastructure/host-provisioning.md
    → Staging host provisioning

docs/operations/operations.md
    → Operational procedures

docs/reliability/reliability.md
    → Reliability architecture

docs/observability/observability.md
    → Observability architecture

docs/troubleshooting/deployment-issues.md
    → Deployment troubleshooting

docs/reference/environment-variables.md
    → Environment variable reference
```

These documents intentionally have different responsibilities and should not duplicate the entire CI/CD implementation.

---

# 49. Source of Truth

The executable CI/CD behavior is defined by the repository workflow under:

```text
.github/workflows/
```

This document describes the architectural model and operational reasoning behind that workflow.

If this document and the executable workflow ever disagree:

```text
Executable Workflow
        │
        ▼
Actual Behavior
```

should be treated as the immediate operational source of truth.

The documentation must then be corrected to restore consistency.

---

# 50. Definition of Done

The Mini-Write CI/CD architecture is considered adequately documented when an engineer can answer:

```text
✓ Where does CI/CD begin?
✓ Where is the workflow defined?
✓ Which runner executes deployment?
✓ How is the runner provisioned?
✓ What separates CI from CD?
✓ How are application artifacts identified?
✓ Where does runtime configuration come from?
✓ How is deployment state preserved?
✓ How is deployment success verified?
✓ How are deployment failures investigated?
✓ How does observability validate deployment behavior?
✓ How is rollback conceptually supported?
✓ What are the security boundaries?
✓ Which configuration is owned by Ansible?
✓ Which configuration is owned by Docker Compose?
✓ Which configuration is owned by the application?
✓ Which configuration is owned by observability?
✓ Where should an engineer look for detailed references?
```

The resulting model is:

```text
Change
  │
  ▼
Validate
  │
  ▼
Build
  │
  ▼
Deploy
  │
  ▼
Verify
  │
  ▼
Observe
  │
  ├── Healthy ──► Release Complete
  │
  └── Unhealthy
          │
          ▼
     Investigate
          │
          ├── Recover
          └── Rollback
```

This is the governing CI/CD lifecycle for the Mini-Write staging environment.

```

هذا الملف يضع **CI/CD داخل المعمارية العامة للمشروع** بدل أن يكون مجرد شرح لملف GitHub Actions؛ فهو يربط بين `Git → CI → self-hosted runner → deployment runtime → Docker Compose → application → observability → rollback/feedback`. وهذا مهم خصوصًا لأن مرحلة Infrastructure ومرحلة Deployment أصبحتا موثقتين كطبقتين منفصلتين لكن مترابطتين. 
```
