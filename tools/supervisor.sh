#!/bin/sh
# Herdr launcher for the interactive /goal run (K-29, D-095, D-120).
#
# Herdr owns the persistent terminal and process lifetime. This script owns the
# run contract around it: one isolated named session, one named coordinator,
# the exact README.md /goal prompt, durable-state reconciliation, and a small
# read/wait/status/stop surface that never depends on a model polling loop.
#
#   sh tools/supervisor.sh start   [options]  create session, start Claude, /goal, attach
#   sh tools/supervisor.sh resume  [options]  resume/restart Claude if needed, attach
#   sh tools/supervisor.sh status  [options]  show Herdr and run-store state
#   sh tools/supervisor.sh stop    [options]  stop session and all its pane processes
#   sh tools/supervisor.sh read    [options]  print recent coordinator/task output
#   sh tools/supervisor.sh wait    [options]  wait until a task is ready
#   sh tools/supervisor.sh watch   [options]  compatibility alias for wait
#   sh tools/supervisor.sh quiescence-proof FILE [options]  atomically prove no runner is active
#
# start always prints the Claude command, literal /goal prompt, and attach
# command before Claude starts. Prompt delivery is automatic; the printed line
# is the operator's copy/paste fallback if delivery is refused.
#
# Options:
#   --dry-run                 print exact intent; create no session or process
#   --coordinator-cmd <cmd>   run a test coordinator in the root pane
#   --session <name>          isolated Herdr session (default ecosystem-coordinator)
#   --repo <path>             repository root (default script parent)
#   --pane <agent-or-pane>    target for read/wait (default coordinator for read)
#   --pattern <ere>           output meaning ready (default runtime prompt)
#   --timeout <s>             wait budget (default 900)
#   --interval <s>            wait polling interval (default 5)
#   --done-file <path>        ready when last line is status: DONE
#   --lines <n>               rows printed by read (default 160)
#
# Environment:
#   HERDR_BIN                 Herdr executable (default herdr; fake seam for tests)
#   DOCKER_BIN                container liveness detector (default docker; test seam)
#   ECOSYSTEM_RUN_DIR         local supervisor logs/state handles
#
# POSIX sh; Python 3 stdlib is used only to parse Herdr JSON.

set -eu

SESSION="ecosystem-coordinator"
COORDINATOR_AGENT="ecosystem-coordinator"
HERDR_BIN="${HERDR_BIN:-herdr}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
DRY_RUN=0
COORDINATOR_CMD=""
REPO=""
TARGET=""
WAIT_PATTERN='(^|[[:space:]])❯[[:space:]]*$|^│[[:space:]]*>[[:space:]]*$|^>[[:space:]]*$|Ready for input'
WAIT_TIMEOUT=900
WAIT_INTERVAL=5
WAIT_DONE_FILE=""
READ_LINES=160
PROOF_FILE=""
ROOT_PANE=""
WORKSPACE_ID=""
WORKSPACE_CREATED=0
SESSION_STARTED=0
COORDINATOR_STARTED=0

usage() {
	sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'
}

log() {
	line="$(date -u +%Y-%m-%dT%H:%M:%SZ) supervisor $*"
	printf '%s\n' "$line" >>"$LOG_FILE"
	printf '%s\n' "$line"
}

herdr() {
	"$HERDR_BIN" --session "$SESSION" "$@"
}

herdr_available() {
	command -v "$HERDR_BIN" >/dev/null 2>&1
}

session_state() {
	herdr_available || return 2
	status_json="$(herdr status --json server 2>/dev/null)" || return 2
	printf '%s\n' "$status_json" | python3 -c '
import json, sys
try:
    payload = json.load(sys.stdin)
    running = payload["running"]
except (KeyError, TypeError, ValueError):
    raise SystemExit(2)
if not isinstance(running, bool):
    raise SystemExit(2)
print("running" if running else "stopped")
'
}

session_live() {
	state="$(session_state 2>/dev/null)" || return 1
	[ "$state" = "running" ]
}

coordinator_live() {
	session_live && herdr agent get "$COORDINATOR_AGENT" >/dev/null 2>&1
}

json_path() {
	# json_path dot.separated.path; JSON arrives on stdin.
	python3 -c '
import json, sys
value = json.load(sys.stdin)
for key in sys.argv[1].split("."):
    value = value[int(key)] if isinstance(value, list) else value[key]
print(value)
' "$1"
}

state_py() {
	python3 "$REPO/tools/state.py" "$@"
}

state_facts() {
	python3 - "$REPO" <<'PY'
import os, sys, time
repo = sys.argv[1]
sys.path.insert(0, os.path.join(repo, "tools"))
os.environ.setdefault("PYTHONDONTWRITEBYTECODE", "1")
import state  # noqa: E402
if not os.environ.get("ECOSYSTEM_STORE", "").strip():
    state.RUN_DIR = os.path.join(repo, "run")
    state.LOG_PATH = os.path.join(state.RUN_DIR, "events.jsonl")
    state.LOCK_PATH = os.path.join(state.RUN_DIR, "events.lock")
snapshot = state.project(state.read_events())
done = [task for task, row in snapshot["tasks"].items() if row["status"] == "done"]
print("done_count\t%d" % len(done))
for task in sorted(done):
    print("done\t%s" % task)
for task, lease in sorted(snapshot["leases"].items()):
    live = "expired" if lease["expires_at"] <= int(time.time()) else "live"
    print("lease\t%s\t%s\t%s\t%s\t%s" % (
        task, lease["token"], lease["expires_at"], lease.get("owner", ""), live))
PY
}

done_count() {
	state_facts | awk -F'\t' '$1 == "done_count" { print $2 }'
}

done_ids() {
	state_facts | awk -F'\t' '$1 == "done" { print $2 }'
}

container_names() {
	if command -v "$DOCKER_BIN" >/dev/null 2>&1; then
		"$DOCKER_BIN" ps --format '{{.Names}}' 2>/dev/null || true
	fi
}

task_has_container() {
	file="$REPO/tasks/$1/container.txt"
	[ -s "$file" ] || return 1
	container="$(sed -n '1p' "$file")"
	[ -n "$container" ] || return 1
	container_names | grep -Fxq -- "$container" 2>/dev/null
}

task_has_herdr_runner() {
	task="$1"
	session_live || return 1
	agent_file="$REPO/tasks/$task/herdr-agent.txt"
	if [ -s "$agent_file" ]; then
		agent="$(sed -n '1p' "$agent_file")"
		expected_agent="$(printf '%s' "$task" | tr '[:upper:]' '[:lower:]')"
		if [ "$agent" = "$expected_agent" ]; then
			agent_info="$(herdr agent get "$agent" 2>/dev/null || true)"
			actual="$(printf '%s\n' "$agent_info" | json_path result.agent.name 2>/dev/null || true)"
			[ "$actual" = "$agent" ] && return 0
		fi
	fi
	pane_file="$REPO/tasks/$task/herdr-pane.txt"
	if [ -s "$pane_file" ]; then
		pane="$(sed -n '1p' "$pane_file")"
		[ -n "$pane" ] && pane_matches_task_runner "$task" "$pane" && return 0
	fi
	return 1
}

pane_matches_task_runner() {
	task="$1"
	pane="$2"
	info="$(herdr pane process-info --pane "$pane" 2>/dev/null)" || return 1
	HERDR_PROCESS_INFO="$info" python3 - "$task" "$REPO/tasks/$task/task.toml" <<'PY'
import json, os, re, sys, tomllib

task, task_file = sys.argv[1:]
try:
    payload = json.loads(os.environ["HERDR_PROCESS_INFO"])
    with open(task_file, "rb") as handle:
        runtime = str(tomllib.load(handle).get("runtime", "")).lower()
except (OSError, ValueError, KeyError, json.JSONDecodeError):
    raise SystemExit(1)

def process_list(value):
    if isinstance(value, dict):
        processes = value.get("foreground_processes")
        if isinstance(processes, list):
            return processes
        for nested in value.values():
            found = process_list(nested)
            if found is not None:
                return found
    return None

marker = "task-" + task.lower()
marker_pattern = re.compile(r"(?<![a-z0-9_-])" + re.escape(marker) + r"(?![a-z0-9_-])")
known = {"claude", "codex", "jackin"}
for process in process_list(payload) or []:
    fields = [process.get("name"), process.get("argv0"), process.get("cmdline"), process.get("cwd")]
    fields.extend(process.get("argv") or [])
    text = " ".join(str(field) for field in fields if field).lower()
    if not marker_pattern.search(text):
        continue
    if runtime in {"claude", "codex"} and runtime in text:
        raise SystemExit(0)
    if runtime == "host" and any(name in text for name in known):
        raise SystemExit(0)
raise SystemExit(1)
PY
}

release_lease() {
	# $1 task, $2 fencing token, $3 reason.
	log "reconcile: releasing lease on $1 (token $2): $3"
	state_py event "$1" --operation "supervisor-reconcile-$3" \
		--key "supervisor-$1-$2-$3" --result "$3" >/dev/null 2>&1 || true
	state_py release "$1" --token "$2" >/dev/null 2>&1 ||
		log "reconcile: release of $1 was refused by the store"
}

reconcile() {
	preview="${1:-0}"
	if [ "$preview" -eq 1 ]; then
		log "reconcile preview: reading state; no event will be written"
	else
		log "reconcile: reading the run state"
	fi
	state_facts | while IFS="$(printf '\t')" read -r kind task token expires owner live; do
		[ "$kind" = "lease" ] || continue
		: "$expires" "$owner"
		if [ "$live" = "expired" ]; then
			if [ "$preview" -eq 1 ]; then
				log "reconcile preview: would release $task token $token (expired-ttl)"
			else
				release_lease "$task" "$token" "expired-ttl"
			fi
		elif task_has_container "$task" || task_has_herdr_runner "$task"; then
			log "reconcile: $task still has a live runner, lease kept"
		else
			if [ "$preview" -eq 1 ]; then
				log "reconcile preview: would release $task token $token (no-live-runner)"
			else
				release_lease "$task" "$token" "no-live-runner"
			fi
		fi
	done
}

assert_invariants() {
	before="$1"
	after="$(done_count)"
	if [ "$after" -lt "$before" ]; then
		log "failed-system: done count fell from $before to $after"
		return 1
	fi
	violated=""
	for task in $(done_ids); do
		if state_facts | awk -F'\t' -v task="$task" \
			'$1 == "lease" && $2 == task { found = 1 } END { exit !found }'; then
			violated="$violated $task"
		fi
	done
	if [ -n "$violated" ]; then
		log "failed-system: done task(s) hold a lease:$violated"
		return 1
	fi
	log "invariants hold: done $before -> $after, no done task leased"
}

process_cwd() {
	pid="$1"
	if [ -e "/proc/$pid/cwd" ]; then
		readlink "/proc/$pid/cwd" 2>/dev/null || true
	elif command -v lsof >/dev/null 2>&1; then
		lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | sed -n '1p'
	fi
}

legacy_coordinator_pids() {
	if [ -s "$LEGACY_PID_FILE" ]; then
		pid="$(sed -n '1p' "$LEGACY_PID_FILE")"
		case "$pid" in
		'' | *[!0-9]*) : ;;
		*) kill -0 "$pid" 2>/dev/null && printf '%s\n' "$pid" ;;
		esac
	fi
	# An unrecorded Claude whose cwd is this repository is also a legacy
	# coordinator when the named Herdr coordinator is not live.
	if ! coordinator_live && command -v pgrep >/dev/null 2>&1; then
		for pid in $(pgrep -x claude 2>/dev/null || true); do
			[ "$(process_cwd "$pid")" = "$REPO" ] && printf '%s\n' "$pid"
		done
	fi
}

refuse_legacy_runners() {
	old_pids="$(legacy_coordinator_pids | sort -u | tr '\n' ',' | sed 's/,$//')"
	if [ -n "$old_pids" ]; then
		log "failed-system: legacy coordinator process(es) detected: pids=$old_pids; stop them before Herdr kickoff"
		return 1
	fi
}

goal_command() {
	# README.md "Start the run" is the single source of truth (D-083).
	sed -n '/^\/goal Follow GOAL\.md\./{p;q;}' "$REPO/README.md"
}

print_kickoff() {
	goal="$1"
	log "Herdr session: $SESSION (isolated)"
	log "server command: $HERDR_BIN --session $SESSION server"
	log "workspace command: $HERDR_BIN --session $SESSION workspace create --cwd $REPO --label $SESSION --no-focus"
	if [ -n "$COORDINATOR_CMD" ]; then
		log "coordinator command: $HERDR_BIN --session $SESSION pane run <root-pane-id> $COORDINATOR_CMD"
	else
		log "Claude command: $HERDR_BIN --session $SESSION agent start $COORDINATOR_AGENT --kind claude --pane <root-pane-id> --timeout 120000 -- --dangerously-skip-permissions --settings '{\"skipDangerousModePermissionPrompt\":true}' --model claude-fable-5"
	fi
	log "goal command (copy/paste fallback): $goal"
	log "prompt command: $HERDR_BIN --session $SESSION agent prompt $COORDINATOR_AGENT '$goal'"
	log "attach command: $HERDR_BIN session attach $SESSION"
}

start_server() {
	: >"$HERDR_LOG"
	log "starting isolated Herdr session $SESSION"
	"$HERDR_BIN" --session "$SESSION" server >>"$HERDR_LOG" 2>&1 &
	server_pid=$!
	printf '%s\n' "$server_pid" >"$SERVER_PID_FILE"
	waited=0
	while ! session_live; do
		waited=$((waited + 1))
		if [ "$waited" -ge 30 ]; then
			log "failed-system: Herdr server did not become ready within 30s"
			kill -TERM "$server_pid" 2>/dev/null || true
			return 1
		fi
		if ! kill -0 "$server_pid" 2>/dev/null; then
			log "failed-system: Herdr server exited before becoming ready (see $HERDR_LOG)"
			return 1
		fi
		sleep 1
	done
	SESSION_STARTED=1
	log "Herdr server ready"
}

stored_pane() {
	[ -s "$PANE_FILE" ] || return 1
	ROOT_PANE="$(sed -n '1p' "$PANE_FILE")"
	[ -n "$ROOT_PANE" ] || return 1
	herdr pane get "$ROOT_PANE" >/dev/null 2>&1 || return 1
}

ensure_root_pane() {
	stored_pane 2>/dev/null && return 0
	created="$(herdr workspace create --cwd "$REPO" --label "$SESSION" --no-focus)"
	ROOT_PANE="$(printf '%s\n' "$created" | json_path result.root_pane.pane_id)"
	WORKSPACE_ID="$(printf '%s\n' "$created" | json_path result.workspace.workspace_id)"
	case "$ROOT_PANE" in
	'' | null) log "failed-system: Herdr did not return a root pane"; return 1 ;;
	esac
	case "$WORKSPACE_ID" in
	'' | null) log "failed-system: Herdr did not return a workspace"; return 1 ;;
	esac
	printf '%s\n' "$ROOT_PANE" >"$PANE_FILE"
	printf '%s\n' "$WORKSPACE_ID" >"$WORKSPACE_FILE"
	WORKSPACE_CREATED=1
}

start_coordinator() {
	pane="$1"
	goal="$2"
	if [ -n "$COORDINATOR_CMD" ]; then
		log "launch command: $HERDR_BIN --session $SESSION pane run $pane $COORDINATOR_CMD"
		herdr pane run "$pane" "$COORDINATOR_CMD" || return 1
		COORDINATOR_STARTED=1
		return 0
	fi
	log "launch command: $HERDR_BIN --session $SESSION agent start $COORDINATOR_AGENT --kind claude --pane $pane --timeout 120000 -- --dangerously-skip-permissions --settings '{\"skipDangerousModePermissionPrompt\":true}' --model claude-fable-5"
	if ! herdr agent start "$COORDINATOR_AGENT" --kind claude --pane "$pane" --timeout 120000 -- \
		--dangerously-skip-permissions \
		--settings '{"skipDangerousModePermissionPrompt":true}' \
		--model claude-fable-5; then
		if ! coordinator_live; then
			log "failed-system: Claude did not start in Herdr"
			return 1
		fi
		log "Claude is present but not ready; attach and inspect its interactive UI"
	fi
	COORDINATOR_STARTED=1
	log "prompt command: $HERDR_BIN --session $SESSION agent prompt $COORDINATOR_AGENT <exact README /goal line>"
	if herdr agent prompt "$COORDINATOR_AGENT" "$goal"; then
		log "submitted canonical /goal command to interactive Claude"
	else
		log "automatic /goal delivery failed; copy/paste the goal command printed above"
	fi
}

cleanup_partial_start() {
	reason="$1"
	log "cleanup: rolling back partial kickoff ($reason)"
	if [ "$WORKSPACE_CREATED" -eq 1 ] && session_live; then
		herdr workspace close "$WORKSPACE_ID" >/dev/null 2>&1 ||
			log "cleanup: could not close partial workspace $WORKSPACE_ID"
		rm -f "$PANE_FILE" "$WORKSPACE_FILE"
	fi
	if [ "$COORDINATOR_STARTED" -eq 1 ] && [ "$SESSION_STARTED" -eq 0 ] && coordinator_live; then
		herdr agent send-keys "$COORDINATOR_AGENT" ctrl+c >/dev/null 2>&1 ||
			log "cleanup: could not interrupt coordinator created in pre-existing session"
	fi
	if [ "$SESSION_STARTED" -eq 1 ] && session_live; then
		"$HERDR_BIN" session stop "$SESSION" --json >/dev/null 2>&1 ||
			log "cleanup: could not stop partial session $SESSION"
	fi
	rm -f "$SERVER_PID_FILE"
}

attach_session() {
	log "attaching interactive Herdr client; detach with Ctrl-b, then q"
	if ! "$HERDR_BIN" session attach "$SESSION"; then
		return 1
	fi
	log "Herdr client detached; session and Claude remain live"
}

require_goal() {
	GOAL="$(goal_command)"
	if [ -z "$GOAL" ]; then
		log "failed-system: README.md has no canonical /goal invocation"
		return 1
	fi
}

cmd_start() {
	require_goal
	print_kickoff "$GOAL"
	refuse_legacy_runners || return 2
	before="$(done_count)"
	if [ "$DRY_RUN" -eq 1 ]; then
		reconcile 1
		assert_invariants "$before"
		log "dry-run: reconciliation preview and commands printed; nothing launched or written"
		return 0
	fi
	herdr_available || {
		log "Herdr is not installed; install Herdr 0.8.2 before starting"
		return 2
	}
	if session_live; then
		log "session $SESSION is already live; use resume"
		return 1
	fi
	if ! start_server; then cleanup_partial_start "server start failed"; return 3; fi
	if ! reconcile 0 || ! assert_invariants "$before"; then
		cleanup_partial_start "reconciliation invariant failed"
		return 3
	fi
	if ! ensure_root_pane; then cleanup_partial_start "workspace creation failed"; return 3; fi
	if ! start_coordinator "$ROOT_PANE" "$GOAL"; then
		cleanup_partial_start "coordinator start failed"
		return 3
	fi
	if ! assert_invariants "$before"; then cleanup_partial_start "restart invariant failed"; return 3; fi
	if ! attach_session; then
		log "interactive attach failed; coordinator preserved; retry command: $HERDR_BIN session attach $SESSION"
		return 4
	fi
	if ! assert_invariants "$before"; then cleanup_partial_start "post-attach invariant failed"; return 3; fi
}

cmd_resume() {
	require_goal
	print_kickoff "$GOAL"
	refuse_legacy_runners || return 2
	before="$(done_count)"
	if [ "$DRY_RUN" -eq 1 ]; then
		reconcile 1
		assert_invariants "$before"
		log "dry-run: reconciliation preview and commands printed; nothing launched or written"
		return 0
	fi
	herdr_available || {
		log "Herdr is not installed; install Herdr 0.8.2 before resuming"
		return 2
	}
	if ! session_live; then
		if ! start_server; then cleanup_partial_start "server start failed"; return 3; fi
	fi
	if ! reconcile 0 || ! assert_invariants "$before"; then
		cleanup_partial_start "reconciliation invariant failed"
		return 3
	fi
	if coordinator_live; then
		log "coordinator already live; preserving the current turn"
	else
		if ! ensure_root_pane; then cleanup_partial_start "workspace creation failed"; return 3; fi
		log "coordinator absent; restarting from durable run state"
		if ! start_coordinator "$ROOT_PANE" "$GOAL"; then
			cleanup_partial_start "coordinator start failed"
			return 3
		fi
	fi
	if ! assert_invariants "$before"; then cleanup_partial_start "restart invariant failed"; return 3; fi
	if ! attach_session; then
		log "interactive attach failed; coordinator preserved; retry command: $HERDR_BIN session attach $SESSION"
		return 4
	fi
	if ! assert_invariants "$before"; then cleanup_partial_start "post-attach invariant failed"; return 3; fi
}

target_text() {
	target="$1"
	if herdr agent get "$target" >/dev/null 2>&1; then
		herdr agent read "$target" --source recent-unwrapped --lines "$READ_LINES"
	else
		herdr pane read "$target" --source recent-unwrapped --lines "$READ_LINES"
	fi
}

target_pane() {
	target="$1"
	if agent="$(herdr agent get "$target" 2>/dev/null)"; then
		printf '%s\n' "$agent" | json_path result.agent.pane_id
	elif herdr pane get "$target" >/dev/null 2>&1; then
		printf '%s\n' "$target"
	else
		return 1
	fi
}

done_file_ready() {
	[ -n "$WAIT_DONE_FILE" ] || return 1
	[ -f "$WAIT_DONE_FILE" ] || return 1
	[ "$(tail -n 1 "$WAIT_DONE_FILE" 2>/dev/null)" = "status: DONE" ]
}

wait_once() {
	deadline=$(($(date +%s) + WAIT_TIMEOUT))
	while [ "$(date +%s)" -lt "$deadline" ]; do
		done_file_ready && return 0
		pane="$(target_pane "$TARGET" 2>/dev/null)" || return 4
		# Herdr owns the wait and observes terminal output without consuming a
		# model turn. A bounded slice lets a done-file end the wait too.
		if herdr pane wait-output "$pane" --regex "$WAIT_PATTERN" \
			--source recent-unwrapped --lines "$READ_LINES" \
			--timeout "$((WAIT_INTERVAL * 1000))" >/dev/null 2>&1; then
			return 0
		fi
		target_pane "$TARGET" >/dev/null 2>&1 || return 4
	done
	return 3
}

cmd_wait() {
	[ -n "$TARGET" ] || {
		printf 'wait: --pane is required\n' >&2
		return 2
	}
	herdr_available || {
		printf 'wait: Herdr is not installed\n' >&2
		return 2
	}
	before="$(target_text "$TARGET" 2>/dev/null | tail -n 20 | cksum || true)"
	if wait_once; then rc=0; else rc=$?; fi
	if [ "$rc" -eq 3 ]; then
		after="$(target_text "$TARGET" 2>/dev/null | tail -n 20 | cksum || true)"
		if [ "$before" != "$after" ]; then
			log "wait $TARGET: budget spent, output still changing; extending once"
			if wait_once; then rc=0; else rc=$?; fi
		fi
	fi
	case "$rc" in
	0) log "wait $TARGET: ready" ;;
	3) log "wait $TARGET: stuck after budget, output no longer changing" ;;
	4) log "wait $TARGET: no such Herdr agent or pane" ;;
	esac
	return "$rc"
}

cmd_read() {
	target="${TARGET:-$COORDINATOR_AGENT}"
	herdr_available || {
		printf 'read: Herdr is not installed\n' >&2
		return 2
	}
	target_text "$target"
}

cmd_status() {
	printf 'session: %s\n' "$SESSION"
	printf 'coordinator agent: %s\n' "$COORDINATOR_AGENT"
	if session_live; then
		printf 'herdr: running\n'
		if coordinator_live; then
			printf 'coordinator: running\n'
		else
			printf 'coordinator: not running\n'
		fi
		herdr status --json server
	else
		printf 'herdr: not running\n'
		printf 'coordinator: not running\n'
	fi
	printf 'supervisor log: %s\n' "$LOG_FILE"
	printf 'herdr log: %s\n' "$HERDR_LOG"
	state_py status --json
}

cmd_stop() {
	if ! herdr_available; then
		log "Herdr is not installed; no session stopped"
		return 0
	fi
	if session_live; then
		"$HERDR_BIN" session stop "$SESSION" --json
		log "stopped Herdr session $SESSION and its pane processes"
	else
		log "no live Herdr session $SESSION to stop"
	fi
	# Keep the pane handle: Herdr restores stopped session topology, so resume
	# can reuse the same terminal instead of creating a duplicate workspace.
	rm -f "$SERVER_PID_FILE"
}

agent_identifiers() {
	# The name is the stable public identifier. An unnamed detected agent is
	# still active and is represented by its pane so it can never disappear
	# from a quiescence decision.
	python3 -c '
import json, sys
try:
    agents = json.load(sys.stdin)["result"]["agents"]
    if not isinstance(agents, list):
        raise TypeError
    values = []
    for agent in agents:
        if not isinstance(agent, dict):
            raise TypeError
        name = agent.get("name")
        pane = agent.get("pane_id")
        if isinstance(name, str) and name:
            values.append(name)
        elif isinstance(pane, str) and pane:
            values.append("pane:" + pane)
        else:
            raise TypeError
except (KeyError, TypeError, ValueError):
    raise SystemExit(2)
print("\n".join(sorted(set(values))))
'
}

pane_identifiers() {
	python3 -c '
import json, sys
try:
    panes = json.load(sys.stdin)["result"]["panes"]
    if not isinstance(panes, list):
        raise TypeError
    values = []
    for pane in panes:
        value = pane.get("pane_id") if isinstance(pane, dict) else None
        if not isinstance(value, str) or not value:
            raise TypeError
        values.append(value)
except (KeyError, TypeError, ValueError):
    raise SystemExit(2)
print("\n".join(sorted(set(values))))
'
}

pane_process_state() {
	# Print one of `active` or `idle`; malformed responses are probe failures.
	python3 -c '
import json, sys
try:
    info = json.load(sys.stdin)["result"]["process_info"]
    processes = info["foreground_processes"]
    if not isinstance(processes, list):
        raise TypeError
except (KeyError, TypeError, ValueError):
    raise SystemExit(2)
print("active" if processes else "idle")
'
}

write_quiescence_proof() {
	# $1 destination, $2 repository, $3 coordinator bool, $4 agents, $5 panes.
	PROOF_REPOSITORY="$2" PROOF_SESSION="$SESSION" \
		PROOF_COORDINATOR="$3" PROOF_AGENTS="$4" PROOF_PANES="$5" \
		python3 - "$1" <<'PY'
import json, os, sys, tempfile
from datetime import datetime, timezone

destination = os.path.abspath(sys.argv[1])
directory = os.path.dirname(destination)
if not os.path.isdir(directory):
    raise SystemExit("quiescence-proof: destination directory does not exist: " + directory)

payload = {
    "repository": os.path.realpath(os.environ["PROOF_REPOSITORY"]),
    "session": os.environ["PROOF_SESSION"],
    "coordinator_running": os.environ["PROOF_COORDINATOR"] == "true",
    "active_agents": sorted(set(filter(None, os.environ["PROOF_AGENTS"].splitlines()))),
    "active_panes": sorted(set(filter(None, os.environ["PROOF_PANES"].splitlines()))),
    "checked_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}

fd, temporary = tempfile.mkstemp(prefix=".quiescence-", suffix=".json", dir=directory)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, sort_keys=True, separators=(",", ":"))
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, destination)
    directory_fd = os.open(directory, os.O_RDONLY)
    try:
        os.fsync(directory_fd)
    finally:
        os.close(directory_fd)
except BaseException:
    try:
        os.unlink(temporary)
    except FileNotFoundError:
        pass
    raise
PY
}

cmd_quiescence_proof() {
	[ -n "$PROOF_FILE" ] || {
		printf 'quiescence-proof: FILE is required\n' >&2
		return 2
	}
	herdr_available || {
		printf 'quiescence-proof: Herdr is not installed; proof not written\n' >&2
		return 2
	}

	if ! current_session_state="$(session_state)"; then
		printf 'quiescence-proof: cannot query Herdr session %s; proof not written\n' "$SESSION" >&2
		return 2
	fi

	active_agents=""
	active_panes=""
	coordinator_running=false
	if [ "$current_session_state" = "running" ]; then
		if ! agents_json="$(herdr agent list 2>/dev/null)" ||
			! active_agents="$(printf '%s\n' "$agents_json" | agent_identifiers)"; then
			printf 'quiescence-proof: cannot list Herdr agents; proof not written\n' >&2
			return 2
		fi
		if printf '%s\n' "$active_agents" | grep -Fxq "$COORDINATOR_AGENT"; then
			coordinator_running=true
		fi
		if ! panes_json="$(herdr pane list 2>/dev/null)" ||
			! pane_ids="$(printf '%s\n' "$panes_json" | pane_identifiers)"; then
			printf 'quiescence-proof: cannot list Herdr panes; proof not written\n' >&2
			return 2
		fi
		for pane in $pane_ids; do
			if ! process_json="$(herdr pane process-info --pane "$pane" 2>/dev/null)" ||
				! process_state="$(printf '%s\n' "$process_json" | pane_process_state)"; then
				printf 'quiescence-proof: cannot inspect Herdr pane %s; proof not written\n' "$pane" >&2
				return 2
			fi
			if [ "$process_state" = "active" ]; then
				active_panes="${active_panes}${active_panes:+
}$pane"
			fi
		done
	fi

	for pid in $(legacy_coordinator_pids | sort -u); do
		active_agents="${active_agents}${active_agents:+
}legacy-pid:$pid"
	done
	active_agents="$(printf '%s\n' "$active_agents" | sed '/^$/d' | sort -u)"
	active_panes="$(printf '%s\n' "$active_panes" | sed '/^$/d' | sort -u)"

	write_quiescence_proof "$PROOF_FILE" "$REPO" "$coordinator_running" \
		"$active_agents" "$active_panes"
	if [ "$coordinator_running" = false ] &&
		[ -z "$active_agents" ] && [ -z "$active_panes" ]; then
		return 0
	fi
	printf 'quiescence-proof: active runner(s) found; proof is not quiescent\n' >&2
	return 1
}

COMMAND=""
while [ $# -gt 0 ]; do
	case "$1" in
	start | resume | status | stop | read | wait | watch | quiescence-proof) COMMAND="$1" ;;
	--pane)
		shift
		TARGET="${1:-}"
		;;
	--pattern)
		shift
		WAIT_PATTERN="${1:-}"
		;;
	--timeout)
		shift
		WAIT_TIMEOUT="${1:-900}"
		;;
	--interval)
		shift
		WAIT_INTERVAL="${1:-5}"
		;;
	--done-file)
		shift
		WAIT_DONE_FILE="${1:-}"
		;;
	--lines)
		shift
		READ_LINES="${1:-160}"
		;;
	--dry-run) DRY_RUN=1 ;;
	--coordinator-cmd)
		shift
		COORDINATOR_CMD="${1:-}"
		;;
	--session)
		shift
		SESSION="${1:-}"
		;;
	--repo)
		shift
		REPO="${1:-}"
		;;
	# Retained as no-ops for callers migrating from the external restart loop.
	--once) : ;;
	--max-restarts) shift; : "${1:-}" ;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		if [ "$COMMAND" = "quiescence-proof" ] && [ -z "$PROOF_FILE" ]; then
			PROOF_FILE="$1"
		else
			printf 'unknown argument: %s\n' "$1" >&2
			usage >&2
			exit 2
		fi
		;;
	esac
	shift
done

[ -n "$COMMAND" ] || {
	usage >&2
	exit 2
}

if [ -z "$REPO" ]; then
	REPO="$(cd "$(dirname "$0")/.." && pwd)"
fi

if [ "$COMMAND" = "quiescence-proof" ]; then
	REPO="$(cd "$REPO" && pwd -P)" || exit 2
	LOG_DIR="${ECOSYSTEM_RUN_DIR:-$REPO/run/logs}"
	LEGACY_PID_FILE="$LOG_DIR/coordinator.pid"
	cmd_quiescence_proof
	exit $?
fi

LOG_DIR="${ECOSYSTEM_RUN_DIR:-$REPO/run/logs}"
mkdir -p "$LOG_DIR"
SESSION_KEY="$(printf '%s' "$SESSION" | tr -c '[:alnum:]_.-' '_')"
LOG_FILE="$LOG_DIR/supervisor-$SESSION_KEY.log"
HERDR_LOG="$LOG_DIR/herdr-$SESSION_KEY.log"
PANE_FILE="$LOG_DIR/coordinator-$SESSION_KEY.pane"
WORKSPACE_FILE="$LOG_DIR/coordinator-$SESSION_KEY.workspace"
SERVER_PID_FILE="$LOG_DIR/herdr-server-$SESSION_KEY.pid"
LEGACY_PID_FILE="$LOG_DIR/coordinator.pid"
: >>"$LOG_FILE"

case "$COMMAND" in
start) cmd_start ;;
resume) cmd_resume ;;
status) cmd_status ;;
stop) cmd_stop ;;
read) cmd_read ;;
wait | watch) cmd_wait ;;
quiescence-proof) cmd_quiescence_proof ;;
esac
