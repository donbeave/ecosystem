# The manager

Working name: "the manager" (see Q-002). This document describes how it is
meant to work. Everything here elaborates decisions in `DECISIONS.md`; where
a point is still open, it links the question in `OPEN-QUESTIONS.md`.

## Responsibilities

The manager owns everything between "a plan exists" and "every task of the
plan is verified `DONE`":

| Responsibility | What it means |
| --- | --- |
| Roadmap | Holds plans and their tasks, their status, and their dependency graph. |
| Watching | Detects when a plan or task becomes ready or changes status (D-005). |
| Analysis | Decides for each task whether it is runnable, which role and agent runtime fit, and what environment it needs. |
| Dispatch | Starts one isolated jackin agent per runnable task, in parallel when dependencies allow (D-004). |
| Verification | Runs each task's verification contract, records the outcome, applies the failure policy (Q-008). |
| Escalation | Routes genuine decisions to the human and feeds the answer back (Q-009). |
| Reporting | Shows roadmap, fleet, logs, and inbox on a termrock-based terminal interface (D-006, Q-011). |

It does **not** run agents itself, does not replace any agent runtime, and
does not reimplement isolation. jackin is the executor.

## Division of labor with jackin

`analysis/jackin.md` shows jackin today runs one agent per container in the
foreground, with no programmatic session API, no scheduler, and a host daemon
that is an empty shell. The recommended split, adopted as the working model:

- **Manager (new):** roadmap and run ledger, plan graph, scheduler, task
  dispatch, verification, artifacts, decision inbox, reporting, multi-host
  awareness.
- **jackin CLI (unchanged, D-009):** the same commands, creating the same
  containers. Nothing in this project redesigns it.
- **jackin daemon (additive, D-008/D-009):** a long-running process per host
  that (1) monitors every agent container on the host, whether started by
  the CLI or by the daemon, continuously verifying where each runs and in
  what state, and (2) connects to the task system, takes tasks from it, and
  executes them by creating containers through the same mechanism the CLI
  uses. It exposes start (role, mounts, brief), list with live status,
  stream events, stop, restart, and "execute and return result" for
  verification scripts, and reconciles state after its own restart.
- **Task system (Q-003):** where the human provides roadmaps and tasks and
  where status is reported back. The daemon is its consumer; the manager
  logic (scheduling, verification policy, inbox) sits between the task
  system and the daemon, in the daemon binary or beside it (Q-001).

Whether the manager ships inside the jackin daemon binary or beside it is
Q-001.

## Layering

```text
human ── termrock TUI ──┐
                        ├── task system (roadmap, tasks, status)      Q-003
human ── jackin CLI ──┐ │
      (unchanged)     │ │  takes tasks, reports status
                      │ manager logic (scheduler, verification, inbox) Q-001
                      │ │
                      │ jackin daemon (per host: monitor all containers,
                      │               execute tasks)                  D-008/9
                      │ │
                      └─┴─ same container-creation mechanism
                              │
                        container backend (Docker / Apple Container)
                              │
                        one agent container per task (or per CLI session)
```

## Lifecycle of a task

1. **Authored.** A task folder exists with description, references,
   dependencies, and verification script (`concept/task-format.md`). Status:
   `draft`.
2. **Ready.** The human marks the plan (or task) ready. The daemon notices
   (D-005).
3. **Runnable.** All dependencies are `done`. The scheduler picks it up,
   subject to resource limits (Q-010).
4. **Running.** The manager asks the jackin daemon to start an isolated agent with the
   right role, mounts the repository and the task folder, and hands the agent
   a prompt of the shape:

   ```text
   /goal Read this file: <task folder>/TASK.md

   Implement it fully until ./verify.sh returns status: DONE
   ```

   The agent is expected to use research and verification subagents (D-007).
5. **Verifying.** When the agent reports completion (or on a schedule), the
   manager runs the task's `verify` in the task's environment and reads the
   status.
6. **Done** if `DONE`; otherwise **failed** and the failure policy applies
   (Q-008): retry, change runtime, split, or escalate.
7. **Merged.** The task's result is integrated according to the merge
   strategy (Q-007). Dependents become runnable.

A plan is `done` when every task is `done` and any plan-level verification
passes.

## Daemon behavior

- Runs continuously alongside the jackin daemon on a host (same binary or
  separate, Q-001); on multi-host setups it connects to each host's jackin
  daemon.
- Watches the roadmap source of truth (Q-003) for changes.
- Keeps a durable run ledger: every dispatch, verification result, retry,
  and escalation, so a restart resumes rather than repeats.
- Enforces limits: concurrent agents per host, per provider account, per
  plan.
- Exposes state to the terminal interface and, later, to desktop and phone.

## Human interaction model

The human does three things: writes or approves the roadmap, marks it ready,
and answers escalations. Everything else is unattended. The interface must
make the third thing fast: a decision inbox where each item carries the
evidence needed to decide and a small set of actions.

## What this borrows from existing research in jackin

jackin's repository already contains design research for a planner/worker
"Conductor", a durable run ledger, typed steps, queue configuration, and a
`jackin-remote` daemon — all marked incomplete with no code
(`analysis/jackin.md`, section 9). The manager should treat that research as
input, not as a design to copy unchanged: it predates the small-task
finding that drives D-003.
