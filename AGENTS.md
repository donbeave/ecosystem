# AGENTS.md

Rules for any agent or person working here. `CLAUDE.md` symlinks to this file; read it first, then `goal/EXECUTION.md`.

## Two modes

| Mode | Scope | Rule |
| --- | --- | --- |
| Planning | `VISION.md`, `SPEC.md`, `OPEN-QUESTIONS.md`, `ROADMAP.md`, `concept/`, `analysis/`, `README.md` | Markdown only, at these paths. No source code, build files, scaffolding, or prototypes here. This never forbids the machine files the Execution row permits (D-118): the run writes and commits them as evidence and tooling. |
| Execution | `GOAL.md`, `goal/`, `tasks/`, `tools/`, `tests/`, `run/`, `findings/`, `PROGRESS.md`, `PREFLIGHT-DEFECTS.md`, root `verify.sh`, `.claude/` | Machine files allowed at exactly these paths and nowhere else (D-118): `tools/` (DAG compiler, state store, supervisor, fixture runner — POSIX `sh` or Python 3 stdlib only), `tests/` (fixtures and harnesses, same two languages), `run/LOCK.toml`, `run/state.db` or `run/events.jsonl` (state store; text preferred), `findings/disposition.toml`, `.claude/settings.json` (D-095), the root `verify.sh` (D-069), and under `tasks/<id>/` — `TASK.md`, `task.toml`, `verify.sh`, `expected-evidence.toml`, `evidence.json`, `refs/`, and text evidence (`.out`, `.log`, `.json`, `.toml`, `.txt`, `.cast`) (D-038, D-059). |

Execution edits a planning document only to update the normative contract (`SPEC.md`) or
amend the graph (`ROADMAP.md`). The host session never makes that edit itself: it delegates
it to a subagent and commits the subagent's edit (D-104).

## Entry point, run mode, source of truth

1. `GOAL.md` is the entry point of any run: its whole text is the prompt the `/goal` runner
   executes, `goal/EXECUTION.md` the procedure, `goal/PREFLIGHT.md`
   the human's one-time checklist, `README.md` "Start the run" the invocation line to paste.
2. Run mode: if any `tasks/README.md` row is not `planned`, a `/goal` run is under way and
   this session is the host session. After a context compaction or a re-prompt, re-read
   `GOAL.md` and `goal/EXECUTION.md` §1 and §5, then run §1 steps 2–3; state is re-derived
   from `tasks/README.md`, `PROGRESS.md`, `tasks/<id>/attempts.log`, and `git log` only,
   never from memory.
3. Treat SPEC.md as the sole authority for final-product requirements and acceptance conditions; keep ROADMAP.md authoritative only for graph and order, GOAL.md plus goal/EXECUTION.md only for run procedure, and concept/ non-normative; never let those documents override SPEC.md on product behavior or acceptance. Correct contradictions in the same commit.
4. Treat `VISION.md` and `OPEN-QUESTIONS.md` as non-normative; final-product requirements and acceptance conditions exist only when stated in `SPEC.md`.

## Delegation law (D-036, D-082, D-092)

- The top-level session coordinates only. It may read `GOAL.md`, `AGENTS.md`,
  `goal/EXECUTION.md`, `goal/PREFLIGHT.md`, `tasks/README.md`, `PROGRESS.md`,
  `PREFLIGHT-DEFECTS.md`, and the current task folder. Nothing else.
- Every read of a large file (`ROADMAP.md`, `SPEC.md`, `concept/*`,
  `analysis/*`, any involved repository), every implementation, every verification, and
  every proof runs in a subagent launched with `model: "claude-opus-5"` — the exact id
  D-095 pins, not the family alias (D-092, amended by D-095). The session may
  `grep` for a single literal instead of delegating, never `Read`.
- One subagent per checklist item, in parallel wherever the wave and the caps of
  `ROADMAP.md` §3 allow.
- Codex lanes (L4..L6) never run as Claude subagents: they run in jackin role containers on
  the `container` path of `goal/EXECUTION.md` §4, in Codex yolo mode
  (`--dangerously-bypass-approvals-and-sandbox`); Claude lanes L1..L3 may take the
  `subagents` path, in Claude yolo mode (`--dangerously-skip-permissions`). Isolation comes
  from the container, not from approvals; no permission allowlist exists anywhere (D-121).
  The session writes only this repository (D-086).

## Never ask the human

- No question, no confirmation, no waiting for a human review or merge. Agents merge when
  the task text names the merge (D-055, D-079).
- An input only a human can provide (login, OTP, consent screen, billing, a credential
  created in a UI, physical hardware) is appended to `PREFLIGHT-DEFECTS.md` with the command
  that proves it is in place; the task row goes `blocked`; the run continues with every
  other runnable task (D-050, D-070).
- Never a defect: a failing test, a design choice, a defect in an involved project, a
  missing `brew`-installable tool, a review, a lane fallback, a quota wait, a capsule
  dialog, or a stale host binary.

## Stuck rule (D-063)

No new evidence for 30 minutes, or three consecutive verify failures → fresh subagents
analyze why (assumption, missing input, failing check, environment) and the fix is applied
before anything else. Binds the host session and every container agent. After
`limits.attempts` attempts (default 3) in one epoch the task is filed `exhausted:` in
`PREFLIGHT-DEFECTS.md` and stays `blocked` until the human fills its `Resolved` cell
(D-070, D-084, D-093).

## Repositories, branches, commits

- Fix involved projects, never work around them: any repository under
  github.com/jackin-project, github.com/tailrocks, or donbeave/jackin-* may be changed
  (D-046).
- Branches (D-047, D-074, amended by D-112): every task works in its own git worktree on
  its own branch `managed/<run-id>/<task-id>`, created from the base SHA locked in
  `run/LOCK.toml`. A worker checks out only that branch and pushes only that branch. In an
  involved project `feat/managed-execution` is the integration target and nothing else — no
  worker ever checks it out, rebases it, or pushes it; in a role repository the integration
  target is `main` (jackin loads the default branch, D-074). This repository is written
  only by the host session, on `main`, never a feature branch.
- Integration: one integrator lease per repository, taken with `python3 tools/state.py
  lease --owner integrator:<repo>`. Only the lease holder fast-forwards or merges a task
  branch into that repository's integration target, one task at a time. Verification runs
  against the resulting integrated SHA, never against a worker branch tip, and that SHA is
  recorded in `tasks/<id>/evidence.json` as `integrated_sha` (D-112). Every external
  mutation carries the idempotency key `hash(run, task, attempt, operation)` and is refused
  when its fencing token is stale (D-113).
- `git commit -s` always (DCO); `git fetch && git rebase` before every push; never
  `--force` (one sanctioned exception, `goal/EXECUTION.md` §4 DCO rule); push at once,
  nothing stays local. Commit and push this repository after every task transition
  (`in-progress`, `done`, `blocked`, ledger row).
- Every repository we create is public (D-065). No binaries, archives, or generated
  artifacts; evidence is text (D-059).

## Credentials

Every credential lives in 1Password and is referenced as `op://`; no secret value in any
file, log, message, or image (D-035). Evidence is scanned before commit (`gitleaks detect
--no-git --source tasks/<id>`, D-081); a hit deletes the file, files a defect naming the
credential to rotate, and blocks the commit.

## Status contract — `tasks/README.md`

- One row per roadmap task id (81, D-088). Columns `Task` and `Status` must keep those
  header names; extra columns (a Linear URL) are fine — `verify.sh` parses by header name.
- Statuses, lowercase, exactly these: `planned`, `ready`, `in-progress`, `waiting`,
  `blocked`, `leased`, `resource-waiting`, `failed-system`, `done`. Only a row with its own
  open `PREFLIGHT-DEFECTS.md` row is ever `blocked`; dependents stay `ready` and are simply
  not runnable (D-084).
- `tasks/README.md` and `PROGRESS.md` are generated projections of the run state store and
  are never hand-edited; a hand edit is a defect, not a transition, and the next render
  discards it. The store is the append-only event log `run/events.jsonl`, written only
  through `tools/state.py` (`transition`, `lease`, `release`, `event`), which appends under a
  flock on `run/events.lock` with `O_APPEND` and `fsync` and chains each event to the
  previous one by hash. Each event carries the lease owner, epoch, and fencing token, and
  every external mutation an idempotency key `sha256(run, task, attempt, operation)`; a
  duplicate key or a superseded token is refused with a non-zero exit and an audit event
  (D-111, D-113). After every transition the host session runs `python3 tools/state.py
  render` and commits the two regenerated files with the log. The run's terminal class is one
  of `DONE`, `BLOCKED HUMAN`, `FAILED SYSTEM`, `PENDING`, derived by `verify.sh` from the
  store, never asserted by an agent (D-110).
- A row is `done` only when `tasks/<id>/verify.out` ends with `status: DONE`,
  `tasks/<id>/verify.sh` exists, and every touched repository is committed and pushed.
  Written by the host session only, then committed and pushed at once.

## Token economy

- The host session never `Read`s `ROADMAP.md`, `SPEC.md`, `concept/*`, or
  `analysis/*`; a subagent reads them and returns what is needed.
- Every subagent returns at most 15 lines: verdict, evidence paths, next action — no file
  dumps, no restated instructions, no code excerpts.
- `PROGRESS.md` rows are one line each, no prose; fallbacks, attempts, and quota hops go in
  the result cell, never in new rows. Reports to the human are at most 12 lines.

## Where things go

| Content | File |
| --- | --- |
| Non-normative problem context, insights, and questions | `VISION.md`, `OPEN-QUESTIONS.md` |
| Final-product requirements and acceptance conditions | `SPEC.md` |
| Non-normative elaboration of manager, task format, roles, and workflow | `concept/manager.md`, `concept/task-format.md`, `concept/roles.md`, `concept/workflow.md` |
| Milestones, tasks, dependencies, waves, roles, lanes | `ROADMAP.md` |
| The `/goal` prompt (that file is the prompt and nothing else), its procedure, the human's checklist | `GOAL.md`, `goal/EXECUTION.md`, `goal/PREFLIGHT.md` (D-069) |
| The invocation line to paste, prerequisites, the two outcomes | `README.md` "Start the run" (D-083) |
| One folder per task, indexed with status | `tasks/README.md`, `tasks/<id>/` |
| Roadmap gate (`status: DONE` when every task is done); run ledgers | `verify.sh`, `PROGRESS.md`, `PREFLIGHT-DEFECTS.md` (D-050, D-069) |
| Facts about existing repositories | `analysis/<repo>.md` |
