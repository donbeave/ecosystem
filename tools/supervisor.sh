#!/bin/sh
# External supervisor for the /goal run (K-29, D-095 amended by D-120).
#
# The coordinator is a Claude Code session; a session dies with its process.
# This script lives outside that process: it starts the session, watches it
# exit, reconciles the durable state store after every exit, and starts the
# session again until the run reaches a terminal message. The authoritative
# state is run/events.jsonl (tools/state.py); this script never invents state,
# it only reconciles what the store says against what the host really runs.
#
#   tools/supervisor.sh start   [options]   start a run (fails if one is live)
#   tools/supervisor.sh resume  [options]   start or re-attach a run
#   tools/supervisor.sh status              print supervisor and run state
#   tools/supervisor.sh stop                stop the coordinator session
#   tools/supervisor.sh watch   [options]   block until a task pane is ready
#
# `watch` is how the coordinator waits for a container task without spending
# one model turn per poll (R3-52): the sleeping happens in this process.
#   --pane <name>               tmux session holding the task (required)
#   --pattern <ere>             pane text that means "ready" (default: a
#                               runtime input prompt)
#   --timeout <s>               budget in seconds (default 900, a cold build)
#   --interval <s>              seconds between captures (default 5)
#   --done-file <path>          also return as soon as this file's last line
#                               is `status: DONE`
# Exit: 0 ready, 3 stuck (budget spent, pane no longer changing), 4 the pane
# is gone. On expiry with a still-changing pane it extends itself once.
#
# Options:
#   --dry-run                   do everything except launching the coordinator
#   --coordinator-cmd <cmd>     run <cmd> instead of claude (tests)
#   --session <name>            tmux session name (default ecosystem-coordinator)
#   --max-restarts <n>          restarts per invocation (default 10)
#   --once                      supervise exactly one coordinator run
#   --repo <path>               repository root (default: this script's parent)
#
# POSIX sh; shellcheck clean.

set -eu

SESSION="ecosystem-coordinator"
DRY_RUN=0
ONCE=0
MAX_RESTARTS=10
COORDINATOR_CMD=""
REPO=""
LEASE_OWNER="supervisor"

usage() {
	sed -n '2,37p' "$0" | sed 's/^# \{0,1\}//'
}

log() {
	printf '%s supervisor %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$LOG_FILE"
	printf '%s supervisor %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

# ---------------------------------------------------------------------------
# state store access (tools/state.py is the only writer of run/events.jsonl)
# ---------------------------------------------------------------------------

# Print the facts this script needs, one `key<TAB>value` line per fact:
#   done_count <n>
#   done <task id>
#   lease <task id> <token> <expires_at> <owner>
state_facts() {
	python3 - "$REPO" <<'PY'
import json, os, sys, time
repo = sys.argv[1]
sys.path.insert(0, os.path.join(repo, "tools"))
os.environ.setdefault("PYTHONDONTWRITEBYTECODE", "1")
import state  # noqa: E402
# `ECOSYSTEM_STORE` already points state.py at a rehearsal store; overriding
# the paths here would silently drag a rehearsal back onto the run of record.
# Only bind the store to --repo when no rehearsal store is set.
if not os.environ.get("ECOSYSTEM_STORE", "").strip():
    state.RUN_DIR = os.path.join(repo, "run")
    state.LOG_PATH = os.path.join(state.RUN_DIR, "events.jsonl")
    state.LOCK_PATH = os.path.join(state.RUN_DIR, "events.lock")
snapshot = state.project(state.read_events())
done = [t for t, row in snapshot["tasks"].items() if row["status"] == "done"]
print("done_count\t%d" % len(done))
for task in sorted(done):
    print("done\t%s" % task)
now = int(time.time())
for task, lease in sorted(snapshot["leases"].items()):
    print("lease\t%s\t%s\t%s\t%s\t%s" % (
        task, lease["token"], lease["expires_at"],
        lease.get("owner", ""), "expired" if lease["expires_at"] <= now else "live"))
print("now\t%d" % now)
sys.stdout.flush()
_ = json
PY
}

state_py() {
	python3 "$REPO/tools/state.py" "$@"
}

done_count() {
	state_facts | awk -F'\t' '$1 == "done_count" { print $2 }'
}

done_ids() {
	state_facts | awk -F'\t' '$1 == "done" { print $2 }'
}

# ---------------------------------------------------------------------------
# reconciliation
# ---------------------------------------------------------------------------

container_names() {
	if command -v docker >/dev/null 2>&1; then
		docker ps --format '{{.Names}}' 2>/dev/null || true
	fi
}

task_has_container() {
	container_names | grep -q -- "$1" 2>/dev/null
}

task_has_tmux() {
	command -v tmux >/dev/null 2>&1 && tmux has-session -t "$1" 2>/dev/null
}

release_lease() {
	# $1 task, $2 token, $3 reason
	log "reconcile: releasing lease on $1 (token $2): $3"
	state_py event "$1" --operation "supervisor-reconcile-$3" \
		--key "supervisor-$1-$2-$3" --result "$3" >/dev/null 2>&1 || true
	state_py release "$1" --token "$2" >/dev/null 2>&1 ||
		log "reconcile: release of $1 was refused by the store"
}

reconcile() {
	log "reconcile: reading the run state"
	state_facts | while IFS="$(printf '\t')" read -r kind task token expires owner live; do
		[ "$kind" = "lease" ] || continue
		: "$expires" "$owner"
		if [ "$live" = "expired" ]; then
			release_lease "$task" "$token" "expired-ttl"
			continue
		fi
		if task_has_container "$task" || task_has_tmux "$task"; then
			log "reconcile: $task still has a live runner, lease kept"
		else
			release_lease "$task" "$token" "no-live-runner"
		fi
	done
	log "reconcile: done tasks: $(done_count)"
}

# ---------------------------------------------------------------------------
# invariants (a supervisor restart must never undo finished work)
# ---------------------------------------------------------------------------

assert_invariants() {
	# $1 the done count observed before the coordinator ran
	before="$1"
	after="$(done_count)"
	if [ "$after" -lt "$before" ]; then
		log "failed-system: done count fell from $before to $after"
		return 1
	fi
	violated=""
	for task in $(done_ids); do
		if state_facts | awk -F'\t' -v t="$task" '$1 == "lease" && $2 == t { found = 1 }
			END { exit !found }'; then
			violated="$violated $task"
		fi
	done
	if [ -n "$violated" ]; then
		log "failed-system: done task(s) leased again:$violated"
		return 1
	fi
	log "invariants hold: done $before -> $after, no done task leased"
	return 0
}

# ---------------------------------------------------------------------------
# the coordinator
# ---------------------------------------------------------------------------

coordinator_command() {
	if [ -n "$COORDINATOR_CMD" ]; then
		printf '%s' "$COORDINATOR_CMD"
		return
	fi
	# D-095 amended by D-120: YOLO mode. These are exactly the flags the
	# operator's `claude-yolo` zsh function expands to; they are spelled out
	# here so the script does not depend on any shell's functions.
	printf '%s' "claude --dangerously-skip-permissions --settings '{\"skipDangerousModePermissionPrompt\":true}' --model claude-fable-5 -p \"\$(cat GOAL.md)\""
}

terminal_reached() {
	grep -q -e 'GOAL COMPLETE' -e 'GOAL BLOCKED' "$RUN_LOG" 2>/dev/null
}

stop_failure_seen() {
	grep -q -e 'StopFailure' -e 'stop hook' "$RUN_LOG" 2>/dev/null
}

launch_coordinator() {
	command="$(coordinator_command)"
	if [ "$DRY_RUN" -eq 1 ]; then
		log "dry-run: would launch in tmux session $SESSION:"
		log "dry-run: cd $REPO && $command"
		return 0
	fi
	: >"$RUN_LOG"
	log "launching coordinator in tmux session $SESSION (log $RUN_LOG)"
	# The session runs the coordinator with its output teed to the run log and
	# its exit code written to a status file, so this process can observe both
	# without owning the terminal.
	# A tmux session inherits the *server's* environment, not this process's,
	# so a rehearsal store set only in this process would be invisible to the
	# coordinator and it would write to the run of record. Export it inline.
	env_prefix=""
	if [ -n "${ECOSYSTEM_STORE:-}" ]; then
		env_prefix="$env_prefix ECOSYSTEM_STORE='$ECOSYSTEM_STORE'"
	fi
	if [ -n "${ECOSYSTEM_RUN_DIR:-}" ]; then
		env_prefix="$env_prefix ECOSYSTEM_RUN_DIR='$ECOSYSTEM_RUN_DIR'"
	fi
	[ -z "$env_prefix" ] || env_prefix="export$env_prefix;"
	tmux new-session -d -s "$SESSION" \
		"cd $REPO && { $env_prefix $command; } >>$RUN_LOG 2>&1; printf '%s' \$? >$STATUS_FILE"
	printf '%s' "$SESSION" >"$PID_FILE"
	while tmux has-session -t "$SESSION" 2>/dev/null; do
		sleep 2
	done
	exit_code="$(cat "$STATUS_FILE" 2>/dev/null || printf 'unknown')"
	log "coordinator exited with code $exit_code"
	if stop_failure_seen; then
		log "observed StopFailure/stop hook in the coordinator log"
	fi
	return 0
}

supervise() {
	restarts=0
	backoff=5
	while :; do
		before="$(done_count)"
		reconcile
		launch_coordinator
		if [ "$DRY_RUN" -eq 1 ]; then
			log "dry-run: nothing was launched; state left untouched"
			return 0
		fi
		if ! assert_invariants "$before"; then
			log "rejecting the restart: invariant violated (failed-system)"
			return 3
		fi
		if terminal_reached; then
			log "terminal message observed; the run is over"
			return 0
		fi
		if [ "$ONCE" -eq 1 ]; then
			log "--once: not restarting"
			return 0
		fi
		restarts=$((restarts + 1))
		if [ "$restarts" -gt "$MAX_RESTARTS" ]; then
			log "restart budget of $MAX_RESTARTS exhausted; giving up"
			return 4
		fi
		log "no terminal message; resuming from durable state in ${backoff}s (restart $restarts)"
		sleep "$backoff"
		backoff=$((backoff * 2))
		[ "$backoff" -le 300 ] || backoff=300
	done
}

# ---------------------------------------------------------------------------
# watch: block until a task pane is ready, without model turns (R3-52)
# ---------------------------------------------------------------------------

# Default "the runtime is waiting for input" pattern: the Claude Code and
# Codex input boxes, and a bare shell prompt.
WATCH_PATTERN='(^│ *> |^> $|^╰─+╯|Ready for input|\$ $)'
WATCH_PANE=""
WATCH_TIMEOUT=900
WATCH_INTERVAL=5
WATCH_DONE_FILE=""

pane_text() {
	tmux capture-pane -p -S -200 -t "$WATCH_PANE" 2>/dev/null || return 1
}

done_file_ready() {
	[ -n "$WATCH_DONE_FILE" ] || return 1
	[ -f "$WATCH_DONE_FILE" ] || return 1
	[ "$(tail -n 1 "$WATCH_DONE_FILE" 2>/dev/null)" = "status: DONE" ]
}

# One budget of waiting. Returns 0 ready, 3 expired, 4 pane gone.
watch_once() {
	deadline=$(($(date +%s) + WATCH_TIMEOUT))
	while [ "$(date +%s)" -lt "$deadline" ]; do
		if ! tmux has-session -t "$WATCH_PANE" 2>/dev/null; then
			return 4
		fi
		if done_file_ready; then
			return 0
		fi
		if pane_text | grep -qE "$WATCH_PATTERN"; then
			return 0
		fi
		sleep "$WATCH_INTERVAL"
	done
	return 3
}

cmd_watch() {
	[ -n "$WATCH_PANE" ] || {
		printf 'watch: --pane is required\n' >&2
		exit 2
	}
	command -v tmux >/dev/null 2>&1 || {
		printf 'watch: tmux is not installed\n' >&2
		exit 2
	}
	before="$(pane_text | tail -n 20 | cksum || true)"
	# `set -e` would abort on a non-zero return, so every call is guarded.
	if watch_once; then rc=0; else rc=$?; fi
	if [ "$rc" -eq 3 ]; then
		after="$(pane_text | tail -n 20 | cksum || true)"
		if [ "$before" != "$after" ]; then
			# Still producing output (a cold `docker build` or `pull`):
			# extend exactly once, then the stuck rule applies.
			log "watch $WATCH_PANE: budget spent, pane still changing; extending once"
			if watch_once; then rc=0; else rc=$?; fi
		fi
	fi
	case "$rc" in
	0) log "watch $WATCH_PANE: ready" ;;
	3) log "watch $WATCH_PANE: stuck after the budget, pane no longer changing" ;;
	4) log "watch $WATCH_PANE: no such tmux session" ;;
	esac
	return "$rc"
}

cmd_status() {
	printf 'session: %s\n' "$SESSION"
	if command -v tmux >/dev/null 2>&1 && tmux has-session -t "$SESSION" 2>/dev/null; then
		printf 'coordinator: running\n'
	else
		printf 'coordinator: not running\n'
	fi
	printf 'log: %s\n' "$LOG_FILE"
	printf 'run log: %s\n' "$RUN_LOG"
	state_py status --json
}

cmd_stop() {
	if command -v tmux >/dev/null 2>&1 && tmux has-session -t "$SESSION" 2>/dev/null; then
		tmux kill-session -t "$SESSION"
		log "stopped tmux session $SESSION"
	else
		log "no tmux session $SESSION to stop"
	fi
	rm -f "$PID_FILE"
}

# ---------------------------------------------------------------------------
# argument parsing
# ---------------------------------------------------------------------------

COMMAND=""
while [ $# -gt 0 ]; do
	case "$1" in
	start | resume | status | stop | watch) COMMAND="$1" ;;
	--pane)
		shift
		WATCH_PANE="${1:-}"
		;;
	--pattern)
		shift
		WATCH_PATTERN="${1:-}"
		;;
	--timeout)
		shift
		WATCH_TIMEOUT="${1:-900}"
		;;
	--interval)
		shift
		WATCH_INTERVAL="${1:-5}"
		;;
	--done-file)
		shift
		WATCH_DONE_FILE="${1:-}"
		;;
	--dry-run) DRY_RUN=1 ;;
	--once) ONCE=1 ;;
	--coordinator-cmd)
		shift
		COORDINATOR_CMD="${1:-}"
		;;
	--session)
		shift
		SESSION="${1:-}"
		;;
	--max-restarts)
		shift
		MAX_RESTARTS="${1:-10}"
		;;
	--repo)
		shift
		REPO="${1:-}"
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		printf 'unknown argument: %s\n' "$1" >&2
		usage >&2
		exit 2
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

# Logs are host-local run artifacts, never repository content: they are
# written to `run/logs/`, which `.gitignore` ignores (D-059).
LOG_DIR="${ECOSYSTEM_RUN_DIR:-$REPO/run/logs}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/supervisor.log"
RUN_LOG="$LOG_DIR/coordinator.log"
STATUS_FILE="$LOG_DIR/coordinator.status"
PID_FILE="$LOG_DIR/coordinator.pid"
: >>"$LOG_FILE"
: >>"$RUN_LOG"
: "$LEASE_OWNER"

case "$COMMAND" in
status) cmd_status ;;
stop) cmd_stop ;;
watch)
	cmd_watch
	exit $?
	;;
start)
	if command -v tmux >/dev/null 2>&1 && tmux has-session -t "$SESSION" 2>/dev/null; then
		log "a coordinator session $SESSION is already live; use resume"
		exit 1
	fi
	log "start: repository $REPO"
	supervise
	;;
resume)
	log "resume: repository $REPO"
	if command -v tmux >/dev/null 2>&1 && tmux has-session -t "$SESSION" 2>/dev/null; then
		log "coordinator session $SESSION is live; nothing to resume"
		exit 0
	fi
	supervise
	;;
esac
