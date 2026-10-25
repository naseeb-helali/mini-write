# Artifact Management

## 1. Purpose

Artifact management preserves the relationship between source revision, built container images, release request, deployed workload, and rollback target. The central principle is that deployment should use a known artifact identity rather than rebuild or resolve a mutable tag during promotion.

## 2. Artifact lifecycle

```text
Source revision
      |
      v
CI validation and build
      |
      v
API / Worker container images
      |
      v
SHA-based registry tags
      |
      v
Manifest + image digests
      |
      v
Promotion eligibility
      |
      v
Deployment and runtime verification
      |
      +----> Successful release evidence
      |
      +----> Previous known-good artifact for rollback
```

## 3. Identity model

The project uses source SHA tags and image digests. A tag is a human-usable reference; a digest identifies the exact image content. Release and rollback workflows validate artifact identity and, for Kubernetes, compare the running container `imageID` digest against the expected digest.

This is stronger than deploying a floating `latest` tag because the promoted artifact is pinned to a specific image identity.

## 4. Artifact manifest

`ci/artifact-manifest.schema.json` describes the expected artifact manifest structure. The implementation performs custom Node.js validation against the expected structure; the presence of a JSON Schema file should not be described as proof that a standards-compliant JSON Schema engine validates the manifest.

The manifest is used as an input to downstream deployment and promotion logic. Its fields carry source/release identity and image references/digests as defined by the repository implementation.

## 5. Promotion

The shared promotion logic is under `ci/promotion/`. Kubernetes adds platform-specific eligibility checks under `ci/kubernetes/promotion/`.

Promotion validation checks that the release being promoted corresponds to the evidence and artifact identity expected by the target workflow. Kubernetes Production-stage promotion validates that Staging evidence and the promotion request refer to the same release, cluster, namespace, repositories, tags, and digests.

## 6. Runtime identity verification

Kubernetes deployment verification goes beyond checking the desired Deployment template. The helper inspects Deployment/ReplicaSet/Pod relationships and compares actual running container image IDs with the requested digest. It also checks generation and desired/updated/Ready/Available replica counts.

Application readiness is a separate gate. The workflow validates readiness probe configuration and Pod Ready/container Ready conditions. This is kubelet-mediated readiness, not an independent HTTP request issued from the GitHub runner.

The ECS adapter contains its own deployment verification implementation. Historical evidence records successful ECS deployment and rollback scenarios, but the current archived `verify.sh` has a shell syntax error found during static review. That defect must be resolved and revalidated before claiming the current adapter is fully verified.

## 7. Rollback artifact selection

Rollback resolves a previously successful release and uses its recorded artifact identity. Kubernetes rollback searches successful Kubernetes CD runs for prior Production-stage verification evidence, validates the evidence and digests, and reapplies the previous API and Worker digests.

The first Production-stage release cannot automatically roll back if no previous successful Production verification artifact exists. The resolver fails closed in that condition and requires operator recovery.

## 8. Evidence

The release artifact management evidence records positive identity/validation scenarios and rejection of a digest mismatch. It supports the use of artifact identity as a deployment control for the tested scenarios; it does not establish artifact signing, provenance attestations, or complete supply-chain security.

## 9. Source map

- `ci/artifact-manifest.schema.json`
- `ci/promotion/eligibility.sh`
- `ci/promotion/promote.sh`
- `ci/rollback/resolve.sh`, `validate.sh`, `execute.sh`
- `ci/deployment/lib/`
- `ci/deployment/adapters/aws-ecs/`
- `ci/kubernetes/deployment/`
- `ci/kubernetes/promotion/`
- `ci/kubernetes/rollback/`
- `evidence/release-artifact-management/`
- `evidence/kubernetes-ec2 evidence/`

---

**Document control**  
Repository baseline: `mini-write.zip` reviewed 2026-10-24.  
Status vocabulary and claim boundaries: see [Validation & Limitations](../06-engineering-evidence/validation-and-limitations.md) where applicable.
