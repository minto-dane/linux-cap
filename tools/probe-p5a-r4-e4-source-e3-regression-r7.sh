#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export NAME=p5a-r4-e4-source-e3-regression-r7
export RUN_ID=20260723T-p5a-r4-e4-owner-oracle-correction-source-e3-regression-r7
export EXPECTED_CANDIDATE_COMMIT=4077ba840f713979c29af64f405dbde39f845d93
export EXPECTED_CANDIDATE_TREE=6ce127d738618fd356ed3533ac32e5796fa72d55
export EXPECTED_CANDIDATE_DIFF_SHA=a4886479f001ea3ef0dbc069ef44040f89df69cc9114421933a5592075bfe255
export EXPECTED_R7_CORRECTIONS=1
exec "$ROOT/tools/probe-p5a-r4-e4-source-e3-regression-r3.sh" "$@"
