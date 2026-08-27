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
| [VISION.md](VISION.md) | The problem, today's workflow, observed insights, and the target we are building toward. Start here. |
| [DECISIONS.md](DECISIONS.md) | Dated decision log. Anything agreed is recorded here before it is elaborated elsewhere. |
| [OPEN-QUESTIONS.md](OPEN-QUESTIONS.md) | Questions not yet decided. Each one is closed by moving it into `DECISIONS.md`. |
| [concept/manager.md](concept/manager.md) | The manager itself: daemon, roadmap watching, task scheduling, agent launching, verification. |
| [concept/task-format.md](concept/task-format.md) | The on-disk format of a plan and its tasks, and the `verify` contract. |
| [concept/workflow.md](concept/workflow.md) | Current manual workflow versus the target workflow, step by step. |
| [analysis/jackin.md](analysis/jackin.md) | What jackin is today, with citations, and its gaps for this goal. |
| [analysis/termrock.md](analysis/termrock.md) | What termrock is today, with citations, and its gaps for this goal. |
| [analysis/symphony.md](analysis/symphony.md) | openai/symphony: the closest existing execution concept, and what to adopt or reject. |
| [analysis/linear-agents.md](analysis/linear-agents.md) | Linear Agents platform facts, jackin role contract facts, and a proposed issue convention. |
| [AGENTS.md](AGENTS.md) | Rules for agents (and humans) editing this repository. `CLAUDE.md` is a symlink to it. |

## Working rules

- Planning only. No source code, no prototypes, no scaffolding in this repository.
- Decisions are explicit. If it is not in `DECISIONS.md`, it is not decided.
- Analyses cite files and lines in the real repositories; opinions are labeled as such.
