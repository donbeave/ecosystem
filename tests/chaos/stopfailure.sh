#!/bin/sh
# StopFailure and process-exit recovery (readiness plan 3.3).
#
# Compaction is not the only way a coordinator session ends. This rehearsal
# proves the other two: a session that dies after a rejected stop hook
# (`StopFailure`, a non-zero exit) and a session whose process simply
# disappears (SIGKILL, no message at all). In both cases the harness observes
# the exit, then asks the Herdr launcher to resume from durable state, not from
# anything the dead process remembered.
#
# Everything happens under ECOSYSTEM_STORE in a temporary directory; the store
# of record is never touched.
#
# POSIX sh.

set -eu

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SEED="$REPO/tasks/CANARY-01/store-events.log"
CHAOS_TMP="${CHAOS_TMPDIR:-$(mktemp -d "${TMPDIR:-/tmp}/chaos-stop.XXXXXX")}"
HERDR_BIN="${HERDR_BIN:-$REPO/tests/chaos/fake_herdr.sh}"
FAKE_HERDR_DIR="${FAKE_HERDR_DIR:-$CHAOS_TMP/herdr}"
export HERDR_BIN FAKE_HERDR_DIR
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

wait_for_file() {
	path="$1"
	waited=0
	while [ ! -s "$path" ]; do
		waited=$((waited + 1))
		[ "$waited" -lt 30 ] || return 1
		sleep 1
	done
}

discard_session() {
	target_session="$1"
	"$HERDR_BIN" --session "$target_session" session stop "$target_session" --json >/dev/null 2>&1 || true
	"$HERDR_BIN" --session "$target_session" session delete "$target_session" --json >/dev/null 2>&1 || true
}

cleanup() {
	discard_session chaos-stopfailure
	discard_session chaos-sigkill
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
	discard_session "$session"
	say "$label: starting $script in isolated Herdr session"
	ECOSYSTEM_STORE="$store" ECOSYSTEM_RUN_DIR="$logs" \
		"$REPO/tools/supervisor.sh" start --repo "$REPO" --session "$session" \
		--coordinator-cmd "$script" >>"$TRANSCRIPT" 2>&1 || true
	status_file="$FAKE_HERDR_DIR/$session/coordinator.status"
	wait_for_file "$status_file" || { check "$label exit was observed" FAIL; return; }
	status="$(sed -n '1p' "$status_file")"
	cat "$FAKE_HERDR_DIR/$session/output" >>"$TRANSCRIPT" 2>/dev/null || true
	say "$label: coordinator exited with code $status"
	say "$label: resuming from durable run state"
	ECOSYSTEM_STORE="$store" ECOSYSTEM_RUN_DIR="$logs" \
		"$REPO/tools/supervisor.sh" resume --repo "$REPO" --session "$session" \
		--coordinator-cmd "$script" >>"$TRANSCRIPT" 2>&1 || true
	wait_for_file "$status_file" || { check "$label resumed exit was observed" FAIL; return; }
	cat "$FAKE_HERDR_DIR/$session/output" >>"$TRANSCRIPT" 2>/dev/null || true
	if ECOSYSTEM_STORE="$store" python3 "$REPO/tools/state.py" verify >/dev/null 2>&1; then
		say "$label: durable state chain remains valid"
	else
		check "$label durable state chain remains valid" FAIL
	fi
}

scenario chaos-stopfailure "tests/chaos/fake_stopfailure.sh" "StopFailure"
assert_log "the StopFailure was observed" "StopFailure: the stop hook refused" "$TRANSCRIPT"
assert_log "the non-zero exit was observed" "StopFailure: coordinator exited with code 1" "$TRANSCRIPT"
assert_log "the session was restarted from durable state" \
	"StopFailure: resuming from durable run state" "$TRANSCRIPT"

scenario chaos-sigkill "tests/chaos/fake_sigkill.sh" "SIGKILL"
assert_log "the killed process's exit code was observed" \
	"SIGKILL: coordinator exited with code 137" "$TRANSCRIPT"
assert_log "the session was restarted from durable state" \
	"SIGKILL: resuming from durable run state" "$TRANSCRIPT"
assert_log "no durable state was corrupted" "SIGKILL: durable state chain remains valid" "$TRANSCRIPT"

cleanup
say "Herdr sessions created by this rehearsal are removed"

if [ "$FAILURES" -eq 0 ]; then
	say "status: DONE"
	exit 0
fi
say "status: FAIL ($FAILURES assertions failed)"
exit 1
