#!/bin/sh
# Adversarial gate fixtures for the root verify.sh (D-069, D-110).
#
# Builds each fixture under tests/fixtures/ into a throwaway repository, runs
# the oracle against it, and compares the last line to the class that fixture
# is built to produce. Exits 0 only when the good fixture yields
# `status: DONE` and every known-bad fixture yields its expected non-DONE
# class, which is what makes a passing run evidence that the gate cannot be
# satisfied by claims alone.
#
# Usage: sh tools/gate_fixtures.sh [--keep] [fixture ...]
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
KEEP=0
WANTED=""
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) WANTED="$WANTED $1"; shift ;;
  esac
done

# fixture:expected terminal class
CASES="good:DONE
forged:FAILED SYSTEM
stale:FAILED SYSTEM
dirty:FAILED SYSTEM
unpushed:FAILED SYSTEM
runnable:PENDING
active:PENDING
blocked-human:BLOCKED HUMAN"

WORK="$(mktemp -d)" || exit 2
[ "$KEEP" -eq 1 ] || trap 'rm -rf "$WORK"' EXIT INT TERM

fails=0
total=0
printf '%s\n' "$CASES" | while IFS=: read -r name want; do
  [ -n "$name" ] || continue
  case " $WANTED " in
    "  ") ;;
    *" $name "*) ;;
    *) continue ;;
  esac
  builder="$REPO/tests/fixtures/$name/build.sh"
  if [ ! -f "$builder" ]; then
    echo "$name: MISSING $builder"
    echo x >>"$WORK/.failed"
    continue
  fi
  root="$WORK/$name"
  if ! sh "$builder" "$root" >"$WORK/$name.build.log" 2>&1; then
    echo "$name: BUILD FAILED — $(tail -n 1 "$WORK/$name.build.log")"
    echo x >>"$WORK/.failed"
    continue
  fi
  sh "$REPO/verify.sh" --root "$root" --expect 3 >"$WORK/$name.out" 2>&1
  got="$(tail -n 1 "$WORK/$name.out")"
  if [ "$got" = "status: $want" ]; then
    echo "$name: ok — $got"
  else
    echo "$name: FAIL — expected \`status: $want\`, got \`$got\`"
    echo x >>"$WORK/.failed"
  fi
  if [ "$name" != "good" ] && [ "$got" = "status: DONE" ]; then
    echo "$name: FAIL — a known-bad fixture was accepted as DONE"
    echo x >>"$WORK/.failed"
  fi
done

total=$(printf '%s\n' "$CASES" | grep -c .)
[ -f "$WORK/.failed" ] && fails=$(grep -c x "$WORK/.failed")
[ "$KEEP" -eq 1 ] && echo "fixtures kept under $WORK"

echo "fixtures: $total defined, $fails failure(s)"
if [ "$fails" -eq 0 ]; then
  echo "status: DONE"
  exit 0
fi
echo "status: FAILED SYSTEM"
exit 1
