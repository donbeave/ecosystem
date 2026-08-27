#!/bin/sh
# good: every task done, evidence fresh and pushed, tree clean -> status: DONE
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root"
