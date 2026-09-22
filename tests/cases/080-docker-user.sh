# Traffic to a container's published port goes through FORWARD, not INPUT, so
# without a jump from DOCKER-USER it is never filtered.
reset_fw
export COUNTRIES="" LOG=/dev/null IPTABLES=$IPT
# shellcheck disable=SC1091
. /block.sh functions-only 2>/dev/null   # any arg but "start"

docker_user_jumps() { $IPT -S DOCKER-USER 2>/dev/null | grep -c "j $CHAIN_NAME"; }

# A host without Docker rules in this backend has no DOCKER-USER chain.
setup
assert_eq "$(jumps)" "1" "setup succeeds without a DOCKER-USER chain"
cleanup

# Docker creates DOCKER-USER; plant it the way the daemon would.
$IPT -N DOCKER-USER
setup
assert_eq "$(docker_user_jumps)" "1" "setup jumps from DOCKER-USER when it exists"
assert_eq "$($IPT -S DOCKER-USER | sed -n 2p)" "-A DOCKER-USER -j $CHAIN_NAME" "and the jump comes first"

setup; setup
assert_eq "$(docker_user_jumps)" "1" "further setups still leave exactly one DOCKER-USER jump"

$IPT -I DOCKER-USER 1 -j "$CHAIN_NAME"
cleanup
assert_eq "$(docker_user_jumps)" "0" "cleanup removes every DOCKER-USER jump"
assert_eq "$(chains)" "0"            "and the chain itself is then removable"
assert_eq "$($IPT -S DOCKER-USER >/dev/null 2>&1; echo $?)" "0" "DOCKER-USER itself belongs to Docker and is left in place"
unset IPTABLES
