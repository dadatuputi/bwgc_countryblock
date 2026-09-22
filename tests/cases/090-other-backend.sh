# A host that moves from one backend to the other keeps the chain an earlier
# version left in the old one. The kernel still evaluates it, and it pins the
# country ipsets so cleanup cannot destroy them.
if ! command -v iptables-nft >/dev/null 2>&1; then
	printf '  skip other backend cleanup (iptables-nft not in image)\n'
else
	reset_fw
	export COUNTRIES="XX" LOG=/dev/null IPTABLES=iptables-nft
	# shellcheck disable=SC1091
	. /block.sh functions-only 2>/dev/null   # any arg but "start"

	# What an earlier version leaves in legacy: the chain, its jump and a
	# rule referencing the country ipset.
	ipset create XX hash:net
	leak_jumps 2
	$IPT -I "$CHAIN_NAME" -m set --match-set XX src,dst -j DROP
	# And the chain this run owns in the detected backend.
	iptables-nft -N "$CHAIN_NAME"

	cleanup_other_backend
	assert_eq "$(jumps)" "0"  "every legacy jump is removed"
	assert_eq "$(chains)" "0" "and the legacy chain with it"
	assert_eq "$(iptables-nft -S 2>/dev/null | grep -c "^-N $CHAIN_NAME")" "1" "the active backend's chain is left to cleanup"

	cleanup
	assert_ne "$(ipset list -n 2>/dev/null | grep -cx XX)" "1" "the ipset it pinned can now be destroyed"

	cleanup_other_backend
	assert_status "$?" "0" "running it with nothing stale is harmless"

	iptables-nft -F 2>/dev/null; iptables-nft -X 2>/dev/null
	unset IPTABLES
fi
