#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

export NAME=p5a-r4-e4-arm64-timing-r5
export RUN_ID=20260722T-p5a-r4-e4-arm64-timing-r5
export EXPECTED_RUNNER_SHA=cd2f210304fae4be4586bb9bcf750e959513ff59e96796ad2a6b64a8a1a727db
export DOMAINLEASE_BUILD_JOBS=6

exec "$ROOT/tools/run-p5a-r4-e4-arm64-timing-r4-in-machine.sh"
