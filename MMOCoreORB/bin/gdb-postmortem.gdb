set pagination off
set print thread-events off
set confirm off

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

echo \n=== BINARY / CORE INFO ===\n
info files
