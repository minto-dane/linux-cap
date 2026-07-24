#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r6-e2-dual-arch-build
JOB_DIR="$ROOT/build/long-jobs/$NAME"
PROBE="$ROOT/tools/probe-$NAME.sh"
WRAPPER="$ROOT/tools/run-$NAME-in-machine.sh"
BUILD_ROOT="$ROOT/build/DomainLeaseLinux.volume/builds/p5a-r6-e2-dual-arch/20260725T-p5a-r6-e2-dual-arch-r1"
SOURCE_GATE="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e2-source-gate/20260725T-p5a-r6-e2-source-gate-r1/result.json"
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
	watch_if_requested
	exit 0
elif [ "$probe_state" = complete ]; then
	printf '%s is already complete.\n' "$NAME"
	watch_if_requested
	exit 0
fi

jq -e '
  .status == "passed_r6_e2_source_gate" and
  .candidate_commit == "66e2fd20fc85012d7dc03649fcf4c7af583cbb94" and
  .direct_primary_child == true and .exact_two_file_boundary == true and
  .private_symbol_count == 49 and
  .dual_arch_layout_build_may_start == true and
  .r6_e3_source_may_start == false
' "$SOURCE_GATE" >/dev/null
[ "$(shasum -a 256 "$SOURCE_GATE" | awk '{print $1}')" = \
	18c329d9f10a34559056f8ef00007f9d6644b82b5d4be5f8227a4d7f8f9d452f ]
[ "$(git -C "$ROOT/linux" rev-parse HEAD)" = \
	5e1ca3037e34823d1ba0cdd1dc04161fac170280 ]
[ "$(git -C "$ROOT/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e2-layout" \
	rev-parse HEAD)" = 66e2fd20fc85012d7dc03649fcf4c7af583cbb94 ]
[ "$(container machine inspect domainlease-dev | jq -r '.[0].status')" = running ]
available_kib=$(df -Pk "$ROOT/build/DomainLeaseLinux.volume" |
	awk 'NR == 2 {print $4}')
[ "$available_kib" -ge 6291456 ] || {
	printf 'error: R6-E2 requires at least 6 GiB free; only %s KiB available\n' \
		"$available_kib" >&2
	exit 1
}

: > "$JOB_DIR/job.log"
rm -f "$JOB_DIR/exit_code" "$JOB_DIR/finished_at" \
	"$JOB_DIR/failure_reason" "$JOB_DIR/progress" \
	"$JOB_DIR/vm_exit_code" "$JOB_DIR/vm_finished_at"
printf '%s\n' external > "$JOB_DIR/mode"
printf '%s\n' running > "$JOB_DIR/state"
printf '%s\n' external > "$JOB_DIR/pid"
date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/started_at"
printf '%s\n' "$BUILD_ROOT" > "$JOB_DIR/watch_path"
printf '%s\n' "$PROBE" > "$JOB_DIR/probe_path"
: > "$JOB_DIR/suppress_git_status"
printf '%s\n' \
	"container machine run --detach -n domainlease-dev --workdir $ROOT $WRAPPER" \
	> "$JOB_DIR/command.txt"

container machine run --detach -n domainlease-dev \
	--workdir "$ROOT" "$WRAPPER"
printf 'started %s in Apple Container machine domainlease-dev\n' "$NAME"
printf 'monitor: cd %s && ./tools/long-job.sh watch %s 30\n' \
	"$ROOT" "$NAME"
watch_if_requested
