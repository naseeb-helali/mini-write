# AWS ECS Deployment

## 1. Deployment model

The ECS path runs the API and Worker as ECS workloads using container images stored in ECR. Terraform defines the ECS infrastructure and related AWS resources. The CD workflow invokes the ECS deployment adapter to apply a release artifact and verify the resulting service state.

## 2. Infrastructure dependencies

The ECS path depends on the Staging AWS infrastructure, including VPC/networking, load balancer, ECS resources, ECR repositories, RDS PostgreSQL, Valkey, S3, Secrets Manager, and IAM permissions as defined in Terraform.

The ALB is the external request entry point. ECS task definitions specify container image references, environment/configuration, ports, and health behavior. The API and Worker are separate services with different runtime responsibilities.

## 3. Delivery flow

```text
CI image build and push
        |
        v
Artifact manifest + digests
        |
        v
ECS deployment adapter
        |
        v
Update ECS task/service image identity
        |
        v
Wait for service convergence / health
        |
        v
Record deployment result
        |
        +---- success
        |
        +---- failure -> rollback to prior known state
```

The adapter scripts under `ci/deployment/adapters/aws-ecs/` implement deploy, verify, and rollback operations. Shared libraries under `ci/deployment/lib/` provide common request and state handling.

## 4. Historical evidence

The deployment recovery closure and benchmark record the following tested results:

| Scenario | Recorded duration |
|---|---:|
| ECS Staging deployment | 215 seconds |
| ECS rollback | 182 seconds |

The evidence also records controlled deployment failure and rollback verification. These are historical measurements for the recorded environment and test scenarios; they are not SLAs or guaranteed future durations.

## 5. Current source validation issue

Static review of the supplied archive found a shell syntax error in:

`ci/deployment/adapters/aws-ecs/verify.sh`

The `bash -n` validation failed for this file. The historical evidence remains evidence that the recorded scenarios were executed at the time of capture, but it does not prove that the current archived adapter source passes syntax validation.

Before describing the current ECS adapter as fully validated, correct the syntax defect and rerun shell validation and the relevant deployment verification path. This documentation records the issue rather than silently treating historical evidence as current-source proof.

## 6. Registry identity

The release workflow is intended to deploy immutable image identity from CI rather than rely on mutable tags. The Terraform task definition bootstrap references `latest` in the reviewed source, while the CI delivery path publishes SHA-tagged images. Check first provisioning behavior and ensure the initial task image reference is aligned with the artifact publication contract.

## 7. Shared data-plane consideration

ECS and Kubernetes-on-EC2 use shared AWS Staging data services in the reviewed Terraform environment. If both compute platforms are active, they may access the same database, cache/queue, and object storage. This is an operational coupling, not full platform isolation.

## 8. Security and operations

The ECS deployment depends on IAM permissions for the runner/workflow, ECR access, network reachability, and secrets/configuration. The infrastructure and security documents describe those controls. The current archive does not justify a blanket least-privilege or compliance claim.

## 9. Source map

- `.github/workflows/cd.yml`
- `infra/terraform/environments/staging/ecs.tf`
- `infra/terraform/environments/staging/alb.tf`
- `infra/terraform/modules/ecs/`
- `infra/terraform/modules/alb/`
- `ci/deployment/adapters/aws-ecs/`
- `ci/deployment/lib/`
- `evidence/deployment-recovery/`
- `evidence/release-artifact-management/`

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../../06-engineering-evidence/validation-and-limitations.md) where applicable.
