define _crashdump_common
  set logging overwrite on
  set logging redirect on
  set logging on

  echo === CURRENT THREAD ===\n
  bt 20
  frame 0
  x/i $pc
  info registers rip rsp rbp rdi rsi
  x/16gx $rsp

  echo \n=== THREADS ===\n
  info threads

  echo \n=== ALL THREAD BACKTRACES ===\n
  thread apply all bt 12

  set logging off
end

define crashdump
  set pagination off
  set logging file gdb-crash.txt
  _crashdump_common
  echo \nWrote gdb-crash.txt\n
end

define crashdump_to
  set pagination off
  set logging file $arg0
  _crashdump_common
  echo \nWrote crash dump to $arg0\n
end

document crashdump
Write a compact crash report to gdb-crash.txt for the current gdb session.
end

document crashdump_to
Write a compact crash report to the specified path for the current gdb session.
end
