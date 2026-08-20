#!/usr/bin/python3
"""Read-only runtime metrics for one F0 Candidate-4 capture cgroup.

The host probe streams this file to the Apple Container VM over stdin.  Keeping
the collector read-only and outside the capture installation means monitoring
cannot become evidence or mutate the exact exploration.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path


RUN_ID = re.compile(r"[A-Za-z0-9._-]{1,128}\Z")


def read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="ascii").strip()
    except OSError:
        return None


def read_key_values(path: Path) -> dict[str, int]:
    result: dict[str, int] = {}
    text = read_text(path)
    if text is None:
        return result
    for line in text.splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[1].isdigit():
            result[fields[0]] = int(fields[1])
    return result


def read_status_bytes(path: Path) -> dict[str, int]:
    result: dict[str, int] = {}
    text = read_text(path)
    if text is None:
        return result
    for line in text.splitlines():
        key, separator, raw_value = line.partition(":")
        fields = raw_value.split()
        if not separator or not fields or not fields[0].isdigit():
            continue
        multiplier = 1024 if len(fields) == 2 and fields[1] == "kB" else 1
        result[key] = int(fields[0]) * multiplier
    return result


def process_metrics(pid: int) -> dict[str, int]:
    proc = Path("/proc") / str(pid)
    stat_text = read_text(proc / "stat")
    uptime_text = read_text(Path("/proc/uptime"))
    if stat_text is None or uptime_text is None:
        return {}
    try:
        stat_fields = stat_text.rsplit(")", 1)[1].split()
        clock_ticks = os.sysconf("SC_CLK_TCK")
        cpu_ticks = int(stat_fields[11]) + int(stat_fields[12])
        start_ticks = int(stat_fields[19])
        elapsed = max(0.0, float(uptime_text.split()[0]) - start_ticks / clock_ticks)
    except (IndexError, ValueError, OSError):
        return {}
    status = read_status_bytes(proc / "status")
    io = read_key_values(proc / "io")
    return {
        "cpu_milliseconds": cpu_ticks * 1000 // clock_ticks,
        "elapsed_seconds": int(elapsed),
        "rss_bytes": status.get("VmRSS", 0),
        "rss_anon_bytes": status.get("RssAnon", 0),
        "rss_file_bytes": status.get("RssFile", 0),
        "swap_bytes": status.get("VmSwap", 0),
        "read_bytes": io.get("read_bytes:", 0),
        "write_bytes": io.get("write_bytes:", 0),
    }


def spill_metrics(pids: list[int]) -> tuple[int, int, int, int]:
    descriptors = 0
    objects: dict[tuple[int, int], os.stat_result] = {}
    for pid in pids:
        fd_root = Path("/proc") / str(pid) / "fd"
        try:
            names = list(fd_root.iterdir())
        except OSError:
            continue
        for descriptor in names:
            try:
                target = os.readlink(descriptor)
                metadata = os.stat(descriptor)
            except OSError:
                continue
            if "/WORK/exact-" not in target or not target.endswith(".spill (deleted)"):
                continue
            descriptors += 1
            objects[(metadata.st_dev, metadata.st_ino)] = metadata
    return (
        descriptors,
        len(objects),
        sum(metadata.st_size for metadata in objects.values()),
        sum(metadata.st_blocks * 512 for metadata in objects.values()),
    )


def main() -> int:
    if len(sys.argv) != 2 or RUN_ID.fullmatch(sys.argv[1]) is None:
        print("runtime_metrics=invalid-run-id")
        return 64
    run_id = sys.argv[1]
    service = Path("/sys/fs/cgroup/system.slice") / (
        f"domainlease-f0-c4-{run_id}.service"
    )
    run_root = service / "capture" / f"run-{run_id}"
    if not run_root.is_dir():
        print("runtime_metrics=no-active-component-cgroup")
        return 0

    components: list[str] = []
    pids: list[int] = []
    active_cgroups: list[Path] = []
    try:
        component_paths = sorted(
            path for path in run_root.iterdir() if path.is_dir()
        )
    except OSError:
        component_paths = []
    for component_path in component_paths:
        component_pids = read_text(component_path / "cgroup.procs")
        if not component_pids:
            continue
        parsed = [int(value) for value in component_pids.splitlines() if value.isdigit()]
        if parsed:
            components.append(component_path.name)
            pids.extend(parsed)
            active_cgroups.append(component_path)

    process_rows = [row for pid in pids if (row := process_metrics(pid))]
    totals = {
        key: sum(row[key] for row in process_rows)
        for key in (
            "cpu_milliseconds",
            "rss_bytes",
            "rss_anon_bytes",
            "rss_file_bytes",
            "swap_bytes",
            "read_bytes",
            "write_bytes",
        )
    }
    elapsed = max((row["elapsed_seconds"] for row in process_rows), default=0)
    spill_fds, spill_objects, spill_logical, spill_allocated = spill_metrics(pids)
    memory_stat = read_key_values(service / "memory.stat")
    memory_events = read_key_values(service / "memory.events")
    component_memory_current = sum(
        int(value)
        for path in active_cgroups
        if (value := read_text(path / "memory.current")) is not None
        and value.isdigit()
    )
    component_memory_maxima = [
        value
        for path in active_cgroups
        if (value := read_text(path / "memory.max")) is not None
    ]
    component_events = [
        read_key_values(path / "memory.events") for path in active_cgroups
    ]

    print(f"runtime_component={','.join(components) if components else 'transitioning'}")
    print(f"candidate_pids={','.join(str(pid) for pid in pids) if pids else 'none'}")
    print(f"candidate_elapsed_seconds={elapsed}")
    for key, value in totals.items():
        print(f"candidate_{key}={value}")
    print(f"spill_descriptors={spill_fds}")
    print(f"spill_objects={spill_objects}")
    print(f"spill_logical_bytes={spill_logical}")
    print(f"spill_allocated_bytes={spill_allocated}")
    print(f"cgroup_memory_current_bytes={read_text(service / 'memory.current') or 'unknown'}")
    print(f"cgroup_memory_max_bytes={read_text(service / 'memory.max') or 'unknown'}")
    print(f"component_memory_current_bytes={component_memory_current}")
    print(
        "component_memory_max_bytes="
        + (",".join(component_memory_maxima) if component_memory_maxima else "unknown")
    )
    print(f"cgroup_anon_bytes={memory_stat.get('anon', 0)}")
    print(f"cgroup_file_bytes={memory_stat.get('file', 0)}")
    print(f"cgroup_oom_kill_count={memory_events.get('oom_kill', 0)}")
    print(f"cgroup_limit_hit_count={memory_events.get('max', 0)}")
    print(
        "component_oom_kill_count="
        + str(sum(events.get("oom_kill", 0) for events in component_events))
    )
    print(
        "component_limit_hit_count="
        + str(sum(events.get("max", 0) for events in component_events))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
