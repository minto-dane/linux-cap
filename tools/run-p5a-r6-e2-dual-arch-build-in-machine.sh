#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
JOB_DIR="$ROOT/build/long-jobs/p5a-r6-e2-dual-arch-build"
RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r6-e2-dual-arch-layout.sh"
RUN_ID=20260725T-p5a-r6-e2-dual-arch-r1
PROGRESS_FILE="$JOB_DIR/progress"

mkdir -p "$JOB_DIR"
rm -f "$JOB_DIR/vm_exit_code" "$JOB_DIR/vm_finished_at"
set +e
env RUN_ID="$RUN_ID" PROGRESS_FILE="$PROGRESS_FILE" \
	"$RUNNER" >> "$JOB_DIR/job.log" 2>&1
rc=$?
set -e
printf '%s\n' "$rc" > "$JOB_DIR/vm_exit_code"
date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/vm_finished_at"
if [ "$rc" -ne 0 ]; then
	printf 'failed (runner exit %s); inspect job.log\n' "$rc" > "$PROGRESS_FILE"
fi
exit "$rc"
