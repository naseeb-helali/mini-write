#!/usr/bin/env bash
set -euo pipefail


# ============================================================================
# Helpers
# ============================================================================

die() {
  echo "KUBERNETES ROLLBACK VALIDATION ERROR: $*" >&2
  exit 1
}


# ============================================================================
# Validate inputs
# ============================================================================

: "${FAILED_SOURCE_SHA:?FAILED_SOURCE_SHA is required}"
: "${TARGET_SOURCE_SHA:?TARGET_SOURCE_SHA is required}"
: "${ROLLBACK_EVIDENCE:?ROLLBACK_EVIDENCE is required}"

[[ -f "$ROLLBACK_EVIDENCE" ]] \
  || die "Rollback evidence not found"


# ============================================================================
# Validate rollback target evidence
# ============================================================================

python3 - <<'PY'

import json
import os
import re


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

def require(ok, msg):
    if not ok:
        raise SystemExit(f'ROLLBACK VALIDATION FAILED: {msg}')


# ----------------------------------------------------------------------------
# Load evidence
# ----------------------------------------------------------------------------

with open(os.environ['ROLLBACK_EVIDENCE'], encoding='utf-8') as f:
    ev = json.load(f)


# ----------------------------------------------------------------------------
# Local constants
# ----------------------------------------------------------------------------

failed = os.environ['FAILED_SOURCE_SHA']
target = os.environ['TARGET_SOURCE_SHA']

sha = re.compile(r'^[0-9a-f]{40}$')
digest = re.compile(r'^sha256:[0-9a-f]{64}$')


# ----------------------------------------------------------------------------
# Validate SHAs
# ----------------------------------------------------------------------------

require(sha.fullmatch(failed) is not None, 'invalid failed SHA')
require(sha.fullmatch(target) is not None, 'invalid target SHA')
require(target != failed, 'rollback target equals failed release')


# ----------------------------------------------------------------------------
# Validate evidence identity
# ----------------------------------------------------------------------------

require(ev.get('schemaVersion') == '1.0', 'invalid evidence schema')
require(ev.get('project') == 'mini-write', 'invalid project')
require(ev.get('gate') == 'production-verification', 'not Production verification evidence')
require(ev.get('status') == 'passed', 'previous release did not pass verification')
require(ev.get('environment') == 'production', 'evidence is not Production')


# ----------------------------------------------------------------------------
# Validate deployment target
# ----------------------------------------------------------------------------

d = ev.get('deployment', {})

require(d.get('target') == 'kubernetes-ec2', 'evidence is not Kubernetes EC2')
require(
    d.get('cluster') == os.environ.get('K8S_CLUSTER_NAME', 'mini-write-staging-k8s'),
    'unexpected cluster',
)
require(
    d.get('namespace') == os.environ.get('K8S_NAMESPACE', 'mini-write-staging'),
    'unexpected namespace',
)


# ----------------------------------------------------------------------------
# Validate release identity
# ----------------------------------------------------------------------------

r = ev.get('release', {})

require(r.get('source') == target, 'target source SHA mismatch')
require(r.get('id') == target, 'target release ID mismatch')


# ----------------------------------------------------------------------------
# Validate evidence flags
# ----------------------------------------------------------------------------

flags = ev.get('evidence', {})

for key in (
    'artifactIdentityVerified',
    'runtimeImageIdentityVerified',
    'applicationReadinessVerified',
    'rolloutVerified',
):
    require(flags.get(key) is True, f'previous Production evidence lacks {key}')


# ----------------------------------------------------------------------------
# Validate per-service artifact and runtime identity
# ----------------------------------------------------------------------------

a = ev.get('artifact', {})

expected = {
    'api': f"{os.environ.get('AWS_ACCOUNT_ID', '496494570164')}.dkr.ecr.{os.environ.get('AWS_REGION', 'us-east-1')}.amazonaws.com/mini-write-api",
    'worker': f"{os.environ.get('AWS_ACCOUNT_ID', '496494570164')}.dkr.ecr.{os.environ.get('AWS_REGION', 'us-east-1')}.amazonaws.com/mini-write-worker",
}

for s in ('api', 'worker'):

    item = a.get(s, {})

    require(item.get('name') == expected[s], f'{s} repository mismatch')
    require(item.get('tag') == target, f'{s} tag mismatch')
    require(
        isinstance(item.get('digest'), str) and digest.fullmatch(item['digest']),
        f'{s} digest invalid',
    )

    service = d.get(s, {})

    require(
        service.get('deploymentImage') == f"{item['name']}@{item['digest']}",
        f'{s} deployment image mismatch',
    )

    pods = service.get('pods', [])

    require(
        len(pods) == service.get('desiredReplicas'),
        f'{s} pod count mismatch',
    )

    for pod in pods:

        require(
            pod.get('actualDigest') == item['digest'],
            f'{s} actual Pod digest mismatch',
        )

        require(
            pod.get('containerReady') is True and pod.get('podReadyCondition') == 'True',
            f'{s} Pod readiness mismatch',
        )

        require(
            pod.get('readinessProbe', {}).get('httpGet', {}).get('path') == '/health/ready',
            f'{s} readiness probe path mismatch',
        )

        require(
            pod.get('readinessProbe', {}).get('httpGet', {}).get('port')
                == {'api': 'http', 'worker': 'metrics'}[s],
            f'{s} readiness probe port mismatch',
        )


# ----------------------------------------------------------------------------
# Report
# ----------------------------------------------------------------------------

print('KUBERNETES ROLLBACK TARGET VALIDATED')
print(f'Failed release: {failed}\nTarget release: {target}')

for s in ('api', 'worker'):
    print(f"{s}: {a[s]['name']}@{a[s]['digest']}")

PY