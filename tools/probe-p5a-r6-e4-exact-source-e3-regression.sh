#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r6-e4-exact-source-e3-regression
JOB_DIR="$ROOT/build/long-jobs/$NAME"
RESULT="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression/20260730T-p5a-r6-e4-e3-regression-r1/result.json"

if [ -s "$RESULT" ]; then
	if jq -e '
	  .status ==
	    "passed_exact_source_e3_regression_awaiting_independent_closure" and
	  .candidate_commit ==
	    "d51ebdc657a1040e423735584775e66399f321f9" and
	  .candidate_parent ==
	    "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
	  .candidate_tree ==
	    "0847c408be82e6c9077c2edd2d00f44ccfbe18fc" and
	  .candidate_diff_sha256 ==
	    "fcc00bcf8dabf4ee8d921a454b7ee871e907da5accefaab10f320f08ff4283d9" and
	  .source_gate_sha256 ==
	    "ab5b33650dafb275ffc281ca7f0828aa3db11d8ca301f82c06980399bc3404e6" and
	  .contract_sha256 ==
	    "ade8e74b7f7488e49a0a656b379ed5179e77509dcc68b7c7f6cac014d07dbd30" and
	  .runner_sha256 ==
	    "670c314a6e66bcb6e88176765920f97ba9c9807a13ffbb98e2bf6a6bcc613364" and
	  .architectures == ["arm64","x86_64"] and
	  .diagnostic_profiles == [
	    "arm64_standard_debug_lockdep_hotplug_faults",
	    "x86_64_standard_debug_lockdep_hotplug_faults",
	    "arm64_generic_kasan_lockdep",
	    "x86_64_kcsan_lockdep"
	  ] and
	  .passed_cases_per_profile == 55 and
	  .total_passed_cases == 220 and
	  .receipts_per_profile == 55 and .total_receipts == 220 and
	  .case_failures == 0 and .case_skips == 0 and
	  .case_timeouts == 0 and .warning_reports == 0 and
	  .measurement_config_enabled == false and
	  .disabled_measurement_artifacts == 0 and
	  .warning_classifier_selftest_passed == true and
	  .fresh_build_output_per_profile == true and
	  .sequential_build_retirement == true and
	  .virtual_synthetic_protocol_only == true and
	  (.results | length) == 4 and
	  all(.results[];
	    .status == "passed" and .cases_passed == 55 and
	    .receipts == 55 and .case_failures == 0 and
	    .case_skips == 0 and .case_timeouts == 0 and
	    .warning_reports == 0 and
	    .measurement_config_enabled == false and
	    .disabled_measurement_artifacts == 0 and
	    .fresh_build_output == true and
	    .build_output_retired_after_seal == true) and
	  .e3_regression_passed_for_e4_source == true and
	  .independent_matrix_closure_pending == true and
	  .independent_closure_passed == false and
	  .r6_e4_source_accepted == false and
	  .measurement_authorized == false and
	  .live_scheduler_attachment == false and
	  .runtime_behavior_approved == false and
	  .production_protection == false and
	  .deployment_ready == false and
	  .multi_node_ready == false and
	  .multi_cluster_ready == false and
	  .datacenter_ready == false
	' "$RESULT" >/dev/null 2>&1; then
		printf 'complete\n'
		printf 'result=%s\n' "$RESULT"
		printf 'profiles=4/4; cases=220/220; receipts=220/220\n'
		printf 'measurement=disabled; warnings=0; next=independent closure\n'
		exit 0
	fi
	printf 'failed\n'
	printf 'result=%s\n' "$RESULT"
	printf 'activity=result exists but exact-source regression contract failed\n'
	exit 0
fi

machine_state=$(
	container machine inspect domainlease-dev 2>/dev/null |
		jq -r '.[0].status // "unknown"' 2>/dev/null ||
		printf unknown
)
if [ "$machine_state" != running ]; then
	printf 'failed\n'
	printf 'machine_state=%s\n' "$machine_state"
	exit 0
fi

processes=$(container machine run -n domainlease-dev \
	/usr/bin/ps -eo args= 2>/dev/null || true)
activity=$(
	printf '%s\n' "$processes" |
		grep -E \
			'[r]un-p5a-r6-e4-exact-source-e3-regression-in-machine|[r]un-sched-exec-lease-p5a-r6-e4-exact-source-e3-regression|[q]emu-system-(aarch64|x86_64)|[m]ake -C .*p5a-r6-e4-local-quantum-measurement' |
		sed -n '1p'
)
if [ -n "$activity" ]; then
	printf 'running\n'
	printf 'machine_state=%s\n' "$machine_state"
	printf 'activity=%s\n' "$activity"
	exit 0
fi

if [ -f "$JOB_DIR/vm_exit_code" ]; then
	rc=$(cat "$JOB_DIR/vm_exit_code")
	printf 'failed\n'
	printf 'machine_state=%s\n' "$machine_state"
	printf 'runner_exit_code=%s\n' "$rc"
	printf 'activity=runner exited without a valid exact-source result\n'
	exit 0
fi

printf 'unknown\n'
printf 'machine_state=%s\n' "$machine_state"
printf 'activity=runner process and result not detected\n'
