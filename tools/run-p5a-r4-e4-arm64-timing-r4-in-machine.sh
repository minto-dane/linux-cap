#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r4-e4-arm64-timing-r4
RUN_ID=20260721T-p5a-r4-e4-arm64-timing-r4
JOB_DIR="$ROOT/build/long-jobs/$NAME"
RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement.sh"
EXPECTED_RUNNER_SHA=2fe52b6e9bfbc57ccca43c6e45fc3c18b15e196967822c34743b202480385e69
HOST_ENV_FILE="$JOB_DIR/outer-host-environment.txt"
PROGRESS_FILE="$JOB_DIR/progress"
BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement/$RUN_ID"
WORKTREE="/var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement/$RUN_ID"
HOST_MIN_KIB=33554432
VM_MIN_KIB=16777216

fail_wrapper()
{
	local reason=$1 rc=${2:-125}
	printf 'failed (%s)\n' "$reason" > "$PROGRESS_FILE"
	printf '%s\n' "$rc" > "$JOB_DIR/vm_exit_code"
	date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/vm_finished_at"
	exit "$rc"
}

mkdir -p "$JOB_DIR"
find "$JOB_DIR/vm_exit_code" "$JOB_DIR/vm_finished_at" -type f -delete 2>/dev/null || true
if [ "$(sha256sum "$RUNNER" | awk '{print $1}')" != "$EXPECTED_RUNNER_SHA" ]; then
	fail_wrapper 'timing runner hash changed before VM execution' 126
fi

set +e
sudo -n fstrim -av 2>&1 | tee "$JOB_DIR/vm-pre-run-trim.log" >/dev/null
pre_trim_rc=${PIPESTATUS[0]}
set -e
printf '%s\n' "$pre_trim_rc" > "$JOB_DIR/vm_pre_run_trim_exit_code"
[ "$pre_trim_rc" -eq 0 ] || fail_wrapper 'VM pre-run trim failed'

host_available_kib=$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')
vm_available_kib=$(df -Pk /var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement | awk 'NR==2 {print $4}')
{
	printf 'host_available_kib=%s\nhost_min_kib=%s\n' "$host_available_kib" "$HOST_MIN_KIB"
	printf 'vm_available_kib=%s\nvm_min_kib=%s\n' "$vm_available_kib" "$VM_MIN_KIB"
} > "$JOB_DIR/vm-pre-run-storage.txt"
case "$host_available_kib:$vm_available_kib" in
	*[!0-9:]*) fail_wrapper 'invalid pre-run storage reading' ;;
esac
[ "$host_available_kib" -ge "$HOST_MIN_KIB" ] || fail_wrapper "shared host storage below ${HOST_MIN_KIB}KiB before runner"
[ "$vm_available_kib" -ge "$VM_MIN_KIB" ] || fail_wrapper "VM storage below ${VM_MIN_KIB}KiB before runner"

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
