#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=${NAME:-p5a-r4-e4-arm64-timing-r4}
RUN_ID=${RUN_ID:-20260721T-p5a-r4-e4-arm64-timing-r4}
EXPECTED_CANDIDATE_COMMIT=${EXPECTED_CANDIDATE_COMMIT:-5857720dedc49f89d2367442f8fdb1a806ffa1cc}
EXPECTED_CANDIDATE_TREE=${EXPECTED_CANDIDATE_TREE:-ee6e329106327a302bf63c78f2ed4fe3ddea7865}
EXPECTED_COMBINED_RUN=${EXPECTED_COMBINED_RUN:-20260719T-p5a-r4-e4-source-e3-regression-r4}
EXPECTED_SOURCE_CLOSURE_R1_SHA=${EXPECTED_SOURCE_CLOSURE_R1_SHA:-5e3ff71d2fea01b29e20b23a9bb8e1a8479d70cc847fa49aa3d33295c8040f3f}
EXPECTED_SOURCE_CLOSURE_R2_SHA=${EXPECTED_SOURCE_CLOSURE_R2_SHA:-bac2aca6649c40fdf21665a0f801be1f0751ef03c437d1b506f78ba77f04f720}
EXPECTED_SOURCE_CLOSURE_NORMALIZED_SHA=${EXPECTED_SOURCE_CLOSURE_NORMALIZED_SHA:-767d2f9ab1bfb6e0c918c2ba0b51147ba79f236085e6985097b14e5a8da43d21}
EXPECTED_RUNNER_SHA=${EXPECTED_RUNNER_SHA:-2fe52b6e9bfbc57ccca43c6e45fc3c18b15e196967822c34743b202480385e69}
EXPECTED_R6_KUNIT_CLOSURE_R1_SHA=${EXPECTED_R6_KUNIT_CLOSURE_R1_SHA:-}
EXPECTED_R6_KUNIT_CLOSURE_R2_SHA=${EXPECTED_R6_KUNIT_CLOSURE_R2_SHA:-}
EXPECTED_R6_KUNIT_CLOSURE_NORMALIZED_SHA=${EXPECTED_R6_KUNIT_CLOSURE_NORMALIZED_SHA:-}
JOB_DIR="$ROOT/build/long-jobs/$NAME"
OUT_DIR="$ROOT/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/$RUN_ID"
RESULT="$OUT_DIR/result.json"
BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement/$RUN_ID"
WORKTREE="/var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement/$RUN_ID"

file_sha()
{
	sha256sum "$1" | awk '{print $1}'
}

validate_complete_result()
{
	local expected status

	[ -s "$OUT_DIR/result.sha256" ] || return 1
	expected=$(awk 'NF {print $1; exit}' "$OUT_DIR/result.sha256")
	[ "$expected" = "$(file_sha "$RESULT")" ] || return 1
	status=$(jq -r '.status // empty' "$RESULT")
	case "$status" in
		passed_r4_local_quantum_measurement|rejected_r4_local_quantum_measurement) ;;
		*) return 1 ;;
	esac
	jq -e \
	  --arg run_id "$RUN_ID" \
	  --arg source_commit "$EXPECTED_CANDIDATE_COMMIT" \
	  --arg source_tree "$EXPECTED_CANDIDATE_TREE" \
	  --arg combined_run "$EXPECTED_COMBINED_RUN" \
	  --arg closure_r1 "$EXPECTED_SOURCE_CLOSURE_R1_SHA" \
	  --arg closure_r2 "$EXPECTED_SOURCE_CLOSURE_R2_SHA" \
	  --arg closure_normalized "$EXPECTED_SOURCE_CLOSURE_NORMALIZED_SHA" \
	  --arg r6_closure_r1 "$EXPECTED_R6_KUNIT_CLOSURE_R1_SHA" \
	  --arg r6_closure_r2 "$EXPECTED_R6_KUNIT_CLOSURE_R2_SHA" \
	  --arg r6_closure_normalized "$EXPECTED_R6_KUNIT_CLOSURE_NORMALIZED_SHA" \
	  --arg runner_sha "$EXPECTED_RUNNER_SHA" '
	  .schema_version == 1 and
	  .id == "sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement-result-v1" and
	  .run_id == $run_id and
	  .architecture == "arm64" and
	  .source.commit == $source_commit and
	  .source.tree == $source_tree and
	  .prerequisites.combined_run == $combined_run and
	  .prerequisites.closure_r1_sha256 == $closure_r1 and
	  .prerequisites.closure_r2_sha256 == $closure_r2 and
	  .prerequisites.closure_normalized_sha256 == $closure_normalized and
	  (($r6_closure_r1 == "" and $r6_closure_r2 == "" and $r6_closure_normalized == "") or
	    (.prerequisites.r6_failure_closure_r1_sha256 == $r6_closure_r1 and
	     .prerequisites.r6_failure_closure_r2_sha256 == $r6_closure_r2 and
	     .prerequisites.r6_failure_closure_normalized_sha256 == $r6_closure_normalized and
	     .prerequisites.r6_failure_independently_closed == true)) and
	  .runner.sha256 == $runner_sha and
	  .runner.parser_sha256 == "dd0372d385bbc0a84c6faedf67ee3596f4766205a125c44e33b9a91652bc2cd1" and
	  .runner.qmp_vcpu_control_sha256 == "e59bc8ad5adb50ddf66652b28a424afd1efbd28a9501e786771d5fb1f8da147e" and
	  .matrix.total_cells == 682 and .matrix.total_measured_pairs == 6820000 and
	  .matrix.result_rows == 682 and .parser.malformed_or_missing_rows == 0 and
	  .parser.duplicate_or_unexpected_cells == 0 and
	  .parser.harness_observation_failures == 0 and .parser.summary_mismatches == 0 and
	  .diagnostics.compiler_diagnostics == 0 and .diagnostics.kunit_suite_passed == true and
	  .diagnostics.kunit_cases_passed == 7 and .diagnostics.kunit_cases_failed == 0 and
	  .diagnostics.kunit_cases_skipped == 0 and .diagnostics.qemu_exit_code == 0 and
	  .placement.guest_vcpus == 2 and .placement.qemu_vcpu_threads_pinned == 2 and
	  .placement.rows_before_all_vcpus_pinned == 0 and
	  .placement.qmp_pause_before_affinity == true and
	  .placement.qmp_mapping_reverified_before_resume == true and
	  .artifacts.raw_inputs_read_only == true and .artifacts.derived_outputs_read_only == true and
	  .artifacts.image.restore_verified == true and
	  .artifacts.exec_lease_object.restore_verified == true and
	  .artifacts.build_output_retired == true and .artifacts.worktree_retired == true and
	  .architecture_measurement_valid == true and
	  .threshold_failure_is_valid_negative_evidence == true and
	  .measurement_result_accepted == false and .real_scheduler_attachment == false and
	  .runtime_behavior_approved == false and .production_protection == false and
	  .deployment_ready == false and .multi_cluster_ready == false and .datacenter_ready == false and
	  ((.status == "passed_r4_local_quantum_measurement" and
	    .parser.rejected_cells == 0 and .parser.threshold_breaches == 0 and
	    .diagnostics.clock_skew_reports == 0 and .diagnostics.kernel_warning_reports == 0 and
	    .x86_64_measurement_may_start == true) or
	   (.status == "rejected_r4_local_quantum_measurement" and
	    (.parser.rejected_cells > 0 or .diagnostics.clock_skew_reports > 0 or
	     .diagnostics.kernel_warning_reports > 0) and
	    .x86_64_measurement_may_start == false))
	' "$RESULT" >/dev/null || return 1
	[ ! -e "$BUILD_ROOT" ] && [ ! -e "$WORKTREE" ] || return 1
}

if [ -s "$RESULT" ]; then
	if [ "$(jq -r '.status // empty' "$RESULT" 2>/dev/null)" = harness_failed ]; then
		printf 'failed\n'
		printf 'result=%s\n' "$RESULT"
		printf 'failure_stage=%s\n' "$(jq -r '.failure.stage // "unknown"' "$RESULT")"
		printf 'failure_reason=%s\n' "$(jq -r '.failure.reason // "unknown"' "$RESULT")"
		exit 0
	fi
	if validate_complete_result; then
		printf 'complete\n'
		printf 'result=%s\n' "$RESULT"
		printf 'classification=%s\n' "$(jq -r '.status' "$RESULT")"
		printf 'rows=682/682 pairs=6820000/6820000 rejected_cells=%s threshold_breaches=%s\n' \
			"$(jq -r '.parser.rejected_cells' "$RESULT")" \
			"$(jq -r '.parser.threshold_breaches' "$RESULT")"
		printf 'kernel_warnings=%s clock_skew=%s x86_may_start=%s\n' \
			"$(jq -r '.diagnostics.kernel_warning_reports' "$RESULT")" \
			"$(jq -r '.diagnostics.clock_skew_reports' "$RESULT")" \
			"$(jq -r '.x86_64_measurement_may_start' "$RESULT")"
		exit 0
	fi
	printf 'failed\n'
	printf 'result=%s\n' "$RESULT"
	printf 'activity=result exists but exact storage-hardened paused-QMP arm64 evidence contract failed\n'
	exit 0
fi

machine_state=$(container machine inspect domainlease-dev 2>/dev/null |
	jq -r '.[0].status // "unknown"' 2>/dev/null || printf unknown)
if [ "$machine_state" != running ]; then
	printf 'failed\n'
	printf 'machine_state=%s\n' "$machine_state"
	exit 0
fi

processes=$(container machine run -n domainlease-dev /usr/bin/ps -eo args= 2>/dev/null || true)
activity=$(printf '%s\n' "$processes" |
	grep -E '[r]un-p5a-r4-e4-arm64-timing.*-in-machine|[r]un-sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement|[q]emu-system-aarch64|[m]ake -C /var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement' |
	sed -n '1p')
if [ -n "$activity" ]; then
	printf 'running\n'
	printf 'machine_state=%s\n' "$machine_state"
	rows=$(awk '/R4_E4_RESULT / { count++ } END { print count + 0 }' \
		"$OUT_DIR/raw/qemu-serial.log" 2>/dev/null || printf '0\n')
	printf 'measurement_rows=%s/682\n' "$rows"
	build_size=$(container machine run -n domainlease-dev du -sh "$BUILD_ROOT" 2>/dev/null || true)
	[ -z "$build_size" ] || printf 'internal_build_size=%s\n' "$build_size"
	printf 'activity=%s\n' "$activity"
	exit 0
fi

if [ -f "$JOB_DIR/vm_exit_code" ]; then
	rc=$(cat "$JOB_DIR/vm_exit_code")
	printf 'failed\n'
	printf 'machine_state=%s\nrunner_exit_code=%s\n' "$machine_state" "$rc"
	printf 'activity=runner exited without a valid complete result\n'
	exit 0
fi

printf 'unknown\n'
printf 'machine_state=%s\n' "$machine_state"
printf 'activity=runner process and result not detected yet\n'
