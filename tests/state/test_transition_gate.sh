#!/bin/sh
# Focused forward-enforcement test for proof-plane transitions and leases.
set -eu

SRC=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/state-transition.XXXXXX")
trap 'rm -rf "$WORK"' EXIT INT TERM
HISTORICAL="$WORK/historical"
STORE="$WORK/store"
RUN_LOCK="$WORK/LOCK.toml"
mkdir -p "$HISTORICAL" "$STORE"
cp "$SRC/run/events.jsonl" "$HISTORICAL/events.jsonl"
PRODUCTION_BEFORE=$(cksum "$SRC/run/events.jsonl")

fail() {
  printf '%s\n' "$1"
  printf '%s\n' 'status: FAIL'
  exit 1
}

state() {
  ECOSYSTEM_STORE="$STORE" ECOSYSTEM_RUN_LOCK="$RUN_LOCK" \
    python3 "$SRC/tools/state.py" "$@"
}

expect_fail() {
  if "$@" >/dev/null 2>&1; then
    fail "unexpected success: $*"
  fi
}

status_of() {
  state status | python3 -c \
    'import json,sys; print(json.load(sys.stdin)["counts"].get(sys.argv[1], 0))' "$1"
}

task_status() {
  ECOSYSTEM_STORE="$STORE" python3 - "$SRC" "$1" <<'PY'
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "tools"))
import state
snapshot = state.project(state.read_events())
print(snapshot["tasks"][sys.argv[2]]["status"])
PY
}

has_lease() {
  ECOSYSTEM_STORE="$STORE" python3 - "$SRC" "$1" <<'PY'
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "tools"))
import state
raise SystemExit(0 if sys.argv[2] in state.project(state.read_events())["leases"] else 1)
PY
}

lease_token() {
  state lease "$1" --owner "$2" --ttl "$3" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])'
}

cat >"$WORK/dag.json" <<'JSON'
{"ids":["M1-01","M1-02a","M1-04a","M1-03"],
 "edges":[["M1-02a","M1-01"],["M1-04a","M1-01"],["M1-03","M1-02a"]],
 "waves":{}}
JSON

LOCK_HASH=$(python3 - "$RUN_LOCK" <<'PY'
import hashlib, pathlib, sys
path = pathlib.Path(sys.argv[1])
body = '''[bundles]
"M1-01" = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
"M1-02a" = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
"M1-03" = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
"M1-04a" = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

[run]
epoch = 1
'''
digest = hashlib.sha256(body.encode()).hexdigest()
path.write_text(body + 'lock_hash = "%s"\n' % digest, encoding='utf-8')
print(digest)
PY
)

state init --dag "$WORK/dag.json" --run-id transition-gate-test >/dev/null
state lock-epoch --epoch 1 --lock-hash "$LOCK_HASH" \
  --key transition-gate-bootstrap --bootstrap >/dev/null
state arm >/dev/null
SEED=$(lease_token M1-01 host:fixture 300)
state transition M1-01 in-progress --token "$SEED" >/dev/null
state transition M1-01 'done' --token "$SEED" >/dev/null
state release M1-01 --token "$SEED" >/dev/null
SNAPSHOT=$(state status)
printf '%s\n' "$SNAPSHOT" | python3 -c '
import json, pathlib, sys
snapshot = json.load(sys.stdin)
events = [line for line in pathlib.Path(sys.argv[1]).read_text().splitlines() if line]
assert snapshot["event_seq"] == len(events) - 1
assert snapshot["task_statuses"]["M1-01"] == "done"
assert snapshot["task_statuses"]["M1-02a"] == "ready"
' "$STORE/events.jsonl" || fail 'status did not expose an event-bound task status snapshot'

printf '%s\n' '== 1. historical store replays unchanged'
ECOSYSTEM_STORE="$HISTORICAL" python3 "$SRC/tools/state.py" verify |
  tail -n 1 | grep -qx 'status: DONE' || fail 'historical chain failed'
[ "$(status_of 'done')" -eq 1 ] || fail 'fixture done count changed'
[ "$(status_of ready)" -eq 2 ] || fail 'historical ready count changed'
[ "$(status_of planned)" -eq 1 ] || fail 'fixture planned count changed'

printf '%s\n' '== 2. illegal terminal and promotion bypasses fail closed'
expect_fail state transition M1-01 ready --attempt 99 --key test-done-ready
[ "$(task_status M1-01)" = 'done' ] || fail 'done task changed status'
expect_fail state transition M1-03 'done' --attempt 99 --key test-planned-done
[ "$(task_status M1-03)" = planned ] || fail 'planned task changed status'

printf '%s\n' '== 3. claim is atomic and same-owner retry is idempotent'
state transition M1-02a resource-waiting >/dev/null
[ "$(task_status M1-02a)" = resource-waiting ] ||
  fail 'internal cap bookkeeping did not record resource-waiting'
state transition M1-02a ready >/dev/null
[ "$(task_status M1-02a)" = ready ] ||
  fail 'internal cap bookkeeping did not restore ready'
TOKEN=$(lease_token M1-02a host:coordinator 300)
[ "$(task_status M1-02a)" = leased ] || fail 'claim did not project leased'
LINES=$(wc -l <"$STORE/events.jsonl" | tr -d ' ')
REPLAY=$(state lease M1-02a --owner host:coordinator --ttl 300)
printf '%s\n' "$REPLAY" | grep -q '"replayed": true' || fail 'lease retry was not replayed'
[ "$(wc -l <"$STORE/events.jsonl" | tr -d ' ')" -eq "$LINES" ] ||
  fail 'same-owner lease retry appended'
expect_fail state lease M1-02a --owner host:other --ttl 300

printf '%s\n' '== 4. legal transitions and events require the exact live token'
expect_fail state transition M1-02a in-progress
expect_fail state transition M1-02a in-progress --token $((TOKEN + 1))
expect_fail state event M1-02a --operation proof --key proof-without-token
state transition M1-02a in-progress --token "$TOKEN" >/dev/null
state event M1-02a --operation proof --token "$TOKEN" --key proof-with-token >/dev/null
state release M1-02a --token "$TOKEN" >/dev/null
LINES=$(wc -l <"$STORE/events.jsonl" | tr -d ' ')
state release M1-02a --token "$TOKEN" | grep -q '(replayed)' || fail 'release retry failed'
[ "$(wc -l <"$STORE/events.jsonl" | tr -d ' ')" -eq "$LINES" ] ||
  fail 'release retry appended'
expect_fail state event M1-02a --operation post-release --token "$TOKEN" --key post-release

printf '%s\n' '== 5. expired leases gate mutations and supervisor cleanup is explicit'
EXPIRED=$(lease_token M1-02a host:coordinator 0)
expect_fail state event M1-02a --operation expired --token "$EXPIRED" --key expired-event
expect_fail state release M1-02a --token "$EXPIRED"
state release M1-02a --token "$EXPIRED" --expired >/dev/null
has_lease M1-02a && fail 'expired cleanup retained lease'

printf '%s\n' '== 6. release cancels a claim and the full lifecycle is legal'
CANCEL=$(lease_token M1-04a host:coordinator 300)
state release M1-04a --token "$CANCEL" >/dev/null
[ "$(task_status M1-04a)" = ready ] || fail 'claim cancellation did not restore ready'
LIVE=$(lease_token M1-04a host:coordinator 300)
state transition M1-04a in-progress --token "$LIVE" >/dev/null
state transition M1-04a waiting --token "$LIVE" >/dev/null
state transition M1-04a in-progress --token "$LIVE" >/dev/null
state transition M1-04a 'done' --token "$LIVE" >/dev/null
state release M1-04a --token "$LIVE" >/dev/null
[ "$(task_status M1-04a)" = 'done' ] || fail 'legal lifecycle did not finish'
has_lease M1-04a && fail 'done task retained lease'
expect_fail state lease M1-04a --owner host:coordinator --ttl 300
expect_fail state lease M1-03 --owner host:coordinator --ttl 300

state verify | tail -n 1 | grep -qx 'status: DONE' || fail 'resulting chain failed'
[ "$(cksum "$SRC/run/events.jsonl")" = "$PRODUCTION_BEFORE" ] ||
  fail 'production event store changed'
printf '%s\n' 'status: DONE'
