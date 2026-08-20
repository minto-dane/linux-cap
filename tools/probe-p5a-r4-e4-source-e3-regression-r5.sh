#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export NAME=p5a-r4-e4-source-e3-regression-r5
export RUN_ID=20260721T-p5a-r4-e4-coalesced-owner-source-e3-regression-r5
export EXPECTED_CANDIDATE_COMMIT=82d91805f8e145d2403057f656e590e4bcae12f1
export EXPECTED_CANDIDATE_TREE=44d9a2125eac6eac4c8c25f38fb6a5eae3a5bd4f
export EXPECTED_CANDIDATE_DIFF_SHA=a7cb42fe5fc6f346ba8ea009097fa15433050e79e3255d64467d7b8ad636aeb9
exec "$ROOT/tools/probe-p5a-r4-e4-source-e3-regression-r3.sh" "$@"
