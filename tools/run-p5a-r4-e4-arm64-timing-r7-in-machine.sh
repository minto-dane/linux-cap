#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

export NAME=p5a-r4-e4-arm64-timing-r7
export RUN_ID=20260723T-p5a-r4-e4-arm64-timing-r7
export EXPECTED_RUNNER_SHA=54e1ee16fdd55c57e306ecb582420455c6e088ac150c39b3f66c8432439a8a50
export DOMAINLEASE_BUILD_JOBS=6

exec "$ROOT/tools/run-p5a-r4-e4-arm64-timing-r4-in-machine.sh"
