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
	-v "$ROOT/tests:/tests:ro" \
	-v "$ROOT/scripts/block.sh:/block.sh:ro" \
	--entrypoint bash "$IMAGE" /tests/in-container.sh
