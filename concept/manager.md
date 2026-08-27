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
- **Task system = Linear (D-010):** the only tracker. Source of truth for
  what work exists and its status. GitHub hosts repositories and pull
  requests only (D-014). The daemon
  is its consumer through a tracker adapter; the manager logic (scheduling,
  verification policy, inbox) sits between the tracker and the daemon, in
  the daemon binary or beside it (Q-001).

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

## Lifecycle of an issue

1. **Authored.** A human creates an issue in the tracker. Its Markdown
   holds a checklist of tasks (D-013) and it defines the jackin role, the
   agent runtime, and the prompt (D-012, convention Q-013).
2. **Assigned.** The human assigns the issue to jackin (D-011). The daemon
   notices (D-005) and validates the three required fields; a missing one
   is reported back on the issue and the issue is not started.
3. **Runnable.** Not blocked by other issues (Q-004) and within resource
   limits (Q-010).
4. **Picked up.** The daemon reads the issue once, prepares the workspace
   for the named repository and branch (reuse and pull if the branch exists
   on the remote, otherwise create from the base branch, default `main`,
   D-014), stores the checklist Markdown locally in the working copy, and
   spawns the named jackin role
   with the named runtime through the same container mechanism as the CLI
   (D-009), handing it the issue's prompt via `/goal`, pointing at the
   local checklist file.
5. **Working.** The agent works through the checklist, using research and
   verification subagents (D-007). Each time it finishes an item it updates
   the local file; the daemon pushes that progress back to the issue. No
   other tracker traffic occurs while working.
6. **Verifying.** Verification (`verify.sh`, D-003) is run by the daemon
   where the issue provides it; the relation between checklist items and
   verification is Q-014.
7. **Done** when the checklist is complete and verification passes; the
   daemon reports completion on the issue. Otherwise **failed** and the
   failure policy applies (Q-008): retry, change runtime, split, or
   escalate.
8. **Pull request.** The daemon opens or updates the pull request on
   GitHub from the task's branch. Merge follows the merge strategy (Q-007).
   Issues blocked by this one become runnable.

## Daemon behavior

- Runs continuously alongside the jackin daemon on a host (same binary or
  separate, Q-001). Prototype: the developer's own computer with local
  Docker (D-017); later a server host; later several hosts, each with its
  own daemon.
- Watches the tracker for assignments (D-011), by webhook or polling
  (Q-015).
- Holds no authoritative task state (D-010). It keeps a local run ledger
  (dispatches, verification results, retries, escalations) and reconciles
  it against the tracker and the container backend on every tick and after
  restart, so a restart resumes rather than repeats.
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
