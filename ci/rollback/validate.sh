#!/usr/bin/env bash

set -euo pipefail

die() {
    echo "ROLLBACK VALIDATION ERROR: $*" >&2
    exit 1
}

: "${FAILED_SOURCE_SHA:?FAILED_SOURCE_SHA is required}"
: "${TARGET_SOURCE_SHA:?TARGET_SOURCE_SHA is required}"
: "${ROLLBACK_EVIDENCE:?ROLLBACK_EVIDENCE is required}"

[[ -f "$ROLLBACK_EVIDENCE" ]] || \
    die "Rollback evidence not found: $ROLLBACK_EVIDENCE"

python3 - <<'PY'
import json
import os
import re
import sys

path = os.environ["ROLLBACK_EVIDENCE"]

with open(path, "r", encoding="utf-8") as f:
    evidence = json.load(f)

failed_sha = os.environ["FAILED_SOURCE_SHA"]
target_sha = os.environ["TARGET_SOURCE_SHA"]

def fail(message):
    print(f"ROLLBACK VALIDATION FAILED: {message}")
    sys.exit(1)

def require(condition, message):
    if not condition:
        fail(message)

sha_pattern = re.compile(r"^[0-9a-f]{40}$")
digest_pattern = re.compile(r"^sha256:[0-9a-f]{64}$")

require(
    evidence.get("schemaVersion") == "1.0",
    "Invalid evidence schema"
)

require(
    evidence.get("project") == "mini-write",
    "Invalid project"
)

require(
    evidence.get("gate") == "production-verification",
    "Evidence is not production verification"
)

require(
    evidence.get("status") == "passed",
    "Previous release was not verified successfully"
)

require(
    evidence.get("environment") == "production",
    "Evidence environment is not production"
)

release = evidence.get("release", {})
artifact = evidence.get("artifact", {})

source = release.get("source")
release_id = release.get("id")

require(
    isinstance(source, str) and sha_pattern.fullmatch(source),
    "Invalid target source SHA"
)

require(
    isinstance(release_id, str) and sha_pattern.fullmatch(release_id),
    "Invalid target release ID"
)

require(
    source == target_sha,
    "Target SHA does not match evidence"
)

require(
    release_id == target_sha,
    "Target release ID does not match target SHA"
)

require(
    target_sha != failed_sha,
    "Rollback target must differ from failed release"
)

api = artifact.get("api", {})
worker = artifact.get("worker", {})

require(
    api.get("tag") == target_sha,
    "API tag does not match rollback target"
)

require(
    worker.get("tag") == target_sha,
    "Worker tag does not match rollback target"
)

require(
    isinstance(api.get("digest"), str)
    and digest_pattern.fullmatch(api["digest"]),
    "Invalid API rollback digest"
)

require(
    isinstance(worker.get("digest"), str)
    and digest_pattern.fullmatch(worker["digest"]),
    "Invalid Worker rollback digest"
)

print("==========================================")
print("ROLLBACK TARGET VALIDATED")
print("==========================================")
print(f"Failed release:  {failed_sha}")
print(f"Target release:  {target_sha}")
print(f"API digest:      {api['digest']}")
print(f"Worker digest:   {worker['digest']}")
print("Production:      PREVIOUSLY VERIFIED")
PY