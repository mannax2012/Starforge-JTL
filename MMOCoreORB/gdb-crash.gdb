define crashdump
  set pagination off
  set logging file gdb-crash.txt
  set logging overwrite on
  set logging redirect on
  set logging enabled on

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

  set logging enabled off
  echo \nWrote gdb-crash.txt\n
end

document crashdump
Write a compact crash report to gdb-crash.txt for the current gdb session.
end
