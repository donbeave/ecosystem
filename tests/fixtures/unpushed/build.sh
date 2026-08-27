#!/bin/sh
# unpushed: HEAD is one commit ahead of the pushed remote head.
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root"
echo "local only" >"$root/notes.md"
git -C "$root" add -A
git -C "$root" commit -q -m "fixture: local commit that was never pushed"
