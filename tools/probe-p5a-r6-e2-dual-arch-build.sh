#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
JOB_DIR="$ROOT/build/long-jobs/p5a-r6-e2-dual-arch-build"
RESULT="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e2-dual-arch-layout/20260725T-p5a-r6-e2-dual-arch-r1/result.json"

if [ -s "$RESULT" ]; then
	if jq -e '
	  .status == "passed_r6_e2_dual_arch_layout" and
	  .architectures == ["arm64","x86_64"] and
	  .modes_per_architecture == 4 and
	  .fresh_architecture_local_baselines == true and
	  .existing_expanded_probe_values_preserved == 51 and
	  .private_probe_symbols_enabled == 49 and
	  .private_symbols_relocations_and_strings_absent_when_disabled == true and
	  .ordinary_scheduler_layout_delta_zero == true and
	  .conservative_private_bytes_per_rq == 74688 and
	  .hard_private_bytes_limit_per_rq == 98304 and
	  .private_memory_envelope_passed == true and
	  .dual_arch_r6_e2_complete == true and
	  .r6_e3_plan_may_start == true and
	  .r6_e3_source_may_start == false and
	  .primary_linux_changed == false and
	  .patch_queue_changed == false and
	  .runtime_behavior_approved == false and
	  .results.arm64.private_probe_symbol_count == 49 and
	  .results.x86_64.private_probe_symbol_count == 49
	' "$RESULT" >/dev/null 2>&1; then
		printf 'complete\n'
		printf 'result=%s\n' "$RESULT"
		printf 'architectures=arm64,x86_64\n'
		printf 'existing_probe_values=51 unchanged per architecture\n'
		printf 'private_probe_symbols=49\n'
		printf 'private_memory_envelope=passed\n'
		exit 0
	fi
	printf 'failed\n'
	printf 'result=%s\n' "$RESULT"
	printf 'activity=result exists but validation contract failed\n'
	exit 0
fi

machine_state=$(
	container machine inspect domainlease-dev 2>/dev/null |
		jq -r '.[0].status // "unknown"' 2>/dev/null ||
		printf unknown
)
if [ "$machine_state" != running ]; then
	printf 'failed\nmachine_state=%s\n' "$machine_state"
	exit 0
fi

processes=$(container machine run -n domainlease-dev \
	/usr/bin/ps -eo args= 2>/dev/null || true)
activity=$(
	printf '%s\n' "$processes" |
		grep -E '[r]un-p5a-r6-e2-dual-arch-build-in-machine|[r]un-sched-exec-lease-p5a-r6-e2-dual-arch-layout|[m]ake -C .*(p5a-r6-e2-layout|/linux)' |
		sed -n '1p'
)
if [ -n "$activity" ]; then
	printf 'running\nmachine_state=%s\nactivity=%s\n' \
		"$machine_state" "$activity"
	exit 0
fi
if [ -f "$JOB_DIR/vm_exit_code" ]; then
	rc=$(cat "$JOB_DIR/vm_exit_code")
	printf 'failed\nmachine_state=%s\nrunner_exit_code=%s\n' \
		"$machine_state" "$rc"
	printf 'activity=runner exited without a valid passed result\n'
	exit 0
fi
printf 'unknown\nmachine_state=%s\n' "$machine_state"
printf 'activity=runner process and result not detected\n'
