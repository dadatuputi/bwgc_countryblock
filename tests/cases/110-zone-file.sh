# process_zone_file feeds every valid line to one "ipset restore". Anything
# else in the file must be skipped rather than reach ipset or abort the batch.
reset_fw
export COUNTRIES="" LOG=/dev/null
# shellcheck disable=SC1091
. /block.sh functions-only 2>/dev/null   # any arg but "start"

ZONE=/tmp/test.zone
members() { ipset list XX 2>/dev/null | sed -n '/^Members:/,$p' | tail -n +2 | sort | tr '\n' ' '; }
ipset create XX hash:net

printf '%s\n' \
	'# comment' \
	'' \
	'1.2.3.0/24' \
	'  5.6.0.0/16  ' \
	'9.9.9.0/24\r' \
	'256.1.1.0/24' \
	'add XX 0.0.0.0/1' \
	'1.2.3.0/24' > "$ZONE"
printf '10.0.0.0/8' >> "$ZONE"   # no trailing newline
sed -i 's/\\r$/\r/' "$ZONE"

process_zone_file "$ZONE" XX
assert_status "$?" "0" "a file mixing valid and invalid lines is accepted"
assert_eq "$(members)" "1.2.3.0/24 10.0.0.0/8 5.6.0.0/16 9.9.9.0/24 " \
	"exactly the valid subnets are added, whitespace, CR and missing newline included"

process_zone_file "$ZONE" XX
assert_status "$?" "0" "adding subnets already in the set is not an error"

process_zone_file "$ZONE" YY
assert_ne "$?" "0" "a failing ipset restore is reported"

printf '1.2.3.0/24\n' > "$ZONE"
process_zone_file "$ZONE" XX
assert_eq "$(members)" "1.2.3.0/24 " "a range dropped from the zone file leaves the set"

printf '1.2.3.0/24\n7.7.7.0/24\n' > "$ZONE"
process_zone_file "$ZONE" XX
ipset() { if [ "$1" = restore ]; then command ipset restore "${@:2}" >/dev/null 2>&1; return 1; fi; command ipset "$@"; }
printf '8.8.8.0/24\n' > "$ZONE"
process_zone_file "$ZONE" XX
assert_ne "$?" "0" "a refused file is reported"
unset -f ipset
assert_eq "$(members)" "1.2.3.0/24 7.7.7.0/24 " "and the set keeps its previous ranges"
ipset list XX-new >/dev/null 2>&1 && fail "no staging set is left behind" || pass "no staging set is left behind"

rm -f "$ZONE"
ipset destroy XX
