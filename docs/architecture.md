# 🏗️ Architecture Documentation — Mini-Write

---

## 🧠 1. System Overview

Mini-Write is designed as a **distributed, event-driven system** that separates user-facing operations from heavy background processing.

The architecture follows a **decoupled pipeline model** to ensure:

* High responsiveness
* Fault tolerance
* Horizontal scalability

---

## 🔷 2. High-Level Architecture

```text
Client 
   ↓
Nginx (Gateway)
   ↓
API Service (Stateless)
   ↓
Redis (Message Queue)
   ↓
Worker Service (Processing Engine)
   ↓
MinIO (Storage) + PostgreSQL (State)
```

---

## 🧩 3. Component Breakdown

---

### 🌐 3.1 Gateway — Nginx

**Responsibility:**

* Entry point to the system
* Reverse proxy to API
* Traffic control & security layer

**Key Features:**

* Rate limiting (protect against abuse)
* Security headers (CSP, XSS protection)
* Method filtering
* Request size limits

---

### ⚙️ 3.2 API Service (Node.js)

**Responsibility:**

* Handle incoming user requests
* Validate & accept uploads
* Push jobs to queue

**Design Characteristics:**

* Stateless (no session storage)
* Fast response (non-blocking)
* No heavy processing

**Why this matters:**

> Prevents CPU-heavy operations from blocking user requests

---

### 🧠 3.3 Redis (Queue Layer)

**Responsibility:**

* Message broker between API and Worker
* Job persistence and retry handling

**Design Decisions:**

* BullMQ used for simplicity and Node.js integration
* AOF (Append Only File) enabled for durability

**Key Features:**

* Retry mechanism (exponential backoff)
* Job deduplication via `jobId`

---

### 👷 3.4 Worker Service

**Responsibility:**

* Execute background jobs
* Process images using Sharp
* Update system state

**Key Characteristics:**

* Isolated from API
* Concurrency-controlled
* Crash-safe design

---

### 🗄️ 3.5 PostgreSQL (State Layer)

**Responsibility:**

* Source of truth for user data
* Track processing state

**Important Fields:**

* `identity_status` → pending / processing / verified
* `document_url` → processed image reference

**Consistency Strategy:**

* Row-level locking (`FOR UPDATE`)
* Transactional updates
* Conditional state transitions

---

### 📦 3.6 MinIO (Object Storage)

**Responsibility:**

* Store uploaded and processed images

**Storage Strategy:**

| Bucket         | Purpose               |
| -------------- | --------------------- |
| user-documents | Raw uploads (private) |
| processed-docs | Optimized images      |

**Design Benefit:**

> Separation between raw and processed data improves performance and security

---

## 🔄 4. Data Flow (End-to-End)

---

### 🔷 Step 1: Upload Phase

* Client sends image to API
* API uploads raw file to MinIO
* API enqueues job in Redis
* API returns immediate response

---

### 🔷 Step 2: Queue Processing

* Worker pulls job from Redis
* Validates job (idempotency check)
* Marks DB state as `processing`

---

### 🔷 Step 3: Image Processing

* Fetch image from MinIO
* Process in memory (Sharp)
* Upload processed version

---

### 🔷 Step 4: Finalization

* Update PostgreSQL:

  * document_url
  * identity_status = verified

---

## ⚖️ 5. Key Architectural Decisions

---

### 🔹 5.1 Decoupling API from Processing

**Decision:**
Use Redis queue between API and Worker

**Why:**

* Avoid blocking requests
* Enable scaling workers independently

---

### 🔹 5.2 Event-Driven Design

**Decision:**
Use asynchronous job execution

**Why:**

* Improves performance under load
* Allows retry & failure recovery

---

### 🔹 5.3 Stateless API

**Decision:**
No session or local state

**Why:**

* Enables horizontal scaling
* Works with load balancers easily

---

### 🔹 5.4 Storage Separation

**Decision:**
Separate raw and processed buckets

**Why:**

* Security (raw files private)
* Performance (optimized images served faster)

---

## 🧱 6. Network Design

---

### 🔷 Network Isolation

Two Docker networks:

* **frontend-network**

  * Gateway + API
  * Public-facing

* **backend-network**

  * Redis, Worker, DB, MinIO
  * Fully isolated

---

### 🔥 Security Benefit

> No direct access to internal services from outside

---

## 🛡️ 7. Reliability & Fault Tolerance

---

### 🔷 Job Retry Strategy

* Exponential backoff
* Configurable retry attempts

---

### 🔷 Idempotency

* Prevent duplicate processing
* Skip already processed jobs

---

### 🔷 Crash Recovery

* Jobs retried automatically
* DB state ensures consistency

---

## ⚡ 8. Performance Considerations

---

### 🔷 API Performance

* No heavy operations
* Fast response time (<100ms)

---

### 🔷 Worker Optimization

* Controlled concurrency
* Memory-limited processing

---

### 🔷 Streaming Strategy

* Buffer size limited (5MB max)
* Prevents memory exhaustion

---

## 🔍 9. Scalability Strategy

---

### 🔷 Horizontal Scaling

| Component | Strategy             |
| --------- | -------------------- |
| API       | Load balancer        |
| Worker    | Increase instances   |
| Redis     | Cluster (future)     |
| DB        | Replication (future) |

---

### 🔷 Queue-Based Scaling

> More workers = faster processing

---

## ⚠️ 10. Trade-offs

---

### 🔹 Redis vs RabbitMQ

* Redis: simple, fast, easy integration
* Trade-off: less advanced routing

---

### 🔹 Memory Processing vs Disk

* Memory: faster
* Trade-off: higher RAM usage

---

### 🔹 At-least-once Execution

* Simpler model
* Requires idempotency handling

---

## 🧪 11. Testing Layer

The system includes a dedicated testing layer:

- API tests (Supertest + Jest)
- Worker tests (mocked processing pipeline)
- Full isolation from infrastructure

This layer ensures that system components can be validated independently of runtime dependencies.

---

## 🧠 12. System Thinking Summary

This system is designed around:

* Decoupling
* Fault tolerance
* Observability readiness
* Scalability

---

> 🔥 The goal was not just to build a working system, but to build a **resilient distributed system**
