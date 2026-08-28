#!/bin/sh
# Stateful Herdr 0.8.2 stand-in for destructive recovery rehearsals.
# It runs the fake coordinator as an ordinary pane process, but never starts
# Herdr, Claude, or an interactive client on the host.
set -eu

ROOT="${FAKE_HERDR_DIR:?FAKE_HERDR_DIR must be set}"
mkdir -p "$ROOT"
SESSION="default"
if [ "${1:-}" = "--session" ]; then
	SESSION="${2:?missing session name}"
	shift 2
fi
STATE="$ROOT/$SESSION"
mkdir -p "$STATE"

{
	printf 'session=%s' "$SESSION"
	for arg in "$@"; do printf ' <%s>' "$arg"; done
	printf '\n'
} >>"$ROOT/trace.log"

process_live() {
	[ -s "$1" ] || return 1
	pid="$(sed -n '1p' "$1")"
	case "$pid" in '' | *[!0-9]*) return 1 ;; esac
	kill -0 "$pid" 2>/dev/null
}

process_tree() (
	parent="$1"
	for child in $(pgrep -P "$parent" 2>/dev/null || true); do
		process_tree "$child"
	done
	printf '%s\n' "$parent"
)

stop_process() {
	pid_file="$1"
	process_live "$pid_file" || return 0
	pid="$(sed -n '1p' "$pid_file")"
	pids="$(process_tree "$pid")"
	for process in $pids; do
		kill -TERM "$process" 2>/dev/null || true
	done
	waited=0
	while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 5 ]; do
		sleep 1
		waited=$((waited + 1))
	done
	for process in $pids; do
		kill -KILL "$process" 2>/dev/null || true
	done
}

case "${1:-} ${2:-} ${3:-}" in
"status --json server")
	[ -f "$STATE/live" ] || exit 1
	printf '{"result":{"running":true,"session":"%s"}}\n' "$SESSION"
	;;
"workspace create "*)
	[ -f "$STATE/live" ] || exit 1
	shift 2
	while [ $# -gt 0 ]; do
		case "$1" in
		--cwd) shift; printf '%s\n' "${1:?missing cwd}" >"$STATE/cwd" ;;
		esac
		shift
	done
	touch "$STATE/pane"
	printf '{"result":{"workspace":{"workspace_id":"w1"},"tab":{"tab_id":"w1:t1"},"root_pane":{"pane_id":"w1:p1"}}}\n'
	;;
"pane get "*)
	[ -f "$STATE/pane" ] || exit 1
	printf '{"result":{"pane":{"pane_id":"w1:p1"}}}\n'
	;;
"pane read "* | "agent read "*)
	[ -f "$STATE/pane" ] || exit 1
	sed -n '1,400p' "$STATE/output" 2>/dev/null || true
	;;
"pane run "*)
	[ -f "$STATE/pane" ] || exit 1
	command="${4:?missing pane command}"
	cwd="$(sed -n '1p' "$STATE/cwd")"
	: >"$STATE/output"
	rm -f "$STATE/coordinator.status"
	(
		cd "$cwd"
		set +e
		sh -c "$command" >>"$STATE/output" 2>&1
		printf '%s\n' "$?" >"$STATE/coordinator.status"
	) &
	printf '%s\n' "$!" >"$STATE/coordinator.pid"
	printf '{"result":{"pane_id":"w1:p1"}}\n'
	;;
"agent get "*)
	[ "${3:-}" = "ecosystem-coordinator" ] || exit 1
	process_live "$STATE/coordinator.pid" || exit 1
	printf '{"result":{"agent":{"name":"ecosystem-coordinator","pane_id":"w1:p1","status":"working"}}}\n'
	;;
"server  ")
	touch "$STATE/live"
	printf '%s\n' "$$" >"$STATE/server.pid"
	trap 'rm -f "$STATE/live"; exit 0' INT TERM
	while [ -f "$STATE/live" ]; do sleep 1; done
	;;
"session attach "*)
	printf 'fixture: attached %s\n' "${3:-$SESSION}"
	;;
"session stop "*)
	target="${3:?missing stop session}"
	target_state="$ROOT/$target"
	stop_process "$target_state/coordinator.pid"
	rm -f "$target_state/live" "$target_state/pane" "$target_state/coordinator.pid"
	printf '{"result":{"stopped":true,"session":"%s"}}\n' "$target"
	;;
"session delete "*)
	target="${3:?missing delete session}"
	target_state="$ROOT/$target"
	[ ! -f "$target_state/live" ] || exit 1
	rm -rf "$target_state"
	printf '{"result":{"deleted":true,"session":"%s"}}\n' "$target"
	;;
*)
	printf 'fake_herdr: unsupported command:' >&2
	printf ' <%s>' "$@" >&2
	printf '\n' >&2
	exit 2
	;;
esac
