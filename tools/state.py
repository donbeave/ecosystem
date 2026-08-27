#!/usr/bin/env python3
"""Atomic append-only run-state store for the /goal run (D-098, D-100).

The authoritative state of the run is the event log `run/events.jsonl`: one
JSON object per line, appended with O_APPEND and fsync under a flock on
`run/events.lock`, so a crash between two writes can never leave a partial
transition. `tasks/README.md` and `PROGRESS.md` are generated projections of
that log and are never hand-edited.

Every event carries `prev`, the SHA-256 of the previous line, which makes the
log a hash chain that `verify` walks. Every external mutation carries an
idempotency key, sha256(run_id, task, attempt, operation); a replay of a key
already in the log is rejected. Every runnable task holds a lease with an
owner, a TTL, an epoch and a fencing token that increases monotonically per
task; an event submitted with a superseded token is rejected.

Python 3 standard library only.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import sys
import time
from datetime import datetime, timezone

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# `ECOSYSTEM_STORE` points the store at another directory, so a rehearsal --
# the canary of the readiness plan, a fixture, a test -- can exercise the real
# code against a copy of the log without touching the run of record. The two
# Markdown projections follow the store, because rendering them into the
# repository from a rehearsal log would corrupt the real projections.
STORE_DIR = os.environ.get("ECOSYSTEM_STORE", "").strip()
if STORE_DIR:
    RUN_DIR = os.path.abspath(STORE_DIR)
    LOG_PATH = os.path.join(RUN_DIR, "events.jsonl")
    LOCK_PATH = os.path.join(RUN_DIR, "events.lock")
    README_PATH = os.path.join(RUN_DIR, "tasks-README.md")
    PROGRESS_PATH = os.path.join(RUN_DIR, "PROGRESS.md")
    AUDIT_PATH = os.path.join(RUN_DIR, "M1-12-audit.md")
else:
    RUN_DIR = os.path.join(REPO, "run")
    LOG_PATH = os.path.join(RUN_DIR, "events.jsonl")
    LOCK_PATH = os.path.join(RUN_DIR, "events.lock")
    README_PATH = os.path.join(REPO, "tasks", "README.md")
    PROGRESS_PATH = os.path.join(REPO, "PROGRESS.md")
    AUDIT_PATH = os.path.join(REPO, "tasks", "M1-12", "audit.md")

GENESIS = "0" * 64

STATUSES = (
    "planned",
    "ready",
    "leased",
    "in-progress",
    "waiting",
    "resource-waiting",
    "blocked",
    "failed-system",
    "done",
)

# Statuses that do not allow a task to be dispatched. `done` is here too: a
# finished task is never dispatched again (a `runnable` list naming a `done`
# task would re-run it).
NOT_RUNNABLE = ("planned", "blocked", "waiting", "resource-waiting", "in-progress",
                "leased", "failed-system", "done")

# D-088: every M2+ task except these four waits for M1-12.
EARLY_START = ("M3-01", "M3-03", "M4-02", "M4-03")

# Concurrency caps of ROADMAP.md §3 / goal/EXECUTION.md §3 (D-056, D-071).
CAPS = {"containers": 6, "claude_containers": 2, "crew_operator": 1, "per_codex_lane": 1}
CODEX_LANES = ("L4", "L5", "L6")


# --------------------------------------------------------------------------
# log primitives
# --------------------------------------------------------------------------

def canonical(event: dict) -> str:
    return json.dumps(event, sort_keys=True, separators=(",", ":"))


def line_hash(line: str) -> str:
    return hashlib.sha256(line.encode("utf-8")).hexdigest()


def idempotency_key(run_id: str, task: str, attempt: int, operation: str) -> str:
    payload = "\x1f".join([str(run_id), str(task), str(attempt), str(operation)])
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class Lock:
    """flock around every read-modify-append cycle."""

    def __init__(self) -> None:
        os.makedirs(RUN_DIR, exist_ok=True)
        self.fd = os.open(LOCK_PATH, os.O_RDWR | os.O_CREAT, 0o644)

    def __enter__(self) -> "Lock":
        fcntl.flock(self.fd, fcntl.LOCK_EX)
        return self

    def __exit__(self, *exc) -> None:
        fcntl.flock(self.fd, fcntl.LOCK_UN)
        os.close(self.fd)


def read_events() -> list:
    if not os.path.exists(LOG_PATH):
        return []
    events = []
    with open(LOG_PATH, "r", encoding="utf-8") as handle:
        for raw in handle:
            raw = raw.strip()
            if raw:
                events.append(json.loads(raw))
    return events


def last_hash(events: list) -> str:
    if not events:
        return GENESIS
    return line_hash(canonical(events[-1]))


def append(events: list, event: dict) -> dict:
    """Append one event, chaining it to the current tail. Caller holds the lock."""
    event = dict(event)
    event["seq"] = len(events)
    event.setdefault("ts", now_iso())
    event["prev"] = last_hash(events)
    line = canonical(event) + "\n"
    fd = os.open(LOG_PATH, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
    try:
        os.write(fd, line.encode("utf-8"))
        os.fsync(fd)
    finally:
        os.close(fd)
    events.append(event)
    return event


def reject(events: list, reason: str, detail: dict) -> None:
    """Record the refusal in the log itself, then exit non-zero."""
    audit = {"type": "rejected", "reason": reason}
    audit.update(detail)
    append(events, audit)
    sys.stderr.write("REJECTED: %s\n" % reason)
    sys.exit(1)


# --------------------------------------------------------------------------
# projection
# --------------------------------------------------------------------------

def project(events: list) -> dict:
    """Replay the log into the current run state."""
    state = {
        "run_id": None,
        "tasks": {},        # id -> {milestone, depends_on, status, lane, ...}
        "order": [],
        "leases": {},       # id -> {owner, token, epoch, expires_at}
        "tokens": {},       # id -> highest fencing token issued
        "keys": set(),      # idempotency keys already accepted
        "progress": [],     # rendered PROGRESS.md rows
    }
    for event in events:
        kind = event.get("type")
        if kind == "init":
            state["run_id"] = event.get("run_id")
            for task in event["tasks"]:
                tid = task["id"]
                if tid not in state["tasks"]:
                    state["order"].append(tid)
                state["tasks"][tid] = {
                    "id": tid,
                    "milestone": task["milestone"],
                    "depends_on": list(task["depends_on"]),
                    "wave": task.get("wave"),
                    "status": task.get("status", "planned"),
                    "lane": "",
                    "attempt": 0,
                }
        elif kind == "transition":
            row = state["tasks"].get(event["task"])
            if row is None:
                continue
            row["status"] = event["status"]
            if event.get("lane"):
                row["lane"] = event["lane"]
            if event["status"] in ("done", "blocked", "waiting", "resource-waiting",
                                   "failed-system"):
                state["progress"].append({
                    "task": event["task"],
                    "lane": event.get("lane") or row.get("lane") or "—",
                    "path": event.get("path") or "—",
                    "result": event.get("result") or event["status"],
                    "evidence": event.get("evidence") or "—",
                    "when": event["ts"],
                })
        elif kind == "lease":
            state["tokens"][event["task"]] = event["token"]
            state["leases"][event["task"]] = {
                "owner": event["owner"],
                "token": event["token"],
                "epoch": event["epoch"],
                "expires_at": event["expires_at"],
            }
        elif kind == "release":
            state["leases"].pop(event["task"], None)
        if event.get("idempotency"):
            state["keys"].add(event["idempotency"])
    return state


def require_fresh_token(state: dict, events: list, task: str, token) -> None:
    """A token below the highest one ever issued for the task is superseded."""
    if token is None:
        return
    current = state["tokens"].get(task)
    if current is not None and int(token) < int(current):
        reject(events, "stale fencing token",
               {"task": task, "token": int(token), "current": int(current)})


# --------------------------------------------------------------------------
# rendering
# --------------------------------------------------------------------------

README_HEADER = """# Tasks

Index of every task with its status (D-038). This file is a generated
projection of the run-state store `run/events.jsonl` and is never
hand-edited: `python3 tools/state.py render` rewrites it from the log, so a
hand edit is silently discarded at the next render (D-098). An agent
starting a task reads this file, then its task folder, and works only on
that task; the host session, the only writer of this repository, records the
status change as an event and re-renders (`goal/EXECUTION.md` §5, D-086).

Statuses: `planned`, `ready`, `leased` (a fencing token is held, D-100),
`in-progress`, `waiting` (every lane of the chain throttled, D-071),
`resource-waiting` (a cap, not a lane, is the constraint), `blocked`
(missing operator input or exhausted, D-070; only a row with its own open
`PREFLIGHT-DEFECTS.md` row is ever `blocked` — dependents stay `ready` and
are simply not runnable, D-084; an `exhausted:` row stays `blocked` until
the human fills its `Resolved` cell, D-093), `failed-system` (the
infrastructure, not the task, failed), `done` — lowercase, exactly these.
The root `verify.sh` (D-069) parses this table by the `Task` and `Status`
header names, reads the task id from the `Task` cell (a link is fine), and
requires `done` plus an existing `tasks/<id>/verify.sh` for every id in
`ROADMAP.md`. Columns may be added (for example the Linear URL from M1-12);
these two must stay.

| Task | Milestone | Depends on | Status |
| --- | --- | --- | --- |
"""

PROGRESS_HEADER = """# Progress

Ledger of the `/goal` run (`GOAL.md`). One row per finished, blocked, or
waiting task. This file is a generated projection of the run-state store
`run/events.jsonl` and is never hand-edited: `python3 tools/state.py render`
rewrites it from the log (D-098). There is no authoring run to record: all
81 bundles are materialised before the run starts (D-114).
Attempts (`n/limit`, the exhaustion counter of D-070, never reset within an
epoch: a resume after a crash keeps the count, and only the closing of an
`exhausted:` row at a session start opens a new epoch, recorded as `epoch 2:
0/3`, D-084), lane fallbacks and quota hops (D-057, D-071), `re-sync`
re-launches, and `prompt landed: file` go into the result cell, never into
separate rows; the lane cell names where the work actually ran
(`L4 → L1 (host)`).

| Task | Lane | Path | Result | Evidence | When (UTC) |
| --- | --- | --- | --- | --- | --- |
"""


def render(state: dict) -> None:
    rows = []
    for tid in state["order"]:
        row = state["tasks"][tid]
        depends = ", ".join(row["depends_on"]) if row["depends_on"] else "—"
        rows.append("| %s | %s | %s | %s |\n"
                    % (tid, row["milestone"], depends, row["status"]))
    with open(README_PATH, "w", encoding="utf-8") as handle:
        handle.write(README_HEADER)
        handle.writelines(rows)

    prows = ["| %s | %s | %s | %s | %s | %s |\n"
             % (p["task"], p["lane"], p["path"], p["result"], p["evidence"], p["when"])
             for p in state["progress"]]
    with open(PROGRESS_PATH, "w", encoding="utf-8") as handle:
        handle.write(PROGRESS_HEADER)
        handle.writelines(prows)


# --------------------------------------------------------------------------
# runnable predicate (goal/EXECUTION.md §3, GOAL.md "Task loop")
# --------------------------------------------------------------------------

def runnable(state: dict) -> list:
    """Runnable: every depends_on row is `done`; the row is not `planned`; for
    M2+ ids other than the four early-start ids, M1-12 is `done` (D-088); and
    the caps allow it."""
    tasks = state["tasks"]
    m112_done = tasks.get("M1-12", {}).get("status") == "done"
    running = [r for r in tasks.values()
               if r["status"] in ("in-progress", "leased")]
    used_lanes = [r["lane"] for r in running if r["lane"]]
    out = []
    for tid in state["order"]:
        row = tasks[tid]
        if row["status"] in NOT_RUNNABLE:
            continue
        if any(tasks.get(d, {}).get("status") != "done" for d in row["depends_on"]):
            continue
        milestone = row["milestone"]
        if milestone != "M1" and tid not in EARLY_START and not m112_done:
            continue
        if len(running) >= CAPS["containers"]:
            continue
        if row["lane"] in CODEX_LANES and used_lanes.count(row["lane"]) >= \
                CAPS["per_codex_lane"]:
            continue
        out.append(tid)
    return out


# --------------------------------------------------------------------------
# subcommands
# --------------------------------------------------------------------------

def load_dag(path: str) -> dict:
    """Read the DAG JSON of `tools/roadmap_compile.py --json`. The compiler
    prints diagnostics after the object, so decode only the leading value."""
    with open(path, "r", encoding="utf-8") if path != "-" else sys.stdin as handle:
        data, _ = json.JSONDecoder().raw_decode(handle.read().lstrip())
    return data


BOOTSTRAP = "M1-01"

AUDIT_PASS_LINE = "audit: PASS"


def m1_audit_passed() -> bool:
    """The M1 exit audit of D-123.

    After the last M1 task turns `done`, the host session launches a fresh
    audit subagent that re-runs every M1 `tasks/<id>/verify.sh host`, checks
    the M1 exit gate, and writes `tasks/M1-12/audit.md` ending with the line
    `audit: PASS`. Until that file exists and ends with that line, no M2+ row
    may reach `ready`.

    The audit gates every M2+ id without exception. The four early-start ids
    of D-088 (M3-01, M3-03, M4-02, M4-03) are exempt from waiting for the
    M1-12 *row* to be `done`, because they only need the task bundles; they
    are not exempt from the audit, whose whole purpose is to prove that the
    M1 foundation the rest of the run stands on actually holds.
    """
    try:
        with open(AUDIT_PATH, "r", encoding="utf-8") as handle:
            lines = [line.strip() for line in handle if line.strip()]
    except OSError:
        return False
    return bool(lines) and lines[-1] == AUDIT_PASS_LINE


def promote(events: list, state: dict, only: str = None) -> list:
    """Arming and auto-promotion (D-119).

    A `planned` row is never dispatched, so something has to move it to
    `ready`. Wave 0 — every task whose `depends_on` is empty, i.e. M1-01 — is
    armed once by `arm`; afterwards every `done` transition promotes each
    `planned` task whose dependencies are all `done`. Both are idempotent:
    a row already past `planned` is left alone.

    Four ids are dependency-free in the compiled DAG (M1-01, M1-02, M10-02,
    M10-03), but D-072 makes M1-01 author every task bundle before any other
    task starts, so `arm` promotes M1-01 alone (`only`); the other three are
    promoted by the auto-promotion when M1-01 turns `done`.

    The M1 audit gate (D-123) is enforced here, and only here, because
    promotion is the sole way a row leaves `planned`: while
    `tasks/M1-12/audit.md` is missing or does not end with `audit: PASS`, no
    M2+ id is promoted, so none can ever be `ready` and none can satisfy the
    runnable predicate of §3. That covers `arm` (which promotes M1-01 alone)
    and the auto-promotion of `transition <id> done` alike.
    """
    tasks = state["tasks"]
    audit_ok = m1_audit_passed()
    promoted = []
    for tid in state["order"]:
        row = tasks[tid]
        if only is not None and tid != only:
            continue
        if row["status"] != "planned":
            continue
        if row["milestone"] != "M1" and not audit_ok:
            continue
        if any(tasks.get(d, {}).get("status") != "done" for d in row["depends_on"]):
            continue
        key = idempotency_key(state["run_id"], tid, 0, "promote")
        if key in state["keys"]:
            continue
        append(events, {"type": "transition", "task": tid, "status": "ready",
                        "lane": "", "path": "", "result": "promoted", "evidence": "",
                        "attempt": 0, "token": None, "idempotency": key})
        row["status"] = "ready"
        state["keys"].add(key)
        promoted.append(tid)
    return promoted


def cmd_arm(args) -> None:
    """Arm wave 0: the dependency-free seed task goes `planned` -> `ready`."""
    with Lock():
        events = read_events()
        promoted = promote(events, project(events), only=BOOTSTRAP)
        render(project(events))
    print("armed: %s" % (", ".join(promoted) if promoted else "nothing to arm"))


def cmd_init(args) -> None:
    dag = load_dag(args.dag)
    depends = {tid: [] for tid in dag["ids"]}
    for child, parent in dag["edges"]:
        if child in depends and parent not in depends[child]:
            depends[child].append(parent)
    tasks = [{
        "id": tid,
        "milestone": tid.split("-", 1)[0],
        "depends_on": sorted(depends[tid]),
        "wave": dag.get("waves", {}).get(tid),
        "status": "planned",
    } for tid in dag["ids"]]
    with Lock():
        events = read_events()
        state = project(events)
        key = idempotency_key(args.run_id, "*", 0, "init")
        if key in state["keys"]:
            reject(events, "duplicate idempotency key",
                   {"task": "*", "operation": "init", "idempotency": key})
        append(events, {"type": "init", "run_id": args.run_id, "idempotency": key,
                        "tasks": tasks})
        render(project(events))
    print("init: %d tasks seeded as planned" % len(tasks))


def cmd_transition(args) -> None:
    if args.status not in STATUSES:
        sys.stderr.write("unknown status: %s\n" % args.status)
        sys.exit(2)
    with Lock():
        events = read_events()
        state = project(events)
        if args.task not in state["tasks"]:
            sys.stderr.write("unknown task: %s\n" % args.task)
            sys.exit(2)
        require_fresh_token(state, events, args.task, args.token)
        key = args.key or idempotency_key(state["run_id"], args.task, args.attempt,
                                          "transition:" + args.status)
        if key in state["keys"]:
            reject(events, "duplicate idempotency key",
                   {"task": args.task, "operation": "transition", "idempotency": key})
        append(events, {"type": "transition", "task": args.task,
                        "status": args.status, "lane": args.lane or "",
                        "path": args.path or "", "result": args.result or "",
                        "evidence": args.evidence or "", "attempt": args.attempt,
                        "token": args.token, "idempotency": key})
        if args.status == "done":
            promote(events, project(events))
        render(project(events))
    print("%s -> %s" % (args.task, args.status))


def cmd_lease(args) -> None:
    with Lock():
        events = read_events()
        state = project(events)
        if args.task not in state["tasks"]:
            sys.stderr.write("unknown task: %s\n" % args.task)
            sys.exit(2)
        token = int(state["tokens"].get(args.task, 0)) + 1
        epoch = token
        expires_at = int(time.time()) + int(args.ttl)
        append(events, {"type": "lease", "task": args.task, "owner": args.owner,
                        "token": token, "epoch": epoch, "ttl": int(args.ttl),
                        "expires_at": expires_at})
    print(json.dumps({"task": args.task, "owner": args.owner, "token": token,
                      "epoch": epoch, "expires_at": expires_at}))


def cmd_release(args) -> None:
    with Lock():
        events = read_events()
        state = project(events)
        require_fresh_token(state, events, args.task, args.token)
        append(events, {"type": "release", "task": args.task, "token": args.token})
    print("released %s" % args.task)


def cmd_event(args) -> None:
    """Record one external mutation. Rejected on a duplicate key or a
    superseded fencing token (D-100)."""
    with Lock():
        events = read_events()
        state = project(events)
        require_fresh_token(state, events, args.task, args.token)
        key = args.key or idempotency_key(state["run_id"], args.task, args.attempt,
                                          args.operation)
        if key in state["keys"]:
            reject(events, "duplicate idempotency key",
                   {"task": args.task, "operation": args.operation, "idempotency": key})
        append(events, {"type": "event", "task": args.task,
                        "operation": args.operation, "attempt": args.attempt,
                        "token": args.token, "result": args.result or "",
                        "evidence": args.evidence or "", "idempotency": key})
    print("recorded %s/%s key=%s" % (args.task, args.operation, key[:12]))


def cmd_render(args) -> None:
    with Lock():
        render(project(read_events()))
    print("rendered tasks/README.md and PROGRESS.md")


def cmd_status(args) -> None:
    state = project(read_events())
    counts = {}
    for row in state["tasks"].values():
        counts[row["status"]] = counts.get(row["status"], 0) + 1
    print(json.dumps({
        "run_id": state["run_id"],
        "tasks": len(state["tasks"]),
        "counts": counts,
        "leases": state["leases"],
        "runnable": runnable(state),
    }, indent=2, sort_keys=True))


def cmd_runnable(args) -> None:
    for tid in runnable(project(read_events())):
        print(tid)


def cmd_verify(args) -> None:
    """Walk the hash chain; every event's `prev` must equal the hash of the
    line before it, and `seq` must be dense and ascending."""
    events = read_events()
    expected = GENESIS
    for index, event in enumerate(events):
        if event.get("seq") != index:
            print("status: FAIL seq %r at line %d" % (event.get("seq"), index + 1))
            sys.exit(1)
        if event.get("prev") != expected:
            print("status: FAIL broken chain at line %d" % (index + 1))
            sys.exit(1)
        expected = line_hash(canonical(event))
    print("events: %d, chain intact" % len(events))
    print("status: DONE")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("init", help="seed the store from the compiled DAG")
    p.add_argument("--dag", required=True, help="DAG JSON file, or - for stdin")
    p.add_argument("--run-id", default="goal-run-1")
    p.set_defaults(func=cmd_init)

    p = sub.add_parser("transition", help="change a task's status")
    p.add_argument("task")
    p.add_argument("status", choices=STATUSES)
    p.add_argument("--lane", default="")
    p.add_argument("--path", default="")
    p.add_argument("--result", default="")
    p.add_argument("--evidence", default="")
    p.add_argument("--attempt", type=int, default=1)
    p.add_argument("--token", type=int)
    p.add_argument("--key")
    p.set_defaults(func=cmd_transition)

    p = sub.add_parser("lease", help="take a lease, returning a fencing token")
    p.add_argument("task")
    p.add_argument("--owner", required=True)
    p.add_argument("--ttl", type=int, required=True)
    p.set_defaults(func=cmd_lease)

    p = sub.add_parser("release", help="drop a lease")
    p.add_argument("task")
    p.add_argument("--token", type=int)
    p.set_defaults(func=cmd_release)

    p = sub.add_parser("event", help="record one external mutation")
    p.add_argument("task")
    p.add_argument("--operation", required=True)
    p.add_argument("--attempt", type=int, default=1)
    p.add_argument("--token", type=int)
    p.add_argument("--result", default="")
    p.add_argument("--evidence", default="")
    p.add_argument("--key")
    p.set_defaults(func=cmd_event)

    sub.add_parser("arm", help="promote every dependency-free task to ready") \
        .set_defaults(func=cmd_arm)
    sub.add_parser("render", help="regenerate the two Markdown projections") \
        .set_defaults(func=cmd_render)
    p = sub.add_parser("status", help="print the run state as JSON")
    p.add_argument("--json", action="store_true", default=True,
                   help="JSON output (the only format)")
    p.set_defaults(func=cmd_status)
    sub.add_parser("runnable", help="print every runnable task id") \
        .set_defaults(func=cmd_runnable)
    sub.add_parser("verify", help="check the hash chain of the log") \
        .set_defaults(func=cmd_verify)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
