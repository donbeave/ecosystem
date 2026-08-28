#!/bin/sh
# involved: the last task touches an involved repository, so its evidence
# matches the `integrated_sha:` line rather than the ecosystem `commit:`
# line (D-112) -> status: DONE
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root"
make_involved "$root" M1-03
