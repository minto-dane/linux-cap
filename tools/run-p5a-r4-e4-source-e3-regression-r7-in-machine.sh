#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export NAME=p5a-r4-e4-source-e3-regression-r7
export RUN_ID=20260723T-p5a-r4-e4-owner-oracle-correction-source-e3-regression-r7
export EXPECTED_COMBINED_RUNNER_SHA=5b2a60b4539803df97a7ee77c88b60f38e6cb62cac2f20936795435ad9409078
exec "$ROOT/tools/run-p5a-r4-e4-source-e3-regression-r3-in-machine.sh" "$@"
