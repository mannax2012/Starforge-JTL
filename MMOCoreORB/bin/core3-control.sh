#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${CORE3_BIN_DIR:-${REPO_ROOT}/bin}"
SERVER_BIN="${CORE3_SERVER_BIN:-${BIN_DIR}/core3}"
LOG_DIR="${CORE3_LOG_DIR:-${BIN_DIR}/log}"
SCREEN_DIR="${CORE3_SCREEN_DIR:-${LOG_DIR}/screen}"
CONTROL_LOG="${CORE3_CONTROL_LOG:-${LOG_DIR}/core3-control.log}"
CORE3_LOG="${CORE3_SERVER_LOG:-${LOG_DIR}/core3.log}"
GDB_SCREEN_LOG="${CORE3_GDB_SCREEN_LOG:-${LOG_DIR}/gdb-screen.log}"
GDB_STATE_FILE="${CORE3_GDB_STATE_FILE:-${LOG_DIR}/gdb-state.txt}"
GDB_LIVE_CRASH_FILE="${CORE3_GDB_LIVE_CRASH_FILE:-${BIN_DIR}/gdb-crash.txt}"
GDB_INIT_FILE="${CORE3_GDB_INIT_FILE:-${BIN_DIR}/gdb-session.gdb}"
SCREEN_SESSION="${CORE3_SCREEN_SESSION:-core3-gdb}"
RAW_PROCESS_NAME="${CORE3_RAW_PROCESS_NAME:-core3}"
CRASH_ROOT="${CORE3_CRASH_ROOT:-${LOG_DIR}/crash}"
LATEST_CAPTURE_FILE="${CORE3_LATEST_CAPTURE_FILE:-${CRASH_ROOT}/latest_capture.txt}"
TAIL_LINES="${CORE3_TAIL_LINES:-400}"
RUN_WAIT_SECONDS="${CORE3_RUN_WAIT_SECONDS:-90}"

export SCREENDIR="${SCREEN_DIR}"

timestamp() {
  date +"%Y-%m-%d_%H-%M-%S"
}

log() {
  local message="$1"
  mkdir -p "${LOG_DIR}"
  printf '[%s] %s\n' "$(date +"%Y-%m-%d %H:%M:%S")" "${message}" >>"${CONTROL_LOG}"
}

fail() {
  log "ERROR: $1"
  printf 'ERROR\n' >&2
  exit 1
}

require_file() {
  local path="$1"
  local description="$2"

  [[ -f "${path}" ]] || fail "${description} not found at ${path}"
}

require_tool() {
  local name="$1"
  command -v "${name}" >/dev/null 2>&1 || fail "required tool not found: ${name}"
}

cleanup_dead_screens() {
  if [[ -d "${SCREEN_DIR}" ]]; then
    screen -wipe >/dev/null 2>&1 || true
  fi
}

session_exists() {
  cleanup_dead_screens
  screen -ls 2>/dev/null | grep -F "${SCREEN_SESSION}" | grep -Eq 'Attached|Detached'
}

raw_server_pids() {
  pgrep -x "${RAW_PROCESS_NAME}" || true
}

raw_server_running() {
  [[ -n "$(raw_server_pids)" ]]
}

wait_for_run_state() {
  for _ in $(seq 1 "${RUN_WAIT_SECONDS}"); do
    if [[ "$(gdb_state)" == "running" ]] || raw_server_running; then
      return 0
    fi
    sleep 1
  done

  return 1
}

wait_for_pid_exit() {
  local pid="$1"

  for _ in $(seq 1 20); do
    if ! kill -0 "${pid}" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done

  return 1
}

gdb_state() {
  if [[ -f "${GDB_STATE_FILE}" ]]; then
    <"${GDB_STATE_FILE}" tr -d '\r'
  else
    printf 'unknown\n'
  fi
}

ensure_paths() {
  mkdir -p "${LOG_DIR}" "${CRASH_ROOT}" "${SCREEN_DIR}"
  chmod 700 "${SCREEN_DIR}" 2>/dev/null || true
  cleanup_dead_screens
}

ensure_session() {
  require_tool screen
  require_tool gdb
  require_file "${SERVER_BIN}" "core3 binary"
  require_file "${GDB_INIT_FILE}" "gdb session init file"

  ensure_paths

  if session_exists; then
    return 0
  fi

  if raw_server_running; then
    fail "core3 is already running outside the managed gdb screen session; stop that process before using this script"
  fi

  printf 'stopped\n' >"${GDB_STATE_FILE}"
  : >"${GDB_SCREEN_LOG}"

  log "Creating screen session ${SCREEN_SESSION}"
  screen -dmS "${SCREEN_SESSION}" -L -Logfile "${GDB_SCREEN_LOG}" bash -c "cd '${BIN_DIR}' && exec gdb -q -x '${GDB_INIT_FILE}' '${SERVER_BIN}'"

  sleep 2

  session_exists || fail "failed to create screen session ${SCREEN_SESSION}"
}

send_to_gdb() {
  local command="$1"
  screen -S "${SCREEN_SESSION}" -p 0 -X stuff "${command}"$'\r'
}

hardcopy_screen() {
  local target="$1"
  screen -S "${SCREEN_SESSION}" -p 0 -X hardcopy -h "${target}"
}

gdb_prompt_contains_crash() {
  local tmp
  tmp="$(mktemp)"
  hardcopy_screen "${tmp}"

  if grep -Eq 'received signal SIG|Program received signal' "${tmp}"; then
    rm -f "${tmp}"
    return 0
  fi

  rm -f "${tmp}"
  return 1
}

current_capture_dir() {
  local dir
  dir="${CRASH_ROOT}/$(timestamp)"
  mkdir -p "${dir}"
  printf '%s\n' "${dir}"
}

capture_log_snapshot() {
  local capture_dir="$1"

  mkdir -p "${capture_dir}"

  if [[ -f "${CORE3_LOG}" ]]; then
    cp -a "${CORE3_LOG}" "${capture_dir}/core3.log"
    tail -n "${TAIL_LINES}" "${CORE3_LOG}" >"${capture_dir}/core3.log.tail"
  fi

  if [[ -f "${GDB_SCREEN_LOG}" ]]; then
    cp -a "${GDB_SCREEN_LOG}" "${capture_dir}/gdb-screen.log"
    tail -n "${TAIL_LINES}" "${GDB_SCREEN_LOG}" >"${capture_dir}/gdb-screen.log.tail"
  fi

  hardcopy_screen "${capture_dir}/gdb-screen-hardcopy.txt" || true

  {
    printf 'timestamp=%s\n' "$(date --iso-8601=seconds)"
    printf 'screen_session=%s\n' "${SCREEN_SESSION}"
    printf 'gdb_state=%s\n' "$(gdb_state)"
    printf 'server_bin=%s\n' "${SERVER_BIN}"
  } >"${capture_dir}/metadata.txt"

  printf '%s\n' "${capture_dir}" >"${LATEST_CAPTURE_FILE}"
}

capture_live_gdb_dump_if_crashed() {
  local capture_dir="$1"
  local target_file="${capture_dir}/gdb-crash.txt"

  if ! gdb_prompt_contains_crash; then
    cat >"${target_file}" <<'EOF'
No live crash state was present in the gdb session at capture time.
The gdb session was at an idle prompt, so no crash backtrace commands were run.
To capture bt 20 / thread apply all bt output, run capture-crash while gdb is stopped on the crash.
EOF
    return 0
  fi

  rm -f "${GDB_LIVE_CRASH_FILE}" "${target_file}"

  send_to_gdb 'source ../gdb-crash.gdb'
  sleep 1
  send_to_gdb 'crashdump'

  for _ in $(seq 1 20); do
    if [[ -f "${GDB_LIVE_CRASH_FILE}" ]]; then
      mv "${GDB_LIVE_CRASH_FILE}" "${target_file}"
      log "Captured live gdb crash dump in ${target_file}"
      return 0
    fi
    sleep 1
  done

  log "Timed out waiting for gdb-crash.txt from live gdb session"
}

capture_crash_artifacts() {
  ensure_session

  local capture_dir
  capture_dir="$(current_capture_dir)"

  capture_log_snapshot "${capture_dir}"
  capture_live_gdb_dump_if_crashed "${capture_dir}"

  printf '%s\n' "${capture_dir}"
}

capture_if_crashed() {
  ensure_session

  if gdb_prompt_contains_crash; then
    capture_crash_artifacts >/dev/null
  fi
}

run_server() {
  ensure_session

  local state
  state="$(gdb_state)"

  if [[ "${state}" == "running" ]]; then
    log "run requested while inferior is already running in ${SCREEN_SESSION}"
    return 0
  fi

  capture_if_crashed

  log "Sending run to gdb session ${SCREEN_SESSION}"
  send_to_gdb 'run'

  if ! wait_for_run_state; then
    fail "gdb session did not enter running state within ${RUN_WAIT_SECONDS}s; attach to ${SCREEN_SESSION} to inspect the terminal"
  fi
}

status_server() {
  local state
  state="$(gdb_state)"

  if session_exists; then
    printf 'session=%s\n' "${SCREEN_SESSION}"
    printf 'gdb_state=%s\n' "${state}"
  else
    printf 'session=missing\n'
    printf 'gdb_state=missing\n'
  fi

  local pids
  pids="$(raw_server_pids | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  if [[ -n "${pids}" ]]; then
    printf 'core3_pids=%s\n' "${pids}"
  fi

  if [[ -f "${LATEST_CAPTURE_FILE}" ]]; then
    printf 'latest_capture=%s\n' "$(<"${LATEST_CAPTURE_FILE}")"
  fi
}

attach_session() {
  ensure_session
  exec screen -r "${SCREEN_SESSION}"
}

stop_server() {
  if ! session_exists; then
    if raw_server_running; then
      local pid
      for pid in $(raw_server_pids); do
        log "Stopping unmanaged core3 pid=${pid}"
        kill -TERM "${pid}" 2>/dev/null || true
        if ! wait_for_pid_exit "${pid}"; then
          log "Unmanaged core3 pid=${pid} did not stop after SIGTERM; sending SIGKILL"
          kill -KILL "${pid}" 2>/dev/null || true
        fi
      done
    else
      log "stop requested but screen session ${SCREEN_SESSION} does not exist"
    fi
    return 0
  fi

  local state
  state="$(gdb_state)"

  if [[ "${state}" == "running" ]]; then
    log "Interrupting running inferior in ${SCREEN_SESSION}"
    screen -S "${SCREEN_SESSION}" -p 0 -X stuff $'\003'
    sleep 2
  fi

  log "Stopping screen session ${SCREEN_SESSION}"
  screen -S "${SCREEN_SESSION}" -X quit || true
  rm -f "${GDB_STATE_FILE}"
}

usage() {
  cat <<'EOF'
Usage: core3-control.sh [command]

Commands:
  run              Capture any current crash state, then send `run` to the gdb session.
  attach           Reattach to the persistent screen session running gdb ./core3.
  status           Show whether the screen session exists and whether gdb is running/stopped.
  capture-crash    Archive the current gdb/log state into a timestamped crash folder.
  stop             Stop the screen session (interrupting the inferior first if needed).
EOF
}

main() {
  local command="${1:-run}"

  case "${command}" in
    run)
      run_server
      status_server
      ;;
    attach)
      attach_session
      ;;
    status)
      status_server
      ;;
    capture-crash)
      local capture_dir
      capture_dir="$(capture_crash_artifacts)"
      printf 'capture_dir=%s\n' "${capture_dir}"
      printf 'SUCCESS\n'
      ;;
    stop)
      stop_server
      status_server
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
