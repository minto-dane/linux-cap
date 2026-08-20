#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r6-e3-source-gate
RUN_ID=20260726T-p5a-r6-e3-source-gate-r1
JOB_DIR="$ROOT/build/long-jobs/$NAME"
PROBE="$ROOT/tools/probe-$NAME.sh"
WRAPPER="$ROOT/tools/run-$NAME-in-machine.sh"
BUILD_ROOT="$ROOT/build/DomainLeaseLinux.volume/builds/p5a-r6-e3-source-gate/$RUN_ID"
OUT_DIR="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e3-correctness-source-gate/$RUN_ID"
RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r6-e3-correctness-source-gate.sh"
PLAN_R3="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan/20260726T-p5a-r6-e3-correctness-plan-r3/result.json"
PLAN_R4="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan/20260726T-p5a-r6-e3-correctness-plan-r4/result.json"
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

[ "$(shasum -a 256 "$PLAN_R3" | awk '{print $1}')" = \
	7a1c6bc4079ab24b34cce54efa3817f210b07502b077e5a8bed4f0944c5eebe2 ]
[ "$(shasum -a 256 "$PLAN_R4" | awk '{print $1}')" = \
	6f989baf4b90f3647948d496863ef7d5024fa4d58774968cf5b7a17b15787917 ]
[ "$(shasum -a 256 "$RUNNER" | awk '{print $1}')" = \
	2416b0e844385e9e7eb1142d4b3f04523e1af0fde6c401b254eeec0bed199c99 ]
[ "$(git -C "$ROOT/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e3-correctness-prototype" \
	rev-parse HEAD)" = 99287291f1c8e0d6c1b3ea86d121508c5547f424 ]
[ "$(git -C "$ROOT/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e3-correctness-prototype" \
	rev-parse refs/remotes/fork/codex/p5a-r6-e3-correctness-prototype)" = \
	99287291f1c8e0d6c1b3ea86d121508c5547f424 ]
[ "$(git -C "$ROOT/capsched" rev-parse HEAD)" = \
	075d4115810f7cda48e03f00994be119e7b65241 ]
[ "$(git -C "$ROOT/capsched" rev-parse \
	refs/remotes/origin/codex/r4-e3-source)" = \
	075d4115810f7cda48e03f00994be119e7b65241 ]
[ "$(container machine inspect domainlease-dev | jq -r '.[0].status')" = \
	running ]
[ ! -e "$BUILD_ROOT" ]
[ ! -e "$OUT_DIR" ]

processes=$(container machine run -n domainlease-dev \
	/usr/bin/ps -eo args=)
if printf '%s\n' "$processes" |
	grep -Eq \
		'[r]un-p5a-r6-e3-source-gate|[r]un-sched-exec-lease-p5a-r6-e3-correctness-source-gate|[m]ake -C .*p5a-r6-e3-source-gate'; then
	printf 'error: R6-E3 source-gate process is already active\n' >&2
	exit 1
fi
available_kib=$(df -Pk "$ROOT/build/DomainLeaseLinux.volume" |
	awk 'NR == 2 {print $4}')
[ "$available_kib" -ge 8388608 ] || {
	printf 'error: source gate requires 8 GiB; only %s KiB available\n' \
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
