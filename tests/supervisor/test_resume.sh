#!/bin/sh
# Acceptance test for the Herdr-backed interactive coordinator launcher.
# Uses a stateful CLI stub: no Herdr session or Claude process is launched.
set -eu

SRC="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/supervisor-test.XXXXXX")"
SESSION="supervisor-test-$$"
export ECOSYSTEM_RUN_DIR="$WORK/logs"
export FAKE_HERDR_DIR="$WORK/herdr"
export HERDR_BIN="$SRC/tests/supervisor/fake_herdr.sh"
export DOCKER_BIN="$SRC/tests/supervisor/fake_docker.sh"
export FAKE_DOCKER_NAMES=""
ARG_ONLY_PID=""
ARG_ONLY_REAPED_PID=""

cleanup() {
	if [ -n "$ARG_ONLY_PID" ]; then
		kill "$ARG_ONLY_PID" 2>/dev/null || true
		wait "$ARG_ONLY_PID" 2>/dev/null || true
	fi
	sh "$WORK/tools/supervisor.sh" stop --repo "$WORK" --session "$SESSION" >/dev/null 2>&1 || true
	if [ -f "$FAKE_HERDR_DIR/$SESSION/server.pid" ]; then
		kill "$(sed -n '1p' "$FAKE_HERDR_DIR/$SESSION/server.pid")" 2>/dev/null || true
	fi
	rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

mkdir -p "$WORK/tools" "$WORK/run" "$WORK/logs"
cp "$SRC/tools/state.py" "$WORK/tools/state.py"
cp "$SRC/tools/supervisor.sh" "$WORK/tools/supervisor.sh"
cp "$SRC/run/events.jsonl" "$WORK/run/events.jsonl"
cp "$SRC/README.md" "$WORK/README.md"

fail() {
	printf '%s\n' "$1"
	[ ! -f "$FAKE_HERDR_DIR/trace.log" ] || sed -n '1,200p' "$FAKE_HERDR_DIR/trace.log"
	printf 'status: FAIL\n'
	exit 1
}

done_count() {
	python3 - "$WORK" <<'PY'
import os, sys
repo = sys.argv[1]
sys.path.insert(0, os.path.join(repo, "tools"))
import state  # noqa: E402
state.RUN_DIR = os.path.join(repo, "run")
state.LOG_PATH = os.path.join(state.RUN_DIR, "events.jsonl")
state.LOCK_PATH = os.path.join(state.RUN_DIR, "events.lock")
print(sum(row["status"] == "done" for row in state.project(state.read_events())["tasks"].values()))
PY
}

planned_tasks() {
	python3 - "$WORK" <<'PY'
import os, sys
repo = sys.argv[1]
sys.path.insert(0, os.path.join(repo, "tools"))
import state  # noqa: E402
state.RUN_DIR = os.path.join(repo, "run")
state.LOG_PATH = os.path.join(state.RUN_DIR, "events.jsonl")
state.LOCK_PATH = os.path.join(state.RUN_DIR, "events.lock")
snapshot = state.project(state.read_events())
for task in snapshot["order"]:
    if snapshot["tasks"][task]["status"] == "planned":
        print(task)
PY
}

fixture_ready() {
	python3 - "$WORK" "$@" <<'PY'
import os, sys
repo, *tasks = sys.argv[1:]
sys.path.insert(0, os.path.join(repo, "tools"))
import state  # noqa: E402
state.RUN_DIR = os.path.join(repo, "run")
state.LOG_PATH = os.path.join(state.RUN_DIR, "events.jsonl")
state.LOCK_PATH = os.path.join(state.RUN_DIR, "events.lock")
events = state.read_events()
snapshot = state.project(events)
for task in tasks:
    if snapshot["tasks"][task]["status"] != "planned":
        continue
    state.append(events, {
        "type": "transition", "task": task, "status": "ready",
        "lane": "", "path": "", "result": "fixture promotion", "evidence": "",
        "attempt": 0, "token": None, "idempotency": "fixture-promote-" + task,
    })
PY
}

state_has_lease() {
	python3 - "$WORK" "$1" <<'PY'
import os, sys
repo, task = sys.argv[1:]
sys.path.insert(0, os.path.join(repo, "tools"))
import state  # noqa: E402
state.RUN_DIR = os.path.join(repo, "run")
state.LOG_PATH = os.path.join(state.RUN_DIR, "events.jsonl")
state.LOCK_PATH = os.path.join(state.RUN_DIR, "events.lock")
raise SystemExit(0 if task in state.project(state.read_events())["leases"] else 1)
PY
}

printf '== 1. dry-run prints the interactive contract and launches nothing\n'
STORE_BEFORE="$(cksum "$WORK/run/events.jsonl")"
DRY="$(sh "$WORK/tools/supervisor.sh" start --repo "$WORK" --session "$SESSION" --dry-run)"
STORE_AFTER="$(cksum "$WORK/run/events.jsonl")"
printf '%s\n' "$DRY" | grep -q -- '--dangerously-skip-permissions' ||
	fail 'dry-run omitted Claude permission mode'
printf '%s\n' "$DRY" | grep -q -- '--model claude-fable-5' ||
	fail 'dry-run omitted pinned Claude model'
printf '%s\n' "$DRY" | grep -q -- '/goal Follow GOAL.md.' ||
	fail 'dry-run omitted canonical /goal prompt'
printf '%s\n' "$DRY" | grep -q -- "session attach $SESSION" ||
	fail 'dry-run omitted Herdr attach command'
printf '%s\n' "$DRY" | grep -q -- "workspace create --cwd $WORK --label $SESSION --no-focus" ||
	fail 'dry-run omitted workspace plan'
printf '%s\n' "$DRY" | grep -q -- 'agent prompt ecosystem-coordinator' ||
	fail 'dry-run omitted exact prompt-submission plan'
printf '%s\n' "$DRY" | grep -q -- 'reconcile preview:' ||
	fail 'dry-run omitted reconciliation preview'
[ "$STORE_BEFORE" = "$STORE_AFTER" ] || fail 'dry-run mutated run state'
if grep -Eq "^session=$SESSION <server>$|^session=$SESSION <workspace> <create>|^session=$SESSION <agent> <start>|^session=$SESSION <agent> <prompt>|^session=default <session> <attach>" \
	"$FAKE_HERDR_DIR/trace.log"; then
	fail 'dry-run launched a Herdr process or agent'
fi
[ -f "$WORK/logs/supervisor-$SESSION.log" ] || fail 'supervisor log is not session-keyed'
[ ! -e "$WORK/logs/supervisor.log" ] || fail 'shared supervisor log was created'
OTHER_SESSION="$SESSION-other"
OTHER_STATUS="$(sh "$WORK/tools/supervisor.sh" status --repo "$WORK" --session "$OTHER_SESSION")"
printf '%s\n' "$OTHER_STATUS" | grep -q "supervisor-$OTHER_SESSION.log" ||
	fail 'status omitted session-keyed supervisor log'
printf '%s\n' "$OTHER_STATUS" | grep -q "herdr-$OTHER_SESSION.log" ||
	fail 'status omitted session-keyed Herdr log'

printf '== 2. start creates isolated session, starts Claude, prompts, attaches\n'
sh "$WORK/tools/supervisor.sh" start --repo "$WORK" --session "$SESSION" >"$WORK/start.out"
TRACE="$FAKE_HERDR_DIR/trace.log"
START_LINE="$(grep -n 'starting isolated Herdr session' "$WORK/start.out" | cut -d: -f1)"
for planned in 'server command:' 'workspace command:' 'Claude command:' \
	'goal command (copy/paste fallback):' 'prompt command:' 'attach command:'; do
	line="$(grep -n "$planned" "$WORK/start.out" | sed -n '1s/:.*//p')"
	[ -n "$line" ] && [ "$line" -lt "$START_LINE" ] ||
		fail "launch plan was not fully printed before mutation: $planned"
done
grep -q "session=$SESSION <server>" "$TRACE" || fail 'named Herdr server not started'
[ -s "$WORK/logs/herdr-server-$SESSION.pid" ] || fail 'server pid is not session-keyed'
grep -q "session=$SESSION <workspace> <create>" "$TRACE" || fail 'workspace not created'
grep -q "session=$SESSION <agent> <start> <ecosystem-coordinator> <--kind> <claude>" "$TRACE" ||
	fail 'interactive Claude agent not started'
grep -q '<--dangerously-skip-permissions>' "$TRACE" || fail 'Claude permission flag not forwarded'
grep -q '<--model> <claude-fable-5>' "$TRACE" || fail 'Claude model not forwarded'
grep -q "session=$SESSION <agent> <prompt> <ecosystem-coordinator>" "$TRACE" ||
	fail 'canonical prompt not submitted through Herdr'
EXPECTED="$(sed -n '/^\/goal Follow GOAL\.md\./{p;q;}' "$WORK/README.md")"
[ "$(sed -n '1p' "$FAKE_HERDR_DIR/$SESSION/prompt")" = "$EXPECTED" ] ||
	fail 'submitted prompt differs from README source of truth'
grep -q "session=default <session> <attach> <$SESSION>" "$TRACE" ||
	fail 'interactive Herdr client not attached'

printf '== 3. status, read, and wait use Herdr agent state\n'
STATUS="$(sh "$WORK/tools/supervisor.sh" status --repo "$WORK" --session "$SESSION")"
printf '%s\n' "$STATUS" | grep -q 'herdr: running' || fail 'status missed live session'
printf '%s\n' "$STATUS" | grep -q 'coordinator: running' || fail 'status missed agent'
READ="$(sh "$WORK/tools/supervisor.sh" read --repo "$WORK" --session "$SESSION")"
printf '%s\n' "$READ" | grep -q 'Ready for input' || fail 'read missed agent output'
sh "$WORK/tools/supervisor.sh" wait --repo "$WORK" --session "$SESSION" \
	--pane ecosystem-coordinator --timeout 1 --interval 1 >/dev/null ||
	fail 'wait missed ready prompt'
grep -q "session=$SESSION <pane> <wait-output> <w1:p1>" "$TRACE" ||
	fail 'wait did not delegate terminal waiting to Herdr'

printf '== 4. reconciliation uses exact recorded agent, pane, and container identities\n'
AGENT_TASK="$(planned_tasks | sed -n '1p')"
PANE_TASK="$(planned_tasks | sed -n '2p')"
CONTAINER_TASK="$(planned_tasks | sed -n '3p')"
fixture_ready "$AGENT_TASK" "$PANE_TASK" "$CONTAINER_TASK"
for task in "$AGENT_TASK" "$PANE_TASK" "$CONTAINER_TASK"; do
	mkdir -p "$WORK/tasks/$task"
	cp "$SRC/tasks/$task/task.toml" "$WORK/tasks/$task/task.toml"
	python3 "$WORK/tools/state.py" lease "$task" --owner fixture --ttl 600 >/dev/null
done
EXPECTED_AGENT="$(printf '%s' "$AGENT_TASK" | tr '[:upper:]' '[:lower:]')"
printf '%s\n' "$EXPECTED_AGENT" >"$WORK/tasks/$AGENT_TASK/herdr-agent.txt"
printf 'w1:p1\n' >"$WORK/tasks/$PANE_TASK/herdr-pane.txt"
printf 'exact-container\n' >"$WORK/tasks/$CONTAINER_TASK/container.txt"
export FAKE_DOCKER_NAMES='exact-container'
export FAKE_HERDR_PROCESS_CMDLINE="jackin load the-architect task-$PANE_TASK --agent claude codex host"
sh "$WORK/tools/supervisor.sh" resume --repo "$WORK" --session "$SESSION" >"$WORK/mapping.out"
for task in "$AGENT_TASK" "$PANE_TASK" "$CONTAINER_TASK"; do
	state_has_lease "$task" || fail "exact live mapping did not retain $task lease"
done
printf 'ecosystem-coordinator\n' >"$WORK/tasks/$AGENT_TASK/herdr-agent.txt"
export FAKE_DOCKER_NAMES='exact-container-extra'
export FAKE_HERDR_PROCESS_CMDLINE="jackin load the-architect task-${PANE_TASK}a --agent claude codex host"
sh "$WORK/tools/supervisor.sh" resume --repo "$WORK" --session "$SESSION" >"$WORK/unmapped.out"
for task in "$AGENT_TASK" "$PANE_TASK" "$CONTAINER_TASK"; do
	if state_has_lease "$task"; then fail "unrecorded or substring runner retained $task lease"; fi
done
rm -f "$WORK/tasks/$AGENT_TASK/herdr-agent.txt" "$WORK/tasks/$PANE_TASK/herdr-pane.txt"
unset FAKE_HERDR_PROCESS_CMDLINE

printf '== 5. resume preserves a live coordinator and only reattaches\n'
BEFORE="$(grep -c "session=$SESSION <agent> <start>" "$TRACE")"
sh "$WORK/tools/supervisor.sh" resume --repo "$WORK" --session "$SESSION" >"$WORK/resume.out"
AFTER="$(grep -c "session=$SESSION <agent> <start>" "$TRACE")"
[ "$BEFORE" -eq "$AFTER" ] || fail 'resume restarted a live coordinator'
grep -q 'coordinator already live; preserving the current turn' "$WORK/resume.out" ||
	fail 'resume did not report preservation'

printf '== 6. resume restarts an absent coordinator without undoing done work\n'
rm -f "$FAKE_HERDR_DIR/$SESSION/agent"
DONE_BEFORE="$(done_count)"
sh "$WORK/tools/supervisor.sh" resume --repo "$WORK" --session "$SESSION" >"$WORK/restart.out"
DONE_AFTER="$(done_count)"
[ "$DONE_AFTER" -eq "$DONE_BEFORE" ] ||
	fail "resume changed done count from $DONE_BEFORE to $DONE_AFTER"
RESTARTED="$(grep -c "session=$SESSION <agent> <start>" "$TRACE")"
[ "$RESTARTED" -eq $((AFTER + 1)) ] || fail 'resume did not restart absent coordinator'
grep -q 'coordinator absent; restarting from durable run state' "$WORK/restart.out" ||
	fail 'resume did not report durable restart'
grep -q 'invariants hold: done .* no done task leased' "$WORK/restart.out" ||
	fail 'resume did not prove done-count and no-done-lease invariants'

printf '== 7. stop terminates the isolated session; no old launch backend remains\n'
sh "$WORK/tools/supervisor.sh" stop --repo "$WORK" --session "$SESSION" >/dev/null
STATUS="$(sh "$WORK/tools/supervisor.sh" status --repo "$WORK" --session "$SESSION")"
printf '%s\n' "$STATUS" | grep -q 'herdr: not running' || fail 'stop left session live'
if grep -Eqi 'tmux|TMUX_' "$SRC/tools/supervisor.sh"; then
	fail 'old launch backend remains in supervisor implementation'
fi

printf '== 8. failed partial kickoff closes workspace and stops new session\n'
export FAKE_HERDR_FAIL='agent-start'
if sh "$WORK/tools/supervisor.sh" start --repo "$WORK" --session "$SESSION" >"$WORK/partial.out" 2>&1; then
	fail 'partial coordinator failure unexpectedly succeeded'
fi
unset FAKE_HERDR_FAIL
STATUS="$(sh "$WORK/tools/supervisor.sh" status --repo "$WORK" --session "$SESSION")"
printf '%s\n' "$STATUS" | grep -q 'herdr: not running' || fail 'partial failure orphaned Herdr session'
grep -q "session=$SESSION <workspace> <close> <w1>" "$TRACE" ||
	fail 'partial failure did not close created workspace'
grep -q "session=default <session> <stop> <$SESSION> <--json>" "$TRACE" ||
	fail 'partial failure did not stop created session'
grep -q 'cleanup: rolling back partial kickoff' "$WORK/partial.out" ||
	fail 'partial failure cleanup was not observable'

printf '== 9. attach failure preserves coordinator and prints exact retry\n'
STOPS_BEFORE="$(grep -c "session=default <session> <stop> <$SESSION>" "$TRACE")"
export FAKE_HERDR_FAIL='attach'
if sh "$WORK/tools/supervisor.sh" start --repo "$WORK" --session "$SESSION" >"$WORK/attach-fail.out" 2>&1; then
	fail 'failed attach unexpectedly succeeded'
fi
unset FAKE_HERDR_FAIL
STATUS="$(sh "$WORK/tools/supervisor.sh" status --repo "$WORK" --session "$SESSION")"
printf '%s\n' "$STATUS" | grep -q 'herdr: running' || fail 'attach failure stopped Herdr session'
printf '%s\n' "$STATUS" | grep -q 'coordinator: running' || fail 'attach failure stopped coordinator'
grep -q "coordinator preserved; retry command: $HERDR_BIN session attach $SESSION" \
	"$WORK/attach-fail.out" || fail 'attach failure omitted retry command'
[ "$(grep -c "session=default <session> <stop> <$SESSION>" "$TRACE")" -eq "$STOPS_BEFORE" ] ||
	fail 'attach failure stopped pre-existing resources'

rm -f "$FAKE_HERDR_DIR/$SESSION/agent"
export FAKE_HERDR_FAIL='agent-start'
if sh "$WORK/tools/supervisor.sh" resume --repo "$WORK" --session "$SESSION" >"$WORK/preexisting-fail.out" 2>&1; then
	fail 'failed coordinator start in pre-existing session unexpectedly succeeded'
fi
unset FAKE_HERDR_FAIL
STATUS="$(sh "$WORK/tools/supervisor.sh" status --repo "$WORK" --session "$SESSION")"
printf '%s\n' "$STATUS" | grep -q 'herdr: running' ||
	fail 'partial resume stopped pre-existing session'
"$HERDR_BIN" --session "$SESSION" pane get w1:p1 >/dev/null ||
	fail 'partial resume closed pre-existing pane'
[ "$(grep -c "session=default <session> <stop> <$SESSION>" "$TRACE")" -eq "$STOPS_BEFORE" ] ||
	fail 'partial resume stopped pre-existing resources'
sh "$WORK/tools/supervisor.sh" stop --repo "$WORK" --session "$SESSION" >/dev/null

printf '== 10. legacy coordinator processes are refused before mutation\n'
SERVER_STARTS="$(grep -c "session=$SESSION <server>" "$TRACE")"
printf '%s\n' "$$" >"$WORK/logs/coordinator.pid"
if sh "$WORK/tools/supervisor.sh" start --repo "$WORK" --session "$SESSION" >"$WORK/legacy-pid.out" 2>&1; then
	fail 'live legacy coordinator pid was accepted'
fi
rm -f "$WORK/logs/coordinator.pid"
grep -q "legacy coordinator process(es) detected: pids=$$" "$WORK/legacy-pid.out" ||
	fail 'legacy coordinator refusal lacked exact pid'
[ "$(grep -c "session=$SESSION <server>" "$TRACE")" -eq "$SERVER_STARTS" ] ||
	fail 'legacy process refusal mutated Herdr state'

printf '== 11. a done task holding a lease is rejected as failed-system\n'
BAD_TASK="$(planned_tasks | sed -n '1p')"
fixture_ready "$BAD_TASK"
python3 "$WORK/tools/state.py" lease "$BAD_TASK" --owner fixture-bad --ttl 600 >/dev/null
BAD_TOKEN="$(python3 - "$WORK" "$BAD_TASK" <<'PY'
import os, sys
repo, task = sys.argv[1:]
sys.path.insert(0, os.path.join(repo, "tools"))
import state  # noqa: E402
state.RUN_DIR = os.path.join(repo, "run")
state.LOG_PATH = os.path.join(state.RUN_DIR, "events.jsonl")
state.LOCK_PATH = os.path.join(state.RUN_DIR, "events.lock")
print(state.project(state.read_events())["leases"][task]["token"])
PY
)"
python3 "$WORK/tools/state.py" transition "$BAD_TASK" 'in-progress' --token "$BAD_TOKEN" \
	--result fixture-bad >/dev/null
python3 "$WORK/tools/state.py" transition "$BAD_TASK" 'done' --token "$BAD_TOKEN" \
	--result fixture-bad >/dev/null
if sh "$WORK/tools/supervisor.sh" resume --repo "$WORK" --session "$SESSION" \
	--dry-run >"$WORK/done-lease.out" 2>&1; then
	fail 'done task with live lease passed restart invariants'
fi
grep -q "failed-system: done task(s) hold a lease: $BAD_TASK" "$WORK/done-lease.out" ||
	fail 'done-lease invariant failure lacked exact task id'

printf '== 12. quiescence proof is atomic, read-only, and fails closed\n'
PROOF="$WORK/quiescence.json"
MUTATIONS_BEFORE="$(grep -Ec '^session=[^ ]+ <server>$|<workspace> <create>|<agent> <start>|<pane> <run>' "$TRACE")"
STATUS_PROBES_BEFORE="$(grep -c '<status> <--json> <server>' "$TRACE" || true)"
export FAKE_HERDR_AUTOSTART_ON_STATUS=1
PROOF_STARTED="$(date +%s)"
sh "$WORK/tools/supervisor.sh" quiescence-proof "$PROOF" \
	--repo "$WORK" --session "$SESSION"
PROOF_ELAPSED=$(($(date +%s) - PROOF_STARTED))
[ "$PROOF_ELAPSED" -lt 5 ] || fail 'absent-session quiescence proof did not complete quickly'
[ ! -e "$FAKE_HERDR_DIR/auto-started" ] && [ ! -e "$FAKE_HERDR_DIR/default/live" ] ||
	fail 'absent-session proof invoked an auto-starting Herdr status command'
[ "$(grep -c '<status> <--json> <server>' "$TRACE" || true)" -eq "$STATUS_PROBES_BEFORE" ] ||
	fail 'quiescence proof invoked Herdr status instead of session inventory'
python3 - "$PROOF" "$WORK" "$SESSION" <<'PY' || fail 'quiet proof schema is invalid'
import json, os, re, sys
proof, repository, session = sys.argv[1:]
data = json.load(open(proof, encoding="utf-8"))
assert set(data) == {
    "repository", "session", "coordinator_running", "active_agents",
    "active_panes", "checked_at",
}
assert data["repository"] == os.path.realpath(repository)
assert data["session"] == session
assert data["coordinator_running"] is False
assert data["active_agents"] == []
assert data["active_panes"] == []
assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", data["checked_at"])
PY

# A process whose arguments contain both `pgrep` and `claude` is not Claude.
# `exec` makes the recorded PID the only process; teardown can reap it exactly.
(cd "$WORK" && exec python3 -c 'import time; time.sleep(30)' 'pgrep -ifl claude') &
ARG_ONLY_PID=$!
sh "$WORK/tools/supervisor.sh" quiescence-proof "$WORK/argument-proof.json" \
	--repo "$WORK" --session "$SESSION" ||
	fail 'proof matched a command argument instead of executable basename'
python3 - "$WORK/argument-proof.json" <<'PY' || fail 'argument-only proof is not quiescent'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["coordinator_running"] is False
assert data["active_agents"] == []
assert data["active_panes"] == []
PY
kill "$ARG_ONLY_PID" 2>/dev/null || true
wait "$ARG_ONLY_PID" 2>/dev/null || true
ARG_ONLY_REAPED_PID="$ARG_ONLY_PID"
if kill -0 "$ARG_ONLY_REAPED_PID" 2>/dev/null; then
	fail 'argument-only regression process survived explicit teardown'
fi
ARG_ONLY_PID=""

# Create only fake backend records; no server or child process is launched.
mkdir -p "$FAKE_HERDR_DIR/$SESSION"
touch "$FAKE_HERDR_DIR/$SESSION/live" "$FAKE_HERDR_DIR/$SESSION/pane" \
	"$FAKE_HERDR_DIR/$SESSION/agent"
if sh "$WORK/tools/supervisor.sh" quiescence-proof "$PROOF" \
	--repo "$WORK" --session "$SESSION" 2>"$WORK/active-proof.err"; then
	fail 'active Herdr state produced a quiescent proof'
fi
python3 - "$PROOF" <<'PY' || fail 'active proof omitted exact runner identifiers'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["coordinator_running"] is True
assert data["active_agents"] == ["ecosystem-coordinator"]
assert data["active_panes"] == ["w1:p1"]
PY

PROOF_BEFORE="$(cksum "$PROOF")"
export FAKE_HERDR_FAIL=agent-list
if sh "$WORK/tools/supervisor.sh" quiescence-proof "$PROOF" \
	--repo "$WORK" --session "$SESSION" >"$WORK/probe-fail.out" 2>&1; then
	fail 'failed Herdr query produced a successful proof'
fi
unset FAKE_HERDR_FAIL
[ "$(cksum "$PROOF")" = "$PROOF_BEFORE" ] ||
	fail 'failed Herdr query replaced the prior proof'
export FAKE_HERDR_FAIL=session-list
if sh "$WORK/tools/supervisor.sh" quiescence-proof "$PROOF" \
	--repo "$WORK" --session "$SESSION" >"$WORK/inventory-fail.out" 2>&1; then
	fail 'failed Herdr session inventory produced a successful proof'
fi
unset FAKE_HERDR_FAIL
[ "$(cksum "$PROOF")" = "$PROOF_BEFORE" ] ||
	fail 'failed Herdr session inventory replaced the prior proof'

rm -f "$FAKE_HERDR_DIR/$SESSION/agent"
export FAKE_HERDR_PANE_IDLE=1
sh "$WORK/tools/supervisor.sh" quiescence-proof "$PROOF" \
	--repo "$WORK" --session "$SESSION"
unset FAKE_HERDR_PANE_IDLE
python3 - "$PROOF" <<'PY' || fail 'idle-pane proof was not quiescent'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["coordinator_running"] is False
assert data["active_agents"] == []
assert data["active_panes"] == []
PY
rm -f "$FAKE_HERDR_DIR/$SESSION/live" "$FAKE_HERDR_DIR/$SESSION/pane"

printf '%s\n' "$$" >"$WORK/logs/coordinator.pid"
if sh "$WORK/tools/supervisor.sh" quiescence-proof "$PROOF" \
	--repo "$WORK" --session "$SESSION" 2>"$WORK/legacy-proof.err"; then
	fail 'legacy coordinator pid produced a quiescent proof'
fi
python3 - "$PROOF" "$$" <<'PY' || fail 'legacy pid missing from proof'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["coordinator_running"] is False
assert data["active_agents"] == ["legacy-pid:" + sys.argv[2]]
assert data["active_panes"] == []
PY
rm -f "$WORK/logs/coordinator.pid"
MUTATIONS_AFTER="$(grep -Ec '^session=[^ ]+ <server>$|<workspace> <create>|<agent> <start>|<pane> <run>' "$TRACE")"
[ "$MUTATIONS_AFTER" -eq "$MUTATIONS_BEFORE" ] ||
	fail 'quiescence proof launched or mutated a Herdr runner'
[ ! -e "$FAKE_HERDR_DIR/auto-started" ] && [ ! -e "$FAKE_HERDR_DIR/default/live" ] ||
	fail 'quiescence proof auto-started the default Herdr session'
unset FAKE_HERDR_AUTOSTART_ON_STATUS
[ -z "$(find "$WORK" -name '.quiescence-*.json' -print -quit)" ] ||
	fail 'quiescence proof left an atomic-write temporary file'

printf '== 13. real Herdr/macOS proof cannot recurse or create an absent session\n'
REAL_SESSION="supervisor-real-proof-$$"
REAL_PROOF="$WORK/real-quiescence.json"
if ! python3 - "$SRC" "$WORK" "$REAL_SESSION" "$REAL_PROOF" <<'PY'
import json, os, subprocess, sys, time

source, work, session, proof = sys.argv[1:]
environment = os.environ.copy()
for key in (
    "HERDR_BIN", "FAKE_HERDR_DIR", "FAKE_HERDR_FAIL",
    "FAKE_HERDR_AUTOSTART_ON_STATUS", "FAKE_HERDR_PANE_IDLE",
):
    environment.pop(key, None)

before = subprocess.run(
    ["herdr", "session", "list", "--json"], check=True, capture_output=True,
    text=True, timeout=2, env=environment,
).stdout
started = time.monotonic()
result = subprocess.run(
    ["sh", os.path.join(source, "tools", "supervisor.sh"),
     "quiescence-proof", proof, "--repo", work, "--session", session],
    cwd=work, capture_output=True, text=True, timeout=5, env=environment,
)
elapsed = time.monotonic() - started
if result.returncode != 0:
    raise AssertionError(result.stdout + result.stderr)
if elapsed >= 5:
    raise AssertionError("proof exceeded five seconds")
after = subprocess.run(
    ["herdr", "session", "list", "--json"], check=True, capture_output=True,
    text=True, timeout=2, env=environment,
).stdout
before_sessions = json.loads(before)["sessions"]
after_sessions = json.loads(after)["sessions"]
if before_sessions != after_sessions:
    raise AssertionError("session inventory changed")
if any(row.get("name") == session for row in after_sessions):
    raise AssertionError("absent named session was created")
data = json.load(open(proof, encoding="utf-8"))
assert data["repository"] == os.path.realpath(work)
assert data["session"] == session
assert data["coordinator_running"] is False
assert data["active_agents"] == []
assert data["active_panes"] == []
PY
then
	fail 'real absent-session proof recursed, timed out, or mutated Herdr'
fi

if [ -n "$ARG_ONLY_REAPED_PID" ] && kill -0 "$ARG_ONLY_REAPED_PID" 2>/dev/null; then
	fail 'argument-only regression process was live at final teardown assertion'
fi

printf 'status: DONE\n'
