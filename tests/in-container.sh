#!/usr/bin/env bash
set -u
CHAIN_NAME=countryblock
. /tests/lib-assert.sh

printf '\nbwgc_countryblock tests\n\n'
for case_file in /tests/cases/*.sh; do
	name=$(basename "$case_file" .sh)
	if [ -n "${FILTER:-}" ]; then
		case "$name" in *"$FILTER"*) ;; *) continue ;; esac
	fi
	printf '%s\n' "$name"
	# shellcheck disable=SC1090
	. "$case_file"
	printf '\n'
done
printf 'ran %d assertions, %d failed\n\n' "$TESTS_RUN" "$TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ] || exit 1
