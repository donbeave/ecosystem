#!/bin/sh
# involved-divergent: evidence and verify.out agree on a commit that exists,
# but it is not the exact integration-target head -> status: FAILED SYSTEM
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root"
make_divergent_involved "$root" M1-03
