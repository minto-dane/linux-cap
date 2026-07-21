#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export NAME=p5a-r4-e4-source-e3-regression-r5
export RUN_ID=20260721T-p5a-r4-e4-coalesced-owner-source-e3-regression-r5
export EXPECTED_SOURCE_RUNNER_SHA=b5815d21564480f51570c62008a680bacbefbda4a29514633264b80ede4dbcff
export EXPECTED_REGRESSION_RUNNER_SHA=16ae06b59823080cfcb127551dec6d59d0eb50509d4b312930728d18039a31a6
export EXPECTED_COMBINED_RUNNER_SHA=b6a779044ad4547dba2849cd62e34f57a814fe74f05fd10875e8be8b39f1101c
export EXPECTED_ROOT_COMMIT=7cb1d94d0eeef99e984b1105c294517be70f633e
export EXPECTED_CAPSCHED_COMMIT=1c94cdff20b519228f56f76a9a69f1ee7a3ef37d
export EXPECTED_CANDIDATE_COMMIT=82d91805f8e145d2403057f656e590e4bcae12f1
export EXPECTED_CANDIDATE_TREE=44d9a2125eac6eac4c8c25f38fb6a5eae3a5bd4f
exec "$ROOT/tools/start-p5a-r4-e4-source-e3-regression-r3.sh" "$@"
