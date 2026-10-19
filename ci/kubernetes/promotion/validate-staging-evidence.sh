#!/usr/bin/env bash
set -euo pipefail

die() { echo "PROMOTION ELIGIBILITY FAILED: $*" >&2; exit 1; }
EVIDENCE=""; REQUEST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --evidence) [[ $# -ge 2 ]] || die "--evidence requires a value"; EVIDENCE="$2"; shift 2 ;;
    --request) [[ $# -ge 2 ]] || die "--request requires a value"; REQUEST="$2"; shift 2 ;;
    --help) echo "Usage: $0 --evidence <promotion-evidence.json> --request <promotion-request.json>"; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
[[ -f "$EVIDENCE" && -f "$REQUEST" ]] || die "Evidence or promotion request missing"
python3 - "$EVIDENCE" "$REQUEST" "${K8S_CLUSTER_NAME:-mini-write-staging-k8s}" "${K8S_NAMESPACE:-mini-write-staging}" <<'PY'
import json, re, sys
with open(sys.argv[1],encoding='utf-8') as f: ev=json.load(f)
with open(sys.argv[2],encoding='utf-8') as f: req=json.load(f)
def require(ok,msg):
    if not ok: raise SystemExit(f'PROMOTION ELIGIBILITY FAILED: {msg}')
require(ev.get('schemaVersion')=='1.0','invalid schema')
require(ev.get('project')=='mini-write','invalid project')
require(ev.get('gate')=='promotion-eligibility','wrong evidence gate')
require(ev.get('status')=='passed','Staging evidence did not pass')
require(ev.get('environment')=='staging','evidence is not from Staging')
d=ev.get('deployment',{})
require(d.get('target')=='kubernetes-ec2','evidence is not Kubernetes EC2 CD')
require(d.get('cluster')==sys.argv[3],'unexpected Kubernetes cluster')
require(d.get('namespace')==sys.argv[4],'unexpected namespace')
release=ev.get('release',{}); request_release=req.get('release',{})
require(release.get('id')==request_release.get('id'),'release ID mismatch')
require(release.get('source')==request_release.get('source'),'source SHA mismatch')
flags=ev.get('evidence',{})
for key in ('stagingDeployed','stagingVerified','artifactIdentityVerified','runtimeImageIdentityVerified','applicationReadinessVerified','rolloutVerified'):
    require(flags.get(key) is True,f'missing evidence flag: {key}')
methods=ev.get('verificationMethods',{})
require(methods.get('runtimeImageIdentity')=='Pod status.containerStatuses[].imageID digest comparison','runtime image identity method missing')
require(methods.get('applicationReadiness')=='Kubernetes readinessProbe using HTTP GET /health/ready','application readiness method missing')
for service in ('api','worker'):
    expected=req.get('artifact',{}).get(service,{})
    actual=ev.get('artifact',{}).get(service,{})
    require(actual.get('name')==expected.get('name'),f'{service} repository changed')
    require(actual.get('tag')==expected.get('tag'),f'{service} tag changed')
    require(actual.get('digest')==expected.get('digest'),f'{service} digest changed')
    require(re.fullmatch(r'sha256:[0-9a-f]{64}',actual.get('digest','')) is not None,f'invalid {service} digest')
    runtime=d.get(service,{})
    require(runtime.get('deploymentImage')==f"{actual['name']}@{actual['digest']}",f'{service} deployment image mismatch')
    pods=runtime.get('pods',[])
    require(len(pods)==runtime.get('desiredReplicas'),f'{service} pod count mismatch')
    for pod in pods:
        require(pod.get('actualDigest')==actual['digest'],f'{service} running Pod digest mismatch')
        require(pod.get('containerReady') is True and pod.get('podReadyCondition')=='True',f'{service} Pod readiness mismatch')
        require(pod.get('readinessProbe',{}).get('httpGet',{}).get('path')=='/health/ready',f'{service} readiness probe path mismatch')
        require(pod.get('readinessProbe',{}).get('httpGet',{}).get('port')=={'api':'http','worker':'metrics'}[service],f'{service} readiness probe port mismatch')
print('Kubernetes Staging promotion evidence validated.')
PY
