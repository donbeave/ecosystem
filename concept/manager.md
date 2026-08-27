# The manager

Working name: "the manager" (Q-002, closed by D-066). This document describes how it is
meant to work. Everything here elaborates decisions in `DECISIONS.md`; the
Symphony-derived rules D-018..D-031 are adopted (D-053) and cited by number.
The manager logic ships inside the jackin daemon binary for the prototype
(Q-001 adopted, D-053; revisited at multi-host, D-026).

## Responsibilities

The manager owns everything between "a plan exists" and "every task of the
plan is verified `DONE`":

| Responsibility | What it means |
| --- | --- |
| Roadmap | Holds plans and their tasks, their status, and their dependency graph. |
| Watching | Detects when a plan or task becomes ready or changes status (D-005). |
| Analysis | Decides for each task whether it is runnable, which role and agent runtime fit, and what environment it needs. |
| Dispatch | Starts one isolated jackin agent per runnable task, in parallel when dependencies allow (D-004). |
| Verification | Runs each task's verification contract, records the outcome, applies the failure policy (D-021, D-027, D-030). |
| Escalation | Routes genuine decisions to the human as a blocker brief and feeds the answer back into the session (D-029); surfaces harness-level blocks (D-051). |
| Reporting | Syncs live run status, including container identity, to Linear (D-049, D-052); exposes a state snapshot (D-025) that the termrock terminal interface reads (D-006). |

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
  the daemon binary (Q-001 adopted, D-053).

## Layering

```text
human ── termrock TUI ──┐
                        ├── task system = Linear (issues, status)     D-010
human ── jackin CLI ──┐ │
      (unchanged)     │ │  takes tasks, reports status
                      │ manager logic (scheduler, verification, inbox) D-053 (in daemon)
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

1. **Authored.** An agent creates the issue in the tracker from the task
   folder (D-067; M1-12 for this roadmap). Its Markdown holds a checklist
   of tasks (D-013) and it defines the jackin role, the agent runtime,
   model, effort, delivery, repository, and branch (D-012, D-014, D-043,
   D-044; convention in `concept/task-format.md`, D-053). Every roadmap
   issue carries the `auto-dispatch` label; a follow-up an agent creates
   during work stays unassigned in the backlog unless its parent issue
   carries that label (D-067).
2. **Assigned.** The issue is assigned to jackin by an agent, in dependency
   order, with no human in the loop (D-067; outside this roadmap the
   D-011 default still applies). The daemon
   notices (D-005, by polling: 5 s for sessions and delegated issues, 30 s
   reconciliation, D-053) and validates the required fields; a missing one
   is reported back on the issue as one `error` activity and the issue is
   not started.
3. **Runnable.** `dispatchable` is true (delegate is jackin, active state,
   every `blocks` relation resolved, fields valid; D-020) and a slot is free
   under the host, repository, state, and provider-account caps (D-022;
   laptop, D-056 as amended by D-071: 6 per host, 1 per Codex home, 2 for
   `~/.claude`, 1 for `crew-operator`).
4. **Picked up.** The daemon reads the issue once, prepares the workspace
   for the named repository and branch (reuse and pull if the branch exists
   on the remote, otherwise create from the base branch, default `main`,
   D-014), reads `.jackin/workflow.toml` and the prompt frame from the base
   branch (D-018), stores the issue and checklist Markdown locally in the
   working copy (the tracker token never enters the container, D-023), and
   spawns the named jackin role with the named runtime, model, effort, and
   account through the same container mechanism as the CLI (D-009) as an
   ordinary attachable capsule session (D-024), delivering the prompt per
   the delivery mode (`/goal` by default, D-044) and pointing at the local
   checklist file. The container is labeled with the issue and attempt,
   the binding goes into the ledger (D-019), and the issue immediately
   shows the container identity — host, instance name, container id,
   attempt, attach command — in the session `externalUrls` (D-052).
5. **Working.** The agent works through the checklist, using research and
   verification subagents (D-007). Each time it finishes an item it updates
   the local file; the daemon pushes that progress back to the issue. The
   daemon also writes one activity per run-state transition and a heartbeat
   every 10 minutes with "last progress at" (D-049); no other writes
   (the candidate and session polls and the pre-write `description` read
   are not issue-content reads, D-081).
5a. **Blocked.** The agent inside the container stops on something the
   daemon did not cause — a permission prompt, a tool refusal, a
   confirmation, any wait for input. The capsule exposes this state for
   every runtime; the daemon sets the run to `blocked` in Linear with the
   reason as far as known and the attach target, so the human knows to
   `hardline` into that container. The state clears automatically when the
   agent resumes (D-051). A block that outlasts the stall window is
   escalated (D-021, D-029) rather than retried. Distinct from **waiting
   for input** (the daemon posted an elicitation and awaits the human's
   reply, D-029) and from **stuck** (no capsule activity within the
   5-minute stall window, D-021, D-049).
6. **Verifying.** Verification (`verify.sh`, D-003) is run by the daemon
   from the repository's `[verify] command` inside the same container via
   exec-with-result, accepting only a final `status: DONE`; checklist items
   carry no individual verification (D-030).
7. **Done** when the checklist is complete and verification passes; the
   daemon marks the PR ready, moves the issue to the review state, and
   posts a `response`. Review never gates what follows: `crew-reviewer`
   tasks run in parallel with the next task and their findings become
   follow-up checklist items on the issue they reviewed (D-055). Otherwise **failed** and the retry policy applies
   (D-021, D-027): continuation after a clean exit, bounded backoff for
   agent-class failures, hold with a comment for config and workspace
   failures; each attempt is a new container in the same workspace and
   each attempt's container is recorded on the issue (D-052). Exhausted
   attempts enter `blocked` with a blocker brief delivered as an
   elicitation (D-029). **Lane fallback (D-057):** on provider quota
   exhaustion or a stuck run past the recovery threshold, and after the
   stuck rule has run (D-063: subagents analyze first), the daemon
   re-launches the attempt on the lane's fallback (`ROADMAP.md` §5: stuck
   chain L1→L2→L3→L4→L5→L6→L1; quota exhaustion skips every lane sharing
   the exhausted account home and consumes no attempt, D-071), switching
   account home, runtime, and model together; the ledger records each
   attempt's lane. Implemented by M6-05; by hand before that, recorded in
   `PROGRESS.md` only, never as a preflight defect (D-071).
8. **Pull request and merge.** The daemon opens or updates the pull
   request on GitHub from the task's branch (D-014). The agent merges it
   itself, using the forwarded `gh` identity, whenever its task text names
   the merge — that text is the per-PR authorization and carries the fixed
   "Authorization (D-055)" section (D-055, D-079); the daemon then moves
   the issue to the merging state. Work the roadmap does not need merged
   stays on `feat/managed-execution` (D-055). One `merge` attempt per
   repository at a time brings the branch up to date and merges; the daemon confirms the
   merge, sets `Done`, and removes the workspace (D-031). Issues blocked by
   this one become dispatchable on the next tick.

## Daemon behavior

- Runs inside the jackin daemon binary on a host (Q-001 adopted, D-053).
  Prototype: the developer's own computer with local Docker (D-017); later
  a server host; later several hosts, each with its own daemon and one
  manager placing runs (D-026).
- Watches the tracker for assignments (D-011) by polling only: 5 s for
  pending sessions and delegated issues, 30 s reconciliation; no webhook is
  needed for correctness (Q-015 adopted, D-053).
- Holds no authoritative task state (D-010). It keeps a local,
  non-authoritative ledger (claims, attempts with kind and terminal reason,
  blocked entries with their brief, retry due times, container-to-issue
  bindings per attempt) and reconciles it against the tracker and the
  container backend on every tick and after restart, adopting labeled
  containers still running, so a restart resumes rather than repeats
  (D-019).
- Enforces slots per host, repository, repository state, and provider
  account, and sorts candidates by priority, age, identifier (D-022).
- Falls back to the next lane on quota exhaustion or stuck, chains
  wrapping across accounts, runtimes, and models (D-057).
- Keeps every in-progress issue's Linear session current: run-state label
  and activity on each transition, heartbeat with last progress, the
  container identity in `externalUrls` from launch to removal and across
  retries (D-049, D-052); detects harness-level blocks through the
  capsule's agent state and marks the run `blocked` with reason and attach
  target until the agent resumes (D-051); marks `stuck` after the stall
  window (D-021).
- Exposes a synchronous state snapshot (`running`, `retrying`, `blocked`,
  `stuck`, totals, attach target per row) over its socket for the terminal
  interface and, later, desktop and phone; it is correct with none of them
  present (D-025).
- Asks the operator for nothing mid-run: every operator input is collected
  in the milestone preflight before agents start; a missing input is a
  preflight defect and the task is marked blocked with the exact item
  (D-050).

## Human interaction model

The human does two things: writes or approves the roadmap, and supplies
inputs only a human can supply — a login, an OTP, a consent screen, billing,
a credential created in a UI, physical hardware. Everything else is
unattended: issues are created and assigned by agents (D-067), agents merge
their own pull requests when the task text authorizes it (D-055, D-079),
and no review, merge, or confirmation waits on a person (D-050, D-055).

There is no human decision inbox and no approval queue. What an agent cannot
resolve itself is escalated in the tracker (D-029, D-068) or, when it is an
input only a human can provide, filed as a preflight defect with the command
that proves it in place while the rest of the roadmap keeps running (D-050,
D-070). The interface must therefore make one thing fast: seeing what is
running, what is blocked, and on which named missing input.

## What this borrows from existing research in jackin

jackin's repository already contains design research for a planner/worker
"Conductor", a durable run ledger, typed steps, queue configuration, and a
`jackin-remote` daemon — all marked incomplete with no code
(`analysis/jackin.md`, section 9). The manager should treat that research as
input, not as a design to copy unchanged: it predates the small-task
finding that drives D-003.
