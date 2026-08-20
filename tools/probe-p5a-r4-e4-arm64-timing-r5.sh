#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

export NAME=p5a-r4-e4-arm64-timing-r5
export RUN_ID=20260722T-p5a-r4-e4-arm64-timing-r5
export EXPECTED_CANDIDATE_COMMIT=82d91805f8e145d2403057f656e590e4bcae12f1
export EXPECTED_CANDIDATE_TREE=44d9a2125eac6eac4c8c25f38fb6a5eae3a5bd4f
export EXPECTED_COMBINED_RUN=20260721T-p5a-r4-e4-coalesced-owner-source-e3-regression-r5
export EXPECTED_SOURCE_CLOSURE_R1_SHA=313651a8eaf26daf8d29eb7634c82222f44bdd2d1b6cee840702324bbad2c57c
export EXPECTED_SOURCE_CLOSURE_R2_SHA=10dd9320e102d452d57e08002e1d930537e669f28add02ef8e851d3ec7577d4a
export EXPECTED_SOURCE_CLOSURE_NORMALIZED_SHA=7536970108657a6cba06debc895ecc3f088818bc6aa19a4f1fdbfdbe50adb449
export EXPECTED_RUNNER_SHA=cd2f210304fae4be4586bb9bcf750e959513ff59e96796ad2a6b64a8a1a727db

exec "$ROOT/tools/probe-p5a-r4-e4-arm64-timing-r4.sh"
