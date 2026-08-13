#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
JOB_ROOT=${LONG_JOB_ROOT:-"$ROOT/build/long-jobs"}

usage()
{
  cat <<'EOF'
Usage:
  tools/long-job.sh start NAME -- COMMAND [ARG...]
  tools/long-job.sh attach NAME PID [WATCH_PATH] [DESCRIPTION...]
  tools/long-job.sh status NAME
  tools/long-job.sh watch NAME [INTERVAL_SECONDS]
  tools/long-job.sh follow NAME
  tools/long-job.sh wait NAME [INTERVAL_SECONDS]
  tools/long-job.sh stop NAME
  tools/long-job.sh list

Long jobs run independently of the invoking terminal. Logs and state are kept
under build/long-jobs/ by default. Set LONG_JOB_ROOT to override that location.
EOF
}

die()
{
  printf 'error: %s\n' "$*" >&2
  exit 1
}

validate_name()
{
  case "$1" in
    ''|*[!A-Za-z0-9._-]*) die "invalid job name: $1" ;;
  esac
}

job_dir()
{
  validate_name "$1"
  printf '%s/%s\n' "$JOB_ROOT" "$1"
}

read_pid()
{
  local dir=$1
  test -f "$dir/pid" || return 1
  cat "$dir/pid"
}

is_alive()
{
  local pid=$1
  kill -0 "$pid" 2>/dev/null
}

run_probe()
{
  local dir=$1
  local probe_path first_line

  PROBE_STATE=unknown
  PROBE_OUTPUT=
  test -f "$dir/probe_path" || return 0
  probe_path=$(cat "$dir/probe_path")
  if [ ! -x "$probe_path" ]; then
    PROBE_OUTPUT="probe is not executable: $probe_path"
    return 0
  fi

  PROBE_OUTPUT=$("$probe_path" 2>&1 || true)
  first_line=$(printf '%s\n' "$PROBE_OUTPUT" | sed -n '1p')
  case "$first_line" in
    running|complete|failed|unknown) PROBE_STATE=$first_line ;;
    *) PROBE_STATE=unknown ;;
  esac
}

write_command()
{
  local file=$1
  shift
  {
    printf '%q' "$1"
    shift
    if [ "$#" -gt 0 ]; then
      printf ' %q' "$@"
    fi
    printf '\n'
  } > "$file"
}

run_job()
{
  local dir=$1
  shift
  local rc

  printf '%s\n' "$$" > "$dir/pid"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$dir/started_at"
  printf '%s\n' running > "$dir/state"
  set +e
  "$@" >> "$dir/job.log" 2>&1
  rc=$?
  set -e
  printf '%s\n' "$rc" > "$dir/exit_code"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$dir/finished_at"
  if [ "$rc" -eq 0 ]; then
    printf '%s\n' complete > "$dir/state"
  else
    printf '%s\n' failed > "$dir/state"
  fi
}

start_job()
{
  local name=$1
  shift
  test "${1:-}" = -- || die "start requires -- before COMMAND"
  shift
  test "$#" -gt 0 || die "start requires COMMAND"

  local dir pid
  dir=$(job_dir "$name")
  if pid=$(read_pid "$dir" 2>/dev/null) && is_alive "$pid"; then
    die "job $name is already running as PID $pid"
  fi

  mkdir -p "$dir"
  : > "$dir/job.log"
  rm -f "$dir/exit_code" "$dir/finished_at" "$dir/failure_reason" \
    "$dir/progress"
  printf '%s\n' managed > "$dir/mode"
  write_command "$dir/command.txt" "$@"
  nohup "$0" _run "$dir" "$@" >/dev/null 2>&1 &
  pid=$!
  printf '%s\n' "$pid" > "$dir/pid"
  printf 'started %s as PID %s\n' "$name" "$pid"
  printf 'status: %s status %s\n' "$0" "$name"
  printf 'follow: %s follow %s\n' "$0" "$name"
}

attach_job()
{
  local name=$1
  local pid=$2
  shift 2
  local watch_path=${1:-}
  if [ "$#" -gt 0 ]; then
    shift
  fi
  is_alive "$pid" || die "PID is not running: $pid"

  local dir
  dir=$(job_dir "$name")
  mkdir -p "$dir"
  printf '%s\n' "$pid" > "$dir/pid"
  printf '%s\n' attached > "$dir/mode"
  printf '%s\n' running > "$dir/state"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$dir/started_at"
  if [ -n "$watch_path" ]; then
    case "$watch_path" in
      /*) printf '%s\n' "$watch_path" > "$dir/watch_path" ;;
      *) printf '%s/%s\n' "$ROOT" "$watch_path" > "$dir/watch_path" ;;
    esac
  fi
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$*" > "$dir/command.txt"
  else
    ps -p "$pid" -o command= > "$dir/command.txt" 2>/dev/null || true
  fi
  printf 'attached %s to PID %s\n' "$name" "$pid"
}

show_probe()
{
  local dir=$1
  test -f "$dir/watch_path" || return 0
  local path physical_path
  path=$(cat "$dir/watch_path")
  printf 'watch_path: %s\n' "$path"
  if [ -e "$path" ]; then
    physical_path=$path
    if [ -d "$path" ]; then
      physical_path=$(cd "$path" && pwd -P)
    fi
    if [ "$physical_path" != "$path" ]; then
      printf 'watch_path_resolved: %s\n' "$physical_path"
    fi
    du -sh "$physical_path" 2>/dev/null || true
    if [ -d "$path/.git" ]; then
      git -C "$path" rev-parse --short HEAD 2>/dev/null \
        | sed 's/^/git_head: /' || printf 'git_head: not ready\n'
      if [ ! -f "$dir/suppress_git_status" ]; then
        git -C "$path" status --short --branch --untracked-files=no 2>/dev/null \
          | head -n 20 || true
      fi
    fi
  else
    printf 'watch_path_state: absent\n'
  fi
}

show_progress()
{
  local dir=$1
  local state=$2
  local progress_line percent

  if [ -f "$dir/progress" ]; then
    sed 's/^/progress: /' "$dir/progress"
    return 0
  fi

  if [ -s "$dir/job.log" ]; then
    progress_line=$(
      tail -c 1048576 "$dir/job.log" 2>/dev/null \
        | tr '\r' '\n' \
        | sed $'s/\033\\[[0-9;]*[[:alpha:]]//g' \
        | grep -E '[0-9]{1,3}%' \
        | tail -n 1 \
        || true
    )
    percent=$(printf '%s\n' "$progress_line" | grep -Eo '[0-9]{1,3}%' | tail -n 1 || true)
    if [ -n "$percent" ]; then
      printf 'progress: %s\n' "$percent"
      printf 'progress_detail: %s\n' "$progress_line"
      return 0
    fi
  fi

  if [ "$state" = complete ]; then
    printf 'progress: 100%%\n'
  elif [ "$state" = running ]; then
    printf 'progress: unavailable (waiting for command progress output)\n'
  fi
}

status_job()
{
  local name=$1
  local dir pid mode state persisted_state
  dir=$(job_dir "$name")
  test -d "$dir" || die "unknown job: $name"
  pid=$(read_pid "$dir" 2>/dev/null || true)
  mode=$(cat "$dir/mode" 2>/dev/null || printf unknown)
  state=$(cat "$dir/state" 2>/dev/null || printf unknown)
  persisted_state=$state
  if [ "$mode" = external ]; then
    run_probe "$dir"
    state=$PROBE_STATE
    if [ "$state" = complete ] && [ "$persisted_state" != complete ]; then
      printf '%s\n' complete > "$dir/state"
      printf '%s\n' 0 > "$dir/exit_code"
      date -u +%Y-%m-%dT%H:%M:%SZ > "$dir/finished_at"
    elif [ "$state" = failed ] && [ "$persisted_state" != failed ]; then
      printf '%s\n' failed > "$dir/state"
      date -u +%Y-%m-%dT%H:%M:%SZ > "$dir/finished_at"
    fi
  elif [ -n "$pid" ] && is_alive "$pid"; then
    state=running
  elif [ "$mode" = managed ] && [ "$persisted_state" = running ] &&
       [ ! -f "$dir/exit_code" ]; then
    state=failed
    printf '%s\n' failed > "$dir/state"
    printf '%s\n' 125 > "$dir/exit_code"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$dir/finished_at"
    printf '%s\n' \
      'managed launcher exited without recording completion' \
      > "$dir/failure_reason"
  elif [ "$mode" = attached ] && [ ! -f "$dir/exit_code" ]; then
    state=finished-exit-unknown
  fi

  STATUS_STATE=$state

  printf 'name: %s\nmode: %s\nstate: %s\n' "$name" "$mode" "$state"
  if [ "$mode" = external ]; then
    printf 'pid: external\n'
    case "$pid" in
      ''|*[!0-9]*) printf 'launcher_pid: not-applicable\n' ;;
      *) printf 'launcher_pid: %s (%s)\n' \
           "$pid" "$(if is_alive "$pid"; then printf alive; else printf exited; fi)" ;;
    esac
  else
    printf 'pid: %s\n' "${pid:-unknown}"
  fi
  test ! -f "$dir/command.txt" || sed 's/^/command: /' "$dir/command.txt"
  test ! -f "$dir/started_at" || sed 's/^/started_at: /' "$dir/started_at"
  test ! -f "$dir/finished_at" || sed 's/^/finished_at: /' "$dir/finished_at"
  test ! -f "$dir/exit_code" || sed 's/^/exit_code: /' "$dir/exit_code"
  test ! -f "$dir/failure_reason" || \
    sed 's/^/failure_reason: /' "$dir/failure_reason"
  show_probe "$dir"
  show_progress "$dir" "$state"
  if [ "$mode" = external ] && [ -n "${PROBE_OUTPUT:-}" ]; then
    printf '%s\n' '--- external probe ---'
    printf '%s\n' "$PROBE_OUTPUT" | sed -n '2,$p'
  fi
  if [ -s "$dir/job.log" ]; then
    printf '%s\n' '--- log tail ---'
    tail -c 131072 "$dir/job.log" 2>/dev/null \
      | tr '\r' '\n' \
      | sed $'s/\033\\[[0-9;]*[[:alpha:]]//g' \
      | tail -n 30
  fi
}

follow_job()
{
  local name=$1
  local dir pid tail_pid
  dir=$(job_dir "$name")
  test -d "$dir" || die "unknown job: $name"
  test -f "$dir/job.log" || {
    status_job "$name"
    die "attached jobs have no captured log"
  }
  pid=$(read_pid "$dir")
  tail -n 80 -f "$dir/job.log" &
  tail_pid=$!
  trap 'kill "$tail_pid" 2>/dev/null || true' EXIT INT TERM
  while is_alive "$pid"; do
    sleep 2
  done
  kill "$tail_pid" 2>/dev/null || true
  wait "$tail_pid" 2>/dev/null || true
  status_job "$name"
}

wait_job()
{
  local name=$1
  local interval=${2:-10}
  local dir pid mode
  dir=$(job_dir "$name")
  test -d "$dir" || die "unknown job: $name"
  mode=$(cat "$dir/mode" 2>/dev/null || printf unknown)
  if [ "$mode" = external ]; then
    while :; do
      run_probe "$dir"
      case "$PROBE_STATE" in
        running|unknown) sleep "$interval" ;;
        *) break ;;
      esac
    done
    status_job "$name"
    return 0
  fi
  pid=$(read_pid "$dir")
  while is_alive "$pid"; do
    sleep "$interval"
  done
  status_job "$name"
}

watch_job()
{
  local name=$1
  local interval=${2:-30}
  local dir
  dir=$(job_dir "$name")
  test -d "$dir" || die "unknown job: $name"
  case "$interval" in
    ''|*[!0-9]*) die "interval must be a positive integer" ;;
    0) die "interval must be greater than zero" ;;
  esac

  while :; do
    if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ]; then
      clear || true
    fi
    printf 'updated_at: %s\nrefresh_interval: %ss\n\n' \
      "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$interval"
    status_job "$name"
    if [ "$STATUS_STATE" != running ] && [ "$STATUS_STATE" != unknown ]; then
      printf '\njob is no longer running; monitor finished.\n'
      break
    fi
    printf '\nPress Ctrl-C to stop monitoring (the job will keep running).\n'
    sleep "$interval"
  done
}

stop_job()
{
  local name=$1
  local dir pid
  dir=$(job_dir "$name")
  pid=$(read_pid "$dir")
  if is_alive "$pid"; then
    kill "$pid"
    printf 'sent TERM to %s (PID %s)\n' "$name" "$pid"
  else
    printf '%s is not running\n' "$name"
  fi
}

list_jobs()
{
  local dir
  mkdir -p "$JOB_ROOT"
  for dir in "$JOB_ROOT"/*; do
    test -d "$dir" || continue
    status_job "$(basename "$dir")" | sed -n '1,4p'
    printf '\n'
  done
}

command=${1:-}
case "$command" in
  start)
    test "$#" -ge 4 || { usage; exit 2; }
    shift
    start_job "$@"
    ;;
  attach)
    test "$#" -ge 3 || { usage; exit 2; }
    shift
    attach_job "$@"
    ;;
  status|follow|stop)
    test "$#" -eq 2 || { usage; exit 2; }
    shift
    "${command}_job" "$@"
    ;;
  wait|watch)
    if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
      usage
      exit 2
    fi
    shift
    "${command}_job" "$@"
    ;;
  list)
    test "$#" -eq 1 || { usage; exit 2; }
    list_jobs
    ;;
  _run)
    test "$#" -ge 3 || exit 2
    shift
    run_job "$@"
    ;;
  -h|--help|help|'')
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
