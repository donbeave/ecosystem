#!/bin/sh
# Roadmap-level gate for the /goal run (D-069). Read-only.
#
# Passes only when every task id listed in the ROADMAP.md task tables has a
# row in tasks/README.md whose Status is `done` and a `tasks/<id>/verify.sh`
# file exists. Last line is the verdict: `status: DONE` or
# `status: PENDING <n> remaining`. Exit code mirrors it (0 / 1).
set -u
cd "$(dirname "$0")" || exit 2

ROADMAP=ROADMAP.md
INDEX=tasks/README.md
[ -f "$ROADMAP" ] || { echo "missing $ROADMAP"; echo "status: PENDING unknown remaining"; exit 2; }
[ -f "$INDEX" ] || { echo "missing $INDEX"; echo "status: PENDING unknown remaining"; exit 2; }

# Task ids: first cell of every task-table row in ROADMAP.md (M1-01, M1-02a, ...).
expected=$(awk -F'|' '/^\| *M[0-9]+-[0-9]+[a-z]? *\|/ { gsub(/ /, "", $2); print $2 }' "$ROADMAP" | sort -u)
total=$(printf '%s\n' "$expected" | grep -c .)

# tasks/README.md: locate the Task and Status columns by header name so extra
# columns (for example a Linear URL) never break the parse.
index_status() {
  awk -F'|' -v want="$1" '
    /^\|/ && !hdr {
      for (i = 2; i < NF; i++) {
        h = tolower($i); gsub(/^ +| +$/, "", h)
        if (h == "task") tc = i
        if (h == "status") sc = i
      }
      hdr = 1; next
    }
    hdr && tc && sc {
      cell = $tc
      if (match(cell, /M[0-9]+-[0-9]+[a-z]?/)) {
        id = substr(cell, RSTART, RLENGTH)
        if (id == want) { s = $sc; gsub(/^ +| +$/, "", s); gsub(/`/, "", s); print tolower(s); exit }
      }
    }' "$INDEX"
}

remaining=0
for id in $expected; do
  status=$(index_status "$id")
  problem=""
  if [ -z "$status" ]; then
    problem="no row in $INDEX"
  elif [ "$status" != "done" ]; then
    problem="status $status"
  fi
  if [ ! -f "tasks/$id/verify.sh" ]; then
    problem="${problem:+$problem; }tasks/$id/verify.sh missing"
  fi
  if [ -n "$problem" ]; then
    remaining=$((remaining + 1))
    echo "$id: $problem"
  fi
done

echo "tasks: $total expected, $((total - remaining)) done"
if [ "$remaining" -eq 0 ] && [ "$total" -gt 0 ]; then
  echo "status: DONE"
  exit 0
fi
echo "status: PENDING $remaining remaining"
exit 1
