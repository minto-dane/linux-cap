#!/usr/bin/env bash
set -euo pipefail

MACHINE=${MACHINE:-domainlease-dev}
CPUS=${DOMAINLEASE_VM_CPUS:-6}
MEMORY=${DOMAINLEASE_VM_MEMORY:-10G}

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

for tool in container jq; do
	command -v "$tool" >/dev/null 2>&1 || die "missing command: $tool"
done
case "$CPUS" in
	''|*[!0-9]*|0) die "invalid CPU count: $CPUS" ;;
esac
case "$MEMORY" in
	*[0-9][GgMmKk]) ;;
	*) die "invalid memory size: $MEMORY" ;;
esac

state=$(container machine inspect "$MACHINE" | jq -r '.[0].status')
if [ "$state" = running ]; then
	processes=$(container machine run -n "$MACHINE" -- /usr/bin/ps -eo args=)
	if printf '%s\n' "$processes" | grep -Eq \
		'[m]ake .*linux|[q]emu-system-|[r]un-sched-exec-lease|/tools/[r]un-p5a-|/(gcc|cc1|ld)( |$)'; then
		die 'build, QEMU, or validation work is active; wait for its detached job to finish'
	fi
fi

container machine set -n "$MACHINE" "cpus=$CPUS" "memory=$MEMORY"
if [ "$state" = running ]; then
	container machine stop "$MACHINE"
fi
container machine run -n "$MACHINE" -- /usr/bin/true

actual_cpus=$(container machine run -n "$MACHINE" -- nproc)
actual_memory_kib=$(container machine run -n "$MACHINE" -- grep '^MemTotal:' /proc/meminfo |
	tr -cd '0-9\n')
minimum_memory_kib=$((9 * 1024 * 1024))
[ "$actual_cpus" -eq "$CPUS" ] || die "expected $CPUS vCPUs, found $actual_cpus"
[ "$actual_memory_kib" -ge "$minimum_memory_kib" ] ||
	die "expected approximately $MEMORY RAM, found ${actual_memory_kib} KiB"

printf 'performance profile active: machine=%s cpus=%s memory=%s build_jobs=%s\n' \
	"$MACHINE" "$actual_cpus" "$MEMORY" "$actual_cpus"
