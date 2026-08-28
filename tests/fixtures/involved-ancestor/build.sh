#!/bin/sh
# involved-ancestor: historical integrated_sha remains an ancestor of the
# later integration head -> status: DONE.
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root"
make_historical_involved "$root" M1-03
