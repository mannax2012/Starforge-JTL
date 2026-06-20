#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CALLER_DIR="${CORE3_CALLER_DIR:-$(pwd -P)}"
BIN_DIR="${CORE3_BIN_DIR:-${REPO_ROOT}/bin}"
SERVER_BIN="${CORE3_SERVER_BIN:-${BIN_DIR}/core3}"
LOG_DIR="${CORE3_LOG_DIR:-${CALLER_DIR}/log}"
SCREEN_DIR="${CORE3_SCREEN_DIR:-${LOG_DIR}/screen}"
CONTROL_LOG="${CORE3_CONTROL_LOG:-${LOG_DIR}/core3-control.log}"
CORE3_LOG="${CORE3_SERVER_LOG:-${BIN_DIR}/log/core3.log}"
GDB_SCREEN_LOG="${CORE3_GDB_SCREEN_LOG:-${LOG_DIR}/gdb-screen.log}"
GDB_STATE_FILE="${CORE3_GDB_STATE_FILE:-${LOG_DIR}/gdb-state.txt}"
GDB_LIVE_CRASH_FILE="${CORE3_GDB_LIVE_CRASH_FILE:-${LOG_DIR}/gdb-crash.txt}"
GDB_INIT_FILE="${CORE3_GDB_INIT_FILE:-${BIN_DIR}/gdb-session.gdb}"
GDB_CRASH_SCRIPT="${CORE3_GDB_CRASH_SCRIPT:-${REPO_ROOT}/gdb-crash.gdb}"
SCREEN_SESSION="${CORE3_SCREEN_SESSION:-core3-gdb}"
RAW_PROCESS_NAME="${CORE3_RAW_PROCESS_NAME:-core3}"
CRASH_ROOT="${CORE3_CRASH_ROOT:-${LOG_DIR}/crash}"
LATEST_CAPTURE_FILE="${CORE3_LATEST_CAPTURE_FILE:-${CRASH_ROOT}/latest_capture.txt}"
BACKUP_ROOT="${CORE3_BACKUP_ROOT:-${LOG_DIR}/backup}"
LATEST_BACKUP_FILE="${CORE3_LATEST_BACKUP_FILE:-${BACKUP_ROOT}/latest_backup.txt}"
BACKUP_KEEP_RAW="${CORE3_BACKUP_KEEP_RAW:-0}"
BACKUP_KEEP_COUNT="${CORE3_BACKUP_KEEP_COUNT:-5}"
TAIL_LINES="${CORE3_TAIL_LINES:-400}"
RUN_WAIT_SECONDS="${CORE3_RUN_WAIT_SECONDS:-90}"
SHUTDOWN_WAIT_SECONDS="${CORE3_SHUTDOWN_WAIT_SECONDS:-180}"
STOP_SHUTDOWN_WAIT_SECONDS="${CORE3_STOP_SHUTDOWN_WAIT_SECONDS:-15}"
RUN_ARGUMENTS="${CORE3_RUN_ARGUMENTS:-}"
EMAIL_ENABLED="${CORE3_EMAIL_ENABLED:-0}"
EMAIL_TO="${CORE3_EMAIL_TO:-}"
EMAIL_FROM="${CORE3_EMAIL_FROM:-${EMAIL_TO}}"
EMAIL_SMTP_HOST="${CORE3_EMAIL_SMTP_HOST:-}"
EMAIL_SMTP_PORT="${CORE3_EMAIL_SMTP_PORT:-587}"
EMAIL_SMTP_USER="${CORE3_EMAIL_SMTP_USER:-}"
EMAIL_SMTP_PASS="${CORE3_EMAIL_SMTP_PASS:-}"
EMAIL_SMTP_STARTTLS="${CORE3_EMAIL_SMTP_STARTTLS:-1}"
EMAIL_SUBJECT_PREFIX="${CORE3_EMAIL_SUBJECT_PREFIX:-[core3-capture]}"
TRANSFER_ENABLED="${CORE3_TRANSFER_ENABLED:-0}"
TRANSFER_DEST="${CORE3_TRANSFER_DEST:-}"
TRANSFER_PATH="${CORE3_TRANSFER_PATH:-}"
TRANSFER_PORT="${CORE3_TRANSFER_PORT:-22}"
TRANSFER_SSH_KEY="${CORE3_TRANSFER_SSH_KEY:-}"
TRANSFER_STRICT_HOST_KEY_CHECKING="${CORE3_TRANSFER_STRICT_HOST_KEY_CHECKING:-1}"
TRANSFER_KNOWN_HOSTS="${CORE3_TRANSFER_KNOWN_HOSTS:-${HOME}/.ssh/known_hosts}"
SQL_BACKUP_ENABLED="${CORE3_SQL_BACKUP_ENABLED:-0}"
SQL_DUMP_TOOL="${CORE3_SQL_DUMP_TOOL:-mysqldump}"
SQL_HOST="${CORE3_SQL_HOST:-localhost}"
SQL_PORT="${CORE3_SQL_PORT:-3306}"
SQL_USER="${CORE3_SQL_USER:-}"
SQL_PASSWORD="${CORE3_SQL_PASSWORD:-}"
SQL_DATABASE="${CORE3_SQL_DATABASE:-}"
DB_RECOVER_TOOL_OVERRIDE="${CORE3_DB_RECOVER_TOOL:-}"
DB_HOTBACKUP_TOOL_OVERRIDE="${CORE3_DB_HOTBACKUP_TOOL:-}"
AUTO_RECOVER_DB="${CORE3_AUTO_RECOVER_DB:-0}"

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
  printf 'ERROR: %s\n' "$1" >&2
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

find_tool() {
  local name

  for name in "$@"; do
    if command -v "${name}" >/dev/null 2>&1; then
      printf '%s\n' "${name}"
      return 0
    fi
  done

  return 1
}

db_recover_tool() {
  if [[ -n "${DB_RECOVER_TOOL_OVERRIDE}" ]]; then
    require_tool "${DB_RECOVER_TOOL_OVERRIDE}"
    printf '%s\n' "${DB_RECOVER_TOOL_OVERRIDE}"
    return 0
  fi

  find_tool db_recover db5.3_recover db5.1_recover db4.8_recover ||
    fail "required Berkeley DB recovery tool not found. Install db_recover or set CORE3_DB_RECOVER_TOOL to the correct executable."
}

db_hotbackup_tool() {
  if [[ -n "${DB_HOTBACKUP_TOOL_OVERRIDE}" ]]; then
    require_tool "${DB_HOTBACKUP_TOOL_OVERRIDE}"
    printf '%s\n' "${DB_HOTBACKUP_TOOL_OVERRIDE}"
    return 0
  fi

  find_tool db_hotbackup db5.3_hotbackup db5.1_hotbackup db4.8_hotbackup ||
    fail "required Berkeley DB hot backup tool not found. Install db_hotbackup or set CORE3_DB_HOTBACKUP_TOOL to the correct executable."
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
  ps -C "${RAW_PROCESS_NAME}" -o pid=,stat= 2>/dev/null | awk '$2 !~ /^Z/ { print $1 }' || true
}

raw_server_zombie_pids() {
  ps -C "${RAW_PROCESS_NAME}" -o pid=,stat= 2>/dev/null | awk '$2 ~ /^Z/ { print $1 }' || true
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

wait_for_shutdown_state() {
  local total_wait_seconds="$1"

  for _ in $(seq 1 "${total_wait_seconds}"); do
    if ! raw_server_running && [[ "$(gdb_state)" == "stopped" ]]; then
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

wait_for_server_exit() {
  local total_wait_seconds="${1:-20}"

  for _ in $(seq 1 "${total_wait_seconds}"); do
    if ! raw_server_running; then
      return 0
    fi
    sleep 1
  done

  return 1
}

gdb_state() {
  if [[ -f "${GDB_STATE_FILE}" ]]; then
    <"${GDB_STATE_FILE}" tr -d '\r'
  elif raw_server_running; then
    printf 'running\n'
  else
    printf 'stopped\n'
  fi
}

ensure_paths() {
  mkdir -p "${LOG_DIR}" "${CRASH_ROOT}" "${BACKUP_ROOT}" "${SCREEN_DIR}"
  chmod 700 "${SCREEN_DIR}" 2>/dev/null || true
  cleanup_dead_screens
}

ensure_session() {
  require_tool screen
  require_tool gdb
  require_file "${SERVER_BIN}" "core3 binary"
  require_file "${GDB_INIT_FILE}" "gdb session init file"
  require_file "${GDB_CRASH_SCRIPT}" "gdb crash macro file"

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
  screen -dmS "${SCREEN_SESSION}" -L -Logfile "${GDB_SCREEN_LOG}" bash -c "cd '${BIN_DIR}' && export CORE3_GDB_STATE_FILE='${GDB_STATE_FILE}' && exec gdb -q -x '${GDB_INIT_FILE}' '${SERVER_BIN}'"

  sleep 2

  session_exists || fail "failed to create screen session ${SCREEN_SESSION}"
}

require_existing_session() {
  ensure_paths

  if session_exists; then
    return 0
  fi

  local script_name
  script_name="$(basename "$0")"

  if raw_server_running; then
    local pids
    pids="$(raw_server_pids | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    fail "managed gdb screen session ${SCREEN_SESSION} is missing while core3 is running unmanaged (pid(s): ${pids}). Start core3 with ${script_name} run if you want crash capture, or stop the unmanaged process first."
  fi

  local state
  state="$(gdb_state)"
  fail "managed gdb screen session ${SCREEN_SESSION} does not exist (gdb_state=${state}). Run ${script_name} run first, then retry capture-crash once gdb is attached to the server."
}

require_running_managed_session() {
  require_existing_session

  local state
  state="$(gdb_state)"

  if [[ "${state}" != "running" ]] && ! raw_server_running; then
    fail "managed gdb session ${SCREEN_SESSION} is not running a live core3 process (gdb_state=${state}). Use $(basename "$0") run first or attach to inspect gdb."
  fi

  if [[ "${state}" != "running" ]]; then
    local pids
    pids="$(raw_server_pids | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    log "shutdown requested with gdb_state=${state} but live core3 pid(s) detected: ${pids}"
  fi
}

send_to_gdb() {
  local command="$1"
  screen -S "${SCREEN_SESSION}" -p 0 -X stuff "${command}"$'\r'
}

stop_unmanaged_server() {
  local signal="$1"
  local failure_message="$2"
  local pid

  for pid in $(raw_server_pids); do
    log "Sending SIG${signal} to unmanaged core3 pid=${pid}"
    kill "-${signal}" "${pid}" 2>/dev/null || true
  done

  if ! wait_for_server_exit 20; then
    fail "${failure_message}"
  fi
}

kill_managed_inferior() {
  local state
  state="$(gdb_state)"

  if [[ "${state}" == "running" ]]; then
    log "Interrupting managed inferior in ${SCREEN_SESSION} via Ctrl-C"
    screen -S "${SCREEN_SESSION}" -p 0 -X stuff $'\003'
    sleep 2
  fi

  if raw_server_running; then
    log "Sending gdb kill to managed inferior in ${SCREEN_SESSION}"
    send_to_gdb 'kill'
    sleep 1
    send_to_gdb 'y'
  fi

  if raw_server_running; then
    stop_unmanaged_server TERM "managed core3 pid(s) did not stop after gdb kill; use force-stop if you need SIGKILL"
  fi
}

teardown_session() {
  if session_exists; then
    log "Stopping screen session ${SCREEN_SESSION}"
    screen -S "${SCREEN_SESSION}" -X quit || true
  fi

  rm -f "${GDB_STATE_FILE}"
}

configure_gdb_run_args() {
  if [[ -n "${RUN_ARGUMENTS}" ]]; then
    log "Configuring gdb inferior args: ${RUN_ARGUMENTS}"
    send_to_gdb "set args ${RUN_ARGUMENTS}"
  else
    log "Clearing gdb inferior args"
    send_to_gdb "set args"
  fi

  sleep 1
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

current_backup_dir() {
  local dir
  dir="${BACKUP_ROOT}/$(timestamp)-database"
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

email_capture_enabled() {
  [[ "${EMAIL_ENABLED}" == "1" ]]
}

email_capture_configured() {
  email_capture_enabled && [[ -n "${EMAIL_TO}" ]] && [[ -n "${EMAIL_FROM}" ]] && [[ -n "${EMAIL_SMTP_HOST}" ]]
}

create_zip_archive() {
  local source_dir="$1"
  local archive_path="$2"

  require_tool python3

  python3 - "${source_dir}" "${archive_path}" <<'PY'
import pathlib
import sys
import zipfile

source_dir = pathlib.Path(sys.argv[1]).resolve()
archive_path = pathlib.Path(sys.argv[2]).resolve()

archive_path.parent.mkdir(parents=True, exist_ok=True)

with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for path in sorted(source_dir.rglob("*")):
        if path == archive_path or not path.is_file():
            continue
        zf.write(path, arcname=path.relative_to(source_dir))
PY
}

transfer_enabled() {
  [[ "${TRANSFER_ENABLED}" == "1" ]]
}

transfer_configured() {
  transfer_enabled && [[ -n "${TRANSFER_DEST}" ]] && [[ -n "${TRANSFER_PATH}" ]]
}

ssh_option_args() {
  if [[ "${TRANSFER_STRICT_HOST_KEY_CHECKING}" == "1" ]]; then
    printf '%s\n' "-o" "StrictHostKeyChecking=yes" "-o" "UserKnownHostsFile=${TRANSFER_KNOWN_HOSTS}"
  else
    printf '%s\n' "-o" "StrictHostKeyChecking=no"
  fi
}

ensure_remote_transfer_path() {
  local remote_path="$1"
  local remote_quoted
  local ssh_args=()

  remote_quoted="$(printf '%q' "${remote_path}")"

  while IFS= read -r arg; do
    ssh_args+=("${arg}")
  done < <(ssh_option_args)

  require_tool ssh

  if [[ -n "${TRANSFER_SSH_KEY}" ]]; then
    require_file "${TRANSFER_SSH_KEY}" "transfer ssh key"
    ssh_args+=(-i "${TRANSFER_SSH_KEY}")
  fi

  ssh_args+=(-p "${TRANSFER_PORT}")
  ssh "${ssh_args[@]}" "${TRANSFER_DEST}" "mkdir -p -- ${remote_quoted}"
}

transfer_file() {
  local file_path="$1"
  local remote_path="$2"
  local scp_args=()

  while IFS= read -r arg; do
    scp_args+=("${arg}")
  done < <(ssh_option_args)

  require_tool scp

  if [[ -n "${TRANSFER_SSH_KEY}" ]]; then
    require_file "${TRANSFER_SSH_KEY}" "transfer ssh key"
    scp_args+=(-i "${TRANSFER_SSH_KEY}")
  fi

  scp_args+=(-P "${TRANSFER_PORT}")
  scp "${scp_args[@]}" "${file_path}" "${TRANSFER_DEST}:${remote_path}/"
}

transfer_artifact_if_configured() {
  local artifact_path="$1"
  local artifact_label="$2"

  if ! transfer_enabled; then
    return 0
  fi

  if ! transfer_configured; then
    log "Transfer skipped for ${artifact_label}: missing CORE3_TRANSFER_DEST or CORE3_TRANSFER_PATH"
    return 0
  fi

  if ! ensure_remote_transfer_path "${TRANSFER_PATH}"; then
    log "Transfer failed for ${artifact_label}: could not create remote path ${TRANSFER_PATH}"
    return 0
  fi

  if ! transfer_file "${artifact_path}" "${TRANSFER_PATH}"; then
    log "Transfer failed for ${artifact_label}: ${artifact_path}"
    return 0
  fi

  log "Transferred ${artifact_label} to ${TRANSFER_DEST}:${TRANSFER_PATH}"
}

rotate_backup_archives() {
  local keep_count="$1"
  local -a archives=()

  if ! [[ "${keep_count}" =~ ^[0-9]+$ ]]; then
    return 0
  fi

  if (( keep_count < 1 )); then
    return 0
  fi

  mapfile -t archives < <(find "${BACKUP_ROOT}" -maxdepth 1 -type f -name '*.zip' -printf '%T@ %p\n' | sort -nr | awk '{sub($1 FS, ""); print}')

  if (( ${#archives[@]} <= keep_count )); then
    return 0
  fi

  local index
  for (( index = keep_count; index < ${#archives[@]}; index++ )); do
    rm -f "${archives[${index}]}"
    log "Removed old backup archive ${archives[${index}]}"
  done
}

send_capture_email() {
  local capture_dir="$1"
  local archive_path="$2"

  CORE3_CAPTURE_DIR="${capture_dir}" \
  CORE3_CAPTURE_ARCHIVE="${archive_path}" \
  CORE3_EMAIL_TO="${EMAIL_TO}" \
  CORE3_EMAIL_FROM="${EMAIL_FROM}" \
  CORE3_EMAIL_SMTP_HOST="${EMAIL_SMTP_HOST}" \
  CORE3_EMAIL_SMTP_PORT="${EMAIL_SMTP_PORT}" \
  CORE3_EMAIL_SMTP_USER="${EMAIL_SMTP_USER}" \
  CORE3_EMAIL_SMTP_PASS="${EMAIL_SMTP_PASS}" \
  CORE3_EMAIL_SMTP_STARTTLS="${EMAIL_SMTP_STARTTLS}" \
  CORE3_EMAIL_SUBJECT_PREFIX="${EMAIL_SUBJECT_PREFIX}" \
  CORE3_SERVER_BIN="${SERVER_BIN}" \
  python3 - <<'PY'
import datetime
import os
import pathlib
import smtplib
import socket
import ssl
from email.message import EmailMessage

capture_dir = pathlib.Path(os.environ["CORE3_CAPTURE_DIR"]).resolve()
archive_path = pathlib.Path(os.environ["CORE3_CAPTURE_ARCHIVE"]).resolve()
to_addr = os.environ["CORE3_EMAIL_TO"]
from_addr = os.environ["CORE3_EMAIL_FROM"]
smtp_host = os.environ["CORE3_EMAIL_SMTP_HOST"]
smtp_port = int(os.environ["CORE3_EMAIL_SMTP_PORT"])
smtp_user = os.environ.get("CORE3_EMAIL_SMTP_USER", "")
smtp_pass = os.environ.get("CORE3_EMAIL_SMTP_PASS", "")
use_starttls = os.environ.get("CORE3_EMAIL_SMTP_STARTTLS", "1") != "0"
subject_prefix = os.environ.get("CORE3_EMAIL_SUBJECT_PREFIX", "[core3-capture]")
server_bin = os.environ.get("CORE3_SERVER_BIN", "core3")
hostname = socket.gethostname()
captured_at = datetime.datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")

msg = EmailMessage()
msg["Subject"] = f"{subject_prefix} {hostname} {capture_dir.name}"
msg["From"] = from_addr
msg["To"] = to_addr
msg.set_content(
    "\n".join(
        [
            "core3 crash capture created.",
            "",
            f"Host: {hostname}",
            f"Captured: {captured_at}",
            f"Server: {server_bin}",
            f"Capture directory: {capture_dir}",
            f"Attachment: {archive_path.name}",
        ]
    )
)

with archive_path.open("rb") as fh:
    msg.add_attachment(
        fh.read(),
        maintype="application",
        subtype="zip",
        filename=archive_path.name,
    )

if use_starttls:
    context = ssl.create_default_context()
    with smtplib.SMTP(smtp_host, smtp_port, timeout=30) as smtp:
        smtp.ehlo()
        smtp.starttls(context=context)
        smtp.ehlo()
        if smtp_user:
            smtp.login(smtp_user, smtp_pass)
        smtp.send_message(msg)
else:
    with smtplib.SMTP(smtp_host, smtp_port, timeout=30) as smtp:
        smtp.ehlo()
        if smtp_user:
            smtp.login(smtp_user, smtp_pass)
        smtp.send_message(msg)
PY
}

email_capture_artifacts() {
  local capture_dir="$1"
  local archive_path="${capture_dir}/capture.zip"

  if ! email_capture_enabled; then
    return 0
  fi

  if ! email_capture_configured; then
    log "Capture email skipped: missing CORE3_EMAIL_TO, CORE3_EMAIL_FROM, or CORE3_EMAIL_SMTP_HOST"
    return 0
  fi

  if ! create_zip_archive "${capture_dir}" "${archive_path}"; then
    log "Capture email skipped: failed to create archive for ${capture_dir}"
    return 0
  fi

  if ! send_capture_email "${capture_dir}" "${archive_path}"; then
    log "Capture email failed for ${capture_dir}"
    return 0
  fi

  log "Capture email sent for ${capture_dir} to ${EMAIL_TO}"
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

  send_to_gdb "source ${GDB_CRASH_SCRIPT}"
  sleep 1
  send_to_gdb "crashdump_to ${GDB_LIVE_CRASH_FILE}"

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
  require_existing_session

  local capture_dir
  local capture_archive
  capture_dir="$(current_capture_dir)"
  capture_archive="${capture_dir}/capture.zip"

  capture_log_snapshot "${capture_dir}"
  capture_live_gdb_dump_if_crashed "${capture_dir}"
  email_capture_artifacts "${capture_dir}"

  if transfer_enabled; then
    if create_zip_archive "${capture_dir}" "${capture_archive}"; then
      transfer_artifact_if_configured "${capture_archive}" "capture archive"
    else
      log "Transfer skipped for capture archive: failed to create archive for ${capture_dir}"
    fi
  fi

  printf '%s\n' "${capture_dir}"
}

capture_if_crashed() {
  ensure_session

  if gdb_prompt_contains_crash; then
    capture_crash_artifacts >/dev/null
  fi
}

shutdown_server() {
  require_running_managed_session

  local shutdown_args="${*:-0}"
  local shutdown_minutes=0
  local shutdown_wait_seconds="${SHUTDOWN_WAIT_SECONDS}"
  local screen_snapshot
  screen_snapshot="$(mktemp)"

  hardcopy_screen "${screen_snapshot}" || true

  if grep -Eq 'received signal SIG|Program received signal' "${screen_snapshot}"; then
    rm -f "${screen_snapshot}"
    fail "cannot perform a clean shutdown because gdb is stopped on a crash in session ${SCREEN_SESSION}. Capture the crash first or recover the session before retrying."
  fi

  rm -f "${screen_snapshot}"

  if [[ "${shutdown_args}" =~ ^[0-9]+$ ]]; then
    shutdown_minutes="${shutdown_args}"
  fi

  shutdown_wait_seconds="$((shutdown_minutes * 60 + SHUTDOWN_WAIT_SECONDS))"

  log "Sending managed shutdown command to core3 via session ${SCREEN_SESSION}: shutdown ${shutdown_args}"
  send_to_gdb "shutdown ${shutdown_args}"

  if ! wait_for_shutdown_state "${shutdown_wait_seconds}"; then
    local state
    local pids
    state="$(gdb_state)"
    pids="$(raw_server_pids | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    fail "timed out waiting ${shutdown_wait_seconds}s for clean shutdown after sending 'shutdown ${shutdown_args}' (session=${SCREEN_SESSION}, gdb_state=${state}, core3_pids=${pids:-none}). Attach to inspect the server console/logs."
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

  if [[ "${AUTO_RECOVER_DB}" == "1" ]]; then
    log "Automatic Berkeley DB recovery enabled; running recovery before start"
    recover_db
  else
    log "Skipping automatic Berkeley DB recovery before start"
  fi

  configure_gdb_run_args

  log "Sending run to gdb session ${SCREEN_SESSION}"
  send_to_gdb 'run'

  if ! wait_for_run_state; then
    fail "gdb session did not enter running state within ${RUN_WAIT_SECONDS}s; attach to ${SCREEN_SESSION} to inspect the terminal"
  fi
}

status_server() {
  local state
  state="$(gdb_state)"

  printf 'session=%s\n' "${SCREEN_SESSION}"
  if session_exists; then
    printf 'session_exists=yes\n'
  else
    printf 'session_exists=no\n'
  fi
  printf 'gdb_state=%s\n' "${state}"

  local pids
  pids="$(raw_server_pids | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  if [[ -n "${pids}" ]]; then
    printf 'core3_pids=%s\n' "${pids}"
    local first_pid
    first_pid="$(printf '%s\n' "${pids}" | awk '{print $1}')"
    if [[ -n "${first_pid}" ]] && [[ -r "/proc/${first_pid}/cmdline" ]]; then
      local cmdline
      cmdline="$(tr '\0' ' ' <"/proc/${first_pid}/cmdline" | sed 's/[[:space:]]*$//')"
      printf 'core3_cmdline=%s\n' "${cmdline}"
    fi
  fi

  local zombie_pids
  zombie_pids="$(raw_server_zombie_pids | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  if [[ -n "${zombie_pids}" ]]; then
    printf 'core3_zombie_pids=%s\n' "${zombie_pids}"
  fi

  if [[ -f "${LATEST_CAPTURE_FILE}" ]]; then
    printf 'latest_capture=%s\n' "$(<"${LATEST_CAPTURE_FILE}")"
  fi

  printf 'run_args=%s\n' "${RUN_ARGUMENTS}"
}

attach_session() {
  ensure_session
  exec screen -r "${SCREEN_SESSION}"
}

stop_server() {
  local stop_shutdown_wait_seconds="${STOP_SHUTDOWN_WAIT_SECONDS}"

  if ! session_exists; then
    if raw_server_running; then
      stop_unmanaged_server TERM "unmanaged core3 pid(s) did not stop after SIGTERM; refusing to send SIGKILL because it can leave Berkeley DB requiring recovery. Stop it from the server console if possible, or use force-stop if you accept the risk."
    else
      log "stop requested but screen session ${SCREEN_SESSION} does not exist"
    fi
    rm -f "${GDB_STATE_FILE}"
    return 0
  fi

  local state
  state="$(gdb_state)"

  if raw_server_running || [[ "${state}" == "running" ]]; then
    if gdb_prompt_contains_crash; then
      log "stop requested while gdb is stopped on a crash; skipping managed shutdown and killing the inferior"
      kill_managed_inferior
    else
      log "stop requested while core3 is running; attempting managed shutdown before tearing down the session"
      send_to_gdb 'shutdown 0'

      if wait_for_shutdown_state "${stop_shutdown_wait_seconds}"; then
        log "Managed shutdown completed for ${SCREEN_SESSION}"
      else
        log "Managed shutdown timed out after ${stop_shutdown_wait_seconds}s; killing the managed inferior instead"
        kill_managed_inferior
      fi
    fi
  fi

  teardown_session

  if raw_server_running; then
    stop_unmanaged_server TERM "core3 pid(s) remained after stopping the managed session; use force-stop if you need SIGKILL"
  fi
}

force_stop_server() {
  if ! session_exists; then
    if raw_server_running; then
      local pid
      for pid in $(raw_server_pids); do
        log "Force-stopping unmanaged core3 pid=${pid} with SIGTERM"
        kill -TERM "${pid}" 2>/dev/null || true
        if ! wait_for_pid_exit "${pid}"; then
          log "Unmanaged core3 pid=${pid} did not stop after SIGTERM; sending SIGKILL"
          kill -KILL "${pid}" 2>/dev/null || true
        fi
      done
    else
      log "force-stop requested but screen session ${SCREEN_SESSION} does not exist"
    fi
    return 0
  fi

  local state
  state="$(gdb_state)"

  if [[ "${state}" == "running" ]]; then
    log "Force-stopping managed inferior in ${SCREEN_SESSION} via Ctrl-C"
    screen -S "${SCREEN_SESSION}" -p 0 -X stuff $'\003'
    sleep 2
  fi

  teardown_session

  if raw_server_running; then
    local pid
    for pid in $(raw_server_pids); do
      log "Force-stopping remaining core3 pid=${pid} with SIGTERM"
      kill -TERM "${pid}" 2>/dev/null || true
      if ! wait_for_pid_exit "${pid}"; then
        log "Remaining core3 pid=${pid} did not stop after SIGTERM; sending SIGKILL"
        kill -KILL "${pid}" 2>/dev/null || true
      fi
    done
  fi
}

recover_db() {
  local recover_tool
  recover_tool="$(db_recover_tool)"

  if raw_server_running; then
    local pids
    pids="$(raw_server_pids | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    fail "cannot run db_recover while core3 is running (pid(s): ${pids})"
  fi

  local state
  state="$(gdb_state)"
  if session_exists && [[ "${state}" == "running" ]]; then
    fail "cannot run db_recover while the managed gdb session is still running core3"
  fi

  local db_home="${BIN_DIR}/databases"
  [[ -d "${db_home}" ]] || fail "database home not found at ${db_home}"

  log "Running ${recover_tool} against ${db_home}"
  "${recover_tool}" -h "${db_home}" -v
  log "${recover_tool} completed for ${db_home}"
}

backup_sql_database() {
  local output_file="$1"
  local -a args=()

  if [[ "${SQL_BACKUP_ENABLED}" != "1" ]]; then
    return 0
  fi

  [[ -n "${SQL_USER}" ]] || fail "CORE3_SQL_USER is required when CORE3_SQL_BACKUP_ENABLED=1"
  [[ -n "${SQL_DATABASE}" ]] || fail "CORE3_SQL_DATABASE is required when CORE3_SQL_BACKUP_ENABLED=1"

  require_tool "${SQL_DUMP_TOOL}"

  args+=(-h "${SQL_HOST}" -P "${SQL_PORT}" -u "${SQL_USER}")

  if [[ -n "${SQL_PASSWORD}" ]]; then
    args+=("-p${SQL_PASSWORD}")
  fi

  args+=("${SQL_DATABASE}")

  "${SQL_DUMP_TOOL}" "${args[@]}" >"${output_file}"
  log "SQL backup completed: ${output_file}"
}

backup_database() {
  local hotbackup_tool
  hotbackup_tool="$(db_hotbackup_tool)"

  local db_home="${BIN_DIR}/databases"
  [[ -d "${db_home}" ]] || fail "database home not found at ${db_home}"

  local backup_dir
  local raw_db_dir
  local archive_path

  backup_dir="$(current_backup_dir)"
  raw_db_dir="${backup_dir}/databases"
  archive_path="${backup_dir}.zip"

  log "Running ${hotbackup_tool} against ${db_home} into ${raw_db_dir}"
  "${hotbackup_tool}" -h "${db_home}" -b "${raw_db_dir}"

  if [[ "${SQL_BACKUP_ENABLED}" == "1" ]]; then
    backup_sql_database "${backup_dir}/sql-backup.sql"
  fi

  {
    printf 'timestamp=%s\n' "$(date --iso-8601=seconds)"
    printf 'db_home=%s\n' "${db_home}"
    printf 'raw_server_running=%s\n' "$(raw_server_running && printf yes || printf no)"
    printf 'sql_backup_enabled=%s\n' "${SQL_BACKUP_ENABLED}"
  } >"${backup_dir}/metadata.txt"

  create_zip_archive "${backup_dir}" "${archive_path}"
  printf '%s\n' "${archive_path}" >"${LATEST_BACKUP_FILE}"
  log "Database backup archive created at ${archive_path}"

  transfer_artifact_if_configured "${archive_path}" "database backup"
  rotate_backup_archives "${BACKUP_KEEP_COUNT}"

  if [[ "${BACKUP_KEEP_RAW}" != "1" ]]; then
    rm -rf "${backup_dir}"
    log "Removed raw backup directory ${backup_dir}"
  fi

  printf '%s\n' "${archive_path}"
}

usage() {
  cat <<'EOF'
Usage: core3-control.sh [command]

Commands:
  run              Capture any current crash state, then send `run` to the gdb session.
  attach           Reattach to the persistent screen session running gdb ./core3.
  status           Show whether the screen session exists and whether gdb is running/stopped.
  capture-crash    Archive the current gdb/log state into a timestamped crash folder.
  backup-db        Create a Berkeley DB hot backup archive and optionally transfer it.
  shutdown         Send the in-server console command `shutdown` (default: `shutdown 0`) and wait for a clean save/exit.
  stop             Prefer a clean shutdown, then stop the screen session.
  force-stop       Interrupt or kill core3 immediately. This can leave Berkeley DB requiring recovery.
  recover-db       Run db_recover against bin/databases while core3 is stopped.

Optional crash email environment:
  CORE3_EMAIL_ENABLED=1
  CORE3_EMAIL_TO=you@example.com
  CORE3_EMAIL_FROM=core3@example.com
  CORE3_EMAIL_SMTP_HOST=smtp.example.com
  CORE3_EMAIL_SMTP_PORT=587
  CORE3_EMAIL_SMTP_USER=optional-user
  CORE3_EMAIL_SMTP_PASS=optional-password
  CORE3_EMAIL_SMTP_STARTTLS=1
  CORE3_EMAIL_SUBJECT_PREFIX=[core3-capture]

Optional backup / transfer environment:
  CORE3_BACKUP_ROOT=/path/to/backup
  CORE3_BACKUP_KEEP_RAW=0
  CORE3_BACKUP_KEEP_COUNT=5
  CORE3_TRANSFER_ENABLED=1
  CORE3_TRANSFER_DEST=ubuntu@testcenter.swg-starforge.com
  CORE3_TRANSFER_PATH=/home/ubuntu/backups
  CORE3_TRANSFER_PORT=22
  CORE3_TRANSFER_SSH_KEY=/path/to/key
  CORE3_TRANSFER_STRICT_HOST_KEY_CHECKING=1
  CORE3_TRANSFER_KNOWN_HOSTS=/path/to/known_hosts
  CORE3_SQL_BACKUP_ENABLED=0
  CORE3_SQL_DUMP_TOOL=mysqldump
  CORE3_SQL_HOST=localhost
  CORE3_SQL_PORT=3306
  CORE3_SQL_USER=your-user
  CORE3_SQL_PASSWORD=your-password
  CORE3_SQL_DATABASE=your-database
  CORE3_AUTO_RECOVER_DB=0
  CORE3_DB_RECOVER_TOOL=db_recover
  CORE3_DB_HOTBACKUP_TOOL=db_hotbackup
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
    backup-db)
      local backup_archive
      backup_archive="$(backup_database)"
      printf 'backup_archive=%s\n' "${backup_archive}"
      printf 'SUCCESS\n'
      ;;
    shutdown)
      shift || true
      shutdown_server "$@"
      status_server
      ;;
    stop)
      stop_server
      status_server
      ;;
    force-stop)
      force_stop_server
      status_server
      ;;
    recover-db)
      recover_db
      printf 'SUCCESS\n'
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
