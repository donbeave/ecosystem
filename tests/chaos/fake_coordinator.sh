#!/bin/sh
# Fake coordinator for the destructive canary rehearsal (readiness plan 3.2).
#
# It stands in for the Claude Code coordinator session: it leases the canary
# task, starts a real throwaway worker container, records the lease as a
# durable event, and then hangs until something kills it. Every invocation is
# a fresh process, exactly as a restarted session is, and every fact it needs
# comes from the state store, never from memory.
#
# When the marker file `finish` exists in the store directory the coordinator
# takes the closing path instead: it reads the canary's status and, only if
# the task is not already `done`, marks it done from the evidence produced by
# the clean canary run, then prints the terminal message. A task already
# `done` is never re-executed.
#
# Environment: ECOSYSTEM_STORE (the rehearsal store; also the scratch
# directory of this rehearsal). The repository is located from this script.

set -eu

STORE="${ECOSYSTEM_STORE:?ECOSYSTEM_STORE must be set}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TASK="CANARY-01"
CONTAINER="chaos-$TASK"
COUNTER="$STORE/coordinator.runs"
FINISH="$STORE/finish"

say() {
	printf '%s coordinator %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

state_py() {
	python3 "$REPO/tools/state.py" "$@"
}

# Print `<status>` and `<leased|unleased>` and `<token>` on three lines.
facts() {
	python3 - "$REPO" "$TASK" <<'PY'
import os, sys
repo, task = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(repo, "tools"))
import state  # noqa: E402
snapshot = state.project(state.read_events())
row = snapshot["tasks"].get(task)
print(row["status"] if row else "missing")
print("leased" if task in snapshot["leases"] else "unleased")
print(snapshot["tokens"].get(task, 0))
PY
}

RUNS=$(( $(cat "$COUNTER" 2>/dev/null || printf '0') + 1 ))
printf '%s' "$RUNS" >"$COUNTER"

FACTS="$(facts)"
STATUS="$(printf '%s\n' "$FACTS" | sed -n 1p)"
LEASE="$(printf '%s\n' "$FACTS" | sed -n 2p)"
TOKEN="$(printf '%s\n' "$FACTS" | sed -n 3p)"
say "run $RUNS: $TASK is $STATUS, $LEASE, highest token $TOKEN"

if [ -f "$FINISH" ]; then
	if [ "$STATUS" = "done" ]; then
		say "$TASK is already done; no re-execution"
		if [ "$LEASE" != "unleased" ]; then
			say "FAIL a done task holds a lease"
			exit 1
		fi
		say "GOAL COMPLETE"
		exit 0
	fi
	say "closing the canary from the evidence of the clean run"
	state_py lease "$TASK" --owner "chaos-integrator" --ttl 600 >/dev/null
	TOKEN="$(facts | sed -n 3p)"
	state_py transition "$TASK" "done" --token "$TOKEN" \
		--lane L0 --path "tests/chaos" \
		--result "canary closed after chaos" \
		--evidence "tasks/CANARY-01/evidence.json" >/dev/null
	state_py release "$TASK" --token "$TOKEN" >/dev/null
	say "$TASK -> done (evidence tasks/CANARY-01/evidence.json and tasks/CANARY-01/verify.out)"
	say "GOAL COMPLETE"
	exit 0
fi

if [ "$STATUS" = "done" ]; then
	say "$TASK is already done; no re-execution"
	say "GOAL COMPLETE"
	exit 0
fi

say "leasing $TASK"
state_py lease "$TASK" --owner "chaos-worker" --ttl 3600 >/dev/null
TOKEN="$(facts | sed -n 3p)"
say "lease taken with fencing token $TOKEN"

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
	say "worker container $CONTAINER already exists; reusing it"
	docker start "$CONTAINER" >/dev/null 2>&1 || true
else
	say "starting worker container $CONTAINER"
	docker run -d --name "$CONTAINER" \
		--label "chaos-rehearsal=CANARY-01" \
		alpine sleep 600 >/dev/null
fi

state_py event "$TASK" --operation "chaos-worker-start" --attempt "$RUNS" \
	--token "$TOKEN" --result "$CONTAINER" >/dev/null
say "recorded the lease-holder event for token $TOKEN"

say "in-progress; hanging until something kills me"
sleep 600
