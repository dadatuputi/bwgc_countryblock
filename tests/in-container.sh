#!/usr/bin/env bash
set -u
CHAIN_NAME=countryblock
. /tests/lib-assert.sh

# Run the whole suite against every backend the kernel accepts. Hosts use
# either, and a runner may lack legacy xtables entirely. Set TEST_BACKENDS to
# force a list; a forced backend the kernel refuses fails the run.
BACKENDS=${TEST_BACKENDS:-}
if [ -z "$BACKENDS" ]; then
	for b in iptables-nft iptables-legacy; do
		if backend_usable "$b"; then
			BACKENDS="$BACKENDS $b"
		else
			printf 'skip %s: not supported by this kernel\n' "$b"
		fi
	done
fi
if [ -z "${BACKENDS// /}" ]; then
	printf 'no usable iptables backend\n'
	exit 1
fi

printf '\nbwgc_countryblock tests\n'
for IPT in $BACKENDS; do
	printf '\n== %s ==\n\n' "$IPT"
	if ! backend_usable "$IPT"; then
		fail "$IPT is usable" "the kernel refuses it"
		continue
	fi
	for case_file in /tests/cases/*.sh; do
		name=$(basename "$case_file" .sh)
		if [ -n "${FILTER:-}" ]; then
			case "$name" in *"$FILTER"*) ;; *) continue ;; esac
		fi
		printf '%s\n' "$name"
		# block.sh detects the backend by itself; pin it to the one under test.
		# Cases that exercise detection unset this.
		export IPTABLES="$IPT"
		# shellcheck disable=SC1090
		. "$case_file"
		printf '\n'
	done
done
printf 'ran %d assertions, %d failed\n\n' "$TESTS_RUN" "$TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ] || exit 1
