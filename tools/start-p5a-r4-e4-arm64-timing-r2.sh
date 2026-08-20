#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r4-e4-arm64-timing-r2
RUN_ID=20260720T-p5a-r4-e4-arm64-timing-r2
JOB_DIR="$ROOT/build/long-jobs/$NAME"
PROBE="$ROOT/tools/probe-$NAME.sh"
WRAPPER="$ROOT/tools/run-$NAME-in-machine.sh"
RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement.sh"
PARSER="$ROOT/capsched/capsched-models/validation/parse-sched-exec-lease-p5a-r4-e4-measurement-evidence.sh"
PARSER_TEST="$ROOT/capsched/capsched-models/validation/test-sched-exec-lease-p5a-r4-e4-measurement-parser.sh"
CLASSIFIER="$ROOT/capsched/capsched-models/validation/lib/kernel-warning-classifier.sh"
CLOSURE_RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure.sh"
CLOSURE_TEST="$ROOT/capsched/capsched-models/validation/test-sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure.sh"
CLOSURE_ROOT="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure"
CLOSURE_R1="$CLOSURE_ROOT/20260720T-p5a-r4-e4-source-e3-final-closure-r1"
CLOSURE_R2="$CLOSURE_ROOT/20260720T-p5a-r4-e4-source-e3-final-closure-r2"
CONFIG_SMOKE="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/20260720T-p5a-r4-e4-arm64-timing-config-smoke-r6"
CLEANUP_NEGATIVE="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/20260720T-p5a-r4-e4-arm64-timing-cleanup-negative-r2"
OUT_DIR="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/$RUN_ID"
BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement/$RUN_ID"
WORKTREE="/var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement/$RUN_ID"
WATCH=0
PREFLIGHT_ONLY=0

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

file_sha()
{
	shasum -a 256 "$1" | awk '{print $1}'
}

watch_if_requested()
{
	if [ "$WATCH" = 1 ]; then
		exec "$ROOT/tools/long-job.sh" watch "$NAME" 30
	fi
}

for command in container df git jq shasum sw_vers sysctl uname; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
for script in "$PROBE" "$WRAPPER" "$RUNNER" "$PARSER" "$PARSER_TEST" \
	"$CLOSURE_RUNNER" "$CLOSURE_TEST"; do
	if [ ! -f "$script" ] || [ ! -x "$script" ]; then
		die "script is not executable: $script"
	fi
	[ ! -L "$script" ] || die "script must not be a symlink: $script"
done
if [ ! -f "$CLASSIFIER" ] || [ ! -r "$CLASSIFIER" ]; then
	die "warning classifier is not readable: $CLASSIFIER"
fi
[ ! -L "$CLASSIFIER" ] || die "warning classifier must not be a symlink: $CLASSIFIER"

mkdir -p "$JOB_DIR"
probe_state=$({ "$PROBE" 2>/dev/null || true; } | sed -n '1p')
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

[ "$(file_sha "$RUNNER")" = a3ee78f5ae1bc32a89bfb0b765a9e87da3888536c0bdb658b2f88acf71ddf392 ] || die 'timing runner hash changed'
[ "$(file_sha "$PARSER")" = dd0372d385bbc0a84c6faedf67ee3596f4766205a125c44e33b9a91652bc2cd1 ] || die 'timing parser hash changed'
[ "$(file_sha "$PARSER_TEST")" = b057af2a23d1bbd95eff6bb165eadd81511ca8549ce609a9a5a7411f4a206db0 ] || die 'timing parser test hash changed'
[ "$(file_sha "$CLASSIFIER")" = 8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a ] || die 'warning classifier hash changed'
[ "$(file_sha "$CLOSURE_RUNNER")" = 271fd7a0d7ab5c62f630e52a3b20c584e9233769760d6b25b586af8182995fba ] || die 'closure runner hash changed'
[ "$(file_sha "$CLOSURE_TEST")" = 4e19dc7ddefd41347cc39753ca67da271833e1655ed7340614ba06a17e5a1644 ] || die 'closure tests changed'
[ "$(file_sha "$CLOSURE_R1/result.json")" = 5e3ff71d2fea01b29e20b23a9bb8e1a8479d70cc847fa49aa3d33295c8040f3f ] || die 'closure r1 result hash changed'
[ "$(file_sha "$CLOSURE_R2/result.json")" = bac2aca6649c40fdf21665a0f801be1f0751ef03c437d1b506f78ba77f04f720 ] || die 'closure r2 result hash changed'
[ "$(file_sha "$CLOSURE_R1/result.normalized.json")" = 767d2f9ab1bfb6e0c918c2ba0b51147ba79f236085e6985097b14e5a8da43d21 ] || die 'closure r1 normalized decision changed'
[ "$(file_sha "$CLOSURE_R2/result.normalized.json")" = 767d2f9ab1bfb6e0c918c2ba0b51147ba79f236085e6985097b14e5a8da43d21 ] || die 'closure r2 normalized decision changed'
cmp "$CLOSURE_R1/result.normalized.json" "$CLOSURE_R2/result.normalized.json" >/dev/null || die 'closure normalized decisions differ'
[ -z "$(find "$CLOSURE_R1/inputs" "$CLOSURE_R2/inputs" -type f -perm -222 -print -quit)" ] || die 'closure inputs became writable'

[ "$(git -C "$ROOT" rev-parse HEAD)" = 44d05b662046ceeec66d8d1921fc7b4986c08d77 ] || die 'superproject commit changed'
[ "$(git -C "$ROOT" rev-parse refs/remotes/origin/codex/r4-e3-source)" = 44d05b662046ceeec66d8d1921fc7b4986c08d77 ] || die 'pushed superproject branch changed'
[ "$(git -C "$ROOT/capsched" rev-parse HEAD)" = 1d12765a59c0203201666f0289252e63b6b921f3 ] || die 'capsched commit changed'
[ "$(git -C "$ROOT/capsched" rev-parse refs/remotes/origin/codex/r4-e3-source)" = 1d12765a59c0203201666f0289252e63b6b921f3 ] || die 'pushed capsched branch changed'
[ "$(git -C "$ROOT/linux" rev-parse HEAD)" = 5e1ca3037e34823d1ba0cdd1dc04161fac170280 ] || die 'primary Linux changed'
[ "$(git -C "$ROOT/linux-patches" rev-parse HEAD)" = 16bb080da472ffabbbafd2698073eca633fb0602 ] || die 'patch queue changed'
[ "$(git -C "$ROOT/linux" rev-parse refs/heads/codex/p5a-r4-e4-local-quantum-measurement)" = 5857720dedc49f89d2367442f8fdb1a806ffa1cc ] || die 'local E4 candidate moved'
[ "$(git -C "$ROOT/linux" rev-parse refs/remotes/fork/codex/p5a-r4-e4-local-quantum-measurement)" = 5857720dedc49f89d2367442f8fdb1a806ffa1cc ] || die 'pushed E4 candidate moved'
[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ] || die 'superproject tracked state is dirty'
[ -z "$(git -C "$ROOT/capsched" status --porcelain)" ] || die 'capsched is dirty'
[ -z "$(git -C "$ROOT/linux" status --porcelain --untracked-files=no)" ] || die 'primary Linux is dirty'
[ -z "$(git -C "$ROOT/linux-patches" status --porcelain)" ] || die 'patch queue is dirty'

grep -Fxq '100% exact arm64 timing config smoke passed; builds=0 boots=0 scratch retired' "$CONFIG_SMOKE/progress" || die 'final config smoke progress changed'
[ "$(file_sha "$CONFIG_SMOKE/raw/measurement-runner.sh")" = a3ee78f5ae1bc32a89bfb0b765a9e87da3888536c0bdb658b2f88acf71ddf392 ] || die 'config smoke used another runner'
grep -Fxq 'CONFIG_NR_CPUS=2' "$CONFIG_SMOKE/raw/arm64.config" || die 'config smoke topology changed'
jq -e '.status == "harness_failed" and .failure.stage == "worktree" and .run_owned_build_scratch_retired == true and .run_owned_worktree_retired == true' "$CLEANUP_NEGATIVE/result.json" >/dev/null || die 'forced-failure cleanup evidence changed'
[ "$(file_sha "$CLEANUP_NEGATIVE/raw/measurement-runner.sh")" = a3ee78f5ae1bc32a89bfb0b765a9e87da3888536c0bdb658b2f88acf71ddf392 ] || die 'cleanup control used another runner'

if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run-owned output already exists: $OUT_DIR"
fi
machine_json=$(container machine inspect domainlease-dev)
[ "$(printf '%s\n' "$machine_json" | jq -r '.[0].status')" = running ] || die 'domainlease-dev is not running'
processes=$(container machine run -n domainlease-dev /usr/bin/ps -eo args=)
if printf '%s\n' "$processes" | grep -Eq '[r]un-p5a-r4-e4-arm64-timing|[r]un-sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement|[q]emu-system-(aarch64|x86_64)|[m]ake -C /var/tmp/linux-cap-worktrees/p5a-r4-e4'; then
	die 'an R4-E4 timing, QEMU, or build process is already active'
fi
container machine run -n domainlease-dev mkdir -p /var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement /var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement
[ "$(container machine run -n domainlease-dev stat -f -c %T /var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement)" = ext2/ext3 ] || die 'VM build root is not internal ext4'
container machine run -n domainlease-dev test ! -e "$BUILD_ROOT"
container machine run -n domainlease-dev test ! -e "$WORKTREE"
vm_available_kib=$(container machine run -n domainlease-dev df -Pk /var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement | awk 'NR==2 {print $4}')
[ "$vm_available_kib" -ge 16777216 ] || die "VM requires 16 GiB free; only $vm_available_kib KiB available"
host_available_kib=$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')
[ "$host_available_kib" -ge 4194304 ] || die "host requires 4 GiB free; only $host_available_kib KiB available"

container machine run -n domainlease-dev --workdir "$ROOT" "$CLOSURE_TEST" > "$JOB_DIR/closure-preflight.log"
container machine run -n domainlease-dev --workdir "$ROOT" "$PARSER_TEST" > "$JOB_DIR/parser-preflight.log"

if [ "$PREFLIGHT_ONLY" = 1 ]; then
	printf 'preflight passed: pushed commits, exact replacement closures, runner/parser, smoke, cleanup, VM, storage, and clean paths are launch-ready\n'
	exit 0
fi

{
	uname -a
	sw_vers
	printf 'logical_cpus='; sysctl -n hw.logicalcpu
	container --version
	printf 'workspace_available_kib='; df -Pk "$ROOT" | awk 'NR==2 {print $4}'
	printf 'vm_internal_available_kib=%s\n' "$vm_available_kib"
} > "$JOB_DIR/outer-host-environment.txt"
: > "$JOB_DIR/job.log"
find "$JOB_DIR/exit_code" "$JOB_DIR/finished_at" "$JOB_DIR/failure_reason" \
	"$JOB_DIR/progress" "$JOB_DIR/vm_exit_code" "$JOB_DIR/vm_finished_at" \
	-type f -delete 2>/dev/null || true
printf 'external\n' > "$JOB_DIR/mode"
printf 'running\n' > "$JOB_DIR/state"
printf 'external\n' > "$JOB_DIR/pid"
date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/started_at"
printf '%s\n' "$OUT_DIR" > "$JOB_DIR/watch_path"
printf '%s\n' "$PROBE" > "$JOB_DIR/probe_path"
: > "$JOB_DIR/suppress_git_status"
printf '%s\n%s\n' "$BUILD_ROOT" "$WORKTREE" > "$JOB_DIR/internal_build_path"
printf 'container machine run --detach -n domainlease-dev --workdir %s %s\n' "$ROOT" "$WRAPPER" > "$JOB_DIR/command.txt"

container machine run --detach -n domainlease-dev --workdir "$ROOT" "$WRAPPER"

printf 'started %s in Apple Container machine domainlease-dev\n' "$NAME"
printf 'monitor: cd %s && ./tools/long-job.sh watch %s 30\n' "$ROOT" "$NAME"
watch_if_requested
