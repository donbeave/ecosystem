#!/bin/sh
# blocked-human: one task is blocked on an operator input and nothing else is
# runnable or active -> status: BLOCKED HUMAN
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root" blocked
cat >>"$root/PREFLIGHT-DEFECTS.md" <<'ROW'
| 1 | M1-03 | Fixture credential created in a vendor UI (human-only) | `test -n "$FIXTURE_CREDENTIAL"` | 2026-08-28 | |
ROW
git -C "$root" add -A
git -C "$root" commit -q -m "fixture: open operator defect"
git -C "$root" push -q origin main
git -C "$root" fetch -q origin
