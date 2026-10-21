#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# Helpers
# ============================================================================

die() {
  echo "KUBERNETES EVIDENCE ERROR: $*" >&2
  exit 1
}


# ============================================================================
# Defaults
# ============================================================================

REQUEST=""

DEPLOYMENT_FILE="${DEPLOYMENT_OUTPUT_DIR:-deployment-output}/deployment.json"
RUNTIME_FILE="${DEPLOYMENT_OUTPUT_DIR:-deployment-output}/runtime-verification.json"
READINESS_FILE="${DEPLOYMENT_OUTPUT_DIR:-deployment-output}/readiness-verification.json"

OUTPUT="${EVIDENCE_OUTPUT:-evidence/evidence.json}"


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

    --deployment-file)
      [[ $# -ge 2 ]] || die "--deployment-file requires a value"
      DEPLOYMENT_FILE="$2"
      shift 2
      ;;

    --runtime-file)
      [[ $# -ge 2 ]] || die "--runtime-file requires a value"
      RUNTIME_FILE="$2"
      shift 2
      ;;

    --readiness-file)
      [[ $# -ge 2 ]] || die "--readiness-file requires a value"
      READINESS_FILE="$2"
      shift 2
      ;;

    --output)
      [[ $# -ge 2 ]] || die "--output requires a value"
      OUTPUT="$2"
      shift 2
      ;;

    --help)
      echo "Usage: $0 --request <request.json> [--deployment-file <deployment.json>] [--runtime-file <runtime-verification.json>] [--readiness-file <readiness-verification.json>] [--output <evidence.json>]"
      exit 0
      ;;

    *)
      die "Unknown argument: $1"
      ;;

  esac
done


# ============================================================================
# Validate inputs exist
# ============================================================================

for file in "$REQUEST" "$DEPLOYMENT_FILE" "$RUNTIME_FILE" "$READINESS_FILE"; do
  [[ -f "$file" ]] || die "Required verification input missing: $file"
done

mkdir -p "$(dirname "$OUTPUT")"


# ============================================================================
# Export inputs for the Python verifier
# ============================================================================

export REQUEST DEPLOYMENT_FILE RUNTIME_FILE READINESS_FILE OUTPUT

export EVIDENCE_ENVIRONMENT="${EVIDENCE_ENVIRONMENT:-staging}"
export EVIDENCE_GATE="${EVIDENCE_GATE:-promotion-eligibility}"

export STARTED_AT="${DEPLOYMENT_STARTED_AT:-}"
export COMPLETED_AT="${DEPLOYMENT_COMPLETED_AT:-}"
export DURATION="${DEPLOYMENT_DURATION_SECONDS:-0}"

export NAMESPACE="${K8S_NAMESPACE:-mini-write-staging}"
export CLUSTER="${K8S_CLUSTER_NAME:-mini-write-staging-k8s}"


# ============================================================================
# Verify inputs and write evidence
# ============================================================================

python3 - <<'PY'

import json
import os
import re
from datetime import datetime, timezone


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

def fail(s):
    raise SystemExit(f'EVIDENCE ERROR: {s}')


# ----------------------------------------------------------------------------
# Load inputs
# ----------------------------------------------------------------------------

with open(os.environ['REQUEST'], encoding='utf-8') as f:
    req = json.load(f)

with open(os.environ['DEPLOYMENT_FILE'], encoding='utf-8') as f:
    snap = json.load(f)

with open(os.environ['RUNTIME_FILE'], encoding='utf-8') as f:
    runtime = json.load(f)

with open(os.environ['READINESS_FILE'], encoding='utf-8') as f:
    readiness = json.load(f)


# ----------------------------------------------------------------------------
# Validate deployment snapshot shape
# ----------------------------------------------------------------------------

items = {x.get('metadata', {}).get('name'): x for x in snap.get('items', [])}

if set(items) != {'api', 'worker'}:
    fail('Deployment snapshot must contain API and Worker')


# ----------------------------------------------------------------------------
# Validate release identity
# ----------------------------------------------------------------------------

release = req.get('release', {})
source = release.get('source')
rid = release.get('id')

if not isinstance(source, str) or not re.fullmatch(r'[0-9a-f]{40}', source) or rid != source:
    fail('Invalid release identity')


# ----------------------------------------------------------------------------
# Validate runtime + readiness evidence
# ----------------------------------------------------------------------------

if runtime.get('status') != 'passed' or runtime.get('runtimeImageIdentity', {}).get('verified') is not True:
    fail('Actual Pod image identity verification has not passed')

if readiness.get('status') != 'passed' or readiness.get('method') != 'kubelet-readiness-probe':
    fail('Application readiness verification has not passed')

if runtime.get('deployment', {}).get('cluster') != os.environ['CLUSTER'] \
    or runtime.get('deployment', {}).get('namespace') != os.environ['NAMESPACE']:
    fail('Runtime verification target mismatch')

if readiness.get('endpointPath') != '/health/ready':
    fail('Unexpected application readiness endpoint')


# ----------------------------------------------------------------------------
# Validate per-service state
# ----------------------------------------------------------------------------

artifacts = req.get('artifacts', {})
services = {}

for name in ('api', 'worker'):

    art = artifacts.get(name, {})

    if not isinstance(art.get('digest'), str) or not re.fullmatch(r'sha256:[0-9a-f]{64}', art['digest']):
        fail(f'Invalid {name} digest')

    if art.get('tag') != source:
        fail(f'{name} tag does not match source SHA')

    image = items[name].get('spec', {}).get('template', {}).get('spec', {}).get('containers', [{}])[0].get('image')

    if items[name].get('metadata', {}).get('namespace') != os.environ['NAMESPACE']:
        fail(f'{name} Deployment is in an unexpected namespace')

    if image != f"{art.get('name')}@{art.get('digest')}":
        fail(f'{name} Deployment template image differs from request')

    status = items[name].get('status', {})
    spec = items[name].get('spec', {})

    if status.get('observedGeneration', 0) < items[name].get('metadata', {}).get('generation', 0):
        fail(f'{name} generation not observed')

    desired = spec.get('replicas', 1)

    if status.get('updatedReplicas', 0) != desired \
        or status.get('readyReplicas', 0) != desired \
        or status.get('availableReplicas', 0) != desired:
        fail(f'{name} is not fully updated, Ready, and Available')

    runtime_service = runtime.get('deployment', {}).get(name, {})

    if runtime_service.get('deploymentImage') != image:
        fail(f'{name} runtime image evidence mismatch')

    pods = runtime_service.get('pods', [])

    if len(pods) != desired:
        fail(f'{name} actual Pod count mismatch')

    for pod in pods:
        if pod.get('actualDigest') != art['digest']:
            fail(f'{name} actual Pod digest mismatch')
        if pod.get('containerReady') is not True or pod.get('podReadyCondition') != 'True':
            fail(f'{name} Pod readiness mismatch')

    ready_service = readiness.get(name, {})

    if ready_service.get('verified') is not True:
        fail(f'{name} application readiness not verified')

    services[name] = {
        'deployment': name,
        'image': image,
        'deploymentImage': image,
        'generation': items[name]['metadata'].get('generation'),
        'observedGeneration': status.get('observedGeneration'),
        'desiredReplicas': desired,
        'updatedReplicas': status.get('updatedReplicas', 0),
        'readyReplicas': status.get('readyReplicas', 0),
        'availableReplicas': status.get('availableReplicas', 0),
        'replicaSet': runtime_service.get('replicaSet'),
        'pods': runtime_service.get('pods'),
    }


# ----------------------------------------------------------------------------
# Validate evidence environment and gate
# ----------------------------------------------------------------------------

env = os.environ['EVIDENCE_ENVIRONMENT']
gate = os.environ['EVIDENCE_GATE']

if env not in ('staging', 'production', 'rollback'):
    fail('Unsupported evidence environment')

if gate not in ('promotion-eligibility', 'production-verification', 'rollback-verification'):
    fail('Unsupported evidence gate')

if (env == 'staging' and gate != 'promotion-eligibility') \
    or (env == 'production' and gate != 'production-verification') \
    or (env == 'rollback' and gate != 'rollback-verification'):
    fail('Environment and evidence gate do not match')


# ----------------------------------------------------------------------------
# Build evidence
# ----------------------------------------------------------------------------

duration = int(os.environ.get('DURATION') or 0)

evidence = {
    'schemaVersion': '1.0',
    'project': 'mini-write',
    'gate': gate,
    'status': 'passed',
    'environment': 'production' if env in ('production', 'rollback') else 'staging',
    'release': {
        'id': rid,
        'source': source,
        'version': release.get('version', f'sha-{source[:12]}'),
    },
    'artifact': {
        s: {
            'name': artifacts[s]['name'],
            'tag': artifacts[s]['tag'],
            'digest': artifacts[s]['digest'],
        }
        for s in ('api', 'worker')
    },
    'deployment': {
        'target': 'kubernetes-ec2',
        'cluster': os.environ['CLUSTER'],
        'namespace': os.environ['NAMESPACE'],
        'api': services['api'],
        'worker': services['worker'],
    },
    'deploymentTiming': {
        'startedAt': os.environ.get('STARTED_AT') or None,
        'completedAt': os.environ.get('COMPLETED_AT') or datetime.now(timezone.utc).isoformat(),
        'durationSeconds': duration,
    },
    'evidence': {
        'stagingDeployed': env == 'staging',
        'stagingVerified': env == 'staging',
        'artifactIdentityVerified': True,
        'runtimeImageIdentityVerified': True,
        'applicationReadinessVerified': True,
        'rolloutVerified': True,
    },
    'verificationMethods': {
        'runtimeImageIdentity': 'Pod status.containerStatuses[].imageID digest comparison',
        'applicationReadiness': 'Kubernetes readinessProbe using HTTP GET /health/ready',
    },
    'evidenceReferences': {
        'githubActionsRunId': os.environ.get('GITHUB_RUN_ID') or None,
        'githubActionsRunUrl': (
            f"{os.environ['GITHUB_SERVER_URL']}/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
            if os.environ.get('GITHUB_RUN_ID') and os.environ.get('GITHUB_REPOSITORY')
            else None
        ),
    },
    'timestamp': datetime.now(timezone.utc).isoformat(),
}


# ----------------------------------------------------------------------------
# Rollback-specific evidence
# ----------------------------------------------------------------------------

if env == 'rollback':

    rollback = req.get('rollback', {})
    failed = rollback.get('failedRelease', {})
    target = rollback.get('targetRelease', {})

    if not isinstance(failed.get('source'), str) \
        or not re.fullmatch(r'[0-9a-f]{40}', failed['source']) \
        or failed.get('source') == source \
        or target.get('source') != source \
        or target.get('id') != source:
        fail('Rollback request identity is incomplete or inconsistent')

    evidence['rollback'] = {
        'failedRelease': failed,
        'targetRelease': target,
    }

    evidence['rollbackTiming'] = {
        'startedAt': os.environ.get('STARTED_AT') or None,
        'completedAt': os.environ.get('COMPLETED_AT') or datetime.now(timezone.utc).isoformat(),
        'durationSeconds': duration,
    }


# ----------------------------------------------------------------------------
# Write evidence
# ----------------------------------------------------------------------------

with open(os.environ['OUTPUT'], 'w', encoding='utf-8') as f:
    json.dump(evidence, f, indent=2)
    f.write('\n')

print(json.dumps(evidence, indent=2))

PY


# ============================================================================
# Verify evidence is valid JSON
# ============================================================================

jq empty "$OUTPUT"