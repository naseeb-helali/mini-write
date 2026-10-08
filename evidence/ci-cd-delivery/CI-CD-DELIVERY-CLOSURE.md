# CI/CD & Delivery — Evidence Closure

## Status

**Closed — optimization and measurement phase complete.**

The CI/CD & Delivery evidence objective is complete. No further CI optimization is required before moving to **Release & Artifact Management**.

## 1. Measurement Contract

| Property | Definition |
|---|---|
| E2E scope | First instrumented job start → last instrumented job completion |
| Build scope | Build job start → timing finalization |
| Queue time | Excluded |
| Evidence publication time | Excluded |
| Source | GitHub Actions timing fragments aggregated into `ci-timing.json` |

This measurement definition ensures that the reported CI metrics have a precise and reproducible scope.

---

## 2. Baseline

The initial measured CI execution established the following baseline:

| Metric | Baseline |
|---|---:|
| CI E2E | **1866s (31m06s)** |
| Build | **954s (15m54s)** |

The baseline was collected before the Trivy execution optimization.

---

## 3. Optimized Observations

Three optimized CI executions were recorded using the same CI configuration.

### E2E

```text
887s
908s
893s
````

Median:

```text
893s
```

Equivalent to:

```text
14m53s
```

### Build

```text
412s
420s
410s
```

Median:

```text
412s
```

Equivalent to:

```text
6m52s
```

The optimized observations remained within a relatively narrow range:

* E2E range: **21 seconds**
* Build range: **10 seconds**

This provides repeatability evidence for the optimization rather than relying on a single optimized run.

---

## 4. Measured Result

| Metric | Baseline | Optimized Median | Reduction | Reduction % |
| ------ | -------: | ---------------: | --------: | ----------: |
| E2E    |    1866s |             893s |      973s |  **52.15%** |
| Build  |     954s |             412s |      542s |  **56.81%** |

### E2E

```text
1866s → 893s

Reduction:
973s

Reduction:
52.15%
```

### Build

```text
954s → 412s

Reduction:
542s

Reduction:
56.81%
```

These are measured results from the Mini-Write CI environment and should not be interpreted as universal CI or Trivy performance benchmarks.

---

## 5. Engineering Change

### 5.1 Observed Problem

The API and Worker container images were both scanned using Trivy within the same CI `build` job.

The first invocation performed the required Trivy initialization:

```text
Install Trivy
        ↓
Restore / prepare vulnerability database
        ↓
Run Trivy
```

The second invocation repeated initialization work that was already available within the same job execution context.

This created unnecessary duplicated work.

---

### 5.2 Root Cause

The two Trivy invocations were executed:

* within the same GitHub Actions job
* on the same execution environment
* using the same local Trivy cache directory
* using the same Trivy configuration

Therefore, repeating scanner installation and cache/database initialization for the Worker scan was unnecessary.

---

### 5.3 Engineering Change

The Worker Trivy invocation was changed to reuse the state prepared by the API invocation.

The relevant configuration became:

```yaml
skip-setup-trivy: true
cache: false
cache-dir: .trivycache/
```

The intent was:

```text
API Trivy invocation
        │
        ├── Install Trivy
        ├── Prepare / restore vulnerability DB
        └── Run API scan
                 │
                 ▼
       Existing job execution context
                 │
                 ▼
Worker Trivy invocation
        │
        └── Run Worker scan
```

The optimization therefore removed redundant initialization rather than removing the security scan.

---

## 6. Security Preservation

The performance optimization did **not** achieve the improvement by weakening the security pipeline.

The following controls remained in place:

* API image Trivy scan retained.
* Worker image Trivy scan retained.
* Trivy remained the scanner.
* Worker scanning was not skipped.
* The existing severity configuration was not reduced as part of this optimization.

The observed optimized Worker Trivy invocation completed in approximately:

```text
~1s
```

after redundant Trivy installation and vulnerability-database restoration were avoided.

This value represents the observed **second Trivy action invocation duration** in the CI job. It should not be presented as a universal one-second vulnerability-scanning benchmark.

---

## 7. Evidence Chain

The engineering evidence can be summarized as:

```text
Observed duplicated Trivy initialization
                ↓
Measured CI baseline
                ↓
Identified redundant setup/cache lifecycle
                ↓
Reuse existing Trivy installation and local DB
                ↓
Preserve API + Worker security scans
                ↓
Execute three optimized CI runs
                ↓
Calculate optimized median
                ↓
Validate repeatability
                ↓
Measured improvement
                ↓
CI/CD & Delivery closed
```

This establishes the complete:

```text
Problem
   ↓
Measurement
   ↓
Root Cause
   ↓
Engineering Change
   ↓
Validation
   ↓
Measured Improvement
   ↓
Evidence
```

chain.

---

## 8. Claims Boundary

### 8.1 Defensible Claims

The following claims are directly supported by the collected evidence:

* Reduced measured CI E2E execution from **1866s to a median of 893s** across three optimized observations.
* Reduced measured CI build execution from **954s to a median of 412s**.
* Achieved a **52.15% reduction** in measured E2E execution.
* Achieved a **56.81% reduction** in measured build execution.
* Removed redundant Trivy initialization and vulnerability-database/cache restoration from the second Trivy invocation within the same CI job.
* Preserved both API and Worker image security scans.

---

### 8.2 Claims Intentionally Not Made

The evidence does not justify claiming:

* Production-scale CI performance.
* Universal Trivy performance independent of runner or environment.
* A universal one-second Worker vulnerability-scan duration.
* That the same percentage improvement will necessarily occur on another CI runner or infrastructure configuration.
* That the optimization represents a production incident or production outage improvement.

These claims are intentionally excluded to keep the evidence technically defensible.

---

## 9. CV-Ready Evidence Statement

> **Optimized GitHub Actions CI by reusing Trivy scanner state and vulnerability data across API/Worker image scans, reducing measured CI E2E execution from 31m06s to a median 14m53s (52.15%) and build execution from 15m54s to a median 6m52s (56.81%) across three optimized runs, while retaining both image security scans.**

---

## 10. Engineering Significance

The value of this work is not simply the reduction in execution time.

The demonstrated engineering process was:

1. Instrument the CI pipeline.
2. Establish a measurable baseline.
3. Identify the actual bottleneck.
4. Inspect the internal execution behavior.
5. Identify redundant work.
6. Change the implementation without weakening the security control.
7. Execute multiple validation runs.
8. Compare baseline against optimized median.
9. Preserve the resulting evidence.
10. Close the optimization instead of continuing unnecessary tuning.

This demonstrates a measurement-driven CI optimization workflow rather than arbitrary pipeline tuning.

---

## 11. Closure Decision

**CI/CD & Delivery: CLOSED**

No additional CI optimization is required for the current Mini-Write evidence objective.

Further optimization should only be introduced if a new measurable requirement or bottleneck is identified.

The project can therefore proceed to the next evidence area:

# Release & Artifact Management

The next area should focus on:

* Artifact identity
* Artifact immutability
* Image digest traceability
* Artifact manifest integrity
* Release-to-artifact relationship
* Digest verification
* Promotion correctness
* Detection/rejection of artifact mismatch
* Evidence of reproducible promotion

```
```
