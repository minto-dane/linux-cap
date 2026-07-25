#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=p5a-r6-e3-source-gate
JOB_DIR="$ROOT/build/long-jobs/$NAME"
RESULT="$ROOT/build/source-check/sched-exec-lease-p5a-r6-e3-correctness-source-gate/20260726T-p5a-r6-e3-source-gate-r1/result.json"

if [ -s "$RESULT" ]; then
	if jq -e '
	  .status ==
	    "passed_source_gate_awaiting_four_profile_diagnostic_matrix" and
	  .candidate_commit ==
	    "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
	  .candidate_parent ==
	    "66e2fd20fc85012d7dc03649fcf4c7af583cbb94" and
	  .candidate_tree ==
	    "2b863b57dfe3f03609ad1a73c965874f71056e8f" and
	  .candidate_diff_sha256 ==
	    "2ed265756c1cee52252bedc6cbfb3d651eed136be9dca98992496ee80ebfb715" and
	  .runner_sha256 ==
	    "2416b0e844385e9e7eb1142d4b3f04523e1af0fde6c401b254eeec0bed199c99" and
	  .exact_direct_e2_child == true and
	  .exact_two_file_boundary == true and
	  .insertions == 1516 and .deletions == 0 and
	  .e2_private_layout_block_preserved == true and
	  .r6_private_values_preserved == 49 and
	  .existing_expanded_values_preserved == 51 and
	  .config_default_off == true and .same_translation_unit == true and
	  .suite_name == "sched_exec_lease_r6_correctness" and
	  .deterministic_case_families == 55 and
	  .allocation_fault_sites == 3 and
	  .stress_repetitions == 4096 and
	  .independent_oracle_leaves == 64 and
	  .strict_checkpatch == {errors:0,warnings:0,checks:0} and
	  .w1_compiler_diagnostics == 0 and
	  .architectures == ["arm64","x86_64"] and
	  .disabled_e3_artifacts == 0 and
	  .ordinary_structure_growth_bytes == 0 and
	  .results.arm64.status == "passed" and
	  .results.x86_64.status == "passed" and
	  .diagnostic_matrix_may_start == true and
	  .r6_e3_source_accepted == false and
	  .r6_e3_correctness_accepted == false and
	  .primary_linux_changed == false and
	  .patch_queue_changed == false and
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
		printf 'candidate=99287291f1c8e0d6c1b3ea86d121508c5547f424\n'
		printf 'architectures=arm64,x86_64\n'
		printf 'cases=55; fault_sites=3; disabled_artifacts=0\n'
		printf 'next=four-profile diagnostic matrix; no correctness claim yet\n'
		exit 0
	fi
	printf 'failed\n'
	printf 'result=%s\n' "$RESULT"
	printf 'activity=result exists but source-gate contract failed\n'
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
			'[r]un-p5a-r6-e3-source-gate-in-machine|[r]un-sched-exec-lease-p5a-r6-e3-correctness-source-gate|[m]ake -C .*p5a-r6-e3' |
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
	printf 'activity=runner exited without a valid source-gate result\n'
	exit 0
fi

printf 'unknown\n'
printf 'machine_state=%s\n' "$machine_state"
printf 'activity=runner process and result not detected\n'
