# setup() runs on every container start. It must not add a second jump.
reset_fw
export COUNTRIES="" LOG=/dev/null
# shellcheck disable=SC1091
. /block.sh functions-only 2>/dev/null   # any arg but "start"

setup
assert_eq "$(jumps)" "1"  "first setup inserts the jump"
assert_eq "$(chains)" "1" "first setup creates the chain"

setup; setup; setup
assert_eq "$(jumps)" "1"  "three further setups still leave exactly one jump"
assert_eq "$(chains)" "1" "and exactly one chain"
assert_eq "$($IPT -S "$CHAIN_NAME" | grep -c 'j RETURN')" "1" "and exactly one RETURN rule"
