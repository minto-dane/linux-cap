#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r4-e4-arm64-timing-r4
RUN_ID=20260721T-p5a-r4-e4-arm64-timing-r4
JOB_DIR="$ROOT/build/long-jobs/$NAME"
PROBE="$ROOT/tools/probe-$NAME.sh"
WRAPPER="$ROOT/tools/run-$NAME-in-machine.sh"
RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement.sh"
QMP_CONTROL="$ROOT/capsched/capsched-models/validation/qmp-sched-exec-lease-vcpu-control.py"
QMP_TEST="$ROOT/capsched/capsched-models/validation/test-sched-exec-lease-p5a-r4-e4-qmp-vcpu-control.sh"
PARSER="$ROOT/capsched/capsched-models/validation/parse-sched-exec-lease-p5a-r4-e4-measurement-evidence.sh"
PARSER_TEST="$ROOT/capsched/capsched-models/validation/test-sched-exec-lease-p5a-r4-e4-measurement-parser.sh"
CLASSIFIER="$ROOT/capsched/capsched-models/validation/lib/kernel-warning-classifier.sh"
SOURCE_CLOSURE_RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure.sh"
SOURCE_CLOSURE_TEST="$ROOT/capsched/capsched-models/validation/test-sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure.sh"
R2_FAILURE_CLOSURE_RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r4-e4-arm64-timing-failure-closure.sh"
R3_STORAGE_CLOSURE_RUNNER="$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-p5a-r4-e4-arm64-timing-r3-storage-failure-closure.sh"
SOURCE_CLOSURE_ROOT="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure"
SOURCE_CLOSURE_R1="$SOURCE_CLOSURE_ROOT/20260720T-p5a-r4-e4-source-e3-final-closure-r1"
SOURCE_CLOSURE_R2="$SOURCE_CLOSURE_ROOT/20260720T-p5a-r4-e4-source-e3-final-closure-r2"
R2_FAILURE_CLOSURE_ROOT="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-failure-closure"
R2_FAILURE_CLOSURE_R1="$R2_FAILURE_CLOSURE_ROOT/20260721T-p5a-r4-e4-arm64-timing-r2-failure-closure-r1"
R2_FAILURE_CLOSURE_R2="$R2_FAILURE_CLOSURE_ROOT/20260721T-p5a-r4-e4-arm64-timing-r2-failure-closure-r2"
R3_STORAGE_CLOSURE_ROOT="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-r3-storage-failure-closure"
R3_STORAGE_CLOSURE_R1="$R3_STORAGE_CLOSURE_ROOT/20260721T-p5a-r4-e4-arm64-timing-r3-storage-failure-closure-r1"
R3_STORAGE_CLOSURE_R2="$R3_STORAGE_CLOSURE_ROOT/20260721T-p5a-r4-e4-arm64-timing-r3-storage-failure-closure-r2"
R3_RESULT="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/20260721T-p5a-r4-e4-arm64-timing-r3/result.json"
CONFIG_SMOKE="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/20260721T-p5a-r4-e4-arm64-timing-config-smoke-r8"
CLEANUP_NEGATIVE="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/20260721T-p5a-r4-e4-arm64-timing-cleanup-negative-r3"
CAPACITY_NEGATIVE="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/20260721T-p5a-r4-e4-host-capacity-negative-r2"
OUT_DIR="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/$RUN_ID"
BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement/$RUN_ID"
WORKTREE="/var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement/$RUN_ID"
CAPSCHED_COMMIT=153a27c01256bfa0610bca9592886420666df7ab
HOST_MIN_KIB=33554432
VM_MIN_KIB=16777216
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

for command in awk cmp container df find git grep jq sed shasum sw_vers sysctl uname; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
for script in "$PROBE" "$WRAPPER" "$RUNNER" "$QMP_CONTROL" "$QMP_TEST" \
	"$PARSER" "$PARSER_TEST" "$SOURCE_CLOSURE_RUNNER" \
	"$SOURCE_CLOSURE_TEST" "$R2_FAILURE_CLOSURE_RUNNER" \
	"$R3_STORAGE_CLOSURE_RUNNER"; do
	if [ ! -f "$script" ] || [ ! -x "$script" ]; then
		die "script is not executable: $script"
	fi
	[ ! -L "$script" ] || die "script must not be a symlink: $script"
done
if [ ! -f "$CLASSIFIER" ] || [ ! -r "$CLASSIFIER" ]; then
	die "warning classifier is not readable: $CLASSIFIER"
fi
[ ! -L "$CLASSIFIER" ] || die 'warning classifier must not be a symlink'

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

[ "$(file_sha "$RUNNER")" = 2fe52b6e9bfbc57ccca43c6e45fc3c18b15e196967822c34743b202480385e69 ] || die 'timing runner hash changed'
[ "$(file_sha "$QMP_CONTROL")" = e59bc8ad5adb50ddf66652b28a424afd1efbd28a9501e786771d5fb1f8da147e ] || die 'QMP vCPU control hash changed'
[ "$(file_sha "$QMP_TEST")" = 06c5f057cb4507b53b2b6cb6f55a3c35d150cd561cf282ac3681f41d17650876 ] || die 'QMP vCPU control test hash changed'
[ "$(file_sha "$PARSER")" = dd0372d385bbc0a84c6faedf67ee3596f4766205a125c44e33b9a91652bc2cd1 ] || die 'timing parser hash changed'
[ "$(file_sha "$PARSER_TEST")" = b057af2a23d1bbd95eff6bb165eadd81511ca8549ce609a9a5a7411f4a206db0 ] || die 'timing parser test hash changed'
[ "$(file_sha "$CLASSIFIER")" = 8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a ] || die 'warning classifier hash changed'
[ "$(file_sha "$SOURCE_CLOSURE_RUNNER")" = 271fd7a0d7ab5c62f630e52a3b20c584e9233769760d6b25b586af8182995fba ] || die 'source closure runner hash changed'
[ "$(file_sha "$SOURCE_CLOSURE_TEST")" = 4e19dc7ddefd41347cc39753ca67da271833e1655ed7340614ba06a17e5a1644 ] || die 'source closure tests changed'
[ "$(file_sha "$R2_FAILURE_CLOSURE_RUNNER")" = 0610b76838bbd4eeb65625b490ac3bbb93331526b283b86d1969c6a71916881d ] || die 'r2 failure closure runner hash changed'
[ "$(file_sha "$R3_STORAGE_CLOSURE_RUNNER")" = c425c924ef0f61b46ead7797f61f1ec14ee933825f31d960cc837ebe27cc1578 ] || die 'r3 storage closure runner hash changed'

[ "$(file_sha "$SOURCE_CLOSURE_R1/result.json")" = 5e3ff71d2fea01b29e20b23a9bb8e1a8479d70cc847fa49aa3d33295c8040f3f ] || die 'source closure r1 result changed'
[ "$(file_sha "$SOURCE_CLOSURE_R2/result.json")" = bac2aca6649c40fdf21665a0f801be1f0751ef03c437d1b506f78ba77f04f720 ] || die 'source closure r2 result changed'
for closure in "$SOURCE_CLOSURE_R1" "$SOURCE_CLOSURE_R2"; do
	[ "$(file_sha "$closure/result.normalized.json")" = 767d2f9ab1bfb6e0c918c2ba0b51147ba79f236085e6985097b14e5a8da43d21 ] || die 'source closure normalized decision changed'
done
cmp "$SOURCE_CLOSURE_R1/result.normalized.json" "$SOURCE_CLOSURE_R2/result.normalized.json" >/dev/null || die 'source closure decisions differ'
[ -z "$(find "$SOURCE_CLOSURE_R1/inputs" "$SOURCE_CLOSURE_R2/inputs" -type f -perm -222 -print -quit)" ] || die 'source closure inputs became writable'

[ "$(file_sha "$R2_FAILURE_CLOSURE_R1/result.json")" = 749777dbd6e9310538f76146650eca52d6c9d6c721645cb21c99cda196a0b705 ] || die 'r2 failure closure r1 changed'
[ "$(file_sha "$R2_FAILURE_CLOSURE_R2/result.json")" = 83ec59df2275ab6d6b8c6a9fe2aed9ecb12156ae318b991a9fa1829d47b37e66 ] || die 'r2 failure closure r2 changed'
for closure in "$R2_FAILURE_CLOSURE_R1" "$R2_FAILURE_CLOSURE_R2"; do
	[ "$(file_sha "$closure/result.normalized.json")" = 9c079b47fae1b7ae45baa6cd7517a9b02af2d6b3f4a9780f180366932e3178ef ] || die 'r2 failure normalized decision changed'
done
cmp "$R2_FAILURE_CLOSURE_R1/result.normalized.json" "$R2_FAILURE_CLOSURE_R2/result.normalized.json" >/dev/null || die 'r2 failure decisions differ'
[ -z "$(find "$R2_FAILURE_CLOSURE_R1/inputs" "$R2_FAILURE_CLOSURE_R2/inputs" -type f -perm -222 -print -quit)" ] || die 'r2 failure closure inputs became writable'

[ "$(file_sha "$R3_RESULT")" = a35076dc95800d34c39bf3cc38f6e6a7c429aac69a8c1bb88278b48f4669a689 ] || die 'r3 failure result changed'
[ "$(file_sha "$R3_STORAGE_CLOSURE_R1/result.json")" = e7d2bb95d9f5899fdbf50a4962d8f2175d879218ccc85135766ef8b9c430700c ] || die 'r3 storage closure r1 changed'
[ "$(file_sha "$R3_STORAGE_CLOSURE_R2/result.json")" = b1f44a63b233182f401f9cc65b5e1176c2874b4915d22d89104e0de556d72b03 ] || die 'r3 storage closure r2 changed'
for closure in "$R3_STORAGE_CLOSURE_R1" "$R3_STORAGE_CLOSURE_R2"; do
	[ "$(file_sha "$closure/result.normalized.json")" = da37226ef0bc0bb6587ce1b234cbdacb09ad133e27986473bc2e7bca5182a624 ] || die 'r3 storage normalized decision changed'
	jq -e '.status == "passed_independent_arm64_timing_host_storage_failure_closure" and .architecture_measurement_valid == false and .x86_64_measurement_may_start == false' "$closure/result.json" >/dev/null || die 'r3 storage closure semantics changed'
done
cmp "$R3_STORAGE_CLOSURE_R1/result.normalized.json" "$R3_STORAGE_CLOSURE_R2/result.normalized.json" >/dev/null || die 'r3 storage decisions differ'
[ -z "$(find "$R3_STORAGE_CLOSURE_R1/inputs" "$R3_STORAGE_CLOSURE_R2/inputs" -type f -perm -222 -print -quit)" ] || die 'r3 storage closure inputs became writable'

[ "$(git -C "$ROOT" branch --show-current)" = codex/r4-e3-source ] || die 'superproject branch changed'
root_head=$(git -C "$ROOT" rev-parse HEAD)
[ "$root_head" = "$(git -C "$ROOT" rev-parse refs/remotes/origin/codex/r4-e3-source)" ] || die 'superproject HEAD is not pushed'
[ "$(git -C "$ROOT" ls-tree HEAD capsched | awk '{print $3}')" = "$CAPSCHED_COMMIT" ] || die 'superproject capsched gitlink changed'
[ "$(git -C "$ROOT/capsched" rev-parse HEAD)" = "$CAPSCHED_COMMIT" ] || die 'capsched commit changed'
[ "$(git -C "$ROOT/capsched" rev-parse refs/remotes/origin/codex/r4-e3-source)" = "$CAPSCHED_COMMIT" ] || die 'capsched commit is not pushed'
[ "$(git -C "$ROOT/linux" rev-parse HEAD)" = 5e1ca3037e34823d1ba0cdd1dc04161fac170280 ] || die 'primary Linux changed'
[ "$(git -C "$ROOT/linux-patches" rev-parse HEAD)" = 16bb080da472ffabbbafd2698073eca633fb0602 ] || die 'patch queue changed'
[ "$(git -C "$ROOT/linux" rev-parse refs/heads/codex/p5a-r4-e4-local-quantum-measurement)" = 5857720dedc49f89d2367442f8fdb1a806ffa1cc ] || die 'local E4 candidate moved'
[ "$(git -C "$ROOT/linux" rev-parse refs/remotes/fork/codex/p5a-r4-e4-local-quantum-measurement)" = 5857720dedc49f89d2367442f8fdb1a806ffa1cc ] || die 'pushed E4 candidate moved'
[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ] || die 'superproject tracked state is dirty'
[ -z "$(git -C "$ROOT/capsched" status --porcelain)" ] || die 'capsched is dirty'
[ -z "$(git -C "$ROOT/linux" status --porcelain --untracked-files=no)" ] || die 'primary Linux is dirty'
[ -z "$(git -C "$ROOT/linux-patches" status --porcelain)" ] || die 'patch queue is dirty'

grep -Fxq '100% exact arm64 timing config smoke passed; builds=0 boots=0 scratch retired' "$CONFIG_SMOKE/progress" || die 'config smoke progress changed'
[ "$(file_sha "$CONFIG_SMOKE/raw/measurement-runner.sh")" = 2fe52b6e9bfbc57ccca43c6e45fc3c18b15e196967822c34743b202480385e69 ] || die 'config smoke used another runner'
[ "$(file_sha "$CONFIG_SMOKE/raw/qmp-vcpu-control.py")" = e59bc8ad5adb50ddf66652b28a424afd1efbd28a9501e786771d5fb1f8da147e ] || die 'config smoke used another QMP helper'
grep -Fxq 'CONFIG_NR_CPUS=2' "$CONFIG_SMOKE/raw/arm64.config" || die 'config smoke topology changed'
[ ! -e "$CONFIG_SMOKE/.failure-seal-reserve" ] || die 'config smoke left its seal reserve'
jq -e '.status == "harness_failed" and .failure.stage == "worktree" and .run_owned_build_scratch_retired == true and .run_owned_worktree_retired == true' "$CLEANUP_NEGATIVE/result.json" >/dev/null || die 'prior forced cleanup evidence changed'
[ "$(file_sha "$CAPACITY_NEGATIVE/result.json")" = 457fb3a7a5f00c0ea40b53af78d09d9f95021678b7003fbd02ef061ca2043c4c ] || die 'capacity-negative result changed'
jq -e '.status == "harness_failed" and .failure.stage == "prerequisite_closure" and (.failure.reason | startswith("host shared storage below 999999999999KiB")) and .run_owned_build_scratch_retired == true and .run_owned_worktree_retired == true and .x86_64_measurement_may_start == false' "$CAPACITY_NEGATIVE/result.json" >/dev/null || die 'capacity-negative semantics changed'
[ ! -e "$CAPACITY_NEGATIVE/.failure-seal-reserve" ] || die 'capacity-negative left its seal reserve'

if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run-owned output already exists: $OUT_DIR"
fi
machine_json=$(container machine inspect domainlease-dev)
[ "$(printf '%s\n' "$machine_json" | jq -r '.[0].status')" = running ] || die 'domainlease-dev is not running'
vm_cpu_count=$(container machine run -n domainlease-dev nproc)
[ "$vm_cpu_count" -ge 2 ] || die "domainlease-dev needs at least two allowed CPUs; found $vm_cpu_count"
processes=$(container machine run -n domainlease-dev /usr/bin/ps -eo args=)
if printf '%s\n' "$processes" | grep -Eq '[r]un-p5a-r4-e4-arm64-timing|[r]un-sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement|[q]emu-system-(aarch64|x86_64)|[m]ake -C /var/tmp/linux-cap-worktrees/p5a-r4-e4'; then
	die 'an R4-E4 timing, QEMU, or build process is already active'
fi
container machine run -n domainlease-dev mkdir -p /var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement /var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement
set +e
container machine run -n domainlease-dev sudo -n fstrim -av > "$JOB_DIR/vm-preflight-trim.log" 2>&1
trim_rc=$?
set -e
printf '%s\n' "$trim_rc" > "$JOB_DIR/vm_preflight_trim_exit_code"
[ "$trim_rc" -eq 0 ] || die 'VM preflight trim failed'
[ "$(container machine run -n domainlease-dev stat -f -c %T /var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement)" = ext2/ext3 ] || die 'VM build root is not internal ext4'
container machine run -n domainlease-dev test ! -e "$BUILD_ROOT"
container machine run -n domainlease-dev test ! -e "$WORKTREE"
vm_available_kib=$(container machine run -n domainlease-dev df -Pk /var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement | awk 'NR==2 {print $4}')
[ "$vm_available_kib" -ge "$VM_MIN_KIB" ] || die "VM requires 16 GiB free; only $vm_available_kib KiB available"
host_available_kib=$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')
[ "$host_available_kib" -ge "$HOST_MIN_KIB" ] || die "host requires 32 GiB free; only $host_available_kib KiB available"

container machine run -n domainlease-dev --workdir "$ROOT" "$SOURCE_CLOSURE_TEST" > "$JOB_DIR/source-closure-preflight.log"
container machine run -n domainlease-dev --workdir "$ROOT" "$PARSER_TEST" > "$JOB_DIR/parser-preflight.log"
container machine run -n domainlease-dev --workdir "$ROOT" "$QMP_TEST" > "$JOB_DIR/qmp-preflight.log"

if [ "$PREFLIGHT_ONLY" = 1 ]; then
	printf 'preflight passed: pushed commits, exact source/r2/r3 closures, paused-QMP control, parser, smoke, capacity control, trim, CPU, 32GiB host, 16GiB VM, and clean paths are r4 launch-ready\n'
	exit 0
fi

{
	uname -a
	sw_vers
	printf 'logical_cpus='; sysctl -n hw.logicalcpu
	container --version
	printf 'workspace_available_kib='; df -Pk "$ROOT" | awk 'NR==2 {print $4}'
	printf 'vm_allowed_cpus=%s\n' "$vm_cpu_count"
	printf 'vm_internal_available_kib=%s\n' "$vm_available_kib"
	printf 'host_launch_min_kib=%s\nvm_launch_min_kib=%s\n' "$HOST_MIN_KIB" "$VM_MIN_KIB"
} > "$JOB_DIR/outer-host-environment.txt"
: > "$JOB_DIR/job.log"
find "$JOB_DIR/exit_code" "$JOB_DIR/finished_at" "$JOB_DIR/failure_reason" \
	"$JOB_DIR/progress" "$JOB_DIR/vm_exit_code" "$JOB_DIR/vm_finished_at" \
	"$JOB_DIR/vm_trim_exit_code" "$JOB_DIR/vm_pre_run_trim_exit_code" \
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
