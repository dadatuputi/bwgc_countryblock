# The bug that caused 14 leaked jumps on a production host: -D was given both a
# rule number and a rule spec, which iptables rejects outright. These assertions
# pin the two forms apart so it cannot regress.
reset_fw
$IPT -N "$CHAIN_NAME" 2>/dev/null || true
$IPT -I INPUT 1 -j "$CHAIN_NAME"

OUT=$($IPT -D INPUT 1 -j "$CHAIN_NAME" 2>&1); STATUS=$?
assert_ne "$STATUS" "0"                     "-D with both a position and a spec is rejected by iptables"
assert_contains "$OUT" "Illegal option"     "iptables says why"
assert_eq "$(jumps)" "1"                    "the rejected delete removed nothing"

$IPT -D INPUT -j "$CHAIN_NAME"
assert_eq "$(jumps)" "0"                    "-D with a spec alone does remove it"

# The script must never combine them again.
SRC=$(cat /block.sh)
assert_not_contains "$SRC" 'FORWARD_RULE'   "the ambiguous shared variable is gone"
assert_contains "$SRC" 'JUMP_SPEC="-j $CHAIN"' "the jump is stored as a spec with no position"
