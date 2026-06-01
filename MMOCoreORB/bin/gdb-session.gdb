set pagination off
set confirm off
set print thread-events off
source ../gdb-crash.gdb

define hook-run
  shell printf 'running\n' > log/gdb-state.txt
end

define hook-continue
  shell printf 'running\n' > log/gdb-state.txt
end

define hook-stop
  shell printf 'stopped\n' > log/gdb-state.txt
end
