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

wait_for_run() {
	# $1 run number, $2 timeout seconds
	waited=0
	while [ "$(cat "$COUNTER" 2>/dev/null || printf '0')" -lt "$1" ]; do
		if [ "$waited" -ge "$2" ]; then
			say "timed out waiting for coordinator run $1"
			return 1
		fi
		sleep 2
		waited=$((waited + 2))
	done
	say "coordinator run $1 observed"
}

wait_for_container() {
	waited=0
	while ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; do
		if [ "$waited" -ge 60 ]; then
			say "timed out waiting for $CONTAINER"
			return 1
		fi
		sleep 2
		waited=$((waited + 2))
	done
	say "worker container $CONTAINER is running"
}

# ---------------------------------------------------------------------------
# start
# ---------------------------------------------------------------------------

say "starting the supervisor"
"$REPO/tools/supervisor.sh" start --repo "$REPO" --session "$SESSION" \
	--max-restarts 20 --coordinator-cmd "tests/chaos/fake_coordinator.sh" \
	>>"$TRANSCRIPT" 2>&1 &
SUP_PID=$!
wait_for_run 1 90
wait_for_container

# (a) forced compaction -------------------------------------------------------
cat "$COORD_LOG" >>"$TRANSCRIPT" 2>/dev/null || true
say "(a) forced compaction: re-prompting the coordinator (kill + supervisor restart)"
tmux kill-session -t "$SESSION"
wait_for_run 2 120

# (b) kill the coordinator ----------------------------------------------------
cat "$COORD_LOG" >>"$TRANSCRIPT" 2>/dev/null || true
say "(b) killing the coordinator session"
tmux kill-session -t "$SESSION"
wait_for_run 3 120

# (c) kill the worker container -----------------------------------------------
cat "$COORD_LOG" >>"$TRANSCRIPT" 2>/dev/null || true
say "(c) killing the worker container $CONTAINER"
docker kill "$CONTAINER" >/dev/null
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
tmux kill-session -t "$SESSION" 2>/dev/null || true
wait_for_run 4 180

# (d) expire the lease --------------------------------------------------------
cat "$COORD_LOG" >>"$TRANSCRIPT" 2>/dev/null || true
say "(d) expiring the lease: TTL 1s, then sleeping 2s"
state_py lease "$TASK" --owner "chaos-ttl" --ttl 1 >>"$TRANSCRIPT" 2>&1
sleep 2
tmux kill-session -t "$SESSION" 2>/dev/null || true
wait_for_run 5 240

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
