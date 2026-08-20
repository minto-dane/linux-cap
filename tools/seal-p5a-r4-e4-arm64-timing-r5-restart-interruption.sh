#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r4-e4-arm64-timing-r5
RUN_ID=20260722T-p5a-r4-e4-arm64-timing-r5
JOB_DIR="$ROOT/build/long-jobs/$NAME"
OUT_DIR="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/$RUN_ID"
RAW_DIR="$OUT_DIR/raw"
ARCHIVE_DIR="$OUT_DIR/interrupted-archive"
RESULT="$OUT_DIR/result.json"
RESULT_SHA="$OUT_DIR/result.sha256"
RESERVE="$OUT_DIR/.failure-seal-reserve"
BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement/$RUN_ID"
WORKTREE="/var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement/$RUN_ID"
BUILD_OUT="$BUILD_ROOT/build"
EXPECTED_SOURCE=82d91805f8e145d2403057f656e590e4bcae12f1
EXPECTED_SOURCE_TREE=44d9a2125eac6eac4c8c25f38fb6a5eae3a5bd4f
EXPECTED_RUNNER=cd2f210304fae4be4586bb9bcf750e959513ff59e96796ad2a6b64a8a1a727db
EXPECTED_IMAGE=21b6ed89a0c48063771ec8988f34731c196265c5ea173967e274fdcc4e7ee6fe
EXPECTED_OBJECT=e8b8148246e031ad45df45de26cec2e6027bcb5c710c4ce5aef70c7353ec7818
EXPECTED_CONFIG=2cbf3e910322ee65f39074a551fd61a14cbe457608358e6a76608ae6d25cf07b

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

file_sha()
{
	shasum -a 256 "$1" | awk '{print $1}'
}

if [ -s "$RESULT" ] && [ -s "$RESULT_SHA" ]; then
	[ "$(awk 'NF {print $1; exit}' "$RESULT_SHA")" = "$(file_sha "$RESULT")" ] ||
		die 'existing interruption result hash does not verify'
	jq -e --arg run_id "$RUN_ID" '
	  .status == "harness_failed" and .run_id == $run_id and
	  .failure.stage == "host_restart" and .matrix.result_rows == 166 and
	  .matrix.total_cells == 682 and .partial_rows_receive_evidence_credit == false and
	  .run_owned_build_scratch_retired == true and
	  .run_owned_worktree_retired == true and
	  .failure_seal_reserve_released == true and
	  .x86_64_measurement_may_start == false
	' "$RESULT" >/dev/null || die 'existing interruption result semantics do not verify'
	printf 'already sealed: %s\n' "$RESULT"
	exit 0
fi

for command in container date find git jq shasum stat sysctl; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
[ -d "$OUT_DIR" ] || die 'interrupted output directory is absent'
[ -s "$RAW_DIR/qemu-serial.log" ] || die 'interrupted serial log is absent'
[ -s "$RAW_DIR/measurement-runner.sh" ] || die 'runner snapshot is absent'
[ "$(file_sha "$RAW_DIR/measurement-runner.sh")" = "$EXPECTED_RUNNER" ] ||
	die 'runner snapshot changed'
[ -f "$RESERVE" ] || die 'failure-seal reserve is absent'
[ "$(stat -f %z "$RESERVE")" -eq 67108864 ] || die 'failure-seal reserve size changed'

rows=$(awk '/R4_E4_RESULT / { count++ } END { print count + 0 }' "$RAW_DIR/qemu-serial.log")
summaries=$(awk '/R4_E4_SUMMARY / { count++ } END { print count + 0 }' "$RAW_DIR/qemu-serial.log")
[ "$rows" -eq 166 ] || die "expected 166 interrupted rows, found $rows"
[ "$summaries" -eq 0 ] || die "expected zero summaries, found $summaries"

host_boot_epoch=$(sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+),.*/\1/')
serial_mtime_epoch=$(stat -f %m "$RAW_DIR/qemu-serial.log")
job_log_mtime_epoch=$(stat -f %m "$JOB_DIR/job.log")
started_epoch=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$(cat "$JOB_DIR/started_at")" +%s)
case "$host_boot_epoch:$serial_mtime_epoch:$job_log_mtime_epoch:$started_epoch" in
	*[!0-9:]*) die 'invalid restart timestamp evidence' ;;
esac
[ "$started_epoch" -lt "$host_boot_epoch" ] || die 'job did not start before host boot'
[ "$serial_mtime_epoch" -lt "$host_boot_epoch" ] || die 'serial log does not predate host boot'
[ "$job_log_mtime_epoch" -lt "$host_boot_epoch" ] || die 'job log does not predate host boot'

machine_state=$(container machine inspect domainlease-dev | jq -r '.[0].status')
[ "$machine_state" = running ] || die 'domainlease-dev is not running'
processes=$(container machine run -n domainlease-dev /usr/bin/ps -eo args=)
if printf '%s\n' "$processes" | grep -Eq \
	'[r]un-p5a-r4-e4-arm64-timing|[r]un-sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement|[q]emu-system-aarch64|[m]ake -C /var/tmp/linux-cap-worktrees/p5a-r4-e4'; then
	die 'timing, QEMU, or build process is still active'
fi

[ "$(container machine run -n domainlease-dev git -C "$WORKTREE" rev-parse HEAD)" = "$EXPECTED_SOURCE" ] ||
	die 'interrupted worktree source changed'
[ -z "$(container machine run -n domainlease-dev git -C "$WORKTREE" status --porcelain --untracked-files=no)" ] ||
	die 'interrupted worktree tracked state is dirty'
[ "$(container machine run -n domainlease-dev sha256sum "$BUILD_OUT/arch/arm64/boot/Image" | awk '{print $1}')" = "$EXPECTED_IMAGE" ] ||
	die 'interrupted Image changed'
[ "$(container machine run -n domainlease-dev sha256sum "$BUILD_OUT/kernel/sched/exec_lease.o" | awk '{print $1}')" = "$EXPECTED_OBJECT" ] ||
	die 'interrupted exec_lease.o changed'
[ "$(container machine run -n domainlease-dev sha256sum "$BUILD_OUT/.config" | awk '{print $1}')" = "$EXPECTED_CONFIG" ] ||
	die 'interrupted config changed'

mkdir -p "$ARCHIVE_DIR/job-records"
container machine run -n domainlease-dev cp "$BUILD_OUT/arch/arm64/boot/Image" "$ARCHIVE_DIR/Image"
container machine run -n domainlease-dev cp "$BUILD_OUT/kernel/sched/exec_lease.o" "$ARCHIVE_DIR/exec_lease.o"
container machine run -n domainlease-dev cp "$BUILD_OUT/.config" "$ARCHIVE_DIR/arm64.config"
for record in command.txt started_at finished_at mode pid progress state watch_path vm-pre-run-storage.txt vm_preflight_trim_exit_code vm_pre_run_trim_exit_code; do
	[ -f "$JOB_DIR/$record" ] && cp "$JOB_DIR/$record" "$ARCHIVE_DIR/job-records/$record"
done
printf '%s\n' "$host_boot_epoch" > "$ARCHIVE_DIR/host-boot-epoch"
printf '%s\n' "$serial_mtime_epoch" > "$ARCHIVE_DIR/serial-mtime-epoch"
printf '%s\n' "$job_log_mtime_epoch" > "$ARCHIVE_DIR/job-log-mtime-epoch"
printf '%s\n' "$rows" > "$ARCHIVE_DIR/partial-result-rows"
printf '%s\n' "$summaries" > "$ARCHIVE_DIR/partial-summary-rows"

[ "$(file_sha "$ARCHIVE_DIR/Image")" = "$EXPECTED_IMAGE" ] || die 'archived Image mismatch'
[ "$(file_sha "$ARCHIVE_DIR/exec_lease.o")" = "$EXPECTED_OBJECT" ] || die 'archived object mismatch'
[ "$(file_sha "$ARCHIVE_DIR/arm64.config")" = "$EXPECTED_CONFIG" ] || die 'archived config mismatch'

(
	cd "$OUT_DIR"
	LC_ALL=C find raw interrupted-archive -type f -print | sort |
		while IFS= read -r file; do shasum -a 256 "$file"; done > interrupted-inputs.sha256
)
inputs_manifest_sha=$(file_sha "$OUT_DIR/interrupted-inputs.sha256")

container machine run -n domainlease-dev rm -rf -- "$BUILD_ROOT" "$WORKTREE"
container machine run -n domainlease-dev test ! -e "$BUILD_ROOT"
container machine run -n domainlease-dev test ! -e "$WORKTREE"
git -C "$ROOT/linux" worktree prune --expire now
[ -z "$(git -C "$ROOT/linux" worktree list --porcelain | grep -F "$WORKTREE" || true)" ] ||
	die 'stale interrupted worktree registration remains'
rm -f "$RESERVE"
[ ! -e "$RESERVE" ] || die 'failure-seal reserve was not released'

tmp="$RESULT.tmp.$$"
jq -n \
	--arg run_id "$RUN_ID" \
	--arg source_commit "$EXPECTED_SOURCE" \
	--arg source_tree "$EXPECTED_SOURCE_TREE" \
	--arg runner_sha "$EXPECTED_RUNNER" \
	--arg image_sha "$EXPECTED_IMAGE" \
	--arg object_sha "$EXPECTED_OBJECT" \
	--arg config_sha "$EXPECTED_CONFIG" \
	--arg manifest_sha "$inputs_manifest_sha" \
	--argjson rows "$rows" \
	--argjson host_boot_epoch "$host_boot_epoch" \
	--argjson serial_mtime_epoch "$serial_mtime_epoch" \
	--argjson job_log_mtime_epoch "$job_log_mtime_epoch" '
	{
	  schema_version: 1,
	  id: "sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement-result-v1",
	  run_id: $run_id,
	  architecture: "arm64",
	  status: "harness_failed",
	  failure: {
	    stage: "host_restart",
	    reason: "host reboot interrupted QEMU before the complete 682-cell matrix"
	  },
	  source: {commit: $source_commit, tree: $source_tree},
	  runner: {sha256: $runner_sha},
	  matrix: {total_cells: 682, result_rows: $rows, summary_rows: 0},
	  restart_evidence: {
	    host_boot_epoch: $host_boot_epoch,
	    serial_mtime_epoch: $serial_mtime_epoch,
	    job_log_mtime_epoch: $job_log_mtime_epoch,
	    serial_and_job_logs_predate_host_boot: true
	  },
	  retained_artifacts: {
	    image_sha256: $image_sha,
	    exec_lease_object_sha256: $object_sha,
	    config_sha256: $config_sha,
	    interrupted_inputs_manifest_sha256: $manifest_sha
	  },
	  partial_rows_receive_evidence_credit: false,
	  architecture_measurement_valid: false,
	  measurement_result_accepted: false,
	  x86_64_measurement_may_start: false,
	  run_owned_build_scratch_retired: true,
	  run_owned_worktree_retired: true,
	  failure_seal_reserve_released: true,
	  real_scheduler_attachment: false,
	  runtime_behavior_approved: false,
	  production_protection: false,
	  deployment_ready: false,
	  multi_cluster_ready: false,
	  datacenter_ready: false
	}
	' > "$tmp"
mv "$tmp" "$RESULT"
file_sha "$RESULT" > "$RESULT_SHA"
chmod -R a-w "$RAW_DIR" "$ARCHIVE_DIR" "$OUT_DIR/interrupted-inputs.sha256" "$RESULT" "$RESULT_SHA"
printf 'failed: host restart interruption sealed; 166/682 rows receive no credit; scratch retired\n' > "$JOB_DIR/progress"
printf 'host_restart\n' > "$JOB_DIR/failure_reason"
printf 'sealed restart interruption result: %s\n' "$RESULT"
printf 'result_sha256=%s\n' "$(file_sha "$RESULT")"
