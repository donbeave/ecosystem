#!/usr/bin/env python3
"""Atomic append-only run-state store for the /goal run (D-111, D-113).

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

`lock-epoch` parses and self-verifies `run/LOCK.toml`, then atomically binds
the state store to that exact identity. Epoch 1 can bootstrap a pre-feature
store without changing tasks. Later epochs refuse leases and require a fresh
supervisor quiescence proof before resetting interrupted work. One event holds
the prior lock, proof digest, fencing changes, and every task reset, providing
the complete forward and rollback audit without rewriting history.

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
import tomllib
from datetime import datetime, timezone

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# `ECOSYSTEM_STORE` points the store at another directory, so an isolated test
# can exercise the real code against a copy of the log without touching the run
# of record. The two
# Markdown projections follow the store, because rendering them into the
# repository from a rehearsal log would corrupt the real projections.
STORE_DIR = os.environ.get("ECOSYSTEM_STORE", "").strip()
if STORE_DIR:
    RUN_DIR = os.path.abspath(STORE_DIR)
    LOG_PATH = os.path.join(RUN_DIR, "events.jsonl")
    LOCK_PATH = os.path.join(RUN_DIR, "events.lock")
    README_PATH = os.path.join(RUN_DIR, "tasks-README.md")
    PROGRESS_PATH = os.path.join(RUN_DIR, "PROGRESS.md")
    AUDIT_PATH = os.path.join(RUN_DIR, "M1-12-audit.txt")
    ISSUE_MIRROR_PATH = os.path.join(RUN_DIR, "M1-12-issues.json")
else:
    RUN_DIR = os.path.join(REPO, "run")
    LOG_PATH = os.path.join(RUN_DIR, "events.jsonl")
    LOCK_PATH = os.path.join(RUN_DIR, "events.lock")
    README_PATH = os.path.join(REPO, "tasks", "README.md")
    PROGRESS_PATH = os.path.join(REPO, "PROGRESS.md")
    AUDIT_PATH = os.path.join(REPO, "tasks", "M1-12", "audit.txt")
    ISSUE_MIRROR_PATH = os.path.join(REPO, "tasks", "M1-12", "issues.json")

# Tests may pair an isolated event store with an isolated immutable lock. The
# override is deliberately ignored for the production store: readiness must
# always compare against this repository's real run/LOCK.toml.
RUN_LOCK_OVERRIDE = os.environ.get("ECOSYSTEM_RUN_LOCK", "").strip()
RUN_LOCK_PATH = os.path.abspath(
    RUN_LOCK_OVERRIDE if STORE_DIR and RUN_LOCK_OVERRIDE
    else os.path.join(REPO, "run", "LOCK.toml"))

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

# These statuses describe work that may have been interrupted when the run's
# immutable lock changes. They return to `ready` in the new lock epoch. A
# terminal, blocked, or not-yet-promoted task is preserved exactly.
INTERRUPTED_STATUSES = ("leased", "in-progress", "waiting", "resource-waiting")

# Host-authored transitions. `planned -> ready` belongs only to arm/promote;
# `ready -> leased` and `leased -> ready` belong only to lease/release.  Keeping
# those control-plane edges out of `transition` prevents a caller from bypassing
# either promotion or claim ownership.
LEGAL_TRANSITIONS = {
    "leased": ("in-progress", "blocked", "failed-system"),
    "in-progress": ("waiting", "resource-waiting", "ready", "blocked",
                    "failed-system", "done"),
    "waiting": ("in-progress", "ready", "blocked", "failed-system", "done"),
    "resource-waiting": ("ready",),
    "blocked": ("ready",),
    "planned": (),
    "ready": ("resource-waiting",),
    "failed-system": (),
    "done": (),
}

# Capacity bookkeeping is host-internal: it claims no worker or external
# resource, so these two edges neither require nor accept a task lease.
UNFENCED_INTERNAL_TRANSITIONS = {
    ("ready", "resource-waiting"),
    ("resource-waiting", "ready"),
}


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


def task_idempotency_key(state: dict, task: str, attempt: int, operation: str) -> str:
    """Default task-operation key, scoped to both restartable epochs."""
    row = state["tasks"].get(task, {})
    payload = "\x1f".join([
        str(state["run_id"]),
        str(state["lock_epoch"]),
        str(task),
        str(row.get("attempt_epoch", 1)),
        str(attempt),
        str(operation),
    ])
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def is_sha256(value: str) -> bool:
    return len(value) == 64 and all(char in "0123456789abcdefABCDEF" for char in value)


def lock_hash_of(text: str) -> str:
    """Match tools/lock.py: hash the lock text without its self-hash line."""
    # keepends=True is part of the lock format: tools/lock.py hashes the final
    # newline before `lock_hash`, not a normalized reconstruction of lines.
    payload = "".join(
        line for line in text.splitlines(keepends=True)
        if not line.lstrip().startswith("lock_hash")
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def read_run_lock_details() -> tuple[int, str, dict]:
    try:
        with open(RUN_LOCK_PATH, "r", encoding="utf-8") as handle:
            text = handle.read()
        data = tomllib.loads(text)
        run = data["run"]
        epoch = run["epoch"]
        recorded_hash = run["lock_hash"]
    except (OSError, KeyError, TypeError, tomllib.TOMLDecodeError) as exc:
        raise ValueError("cannot read [run].epoch and lock_hash: %s" % exc) from exc
    if not isinstance(epoch, int) or isinstance(epoch, bool) or epoch < 1:
        raise ValueError("[run].epoch is not a positive integer")
    if not isinstance(recorded_hash, str) or not is_sha256(recorded_hash):
        raise ValueError("[run].lock_hash is not 64 hexadecimal characters")
    recorded_hash = recorded_hash.lower()
    if lock_hash_of(text) != recorded_hash:
        raise ValueError("[run].lock_hash does not match file content")
    return epoch, recorded_hash, data


def read_run_lock() -> tuple[int, str]:
    epoch, recorded_hash, _ = read_run_lock_details()
    return epoch, recorded_hash


def read_quiescence_proof(path: str) -> dict:
    """Validate a fresh supervisor-produced proof and return its audit summary."""
    try:
        with open(path, "rb") as handle:
            raw = handle.read()
        proof = json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("cannot read quiescence proof: %s" % exc) from exc
    if not isinstance(proof, dict):
        raise ValueError("quiescence proof is not a JSON object")
    expected_repo = os.path.realpath(REPO)
    current_repo = os.path.realpath(os.getcwd())
    if current_repo != expected_repo:
        raise ValueError("lock epoch command cwd is not this repository")
    if os.path.realpath(str(proof.get("repository", ""))) != current_repo:
        raise ValueError("quiescence proof repository does not match this repository")
    if proof.get("session") != "ecosystem-coordinator":
        raise ValueError("quiescence proof session is not ecosystem-coordinator")
    if proof.get("coordinator_running") is not False:
        raise ValueError("quiescence proof reports a running coordinator")
    if proof.get("active_agents") != []:
        raise ValueError("quiescence proof reports active agents")
    if proof.get("active_panes") != []:
        raise ValueError("quiescence proof reports active panes")
    checked_at = proof.get("checked_at")
    if not isinstance(checked_at, str):
        raise ValueError("quiescence proof has no checked_at timestamp")
    try:
        checked = datetime.fromisoformat(checked_at.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError("quiescence proof checked_at is invalid") from exc
    if checked.tzinfo is None:
        raise ValueError("quiescence proof checked_at has no timezone")
    age = (datetime.now(timezone.utc) - checked.astimezone(timezone.utc)).total_seconds()
    if age < -30 or age > 300:
        raise ValueError("quiescence proof is not fresh (maximum age 300 seconds)")
    return {
        "proof_sha256": hashlib.sha256(raw).hexdigest(),
        "repository": expected_repo,
        "session": "ecosystem-coordinator",
        "coordinator_running": False,
        "active_agents": 0,
        "active_panes": 0,
        "checked_at": checked.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


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
        "lock_epoch": 0,
        "lock_hash": None,
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
                    "attempt_epoch": 1,
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
            # A task claim is the sole ready -> leased edge. Repository
            # integration leases are mutation-scoped and do not replace the
            # task's delivery status.
            row = state["tasks"].get(event["task"])
            if row is not None and row["status"] == "ready" and \
                    not str(event.get("owner", "")).startswith("integrator:"):
                row["status"] = "leased"
        elif kind == "release":
            state["leases"].pop(event["task"], None)
            row = state["tasks"].get(event["task"])
            if row is not None and row["status"] == "leased":
                row["status"] = "ready"
        elif kind == "lock_epoch":
            state["lock_epoch"] = event["epoch"]
            state["lock_hash"] = event["lock_hash"]
            for fence in event.get("fences", []):
                state["tokens"][fence["task"]] = fence["to_token"]
            for reset in event.get("resets", []):
                row = state["tasks"].get(reset["task"])
                if row is None:
                    continue
                row["status"] = reset["to_status"]
                row["attempt_epoch"] = reset["to_attempt_epoch"]
        if event.get("idempotency"):
            state["keys"].add(event["idempotency"])
    return state


def require_active_lease(state: dict, events: list, task: str, token,
                         allow_expired: bool = False) -> dict:
    """Require the exact active lease token, not merely a non-stale integer."""
    if token is None:
        reject(events, "missing fencing token", {"task": task, "token": None})
    lease = state["leases"].get(task)
    if lease is None:
        floor = state["tokens"].get(task)
        if floor is not None and int(token) < int(floor):
            reject(events, "stale fencing token",
                   {"task": task, "token": int(token), "current": int(floor)})
        reject(events, "task has no active lease",
               {"task": task, "token": int(token)})
    current = int(lease["token"])
    if int(token) != current:
        reject(events, "fencing token is not the active lease token",
               {"task": task, "token": int(token), "current": current})
    if not allow_expired and int(lease["expires_at"]) <= int(time.time()):
        reject(events, "active lease is expired",
               {"task": task, "token": current,
                "expires_at": int(lease["expires_at"])})
    return lease


# --------------------------------------------------------------------------
# rendering
# --------------------------------------------------------------------------

README_HEADER = """# Tasks

Index of every task with its status (D-038). This file is a generated
projection of the run-state store `run/events.jsonl` and is never
hand-edited: `python3 tools/state.py render` rewrites it from the log, so a
hand edit is silently discarded at the next render (D-111). An agent
starting a task reads this file, then its task folder, and works only on
that task; the host session, the only writer of this repository, records the
status change as an event and re-renders (`goal/EXECUTION.md` §5, D-086).

Statuses: `planned`, `ready`, `leased` (a fencing token is held, D-113),
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
rewrites it from the log (D-111). There is no authoring run to record: all
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
    M2+ ids other than the four early-start ids, M1-12 is `done` and the M1
    audit currently passes, its issue mirror exists; and the caps allow it."""
    tasks = state["tasks"]
    m112_done = tasks.get("M1-12", {}).get("status") == "done"
    audit_ok = m1_audit_passed(state)
    running = [r for r in tasks.values()
               if r["status"] in ("in-progress", "leased")]
    used_lanes = [r["lane"] for r in running if r["lane"]]
    out = []
    for tid in state["order"]:
        row = tasks[tid]
        # Lease acquisition is the atomic claim. Even before a caller records
        # the next delivery status, a claimed row cannot be dispatched twice.
        if tid in state["leases"]:
            continue
        if row["status"] in NOT_RUNNABLE:
            continue
        if any(tasks.get(d, {}).get("status") != "done" for d in row["depends_on"]):
            continue
        milestone = row["milestone"]
        if milestone != "M1" and tid not in EARLY_START and \
                (not m112_done or not audit_ok or not issue_mirror_has_task(tid)):
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


def text_artifact_sha256(path: str) -> str | None:
    try:
        with open(path, "rb") as handle:
            raw = handle.read()
        text = raw.decode("utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines or lines[-1] != "status: DONE":
        return None
    return hashlib.sha256(raw).hexdigest()


def issue_mirror_has_task(task_id: str) -> bool:
    """Require the task in both M1-12 reconciliation observations."""
    try:
        with open(ISSUE_MIRROR_PATH, "r", encoding="utf-8") as handle:
            snapshot = json.load(handle)
        passes = snapshot["passes"]
        if not isinstance(passes, list) or len(passes) != 2:
            return False
        return all(
            isinstance(item, dict) and
            sum(issue.get("task_id") == task_id
                for issue in item.get("issues", []) if isinstance(issue, dict)) == 1
            for item in passes
        )
    except (OSError, KeyError, TypeError, json.JSONDecodeError):
        return False


def m1_audit_passed(state: dict) -> bool:
    """The M1 exit audit of CTRL-006.

    After the last M1 task turns `done`, the host session launches a fresh
    audit subagent that re-runs every M1 `tasks/<id>/verify.sh host` and the M1
    exit gate. The audit binds their DONE transcripts and exact M1 bundle set
    to the current state and immutable lock epoch/hash. Until every binding
    matches and the final line is `audit: PASS`, no non-exempt M2+ row may
    reach `ready`. EARLY_START ids are exempt from M1-12 and audit gates.
    """
    try:
        lock_epoch, lock_hash, lock_data = read_run_lock_details()
        bundles = lock_data["bundles"]
        if not isinstance(bundles, dict):
            return False
        locked_m1 = {tid: value.lower() for tid, value in bundles.items()
                     if tid.startswith("M1-") and isinstance(value, str)
                     and is_sha256(value)}
        state_m1 = {tid for tid, row in state["tasks"].items()
                    if row["milestone"] == "M1"}
        if set(locked_m1) != state_m1 or not locked_m1:
            return False
        if any(state["tasks"][tid]["status"] != "done" for tid in state_m1):
            return False
        if (state["lock_epoch"], state["lock_hash"]) != (lock_epoch, lock_hash):
            return False
        artifact_dir = os.path.dirname(AUDIT_PATH)
        exit_sha = text_artifact_sha256(
            os.path.join(artifact_dir, "audit-exit-gate.out"))
        if exit_sha is None:
            return False
        expected = [
            "lock_epoch: %d" % lock_epoch,
            "lock_hash: %s" % lock_hash,
            "exit_gate_sha256: %s" % exit_sha,
        ]
        for tid in sorted(locked_m1):
            verify_sha = text_artifact_sha256(
                os.path.join(artifact_dir, "audit-%s.out" % tid))
            if verify_sha is None:
                return False
            expected.append("%s: bundle=%s verify=%s" %
                            (tid, locked_m1[tid], verify_sha))
        expected.append(AUDIT_PASS_LINE)
        with open(AUDIT_PATH, "r", encoding="utf-8") as handle:
            lines = [line.strip() for line in handle if line.strip()]
    except (OSError, KeyError, TypeError, ValueError, tomllib.TOMLDecodeError):
        return False
    return lines == expected


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

    The M1 audit gate (CTRL-006) is enforced here, and only here, because
    promotion is the sole way a row leaves `planned`: while
    `tasks/M1-12/audit.txt` is missing or does not end with `audit: PASS`, no
    non-exempt M2+ id is promoted. EARLY_START ids promote as soon as their
    dependencies are done. That covers `arm` (which promotes M1-01 alone),
    auto-promotion after `transition <id> done`, and explicit post-audit
    `promote` reconciliation.
    """
    tasks = state["tasks"]
    audit_ok = m1_audit_passed(state)
    promoted = []
    for tid in state["order"]:
        row = tasks[tid]
        if only is not None and tid != only:
            continue
        if row["status"] != "planned":
            continue
        if row["milestone"] != "M1" and tid not in EARLY_START and not audit_ok:
            continue
        if any(tasks.get(d, {}).get("status") != "done" for d in row["depends_on"]):
            continue
        key = task_idempotency_key(state, tid, 0, "promote")
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


def cmd_promote(args) -> None:
    """Promote every newly eligible task after an external gate changes."""
    with Lock():
        events = read_events()
        promoted = promote(events, project(events))
        render(project(events))
    print("promoted: %s" % (", ".join(promoted) if promoted else "nothing"))


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
        current_status = state["tasks"][args.task]["status"]
        if args.status not in LEGAL_TRANSITIONS.get(current_status, ()):
            reject(events, "illegal task transition", {
                "task": args.task,
                "from_status": current_status,
                "to_status": args.status,
            })
        edge = (current_status, args.status)
        if edge in UNFENCED_INTERNAL_TRANSITIONS:
            if args.task in state["leases"]:
                reject(events, "resource bookkeeping requires an unleased task", {
                    "task": args.task,
                    "from_status": current_status,
                    "to_status": args.status,
                })
            if args.token is not None:
                reject(events, "resource bookkeeping does not accept a fencing token", {
                    "task": args.task,
                    "from_status": current_status,
                    "to_status": args.status,
                    "token": args.token,
                })
        else:
            require_active_lease(state, events, args.task, args.token)
        key = args.key or task_idempotency_key(
            state, args.task, args.attempt,
            "transition:%s->%s" % (current_status, args.status))
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
        prior = state["leases"].get(args.task)
        if prior is not None:
            if prior["owner"] == args.owner and \
                    int(prior["expires_at"]) > int(time.time()):
                render(state)
                print(json.dumps({"task": args.task, "owner": prior["owner"],
                                  "token": prior["token"], "epoch": prior["epoch"],
                                  "expires_at": prior["expires_at"], "replayed": True}))
                return
            reject(events, "task already has an active lease", {
                "task": args.task,
                "owner": args.owner,
                "current_owner": prior["owner"],
                "current_token": prior["token"],
                "expires_at": prior["expires_at"],
            })
        status = state["tasks"][args.task]["status"]
        integration = args.owner.startswith("integrator:")
        if integration and (not args.owner[len("integrator:"):].strip() or
                            status != "in-progress"):
            reject(events, "integrator lease requires an in-progress task and repository", {
                "task": args.task, "owner": args.owner, "status": status,
            })
        if not integration and status not in (
                "ready", "in-progress", "waiting", "resource-waiting", "blocked"):
            reject(events, "task status cannot acquire a lease", {
                "task": args.task, "owner": args.owner, "status": status,
            })
        token = int(state["tokens"].get(args.task, 0)) + 1
        epoch = int(state["lock_epoch"])
        expires_at = int(time.time()) + int(args.ttl)
        append(events, {"type": "lease", "task": args.task, "owner": args.owner,
                        "token": token, "epoch": epoch, "ttl": int(args.ttl),
                        "expires_at": expires_at})
        render(project(events))
    print(json.dumps({"task": args.task, "owner": args.owner, "token": token,
                      "epoch": epoch, "expires_at": expires_at, "replayed": False}))


def cmd_release(args) -> None:
    with Lock():
        events = read_events()
        state = project(events)
        if args.task not in state["tasks"]:
            sys.stderr.write("unknown task: %s\n" % args.task)
            sys.exit(2)
        # A retry after the exact release reached durable storage is a safe
        # no-op. A lock-epoch fencing floor with no matching lease is not.
        lease = state["leases"].get(args.task)
        if lease is None and args.token is not None and any(
                event.get("type") == "release" and
                event.get("task") == args.task and
                event.get("token") == args.token for event in events):
            render(state)
            print("released %s (replayed)" % args.task)
            return
        require_active_lease(state, events, args.task, args.token,
                             allow_expired=args.expired)
        if args.expired:
            lease = state["leases"][args.task]
            if int(lease["expires_at"]) > int(time.time()):
                reject(events, "--expired requires an expired active lease", {
                    "task": args.task, "token": args.token,
                    "expires_at": int(lease["expires_at"]),
                })
            operation = "supervisor-reconcile-expired-ttl:%s" % args.token
            key = task_idempotency_key(state, args.task,
                                       state["tasks"][args.task].get("attempt", 0),
                                       operation)
            if key not in state["keys"]:
                append(events, {"type": "event", "task": args.task,
                                "operation": operation,
                                "attempt": state["tasks"][args.task].get("attempt", 0),
                                "token": args.token, "result": "expired-ttl",
                                "evidence": "", "idempotency": key})
        append(events, {"type": "release", "task": args.task, "token": args.token})
        render(project(events))
    print("released %s" % args.task)


def cmd_event(args) -> None:
    """Record one external mutation. Rejected on a duplicate key or a
    superseded fencing token (D-113)."""
    with Lock():
        events = read_events()
        state = project(events)
        require_active_lease(state, events, args.task, args.token)
        key = args.key or task_idempotency_key(
            state, args.task, args.attempt, args.operation)
        if key in state["keys"]:
            reject(events, "duplicate idempotency key",
                   {"task": args.task, "operation": args.operation, "idempotency": key})
        append(events, {"type": "event", "task": args.task,
                        "operation": args.operation, "attempt": args.attempt,
                        "token": args.token, "result": args.result or "",
                        "evidence": args.evidence or "", "idempotency": key})
    print("recorded %s/%s key=%s" % (args.task, args.operation, key[:12]))


def cmd_lock_epoch(args) -> None:
    """Bind the store to the next immutable run lock in one append.

    Retrying the same key with the same caller payload is a successful no-op.
    A reused key with different payload is an audited refusal. Epoch 1 can
    bootstrap a pre-feature store without changing task state. Every later
    reset requires a fresh machine-readable proof that the supervisor and all
    of its panes are stopped.
    """
    requested_hash = args.lock_hash.lower()
    with Lock():
        events = read_events()
        state = project(events)

        if not args.key.strip():
            reject(events, "lock epoch idempotency key is empty", {
                "operation": "lock-epoch",
                "requested_epoch": args.epoch,
                "requested_lock_hash": args.lock_hash,
            })

        if not is_sha256(args.lock_hash):
            reject(events, "lock hash is not 64 hexadecimal characters", {
                "operation": "lock-epoch",
                "requested_idempotency": args.key,
                "requested_epoch": args.epoch,
                "requested_lock_hash": args.lock_hash,
            })
        try:
            actual_epoch, actual_hash = read_run_lock()
        except ValueError as exc:
            reject(events, "run lock is invalid", {
                "operation": "lock-epoch",
                "requested_idempotency": args.key,
                "error": str(exc),
            })
        if args.epoch != actual_epoch or requested_hash != actual_hash:
            reject(events, "requested lock does not match run/LOCK.toml", {
                "operation": "lock-epoch",
                "requested_idempotency": args.key,
                "requested_epoch": args.epoch,
                "requested_lock_hash": requested_hash,
                "actual_epoch": actual_epoch,
                "actual_lock_hash": actual_hash,
            })

        prior = next((event for event in events
                      if event.get("idempotency") == args.key and
                      event.get("type") != "rejected"), None)
        if prior is not None:
            if (prior.get("type") == "lock_epoch" and
                    prior.get("epoch") == args.epoch and
                    prior.get("lock_hash") == requested_hash and
                    bool(prior.get("bootstrap")) == bool(args.bootstrap)):
                # The event may have reached durable storage just before a
                # crash in rendering. Repair either projection on retry.
                render(state)
                print(json.dumps({
                    "bootstrap": bool(prior.get("bootstrap")),
                    "epoch": prior["epoch"],
                    "lock_hash": prior["lock_hash"],
                    "reset_tasks": [item["task"] for item in prior.get("resets", [])],
                    "replayed": True,
                }, sort_keys=True))
                return
            reject(events, "conflicting duplicate idempotency key", {
                "operation": "lock-epoch",
                "requested_idempotency": args.key,
                "requested_bootstrap": bool(args.bootstrap),
                "requested_epoch": args.epoch,
                "requested_lock_hash": requested_hash,
                "existing_type": prior.get("type"),
                "existing_bootstrap": bool(prior.get("bootstrap")),
                "existing_epoch": prior.get("epoch"),
                "existing_lock_hash": prior.get("lock_hash"),
            })

        expected_epoch = int(state["lock_epoch"]) + 1
        if args.epoch != expected_epoch:
            reject(events, "lock epoch is not sequential", {
                "operation": "lock-epoch",
                "requested_idempotency": args.key,
                "requested_epoch": args.epoch,
                "current_epoch": state["lock_epoch"],
                "expected_epoch": expected_epoch,
            })
        if args.bootstrap and (state["lock_epoch"] != 0 or state["lock_hash"] is not None):
            reject(events, "bootstrap requires an unbound epoch-0 store", {
                "operation": "lock-epoch",
                "requested_idempotency": args.key,
                "current_epoch": state["lock_epoch"],
                "current_lock_hash": state["lock_hash"],
            })
        if not args.bootstrap and state["lock_epoch"] == 0:
            reject(events, "epoch-0 store requires --bootstrap", {
                "operation": "lock-epoch",
                "requested_idempotency": args.key,
                "requested_epoch": args.epoch,
            })
        if not args.bootstrap and state["leases"]:
            reject(events, "active leases prevent lock epoch change", {
                "operation": "lock-epoch",
                "requested_idempotency": args.key,
                "requested_epoch": args.epoch,
                "active_leases": sorted(state["leases"]),
            })

        active_tasks = [] if args.bootstrap else [
            task for task in state["order"]
            if state["tasks"][task]["status"] in INTERRUPTED_STATUSES
        ]
        quiescence = None
        if active_tasks:
            if not args.quiescent or not args.quiescence_proof:
                reject(events, "active tasks require quiescence proof", {
                    "operation": "lock-epoch",
                    "requested_idempotency": args.key,
                    "requested_epoch": args.epoch,
                    "active_tasks": active_tasks,
                    "quiescent_flag": bool(args.quiescent),
                    "proof_supplied": bool(args.quiescence_proof),
                })
            try:
                quiescence = read_quiescence_proof(args.quiescence_proof)
            except ValueError as exc:
                reject(events, "quiescence proof is invalid", {
                    "operation": "lock-epoch",
                    "requested_idempotency": args.key,
                    "requested_epoch": args.epoch,
                    "active_tasks": active_tasks,
                    "error": str(exc),
                })

        resets = []
        for task in active_tasks:
            row = state["tasks"][task]
            resets.append({
                "task": task,
                "from_status": row["status"],
                "to_status": "ready",
                "from_attempt_epoch": row.get("attempt_epoch", 1),
                "to_attempt_epoch": row.get("attempt_epoch", 1) + 1,
            })

        # Advance every task's fencing floor. This invalidates even a token
        # whose lease was released before the lock change; otherwise its old
        # holder could still mutate state until a replacement lease happened
        # to issue the next token.
        fences = [] if args.bootstrap else [{
            "task": task,
            "from_token": int(state["tokens"].get(task, 0)),
            "to_token": int(state["tokens"].get(task, 0)) + 1,
        } for task in state["order"]]

        event = append(events, {
            "type": "lock_epoch",
            "epoch": args.epoch,
            "lock_hash": requested_hash,
            "previous_epoch": state["lock_epoch"],
            "previous_lock_hash": state["lock_hash"],
            "bootstrap": bool(args.bootstrap),
            "fences": fences,
            "quiescence": quiescence,
            "resets": resets,
            "idempotency": args.key,
        })
        render(project(events))
    print(json.dumps({
        "bootstrap": bool(event.get("bootstrap")),
        "epoch": event["epoch"],
        "lock_hash": event["lock_hash"],
        "reset_tasks": [item["task"] for item in resets],
        "replayed": False,
    }, sort_keys=True))


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
        "lock_epoch": state["lock_epoch"],
        "lock_hash": state["lock_hash"],
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
    line before it, `seq` must be dense, and the projected lock identity must
    equal the immutable lock that readiness verifies."""
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
    # Legacy isolated fixtures did not carry a lock. New lock-aware fixtures
    # opt in with ECOSYSTEM_RUN_LOCK; the production store is always strict.
    if not STORE_DIR or os.environ.get("ECOSYSTEM_RUN_LOCK"):
        try:
            actual_epoch, actual_hash = read_run_lock()
        except ValueError as exc:
            print("status: FAIL run lock invalid: %s" % exc)
            sys.exit(1)
        state = project(events)
        if (state["lock_epoch"], state["lock_hash"]) != (actual_epoch, actual_hash):
            print("status: FAIL state lock epoch/hash does not match run/LOCK.toml")
            print("state lock: epoch %s hash %s" %
                  (state["lock_epoch"], state["lock_hash"]))
            print("run lock: epoch %s hash %s" % (actual_epoch, actual_hash))
            sys.exit(1)
        print("lock: epoch %s hash %s" % (actual_epoch, actual_hash))
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
    p.add_argument("--expired", action="store_true",
                   help="supervisor-only cleanup of an exact expired lease")
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

    p = sub.add_parser("lock-epoch", help="atomically bind the next run lock epoch")
    p.add_argument("--epoch", type=int, required=True)
    p.add_argument("--lock-hash", required=True)
    p.add_argument("--key", required=True, help="idempotency key for this lock change")
    p.add_argument("--bootstrap", action="store_true",
                   help="bind an epoch-0 store without resetting or fencing tasks")
    p.add_argument("--quiescent", action="store_true",
                   help="assert that the supervisor produced the supplied stop proof")
    p.add_argument("--quiescence-proof",
                   help="fresh JSON from `sh tools/supervisor.sh quiescence-proof FILE`")
    p.set_defaults(func=cmd_lock_epoch)

    sub.add_parser("arm", help="promote every dependency-free task to ready") \
        .set_defaults(func=cmd_arm)
    sub.add_parser("promote", help="promote tasks eligible after an external gate change") \
        .set_defaults(func=cmd_promote)
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
