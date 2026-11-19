#!/usr/bin/env sh
# Minimal assertions, POSIX sh, no dependencies. Runs inside the image.

TESTS_RUN=0
TESTS_FAILED=0

pass() { TESTS_RUN=$((TESTS_RUN+1)); printf '  ok   %s\n' "$1"; }
fail() {
	TESTS_RUN=$((TESTS_RUN+1)); TESTS_FAILED=$((TESTS_FAILED+1))
	printf '  FAIL %s\n' "$1"
	[ -n "${2:-}" ] && printf '       %s\n' "$2"
	return 0
}
assert_eq() { [ "$1" = "$2" ] && pass "$3" || fail "$3" "expected '$2', got '$1'"; }
assert_ne() { [ "$1" != "$2" ] && pass "$3" || fail "$3" "expected something other than '$2'"; }
assert_file()    { [ -f "$1" ] && pass "$2" || fail "$2" "missing file: $1"; }
assert_no_file() { [ ! -e "$1" ] && pass "$2" || fail "$2" "file should not exist: $1"; }
assert_status()  { [ "$1" -eq "$2" ] && pass "$3" || fail "$3" "expected exit $2, got $1"; }
assert_contains() {
	printf '%s' "$1" | grep -qF -- "$2" && pass "$3" || fail "$3" "expected to find: $2"
}
assert_not_contains() {
	printf '%s' "$1" | grep -qF -- "$2" && fail "$3" "did not expect: $2" || pass "$3"
}

# Firewall helpers. Every case starts from an empty ruleset; the container has
# its own network namespace, so this cannot touch the host.
#
# IPT is the backend under test, set by in-container.sh, which runs the suite
# once per backend the kernel accepts.
IPT=${IPT:-iptables-nft}

# A backend is usable when the kernel lets it list the filter table. Kernels
# without legacy xtables (Ubuntu 26.04 GitHub runners) refuse iptables-legacy.
backend_usable() {
  command -v "$1" >/dev/null 2>&1 && "$1" -S >/dev/null 2>&1
}

jumps()  { $IPT -S INPUT 2>/dev/null | grep -c "j $CHAIN_NAME"; }
chains() { $IPT -S 2>/dev/null | grep -c "^-N $CHAIN_NAME"; }

reset_fw() {
  for _b in iptables-nft iptables-legacy; do
    backend_usable "$_b" || continue
    $_b -F 2>/dev/null || true
    $_b -X 2>/dev/null || true
  done
  ipset destroy 2>/dev/null || true
}

# Leave the mess an older version would leave behind: N jumps and a chain that
# -X could not remove because it was still referenced.
leak_jumps() {
  $IPT -N "$CHAIN_NAME" 2>/dev/null || true
  _i=0
  while [ "$_i" -lt "$1" ]; do
    $IPT -I INPUT 1 -j "$CHAIN_NAME"
    _i=$((_i + 1))
  done
}
