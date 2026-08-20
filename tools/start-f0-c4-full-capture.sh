#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=f0-c4-full-capture
JOB_DIR="$ROOT/build/long-jobs/$NAME"
PROBE="$ROOT/tools/probe-f0-c4-full-capture.sh"
STARTER="$ROOT/capsched/capsched-models/validation/f0-c4-capture/start-candidate4-full-capture.sh"
RUN_ID=
WATCH=0

for argument in "$@"; do
	case "$argument" in
		--watch)
			[ "$WATCH" = 0 ] || {
				printf 'usage: %s [RUN_ID] [--watch]\n' "$0" >&2
				exit 2
			}
			WATCH=1
			;;
		*)
			[ -z "$RUN_ID" ] || {
				printf 'usage: %s [RUN_ID] [--watch]\n' "$0" >&2
				exit 2
			}
			RUN_ID=$argument
			;;
	esac
done
if [ -z "$RUN_ID" ]; then
	RUN_ID=candidate4-full-$(date -u '+%Y%m%dT%H%M%SZ')
fi
case "$RUN_ID" in
	''|*[!A-Za-z0-9._-]*)
		printf 'usage: %s [RUN_ID] [--watch]\n' "$0" >&2
		exit 2
		;;
esac

watch_if_requested()
{
	if [ "$WATCH" = 1 ]; then
		exec "$ROOT/tools/long-job.sh" watch "$NAME" 30
	fi
}

mkdir -p "$JOB_DIR"
if [ -s "$JOB_DIR/run_id" ]; then
	probe_state=$($PROBE 2>/dev/null | sed -n '1p' || true)
	if [ "$probe_state" = running ]; then
		printf '%s is already running.\n' "$NAME"
		printf 'run_id: %s\n' "$(cat "$JOB_DIR/run_id")"
		printf 'monitor: cd %s && ./tools/long-job.sh watch %s 30\n' \
			"$ROOT" "$NAME"
		watch_if_requested
		exit 0
	fi
fi

: > "$JOB_DIR/job.log"
rm -f "$JOB_DIR/exit_code" "$JOB_DIR/finished_at" \
	"$JOB_DIR/failure_reason" "$JOB_DIR/progress"
printf '%s\n' external > "$JOB_DIR/mode"
printf '%s\n' running > "$JOB_DIR/state"
printf '%s\n' external > "$JOB_DIR/pid"
printf '%s\n' "$RUN_ID" > "$JOB_DIR/run_id"
date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/started_at"
printf '%s\n' "$PROBE" > "$JOB_DIR/probe_path"
: > "$JOB_DIR/suppress_git_status"
printf '%s\n' \
	"$STARTER $RUN_ID" > "$JOB_DIR/command.txt"

set +e
output=$("$STARTER" "$RUN_ID" 2>&1)
rc=$?
set -e
printf '%s\n' "$output" | tee -a "$JOB_DIR/job.log"
if [ "$rc" -ne 0 ]; then
	printf '%s\n' failed > "$JOB_DIR/state"
	printf '%s\n' "$rc" > "$JOB_DIR/exit_code"
	date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/finished_at"
	printf 'error: detached capture starter failed with status %s\n' "$rc" >&2
	exit "$rc"
fi

probe_state=$($PROBE 2>/dev/null | sed -n '1p' || true)
if [ "$probe_state" != running ]; then
	printf '%s\n' failed > "$JOB_DIR/state"
	printf '%s\n' 1 > "$JOB_DIR/exit_code"
	date -u +%Y-%m-%dT%H:%M:%SZ > "$JOB_DIR/finished_at"
	printf 'error: capture probe returned %s after launch\n' \
		"${probe_state:-no-state}" >&2
	exit 1
fi

printf 'started %s in Apple Container machine domainlease-dev\n' "$NAME"
printf 'run_id: %s\n' "$RUN_ID"
printf 'monitor: cd %s && ./tools/long-job.sh watch %s 30\n' \
	"$ROOT" "$NAME"
watch_if_requested
