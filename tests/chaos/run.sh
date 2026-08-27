#!/bin/sh
# Destructive canary rehearsal (readiness plan 3.2).
#
# Drives tools/supervisor.sh with tests/chaos/fake_coordinator.sh against a
# temporary copy of the run-state store seeded with CANARY-01 leased and
# in-progress, and applies five failures in order:
#
#   (a) forced compaction  -- the coordinator is re-prompted: killed once and
#                             restarted by the supervisor
#   (b) coordinator killed -- tmux kill-session
#   (c) worker killed      -- docker kill chaos-CANARY-01
#   (d) lease expired      -- a lease with a 1s TTL, then a reconcile
#   (e) host restarted     -- tmux kill-server, the supervisor itself killed,
#                             its pid file removed, then supervisor.sh resume
#
# After the final resume the coordinator closes the canary from the evidence
# of the clean run, and a further resume must observe a `done` task and
# re-execute nothing. The rehearsal then asserts that no failure produced a
# duplicate side effect.
#
# The store of record (run/events.jsonl) is never touched: everything happens
# under ECOSYSTEM_STORE in a temporary directory.
#
# POSIX sh.

set -eu

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SESSION="chaos-coordinator"
CONTAINER="chaos-CANARY-01"
TASK="CANARY-01"
SEED="$REPO/tasks/CANARY-01/store-events.log"

CHAOS_TMP="${CHAOS_TMPDIR:-$(mktemp -d "${TMPDIR:-/tmp}/chaos-canary.XXXXXX")}"
ECOSYSTEM_STORE="$CHAOS_TMP/store"
ECOSYSTEM_RUN_DIR="$CHAOS_TMP/logs"
export ECOSYSTEM_STORE ECOSYSTEM_RUN_DIR
mkdir -p "$ECOSYSTEM_STORE" "$ECOSYSTEM_RUN_DIR"

SUP_LOG="$ECOSYSTEM_RUN_DIR/supervisor.log"
COORD_LOG="$ECOSYSTEM_RUN_DIR/coordinator.log"
TRANSCRIPT="$CHAOS_TMP/transcript.log"
COUNTER="$ECOSYSTEM_STORE/coordinator.runs"
FAILURES=0

# The supervisor's production backoff doubles from 5s and is capped at 300s,
# so by the fourth restart a fixed wait here would be racing a 40s sleep and
# by the sixth a 160s one. The rehearsal bounds it instead of guessing at it;
# the backoff path itself is still exercised, just on a short clock.
SUPERVISOR_BACKOFF_START=2
SUPERVISOR_BACKOFF_MAX=8
export SUPERVISOR_BACKOFF_START SUPERVISOR_BACKOFF_MAX

# Every wait below is a poll of an explicit condition with this budget. It is
# deliberately generous: nothing here is a sleep that assumes work is done.
WAIT_BUDGET="${CHAOS_WAIT_BUDGET:-240}"

say() {
	printf '%s chaos %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$TRANSCRIPT"
}

check() {
	# $1 label, $2 "PASS"/"FAIL"
	if [ "$2" = "PASS" ]; then
		say "ASSERT PASS $1"
	else
		say "ASSERT FAIL $1"
		FAILURES=$((FAILURES + 1))
	fi
}

assert() {
	# $1 label, then the command that must succeed
	label="$1"
	shift
	if "$@"; then
		check "$label" PASS
	else
		check "$label" FAIL
	fi
}

state_py() {
	python3 "$REPO/tools/state.py" "$@"
}

cleanup() {
	set +e
	[ -z "${SUP_PID:-}" ] || kill -TERM "$SUP_PID" 2>/dev/null
	tmux kill-session -t "$SESSION" 2>/dev/null
	docker rm -f "$CONTAINER" >/dev/null 2>&1
	set -e
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# seed: a temporary store with CANARY-01 leased and in-progress
# ---------------------------------------------------------------------------

say "store: $ECOSYSTEM_STORE (the run of record is untouched)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
tmux kill-session -t "$SESSION" 2>/dev/null || true

# The first five events of the clean canary run end exactly at `in-progress`
# under lease token 1; a prefix of a hash chain is itself a valid hash chain.
head -5 "$SEED" >"$ECOSYSTEM_STORE/events.jsonl"
state_py verify >>"$TRANSCRIPT" 2>&1
say "seeded $TASK as $(state_py status | python3 -c 'import json,sys; print(json.load(sys.stdin)["counts"])')"

# Poll one explicit condition until it holds or the budget is spent. The
# rehearsal never sleeps for a fixed period in the hope that something has
# happened; it names the condition it is waiting for.
wait_until() {
	# $1 description, then the command whose success is the condition
	what="$1"
	shift
	waited=0
	while ! "$@"; do
		if [ "$waited" -ge "$WAIT_BUDGET" ]; then
			say "timed out after ${WAIT_BUDGET}s waiting for $what"
			return 1
		fi
		sleep 1
		waited=$((waited + 1))
	done
	say "$what (after ${waited}s)"
}

# shellcheck disable=SC2329  # called indirectly through wait_until
run_count() {
	# The counter is append-only: one line per coordinator invocation. Its
	# line count can only grow, so no kill can make it read low.
	[ -f "$COUNTER" ] || { printf '0'; return; }
	wc -l <"$COUNTER" | tr -d ' '
}

# shellcheck disable=SC2329  # called indirectly through wait_until
run_reached() {
	[ "$(run_count)" -ge "$1" ]
}

wait_for_run() {
	# $1 run number
	wait_until "coordinator run $1" run_reached "$1"
}

# shellcheck disable=SC2329  # called indirectly through wait_until
container_running() {
	docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"
}

wait_for_container() {
	wait_until "worker container $CONTAINER running" container_running
}

# shellcheck disable=SC2329  # called indirectly through wait_until
session_running() {
	tmux has-session -t "$SESSION" 2>/dev/null
}

# shellcheck disable=SC2329  # called indirectly through wait_until
session_gone() {
	! tmux has-session -t "$SESSION" 2>/dev/null
}

# Kill the coordinator session, waiting for it to exist first: a kill issued
# while the supervisor is between restarts hits nothing, and the failure it is
# meant to inject never happens.
kill_coordinator() {
	wait_until "tmux session $SESSION" session_running || return 1
	tmux kill-session -t "$SESSION" 2>/dev/null || true
	wait_until "tmux session $SESSION gone" session_gone
}

# ---------------------------------------------------------------------------
# start
# ---------------------------------------------------------------------------

say "starting the supervisor"
"$REPO/tools/supervisor.sh" start --repo "$REPO" --session "$SESSION" \
	--max-restarts 20 --coordinator-cmd "tests/chaos/fake_coordinator.sh" \
	>>"$TRANSCRIPT" 2>&1 &
SUP_PID=$!
wait_for_run 1
wait_for_container

# (a) forced compaction -------------------------------------------------------
cat "$COORD_LOG" >>"$TRANSCRIPT" 2>/dev/null || true
say "(a) forced compaction: re-prompting the coordinator (kill + supervisor restart)"
kill_coordinator
wait_for_run 2

# (b) kill the coordinator ----------------------------------------------------
cat "$COORD_LOG" >>"$TRANSCRIPT" 2>/dev/null || true
say "(b) killing the coordinator session"
kill_coordinator
wait_for_run 3

# (c) kill the worker container -----------------------------------------------
cat "$COORD_LOG" >>"$TRANSCRIPT" 2>/dev/null || true
say "(c) killing the worker container $CONTAINER"
docker kill "$CONTAINER" >/dev/null
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
kill_coordinator
wait_for_run 4

# (d) expire the lease --------------------------------------------------------
cat "$COORD_LOG" >>"$TRANSCRIPT" 2>/dev/null || true
say "(d) expiring the lease: TTL 1s, then waiting for the store to call it expired"
state_py lease "$TASK" --owner "chaos-ttl" --ttl 1 >>"$TRANSCRIPT" 2>&1
# shellcheck disable=SC2329  # called indirectly through wait_until
lease_expired() {
	# The lease TTL is wall-clock: wait for the store itself to report the
	# lease as past its expiry rather than sleeping for the TTL and hoping.
	python3 - "$REPO" "$TASK" <<'LEASE'
import os, sys, time
repo, task = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(repo, "tools"))
import state  # noqa: E402
lease = state.project(state.read_events())["leases"].get(task)
sys.exit(0 if lease and lease["expires_at"] <= int(time.time()) else 1)
LEASE
}
wait_until "the lease on $TASK to read expired" lease_expired
kill_coordinator
wait_for_run 5

# a superseded agent tries to repeat its external mutation ---------------------
say "replaying a lease-holder event with the stale fencing token 1"
if state_py event "$TASK" --operation "github_pr" --attempt 99 --token 1 \
	--result "https://github.com/donbeave/ecosystem/pull/1" >>"$TRANSCRIPT" 2>&1; then
	check "stale fencing token 1 is rejected" FAIL
else
	check "stale fencing token 1 is rejected" PASS
fi

# (e) host restart ------------------------------------------------------------
say "(e) host restart: tmux kill-server, kill the supervisor, remove the pid file"
: >"$ECOSYSTEM_STORE/finish"
tmux kill-server 2>/dev/null || true
kill -TERM "$SUP_PID" 2>/dev/null || true
wait "$SUP_PID" 2>/dev/null || true
SUP_PID=""
rm -f "$ECOSYSTEM_RUN_DIR/coordinator.pid"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

say "re-invoking tools/supervisor.sh resume after the host restart"
"$REPO/tools/supervisor.sh" resume --repo "$REPO" --session "$SESSION" \
	--once --coordinator-cmd "tests/chaos/fake_coordinator.sh" \
	>>"$TRANSCRIPT" 2>&1 || true
cat "$COORD_LOG" >>"$TRANSCRIPT" 2>/dev/null || true

say "resuming once more: a done task must not be re-executed"
"$REPO/tools/supervisor.sh" resume --repo "$REPO" --session "$SESSION" \
	--once --coordinator-cmd "tests/chaos/fake_coordinator.sh" \
	>>"$TRANSCRIPT" 2>&1 || true
cat "$COORD_LOG" >>"$TRANSCRIPT" 2>/dev/null || true

# ---------------------------------------------------------------------------
# assertions
# ---------------------------------------------------------------------------

say "--- assertions ---"
cat "$SUP_LOG" >>"$TRANSCRIPT" 2>/dev/null || true
assert "the event chain is intact" state_py verify

FACTS="$(python3 - "$REPO" "$TASK" <<'PY'
import json, os, sys
repo, task = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(repo, "tools"))
import state  # noqa: E402
events = state.read_events()
snapshot = state.project(events)
inits = sum(1 for e in events if e.get("type") == "init"
            for t in e["tasks"] if t["id"] == task)
dones = sum(1 for e in events if e.get("type") == "transition"
            and e.get("task") == task and e.get("status") == "done")
rejected = [e for e in events if e.get("type") == "rejected"]
stale = [e for e in rejected if e.get("reason") == "stale fencing token"]
# an accepted event carrying the stale token after a higher token was issued
applied_stale = [e for e in events if e.get("type") == "event"
                 and e.get("task") == task and e.get("token") == 1
                 and e.get("seq", 0) > 5]
print(json.dumps({
    "inits": inits, "dones": dones, "status": snapshot["tasks"][task]["status"],
    "leases": len(snapshot["leases"]), "rejected": len(rejected),
    "stale_rejected": len(stale), "applied_stale": len(applied_stale),
}))
PY
)"
say "store facts: $FACTS"
val() { printf '%s' "$FACTS" | python3 -c "import json,sys; print(json.load(sys.stdin)['$1'])"; }

assert "the state store shows $TASK once" test "$(val inits)" = "1"
assert "exactly one done transition for $TASK" test "$(val dones)" = "1"
assert "$TASK is done" test "$(val status)" = "done"
assert "no lease outlives the run" test "$(val leases)" = "0"
assert "an audit event records the rejected stale fencing token" \
	test "$(val stale_rejected)" -ge 1
assert "no second lease-holder event applied after the stale one" \
	test "$(val applied_stale)" = "0"

PRS="$(cd "$REPO" && gh pr list --search 'canary: CANARY-01' --state all \
	--json number 2>/dev/null || printf '[]')"
PRCOUNT="$(printf '%s' "$PRS" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
say "gh pr list --search 'canary: CANARY-01' --state all --json number -> $PRS"
assert "exactly one pull request" test "$PRCOUNT" = "1"

say "Linear activity: blocked-on-human (PREFLIGHT-DEFECTS #4) -- op is not signed in,"
say "so no Linear mutation was attempted and none can have been duplicated"

assert "no done task re-executed" \
	grep -q "already done; no re-execution" "$TRANSCRIPT"
assert "the coordinator reached its terminal message" \
	grep -q "GOAL COMPLETE" "$TRANSCRIPT"
assert "(d) the expired lease was reconciled" \
	grep -q "reconcile: releasing lease on $TASK (token .*): expired-ttl" "$TRANSCRIPT"
assert "(c) the dead worker was reconciled" \
	grep -q "reconcile: releasing lease on $TASK (token .*): no-live-runner" "$TRANSCRIPT"
assert "(a)(b) the supervisor resumed from durable state" \
	grep -q "resuming from durable state" "$TRANSCRIPT"

cleanup
say "containers and tmux sessions created by this rehearsal are removed"

if [ "$FAILURES" -eq 0 ]; then
	say "status: DONE"
	exit 0
fi
say "status: FAIL ($FAILURES assertions failed)"
exit 1
