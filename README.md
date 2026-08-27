# Tailrocks Ecosystem — Agent Manager concept

This repository is a **research and planning space**, not a codebase. It holds
the vision, decisions, and concept documents for a new project: a manager that
runs many AI coding agents on big tasks inside the Tailrocks ecosystem
(jackin, termrock, parallax, velnor, tailrocks-skills, ...).

Nothing here is implemented. Every file is a plan, an analysis, or a recorded
decision. The documents are improved incrementally: each conversation that
reaches agreement on a point updates the relevant file.

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
| [AGENTS.md](AGENTS.md) | Rules for agents (and humans) editing this repository. `CLAUDE.md` is a symlink to it. |
| [GOAL.md](GOAL.md) | The `/goal` prompt that executes the whole roadmap unattended (`/goal Follow GOAL.md`), under 4000 characters; the run ends COMPLETE or BLOCKED (D-069, D-070). |
| [goal/EXECUTION.md](goal/EXECUTION.md) | How the host session runs it: session start, per-task procedure, wave order, execution paths, resume, STOP. |
| [goal/PREFLIGHT.md](goal/PREFLIGHT.md) | Everything the human provides once before the run (D-050), consolidated from `ROADMAP.md`. |
| [verify.sh](verify.sh) | Roadmap-level gate: `status: DONE` only when every task in `tasks/README.md` is `done` with its `verify.sh` (D-069). |
| [PROGRESS.md](PROGRESS.md) | Append-only ledger of the run: one row per task with lane, path, result, evidence. |
| [PREFLIGHT-DEFECTS.md](PREFLIGHT-DEFECTS.md) | Operator inputs found missing mid-run; the only reason the run stops. |

## Working rules

- Planning only. No source code, no prototypes, no scaffolding in this repository; the only runnable files are `tasks/<id>/verify.sh` and the root `verify.sh` (D-038, D-069).
- Decisions are explicit. If it is not in `DECISIONS.md`, it is not decided.
- Analyses cite files and lines in the real repositories; opinions are labeled as such.
