#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=${NAME:-p5a-r4-e4-source-e3-regression-r3}
RUN_ID=${RUN_ID:-20260719T-p5a-r4-e4-source-e3-regression-r3}
JOB_DIR="$ROOT/build/long-jobs/$NAME"
RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r4-e4-source-and-e3-regression.sh"
PROGRESS_FILE="$JOB_DIR/progress"
EXPECTED_COMBINED_RUNNER_SHA=${EXPECTED_COMBINED_RUNNER_SHA:-cbadfbcb179029102d54482991c586785765839d4f8bd8d200ae186215c4467a}
BUILD_JOBS=${DOMAINLEASE_BUILD_JOBS:-$(nproc)}

case "$BUILD_JOBS" in
	''|*[!0-9]*|0) printf '%s\n' 'failed (invalid build parallelism)' > "$PROGRESS_FILE"; exit 125 ;;
esac

mkdir -p "$JOB_DIR"
rm -f "$JOB_DIR/vm_exit_code" "$JOB_DIR/vm_finished_at"
if [ "$(sha256sum "$RUNNER" | awk '{print $1}')" != "$EXPECTED_COMBINED_RUNNER_SHA" ]; then
	printf '%s\n' 'failed (combined runner hash changed before VM execution)' > "$PROGRESS_FILE"
	printf '%s\n' 126 > "$JOB_DIR/vm_exit_code"
	date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/vm_finished_at"
	exit 126
fi
set +e
env RUN_ID="$RUN_ID" PROGRESS_FILE="$PROGRESS_FILE" JOBS="$BUILD_JOBS" \
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
if [ "$rc" -ne 0 ]; then
	printf 'failed (runner exit %s); inspect job.log\n' "$rc" > "$PROGRESS_FILE"
fi
exit "$rc"
