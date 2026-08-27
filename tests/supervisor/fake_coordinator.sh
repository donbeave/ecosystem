#!/bin/sh
# Simulated coordinator for the supervisor recovery test.
#
# First invocation: leases a task, marks it `done`, releases the lease, then
# sleeps until the test kills it — standing in for a coordinator that dies
# mid-run (process exit, StopFailure, dead tmux session, host restart).
# Second invocation: asserts the task is still `done` and holds no new lease,
# then prints the terminal message so the supervisor stops.
#
# Environment: FIXTURE_REPO (temporary repository copy), FIXTURE_TASK.

set -eu

REPO="${FIXTURE_REPO:?FIXTURE_REPO must be set}"
TASK="${FIXTURE_TASK:?FIXTURE_TASK must be set}"
STATE="python3 $REPO/tools/state.py"

status_of() {
	python3 - "$REPO" "$TASK" <<'PY'
import os, sys
repo, task = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(repo, "tools"))
import state  # noqa: E402
state.RUN_DIR = os.path.join(repo, "run")
state.LOG_PATH = os.path.join(state.RUN_DIR, "events.jsonl")
state.LOCK_PATH = os.path.join(state.RUN_DIR, "events.lock")
snapshot = state.project(state.read_events())
row = snapshot["tasks"].get(task)
print(row["status"] if row else "missing")
print("leased" if task in snapshot["leases"] else "unleased")
PY
}

FACTS="$(status_of)"
STATUS="$(printf '%s\n' "$FACTS" | sed -n 1p)"
LEASE="$(printf '%s\n' "$FACTS" | sed -n 2p)"

if [ "$STATUS" = "done" ]; then
	printf 'fixture: %s is still done after the restart\n' "$TASK"
	if [ "$LEASE" != "unleased" ]; then
		printf 'fixture: FAIL %s was leased again\n' "$TASK"
		exit 1
	fi
	printf 'fixture: PASS resumed without re-running a done task\n'
	printf 'GOAL COMPLETE\n'
	exit 0
fi

printf 'fixture: first run, taking %s to done\n' "$TASK"
$STATE lease "$TASK" --owner fixture --ttl 600 >/dev/null
TOKEN="$(python3 - "$REPO" "$TASK" <<'PY'
import os, sys
repo, task = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(repo, "tools"))
import state  # noqa: E402
state.RUN_DIR = os.path.join(repo, "run")
state.LOG_PATH = os.path.join(state.RUN_DIR, "events.jsonl")
state.LOCK_PATH = os.path.join(state.RUN_DIR, "events.lock")
print(state.project(state.read_events())["leases"][task]["token"])
PY
)"
$STATE transition "$TASK" "done" --token "$TOKEN" --result "fixture" >/dev/null
$STATE release "$TASK" --token "$TOKEN" >/dev/null
printf 'fixture: %s is done; now hanging until killed\n' "$TASK"
sleep 300
