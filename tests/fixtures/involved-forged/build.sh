#!/bin/sh
# involved-forged: same shape, but evidence.json names a different SHA than
# the `integrated_sha:` line of verify.out -> status: FAILED SYSTEM
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root"
make_involved "$root" M1-03 0000000000000000000000000000000000000000
