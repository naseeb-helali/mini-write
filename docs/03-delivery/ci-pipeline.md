# CI Pipeline

## 1. Purpose

The CI pipeline automates the repeatable checks required before application artifacts are published. Its purpose is to detect defects early, produce container images from a known source revision, and retain evidence about execution and quality gates.

## 2. Workflow location

The primary workflow is `.github/workflows/ci.yml`. API and Worker are treated as separate application components and are validated through their own package/test configuration.

## 3. Pipeline responsibilities

The workflow covers the following broad stages:

1. Source checkout and dependency setup.
2. API and Worker quality/test execution.
3. Coverage collection and threshold evaluation.
4. Dependency security audit.
5. Docker image build.
6. Container image scanning.
7. Registry publication using source-revision identity.
8. Timing/evidence aggregation where configured.

The exact order and conditions are defined by the workflow YAML and should be treated as the executable contract.

## 4. Tests and coverage

API and Worker use Jest-based test suites. The reviewed repository includes test directories and coverage summaries. The CI coverage gate checks line coverage against a 70% threshold. It should not be described as a 70% gate for every coverage dimension: branch and function coverage are separate measurements.

Recorded coverage snapshots include:

| Component | Lines | Statements | Functions | Branches |
|---|---:|---:|---:|---:|
| API | 80.44% | 80.22% | 75.83% | 53.62% |
| Worker | 87.74% | 87.17% | 66.66% | 54.90% |

These are repository coverage artifacts. They are not proof that the review environment freshly executed the test suite.

## 5. Lint and static checks

The reviewed API and Worker `lint` scripts currently print that linting is not configured. Therefore, the pipeline must not be described as enforcing ESLint or an equivalent lint policy merely because a job or command named lint exists.

The archive review separately performed static syntax/parsing checks. Those review results are recorded in [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md), not as a CI run.

## 6. Dependency and image security

The workflow includes `npm audit` at high severity and Trivy image scanning. The CI optimization evidence describes reuse of Trivy setup/cache state between API and Worker scans in the same job to avoid redundant initialization.

The optimization retained both image scans; it did not remove the Worker scan. However, the reviewed Trivy action configuration uses `exit-code: 0` for the scan, which makes the scan informational/non-blocking rather than a release-blocking vulnerability gate. Describe the scan as executed/configured, not as a mandatory critical-vulnerability deployment gate.

## 7. CI performance optimization

The retained closure defines the measurement contract:

- E2E timing starts at the first instrumented job and ends at the last instrumented job.
- Queue time is excluded.
- Evidence publication time is excluded.
- Build timing is measured from build job start to timing finalization.

Recorded values:

| Metric | Baseline | Optimized observations | Optimized median |
|---|---:|---|---:|
| CI E2E | 1866s | 887s, 908s, 893s | 893s |
| Build | 954s | 412s, 420s, 410s | 412s |

Using the displayed baseline and median values, the E2E reduction is 973 seconds (approximately 52.14%); the Build reduction is 542 seconds (approximately 56.81%). The closure text reports 52.15% for E2E, a small arithmetic/rounding discrepancy. The documentation uses raw values and a consistently recomputed percentage.

The engineering change avoided repeating Trivy setup/database initialization for the second image scan within the same job. The evidence reports the second invocation at approximately one second in that measured run; this is not a general scan-performance guarantee.

## 8. Artifact output

The workflow builds API and Worker images and publishes them to the configured registry using source SHA identity. The artifact lifecycle, manifest, digest validation, and promotion controls are described in [Artifact Management](artifact-management.md).

## 9. Runner model

The workflows use a self-hosted runner in the reviewed configuration. The runner is provisioned by the VM Ansible GitHub runner role and has Docker access. It is therefore part of the delivery control plane, not an incidental build agent.

Runner availability, credentials, Docker privileges, and workflow trust are operational dependencies. Pull-request workflows running on a persistent privileged self-hosted runner require careful repository and branch trust controls.

## 10. Verification boundary

The CI closure supports the recorded performance measurements and optimization. It does not mean every current workflow revision was freshly executed during this archive review. The static review did not install dependencies or execute Jest tests.

## 11. Source map

- `.github/workflows/ci.yml`
- `api/package.json`, `api/package-lock.json`, `api/jest.config.js`, `api/tests/`
- `worker/package.json`, `worker/package-lock.json`, `worker/tests/`
- `api/Dockerfile`, `worker/Dockerfile`
- `ci/ci-timing.schema.json`
- `evidence/ci-cd-delivery/`

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
