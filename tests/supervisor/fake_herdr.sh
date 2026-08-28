#!/bin/sh
# Stateful Herdr 0.8.2 CLI stub. It never launches Herdr or Claude.
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

line="session=$SESSION"
for arg in "$@"; do line="$line <$arg>"; done
printf '%s\n' "$line" >>"$ROOT/trace.log"

case "${1:-} ${2:-} ${3:-}" in
"session list --json")
	[ "${FAKE_HERDR_FAIL:-}" != "session-list" ] || exit 1
	python3 - "$ROOT" <<'PY'
import json, os, sys

root = sys.argv[1]
sessions = [{
    "name": "default",
    "default": True,
    "running": os.path.isfile(os.path.join(root, "default", "live")),
    "socket_path": os.path.join(root, "default", "herdr.sock"),
    "session_dir": os.path.join(root, "default"),
}]
for name in sorted(os.listdir(root)):
    directory = os.path.join(root, name)
    if name == "default" or not os.path.isdir(directory):
        continue
    sessions.append({
        "name": name,
        "default": False,
        "running": os.path.isfile(os.path.join(directory, "live")),
        "socket_path": os.path.join(directory, "herdr.sock"),
        "session_dir": directory,
    })
print(json.dumps({"sessions": sessions}, separators=(",", ":")))
PY
	;;
"status --json server")
	[ "${FAKE_HERDR_FAIL:-}" != "status" ] || exit 1
	if [ "${FAKE_HERDR_AUTOSTART_ON_STATUS:-0}" = 1 ]; then
		mkdir -p "$ROOT/default"
		touch "$ROOT/default/live" "$ROOT/auto-started"
	fi
	if [ -f "$STATE/live" ]; then running=true; status=running; else running=false; status=not_running; fi
	printf '{"status":"%s","running":%s,"session":"%s"}\n' "$status" "$running" "$SESSION"
	;;
"workspace create "*)
	[ -f "$STATE/live" ] || exit 1
	[ "${FAKE_HERDR_FAIL:-}" != "workspace-create" ] || exit 1
	touch "$STATE/pane"
	printf '{"result":{"workspace":{"workspace_id":"w1"},"tab":{"tab_id":"w1:t1"},"root_pane":{"pane_id":"w1:p1"}}}\n'
	;;
"pane get "*)
	[ -f "$STATE/pane" ] || exit 1
	printf '{"result":{"pane":{"pane_id":"w1:p1"}}}\n'
	;;
"pane list "*)
	[ -f "$STATE/live" ] || exit 1
	[ "${FAKE_HERDR_FAIL:-}" != "pane-list" ] || exit 1
	if [ -f "$STATE/pane" ]; then
		printf '{"result":{"type":"pane_list","panes":[{"pane_id":"w1:p1"}]}}\n'
	else
		printf '{"result":{"type":"pane_list","panes":[]}}\n'
	fi
	;;
"pane process-info "*)
	[ -f "$STATE/pane" ] || exit 1
	[ "${FAKE_HERDR_FAIL:-}" != "process-info" ] || exit 1
	cmdline="${FAKE_HERDR_PROCESS_CMDLINE:-jackin load the-architect task-M1-01 --agent claude}"
	if [ "${FAKE_HERDR_PANE_IDLE:-0}" = 1 ]; then
		printf '{"result":{"type":"pane_process_info","process_info":{"pane_id":"w1:p1","foreground_processes":[]}}}\n'
	else
		printf '{"result":{"type":"pane_process_info","process_info":{"pane_id":"w1:p1","foreground_processes":[{"pid":42,"name":"jackin","cmdline":"%s"}]}}}\n' "$cmdline"
	fi
	;;
"pane read "*)
	[ -f "$STATE/pane" ] || exit 1
	sed -n '1,240p' "$STATE/output" 2>/dev/null || true
	;;
"pane wait-output "*)
	[ -f "$STATE/pane" ] && [ -s "$STATE/output" ] || exit 1
	printf '{"result":{"pane_id":"w1:p1","matched_line":"Ready for input"}}\n'
	;;
"pane run "*)
	[ -f "$STATE/pane" ] || exit 1
	[ "${FAKE_HERDR_FAIL:-}" != "pane-run" ] || exit 1
	printf 'Ready for input\n' >"$STATE/output"
	printf '{"result":{"pane_id":"w1:p1"}}\n'
	;;
"agent start "*)
	[ -f "$STATE/pane" ] || exit 1
	[ "${FAKE_HERDR_FAIL:-}" != "agent-start" ] || exit 1
	touch "$STATE/agent"
	printf 'Ready for input\n' >"$STATE/output"
	printf '{"result":{"agent":{"name":"ecosystem-coordinator","pane_id":"w1:p1","status":"idle"}}}\n'
	;;
"agent get "*)
	[ -f "$STATE/agent" ] || exit 1
	printf '{"result":{"agent":{"name":"%s","pane_id":"w1:p1","status":"idle"}}}\n' "${3:-ecosystem-coordinator}"
	;;
"agent list "*)
	[ -f "$STATE/live" ] || exit 1
	[ "${FAKE_HERDR_FAIL:-}" != "agent-list" ] || exit 1
	if [ -f "$STATE/agent" ]; then
		printf '{"result":{"type":"agent_list","agents":[{"name":"ecosystem-coordinator","pane_id":"w1:p1","agent_status":"idle"}]}}\n'
	else
		printf '{"result":{"type":"agent_list","agents":[]}}\n'
	fi
	;;
"agent prompt "*)
	[ -f "$STATE/agent" ] || exit 1
	[ "${FAKE_HERDR_FAIL:-}" != "agent-prompt" ] || exit 1
	printf '%s\n' "${4:-}" >"$STATE/prompt"
	printf 'Ready for input\n' >"$STATE/output"
	printf '{"result":{"agent":{"name":"ecosystem-coordinator","status":"working"}}}\n'
	;;
"agent read "*)
	[ -f "$STATE/agent" ] || exit 1
	sed -n '1,240p' "$STATE/output" 2>/dev/null || true
	;;
"agent send-keys "*)
	[ -f "$STATE/agent" ] || exit 1
	rm -f "$STATE/agent"
	printf '{"result":{"sent":true}}\n'
	;;
"server  ")
	[ "${FAKE_HERDR_FAIL:-}" != "server" ] || exit 1
	touch "$STATE/live"
	printf '%s\n' "$$" >"$STATE/server.pid"
	trap 'rm -f "$STATE/live"; exit 0' INT TERM
	while [ -f "$STATE/live" ]; do sleep 1; done
	;;
"session attach "*)
	# Ungrouped session commands carry the name after the verb.
	[ "${FAKE_HERDR_FAIL:-}" != "attach" ] || exit 1
	printf 'fixture: attached %s\n' "${3:-$SESSION}"
	;;
"session stop "*)
	STOP_SESSION="${3:?missing stop session}"
	STOP_STATE="$ROOT/$STOP_SESSION"
	rm -f "$STOP_STATE/live" "$STOP_STATE/agent" "$STOP_STATE/pane"
	printf '{"result":{"stopped":true,"session":"%s"}}\n' "$STOP_SESSION"
	;;
"workspace close "*)
	rm -f "$STATE/agent" "$STATE/pane"
	printf '{"result":{"closed":true}}\n'
	;;
*)
	printf 'fake_herdr: unsupported command:' >&2
	printf ' <%s>' "$@" >&2
	printf '\n' >&2
	exit 2
	;;
esac
