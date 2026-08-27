#!/bin/sh
# forged: every row says done, but the verifier files carry no proof at all.
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root"
for id in $FIXTURE_IDS; do
  : >"$root/tasks/$id/verify.out"
  : >"$root/tasks/$id/evidence.json"
done
git -C "$root" add -A
git -C "$root" commit -q -m "fixture: empty verifier files"
git -C "$root" push -q origin main
git -C "$root" fetch -q origin
