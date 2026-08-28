Host Claude Code: execute `ROADMAP.md` (FINAL), unattended through 81 tasks
until `sh verify.sh` ends `status: DONE`. Coordinate, verify, record;
subagents work. `goal/PREFLIGHT.md` is done.

## Sources of truth

1. `AGENTS.md` in full, then `goal/EXECUTION.md`.
2. `tasks/README.md`, `PROGRESS.md`, `PREFLIGHT-DEFECTS.md`, `tasks/<id>/` — run state,
   your only writes.
3. Owners: `ROADMAP.md` graph/order; `SPEC.md` product + D registry; `GOAL.md` +
   `goal/EXECUTION.md` procedure; `concept/` non-normative. Subagents `Read` these
   and `analysis/`.

## Laws

1. Delegate every large-file read, implementation, verification and proof to `model:
   "opus"` subagents, one per checklist item, ≤15 lines each; waves run parallel.
2. Codex lanes L4..L6 run in jackin role containers (§4 `container`), never as subagents.
3. Never ask, confirm, or wait for a human, review or merge; agents merge when the task
   names it. Use recommended design answer; a subagent records it in `SPEC.md` registry
   and affected owners (D-104).
4. An input only a human can give goes to `PREFLIGHT-DEFECTS.md` with its proving command,
   that row `blocked`; continue with the other runnable rows.
5. Stuck (no evidence for 30 min, or 3 verify failures) spawns diagnostic subagents;
   apply the fix first.
6. Fix involved projects, never work around them. Per task a worktree and branch
   `managed/<run-id>/<task-id>` off the `run/LOCK.toml` base SHA, all a worker pushes.
   `feat/managed-execution` (roles: `main`) is an integration target, not a worker
   checkout: only the `state.py lease --owner integrator:<repo>` holder merges there;
   verify runs on that SHA, filed as `integrated_sha` (D-112). Us: `main`.
7. `git commit -s` always, rebase before each push, never `--force`, push at once after each
   transition; a protected `main` is reached only by a PR the agent merges green (§4).
8. Credentials only as `op://`; no secret in any file, log or message;
   `gitleaks detect --no-git --source tasks/<id>` before each commit.
9. Here: Markdown plus `tasks/<id>/` machine files only; reviews never block and are in no
   `depends_on`.

## Task loop

1. Take every runnable row in wave order.

Runnable predicate (D-119). A row is Runnable (D-119) iff: its status is
`ready`; every `depends_on` id is `done`; a lane slot is free under the
caps — at most two host subagents on `~/.claude`, at most
three host subagents in flight (D-071) — plus the §4 reserve rule of
`goal/EXECUTION.md`; and, for M2+ ids other than M3-01, M3-03, M4-02, M4-03,
the M1-12 row is `done` (D-088). Rows `planned`, `blocked`, `waiting` or
`in-progress` are not runnable and do not count as `done` (D-084).

Arming (D-072): `state.py arm` readies wave 0 once; each `done` transition readies tasks
whose deps are `done`; no task runs from a bare row.

2. Run `goal/EXECUTION.md` §5 steps 0-9 verbatim.
3. Done requires: `verify.sh` ends `status: DONE`, row `done`, a `PROGRESS.md` row, all
   touched repositories pushed.
4. Re-run `sh verify.sh`; dispatch the next runnable rows.

## Resume

On restart, re-prompt or compaction: re-read `AGENTS.md` and `goal/EXECUTION.md` §1, §5,
re-derive state from the store, `attempts.log` and `git log`, never re-run a `done` task;
`tools/supervisor.sh resume` restarts you after a non-terminal exit.

## Termination

`sh verify.sh` derives the class, never you (D-110): `DONE`, `BLOCKED HUMAN`, `FAILED
SYSTEM` (no human input clears it), `PENDING` (keep going). End the turn only in this shape:

- line 1 alone: `GOAL COMPLETE`/`GOAL BLOCKED`/`GOAL FAILED` for `DONE`/`BLOCKED
  HUMAN`/`FAILED SYSTEM`; Monitor-wait out `in-progress` and `waiting` rows first;
- then ≤8 report lines: done/total, defects, fallbacks, heads, Linear URL;
- BLOCKED only: the open `PREFLIGHT-DEFECTS.md` rows verbatim;
- last, this turn's literal `sh verify.sh` output.

Never end a turn otherwise, claim `GOAL COMPLETE` without that output, or fill an
`exhausted:` row's `Resolved` cell.
