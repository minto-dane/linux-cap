#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export NAME=p5a-r4-e4-source-e3-regression-r5
export RUN_ID=20260721T-p5a-r4-e4-coalesced-owner-source-e3-regression-r5
export EXPECTED_COMBINED_RUNNER_SHA=b6a779044ad4547dba2849cd62e34f57a814fe74f05fd10875e8be8b39f1101c
exec "$ROOT/tools/run-p5a-r4-e4-source-e3-regression-r3-in-machine.sh" "$@"
