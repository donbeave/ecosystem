#!/bin/sh
# multi-involved: both repository records match their exact integration heads
# -> status: DONE
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root"
make_multi_involved "$root" M1-03
