# validate_ip_range guards what reaches ipset. Malformed input should be
# rejected rather than passed through to the firewall.
export COUNTRIES="" LOG=/dev/null
# shellcheck disable=SC1091
. /block.sh functions-only 2>/dev/null   # any arg but "start"

for good in "1.2.3.0/24" "10.0.0.0/8" "255.255.255.255/32" "0.0.0.0/0"; do
	validate_ip_range "$good" && pass "accepts $good" || fail "accepts $good"
done
for bad in "1.2.3.0/33" "256.1.1.1/24" "1.2.3/24" "not-an-ip" "1.2.3.4" "" "1.2.3.4/-1"; do
	validate_ip_range "$bad" 2>/dev/null && fail "rejects '${bad:-<empty>}'" || pass "rejects '${bad:-<empty>}'"
done
