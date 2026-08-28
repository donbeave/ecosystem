Execute `ROADMAP.md`'s 81-task graph unattended until `sh verify.sh` ends
`status: DONE`. Coordinate only; subagents execute.

## Inputs

1. Read `AGENTS.md`, then `goal/EXECUTION.md`.
2. Run state and only writes: `tasks/README.md`, `PROGRESS.md`,
   `PREFLIGHT-DEFECTS.md`, `tasks/<id>/`.
3. `SPEC.md` alone defines product/acceptance; `ROADMAP.md` graph/order; this file
   plus `goal/EXECUTION.md` procedure; others context.

## Laws

1. Delegate large reads, implementation, verification, and proof to `model:
   "claude-opus-5"`, one subagent per item, ≤15 lines each; parallelize waves.
2. Codex lanes L4..L6 run in jackin role containers (§4 `container`), never as subagents.
3. Never ask, confirm, or await human review/merge; agents merge when named.
   A subagent updates `SPEC.md`, then derived pointers (D-104).
4. Human-only input goes to `PREFLIGHT-DEFECTS.md` with proof command, row `blocked`;
   continue other runnable rows.
5. Stuck (no evidence for 30 min, or 3 verify failures): spawn diagnostic subagents;
   apply the fix first.
6. Fix involved projects. Each task gets worktree/branch
   `managed/<run-id>/<task-id>` from the locked base; worker pushes all.
   Integration target is `feat/managed-execution` (roles: `main`), never a worker
   checkout; only its `integrator:<repo>` lease holder merges. Verify that SHA and
   file it as `integrated_sha` (D-112). Us: `main`.
7. Always `git commit -s`; rebase before push; never `--force`; push each transition.
   Reach protected `main` only through green PR agent merges (§4).
8. Credentials only as `op://`; no secrets in files/logs/messages;
   `gitleaks detect --no-git --source tasks/<id>` before each commit.
9. Here: Markdown plus `tasks/<id>/` machine files only; reviews never block or enter
   `depends_on`.

## Loop

1. Take runnable rows in wave order.

Runnable predicate (D-119). A row is Runnable (D-119) iff its status is `ready`; every
`depends_on` id is `done`; a lane slot is free under the caps (at most two
host subagents on `~/.claude`, at most three in flight, D-071) and the §4
reserve rule; and, except for M3-01, M3-03, M4-02, M4-03, an M2+ row has
M1-12 `done`, a valid lock-bound CTRL-006 audit, and one matching issue in
both passes of `tasks/M1-12/issues.json`. Those four ids
bypass both gates, run locked bundles, and receive issue backfill from M1-12
without rerun (ISSUE-006, CTRL-006, CTRL-014). `planned`, `leased`, `blocked`,
`waiting`, `resource-waiting`, `in-progress`, `failed-system`, and `done` are
not runnable (D-084).

Arming (D-072): `state.py arm` readies wave 0 once; each `done` transition readies tasks
whose deps are `done`; no task runs from a bare row.
After valid audit PASS, `state.py promote` reconciles remaining planned rows.
The host first records that PASS as M1-12's fenced `foundation-audit` event;
no synthetic task or projection row represents it.

2. Run `goal/EXECUTION.md` §5 steps 0-9 verbatim.
3. Done requires: `verify.sh` ends `status: DONE`, row `done`, `PROGRESS.md` row, all
   touched repositories pushed.
4. Re-run `sh verify.sh`; dispatch next runnable rows.

## Resume

On restart/re-prompt/compaction: re-read `AGENTS.md`, execution §1/§5; re-derive
from store, `attempts.log`, `git log`; never re-run `done`;
`tools/supervisor.sh resume` restarts you after a non-terminal exit.

## Termination

`sh verify.sh` alone derives (D-110): `DONE`, `BLOCKED HUMAN`, `FAILED
SYSTEM` (no human input clears it), `PENDING` (keep going). End the turn only in this shape:

- line 1 alone: `GOAL COMPLETE`/`GOAL BLOCKED`/`GOAL FAILED` for `DONE`/`BLOCKED
  HUMAN`/`FAILED SYSTEM`; Monitor-wait out `in-progress` and `waiting` rows first;
- then ≤8 report lines: done/total, defects, fallbacks, heads, Linear URL;
- BLOCKED only: the open `PREFLIGHT-DEFECTS.md` rows verbatim;
- last, this turn's literal `sh verify.sh` output.

Never end a turn otherwise, claim `GOAL COMPLETE` without that output, or fill an
`exhausted:` row's `Resolved` cell.
