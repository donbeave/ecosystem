#!/bin/sh
# Acceptance test for the M1 exit audit gate (D-123, R3 close-out).
#
# "No M2+ row is promoted to `ready` until `tasks/M1-12/audit.md` ends with
#  `audit: PASS`" — proven on a temporary store (`ECOSYSTEM_STORE`) so the run
# of record is never touched. Three properties are checked:
#
#   1. `arm` promotes the M1 bootstrap task even with no audit file.
#   2. `transition <last M1 id> done` does not promote its M2+ dependents while
#      the audit file is missing, and does not promote them when the file
#      exists but does not end with `audit: PASS`.
#   3. Once the file ends with `audit: PASS`, the next `done` transition
#      promotes them.
#
# The four D-088 early-start ids (M3-01, M3-03, M4-02, M4-03) are exempt from
# waiting for the M1-12 row, not from the audit: M4-02 is in the fixture to
# prove it stays `planned` too.
#
#   sh tests/state/test_m1_audit_gate.sh
#
# Last line is `status: DONE` on success.

set -eu

SRC="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/state-audit-test.XXXXXX")"
export ECOSYSTEM_STORE="$WORK/store"
AUDIT="$ECOSYSTEM_STORE/M1-12-audit.md"
STATE="$SRC/tools/state.py"

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT INT TERM

mkdir -p "$ECOSYSTEM_STORE"

fail() {
	printf '%s\n' "$1"
	printf 'status: FAIL\n'
	exit 1
}

# A four-task DAG in the shape `tools/roadmap_compile.py --json` prints:
# M1-01 -> M1-12 -> {M2-01, M4-02}.
cat >"$WORK/dag.json" <<'JSON'
{"ids": ["M1-01", "M1-12", "M2-01", "M4-02"],
 "edges": [["M1-12", "M1-01"], ["M2-01", "M1-12"], ["M4-02", "M1-12"]],
 "waves": {}}
JSON

# Print one task's status from the rendered projection.
row_status() {
	awk -F'|' -v id="$1" '$2 ~ "^ "id" $" {gsub(/ /, "", $5); print $5}' \
		"$ECOSYSTEM_STORE/tasks-README.md"
}

python3 "$STATE" init --dag "$WORK/dag.json" --run-id audit-gate-test >/dev/null

printf '== 1. arm promotes the M1 bootstrap with no audit file present\n'
[ ! -e "$AUDIT" ] || fail "the fixture store already has an audit file"
python3 "$STATE" arm >/dev/null
[ "$(row_status M1-01)" = "ready" ] || fail "arm did not promote M1-01"
printf 'M1-01 ready\n'

printf '== 2. M1 promotion is not gated: M1-01 done promotes M1-12\n'
python3 "$STATE" transition M1-01 "done" --result seeded >/dev/null
[ "$(row_status M1-12)" = "ready" ] || fail "M1-12 was not promoted"
printf 'M1-12 ready\n'

printf '== 3. no audit file: M1-12 done promotes no M2+ row\n'
python3 "$STATE" transition M1-12 "done" --result seeded >/dev/null
[ "$(row_status M2-01)" = "planned" ] ||
	fail "M2-01 was promoted with no audit file (D-123)"
[ "$(row_status M4-02)" = "planned" ] ||
	fail "early-start M4-02 was promoted with no audit file (D-123)"
printf 'M2-01 and M4-02 stayed planned\n'

printf '== 4. an audit file that does not end with the pass line still refuses\n'
printf 'M1 audit\n\naudit: FAIL\n' >"$AUDIT"
python3 "$STATE" transition M1-12 "done" --attempt 2 --result re-checked >/dev/null
[ "$(row_status M2-01)" = "planned" ] || fail "M2-01 moved on a failing audit"
[ "$(row_status M4-02)" = "planned" ] || fail "M4-02 moved on a failing audit"
printf 'a failing audit promotes nothing\n'

printf '== 5. an audit ending in the pass line opens the gate on the next promotion\n'
printf 'M1 audit\n\naudit: PASS\n' >"$AUDIT"
python3 "$STATE" transition M1-12 "done" --attempt 3 --result re-checked >/dev/null
[ "$(row_status M2-01)" = "ready" ] || fail "M2-01 was not promoted after the pass"
[ "$(row_status M4-02)" = "ready" ] || fail "M4-02 was not promoted after the pass"
printf 'M2-01 and M4-02 ready\n'

python3 "$STATE" verify | tail -1 | grep -q 'status: DONE' ||
	fail "the event log chain is broken"

printf 'status: DONE\n'
