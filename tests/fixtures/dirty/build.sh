#!/bin/sh
# dirty: an uncommitted file in the working tree.
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root"
echo "uncommitted" >"$root/scratch.txt"
