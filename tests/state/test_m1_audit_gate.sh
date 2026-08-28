#!/bin/sh
# Acceptance test for the M1 exit audit gate (D-123, R3 close-out).
#
# "No non-exempt M2+ row is promoted to `ready` until
# `tasks/M1-12/audit.txt` ends with `audit: PASS`" — proven on a temporary
# store (`ECOSYSTEM_STORE`) so the run of record is never touched. Five
# properties are checked:
#
#   1. `arm` promotes the M1 bootstrap task even with no audit file.
#   2. The four CTRL-014 early-start ids promote as soon as their dependencies
#      are done, without M1-12 or an audit.
#   3. Other M2+ ids stay planned while the audit is missing or failing.
#   4. Once the file ends with `audit: PASS`, explicit gate reconciliation
#      promotes the non-exempt row without a duplicate `done` transition.
#   5. A passing audit cannot dispatch a task absent from the issue mirror.
#   6. A removed or failing audit immediately makes that ready row non-runnable.
#
#   sh tests/state/test_m1_audit_gate.sh
#
# Last line is `status: DONE` on success.

set -eu

SRC="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/state-audit-test.XXXXXX")"
export ECOSYSTEM_STORE="$WORK/store"
export ECOSYSTEM_RUN_LOCK="$WORK/LOCK.toml"
AUDIT="$ECOSYSTEM_STORE/M1-12-audit.txt"
ISSUES="$ECOSYSTEM_STORE/M1-12-issues.json"
STATE="$SRC/tools/state.py"

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT INT TERM

mkdir -p "$ECOSYSTEM_STORE"

fail() {
	printf '%s\n' "$1"
	printf 'status: FAIL\n'
	exit 1
}

# A seven-task DAG in the shape `tools/roadmap_compile.py --json` prints:
# M1-01 -> M1-12 -> M2-01, with all four early-start ids depending on M1-01.
cat >"$WORK/dag.json" <<'JSON'
{"ids": ["M1-01", "M1-12", "M2-01", "M3-01", "M3-03", "M4-02", "M4-03"],
 "edges": [["M1-12", "M1-01"], ["M2-01", "M1-12"],
           ["M3-01", "M1-01"], ["M3-03", "M1-01"],
           ["M4-02", "M1-01"], ["M4-03", "M1-01"]],
 "waves": {}}
JSON

LOCK_HASH=$(python3 - "$ECOSYSTEM_RUN_LOCK" <<'PY'
import hashlib, pathlib, sys
path = pathlib.Path(sys.argv[1])
body = '''[bundles]
"M1-01" = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
"M1-12" = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
"M2-01" = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
"M3-01" = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
"M3-03" = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
"M4-02" = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
"M4-03" = "1111111111111111111111111111111111111111111111111111111111111111"

[run]
epoch = 1
'''
digest = hashlib.sha256(body.encode()).hexdigest()
path.write_text(body + 'lock_hash = "%s"\n' % digest, encoding='utf-8')
print(digest)
PY
)

# Print one task's status from the rendered projection.
row_status() {
	awk -F'|' -v id="$1" '$2 ~ "^ "id" $" {gsub(/ /, "", $5); print $5}' \
		"$ECOSYSTEM_STORE/tasks-README.md"
}

assert_early_ready() {
	for id in M3-01 M3-03 M4-02 M4-03; do
		[ "$(row_status "$id")" = "ready" ] ||
			fail "early-start $id did not bypass the M1-12 and audit gates"
	done
}

complete_task() {
	id="$1"
	lease=$(python3 "$STATE" lease "$id" --owner "fixture:$id" --ttl 600)
	token=$(printf '%s\n' "$lease" |
		python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
	[ "$(row_status "$id")" = "leased" ] || fail "$id lease did not claim ready row"
	python3 "$STATE" transition "$id" in-progress --token "$token" >/dev/null
	python3 "$STATE" transition "$id" 'done' --token "$token" --result seeded >/dev/null
	python3 "$STATE" release "$id" --token "$token" >/dev/null
}

artifact_sha() {
	python3 - "$1" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}

write_artifacts() {
	printf 'M1-01 host verify\nstatus: DONE\n' >"$ECOSYSTEM_STORE/audit-M1-01.out"
	printf 'M1-12 host verify\nstatus: DONE\n' >"$ECOSYSTEM_STORE/audit-M1-12.out"
	printf 'locked creation set and M1 exit gate\nstatus: DONE\n' \
		>"$ECOSYSTEM_STORE/audit-exit-gate.out"
}

write_audit() {
	epoch="$1"
	lock_hash="$2"
	m101_bundle="${3:-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}"
	{
		printf 'lock_epoch: %s\n' "$epoch"
		printf 'lock_hash: %s\n' "$lock_hash"
		printf 'exit_gate_sha256: %s\n' \
			"$(artifact_sha "$ECOSYSTEM_STORE/audit-exit-gate.out")"
		printf 'M1-01: bundle=%s verify=%s\n' \
			"$m101_bundle" \
			"$(artifact_sha "$ECOSYSTEM_STORE/audit-M1-01.out")"
		printf 'M1-12: bundle=%s verify=%s\n' \
			bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
			"$(artifact_sha "$ECOSYSTEM_STORE/audit-M1-12.out")"
		printf 'audit: PASS\n'
	} >"$AUDIT"
}

write_issue_mirror() {
	cat >"$ISSUES" <<'JSON'
{"passes":[{"issues":[{"task_id":"M2-01"}]},{"issues":[{"task_id":"M2-01"}]}]}
JSON
}

python3 "$STATE" init --dag "$WORK/dag.json" --run-id audit-gate-test >/dev/null
python3 "$STATE" lock-epoch --epoch 1 --lock-hash "$LOCK_HASH" \
	--key audit-gate-bootstrap --bootstrap >/dev/null

printf '== 1. arm promotes the M1 bootstrap with no audit file present\n'
[ ! -e "$AUDIT" ] || fail "the fixture store already has an audit file"
python3 "$STATE" arm >/dev/null
[ "$(row_status M1-01)" = "ready" ] || fail "arm did not promote M1-01"
printf 'M1-01 ready\n'

printf '== 2. M1-01 done promotes M1-12 and all four early-start ids\n'
complete_task M1-01
[ "$(row_status M1-12)" = "ready" ] || fail "M1-12 was not promoted"
assert_early_ready
printf 'M1-12 and early-start ids ready\n'

printf '== 3. no audit file: M1-12 done does not promote ordinary M2+\n'
complete_task M1-12
python3 "$STATE" promote >/dev/null
[ "$(row_status M2-01)" = "planned" ] ||
	fail "M2-01 was promoted with no audit file (CTRL-006)"
assert_early_ready
printf 'M2-01 stayed planned; early-start ids stayed ready\n'

printf '== 4. last-line PASS and mismatched lock identities still refuse\n'
printf 'audit: PASS\n' >"$AUDIT"
python3 "$STATE" promote >/dev/null
[ "$(row_status M2-01)" = "planned" ] || fail "last-line-only audit promoted M2-01"
write_artifacts
write_audit 2 "$LOCK_HASH"
python3 "$STATE" promote >/dev/null
[ "$(row_status M2-01)" = "planned" ] || fail "wrong audit epoch promoted M2-01"
write_audit 1 2222222222222222222222222222222222222222222222222222222222222222
python3 "$STATE" promote >/dev/null
[ "$(row_status M2-01)" = "planned" ] || fail "wrong audit lock hash promoted M2-01"
write_audit 1 "$LOCK_HASH" 0000000000000000000000000000000000000000000000000000000000000000
python3 "$STATE" promote >/dev/null
[ "$(row_status M2-01)" = "planned" ] || fail "wrong locked M1 bundle promoted M2-01"
assert_early_ready
printf 'unbound and stale audits promoted no ordinary M2+ row\n'

printf '== 5. a passing audit opens the gate through explicit reconciliation\n'
write_audit 1 "$LOCK_HASH"
python3 "$STATE" promote >/dev/null
[ "$(row_status M2-01)" = "ready" ] || fail "M2-01 was not promoted after the pass"
[ "$(grep -c '"status":"done","task":"M1-12"' "$ECOSYSTEM_STORE/events.jsonl")" = 1 ] ||
	fail "audit reconciliation duplicated the M1-12 done transition"
assert_early_ready
printf 'M2-01 and early-start ids ready\n'

events_before=$(wc -l <"$ECOSYSTEM_STORE/events.jsonl")
python3 "$STATE" promote >/dev/null
[ "$(wc -l <"$ECOSYSTEM_STORE/events.jsonl")" = "$events_before" ] ||
	fail "repeated promotion was not idempotent"

printf '== 6. runnable re-checks the audit after promotion\n'
if python3 "$STATE" runnable | grep -qx M2-01; then
	fail "M2-01 was runnable without its issue mirror"
fi
write_issue_mirror
python3 "$STATE" runnable | grep -qx M2-01 ||
	fail "M2-01 was not runnable with passing audit and mirrored issue"
printf 'tampered but still well-formed\nstatus: DONE\n' \
	>"$ECOSYSTEM_STORE/audit-M1-01.out"
if python3 "$STATE" runnable | grep -qx M2-01; then
	fail "M2-01 remained runnable after a verified artifact changed"
fi
write_artifacts
write_audit 1 "$LOCK_HASH"
python3 "$STATE" runnable | grep -qx M2-01 || fail "restored audit did not reopen gate"
rm -f "$AUDIT"
if python3 "$STATE" runnable | grep -qx M2-01; then
	fail "M2-01 remained runnable after the audit disappeared"
fi
printf 'ready row stayed gated by current audit state; promotion stayed idempotent\n'

python3 "$STATE" verify | tail -1 | grep -q 'status: DONE' ||
	fail "the event log chain is broken"

printf 'status: DONE\n'
