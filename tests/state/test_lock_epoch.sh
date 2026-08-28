#!/bin/sh
# Acceptance test for immutable-lock binding and atomic epoch migration.

set -eu

SRC="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/state-lock-epoch-test.XXXXXX")"
export ECOSYSTEM_STORE="$WORK/store"
export ECOSYSTEM_RUN_LOCK="$WORK/LOCK.toml"
STATE="$SRC/tools/state.py"
KEY_BOOTSTRAP=lock-epoch-bootstrap
KEY_TWO=lock-epoch-two
KEY_THREE=lock-epoch-three

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT INT TERM
mkdir -p "$ECOSYSTEM_STORE"

fail() {
	printf '%s\n' "$1"
	printf 'status: FAIL\n'
	exit 1
}

write_lock() {
	python3 - "$ECOSYSTEM_RUN_LOCK" "$1" "$SRC/run/LOCK.toml" <<'PY'
import hashlib, pathlib, sys
path, epoch, template = pathlib.Path(sys.argv[1]), int(sys.argv[2]), pathlib.Path(sys.argv[3])
lines = template.read_text(encoding="utf-8").splitlines(keepends=True)
body_lines = []
in_run = False
for line in lines:
    if line.strip() == "[run]":
        in_run = True
    if in_run and line.lstrip().startswith("epoch ="):
        ending = "\n" if line.endswith("\n") else ""
        line = "epoch = %d%s" % (epoch, ending)
    if line.lstrip().startswith("lock_hash"):
        continue
    body_lines.append(line)
body = "".join(body_lines)
digest = hashlib.sha256(body.encode()).hexdigest()
path.write_text(body + 'lock_hash = "%s"\n' % digest, encoding="utf-8")
print(digest)
PY
}

write_proof() {
	python3 - "$1" "$SRC" "${2:-0}" <<'PY'
from datetime import datetime, timedelta, timezone
import json, pathlib, sys
checked = datetime.now(timezone.utc) - timedelta(seconds=int(sys.argv[3]))
proof = {
    "repository": str(pathlib.Path(sys.argv[2]).resolve()),
    "session": "ecosystem-coordinator",
    "coordinator_running": False,
    "active_agents": [],
    "active_panes": [],
    "checked_at": checked.strftime("%Y-%m-%dT%H:%M:%SZ"),
}
pathlib.Path(sys.argv[1]).write_text(json.dumps(proof) + "\n", encoding="utf-8")
PY
}

cat >"$WORK/dag.json" <<'JSON'
{"ids": ["DONE", "ACTIVE", "WAIT", "RESOURCE", "LEASED", "BLOCKED", "PLANNED"],
 "edges": [], "waves": {}}
JSON

hash_one=$(write_lock 1)
python3 - "$STATE" "$SRC/tools/lock.py" "$ECOSYSTEM_RUN_LOCK" <<'PY' ||
import importlib.util, pathlib, sys
modules = []
for name, path in (("state", sys.argv[1]), ("lock", sys.argv[2])):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    modules.append(module)
text = pathlib.Path(sys.argv[3]).read_text(encoding="utf-8")
assert modules[0].lock_hash_of(text) == modules[1].lock_hash_of(text)
PY
fail "state and repository lock hashing algorithms differ"
python3 "$STATE" init --dag "$WORK/dag.json" --run-id lock-epoch-test >/dev/null
# Seed legacy pre-gate events directly: this fixture proves the expand phase
# preserves historical replay while enforcing only future CLI appends.
python3 - "$STATE" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("state", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
events = module.read_events()
for task, status, result, evidence in (
    ("DONE", "done", "complete", "keep-this-evidence"),
    ("ACTIVE", "in-progress", "", ""),
    ("WAIT", "waiting", "throttled", ""),
    ("RESOURCE", "resource-waiting", "capped", ""),
    ("LEASED", "leased", "", ""),
    ("BLOCKED", "blocked", "operator-input", ""),
):
    module.append(events, {
        "type": "transition", "task": task, "status": status,
        "lane": "", "path": "", "result": result, "evidence": evidence,
        "attempt": 1, "token": None, "idempotency": "legacy-" + task,
    })
module.render(module.project(events))
PY
lease_json=$(python3 "$STATE" lease ACTIVE --owner fixture-worker --ttl 600)
token=$(printf '%s\n' "$lease_json" |
	python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')

printf '== 1. verify rejects an unbound store, then bootstrap binds without reset\n'
if python3 "$STATE" verify >"$WORK/unbound.out" 2>&1; then
	fail "epoch-0 state verified against an epoch-1 lock"
fi
grep -q 'state lock epoch/hash does not match' "$WORK/unbound.out" ||
	fail "unbound verification failure did not name the lock mismatch"
python3 "$STATE" lock-epoch --epoch 1 --lock-hash "$hash_one" \
	--key "$KEY_BOOTSTRAP" --bootstrap >"$WORK/bootstrap.out"
python3 - "$STATE" "$hash_one" <<'PY' || fail "bootstrap changed task state"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("state", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
state = module.project(module.read_events())
assert state["lock_epoch"] == 1 and state["lock_hash"] == sys.argv[2]
assert state["tasks"]["ACTIVE"]["status"] == "in-progress"
assert state["tasks"]["ACTIVE"]["attempt_epoch"] == 1
assert state["tokens"]["ACTIVE"] == 1
event = next(item for item in module.read_events() if item["type"] == "lock_epoch")
assert event["bootstrap"] is True and event["resets"] == [] and event["fences"] == []
PY
python3 "$STATE" verify | tail -1 | grep -q 'status: DONE' ||
	fail "bootstrapped state does not verify"

printf '== 2. requested identity must exactly match the parsed immutable lock\n'
hash_two=$(write_lock 2)
if python3 "$STATE" verify >"$WORK/advanced-lock.out" 2>&1; then
	fail "state verified after run/LOCK.toml advanced alone"
fi
wrong_hash=dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
if python3 "$STATE" lock-epoch --epoch 2 --lock-hash "$wrong_hash" \
	--key wrong-lock >"$WORK/wrong-lock.out" 2>&1; then
	fail "caller-supplied hash overrode run/LOCK.toml"
fi
grep -q 'REJECTED: requested lock does not match run/LOCK.toml' "$WORK/wrong-lock.out" ||
	fail "wrong lock identity had no audited refusal"

printf '== 3. a live lease blocks reset before proof is considered\n'
if python3 "$STATE" lock-epoch --epoch 2 --lock-hash "$hash_two" \
	--key "$KEY_TWO" --quiescent --quiescence-proof "$WORK/missing.json" \
	>"$WORK/leased.out" 2>&1; then
	fail "lock epoch changed while a lease was active"
fi
grep -q 'REJECTED: active leases prevent lock epoch change' "$WORK/leased.out" ||
	fail "lease refusal was not explicit"
python3 "$STATE" release ACTIVE --token "$token" >/dev/null

printf '== 4. active task reset requires explicit, fresh supervisor proof\n'
if python3 "$STATE" lock-epoch --epoch 2 --lock-hash "$hash_two" \
	--key "$KEY_TWO" >"$WORK/no-proof.out" 2>&1; then
	fail "active tasks reset without quiescence proof"
fi
grep -q 'REJECTED: active tasks require quiescence proof' "$WORK/no-proof.out" ||
	fail "missing proof refusal was not explicit"
write_proof "$WORK/stale-proof.json" 301
if python3 "$STATE" lock-epoch --epoch 2 --lock-hash "$hash_two" \
	--key "$KEY_TWO" --quiescent --quiescence-proof "$WORK/stale-proof.json" \
	>"$WORK/stale-proof.out" 2>&1; then
	fail "stale quiescence proof was accepted"
fi
grep -q 'REJECTED: quiescence proof is invalid' "$WORK/stale-proof.out" ||
	fail "stale proof refusal was not audited"
write_proof "$WORK/proof.json"

printf '== 5. one event resets interrupted work and preserves terminal evidence\n'
progress_before=$(cksum "$ECOSYSTEM_STORE/PROGRESS.md")
python3 "$STATE" lock-epoch --epoch 2 --lock-hash "$hash_two" \
	--key "$KEY_TWO" --quiescent --quiescence-proof "$WORK/proof.json" \
	>"$WORK/epoch-two.out"
python3 - "$STATE" "$hash_two" <<'PY' || fail "epoch-2 projection is wrong"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("state", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
state = module.project(module.read_events())
assert state["lock_epoch"] == 2 and state["lock_hash"] == sys.argv[2]
for task in ("ACTIVE", "WAIT", "RESOURCE", "LEASED"):
    assert state["tasks"][task]["status"] == "ready", task
    assert state["tasks"][task]["attempt_epoch"] == 2, task
assert state["tasks"]["DONE"]["status"] == "done"
assert state["tasks"]["DONE"]["attempt_epoch"] == 1
assert state["tasks"]["BLOCKED"]["status"] == "blocked"
assert state["tasks"]["PLANNED"]["status"] == "planned"
event = [item for item in module.read_events() if item["type"] == "lock_epoch"][-1]
assert event["bootstrap"] is False
assert len(event["quiescence"]["proof_sha256"]) == 64
assert event["quiescence"]["active_agents"] == 0
assert event["quiescence"]["active_panes"] == 0
assert "path" not in event["quiescence"]
PY
[ "$(cksum "$ECOSYSTEM_STORE/PROGRESS.md")" = "$progress_before" ] ||
	fail "lock migration changed retained progress evidence"
grep -q 'keep-this-evidence' "$ECOSYSTEM_STORE/PROGRESS.md" ||
	fail "done-task evidence was lost"
python3 "$STATE" verify | tail -1 | grep -q 'status: DONE' ||
	fail "epoch-2 state does not match the immutable lock"

printf '== 6. exact retry is idempotent and repairs projections\n'
lines_before=$(wc -l <"$ECOSYSTEM_STORE/events.jsonl" | tr -d ' ')
printf 'corrupt projection\n' >"$ECOSYSTEM_STORE/tasks-README.md"
python3 "$STATE" lock-epoch --epoch 2 --lock-hash "$hash_two" \
	--key "$KEY_TWO" --quiescent --quiescence-proof "$WORK/proof.json" \
	>"$WORK/replay.out"
grep -q '"replayed": true' "$WORK/replay.out" || fail "retry was not replayed"
[ "$(wc -l <"$ECOSYSTEM_STORE/events.jsonl" | tr -d ' ')" = "$lines_before" ] ||
	fail "exact retry appended another event"
grep -q '^# Tasks' "$ECOSYSTEM_STORE/tasks-README.md" ||
	fail "exact retry did not repair projections"

printf '== 7. task default keys include lock and attempt epochs\n'
lease_json=$(python3 "$STATE" lease ACTIVE --owner fixture-worker --ttl 600)
post_reset_token=$(printf '%s\n' "$lease_json" |
	python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
python3 "$STATE" transition ACTIVE in-progress --attempt 1 \
	--token "$post_reset_token" >/dev/null ||
	fail "post-reset attempt collided with its pre-reset default key"
python3 "$STATE" release ACTIVE --token "$post_reset_token" >/dev/null
python3 - "$STATE" <<'PY' || fail "post-reset transition key is not epoch-scoped"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("state", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
events = module.read_events()
starts = [item for item in events if item.get("task") == "ACTIVE" and
          item.get("type") == "transition" and item.get("status") == "in-progress"]
assert len(starts) == 2
assert starts[0]["attempt"] == starts[1]["attempt"] == 1
assert starts[0]["idempotency"] != starts[1]["idempotency"]
PY

printf '== 8. the lock epoch itself invalidates every earlier fencing token\n'
if python3 "$STATE" event ACTIVE --operation stale-before-replacement --attempt 2 \
	--token "$token" >"$WORK/stale-token.out" 2>&1; then
	fail "pre-migration fencing token survived the lock epoch"
fi
grep -q 'REJECTED: stale fencing token' "$WORK/stale-token.out" ||
	fail "old token had no clear refusal"
lease_json=$(python3 "$STATE" lease ACTIVE --owner replacement-worker --ttl 600)
new_token=$(printf '%s\n' "$lease_json" |
	python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
[ "$new_token" -gt "$token" ] || fail "replacement fencing token did not advance"
python3 "$STATE" release ACTIVE --token "$new_token" >/dev/null

printf '== 9. conflicting keys are audited; the next epoch retains rollback data\n'
hash_three=$(write_lock 3)
if python3 "$STATE" lock-epoch --epoch 3 --lock-hash "$hash_three" \
	--key "$KEY_TWO" --quiescent --quiescence-proof "$WORK/proof.json" \
	>"$WORK/conflict.out" 2>&1; then
	fail "conflicting reuse of an idempotency key succeeded"
fi
grep -q 'REJECTED: conflicting duplicate idempotency key' "$WORK/conflict.out" ||
	fail "conflicting duplicate had no audited refusal"
write_proof "$WORK/proof-three.json"
python3 "$STATE" lock-epoch --epoch 3 --lock-hash "$hash_three" \
	--key "$KEY_THREE" --quiescent --quiescence-proof "$WORK/proof-three.json" >/dev/null
python3 - "$ECOSYSTEM_STORE/events.jsonl" "$hash_one" "$hash_two" <<'PY' ||
import json, sys
events = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8")]
epochs = [event for event in events if event["type"] == "lock_epoch"]
assert len(epochs) == 3
bootstrap, second, third = epochs
assert bootstrap["previous_epoch"] == 0 and bootstrap["previous_lock_hash"] is None
assert second["previous_epoch"] == 1 and second["previous_lock_hash"] == sys.argv[2]
assert {item["task"] for item in second["resets"]} == {
    "ACTIVE", "WAIT", "RESOURCE", "LEASED"
}
assert third["previous_epoch"] == 2 and third["previous_lock_hash"] == sys.argv[3]
assert [item["task"] for item in third["resets"]] == ["ACTIVE"]
active_fence = next(item for item in second["fences"] if item["task"] == "ACTIVE")
assert active_fence == {"task": "ACTIVE", "from_token": 1, "to_token": 2}
PY
fail "lock events lack rollback/audit data"

printf '== 10. rendering is stable and the append-only chain remains intact\n'
python3 "$STATE" render >/dev/null
readme_before=$(cksum "$ECOSYSTEM_STORE/tasks-README.md")
progress_before=$(cksum "$ECOSYSTEM_STORE/PROGRESS.md")
python3 "$STATE" render >/dev/null
[ "$(cksum "$ECOSYSTEM_STORE/tasks-README.md")" = "$readme_before" ] ||
	fail "tasks projection is unstable"
[ "$(cksum "$ECOSYSTEM_STORE/PROGRESS.md")" = "$progress_before" ] ||
	fail "progress projection is unstable"
python3 "$STATE" verify | tail -1 | grep -q 'status: DONE' ||
	fail "event hash chain or lock identity is broken"

printf 'status: DONE\n'
