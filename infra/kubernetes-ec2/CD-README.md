# Mini-Write Kubernetes CD

This is a Kubernetes-specific delivery path alongside the existing VM/ECS CD. It does not replace, edit, or reuse the old VM/ECS deployment adapters. The old `cd.yml`, `ci/deployment/`, VM adapters, ECS adapters, and existing shared promotion/rollback contracts remain untouched.

## 1. Event model and release flow

- Successful `Mini-Write CI` completion on `main`: resolve the CI run and deploy its existing artifact to Staging.
- Push of a `v*` tag: resolve the existing CI artifact, prove Kubernetes Staging eligibility, then enter the protected Production release path.
- Manual dispatch: choose `staging` or `production` and provide the source SHA whose existing CI artifact is to be deployed.
- No build, image rebuild, image push, or artifact regeneration occurs in this CD.

The CI artifact remains authoritative. Staging and Production consume the exact ECR image digests from the same manifest. Production does not rebuild or republish.

## 2. Responsibilities retained from the previous CD

| Previous CD responsibility / setting | Kubernetes implementation |
|---|---|
| Resolve source SHA for workflow_run, tag push, and manual dispatch | Preserved in `resolve-artifact` |
| Resolve successful CI run and its artifact | Preserved; exact artifact name is checked before selecting the run |
| Validate manifest schema, project, source, release, version, repository, tag, digest | `validate-artifact.sh` |
| Validate deployment target | `validate-target.sh`; requires `DEPLOYMENT_TARGET=kubernetes-ec2` |
| Validate environment configuration | `validate-target.sh` runs in Staging, Production, and Rollback |
| AWS credentials through GitHub OIDC | Preserved; assumed role is verified with STS |
| Registry access | ECR pull authentication is performed by EC2 nodes through the configured ECR credential provider |
| Build deployment request | Preserved for Staging and Production; rollback builds a rollback request from previous Production evidence |
| Deployment timer and duration evidence | Preserved for Staging, Production, and Rollback |
| Deploy and verify adapters | Kubernetes deployment, runtime-identity, and readiness helpers |
| Staging promotion evidence | Preserved and strengthened with actual Pod image IDs and readiness evidence |
| Production eligibility | Finds only successful runs of `kubernetes-cd.yml` and validates the unique Kubernetes Staging artifact |
| Promotion authorization | Existing `ci/promotion/promote.sh` runs inside the protected Production job, after approval |
| Production Environment approval | Preserved |
| Production mutation boundary | Set immediately before `kubectl apply`; failure before this point does not trigger rollback |
| Resolve and validate previous known-good Production release | Kubernetes-only artifact namespace and rollback helpers |
| Rollback Environment approval | Preserved: rollback uses GitHub Environment `production`, as the old workflow did |
| Rollback timing and evidence | Preserved; includes restored image identities, Pod readiness, and duration |

## 3. Kubernetes-specific changes and why they are required

### Deployment target and cluster identity

The deployment target is fixed to `kubernetes-ec2`. The configuration validator requires the known staging cluster, namespace, private Control Plane EC2 instance, deployer kubeconfig path, AWS account, and region. The SSM tunnel connects only to the configured Control Plane instance and the deployer kubeconfig must use `https://localhost:6443`.

The validator also renders the workload Kustomize base and checks that it targets `mini-write-staging` and contains the API and Worker workloads. The cluster's API identity is anchored by the SSM target and the existing deployer kubeconfig/CA; the deployer Role is not expanded to read cluster-scoped kubeadm configuration or namespaces.

### Registry authentication

This cluster is intentionally ECR-only. Its EC2 nodes already use the ECR credential provider, so the Runner does not execute `amazon-ecr-login` or Docker login: the Runner sends Deployment objects to the Kubernetes API, while the nodes pull the images. `REGISTRY_TYPE` is validated as `ecr`, and both repositories are checked against the known account and region. GHCR is not enabled for this cluster because no GHCR node credential mechanism is configured.

### Runtime image identity

Checking `Deployment.spec.template` alone is insufficient. After rollout, `verify.sh` retrieves Deployments, ReplicaSets, and Pods using the existing namespace-scoped read permissions. It identifies the ReplicaSet owned by each Deployment for the requested image, follows its Pods, and compares each running container's `status.containerStatuses[].imageID` digest with the CI artifact digest. It also checks the observed Deployment generation and desired/updated/Ready/Available replica counts.

### Application readiness

The previous ECS adapter independently called `API_HEALTH_URL` using `curl` retries. The current Kubernetes runner path has no direct route to the private ClusterIP Service, and the deployer RBAC intentionally does not include `pods/portforward`, `pods/exec`, or broad proxy permissions. The Kubernetes equivalent therefore uses the actual workload `readinessProbe` and the Pod `Ready` condition as a separate verification gate. `verify-readiness.sh` checks that both API and Worker readiness probes use HTTP `/health/ready`, and that each current Pod and application container is Ready. This is an in-cluster kubelet probe, not a separate HTTP request from the Runner; evidence records that method explicitly.

### Concurrency

The previous CD used separate Staging and Production concurrency groups because those were separate deployment targets. This project decision uses one namespace and the same `api` and `worker` Deployments for both workflow stages. The new workflow therefore serializes the whole release transaction with one shared concurrency group. This also prevents another CD run from changing the shared workloads between a failed Production mutation and its rollback.

### Timeouts and protected environments

The old job timeouts are retained exactly:

- Staging: 20 minutes.
- Production: 30 minutes.
- Rollback: 30 minutes.

Both Production release and Production rollback use the protected GitHub Environment named `production`. This preserves the old approval behavior; rollback is not configured to bypass the Environment gate.

## 4. Helper files

```text
ci/kubernetes/
├── connection/
│   └── ssm-tunnel.sh
├── deployment/
│   ├── validate-target.sh
│   ├── validate-aws-identity.sh
│   ├── validate-artifact.sh
│   ├── deploy.sh
│   ├── verify.sh
│   ├── verify-readiness.sh
│   └── record-evidence.sh
├── promotion/
│   └── validate-staging-evidence.sh
└── rollback/
    ├── resolve.sh
    ├── validate.sh
    └── execute.sh
```

- `connection/ssm-tunnel.sh`: starts/stops SSM port forwarding to the private Kubernetes API; verifies `kubectl auth whoami` is `mini-write-deployer` and checks the namespace-scoped verbs required by deployment and verification.
- `deployment/validate-target.sh`: validates the Kubernetes target, ECR-only registry model, AWS/cluster/namespace/instance configuration, runner prerequisites, kubeconfig endpoint, and rendered workload namespace.
- `deployment/validate-aws-identity.sh`: confirms the assumed AWS role and account after OIDC.
- `deployment/validate-artifact.sh`: validates the original CI manifest and immutable ECR image identities.
- `deployment/deploy.sh`: adds the immutable digests to a temporary Kustomize copy and applies it. For Production, it writes `deployment-state/deployment-started.json` and marks the mutation boundary immediately before `kubectl apply`.
- `deployment/verify.sh`: verifies rollout, Deployment generation/replicas, current ReplicaSet, and actual running Pod `imageID` digests.
- `deployment/verify-readiness.sh`: separately validates API and Worker readiness probe configuration and current Pod Ready/container Ready states.
- `deployment/record-evidence.sh`: records Staging promotion, Production verification, or Rollback verification evidence only after all required checks passed.
- `promotion/validate-staging-evidence.sh`: validates that the Staging evidence and Promotion request refer to the same release, cluster, namespace, repositories, tags, and digests.
- `rollback/resolve.sh`: searches only successful Kubernetes CD runs for previous Production verification artifacts.
- `rollback/validate.sh`: validates the previous Production evidence, cluster/namespace, image repositories, digests, and verification flags.
- `rollback/execute.sh`: builds a rollback request from the previous Production evidence and applies both prior digests. The workflow then runs the same separate rollout/runtime-identity and application-readiness Gates, captures rollback timing, and records rollback evidence.

## 5. AWS and Kubernetes configuration

The Kubernetes workflow defines its own target configuration at workflow scope instead of changing the old VM/ECS GitHub Environment variables. This keeps the previous CD settings and deployment path independent. The workflow is deliberately bound to the already provisioned environment:

- AWS account: `496494570164`
- AWS region: `us-east-1`
- Deployment target: `kubernetes-ec2`
- Registry: ECR
- Cluster: `mini-write-staging-k8s`
- Namespace: `mini-write-staging`
- Control Plane instance: `i-0552c82b27dd23b29`
- Runner kubeconfig: `/home/janad/.kube/mini-write-deployer/kubeconfig`
- OIDC role: `arn:aws:iam::496494570164:role/mini-write-github-cd-runner`

The kubeconfig and its private key remain on the Runner. They are never printed, copied to the Control Plane, or uploaded as artifacts.

## 6. Evidence artifacts

- `mini-write-kubernetes-promotion-eligibility-<source-sha>` — 30 days.
- `mini-write-kubernetes-production-verification-<source-sha>` — 90 days.
- `mini-write-kubernetes-rollback-verification-<failed-sha>-<run-id>` — 90 days.

Evidence includes release and image identity, cluster and namespace, Deployment/ReplicaSet/Pod information, actual Pod image IDs, readiness method/results, deployment timing, and GitHub run references. Rollback evidence additionally records the failed release, restored target release, and a dedicated `rollbackTiming` object. The Staging and Production prefixes are unique to this workflow, so old VM/ECS CD evidence cannot satisfy the new Production eligibility or rollback lookups.

## 7. Single-namespace operating model

Staging and Production are workflow/release stages, not separate live workload environments. Both target `mini-write-staging/api` and `mini-write-staging/worker`. Production promotion reapplies the exact digests already verified in Staging. A Production rollback restores the previous verified Production digests in the same namespace and therefore also moves the shared Staging workloads backward.

## 8. RBAC and operational constraints

- No namespace creation or namespace-scoped RBAC expansion is performed.
- No cluster-admin, Pod exec, Pod port-forward, resource deletion, or broad Secret read permission is required.
- API currently uses `Recreate`; API downtime during replacement is expected under the supplied manifest strategy.
- Worker uses `RollingUpdate` with `maxSurge: 1`; old and new Worker Pods can overlap during rollout. Queue concurrency, idempotency, and graceful shutdown must be validated operationally.
- The first Production release cannot automatically roll back if there is no previous successful Kubernetes Production verification artifact. The resolver fails closed and requires operator recovery.
- The old VM/ECS workflow and helper files must remain untouched. Disable the old workflow before enabling this Kubernetes workflow, because the old and new workflows do not share a concurrency lock.

## 9. Validation performed for this package

Validation performed on this generated package:

- `bash -n` passed for every Kubernetes helper script.
- YAML parsing and structural assertions passed for all six jobs, the original 20/30/30-minute timeouts, Production and Rollback Environment gates, and Promotion Authorization ordering.
- Mocked Kubernetes fixture tests passed for Deployment/ReplicaSet/Pod image identity, readiness probes, Staging promotion evidence, Production verification evidence, rollback evidence, target configuration, CI artifact validation, the deploy adapter, the Production mutation marker, AWS assumed-role identity, and rollback request generation.

This is static and fixture-based validation, not a GitHub Actions execution or a live cluster deployment. The active local environment does not include `kubectl` or `actionlint`, so actual Kustomize rendering against the repository manifests, live Pod `imageID` inspection on containerd, SSM connectivity, and `kubectl apply` must be verified by the configured self-hosted Runner before enabling Production use.
