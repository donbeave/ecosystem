#!/bin/sh
# Exact-name container liveness stub.
set -eu
[ "${1:-}" = "ps" ] || exit 2
[ -z "${FAKE_DOCKER_NAMES:-}" ] || printf '%s\n' "$FAKE_DOCKER_NAMES"
