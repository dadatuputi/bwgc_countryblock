# The real entry point, not the functions in isolation: a container starting up
# on a host with a backlog must converge on exactly one jump unattended.
reset_fw
leak_jumps 6
assert_eq "$(jumps)" "6" "host starts with a backlog"

COUNTRIES="" LOG=/dev/null timeout 10 bash /block.sh start >/dev/null 2>&1 &
BG=$!
sleep 3
assert_eq "$(jumps)" "1" "start converges on exactly one jump with no manual step"
kill "$BG" 2>/dev/null || true
wait 2>/dev/null || true
