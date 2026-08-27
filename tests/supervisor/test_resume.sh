#!/bin/sh
# Acceptance test for tools/supervisor.sh (row 1.12, K-29):
# "killing the coordinator process and re-invoking the supervisor resumes
#  without re-running a `done` task".
#
# The run is simulated end to end on a temporary copy of the state store, with
# tests/supervisor/fake_coordinator.sh standing in for the Claude coordinator.
#
#   sh tests/supervisor/test_resume.sh
#
# Last line is `status: DONE` on success.

set -eu

SRC="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/supervisor-test.XXXXXX")"
SESSION="supervisor-test-$$"
TASK="M1-01"
export ECOSYSTEM_RUN_DIR="$WORK/logs"

cleanup() {
	tmux kill-session -t "$SESSION" 2>/dev/null || true
	rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

mkdir -p "$WORK/tools" "$WORK/run" "$WORK/tasks" "$WORK/logs"
cp "$SRC/tools/state.py" "$WORK/tools/state.py"
cp "$SRC/tools/supervisor.sh" "$WORK/tools/supervisor.sh"
cp "$SRC/run/events.jsonl" "$WORK/run/events.jsonl"

FIXTURE="$SRC/tests/supervisor/fake_coordinator.sh"
export FIXTURE_REPO="$WORK"
export FIXTURE_TASK="$TASK"

fail() {
	printf '%s\n' "$1"
	printf 'status: FAIL\n'
	exit 1
}

done_count() {
	python3 - "$WORK" <<'PY'
import os, sys
repo = sys.argv[1]
sys.path.insert(0, os.path.join(repo, "tools"))
import state  # noqa: E402
snapshot = state.project(state.read_events())
print(sum(1 for r in snapshot["tasks"].values() if r["status"] == "done"))
PY
}

printf '== 1. dry run prints the exact coordinator command, launches nothing\n'
DRY="$(sh "$WORK/tools/supervisor.sh" resume --repo "$WORK" --session "$SESSION" --dry-run)"
printf '%s\n' "$DRY" | grep -q -- '--dangerously-skip-permissions' ||
	fail "dry-run did not print the claude command"
printf '%s\n' "$DRY" | grep -q -- '--model claude-fable-5' ||
	fail "dry-run did not print the model flag"
if tmux has-session -t "$SESSION" 2>/dev/null; then fail "dry-run started a session"; fi
printf 'dry-run ok\n'

printf '== 2. first run: the simulated coordinator takes %s to done, then hangs\n' "$TASK"
sh "$WORK/tools/supervisor.sh" resume --repo "$WORK" --session "$SESSION" \
	--coordinator-cmd "sh $FIXTURE" --max-restarts 2 >"$WORK/logs/first.out" 2>&1 &
SUPERVISOR_PID=$!

waited=0
while [ "$(done_count)" -lt 1 ]; do
	waited=$((waited + 1))
	[ "$waited" -lt 60 ] || fail "the fixture never reached done"
	sleep 1
done
BEFORE="$(done_count)"
printf 'done tasks before the kill: %s\n' "$BEFORE"

printf '== 3. kill the coordinator process\n'
tmux kill-session -t "$SESSION" 2>/dev/null || fail "no coordinator session to kill"

printf '== 4. the supervisor observes the exit and resumes from durable state\n'
waited=0
while kill -0 "$SUPERVISOR_PID" 2>/dev/null; do
	waited=$((waited + 1))
	[ "$waited" -lt 120 ] || fail "the supervisor never finished"
	sleep 1
done
wait "$SUPERVISOR_PID" || fail "the supervisor exited non-zero"

AFTER="$(done_count)"
[ "$AFTER" -ge "$BEFORE" ] || fail "the done count fell from $BEFORE to $AFTER"

grep -q 'coordinator exited with code' "$WORK/logs/supervisor.log" ||
	fail "the supervisor log does not record the observed exit"
grep -q 'resuming from durable state' "$WORK/logs/supervisor.log" ||
	fail "the supervisor log does not record the resume"
grep -q 'invariants hold' "$WORK/logs/supervisor.log" ||
	fail "the supervisor log does not record the invariant check"
grep -q 'PASS resumed without re-running a done task' "$WORK/logs/coordinator.log" ||
	fail "the fixture did not confirm the resume"
if grep -q 'first run, taking' "$WORK/logs/coordinator.log"; then
	fail "the second coordinator run re-ran the done task"
fi

python3 "$WORK/tools/state.py" verify | tail -1 | grep -q 'status: DONE' ||
	fail "the event log chain is broken"

printf 'done tasks after the resume: %s (was %s)\n' "$AFTER" "$BEFORE"
printf 'status: DONE\n'
