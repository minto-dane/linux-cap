#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r6-e3-four-profile-matrix
JOB_DIR="$ROOT/build/long-jobs/$NAME"
RESULT="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix/20260726T-p5a-r6-e3-four-profile-r1/result.json"

if [ -s "$RESULT" ]; then
	if jq -e '
	  .status ==
	    "passed_four_profile_matrix_awaiting_independent_closure" and
	  .candidate_commit ==
	    "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
	  .candidate_parent ==
	    "66e2fd20fc85012d7dc03649fcf4c7af583cbb94" and
	  .candidate_tree ==
	    "2b863b57dfe3f03609ad1a73c965874f71056e8f" and
	  .candidate_diff_sha256 ==
	    "2ed265756c1cee52252bedc6cbfb3d651eed136be9dca98992496ee80ebfb715" and
	  .source_gate_sha256 ==
	    "88376403879ecc2b0a059791ba59a5bd71addd493e9c8052c2742f877f9e7f25" and
	  .runner_sha256 ==
	    "4b27719906ac0078ffed06af1931eff590bd05024bfbc736b3ddc0f860a4119d" and
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
	  .warning_classifier_selftest_passed == true and
	  .fresh_build_output_per_profile == true and
	  .sequential_build_retirement == true and
	  .virtual_synthetic_protocol_only == true and
	  (.results | length) == 4 and
	  all(.results[];
	    .status == "passed" and .cases_passed == 55 and
	    .receipts == 55 and .case_failures == 0 and
	    .case_skips == 0 and .case_timeouts == 0 and
	    .warning_reports == 0 and .fresh_build_output == true and
	    .build_output_retired_after_seal == true) and
	  .four_profile_matrix_passed == true and
	  .independent_matrix_closure_pending == true and
	  .r6_e3_source_accepted == false and
	  .r6_e3_correctness_accepted == false and
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
		printf 'warnings=0; next=independent matrix closure\n'
		exit 0
	fi
	printf 'failed\n'
	printf 'result=%s\n' "$RESULT"
	printf 'activity=result exists but four-profile contract failed\n'
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
			'[r]un-p5a-r6-e3-four-profile-matrix-in-machine|[r]un-sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix|[q]emu-system-(aarch64|x86_64)|[m]ake -C .*p5a-r6-e3-correctness-prototype' |
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
	printf 'activity=runner exited without a valid four-profile result\n'
	exit 0
fi

printf 'unknown\n'
printf 'machine_state=%s\n' "$machine_state"
printf 'activity=runner process and result not detected\n'
