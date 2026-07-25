#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r6-e3-four-profile-matrix
JOB_DIR="$ROOT/build/long-jobs/$NAME"
RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix.sh"
RUN_ID=20260726T-p5a-r6-e3-four-profile-r1
SOURCE_GATE_RESULT="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e3-correctness-source-gate/20260726T-p5a-r6-e3-source-gate-r1/result.json"
SOURCE_GATE_SHA256=88376403879ecc2b0a059791ba59a5bd71addd493e9c8052c2742f877f9e7f25
PROGRESS_FILE="$JOB_DIR/progress"
JOBS=${JOBS:-6}

mkdir -p "$JOB_DIR"
find "$JOB_DIR/vm_exit_code" "$JOB_DIR/vm_finished_at" \
	-type f -delete 2>/dev/null || true
set +e
env RUN_ID="$RUN_ID" PROGRESS_FILE="$PROGRESS_FILE" JOBS="$JOBS" \
	SOURCE_GATE_RESULT="$SOURCE_GATE_RESULT" \
	SOURCE_GATE_SHA256="$SOURCE_GATE_SHA256" \
	"$RUNNER" >> "$JOB_DIR/job.log" 2>&1
rc=$?
set -e
printf '%s\n' "$rc" > "$JOB_DIR/vm_exit_code"
date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/vm_finished_at"
if [ "$rc" -ne 0 ]; then
	printf 'failed (runner exit %s); inspect job.log\n' "$rc" \
		> "$PROGRESS_FILE"
fi
exit "$rc"
