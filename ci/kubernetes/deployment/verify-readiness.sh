#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# Helpers
# ============================================================================

die() {
  echo "KUBERNETES APPLICATION READINESS ERROR: $*" >&2
  exit 1
}


# ============================================================================
# Arguments
# ============================================================================

RUNTIME_FILE="${1:-deployment-output/runtime-verification.json}"
OUTPUT_FILE="${2:-deployment-output/readiness-verification.json}"


# ============================================================================
# Validate inputs
# ============================================================================

[[ -f "$RUNTIME_FILE" ]] \
  || die "Runtime verification evidence is missing: $RUNTIME_FILE"

mkdir -p "$(dirname "$OUTPUT_FILE")"


# ============================================================================
# Verify application readiness and write evidence
# ============================================================================

python3 - "$RUNTIME_FILE" "$OUTPUT_FILE" <<'PY'

import json
import sys
from datetime import datetime, timezone


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

def fail(message):
    raise SystemExit(f'APPLICATION READINESS FAILED: {message}')


# ----------------------------------------------------------------------------
# Load runtime verification evidence
# ----------------------------------------------------------------------------

with open(sys.argv[1], encoding='utf-8') as f:
    runtime = json.load(f)


# ----------------------------------------------------------------------------
# Validate runtime identity verification passed
# ----------------------------------------------------------------------------

if runtime.get('status') != 'passed' \
    or runtime.get('runtimeImageIdentity', {}).get('verified') is not True:
    fail('runtime identity verification has not passed')


# ----------------------------------------------------------------------------
# Validate per-service readiness evidence
# ----------------------------------------------------------------------------

services = {}

for name in ('api', 'worker'):

    dep = runtime.get('deployment', {}).get(name, {})

    # The endpoint path is read from the exact Deployment template snapshot
    # recorded by verify.sh in the per-container probe metadata below.

    pods = dep.get('pods', [])

    if not pods:
        fail(f'{name}: no current Pods were verified')

    for pod in pods:

        if pod.get('containerReady') is not True:
            fail(f'{name}: container is not Ready in Pod {pod.get("pod")}')

        if pod.get('podReadyCondition') != 'True':
            fail(f'{name}: Pod Ready condition is not True for {pod.get("pod")}')

        probe = pod.get('readinessProbe', {})
        http_get = probe.get('httpGet', {})

        if http_get.get('path') != '/health/ready':
            fail(f'{name}: readinessProbe must call /health/ready')

        if str(http_get.get('scheme', 'HTTP')).upper() != 'HTTP':
            fail(f'{name}: readinessProbe scheme is not HTTP')

        expected_port = {'api': 'http', 'worker': 'metrics'}[name]

        if http_get.get('port') != expected_port:
            fail(f'{name}: readinessProbe must use the {expected_port} container port')

    services[name] = {
        'verified': True,
        'endpointPath': '/health/ready',
        'method': 'kubelet-readiness-probe',
        'pods': [
            {
                'pod': p['pod'],
                'containerReady': p['containerReady'],
                'podReadyCondition': p['podReadyCondition'],
            }
            for p in pods
        ],
    }


# ----------------------------------------------------------------------------
# Build result
# ----------------------------------------------------------------------------

result = {
    'schemaVersion': '1.0',
    'project': 'mini-write',
    'status': 'passed',
    'method': 'kubelet-readiness-probe',
    'endpointPath': '/health/ready',
    'api': services['api'],
    'worker': services['worker'],
    'timestamp': datetime.now(timezone.utc).isoformat(),
}


# ----------------------------------------------------------------------------
# Write result
# ----------------------------------------------------------------------------

with open(sys.argv[2], 'w', encoding='utf-8') as f:
    json.dump(result, f, indent=2)
    f.write('\n')

print(json.dumps(result, indent=2))

PY


# ============================================================================
# Report
# ============================================================================

echo "Application readiness verified through the API and Worker Kubernetes readiness probes."