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
	sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
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
	tmux new-session -d -s "$SESSION" \
		"cd $REPO && { $command; } >>$RUN_LOG 2>&1; printf '%s' \$? >$STATUS_FILE"
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
	start | resume | status | stop) COMMAND="$1" ;;
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
