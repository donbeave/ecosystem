#!/bin/sh
# CANARY-01 verification. Written by tools/canary.sh.
#
# Takes one argument, container or host, and runs only that part. Prints
# status: DONE as its last line on success and status: PENDING otherwise.
# Paths are resolved from the script itself, so the check is the same in an
# isolated worktree, at the pull-request head, and on the integration branch.
set -u

role="${1:-host}"
if [ "$role" = "container" ]; then
  echo "no container part"
  echo "status: DONE"
  exit 0
fi

unset CDPATH
dir=$(cd -- "$(dirname -- "$0")" && pwd)
file="$dir/canary.txt"
want="canary CANARY-01 readiness-2026-08-28"

if [ ! -f "$file" ]; then
  echo "missing: $file"
  echo "status: PENDING"
  exit 1
fi

got=$(cat "$file")
if [ "$got" != "$want" ]; then
  echo "content differs: expected \"$want\", found \"$got\""
  echo "status: PENDING"
  exit 1
fi

echo "canary file present with the expected content"
echo "status: DONE"
