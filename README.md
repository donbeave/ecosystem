# Tailrocks Ecosystem — Agent Manager concept

This repository is the **plan of record and the run state** for a new project:
a manager that runs many AI coding agents on big tasks inside the Tailrocks
ecosystem (jackin, termrock, parallax, velnor, tailrocks-skills, ...). It holds
the vision, decisions, and concept documents; the task bundles and evidence of
the `/goal` run; and the machine files that run and gate it — `tools/`,
`tests/`, `run/`, `findings/`, the root `verify.sh`, and `tasks/<id>/`, at
exactly the paths D-118 permits.

No product code lives here: that is written in the involved repositories
(github.com/jackin-project, github.com/tailrocks, donbeave/jackin-*). The
planning documents are improved incrementally — each conversation that reaches
agreement on a point updates the relevant file.

## Start the run

Prerequisites: complete `goal/PREFLIGHT.md` §1–§5. An undone §3–§5 item is not a guaranteed
stop: it becomes a `PREFLIGHT-DEFECTS.md` row that blocks only the tasks needing it, and ends
the run as BLOCKED only when nothing else is runnable (D-050, D-070). Open Claude Code in this
repository.

```text
/goal Follow GOAL.md. Goal reached only when the current turn ends with a message whose first line is exactly `GOAL COMPLETE` or `GOAL BLOCKED` and whose last lines are the literal output of `sh verify.sh` from that turn: last line `status: DONE` for COMPLETE, or `status: BLOCKED HUMAN` preceded by the open PREFLIGHT-DEFECTS.md rows for BLOCKED. Any other turn end is not the goal.
```

This one line is the only invocation; every document that says "the invocation line of
`GOAL.md`" means it, copied verbatim — never shortened to `/goal Follow GOAL.md`, because the
argument carries the two terminal facts the runner's judge checks (D-083). `GOAL.md` itself is
the prompt the runner executes and holds nothing else.

A run is started and restarted by `tools/supervisor.sh start` (`resume` after any crash),
which reconciles leases and live containers, launches the coordinator in the tmux session
`ecosystem-coordinator`, and re-invokes it from durable state on any exit that is not
`GOAL COMPLETE`/`GOAL BLOCKED` — see `goal/EXECUTION.md` §1 "Supervisor".

Wave 0 is armed once, by `python3 tools/state.py arm`: it moves every dependency-free task
— M1-01, which authors every task bundle (D-072) — from `planned` to `ready`, and is
idempotent. Every later `done` transition promotes each `planned` task whose dependencies
are all `done` to `ready`, so a row is `ready` before it is ever dispatched and no task
runs from a bare row.

Start the session with the model and permission mode the run is pinned to (D-095, D-120):

```text
claude-yolo --model claude-fable-5
```

`claude-yolo` is a zsh function in the operator's `~/.zshrc`; it expands to

```text
claude --settings '{"skipDangerousModePermissionPrompt":true}' \
       --dangerously-skip-permissions --model claude-fable-5
```

so any host can reproduce the launch without that file. Every agent runtime runs in its yolo mode
— Claude Code with `--dangerously-skip-permissions`, Codex CLI with
`--dangerously-bypass-approvals-and-sandbox` — on the host and in every container; isolation
comes from the container, not from approvals, and no permission allowlist exists anywhere
(D-121). `claude-fable-5` at effort high is
the host session; every subagent it launches runs `claude-opus-5` (`AGENTS.md` delegation
law). The permission mode is `bypassPermissions`, so an unattended run never stops on a
permission prompt and no tool allowlist is needed; `.claude/settings.json` is committed in
this repository and pins the host model, sets `skipDangerousModePermissionPrompt`, and
denies `git push --force` and `git push -f`. Only a new irreversible operation is ever
added to that file, as a `deny` entry.

The run's terminal class is derived by `verify.sh` from the run state store, never
asserted by an agent, and is one of `DONE`, `BLOCKED HUMAN`, `FAILED SYSTEM`, `PENDING`
(D-110). COMPLETE and BLOCKED below are the human-facing names of the first two;
`FAILED SYSTEM` means a plan, tool, or environment defect that no human input would
unblock. The implementation run is armed only after a static and a live readiness gate
both print `status: READY` for the same lock hash (D-109).

The run has exactly two good outcomes (D-069, D-070, D-083), and `verify.sh` decides which
one it reached from the state store and the repositories, not from anything an agent writes.
COMPLETE: `sh verify.sh` prints `status: DONE` as its last line in the final turn — every
task is `done`, its evidence names a commit that is an ancestor of the pushed head, its
recorded bundle hash still matches its bundle, the tree is clean, and `PROGRESS.md` holds one
row per done task. BLOCKED: `status: BLOCKED HUMAN` — no task is runnable, none is
`in-progress` or `waiting`, and `PREFLIGHT-DEFECTS.md` has a row with an empty `Resolved`
cell, the only reason the run stops. The two bad outcomes are `status: PENDING`, which means
work remains and the run has simply not finished, and `status: FAILED SYSTEM`, an integrity
failure — forged, stale, dirty, unpushed, or contradicting the state store — that no operator
input would clear. A failing check, a design question, a review, a quota
wait, a capsule dialog, and a defect in an involved project are never reasons to stop.
Re-running the same line after BLOCKED, a crash, or a context compaction resumes; nothing
finished is redone (`goal/EXECUTION.md` §1).

## Map

| File | Purpose |
| --- | --- |
| [SPEC.md](SPEC.md) | The living specification: only decided points, with open questions marked. Improved every conversation. |
| [ROADMAP.md](ROADMAP.md) | Milestones, tasks, dependencies, roles, and the decisions that gate each milestone. Proposal until finalized. |
| [VISION.md](VISION.md) | The problem, today's workflow, observed insights, and the target we are building toward. Start here. |
| [DECISIONS.md](DECISIONS.md) | Dated decision log. Anything agreed is recorded here before it is elaborated elsewhere. |
| [OPEN-QUESTIONS.md](OPEN-QUESTIONS.md) | Questions not yet decided. Each one is closed by moving it into `DECISIONS.md`. |
| [concept/manager.md](concept/manager.md) | The manager itself: daemon, roadmap watching, task scheduling, agent launching, verification. |
| [concept/task-format.md](concept/task-format.md) | The on-disk format of a plan and its tasks, and the `verify` contract. |
| [concept/roles.md](concept/roles.md) | Proposed jackin agent roles that build the product: builder, operator, reviewer; naming, specs, trust, credentials. |
| [concept/credentials.md](concept/credentials.md) | 1Password inventory: what exists, what must be created, naming (metadata only). |
| [concept/workflow.md](concept/workflow.md) | Current manual workflow versus the target workflow, step by step. |
| [analysis/jackin.md](analysis/jackin.md) | What jackin is today, with citations, and its gaps for this goal. |
| [analysis/termrock.md](analysis/termrock.md) | What termrock is today, with citations, and its gaps for this goal. |
| [analysis/symphony.md](analysis/symphony.md) | openai/symphony: the closest existing execution concept, and what to adopt or reject. |
| [analysis/linear-agents.md](analysis/linear-agents.md) | Linear Agents platform facts, jackin role contract facts, and a proposed issue convention. |
| [AGENTS.md](AGENTS.md) | Rules for agents (and humans) working in this repository: the two modes, the delegation law, the status contract, the token economy. `CLAUDE.md` is a symlink to it. |
| [GOAL.md](GOAL.md) | The `/goal` prompt itself, nothing else: mission, sources of truth, operating laws, task loop, resume, termination (D-069, D-083). Under 4000 characters. The invocation line to paste is in "Start the run" above. |
| [goal/EXECUTION.md](goal/EXECUTION.md) | How the host session runs it: session start, per-task procedure, wave order, execution paths, resume, STOP, host session budget. |
| [goal/PREFLIGHT.md](goal/PREFLIGHT.md) | Everything the human provides once before the run (D-050), consolidated from `ROADMAP.md`. |
| [verify.sh](verify.sh) | Roadmap-level gate: derives the run's terminal class — `DONE`, `BLOCKED HUMAN`, `FAILED SYSTEM`, `PENDING` — from the state store, the compiled graph and the repository (D-069, D-110). `sh tools/gate_fixtures.sh` proves it against the adversarial fixtures in `tests/fixtures/`. |
| [PROGRESS.md](PROGRESS.md) | Append-only ledger of the run: one row per task with lane, path, result, evidence. |
| [PREFLIGHT-DEFECTS.md](PREFLIGHT-DEFECTS.md) | Operator inputs found missing mid-run; the only reason the run stops. |

## Working rules

- Planning only in the planning documents. No source code, no prototypes, no scaffolding in this repository; that rule never forbids the run's own machine files, which are permitted at exactly these paths (D-118): `tools/` (POSIX `sh` or Python 3 stdlib only), `tests/` (fixtures and harnesses, same two languages), `run/LOCK.toml`, `run/state.db` or `run/events.jsonl`, `findings/disposition.toml`, `.claude/settings.json` (D-095), the root `verify.sh` (D-069), and under `tasks/<id>/` — `TASK.md`, `task.toml`, `verify.sh`, `expected-evidence.toml`, `evidence.json`, `refs/`, and text evidence (D-038, D-093).
- Decisions are explicit. If it is not in `DECISIONS.md`, it is not decided.
- Analyses cite files and lines in the real repositories; opinions are labeled as such.
