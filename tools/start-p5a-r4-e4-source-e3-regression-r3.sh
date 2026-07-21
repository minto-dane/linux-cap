#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=${NAME:-p5a-r4-e4-source-e3-regression-r3}
RUN_ID=${RUN_ID:-20260719T-p5a-r4-e4-source-e3-regression-r3}
JOB_DIR="$ROOT/build/long-jobs/$NAME"
PROBE="$ROOT/tools/probe-$NAME.sh"
WRAPPER="$ROOT/tools/run-$NAME-in-machine.sh"
SOURCE_RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r4-e4-local-quantum-source-gate.sh"
REGRESSION_RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r4-e4-e3-six-profile-regression.sh"
COMBINED_RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r4-e4-source-and-e3-regression.sh"
OUT_DIR="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-source-and-e3-regression/$RUN_ID"
SOURCE_OUT="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-local-quantum-source-gate/$RUN_ID-source"
CONFIG_OUT="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-e3-six-profile-regression/$RUN_ID-config-smoke"
REGRESSION_OUT="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-e3-six-profile-regression/$RUN_ID-e3-regression"
SOURCE_BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r4-e4-source-gate/$RUN_ID-source"
REGRESSION_BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r4-e4-e3-regression/$RUN_ID-e3-regression"
SOURCE_E3_WORKTREE="$ROOT/build/DomainLeaseLinux.volume/worktrees/p5a-r4-e4-source-gate-e3-$RUN_ID-source"
SOURCE_E4_WORKTREE="$ROOT/build/DomainLeaseLinux.volume/worktrees/p5a-r4-e4-source-gate-e4-$RUN_ID-source"
REGRESSION_WORKTREE="$ROOT/build/DomainLeaseLinux.volume/worktrees/p5a-r4-e4-e3-regression-$RUN_ID-e3-regression"
WATCH=0
PREFLIGHT_ONLY=0
EXPECTED_SOURCE_RUNNER_SHA=${EXPECTED_SOURCE_RUNNER_SHA:-8458c7ec6ea8ea8c38d2cee0e358fdfb6eff4e3bf6ec7c53ecf9cbe8241561c5}
EXPECTED_REGRESSION_RUNNER_SHA=${EXPECTED_REGRESSION_RUNNER_SHA:-e4712c30926e2364af9354db88bd5adca9d1b0afc7df0b79428f1621642d7e9c}
EXPECTED_COMBINED_RUNNER_SHA=${EXPECTED_COMBINED_RUNNER_SHA:-cbadfbcb179029102d54482991c586785765839d4f8bd8d200ae186215c4467a}
EXPECTED_ROOT_COMMIT=${EXPECTED_ROOT_COMMIT:-38b533ba2d704df84c902d393abb25198b92e015}
EXPECTED_CAPSCHED_COMMIT=${EXPECTED_CAPSCHED_COMMIT:-0dc0976f8ffbf8c1398975ecdbac9627181e0c39}
EXPECTED_CANDIDATE_COMMIT=${EXPECTED_CANDIDATE_COMMIT:-9e4cb44fd1a1f998fcc288df87dad60505e8bf18}
EXPECTED_CANDIDATE_TREE=${EXPECTED_CANDIDATE_TREE:-e6feb28a29fc8c37bc46af0fbf37de30f3401a4f}

case "${1:-}" in
	'') ;;
	--watch) WATCH=1 ;;
	--preflight-only) PREFLIGHT_ONLY=1 ;;
	*) printf 'usage: %s [--watch|--preflight-only]\n' "$0" >&2; exit 2 ;;
esac

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

watch_if_requested()
{
	if [ "$WATCH" = 1 ]; then
		exec "$ROOT/tools/long-job.sh" watch "$NAME" 30
	fi
}

for tool in container git jq shasum; do
	command -v "$tool" >/dev/null 2>&1 || die "missing command: $tool"
done
for script in "$PROBE" "$WRAPPER" "$SOURCE_RUNNER" "$REGRESSION_RUNNER" "$COMBINED_RUNNER"; do
	[ -x "$script" ] || die "script is not executable: $script"
	[ ! -L "$script" ] || die "script must not be a symlink: $script"
done

mkdir -p "$JOB_DIR"
probe_state=$("$PROBE" 2>/dev/null | sed -n '1p' || true)
if [ "$probe_state" = running ]; then
	printf '%s is already running.\n' "$NAME"
	printf 'monitor: cd %s && ./tools/long-job.sh watch %s 30\n' "$ROOT" "$NAME"
	watch_if_requested
	exit 0
elif [ "$probe_state" = complete ]; then
	printf '%s is already complete.\n' "$NAME"
	watch_if_requested
	exit 0
fi

[ "$(shasum -a 256 "$SOURCE_RUNNER" | awk '{print $1}')" = "$EXPECTED_SOURCE_RUNNER_SHA" ] || die 'source runner hash changed'
[ "$(shasum -a 256 "$REGRESSION_RUNNER" | awk '{print $1}')" = "$EXPECTED_REGRESSION_RUNNER_SHA" ] || die 'regression runner hash changed'
[ "$(shasum -a 256 "$COMBINED_RUNNER" | awk '{print $1}')" = "$EXPECTED_COMBINED_RUNNER_SHA" ] || die 'combined runner hash changed'
[ "$(git -C "$ROOT" rev-parse HEAD)" = "$EXPECTED_ROOT_COMMIT" ] || die 'superproject commit changed'
[ "$(git -C "$ROOT/capsched" rev-parse HEAD)" = "$EXPECTED_CAPSCHED_COMMIT" ] || die 'capsched commit changed'
[ "$(git -C "$ROOT/linux" rev-parse HEAD)" = 5e1ca3037e34823d1ba0cdd1dc04161fac170280 ] || die 'primary Linux changed'
[ "$(git -C "$ROOT/linux-patches" rev-parse HEAD)" = 16bb080da472ffabbbafd2698073eca633fb0602 ] || die 'patch queue changed'
[ "$(git -C "$ROOT/linux" rev-parse refs/heads/codex/p5a-r4-e4-local-quantum-measurement)" = "$EXPECTED_CANDIDATE_COMMIT" ] || die 'local E4 branch changed'
[ "$(git -C "$ROOT/linux" rev-parse refs/remotes/fork/codex/p5a-r4-e4-local-quantum-measurement)" = "$EXPECTED_CANDIDATE_COMMIT" ] || die 'fork E4 branch changed'
[ "$(git -C "$ROOT/linux" rev-parse "$EXPECTED_CANDIDATE_COMMIT^")" = da9ce9159b3450c28c8faf8dceac671fb7bfeba2 ] || die 'E4 parent changed'
[ "$(git -C "$ROOT/linux" rev-parse "$EXPECTED_CANDIDATE_COMMIT^{tree}")" = "$EXPECTED_CANDIDATE_TREE" ] || die 'E4 tree changed'
[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ] || die 'superproject is dirty'
[ -z "$(git -C "$ROOT/capsched" status --porcelain)" ] || die 'capsched is dirty'
[ -z "$(git -C "$ROOT/linux" status --porcelain --untracked-files=no)" ] || die 'primary Linux is dirty'
[ -z "$(git -C "$ROOT/linux-patches" status --porcelain)" ] || die 'patch queue is dirty'

for path in "$OUT_DIR" "$SOURCE_OUT" "$CONFIG_OUT" "$REGRESSION_OUT" \
	"$SOURCE_E3_WORKTREE" "$SOURCE_E4_WORKTREE" "$REGRESSION_WORKTREE"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "run-owned path already exists: $path"
	fi
done

machine_json=$(container machine inspect domainlease-dev)
[ "$(printf '%s\n' "$machine_json" | jq -r '.[0].status')" = running ] || die 'domainlease-dev is not running'
[ "$(printf '%s\n' "$machine_json" | jq -r '.[0].diskSize')" -gt 0 ] || die 'domainlease-dev disk allocation is unavailable'
processes=$(container machine run -n domainlease-dev -- /usr/bin/ps -eo args=)
if printf '%s\n' "$processes" | grep -Eq '[r]un-p5a-r4-e4-source-e3-regression|[r]un-sched-exec-lease-p5a-r4-e4|[q]emu-system-(aarch64|x86_64)|[m]ake -C .*p5a-r4-e4'; then
	die 'an R4-E4 gate, QEMU, or build process is already active'
fi
container machine run -n domainlease-dev -- mkdir -p /var/tmp/linux-cap-builds/p5a-r4-e4-source-gate /var/tmp/linux-cap-builds/p5a-r4-e4-e3-regression
[ "$(container machine run -n domainlease-dev -- stat -f -c %T /var/tmp/linux-cap-builds/p5a-r4-e4-e3-regression)" = ext2/ext3 ] || die 'VM build root is not internal ext4'
container machine run -n domainlease-dev -- test ! -e "$SOURCE_BUILD_ROOT"
container machine run -n domainlease-dev -- test ! -e "$REGRESSION_BUILD_ROOT"
internal_available_kib=$(container machine run -n domainlease-dev -- df -Pk /var/tmp/linux-cap-builds/p5a-r4-e4-e3-regression | awk 'NR == 2 {print $4}')
[ "$internal_available_kib" -ge 6291456 ] || die "VM requires at least 6 GiB free; only $internal_available_kib KiB available"
host_available_kib=$(df -Pk "$ROOT" | awk 'NR == 2 {print $4}')
[ "$host_available_kib" -ge 12582912 ] || die "host requires at least 12 GiB free; only $host_available_kib KiB available"

if [ "$PREFLIGHT_ONLY" = 1 ]; then
	printf 'preflight passed: exact inputs, clean repositories, VM, and storage are launch-ready\n'
	exit 0
fi

: > "$JOB_DIR/job.log"
find "$JOB_DIR/exit_code" "$JOB_DIR/finished_at" "$JOB_DIR/failure_reason" \
	"$JOB_DIR/progress" "$JOB_DIR/vm_exit_code" "$JOB_DIR/vm_finished_at" \
	-type f -delete 2>/dev/null || true
printf '%s\n' external > "$JOB_DIR/mode"
printf '%s\n' running > "$JOB_DIR/state"
printf '%s\n' external > "$JOB_DIR/pid"
date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/started_at"
printf '%s\n' "$OUT_DIR" > "$JOB_DIR/watch_path"
printf '%s\n' "$PROBE" > "$JOB_DIR/probe_path"
: > "$JOB_DIR/suppress_git_status"
printf '%s\n%s\n' "$SOURCE_BUILD_ROOT" "$REGRESSION_BUILD_ROOT" > "$JOB_DIR/internal_build_path"
printf '%s\n' \
	"container machine run --detach -n domainlease-dev --workdir $ROOT $WRAPPER" \
	> "$JOB_DIR/command.txt"

container machine run --detach -n domainlease-dev --workdir "$ROOT" "$WRAPPER"

printf 'started %s in Apple Container machine domainlease-dev\n' "$NAME"
printf 'monitor: cd %s && ./tools/long-job.sh watch %s 30\n' "$ROOT" "$NAME"
watch_if_requested
