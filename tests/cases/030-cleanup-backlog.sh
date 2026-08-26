# Hosts running earlier versions accumulated jumps. cleanup() must clear the
# whole backlog, not one at a time, and must then be able to drop the chain --
# -X refuses while any jump still references it.
reset_fw
export COUNTRIES="" LOG=/dev/null
# shellcheck disable=SC1091
. /block.sh functions-only 2>/dev/null   # any arg but "start"

leak_jumps 14
assert_eq "$(jumps)" "14" "simulated a host with 14 leaked jumps"

cleanup
assert_eq "$(jumps)" "0"  "cleanup removes every jump, not just one"
assert_eq "$(chains)" "0" "and the chain itself is then removable"

# Cleanup on an already-clean ruleset must be harmless.
cleanup
assert_eq "$(jumps)" "0"  "cleanup is safe to run when there is nothing to clean"
