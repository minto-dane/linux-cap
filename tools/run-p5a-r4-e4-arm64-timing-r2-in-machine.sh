#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r4-e4-arm64-timing-r2
RUN_ID=20260720T-p5a-r4-e4-arm64-timing-r2
JOB_DIR="$ROOT/build/long-jobs/$NAME"
RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement.sh"
EXPECTED_RUNNER_SHA=a3ee78f5ae1bc32a89bfb0b765a9e87da3888536c0bdb658b2f88acf71ddf392
HOST_ENV_FILE="$JOB_DIR/outer-host-environment.txt"
PROGRESS_FILE="$JOB_DIR/progress"
BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement/$RUN_ID"
WORKTREE="/var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement/$RUN_ID"

mkdir -p "$JOB_DIR"
find "$JOB_DIR/vm_exit_code" "$JOB_DIR/vm_finished_at" -type f -delete 2>/dev/null || true
if [ "$(sha256sum "$RUNNER" | awk '{print $1}')" != "$EXPECTED_RUNNER_SHA" ]; then
	printf '%s\n' 'failed (timing runner hash changed before VM execution)' > "$PROGRESS_FILE"
	printf '%s\n' 126 > "$JOB_DIR/vm_exit_code"
	date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/vm_finished_at"
	exit 126
fi
set +e
env RUN_ID="$RUN_ID" BUILD_ROOT="$BUILD_ROOT" WORKTREE="$WORKTREE" \
	HOST_ENV_FILE="$HOST_ENV_FILE" PROGRESS_FILE="$PROGRESS_FILE" \
	"$RUNNER" >> "$JOB_DIR/job.log" 2>&1
rc=$?
set -e
set +e
sudo -n fstrim -av 2>&1 | tee "$JOB_DIR/vm-trim.log" >/dev/null
trim_rc=${PIPESTATUS[0]}
set -e
printf '%s\n' "$trim_rc" > "$JOB_DIR/vm_trim_exit_code"
printf '%s\n' "$rc" > "$JOB_DIR/vm_exit_code"
date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/vm_finished_at"
if [ "$rc" -ne 0 ] && [ ! -s "$PROGRESS_FILE" ]; then
	printf 'failed (runner exit %s); inspect job.log and result.json\n' "$rc" > "$PROGRESS_FILE"
fi
exit "$rc"
