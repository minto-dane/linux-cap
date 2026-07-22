#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=${NAME:-p5a-r4-e4-source-e3-regression-r3}
RUN_ID=${RUN_ID:-20260719T-p5a-r4-e4-source-e3-regression-r3}
EXPECTED_CANDIDATE_COMMIT=${EXPECTED_CANDIDATE_COMMIT:-9e4cb44fd1a1f998fcc288df87dad60505e8bf18}
EXPECTED_CANDIDATE_TREE=${EXPECTED_CANDIDATE_TREE:-e6feb28a29fc8c37bc46af0fbf37de30f3401a4f}
EXPECTED_CANDIDATE_DIFF_SHA=${EXPECTED_CANDIDATE_DIFF_SHA:-bb115b371cd18551b93c09ae9b3d0cf458e70c9964927ff08d1bd3f586dd4cd2}
EXPECTED_R7_CORRECTIONS=${EXPECTED_R7_CORRECTIONS:-0}
JOB_DIR="$ROOT/build/long-jobs/$NAME"
OUT_DIR="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-source-and-e3-regression/$RUN_ID"
RESULT="$OUT_DIR/result.json"
SOURCE_RESULT="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-local-quantum-source-gate/$RUN_ID-source/result.json"
CONFIG_RESULT="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-e3-six-profile-regression/$RUN_ID-config-smoke/config-smoke-result.json"
REGRESSION_DIR="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-e3-six-profile-regression/$RUN_ID-e3-regression"
REGRESSION_RESULT="$REGRESSION_DIR/result.json"
SOURCE_BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r4-e4-source-gate/$RUN_ID-source"
REGRESSION_BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r4-e4-e3-regression/$RUN_ID-e3-regression"

sha256_file()
{
	sha256sum "$1" | awk '{print $1}'
}

validate_result()
{
	local expected

	case "$EXPECTED_R7_CORRECTIONS" in
		0|1) ;;
		*) return 1 ;;
	esac
	[ -s "$OUT_DIR/result.sha256" ] || return 1
	expected=$(awk 'NF {print $1; exit}' "$OUT_DIR/result.sha256")
	[ "$expected" = "$(sha256_file "$RESULT")" ] || return 1
	jq -e --arg candidate "$EXPECTED_CANDIDATE_COMMIT" \
		--argjson r7 "$EXPECTED_R7_CORRECTIONS" '
	  .status == "passed_source_and_six_profile_e3_regression_awaiting_independent_closure" and
	  .candidate_commit == $candidate and
	  .fresh_source_objects == 6 and .e3_profiles == 6 and
	  .e3_cases_passed == 216 and .e3_receipts == 216 and
	  ($r7 == 0 or (.e3_handoff_race_strengthened == true and
	    .e4_offline_oracle_corrected == true)) and
	  .vcpu_migration_observation_enforced == true and
	  .irq_preempt_state_recorded == true and
	  .independent_closure_required == true and
	  .timing_measurement_may_start == false and
	  .r4_e4_source_accepted == false and .real_scheduler_attachment == false and
	  .runtime_behavior_approved == false and .production_protection == false and
	  .deployment_ready == false and .multi_cluster_ready == false and
	  .datacenter_ready == false
	' "$RESULT" >/dev/null || return 1
	[ "$(sha256_file "$SOURCE_RESULT")" = "$(jq -r '.source_gate_result_sha256' "$RESULT")" ] || return 1
	[ "$(sha256_file "$CONFIG_RESULT")" = "$(jq -r '.config_smoke_result_sha256' "$RESULT")" ] || return 1
	[ "$(sha256_file "$REGRESSION_RESULT")" = "$(jq -r '.e3_regression_result_sha256' "$RESULT")" ] || return 1
	jq -e --arg candidate "$EXPECTED_CANDIDATE_COMMIT" \
		--arg tree "$EXPECTED_CANDIDATE_TREE" \
		--arg diff_sha "$EXPECTED_CANDIDATE_DIFF_SHA" \
		--argjson r7 "$EXPECTED_R7_CORRECTIONS" '
	  .status == "passed_source_and_object_gate_awaiting_six_profile_e3_regression" and
	  .candidate_commit == $candidate and
	  .candidate_tree == $tree and
	  .candidate_diff_sha256 == $diff_sha and
	  .fresh_objects == 6 and .w1_compiler_diagnostics == 0 and
	  .disabled_e4_artifacts == 0 and
	  (($r7 == 0 and .e3_cases_byte_preserved == 36) or
	    ($r7 == 1 and .e3_case_manifest_preserved == 36 and
	      .e3_handoff_race_strengthened == true and
	      .e4_offline_oracle_corrected == true)) and
	  .measurement_task_migration_disabled == true and
	  .vcpu_migration_observation_enforced == true and
	  .irq_preempt_state_recorded == true and
	  .timing_measurement_may_start == false and .r4_e4_source_accepted == false
	' "$SOURCE_RESULT" >/dev/null || return 1
	jq -e --arg candidate "$EXPECTED_CANDIDATE_COMMIT" '
	  .status == "passed_e4_candidate_six_profile_e3_config_smoke_without_build_or_boot" and
	  .candidate_commit == $candidate and
	  .builds_started == 0 and .boots_started == 0 and
	  .e4_measurement_suite_enabled == false and .timing_measurement_may_start == false
	' "$CONFIG_RESULT" >/dev/null || return 1
	jq -e --arg candidate "$EXPECTED_CANDIDATE_COMMIT" '
	  .status == "passed_six_profile_e3_regression_awaiting_independent_closure" and
	  .candidate_commit == $candidate and
	  .profiles == ["arm64_standard_debug","x86_64_standard_debug","arm64_hotplug_fault_injection","x86_64_hotplug_fault_injection","arm64_generic_kasan","x86_64_kcsan"] and
	  .total_passed_cases == 216 and .total_receipts == 216 and
	  .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and
	  .warning_reports == 0 and .six_profile_e3_regression_passed == true and
	  .independent_regression_closure_pending == true and
	  .e4_measurement_suite_enabled == false and .timing_measurement_may_start == false and
	  .r4_e4_source_accepted == false and .production_protection == false and
	  .datacenter_ready == false and (.results | length) == 6 and
	  all(.results[]; .status == "passed" and .cases_passed == 36 and
	    .receipts == 36 and .case_failures == 0 and .case_skips == 0 and
	    .case_timeouts == 0 and .warning_reports == 0 and
	    .build_output_retired_after_seal == true)
	' "$REGRESSION_RESULT" >/dev/null || return 1
}

if [ -s "$RESULT" ]; then
	if validate_result; then
		printf 'complete\n'
		printf 'result=%s\n' "$RESULT"
		printf 'source_objects=6/6; profiles=6/6; cases=216/216; receipts=216/216; warnings=0\n'
		printf 'observability=CPU migration and IRQ/preemption source contract enforced\n'
		printf 'next=independent read-only artifact closure; timing remains blocked\n'
		exit 0
	fi
	printf 'failed\n'
	printf 'result=%s\n' "$RESULT"
	printf 'activity=result exists but exact corrected combined or child-artifact contract failed\n'
	exit 0
fi

machine_state=$(container machine inspect domainlease-dev 2>/dev/null |
	jq -r '.[0].status // "unknown"' 2>/dev/null || printf unknown)
if [ "$machine_state" != running ]; then
	printf 'failed\n'
	printf 'machine_state=%s\n' "$machine_state"
	exit 0
fi

processes=$(container machine run -n domainlease-dev -- /usr/bin/ps -eo args= 2>/dev/null || true)
activity=$(printf '%s\n' "$processes" |
	grep -E '[r]un-p5a-r4-e4-source-e3-regression|[r]un-sched-exec-lease-p5a-r4-e4|[q]emu-system-(aarch64|x86_64)|[m]ake -C .*p5a-r4-e4' |
	sed -n '1p')
if [ -n "$activity" ]; then
	printf 'running\n'
	printf 'machine_state=%s\n' "$machine_state"
	sealed=$(find "$REGRESSION_DIR" -maxdepth 1 -name '*-result.json' -type f 2>/dev/null | wc -l | tr -d ' ')
	printf 'profiles_sealed=%s/6\n' "$sealed"
	source_size=$(container machine run -n domainlease-dev -- du -sh "$SOURCE_BUILD_ROOT" 2>/dev/null || true)
	regression_size=$(container machine run -n domainlease-dev -- du -sh "$REGRESSION_BUILD_ROOT" 2>/dev/null || true)
	[ -z "$source_size" ] || printf 'source_build_size=%s\n' "$source_size"
	[ -z "$regression_size" ] || printf 'regression_build_size=%s\n' "$regression_size"
	printf 'activity=%s\n' "$activity"
	exit 0
fi

if [ -f "$JOB_DIR/vm_exit_code" ]; then
	rc=$(cat "$JOB_DIR/vm_exit_code")
	printf 'failed\n'
	printf 'machine_state=%s\n' "$machine_state"
	printf 'runner_exit_code=%s\n' "$rc"
	printf 'activity=runner exited without a valid corrected combined result\n'
	exit 0
fi

printf 'unknown\n'
printf 'machine_state=%s\n' "$machine_state"
printf 'activity=runner process and result not detected yet\n'
