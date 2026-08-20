#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export NAME=p5a-r4-e4-source-e3-regression-r7
export RUN_ID=20260723T-p5a-r4-e4-owner-oracle-correction-source-e3-regression-r7
export EXPECTED_SOURCE_RUNNER_SHA=c29d8862589f9cd7a203002f06aa756131fe77dd1e97b08b8f322090fb122e3e
export EXPECTED_REGRESSION_RUNNER_SHA=3b3383b88a2204d2d68dddf2ae26362d355e29ed6a2e1d896681780e79b1a5f9
export EXPECTED_COMBINED_RUNNER_SHA=5b2a60b4539803df97a7ee77c88b60f38e6cb62cac2f20936795435ad9409078
export EXPECTED_ROOT_COMMIT=HEAD
export EXPECTED_CAPSCHED_COMMIT=bb5b21ff6b1c9d254f1b77860a28bfe3694c5f8d
export EXPECTED_CANDIDATE_COMMIT=4077ba840f713979c29af64f405dbde39f845d93
export EXPECTED_CANDIDATE_TREE=6ce127d738618fd356ed3533ac32e5796fa72d55
export EXPECTED_CANDIDATE_BRANCH=codex/p5a-r4-e4-local-quantum-measurement-r7
exec "$ROOT/tools/start-p5a-r4-e4-source-e3-regression-r3.sh" "$@"
