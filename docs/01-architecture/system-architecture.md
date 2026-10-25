# System Architecture

## 1. Purpose and boundaries

Mini-Write is a small distributed application used as the workload for DevOps engineering practice. This document explains the application components and their dependencies only to the extent required to understand deployment, operations, and reliability. It is not intended to replace application source documentation.

## 2. Logical architecture

```text
                    Client
                      |
                      v
               Nginx Gateway
                      |
                      v
                Node.js API
                /    |    \
               /     |     \
              v      v      v
        PostgreSQL Redis   Object Storage
                     |
                  BullMQ
                     |
                     v
                  Worker
                     |
              Image Processing
                     |
                     v
              Object Storage
```

The API is the synchronous request-facing service. The Worker performs asynchronous image-processing work. PostgreSQL stores application state; Redis-compatible queue infrastructure carries asynchronous jobs; object storage holds source and processed objects.

## 3. Component responsibilities

| Component | Responsibility | Operational dependency |
|---|---|---|
| Nginx | Reverse proxy and request-edge controls | API upstream and gateway configuration |
| API | HTTP endpoints, request validation, application coordination, queue submission | PostgreSQL, Redis/Valkey, object storage |
| Redis / Valkey | BullMQ queue backend | API and Worker connectivity; persistence/availability configuration depends on platform |
| Worker | Consume jobs and process images | Queue backend, PostgreSQL, object storage |
| PostgreSQL | Durable application records and processing state | Network reachability, credentials, schema compatibility |
| MinIO / S3 | Object storage provider | API/Worker credentials and endpoint configuration |
| Prometheus metrics endpoints | Expose operational measurements | Scraper reachability and metric instrumentation |

## 4. Request and processing flow

A typical asynchronous upload flow is:

1. Client sends an upload request through Nginx.
2. Nginx forwards the request to the stateless API.
3. API validates the request and coordinates storage and application state.
4. API creates or updates the corresponding database record and submits asynchronous work to BullMQ.
5. Worker consumes the job and retrieves the required object.
6. Worker performs image processing using Sharp.
7. Worker writes the resulting object to the configured storage provider.
8. Worker updates the processing state in PostgreSQL.
9. Subsequent API reads expose the persisted result/state.

The exact sequence of database and queue operations matters for failure handling. Queue submission is not equivalent to completed processing, and an API success response must not be interpreted as proof that asynchronous processing has completed.

## 5. Storage abstraction

The code contains storage provider implementations for MinIO and S3. This allows the application to use a local/self-managed object-storage endpoint in one deployment context and AWS S3 in AWS deployment contexts, subject to the runtime configuration. The abstraction is an application integration boundary; it does not mean that storage data is automatically shared between different environments.

## 6. Queue processing model

BullMQ is used for asynchronous image-processing jobs. The Worker configuration includes retry attempts and exponential backoff, with concurrency configured in the Worker. The application uses processing states such as `pending`, `processing`, and `verified` to represent progress.

This is an at-least-once processing environment: a job can be retried, and the same logical work may be observed more than once. Idempotency is therefore a necessary application behavior, not an optional optimization. The state transitions and duplicate handling must be interpreted carefully; the current source review identified a failure path in which a job left in `processing` can be skipped on retry. See [Reliability & Recovery](../04-operations/reliability-and-recovery.md).

## 7. Health interfaces

The API exposes:

- `/health/live` — process liveness signal.
- `/health/ready` — readiness signal that considers required dependencies.
- `/metrics` — application metrics endpoint.

The Worker exposes its metrics server on port 9464 in the reviewed configuration and has its own health/runtime checks. Deployment platforms do not all consume health information in the same way: Docker health checks, ECS task health checks, Kubernetes probes, and CI deployment verification are distinct mechanisms.

## 8. Container boundaries

The API and Worker are separately containerized using their own Dockerfiles and package manifests. This allows them to be built and deployed independently while sharing the application codebase and common infrastructure dependencies.

The Nginx gateway is configured separately. Runtime port values differ by deployment context: the VM Ansible template configures the API to listen on port 80, while ECS/Kubernetes use the API container's 8080 listener behind a Service/target mapping. The root `.env.example` and root Compose healthcheck/upstream values require careful interpretation; do not treat the example file as a validated universal runtime contract.

## 9. Key operational dependencies

- API readiness depends on required backing services, not merely process startup.
- Queue availability affects asynchronous submission and processing.
- PostgreSQL state and object storage can become inconsistent if a multi-step operation fails partway through.
- Worker retry behavior must be idempotent with respect to database and object-storage side effects.
- Storage provider configuration must match the selected deployment platform.

## 10. Source map

- `api/src/index.js`, `api/src/routes/`, `api/src/controllers/`
- `api/src/services/queueService.js`, `api/src/services/storageService.js`
- `api/src/storage/providers/minio.js`, `api/src/storage/providers/s3.js`
- `api/src/health/`, `api/src/observability/`
- `worker/src/index.js`, `worker/src/processors/imageProcessor.js`
- `worker/src/storage/`, `worker/src/health/`, `worker/src/observability/`
- `docker-compose.yml`, `api/Dockerfile`, `worker/Dockerfile`, `proxy/nginx.conf`

## 11. Scope boundary

This architecture describes the application as a DevOps workload. It does not attempt to document every API contract, data model, UI feature, or image-processing algorithm. Those details belong in application-level documentation if needed.

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
