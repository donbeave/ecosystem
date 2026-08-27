# Vision

## One sentence

Turn "work with an agent" into "hand a roadmap to a manager": a daemon inside
the Tailrocks ecosystem watches a plan made of small, independently verifiable
tasks and runs isolated jackin agents on each of them, in parallel where the
plan allows, until every task's verification says `DONE`.

## Why this project exists

Building software with AI agents today is a manual, per-feature ritual. The
ecosystem already has strong pieces — jackin for isolated agent runs, termrock
for terminal interfaces, tailrocks-skills for how work is done, parallax for
evidence — but the person is still the scheduler, the dispatcher, and the
verifier. The manager removes the person from that loop and keeps them where
they add value: defining what must be built and deciding when the system asks.

This is the piece that makes the "more agents than developers" future in the
[Tailrocks vision](https://github.com/tailrocks/vision) operational instead
of aspirational.

## The problem, as it is lived today

For any project or feature the same manual sequence happens:

1. Pick the project that is the **source of truth**. A project holds
   everything that must be done plus the references agents verify against:
   database structures, API contracts, TUI designs, and similar artifacts.
   Those references are what lets an agent check its own work.
2. Start a jackin session and use skills to build a plan and everything the
   plan needs.
3. When the plan is finished, store it on a branch in the repository.
4. Start a **new** agent and hand it the plan with a prompt shaped like:

   ```text
   /goal Follow this plan: <plan.md>

   Read this plan and all related references and work on this task.

   Work on this plan until ./verify.sh returns status: DONE
   ```

5. The agent mostly delivers, but with a large plan it implements a lot
   incorrectly: it loses or confuses context across the many things the plan
   asks for.

Every step is a human action. Every agent is started by hand. Every result is
checked by hand or by a script the human wrote and ran.

## What was observed

Two findings drive the design:

- **Small tasks beat big plans.** An agent given one small task with a clear
  description of what to build and how to verify it is markedly more accurate
  than an agent given the whole plan, even when the whole plan is available
  in the repository as context. The prompt for a single task is the same
  shape, only narrower:

  ```text
  /goal Read this file: <task.md>

  Implement it fully until ./verify-task.sh returns status: DONE
  ```

- **Research and verification subagents help.** Spawning subagents to
  research the codebase and to verify the concept before and after
  implementation raises quality further.

From these follow the structural consequences:

- A plan should be **decomposed up front** into tasks, each in its own folder
  with its own description and its own verification script.
- Tasks that have **no dependency on each other can run in parallel**, each
  with its own agent.
- The whole plan can stay in the repository as context, while the prompt
  restricts each agent to exactly one task.
- Verification becomes a **contract** (`verify` returns `DONE` or not) rather
  than a human judgment, which is what makes unattended execution possible.

## What jackin is good at, and what is missing

jackin already does the hard part of running one agent safely: isolated
containers, roles with pre-installed toolchains and skills, agent-runtime
independence, and tooling to inspect and manage running agents. What it does
not have is anything that decides *which* agent to start, *on what*, *when*,
and *whether the result is acceptable*.

That gap is the manager.

## The target

A manager, which may live inside jackin as a daemon, that:

- Knows about a **roadmap**: a set of plans, each decomposed into tasks with
  descriptions, references, dependencies, and verification scripts.
- **Watches** the roadmap. When tasks are added or their status changes, the
  daemon notices without being told.
- **Analyzes** each task: determines readiness (dependencies satisfied),
  picks the role and agent runtime, and prepares the isolated environment.
- **Starts** agents through jackin, one per task, in parallel where the
  dependency graph allows, on the local machine or on remote hosts.
- **Verifies** each task with its script and records the outcome; retries,
  escalates, or moves on according to policy.
- **Reports** progress on a terminal interface built from termrock, and
  asks the human only when a decision is genuinely theirs.

The human's job becomes: write or approve the roadmap, say "ready", and answer
questions. The system's job becomes everything else.

## The bar

The destination is a production-ready product and a production-ready
process for building software with Linear + jackin: issues are the work,
jackin roles do it, humans decide (D-041). Everything in this repository —
milestones, tasks, decisions — is measured against that bar.

## Scope boundaries

- The manager orchestrates; it is **not** another agent runtime and does not
  compete with Claude Code, Codex, Amp, or any other. Neither jackin nor the
  manager builds a harness: the vendors' harnesses are used as shipped, and
  the ecosystem is built around all of them (D-015).
- Live visibility is non-negotiable: every managed agent runs under the
  jackin capsule so a human can attach to its container and watch the exact
  prompt and the live session (D-016).
- jackin remains the isolation and runtime layer. Changes to jackin are
  planned where the manager needs them; the manager does not reimplement
  jackin.
- termrock remains the component layer for every terminal interface,
  including the manager's. Changes to termrock are planned where the manager's
  interface needs them.
- This repository plans. It does not implement.

## Related repositories

| Repository | Role in this vision |
| --- | --- |
| [jackin](https://jackin.tailrocks.com/) | Isolated agent execution, roles, runtime adapters, control plane. Analysis: `analysis/jackin.md`. |
| [termrock](https://github.com/tailrocks/termrock) | TUI design system every Tailrocks terminal interface is built from. Analysis: `analysis/termrock.md`. |
| [tailrocks-skills](https://skills.tailrocks.com) | The skills agents use to plan, build, review, and verify. |
| [parallax](https://github.com/tailrocks/parallax) | Observability and evidence bundles for agents. |
| [velnor](https://github.com/tailrocks/velnor) | CI that proves task results. |
