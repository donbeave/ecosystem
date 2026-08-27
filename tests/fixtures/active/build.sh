#!/bin/sh
# active: one task is in-progress -> status: PENDING
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root" in-progress
