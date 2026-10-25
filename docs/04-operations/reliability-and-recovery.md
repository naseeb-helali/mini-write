# Reliability and Recovery

## 1. Purpose

Reliability engineering in Mini-Write focuses on practical operational behavior when dependencies fail, jobs retry, deployments do not become healthy, or a release must be reversed. It is an applied engineering capability, not a claim of formal SRE maturity.

## 2. Application runtime boundaries

The API and Worker contain runtime modules for execution context, operation context, policy resolution, retry behavior, and infrastructure boundaries. The purpose is to make failure-handling and dependency behavior explicit rather than scattering retry decisions throughout business logic.

The API runtime uses its infrastructure boundary in the reviewed code. The Worker contains an infrastructure boundary implementation, but the reviewed business-processing path does not demonstrate the same integration usage. Documentation must not claim symmetric runtime integration without source proof.

## 3. Retry behavior

Retries are useful for transient failures such as short-lived network errors or temporary dependency unavailability. They are harmful when they amplify load, repeat non-idempotent side effects, or hide permanent failures.

The API retry executor uses a timeout race. A timeout from `Promise.race` does not necessarily cancel the underlying operation. If the operation continues after the caller times out, a retry may overlap with the original operation. This is an important behavior boundary when describing the retry mechanism.

The Worker queue configuration uses multiple attempts with exponential backoff. This provides retry opportunities but does not by itself guarantee safe processing.

## 4. Idempotency and job state

The application uses processing states such as `pending`, `processing`, and `verified`. The Worker must be safe when a job is delivered more than once, because BullMQ processing is at-least-once in failure/retry scenarios.

The reviewed `imageProcessor.js` contains a failure path worth preserving in the reliability assessment: after the database state changes to `processing`, a later failure can cause a retry to observe that state and skip the job. This may leave the record stuck in `processing` while the queue considers the retry path complete. Therefore, the presence of state-based duplicate protection should not be described as fully proven idempotency across all failure points.

The API `queueService.js` also catches queue enqueue errors and logs them without rethrowing in the reviewed path. This can allow an API operation to appear successful even though the job was not accepted by the queue. This is a relevant reliability limitation because request success and asynchronous work acceptance are separate outcomes.

## 5. Graceful shutdown

The Worker has SIGTERM handling in the reviewed implementation. The API does not demonstrate equivalent graceful shutdown behavior. During container replacement, this difference can affect in-flight work and connection cleanup.

In Kubernetes, the API uses a `Recreate` strategy with one replica, so service downtime during replacement is possible. Worker `RollingUpdate` with `maxSurge: 1` can temporarily run old and new Workers together. Queue concurrency, duplicate handling, and graceful shutdown must therefore be considered during rollouts.

## 6. Deployment verification and rollback

Deployment reliability is supported by:

- Immutable artifact identity.
- Deployment preflight.
- Readiness/health verification.
- Recorded deployment state.
- Rollback to a previous known-good artifact.
- Post-rollback verification.

ECS evidence records a Staging deployment and rollback scenario. Kubernetes evidence records Staging deployment, Production-stage verification, and rollback. Kubernetes rollback resolves the previous successful Production-stage artifact rather than rebuilding an image.

The Kubernetes first-release case has no previous Production-stage artifact to restore. The resolver fails closed, requiring operator recovery if no prior successful verification exists.

## 7. Recovery measurements

| Platform | Operation | Recorded duration |
|---|---|---:|
| ECS | Staging deployment | 215s |
| ECS | Rollback | 182s |
| Kubernetes on EC2 | Staging deployment | 16s |
| Kubernetes on EC2 | Production-stage verification | 15s |
| Kubernetes on EC2 | Rollback | 48s |

These values are tied to retained evidence and the tested target. They are not SLAs or a fair universal comparison between orchestration platforms; the measurement boundaries and workload conditions may differ.

## 8. Reliability limitations relevant to claims

- API queue submission errors may be logged without propagating failure to the caller.
- Worker state handling may skip a retry after an earlier attempt failed in the `processing` state.
- API retry timeout does not necessarily cancel the underlying operation.
- API graceful shutdown is not equivalent to Worker graceful shutdown.
- Kubernetes API `Recreate` strategy can cause downtime.
- ECS current verify adapter has a syntax issue in the reviewed archive.
- Kubernetes rollback requires a prior successful Production-stage artifact.

These findings should be treated as bounded engineering observations, not expanded into an unrelated enterprise reliability backlog.

## 9. Source map

- `api/src/runtime/`
- `worker/src/runtime/`
- `api/src/services/queueService.js`
- `worker/src/processors/imageProcessor.js`
- `api/src/config/redis.js`
- `worker/src/config/redis.js`
- `ci/deployment/`
- `ci/rollback/`
- `ci/kubernetes/rollback/`
- `infra/kubernetes-ec2/manifests/workloads/staging/`
- `evidence/deployment-recovery/`
- `evidence/kubernetes-ec2 evidence/`

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
