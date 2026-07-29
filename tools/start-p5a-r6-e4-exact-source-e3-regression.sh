#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r6-e4-exact-source-e3-regression
RUN_ID=20260730T-p5a-r6-e4-e3-regression-r1
JOB_DIR="$ROOT/build/long-jobs/$NAME"
PROBE="$ROOT/tools/probe-$NAME.sh"
WRAPPER="$ROOT/tools/run-$NAME-in-machine.sh"
OUT_DIR="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression/$RUN_ID"
RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r6-e4-exact-source-e3-regression.sh"
CONTRACT="$ROOT/capsched/capsched-models/analysis/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-v1.json"
SOURCE_GATE="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e4-local-quantum-source-gate/20260729T-p5a-r6-e4-source-gate/result.json"
CANDIDATE_DIR="$ROOT/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e4-local-quantum-measurement"
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

[ "$(shasum -a 256 "$RUNNER" | awk '{print $1}')" = \
	670c314a6e66bcb6e88176765920f97ba9c9807a13ffbb98e2bf6a6bcc613364 ]
[ "$(shasum -a 256 "$CONTRACT" | awk '{print $1}')" = \
	ade8e74b7f7488e49a0a656b379ed5179e77509dcc68b7c7f6cac014d07dbd30 ]
[ "$(shasum -a 256 "$SOURCE_GATE" | awk '{print $1}')" = \
	ab5b33650dafb275ffc281ca7f0828aa3db11d8ca301f82c06980399bc3404e6 ]
jq -e '
  .status == "passed_r6_e4_source_build_gate" and
  .candidate_commit ==
    "d51ebdc657a1040e423735584775e66399f321f9" and
  .e3_shared_helpers_changed == true and
  .e3_four_profile_regression_required == true and
  .e3_four_profile_regression_passed == false and
  .r6_e4_source_accepted == false and
  .measurement_authorized == false
' "$SOURCE_GATE" >/dev/null
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = \
	d51ebdc657a1040e423735584775e66399f321f9 ]
[ "$(git -C "$CANDIDATE_DIR" rev-parse \
	refs/remotes/fork/codex/p5a-r6-e4-local-quantum-measurement)" = \
	d51ebdc657a1040e423735584775e66399f321f9 ]
[ -z "$(git -C "$CANDIDATE_DIR" status \
	--porcelain --untracked-files=no)" ]
[ "$(git -C "$ROOT/capsched" rev-parse HEAD)" = \
	"$(git -C "$ROOT/capsched" rev-parse \
	refs/remotes/origin/codex/r6-e4-exact-source-e3-regression)" ]
[ "$(git -C "$ROOT" rev-parse HEAD)" = \
	"$(git -C "$ROOT" rev-parse \
	refs/remotes/origin/codex/r6-e4-exact-source-e3-regression)" ]
[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]
[ "$(container machine inspect domainlease-dev |
	jq -r '.[0].status')" = running ]
[ ! -e "$OUT_DIR" ]

processes=$(container machine run -n domainlease-dev \
	/usr/bin/ps -eo args=)
if printf '%s\n' "$processes" |
	grep -Eq \
		'[r]un-p5a-r6-e4-exact-source-e3-regression|[r]un-sched-exec-lease-p5a-r6-e4-exact-source-e3-regression|[q]emu-system-(aarch64|x86_64)|[m]ake -C .*p5a-r6-e4-local-quantum-measurement'; then
	printf 'error: exact-source E3 regression process is already active\n' >&2
	exit 1
fi
guest_cpus=$(container machine run -n domainlease-dev nproc)
[ "$guest_cpus" -ge 6 ] || {
	printf 'error: regression requires 6 guest CPUs; only %s available\n' \
		"$guest_cpus" >&2
	exit 1
}
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
	printf 'error: regression requires 8 GiB internal space; only %s KiB available\n' \
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
printf 'started %s with six build jobs on six guest CPUs\n' "$NAME"
printf 'monitor: cd %s && ./tools/long-job.sh watch %s 30\n' \
	"$ROOT" "$NAME"
watch_if_requested
