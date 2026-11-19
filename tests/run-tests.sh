#!/usr/bin/env sh
#
# Test suite for bwgc_countryblock.
#
#   ./tests/run-tests.sh            build the image and run every case
#   ./tests/run-tests.sh idempot    run only cases matching "idempot"
#   BWGC_IMAGE=... ./tests/run-tests.sh
#
# These run inside the image with --cap-add NET_ADMIN. The container has its own
# network namespace, so the real iptables commands are exercised against real
# tables without any possibility of touching the host's firewall.
#
# The suite runs once per backend the kernel accepts (iptables-nft, then
# iptables-legacy). Kernels that no longer load legacy xtables on demand need
# "modprobe ip_tables iptable_filter" on the host for the legacy run; without
# it that run is skipped. TEST_BACKENDS="iptables-legacy" forces a list and
# fails if the kernel refuses one.
#
# bash, not sh: block.sh uses [[ ]], local -a and ${var,,}, so sourcing it from
# busybox sh fails at parse time.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FILTER="${1:-}"

if [ -n "${BWGC_IMAGE:-}" ]; then
	IMAGE="$BWGC_IMAGE"
	printf 'testing existing image: %s\n' "$IMAGE"
else
	IMAGE=bwgc_countryblock:test
	printf 'building %s\n' "$IMAGE"
	docker build -q -t "$IMAGE" "$ROOT" >/dev/null
fi

docker run --rm --cap-add NET_ADMIN \
	-e FILTER="$FILTER" \
	-e TEST_BACKENDS="${TEST_BACKENDS:-}" \
	-v "$ROOT/tests:/tests:ro" \
	-v "$ROOT/scripts/block.sh:/block.sh:ro" \
	--entrypoint bash "$IMAGE" /tests/in-container.sh
