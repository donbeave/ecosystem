#!/bin/sh
# stale: the bundle changed after the evidence was recorded, so the recorded
# bundle_hash no longer matches the bundle it claims to prove.
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root"
printf '\nAmended after the verification ran.\n' >>"$root/tasks/M1-02/TASK.md"
git -C "$root" add -A
git -C "$root" commit -q -m "fixture: bundle changed after verification"
git -C "$root" push -q origin main
git -C "$root" fetch -q origin
