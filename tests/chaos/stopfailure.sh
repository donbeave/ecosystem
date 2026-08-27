#!/bin/sh
# StopFailure and process-exit recovery (readiness plan 3.3).
#
# Compaction is not the only way a coordinator session ends. This rehearsal
# proves the other two: a session that dies after a rejected stop hook
# (`StopFailure`, a non-zero exit) and a session whose process simply
# disappears (SIGKILL, no message at all). In both cases the supervisor log
# must show that the exit was observed and that the run was resumed from the
# durable state, not from anything the dead session remembered.
#
# Everything happens under ECOSYSTEM_STORE in a temporary directory; the store
# of record is never touched.
#
# POSIX sh.

set -eu

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SEED="$REPO/tasks/CANARY-01/store-events.log"
CHAOS_TMP="${CHAOS_TMPDIR:-$(mktemp -d "${TMPDIR:-/tmp}/chaos-stop.XXXXXX")}"
TRANSCRIPT="$CHAOS_TMP/transcript.log"
FAILURES=0

say() {
	printf '%s chaos %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$TRANSCRIPT"
}

check() {
	if [ "$2" = "PASS" ]; then
		say "ASSERT PASS $1"
	else
		say "ASSERT FAIL $1"
		FAILURES=$((FAILURES + 1))
	fi
}

assert_log() {
	# $1 label, $2 pattern, $3 log file
	if grep -q -- "$2" "$3"; then
		check "$1" PASS
	else
		check "$1" FAIL
	fi
}

cleanup() {
	tmux kill-session -t chaos-stopfailure 2>/dev/null || true
	tmux kill-session -t chaos-sigkill 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# $1 session name, $2 coordinator script, $3 label
scenario() {
	session="$1"
	script="$2"
	label="$3"
	store="$CHAOS_TMP/$session/store"
	logs="$CHAOS_TMP/$session/logs"
	mkdir -p "$store" "$logs"
	head -5 "$SEED" >"$store/events.jsonl"
	tmux kill-session -t "$session" 2>/dev/null || true
	say "$label: supervising $script (restart budget 1)"
	ECOSYSTEM_STORE="$store" ECOSYSTEM_RUN_DIR="$logs" \
		"$REPO/tools/supervisor.sh" start --repo "$REPO" --session "$session" \
		--max-restarts 1 --coordinator-cmd "$script" >>"$TRANSCRIPT" 2>&1 || true
	say "$label: supervisor log"
	cat "$logs/supervisor.log" >>"$TRANSCRIPT"
	SUPLOG="$logs/supervisor.log"
}

scenario chaos-stopfailure "tests/chaos/fake_stopfailure.sh" "StopFailure"
assert_log "the StopFailure was observed" "observed StopFailure" "$SUPLOG"
assert_log "the non-zero exit was observed" "coordinator exited with code 1" "$SUPLOG"
assert_log "the session was restarted from durable state" \
	"resuming from durable state" "$SUPLOG"

scenario chaos-sigkill "tests/chaos/fake_sigkill.sh" "SIGKILL"
assert_log "the killed process's exit code was observed" \
	"coordinator exited with code 137" "$SUPLOG"
assert_log "the session was restarted from durable state" \
	"resuming from durable state" "$SUPLOG"
assert_log "no finished work was undone" "invariants hold" "$SUPLOG"

cleanup
say "tmux sessions created by this rehearsal are removed"

if [ "$FAILURES" -eq 0 ]; then
	say "status: DONE"
	exit 0
fi
say "status: FAIL ($FAILURES assertions failed)"
exit 1
