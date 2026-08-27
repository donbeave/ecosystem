#!/bin/sh
# runnable: one task is still ready, so work remains -> status: PENDING
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root" ready
