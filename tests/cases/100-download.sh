# A failed download must not replace the last good zone file, and whatever the
# download does the ipset must still be filled from a valid file. curl is
# stubbed: the suite runs without network access.
reset_fw
export COUNTRIES="XX" LOG=/dev/null
# shellcheck disable=SC1091
. /block.sh functions-only 2>/dev/null   # any arg but "start"

ZONE=/tmp/xx-aggregated.zone
curl_out() { while [ $# -gt 0 ]; do [ "$1" = "-o" ] && printf '%s' "$2"; shift; done; }
members() { ipset list XX 2>/dev/null | sed -n '/^Members:/,$p' | tail -n +2 | sort | tr '\n' ' '; }
ipset create XX hash:net

# First download: no cached file yet.
curl() { printf '1.2.3.0/24\n' > "$(curl_out "$@")"; }
rm -f "$ZONE"
update
assert_eq "$(cat "$ZONE")" "1.2.3.0/24" "a successful download becomes the zone file"
assert_eq "$(members)" "1.2.3.0/24 " "and fills the ipset"

# The server is unreachable or answers with an error.
curl() { printf 'garbage\n' > "$(curl_out "$@")"; return 22; }
update
assert_eq "$(cat "$ZONE")" "1.2.3.0/24" "a failed download keeps the previous zone file"
assert_no_file "$ZONE.part" "and leaves no partial file behind"

# 304 Not Modified: curl succeeds and writes nothing.
curl() { :; }
ipset flush XX
update
assert_eq "$(cat "$ZONE")" "1.2.3.0/24" "an unchanged zone file is kept"
assert_eq "$(members)" "1.2.3.0/24 " "and the ipset is still filled from it"

# -z needs an existing file, so it is only passed once there is one.
curl() { CURL_ARGS="$*"; }
update
assert_contains "$CURL_ARGS" "-z $ZONE" "-z is passed when a zone file exists"
rm -f "$ZONE"
update
assert_not_contains "$CURL_ARGS" "-z" "and not when there is none"

unset -f curl
rm -f "$ZONE"
ipset destroy XX
