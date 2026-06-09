# 🚀 Mini-Write — Asynchronous Image Processing System

> **Production-Ready Distributed System**
> Built to simulate core backend services of an Appwrite-like platform with a strong focus on **DevOps, Reliability, and System Design**

---

## 🧠 Overview

Mini-Write is a **high-performance asynchronous image processing pipeline** designed to handle user-uploaded identity documents at scale.

The system follows an **event-driven architecture** where heavy tasks (image processing) are completely decoupled from the API layer, ensuring:

* ⚡ Fast API response times (<100ms)
* 🔄 Reliable background processing
* 📦 Scalable worker-based execution

---

## 🎯 Core Use Case

Users upload ID images → system processes them asynchronously:

* Image optimization (resize, compress)
* Metadata sanitization
* Storage separation (raw vs processed)
* Database state update

---

## 🏗️ Architecture

```text
Client → Nginx (Gateway) → API → Redis (Queue) → Worker → MinIO + PostgreSQL
```

---

## 🔧 Tech Stack

| Layer         | Technology            |
| ------------- | --------------------- |
| Gateway       | Nginx                 |
| API           | Node.js (Express)     |
| Queue         | Redis + BullMQ        |
| Worker        | Node.js + Sharp       |
| Database      | PostgreSQL            |
| Storage       | MinIO (S3-compatible) |
| Orchestration | Docker Compose        |

---

## ⚙️ Key Engineering Features

### 🔷 1. Reliability Layer (Critical)

* Idempotent job processing
* Duplicate job prevention using `jobId`
* Safe retry strategy with exponential backoff
* Crash-safe execution model

---

### 🔷 2. Consistency & Data Integrity

* Transactional DB updates
* Race condition protection using `SELECT ... FOR UPDATE`
* Conditional updates to prevent concurrent execution
* Multi-phase processing (lock → process → commit)

---

### 🔷 3. Asynchronous Processing Model

* "Upload & Forget" pattern
* API is fully stateless
* Background workers handle heavy CPU tasks

---

### 🔷 4. Health & Readiness System

* `/health/live` → liveness probe
* `/health/ready` → deep system validation
* Real checks:

  * PostgreSQL
  * Redis
  * MinIO

---

### 🔷 5. Resource Safety

* Memory limits per container
* CPU constraints
* Node.js memory caps (`--max-old-space-size`)
* File size protection (anti-memory-exhaustion)

---

### 🔷 6. Security (Gateway Level)

* Rate limiting (Nginx)
* Security headers:

  * X-Frame-Options
  * CSP
  * XSS Protection
* Method filtering
* Proxy hardening

---

### 🔷 7. Storage Strategy

* Raw images → private bucket
* Processed images → optimized bucket
* Full separation of concerns

---

## 🧪 8. Testing

The system includes a comprehensive testing strategy covering:

- API logic (authentication, upload)
- Worker processing pipeline
- Middleware access control
- Health & readiness endpoints
- Failure and edge-case scenarios

See: `docs/testing.md`

---

## 🔄 Request Flow (Deep Dive)

### 1. Upload Phase

* API receives image
* Stores raw file in MinIO
* Pushes job to Redis queue

### 2. Processing Phase

* Worker consumes job
* Applies image transformation (Sharp)
* Uploads processed image

### 3. Finalization Phase

* Updates PostgreSQL:

  * `document_url`
  * `identity_status = verified`

---

## 🧪 Failure Handling Strategy

| Scenario          | Behavior                      |
| ----------------- | ----------------------------- |
| Worker crash      | Job retried automatically     |
| Redis restart     | Jobs preserved (AOF enabled)  |
| Duplicate request | Ignored via idempotency       |
| Partial failure   | Safe retry without corruption |

---

## 🚀 Quick Start

```bash
git clone <repo>
cd mini-write
cp .env.example .env
docker-compose up --build
```

---

## 📡 Endpoints

| Endpoint           | Description     |
| ------------------ | --------------- |
| `/api/v1/auth/...` | API routes      |
| `/health/live`     | Liveness check  |
| `/health/ready`    | Readiness check |

---

## 📊 What This Project Demonstrates

This project is not a CRUD app.

It demonstrates:

* Distributed system design
* Event-driven architecture
* Production-grade reliability patterns
* DevOps mindset (containers, networking, isolation)
* Failure handling & system resilience

---

## 🧠 Design Philosophy

> “Build systems that continue to work even when parts of them fail.”

Key principles:

* Decoupling
* Observability-ready design
* Failure-first thinking
* Horizontal scalability

---

## 🔮 Next Steps (Planned)

* Kubernetes deployment (HPA + Probes)
* Observability stack (Prometheus + Grafana + ELK)
* Infrastructure as Code (Terraform + Ansible)

---

## 👨‍💻 Author

Built with a focus on mastering **DevOps Engineering & Distributed Systems**

---

## ⭐ Why This Project Matters

This system reflects real-world backend challenges:

* Handling asynchronous workloads
* Ensuring data consistency
* Preventing race conditions
* Building resilient pipelines

---

> 🔥 This is not just a project — it's a **production mindset demonstration**