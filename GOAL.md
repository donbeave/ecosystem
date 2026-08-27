Host Claude Code session: execute `ROADMAP.md` (FINAL) end to end, unattended: all 81
tasks until `sh verify.sh` ends `status: DONE`. You coordinate, verify and record;
subagents work. `goal/PREFLIGHT.md` is done.

## Sources of truth

1. `AGENTS.md` in full, then `goal/EXECUTION.md`.
2. `tasks/README.md`, `PROGRESS.md`, `PREFLIGHT-DEFECTS.md`, `tasks/<id>/` — run state,
   the only files you write.
3. Precedence: `ROADMAP.md` > `SPEC.md` > `DECISIONS.md` > `concept/`; only
   `DECISIONS.md` decides. Never `Read` those or `analysis/`; a subagent does.

## Laws

1. Delegate every large-file read, implementation, verification and proof to `model:
   "opus"` subagents, one per checklist item, ≤15 lines each; waves run parallel within
   the caps.
2. Codex lanes L4..L6 run in jackin role containers (§4 `container`), never as subagents.
3. Never ask, confirm, or wait for a human, review or merge; agents merge when the task
   names it. Answer design questions with the recommended answer, recorded by a subagent
   in `DECISIONS.md`+`SPEC.md` (D-104).
4. An input only a human can give goes to `PREFLIGHT-DEFECTS.md` with its proving command,
   that row `blocked`; continue with the other runnable tasks.
5. Stuck (no evidence for 30 min, or three verify failures) spawns diagnostic subagents;
   apply the fix first.
6. Fix involved projects, never work around them. Per task a worktree and branch
   `managed/<run-id>/<task-id>` off the `run/LOCK.toml` base SHA; a worker pushes only
   that. `feat/managed-execution` (roles: `main`) is an integration target, never a worker
   checkout: only the `state.py lease --owner integrator:<repo>` holder merges there and
   verify runs on that integrated SHA, filed as `integrated_sha` (D-112). Us: `main`.
7. `git commit -s` always, rebase before each push, never `--force`, push at once after
   every transition; a protected `main` is reached only by a PR the agent merges on green
   checks (§4).
8. Credentials only as `op://`; no secret in any file, log or message;
   `gitleaks detect --no-git --source tasks/<id>` before each commit.
9. Here: Markdown plus `tasks/<id>/` machine files only; reviews never block
   and appear in no `depends_on`.

## Task loop

1. Take every runnable row in wave order.

Runnable (D-119), from the store: `ready`; all `depends_on` `done`; a free lane slot under
the caps (≤2 host subagents on `~/.claude`, ≤3 in flight, D-071) and the §4 reserve rule;
for M2+ ids other than M3-01, M3-03, M4-02, M4-03, also M1-12 `done` (D-088). `planned`,
`blocked`, `waiting`, `in-progress` are neither runnable nor `done` (D-084). Arming
(D-072): `state.py arm` readies wave 0 (M1-01) once, idempotently; each `done` transition
readies tasks whose deps are all `done`; no task runs from a bare row.

2. Run `goal/EXECUTION.md` §5 steps 0-9 verbatim.
3. Done requires: `verify.sh` ends `status: DONE`, row `done`, a `PROGRESS.md` row, all
   touched repositories pushed.
4. Re-run `sh verify.sh`, then dispatch the next runnable tasks.

## Resume

On restart, re-prompt or compaction: re-read `AGENTS.md` and `goal/EXECUTION.md` §1, §5,
re-derive state from the store, `attempts.log` and `git log`, never re-run a `done`
task; `tools/supervisor.sh resume` restarts you after a non-terminal exit.

## Termination

`sh verify.sh` derives the class, never you (D-110): `DONE`, `BLOCKED HUMAN`, `FAILED
SYSTEM` (no human input clears it), `PENDING` (keep going). End the
turn only in this shape, nothing after:

- line 1 alone: `GOAL COMPLETE`/`GOAL BLOCKED`/`GOAL FAILED` for `DONE`/`BLOCKED
  HUMAN`/`FAILED SYSTEM`; Monitor-wait out `in-progress` and `waiting` rows first;
- then ≤8 report lines: tasks done/total, defects, fallbacks, heads, Linear URL;
- then, BLOCKED only, the open `PREFLIGHT-DEFECTS.md` rows verbatim;
- last, this turn's literal `sh verify.sh` output.

Never end a turn any other way, claim `GOAL COMPLETE` without that output, or fill an
`exhausted:` row's `Resolved` cell.