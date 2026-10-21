#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# Helpers
# ============================================================================

die() {
  echo "KUBERNETES RUNTIME VERIFICATION ERROR: $*" >&2
  exit 1
}


# ============================================================================
# Defaults
# ============================================================================

REQUEST=""

OUTPUT_DIR="${DEPLOYMENT_OUTPUT_DIR:-deployment-output}"
NAMESPACE="${K8S_NAMESPACE:-mini-write-staging}"
ROLLOUT_TIMEOUT="${K8S_ROLLOUT_TIMEOUT:-300s}"


# ============================================================================
# Argument parsing
# ============================================================================

while [[ $# -gt 0 ]]; do
  case "$1" in

    --request)
      [[ $# -ge 2 ]] || die "--request requires a value"
      REQUEST="$2"
      shift 2
      ;;

    --output-dir)
      [[ $# -ge 2 ]] || die "--output-dir requires a value"
      OUTPUT_DIR="$2"
      shift 2
      ;;

    --help)
      echo "Usage: $0 --request <request.json> [--output-dir <dir>]"
      exit 0
      ;;

    *)
      die "Unknown argument: $1"
      ;;

  esac
done


# ============================================================================
# Validate inputs
# ============================================================================

[[ -f "$REQUEST" ]] \
  || die "Deployment request not found"

for c in kubectl jq python3; do
  command -v "$c" >/dev/null 2>&1 || die "$c is required"
done

: "${KUBECONFIG:?KUBECONFIG must point to deployer kubeconfig}"
: "${DEPLOYMENT_TARGET:?DEPLOYMENT_TARGET is required}"

[[ "$DEPLOYMENT_TARGET" == kubernetes-ec2 ]] \
  || die "Unexpected deployment target: $DEPLOYMENT_TARGET"

mkdir -p "$OUTPUT_DIR"


# ============================================================================
# Wait for rollout
# ============================================================================

for deployment in api worker; do
  echo "Waiting for ${deployment} rollout."
  kubectl -n "$NAMESPACE" rollout status "deployment/${deployment}" \
    --timeout="$ROLLOUT_TIMEOUT"
done


# ============================================================================
# Snapshot cluster state
# ============================================================================

kubectl -n "$NAMESPACE" get deployments api worker -o json \
  > "$OUTPUT_DIR/deployment.json"

kubectl -n "$NAMESPACE" get replicasets -o json \
  > "$OUTPUT_DIR/replicasets.json"

kubectl -n "$NAMESPACE" get pods -o json \
  > "$OUTPUT_DIR/pods.json"


# ============================================================================
# Verify rollout, replica sets, and actual Pod image identity
# ============================================================================

python3 - \
  "$REQUEST" \
  "$OUTPUT_DIR/deployment.json" \
  "$OUTPUT_DIR/replicasets.json" \
  "$OUTPUT_DIR/pods.json" \
  "$OUTPUT_DIR/runtime-verification.json" \
  "$NAMESPACE" \
  "${K8S_CLUSTER_NAME:-mini-write-staging-k8s}" \
  <<'PY'

import json
import re
import sys
from datetime import datetime, timezone


# ----------------------------------------------------------------------------
# Positional arguments
# ----------------------------------------------------------------------------

(
    request_path,
    deployments_path,
    replicasets_path,
    pods_path,
    output_path,
    namespace,
    cluster,
) = sys.argv[1:]


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

def fail(message):
    raise SystemExit(f'KUBERNETES RUNTIME VERIFICATION FAILED: {message}')


# ----------------------------------------------------------------------------
# Load snapshots
# ----------------------------------------------------------------------------

with open(request_path, encoding='utf-8') as f:
    req = json.load(f)

with open(deployments_path, encoding='utf-8') as f:
    deployments = json.load(f)

with open(replicasets_path, encoding='utf-8') as f:
    replicasets = json.load(f)

with open(pods_path, encoding='utf-8') as f:
    pods = json.load(f)


# ----------------------------------------------------------------------------
# Validate request
# ----------------------------------------------------------------------------

if req.get('schemaVersion') != '1.0' or req.get('project') != 'mini-write':
    fail('invalid deployment request')

source = req.get('release', {}).get('source')

if not isinstance(source, str) \
    or not re.fullmatch(r'[0-9a-f]{40}', source) \
    or req.get('release', {}).get('id') != source:
    fail('invalid source SHA or release identity')


# ----------------------------------------------------------------------------
# Validate deployment snapshot shape
# ----------------------------------------------------------------------------

items = {x.get('metadata', {}).get('name'): x for x in deployments.get('items', [])}

if set(items) != {'api', 'worker'}:
    fail('Deployment snapshot must contain exactly API and Worker')

rs_items = replicasets.get('items', [])
pod_items = pods.get('items', [])


# ----------------------------------------------------------------------------
# Verify each service
# ----------------------------------------------------------------------------

services = {}

for name in ('api', 'worker'):

    art = req.get('artifacts', {}).get(name, {})

    expected_repo = art.get('name')
    expected_digest = art.get('digest')
    expected_image = f'{expected_repo}@{expected_digest}'

    if art.get('tag') != source:
        fail(f'{name}: artifact tag does not match source SHA')

    if not isinstance(expected_repo, str) \
        or not re.fullmatch(r'[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/mini-write-' + name, expected_repo):
        fail(f'{name}: unexpected repository')

    if not isinstance(expected_digest, str) \
        or not re.fullmatch(r'sha256:[0-9a-f]{64}', expected_digest):
        fail(f'{name}: invalid expected digest')

    dep = items[name]
    meta = dep.get('metadata', {})
    spec = dep.get('spec', {})
    status = dep.get('status', {})

    containers = spec.get('template', {}).get('spec', {}).get('containers', [])

    if len(containers) != 1:
        fail(f'{name}: expected exactly one application container')

    container_name = containers[0].get('name')

    if containers[0].get('image') != expected_image:
        fail(f'{name}: Deployment template image mismatch')

    desired = spec.get('replicas', 1)

    if not isinstance(desired, int) or desired < 1:
        fail(f'{name}: invalid desired replica count')

    if status.get('observedGeneration', 0) < meta.get('generation', 0):
        fail(f'{name}: controller has not observed current generation')

    for key in ('replicas', 'updatedReplicas', 'readyReplicas', 'availableReplicas'):
        if status.get(key, 0) != desired:
            fail(f'{name}: {key}={status.get(key, 0)} does not equal desired={desired}')

    # ---- Current ReplicaSet for the requested image -------------------------

    matching_rs = []

    for rs in rs_items:
        owner = next(
            (
                o
                for o in rs.get('metadata', {}).get('ownerReferences', [])
                if o.get('kind') == 'Deployment' and o.get('uid') == meta.get('uid')
            ),
            None,
        )

        rs_containers = rs.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])

        if owner \
            and len(rs_containers) == 1 \
            and rs_containers[0].get('image') == expected_image \
            and rs.get('spec', {}).get('replicas', 0) == desired:
            matching_rs.append(rs)

    if len(matching_rs) != 1:
        fail(f'{name}: expected exactly one current ReplicaSet for requested image; found {len(matching_rs)}')

    rs = matching_rs[0]
    rs_uid = rs.get('metadata', {}).get('uid')

    if rs.get('spec', {}).get('replicas', 0) != desired \
        or rs.get('status', {}).get('readyReplicas', 0) != desired:
        fail(f'{name}: current ReplicaSet is not fully ready')

    # ---- Active Pods owned by the current ReplicaSet ------------------------

    current_pods = []

    for pod in pod_items:
        owner = next(
            (
                o
                for o in pod.get('metadata', {}).get('ownerReferences', [])
                if o.get('kind') == 'ReplicaSet' and o.get('uid') == rs_uid
            ),
            None,
        )

        if owner and not pod.get('metadata', {}).get('deletionTimestamp'):
            current_pods.append(pod)

    if len(current_pods) != desired:
        fail(f'{name}: current ReplicaSet has {len(current_pods)} active Pods; expected {desired}')

    # ---- Per-Pod runtime image identity -------------------------------------

    pod_evidence = []

    for pod in current_pods:

        pod_meta = pod.get('metadata', {})
        pod_spec = pod.get('spec', {})
        pod_status = pod.get('status', {})
        pod_containers = pod_spec.get('containers', [])

        if len(pod_containers) != 1 or pod_containers[0].get('image') != expected_image:
            fail(f'{name}: Pod {pod_meta.get("name")} spec image mismatch')

        cstatus = next(
            (
                c
                for c in pod_status.get('containerStatuses', [])
                if c.get('name') == container_name
            ),
            None,
        )

        if not cstatus:
            fail(f'{name}: Pod {pod_meta.get("name")} has no status for container {container_name}')

        image_id = cstatus.get('imageID', '')
        matches = re.findall(r'sha256:[0-9a-f]{64}', image_id)

        if not matches or matches[-1] != expected_digest:
            fail(f'{name}: actual Pod imageID digest mismatch for {pod_meta.get("name")}: {image_id}')

        pod_evidence.append({
            'pod': pod_meta.get('name'),
            'replicaSet': rs.get('metadata', {}).get('name'),
            'container': container_name,
            'specImage': pod_containers[0].get('image'),
            'imageID': image_id,
            'actualDigest': matches[-1],
            'containerReady': bool(cstatus.get('ready')),
            'podReadyCondition': next(
                (
                    c.get('status')
                    for c in pod_status.get('conditions', [])
                    if c.get('type') == 'Ready'
                ),
                'Unknown',
            ),
            'readinessProbe': containers[0].get('readinessProbe', {}),
        })

    # ---- Service evidence ---------------------------------------------------

    services[name] = {
        'deployment': name,
        'deploymentImage': expected_image,
        'generation': meta.get('generation'),
        'observedGeneration': status.get('observedGeneration'),
        'desiredReplicas': desired,
        'updatedReplicas': status.get('updatedReplicas', 0),
        'readyReplicas': status.get('readyReplicas', 0),
        'availableReplicas': status.get('availableReplicas', 0),
        'replicaSet': rs.get('metadata', {}).get('name'),
        'pods': pod_evidence,
    }


# ----------------------------------------------------------------------------
# Build evidence
# ----------------------------------------------------------------------------

evidence = {
    'schemaVersion': '1.0',
    'project': 'mini-write',
    'status': 'passed',
    'release': {
        'source': source,
        'id': req.get('release', {}).get('id'),
    },
    'deployment': {
        'target': 'kubernetes-ec2',
        'cluster': cluster,
        'namespace': namespace,
        'api': services['api'],
        'worker': services['worker'],
    },
    'runtimeImageIdentity': {
        'verified': True,
        'method': 'Pod status.containerStatuses[].imageID digest comparison',
    },
    'timestamp': datetime.now(timezone.utc).isoformat(),
}


# ----------------------------------------------------------------------------
# Write evidence
# ----------------------------------------------------------------------------

with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(evidence, f, indent=2)
    f.write('\n')

print(json.dumps(evidence, indent=2))

PY


# ============================================================================
# Report
# ============================================================================

echo "Kubernetes rollout and actual running Pod image digest verification passed."