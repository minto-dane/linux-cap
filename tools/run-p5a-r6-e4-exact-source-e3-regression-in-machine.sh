#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r6-e4-exact-source-e3-regression
JOB_DIR="$ROOT/build/long-jobs/$NAME"
RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r6-e4-exact-source-e3-regression.sh"
RUN_ID=20260730T-p5a-r6-e4-e3-regression-r1
PROGRESS_FILE="$JOB_DIR/progress"
JOBS=6

mkdir -p "$JOB_DIR"
find "$JOB_DIR/vm_exit_code" "$JOB_DIR/vm_finished_at" \
	-type f -delete 2>/dev/null || true
set +e
env RUN_ID="$RUN_ID" PROGRESS_FILE="$PROGRESS_FILE" JOBS="$JOBS" \
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
