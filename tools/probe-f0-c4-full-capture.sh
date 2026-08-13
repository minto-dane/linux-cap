#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=f0-c4-full-capture
JOB_DIR="$ROOT/build/long-jobs/$NAME"
RUN_FILE="$JOB_DIR/run_id"

if [ ! -s "$RUN_FILE" ]; then
	printf 'unknown\n'
	printf 'activity=run ID is not registered\n'
	exit 0
fi
run_id=$(cat "$RUN_FILE")
case "$run_id" in
	''|*[!A-Za-z0-9._-]*)
		printf 'failed\n'
		printf 'activity=registered run ID is malformed\n'
		exit 0
		;;
esac

machine_state=$(
	container machine inspect domainlease-dev 2>/dev/null \
		| jq -r '.[0].status // "unknown"' 2>/dev/null \
		|| printf unknown
)
if [ "$machine_state" != running ]; then
	printf 'failed\n'
	printf 'machine_state=%s\n' "$machine_state"
	printf 'run_id=%s\n' "$run_id"
	printf 'activity=Apple Container machine is not running\n'
	exit 0
fi

vm()
{
	container machine run --root -n domainlease-dev -- "$@"
}

launcher_unit=domainlease-f0-c4-host-launch-$run_id
capture_unit=domainlease-f0-c4-$run_id
progress_path=/run/domainlease-f0-c4/progress/$run_id
evidence=/var/lib/domainlease-f0-c4/evidence/$run_id
commit=$evidence/RAW_COMMIT.json
work=/var/lib/domainlease-f0-c4/work/$run_id

progress=$(vm /usr/bin/cat "$progress_path" 2>/dev/null || true)
if [ -z "$progress" ]; then
	progress='0% waiting for first durable progress receipt'
fi
printf '%s\n' "$progress" > "$JOB_DIR/progress"

commit_json=$(vm /usr/bin/cat "$commit" 2>/dev/null || true)
if [ -n "$commit_json" ]; then
	capture_status=$(printf '%s\n' "$commit_json" | jq -r \
		--arg run_id "$run_id" \
		'if .run_id == $run_id then .capture_status // "MALFORMED" else "MALFORMED" end' \
		2>/dev/null || printf MALFORMED)
	if [ "$capture_status" = RAW_CAPTURE_COMPLETE ]; then
		state=complete
	else
		state=failed
	fi
else
	launcher_state=$(vm /usr/bin/systemctl is-active "$launcher_unit" 2>/dev/null || true)
	capture_state=$(vm /usr/bin/systemctl is-active "$capture_unit" 2>/dev/null || true)
	case "$launcher_state:$capture_state" in
		active:*|activating:*|*:active|*:activating) state=running ;;
		*) state=failed ;;
	esac
	capture_status=not-published
fi

printf '%s\n' "$state"
printf 'machine_state=%s\n' "$machine_state"
printf 'run_id=%s\n' "$run_id"
printf 'capture_status=%s\n' "$capture_status"
printf 'progress=%s\n' "$progress"
printf 'launcher_unit=%s\n' \
	"$(vm /usr/bin/systemctl is-active "$launcher_unit" 2>/dev/null || true)"
printf 'capture_unit=%s\n' \
	"$(vm /usr/bin/systemctl is-active "$capture_unit" 2>/dev/null || true)"
printf 'external_memory_usage=%s\n' \
	"$(vm /usr/bin/du -sh "$work" 2>/dev/null || printf not-created)"
printf 'evidence_usage=%s\n' \
	"$(vm /usr/bin/du -sh "$evidence" 2>/dev/null || printf not-published)"
if [[ $state == running ]]; then
	printf '%s\n' '--- exact exploration runtime ---'
	container machine run -i --root -n domainlease-dev \
		/usr/bin/python3 - "$run_id" \
		< "$ROOT/tools/f0-c4-vm-runtime-metrics.py" 2>/dev/null \
		|| printf 'runtime_metrics=unavailable\n'
fi
printf '%s\n' '--- vm journal tail ---'
vm /usr/bin/journalctl -u "$capture_unit" -u "$launcher_unit" \
	-n 8 --no-pager 2>/dev/null || true
