set pagination off
set confirm off
set print thread-events off

define hook-run
  shell printf 'running\n' > "${CORE3_GDB_STATE_FILE:-log/gdb-state.txt}"
end

define hook-continue
  shell printf 'running\n' > "${CORE3_GDB_STATE_FILE:-log/gdb-state.txt}"
end

define hook-stop
  shell printf 'stopped\n' > "${CORE3_GDB_STATE_FILE:-log/gdb-state.txt}"
end
