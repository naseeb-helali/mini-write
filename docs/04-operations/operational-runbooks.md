# Operational Runbooks

## 1. Purpose and use

This document provides project-specific operational workflows. It is intentionally limited to procedures supported by the repository. Before executing a procedure, confirm the target environment, current workflow version, credentials, and deployment state. Do not run state-changing commands against an environment merely because the command appears in an example.

## 2. Pre-deployment checks

Before any release:

1. Confirm the target platform (VM, ECS, or Kubernetes on EC2).
2. Confirm the source revision and artifact manifest.
3. Confirm API and Worker image tags/digests refer to the same intended release.
4. Confirm required registry and AWS identity access.
5. Confirm platform-specific configuration and secrets are available.
6. Confirm no conflicting deployment workflow is operating on the same target.
7. Confirm the previous known-good deployment state/evidence is available if rollback is expected.

## 3. CI failure triage

When CI fails:

1. Identify the failing workflow job and component (API or Worker).
2. Separate dependency installation, tests, coverage, audit, image build, and Trivy scan failures.
3. Inspect the relevant package lockfile and job logs.
4. Do not bypass a failed test or security step without understanding the failure and recording the reason.
5. Confirm whether the failure is source-related or runner/environment-related.

The current lint scripts are placeholders; do not treat a successful placeholder command as evidence of lint quality enforcement.

## 4. Terraform Staging change procedure

The infrastructure workflow is intended to separate planning and applying:

1. Review the Terraform source change.
2. Run the configured plan workflow and inspect proposed resource changes.
3. Confirm the target is Staging and the expected backend/workspace/state is selected.
4. Invoke apply only through the configured explicit workflow path.
5. Inspect apply output.
6. Run the post-apply plan/reconciliation step.
7. Confirm that no unexpected changes remain.

The retained infrastructure closure records a successful Staging apply followed by `No changes`. It does not imply that every future change is safe or that Production is provisioned.

## 5. VM deployment triage

For VM deployment failures:

1. Confirm the correct inventory and host connectivity.
2. Check the Ansible provisioning/runtime role status.
3. Confirm Docker daemon and Compose availability on the host.
4. Inspect rendered environment and Compose configuration without printing secret values.
5. Confirm API port mapping matches Nginx upstream and healthcheck configuration.
6. Inspect container status and logs.
7. Check Nginx upstream reachability and API `/health/ready` behavior.
8. Inspect deployment state and lock files before attempting rollback.

The VM deployment path has no dedicated retained runtime evidence package in the reviewed archive. Do not report an unrecorded timing or rollback outcome as evidence.

## 6. ECS deployment triage

For ECS deployment failures:

1. Confirm AWS account and region.
2. Confirm the workflow assumed the expected role.
3. Confirm ECR image digest and task definition image reference.
4. Inspect ECS service deployment state and task health.
5. Inspect task stopped reasons and CloudWatch logs.
6. Confirm ALB target health and security-group connectivity.
7. If recovery is required, resolve the previous known-good deployment state and follow the adapter rollback path.
8. Verify service convergence and health after rollback.

Important: the archived `ci/deployment/adapters/aws-ecs/verify.sh` fails shell syntax validation. Do not rely on manual invocation of the current archived script until corrected and revalidated.

## 7. Kubernetes deployment triage

For Kubernetes CD failures:

1. Confirm the self-hosted runner is online and has the required AWS CLI, Session Manager Plugin, and `kubectl` tooling.
2. Confirm the AWS OIDC identity and account.
3. Confirm SSM access to the configured control-plane instance.
4. Confirm the deployer kubeconfig is present on the runner and targets `https://localhost:6443` while the SSM tunnel is active.
5. Confirm `kubectl auth whoami` reports the expected deployer identity and the required namespace-scoped verbs are available.
6. Confirm the target cluster/namespace and rendered Kustomize workload configuration.
7. Confirm ECR repository and artifact digest validation.
8. Inspect Deployment generation, ReplicaSet ownership, Pod states, and actual container `imageID` digests.
9. Inspect API/Worker readiness probe results.
10. If deployment failed after the mutation boundary, use the workflow's rollback resolution and validation path.

The Kubernetes Production-stage workflow targets the same Staging cluster and namespace. Confirm this before treating a change as isolated to Production.

## 8. Secret synchronization

The Kubernetes secret helper retrieves values from AWS Secrets Manager and synchronizes Kubernetes Secret objects. Operational handling:

- Never echo secret values.
- Restrict access to the runner and temporary files.
- Confirm the expected secret names and namespace.
- Validate synchronization without exposing data.
- If values are consumed as environment variables, restart/roll out the workload so processes receive the new values.

Updating a Secret object alone does not refresh environment variables in existing Pods.

## 9. Rollback decision

Rollback should be used when a release fails required verification or introduces a material regression. The intended rollback source is the previous known-good artifact identity/evidence, not a newly rebuilt image or a mutable `latest` tag.

After rollback:

1. Verify the restored digest.
2. Verify desired/updated/ready replicas or platform-specific health.
3. Verify application readiness.
4. Record the failed release and restored release identity.
5. Preserve the evidence artifact for later analysis.

If no previous known-good Kubernetes Production-stage artifact exists, the automated resolver cannot provide one; operator recovery is required.

## 10. Operational safety

- Do not paste secret values into terminal transcripts or incident notes.
- Do not edit production-like resources manually while a workflow may be applying changes.
- Do not run both old VM/ECS CD and Kubernetes CD concurrently against shared targets; their concurrency locks are separate.
- Preserve state/evidence before cleanup.
- Verify the exact target before running any destructive operation.

## 11. Source map

- `.github/workflows/`
- `ci/deployment/`
- `ci/kubernetes/`
- `ci/rollback/`
- `infra/ansible/`
- `infra/kubernetes-ec2/ansible/`
- `infra/kubernetes-ec2/manifests/`
- `docs/troubleshooting/` (legacy reference material)
- `evidence/`

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
