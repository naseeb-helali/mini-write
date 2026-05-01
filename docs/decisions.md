# 📝 Architectural Decisions — Mini-Write

---

## 1️⃣ Queue Technology: Redis + BullMQ

**Decision:** Use Redis as the backend for BullMQ queues.

**Reasoning:**

* ✅ **High performance**: In-memory store → low-latency job scheduling.
* ✅ **Persistence**: AOF (Append-Only File) allows recovery after crash.
* ✅ **Compatibility**: BullMQ integrates natively with Node.js.
* ✅ **Simplicity**: No need for a complex broker like RabbitMQ for our workload.

**Alternatives Considered:**

| Alternative | Pros                                     | Cons                                                |
| ----------- | ---------------------------------------- | --------------------------------------------------- |
| RabbitMQ    | Advanced features, transactional support | Operational overhead, heavier footprint             |
| Kafka       | Persistent logs, scalable                | Overkill for single queue system, higher complexity |

**Trade-offs:**

* At-least-once delivery → possible duplicate jobs
* Compensated by **idempotency layer** in Worker

---

## 2️⃣ Image Processing: Sharp + MinIO

**Decision:** Use Sharp for image processing and MinIO for object storage.

**Reasoning:**

* ✅ **Sharp**: Fast, memory-efficient, supports streaming, rotation, resizing.
* ✅ **MinIO**: S3-compatible → portable for cloud deployment.
* ✅ **Local dev alignment**: Enables full local simulation of production.

**Alternatives Considered:**

| Alternative | Pros                       | Cons                          |
| ----------- | -------------------------- | ----------------------------- |
| Jimp        | Pure JS, easier to install | Slower, memory heavy          |
| AWS S3      | Managed service            | Harder to test locally, costs |

**Trade-offs:**

* MinIO allows offline dev/testing → trade-off is managing local persistence manually.
* Sharp in memory → memory safety critical → we added **MAX_FILE_SIZE checks** and dynamic concurrency.

---

## 3️⃣ Idempotency & Consistency

**Decision:** Implement DB row-level locking + status flags for job processing.

**Reasoning:**

* ✅ Prevent race conditions between multiple workers.
* ✅ Ensure at-least-once jobs do not corrupt data.
* ✅ Partial failure safe → retry logic does not break system.

**Alternatives Considered:**

| Alternative               | Pros                | Cons                                |
| ------------------------- | ------------------- | ----------------------------------- |
| Distributed locks (Redis) | Global locks        | Complexity, deadlock risk           |
| Optimistic locking        | No DB lock overhead | Needs conflict handling → more code |

**Trade-offs:**

* Slight DB overhead per job → acceptable for correctness.
* Guarantees safe multi-worker execution.

---

## 4️⃣ API Design: Express.js + Structured Services

**Decision:** Node.js + Express with service-layer separation.

**Reasoning:**

* ✅ Familiar to full-stack engineers.
* ✅ Lightweight → fast container startup.
* ✅ Clear separation: routes, services, processors → maintainable.

**Alternatives Considered:**

| Alternative | Pros          | Cons                                 |
| ----------- | ------------- | ------------------------------------ |
| NestJS      | Full-featured | Heavier, steeper learning curve      |
| Fastify     | Faster        | Less community adoption than Express |

**Trade-offs:**

* Express simplicity → fewer built-in patterns → must enforce **service layer discipline manually**.

---

## 5️⃣ Containerization: Docker Multi-Stage Builds

**Decision:** Multi-stage Docker builds for API & Worker.

**Reasoning:**

* ✅ Reduced final image size.
* ✅ Separation of build vs runtime → fewer vulnerabilities.
* ✅ Idempotent, cacheable layers → faster rebuilds.

**Alternatives Considered:**

| Alternative        | Pros    | Cons                             |
| ------------------ | ------- | -------------------------------- |
| Single-stage image | Simpler | Large, includes dev dependencies |

**Trade-offs:**

* Slightly longer build pipeline → offset by smaller runtime images and security benefits.

---

## 6️⃣ Proxy Layer: Nginx

**Decision:** Nginx as reverse proxy + basic security headers + rate limiting.

**Reasoning:**

* ✅ Shields Node API from direct public access.
* ✅ Handles connection keep-alive, max body size.
* ✅ Enables simple load balancing if scaling horizontally.

**Alternatives Considered:**

| Alternative            | Pros   | Cons                                                |
| ---------------------- | ------ | --------------------------------------------------- |
| Node.js built-in proxy | Simple | Less performant, no rate limiting, harder to secure |

**Trade-offs:**

* Slight increase in latency (~1-2ms) → negligible for microservices.

---

## 7️⃣ Resource Safety

**Decision:** Limit memory & CPU in Docker + dynamic concurrency.

**Reasoning:**

* ✅ Prevent OOM kills in Worker.
* ✅ Keep API stable under load.
* ✅ Aligns with production container orchestration standards.

**Trade-offs:**

* Limited concurrency → throughput slightly reduced
* Safety prioritized over raw speed

---

## 8️⃣ Health & Readiness

**Decision:** Implement true health checks for:

* DB connectivity
* Redis availability
* MinIO reachability

**Reasoning:**

* ✅ Reliable Docker health checks
* ✅ Supports Kubernetes readiness probes
* ✅ Detects service degradation early

**Trade-offs:**

* Health check adds extra minor latency per probe → acceptable

---

## 9️⃣ Security Basics

**Decision:** Remove hardcoded secrets + enforce secure headers & method filtering

**Reasoning:**

* ✅ Avoid leaking sensitive information.
* ✅ Reduce attack surface.
* ✅ Compatible with containerized deployment.

**Trade-offs:**

* Slightly more complex configuration → worth it for secure production-grade system.

---

## 🔑 Summary of Decisions

| Layer           | Decision                      | Key Benefit                 |
| --------------- | ----------------------------- | --------------------------- |
| Queue           | Redis + BullMQ                | Reliable job execution      |
| Storage         | MinIO                         | Cloud-compatible, local dev |
| Image Processor | Sharp                         | Fast, memory-safe           |
| DB              | Transactions + Row Lock       | Correctness, idempotency    |
| API             | Express + Services            | Maintainable, testable      |
| Containers      | Multi-stage Docker            | Small & secure images       |
| Proxy           | Nginx                         | Security + performance      |
| Resource Safety | Limits + Dynamic concurrency  | Prevent crashes under load  |
| Health          | Full service checks           | Reliable orchestration      |
| Security        | No hardcoded values + headers | Production-grade safety     |

---