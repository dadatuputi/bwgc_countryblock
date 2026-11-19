# Rules written to the wrong backend are accepted but never consulted, so a
# misdetection blocks nothing while appearing configured. Ref #6.
reset_fw
export COUNTRIES="" LOG=/dev/null
unset IPTABLES
# shellcheck disable=SC1091
. /block.sh functions-only 2>/dev/null   # any arg but "start"

# An explicit override always wins, so an operator can force either backend.
IPTABLES=iptables-nft
assert_eq "$(detect_iptables)" "iptables-nft" "an explicit IPTABLES override is honoured"
IPTABLES=iptables-legacy
assert_eq "$(detect_iptables)" "iptables-legacy" "override works for legacy too"

# With no override, the backend holding Docker's chains is chosen. This
# container has none in either, so detection falls back to the first backend
# the kernel accepts, nft first. Legacy would fail outright on kernels built
# without it.
unset IPTABLES
DETECTED=$(detect_iptables)
if backend_usable iptables-nft; then
	assert_eq "$DETECTED" "iptables-nft" "falls back to nft when neither shows Docker chains"
else
	assert_eq "$DETECTED" "iptables-legacy" "falls back to legacy when the kernel refuses nft"
fi

# Plant a DOCKER chain in the nft backend and confirm detection follows it.
if backend_usable iptables-nft; then
	iptables-nft -N DOCKER 2>/dev/null || true
	unset IPTABLES
	assert_eq "$(detect_iptables)" "iptables-nft" "detects nft when Docker's chains live there"
	iptables-nft -X DOCKER 2>/dev/null || true
else
	printf '  skip nft detection (iptables-nft unusable here)\n'
fi

# And legacy when they live there instead.
if backend_usable iptables-legacy; then
	iptables-legacy -N DOCKER 2>/dev/null || true
	unset IPTABLES
	assert_eq "$(detect_iptables)" "iptables-legacy" "detects legacy when Docker's chains live there"
	iptables-legacy -X DOCKER 2>/dev/null || true
else
	printf '  skip legacy detection (kernel has no legacy xtables)\n'
fi

# The chosen backend is logged, so a misdetection is visible.
assert_contains "$(cat /block.sh)" "Using iptables backend" "the chosen backend is logged"
