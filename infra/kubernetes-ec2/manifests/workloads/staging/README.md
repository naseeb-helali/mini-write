# Mini-Write — Stage 4.2: Kubernetes Workload Manifests

## 1. Scope

This stage defines the staging Namespace, application ConfigMap, API and Worker Deployments, and their internal ClusterIP Services. It does not apply resources to the cluster.

Out of scope: Nginx/Gateway, ALB/Ingress integration, Secrets Manager delivery implementation, IAM redesign or per-Pod identity, Prometheus stack/scrape configuration, CI/CD deployment integration, and changes to ECS, Terraform, Compose, or the existing `infra/ansible/` path.

## 2. Files

| File | Responsibility |
|---|---|
| `namespace.yaml` | `mini-write-staging` Namespace |
| `configmap.yaml` | Non-secret staging runtime configuration |
| `api-deployment.yaml` | API workload, probes, resources, image digest |
| `api-service.yaml` | Internal `api:80` -> container port 8080 |
| `worker-deployment.yaml` | Background Worker, probes, resources, image digest |
| `worker-service.yaml` | Internal Worker health/metrics endpoint on 9464 |
| `kustomization.yaml` | Aggregates all Stage 4.2 resources |
| `validate.sh` | Render and optionally schema-validate; never applies |

## 3. Runtime contract mapping

| Workload | Container listener | Service | Health endpoints |
|---|---:|---|---|
| API | 8080 | `api:80` -> 8080 | `/health/live`, `/health/ready` |
| Worker | 9464 | `worker:9464` -> 9464 | `/health/live`, `/health/ready` |

The API Service retains port 80 for the existing `api:80` consumer contract while targeting the actual Node.js listener on 8080. Worker remains internal; it is not exposed publicly. Readiness is dependency-aware, while liveness is process/application health.

## 4. Immutable image references

Images are pinned by the ECR SHA-256 digests supplied for this staging build:

- API: `496494570164.dkr.ecr.us-east-1.amazonaws.com/mini-write-api@sha256:bd57bd8b9b6504c3447aca3850edd0f4a2d4ad27494cdd9ec7eb73f3a86c287d`
- Worker: `496494570164.dkr.ecr.us-east-1.amazonaws.com/mini-write-worker@sha256:59f1c216a411e4713b367fd83c40a444b7d7b5d1f301960d4e8f7cea83187d64`

The mutable tag is not used by the Deployments. The ECR credential provider is configured on the nodes, but successful private-image pulls must still be confirmed during rollout.

## 5. ConfigMap values

`configmap.yaml` uses the staging values supplied for this deployment:

- PostgreSQL endpoint: `mini-write-staging-postgres.cal0q46wccqr.us-east-1.rds.amazonaws.com`
- Database: `miniwrite_db`
- Database user: `miniwrite_admin`
- Redis endpoint: `mini-write-staging-redis.newmun.ng.0001.use1.cache.amazonaws.com`
- Region: `us-east-1`
- Buckets: `mini-write-staging-input`, `mini-write-staging-processed`

The bucket names follow the project's Stage 4.1/Terraform naming contract; verify their existence and the exact output-bucket name against the applied staging Terraform state before applying. The ConfigMap contains no credentials.

## 6. Secret prerequisite — deliberately not implemented here

Both Deployments reference an existing Kubernetes Secret named `mini-write-staging-secrets`:

- `POSTGRES_PASSWORD` — API and Worker
- `REDIS_PASSWORD` — API and Worker
- `JWT_SECRET` — API only

No Secret manifest or secret values are included. The mechanism that synchronizes AWS Secrets Manager into Kubernetes belongs to the subsequent secrets/security configuration work (Stage 4.3). Until the Secret exists with these exact keys, the Pods will not start successfully. Do not create a plaintext Secret file in Git.

## 7. Scheduling and rollout decisions

- Both workloads start with one replica, matching the existing ECS desired count.
- API uses `Recreate`: `initUserTable()` runs before its listener starts, and concurrent initialization safety has not been established. This avoids overlapping old/new API Pods at the cost of a short interruption during replacement.
- Worker uses one replica with `maxSurge: 1` and `maxUnavailable: 0`; its SIGTERM handler closes the Worker, Queue, and metrics server. During an update, a temporary second Worker Pod may run, so effective processing concurrency can temporarily increase.
- Resource limits preserve the existing ceilings: API 500m CPU / 512Mi; Worker 1 CPU / 1Gi.
- Requests (API 100m / 256Mi; Worker 250m / 512Mi) are provisional scheduling estimates, not measured production baselines. Revisit after observing actual usage and node allocatable capacity.
- API graceful HTTP server shutdown was not established by the Stage 4.1 source review. `terminationGracePeriodSeconds: 30` does not itself implement graceful shutdown.
- No HPA or PDB is introduced in this stage.

## 8. Validation

From the repository root:

```bash
bash infra/kubernetes-ec2/manifests/workloads/staging/validate.sh
```

Equivalent render-only command:

```bash
kubectl kustomize infra/kubernetes-ec2/manifests/workloads/staging
```

If `kubeconform` is installed, `validate.sh` also runs strict schema validation. The script never invokes `kubectl apply`.

Rendering/schema validation does not prove that:

- the referenced Kubernetes Secret exists;
- the S3 buckets exist or the node role has the required least-privilege permissions;
- RDS/Redis are reachable from the Pods;
- the ECR credential provider can pull these specific images;
- the Worker can write to the processed bucket;
- the Pods can schedule and become Ready.

Those checks belong to the pre-apply and runtime validation sequence.

## 9. Pre-apply checklist

- [ ] Confirm the two ECR digests still exist in the expected repositories/region.
- [ ] Confirm the two S3 bucket names against applied Terraform outputs.
- [ ] Confirm the `mini-write-staging-secrets` object will be provisioned securely with the required keys through the agreed Stage 4.3 mechanism.
- [ ] Confirm node security groups permit Pod egress to RDS TCP 5432, Redis TCP 6379, and S3 HTTPS, and that return paths/DNS are valid.
- [ ] Render and schema-validate the manifests.
- [ ] Review rendered YAML before applying.

**Status:** manifest files authored with the supplied image digests and endpoint values. No live Kubernetes resources were applied by this package-generation step.
