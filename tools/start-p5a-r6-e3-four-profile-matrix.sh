#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r6-e3-four-profile-matrix
RUN_ID=20260726T-p5a-r6-e3-four-profile-r1
JOB_DIR="$ROOT/build/long-jobs/$NAME"
PROBE="$ROOT/tools/probe-$NAME.sh"
WRAPPER="$ROOT/tools/run-$NAME-in-machine.sh"
OUT_DIR="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix/$RUN_ID"
RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix.sh"
SOURCE_GATE="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e3-correctness-source-gate/20260726T-p5a-r6-e3-source-gate-r1/result.json"
SOURCE_GATE_SHA256=88376403879ecc2b0a059791ba59a5bd71addd493e9c8052c2742f877f9e7f25
CANDIDATE_DIR="$ROOT/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e3-correctness-prototype"
WATCH=0

case "${1:-}" in
	'') ;;
	--watch) WATCH=1 ;;
	*) printf 'usage: %s [--watch]\n' "$0" >&2; exit 2 ;;
esac

watch_if_requested()
{
	if [ "$WATCH" = 1 ]; then
		exec "$ROOT/tools/long-job.sh" watch "$NAME" 30
	fi
}

mkdir -p "$JOB_DIR"
probe_state=$("$PROBE" 2>/dev/null | sed -n '1p' || true)
if [ "$probe_state" = running ]; then
	printf '%s is already running.\n' "$NAME"
	printf 'monitor: cd %s && ./tools/long-job.sh watch %s 30\n' \
		"$ROOT" "$NAME"
	watch_if_requested
	exit 0
elif [ "$probe_state" = complete ]; then
	printf '%s is already complete.\n' "$NAME"
	watch_if_requested
	exit 0
fi

jq -e '
  .status == "passed_source_gate_awaiting_four_profile_diagnostic_matrix" and
  .candidate_commit == "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
  .candidate_parent == "66e2fd20fc85012d7dc03649fcf4c7af583cbb94" and
  .candidate_tree == "2b863b57dfe3f03609ad1a73c965874f71056e8f" and
  .deterministic_case_families == 55 and
  .allocation_fault_sites == 3 and
  .strict_checkpatch == {errors:0,warnings:0,checks:0} and
  .w1_compiler_diagnostics == 0 and
  .diagnostic_matrix_may_start == true and
  .r6_e3_source_accepted == false and
  .r6_e3_correctness_accepted == false and
  .production_protection == false and
  .deployment_ready == false and
  .datacenter_ready == false
' "$SOURCE_GATE" >/dev/null
[ "$(shasum -a 256 "$SOURCE_GATE" | awk '{print $1}')" = \
	"$SOURCE_GATE_SHA256" ]
[ "$(shasum -a 256 "$RUNNER" | awk '{print $1}')" = \
	4b27719906ac0078ffed06af1931eff590bd05024bfbc736b3ddc0f860a4119d ]
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = \
	99287291f1c8e0d6c1b3ea86d121508c5547f424 ]
[ "$(git -C "$CANDIDATE_DIR" rev-parse \
	refs/remotes/fork/codex/p5a-r6-e3-correctness-prototype)" = \
	99287291f1c8e0d6c1b3ea86d121508c5547f424 ]
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain \
	--untracked-files=no)" ]
[ "$(git -C "$ROOT/capsched" rev-parse HEAD)" = \
	075d4115810f7cda48e03f00994be119e7b65241 ]
[ "$(git -C "$ROOT/capsched" rev-parse \
	refs/remotes/origin/codex/r4-e3-source)" = \
	075d4115810f7cda48e03f00994be119e7b65241 ]
[ "$(git -C "$ROOT" rev-parse HEAD)" = \
	"$(git -C "$ROOT" rev-parse refs/remotes/origin/codex/r4-e3-source)" ]
[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]
[ "$(container machine inspect domainlease-dev |
	jq -r '.[0].status')" = running ]
[ ! -e "$OUT_DIR" ]

processes=$(container machine run -n domainlease-dev \
	/usr/bin/ps -eo args=)
if printf '%s\n' "$processes" |
	grep -Eq \
		'[r]un-p5a-r6-e3-four-profile-matrix|[r]un-sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix|[q]emu-system-(aarch64|x86_64)|[m]ake -C .*p5a-r6-e3-correctness-prototype'; then
	printf 'error: R6-E3 matrix process is already active\n' >&2
	exit 1
fi
storage_type=$(container machine run -n domainlease-dev \
	stat -f -c %T /var/tmp)
available_kib=$(container machine run -n domainlease-dev \
	df -Pk /var/tmp | awk 'NR == 2 {print $4}')
[ "$storage_type" = ext2/ext3 ] || {
	printf 'error: /var/tmp is not internal ext storage: %s\n' \
		"$storage_type" >&2
	exit 1
}
[ "$available_kib" -ge 8388608 ] || {
	printf 'error: matrix requires 8 GiB internal space; only %s KiB available\n' \
		"$available_kib" >&2
	exit 1
}

: > "$JOB_DIR/job.log"
find "$JOB_DIR/exit_code" "$JOB_DIR/finished_at" \
	"$JOB_DIR/failure_reason" "$JOB_DIR/progress" \
	"$JOB_DIR/vm_exit_code" "$JOB_DIR/vm_finished_at" \
	-type f -delete 2>/dev/null || true
printf '%s\n' external > "$JOB_DIR/mode"
printf '%s\n' running > "$JOB_DIR/state"
printf '%s\n' external > "$JOB_DIR/pid"
date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/started_at"
printf '%s\n' "$OUT_DIR" > "$JOB_DIR/watch_path"
printf '%s\n' "$PROBE" > "$JOB_DIR/probe_path"
: > "$JOB_DIR/suppress_git_status"
printf '%s\n' \
	"container machine run --detach -n domainlease-dev --workdir $ROOT $WRAPPER" \
	> "$JOB_DIR/command.txt"

container machine run --detach -n domainlease-dev \
	--workdir "$ROOT" "$WRAPPER"
printf 'started %s with six build jobs in domainlease-dev\n' "$NAME"
printf 'monitor: cd %s && ./tools/long-job.sh watch %s 30\n' \
	"$ROOT" "$NAME"
watch_if_requested
