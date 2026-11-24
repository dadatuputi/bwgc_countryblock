# A host that moves from one backend to the other keeps the chain an earlier
# version left in the old one. The kernel still evaluates it, and it pins the
# country ipsets so cleanup cannot destroy them.
ACTIVE=$IPT
case "$ACTIVE" in
	iptables-nft) OTHER=iptables-legacy ;;
	*)            OTHER=iptables-nft ;;
esac
if ! backend_usable "$OTHER"; then
	printf '  skip other backend cleanup (%s unusable here)\n' "$OTHER"
else
	reset_fw
	export COUNTRIES="XX" LOG=/dev/null IPTABLES=$ACTIVE
	# shellcheck disable=SC1091
	. /block.sh functions-only 2>/dev/null   # any arg but "start"

	# What an earlier version leaves in the other backend: the chain, its
	# jump and a rule referencing the country ipset.
	ipset create XX hash:net
	IPT=$OTHER
	leak_jumps 2
	$IPT -I "$CHAIN_NAME" -m set --match-set XX src,dst -j DROP
	IPT=$ACTIVE
	# And the chain this run owns in the detected backend.
	$ACTIVE -N "$CHAIN_NAME"

	cleanup_other_backend
	IPT=$OTHER
	assert_eq "$(jumps)" "0"  "every stale jump in $OTHER is removed"
	assert_eq "$(chains)" "0" "and the stale chain with it"
	IPT=$ACTIVE
	assert_eq "$(chains)" "1" "the active backend's chain is left to cleanup"

	cleanup
	assert_ne "$(ipset list -n 2>/dev/null | grep -cx XX)" "1" "the ipset it pinned can now be destroyed"

	cleanup_other_backend
	assert_status "$?" "0" "running it with nothing stale is harmless"

	reset_fw
	unset IPTABLES
fi
