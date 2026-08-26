# SIGKILL cannot be trapped. Listing it implied a hard kill would clean up, and
# that assumption is why leaked jumps were never noticed.
SRC=$(cat /block.sh)
# Scope this to the trap line itself. The file mentions SIGKILL in a comment
# explaining why it was removed, and that comment is worth keeping.
TRAP_LINE=$(grep -E '^\s*trap ' /block.sh || true)
assert_not_contains "$TRAP_LINE" "SIGKILL"  "SIGKILL is not listed in the trap"
assert_contains "$SRC" "SIGINT SIGTERM EXIT" "the trap covers the signals that can be caught, plus EXIT"

# Idempotency is what actually protects against an untrappable kill, so both
# halves must be guarded rather than relying on the trap firing.
assert_contains "$SRC" '$IPTABLES -C INPUT $JUMP_SPEC' "setup checks before inserting"
assert_contains "$SRC" 'while $IPTABLES -C INPUT $JUMP_SPEC' "cleanup loops until none remain"
