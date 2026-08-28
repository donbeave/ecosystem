#!/bin/sh
# multi-involved-divergent: first repository is exact, second names an existing
# divergent commit -> status: FAILED SYSTEM
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root"
make_multi_involved "$root" M1-03 1
