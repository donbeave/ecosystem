# Decisions

Dated log of agreed decisions. Newest at the bottom. A decision is the only
thing that makes a statement "true" for this project; concept documents
elaborate decisions, they never precede them.

Format: `D-NNN` — date — title — decision — rationale — consequences.

---

## D-001 — 2026-08-27 — This repository is planning only

**Decision.** `ecosystem/` contains Markdown only: vision, decisions, concept
documents, analyses of existing repositories. No source code, prototypes, or
scaffolding until the concept is aligned and a separate implementation plan
says so. (Amended by D-038: verification scripts inside `tasks/<task>/` are
the one permitted runnable file type; amended by D-069: the single
roadmap-level gate `verify.sh` at the repository root is the other.)

**Rationale.** Planning is the critical phase. Implementing before the concept
is agreed produces the same context-loss failure at project scale that large
plans produce at agent scale.

**Consequences.** Every conversation that reaches agreement updates these
files. `AGENTS.md` encodes the rules.

## D-002 — 2026-08-27 — The goal is a manager for many agents on big tasks

**Decision.** The new project is a manager: it owns roadmaps, plans, and
tasks; it decides which agent starts on what and when; it verifies results.
It may be part of jackin (as a daemon) rather than a separate product; that
placement is still open (see `OPEN-QUESTIONS.md`).

**Rationale.** jackin already solves isolated execution of one agent. The
missing layer is scheduling, dispatch, and verification across many agents.

**Consequences.** jackin is the execution substrate, not something to
reimplement. Changes to jackin are planned only where the manager needs them.

## D-003 — 2026-08-27 — Plans are decomposed into small, independently verifiable tasks

**Decision.** A plan is stored as a set of tasks. Each task lives in its own
folder with a description of what must be done, references to the source of
truth it must satisfy, and a verification script whose success output is the
literal status `DONE`. An agent is given exactly one task.

**Rationale.** Observed: agents given one small task with a clear verification
are markedly more accurate than agents given the whole plan. Per-task
verification scripts make unattended execution possible.

**Consequences.** The task format is a first-class contract (see
`concept/task-format.md`). The whole plan may remain in the repository as
context, but the prompt restricts the agent to one task.

## D-004 — 2026-08-27 — Independent tasks run in parallel

**Decision.** Tasks declare dependencies. Tasks with no unsatisfied
dependencies are runnable concurrently, each with its own isolated agent.

**Rationale.** Decomposition makes parallelism free; the manager's job is to
exploit it.

**Consequences.** The manager needs a dependency graph, a scheduler, and a
strategy for merging parallel results (open question).

## D-005 — 2026-08-27 — The manager watches the roadmap and acts on changes

**Decision.** The manager runs as a daemon. When the human marks a plan or
task as ready, or task status changes, the daemon detects it and starts
analyzing and executing runnable tasks without a further command.

**Rationale.** The manual ritual — start a session, build a plan, start
another agent, paste a prompt — is the problem being solved. "I say it's
ready, it runs" is the target interaction.

**Consequences.** Roadmap state needs a machine-readable source of truth the
daemon can watch (open question: files on a branch, a database, or both).

## D-006 — 2026-08-27 — termrock is the component layer for every TUI

**Decision.** Every Tailrocks terminal interface, including the manager's,
is built from termrock components. Product-specific widgets are built on top
of termrock, and generic gaps are landed in termrock, not duplicated in the
product.

**Rationale.** One design system keeps all terminal surfaces consistent and
lets a small team maintain them. Duplication already exists in jackin
(`analysis/termrock.md`) and is the pattern to stop.

**Consequences.** The termrock gaps listed in `analysis/termrock.md` become
part of the plan; jackin's duplicated widgets are scheduled for removal.

## D-007 — 2026-08-27 — Research and verification subagents are part of the method

**Decision.** Task execution is expected to use subagents for research before
implementation and for verification after it, in addition to the task's
verification script.

**Rationale.** Observed to raise result quality.

**Consequences.** Roles and skills used by the manager's agents must support
this pattern; the manager may need to make it explicit in the task prompt.

## D-008 — 2026-08-27 — jackin gets its own long-running daemon that owns containers

**Decision.** jackin gains a real daemon: a long-running process on each
host that spawns agent containers programmatically (not through a foreground
CLI session), keeps track of every container it started, and continuously
verifies where each one runs and what state it is in. The daemon is the only
component that talks to the container backend for agent runs.

**Rationale.** Unattended execution needs a process that outlives any single
CLI invocation and that can answer "what is running, where, and in what
status" at any time. Today jackin runs one agent per foreground session and
its host daemon is an empty shell (`analysis/jackin.md`), so nothing can
report fleet status or start agents on behalf of another program.

**Consequences.**

- The daemon exposes a programmatic interface: start an agent container with
  a role, mounts, and brief; list containers with live status; stream events;
  stop or restart. The manager is a client of this interface.
- Container status tracking is a daemon responsibility, including
  reconciliation after daemon restart (adopt containers still running, mark
  lost ones).
- Q-012 is closed: a task run maps to a container started by the daemon,
  observed through the daemon. Q-001 is narrowed: the manager sits on top
  of the jackin daemon; whether it ships in the same binary is still open.

## D-009 — 2026-08-27 — jackin CLI stays as it is; the daemon is additive

**Decision.** jackin itself is not redesigned. The existing commands keep
working unchanged and keep creating the same containers the same way. The
daemon is added beside them with two jobs: monitor the containers on its host
(whether started by the CLI or by the daemon), and connect to a task system
where the human provides tasks, taking tasks from there and executing them by
creating containers through the same mechanism the CLI uses.

**Rationale.** The isolation and role model already works and is in daily
use; changing it risks the thing that is not broken. The missing capability
is unattended execution and observation, which an additive daemon provides
without touching the interactive path.

**Consequences.**

- No breaking change to jackin's commands, config schemas, or role contract
  is planned by this project. Where the daemon needs a capability the CLI
  path lacks (detached launch, programmatic brief injection, execute-and-
  return for verification), it is added as a shared internal path that the
  CLI may also use, never as a replacement.
- The daemon reconciles against the container backend, so containers started
  interactively appear in the same status view as daemon-started ones.
- The "task system" the daemon connects to is a separate concern from the
  daemon: it is where roadmaps and tasks live and where status is reported.
  Its form is Q-003 (files on a branch, a service, or both). The daemon is a
  consumer of that system.
- D-008 stands; this decision narrows how it is achieved.

## D-010 — 2026-08-27 — The task system is an issue tracker, following the Symphony concept

**Decision.** Tasks are provided through an issue tracker, in the same
concept as openai/symphony (`analysis/symphony.md`): the tracker is the
source of truth for what work exists and its status; the daemon holds no
authoritative task state of its own and rebuilds its view from the tracker
and local workspaces after restart. **Linear is the only tracker.** GitHub
is not a task source: it is used only to host the repository a task works
on and to manage the pull request that carries the result. (Superseded
wording from earlier the same day: GitHub Issues was briefly considered as
a second adapter; that is withdrawn.)

**Rationale.** The human already thinks in issues. A tracker gives
assignment, status, comments, and history for free, with a native UI on
desktop and phone, and Symphony proves the dispatch loop works at scale.
Git-tracked task folders remain possible as plan content but are no longer
the task system.

**Consequences.** Q-003 is closed. The daemon needs a Linear adapter and
a GitHub repository/PR adapter; no GitHub Issues adapter. The task-folder layout in
`concept/task-format.md` is demoted to "the local working copy of an issue",
not the source of truth.

## D-011 — 2026-08-27 — Assignment is the trigger

**Decision.** When an issue is assigned to jackin in the tracker (Linear:
the jackin agent app, installed with `app:assignable`), the jackin daemon
picks it up and spawns a jackin role to work on it. Creating an issue alone
does not start work; assignment does.

**Rationale.** Assignment is the natural human gesture for "you, do this",
is visible in the tracker, and is exactly the event Linear's agent platform
is built around.

**Consequences.** The daemon subscribes to (or polls for) assignment events.
Work is never started from an unassigned issue.

## D-012 — 2026-08-27 — The issue defines the role, the agent runtime, and the prompt

**Decision.** Every issue that jackin executes must define three things:
(1) the jackin agent role to spawn (for example `the-architect`, designed as
in https://github.com/jackin-project/jackin-the-architect); (2) which agent
runtime to use inside that role (Claude Code, Codex, Amp, ...); (3) the
prompt to pass to the agent. The daemon refuses issues that lack any of the
three and reports why on the issue.

**Rationale.** The role fixes the environment and skills, the runtime fixes
the model and behavior, the prompt fixes the work. Keeping all three on the
issue means the human controls the run entirely from the tracker and the
daemon never guesses.

**Consequences.** A convention for expressing the three on a Linear issue is
needed (labels, template fields, or a description block) — see
`analysis/linear-agents.md` when available and Q-013. Roles must be
resolvable by name to a published image.

## D-013 — 2026-08-27 — The issue carries a Markdown checklist that the agent mirrors locally and reports back

**Decision.** The issue's Markdown (the description or an attached Markdown
file) contains a checklist of the tasks to be done. The daemon reads it once
when it picks the issue up, stores it locally, and the agent works on the
local copy through the `/goal` command. The local file is the working status
tracker: the agent updates it only when it finishes a checklist item, and on
each such update the progress is pushed back to the tracker so the issue
shows clear progress. The daemon does not make repeated reads of the
tracker while working; it reads once and writes on completion of items
(and, per D-049, on every run-status change and heartbeat).

**Rationale.** One read plus write-on-progress keeps tracker traffic and
rate-limit exposure minimal, keeps the agent's working state local and
fast, and gives the human progress in the tool they already watch.

**Consequences.** The checklist format is part of the task contract
(`concept/task-format.md`). Write-back is idempotent (re-pushing the same
checklist is safe). Per-item verification (`verify.sh`, D-003) applies to
checklist items where present; how checklist items and verification
scripts relate is Q-014.

*Amended by D-081: the candidate, session, and activity polls and the
pre-write `description` read are not issue-content reads.*

## D-014 — 2026-08-27 — A task names its repository and its branch; branches are created or reused

**Decision.** Every task specifies the GitHub repository it works on and
the branch name to use. The daemon prepares the workspace as follows: if the
branch exists on the remote, it is pulled and reused; if it does not exist,
it is created from a base branch that the task may specify, defaulting to
`main`. The result of the work is managed as a pull request on GitHub from
that branch.

**Rationale.** The repository and branch are the two facts that make a task
concrete. Reusing an existing branch lets several tasks, or a retried task,
continue the same line of work; a declared base branch (default `main`)
removes any guessing about where a new branch starts.

**Consequences.**

- Repository, branch, and optional base branch join role, runtime, prompt,
  and checklist as issue fields (`concept/task-format.md`, convention
  Q-013). A missing repository or branch is a validation failure reported
  on the issue.
- The daemon performs the git preparation before spawning the agent, so
  the agent starts on the right branch; the agent does not choose branches.
- Pull request creation and updates are a daemon responsibility through
  GitHub; how this interacts with the merge strategy is Q-007.

## D-015 — 2026-08-27 — Any agent runtime; jackin is an ecosystem, never a harness

**Decision.** The manager works with any agent runtime jackin supports —
Claude Code, Codex, Amp, Kimi, OpenCode, Grok, and future ones — and
communicates with them only through jackin and jackin agent roles. Neither
jackin nor the manager builds an agent harness of its own; the harnesses
shipped by the agent vendors are used as they are, and the ecosystem is
built around them.

**Rationale.** This is the defining difference from openai/symphony, which
drives Codex through its app-server protocol. Vendors' harnesses are good
and keep improving; competing with them is wasted effort and locks the user
to one model.

**Consequences.** Nothing in the design may depend on a runtime-specific
protocol. Anything the manager needs from an agent (prompt in, progress
out, completion signal) must be expressible for every runtime through the
role contract and the container, not through a vendor API. Runtime
selection is per issue (D-012).

## D-016 — 2026-08-27 — Live visibility through the jackin capsule is preserved

**Decision.** Every agent the manager starts runs in a jackin container with
the jackin capsule, so a human can attach to that specific container at any
time and watch the live session: the exact prompt that was passed and what
the agent is doing right now. The manager never launches agents in a way
that removes this ability.

**Rationale.** Seeing the real prompt and the real session is the most
understandable form of observability and jackin provides it out of the box.
Dashboards summarize; attach shows the truth.

**Consequences.** "Detached" or programmatic launch (needed by the daemon,
`analysis/linear-agents.md`) must keep a capsule session that supports
attach; headless runs that only capture stdout are not acceptable. The
manager's TUI lists running containers and offers attach as a first-class
action (Q-011).

## D-017 — 2026-08-27 — First prototype runs everything locally

**Decision.** The first prototype runs entirely on the developer's own
computer: the jackin daemon listens to Linear, spawns roles in local Docker,
and the human watches through the local TUI and capsule attach. No server,
no remote hosts, no multi-host coordination until the local loop is fully
workable end to end. Afterwards the same daemon moves unchanged in concept
to a server host where Docker is available.

**Rationale.** jackin was designed from the start to run on any host with a
container backend, so the local machine is a valid first host and the
cheapest place to iterate. Multi-host adds failure modes that would slow
down validating the core loop.

**Consequences.**

- Q-010 is narrowed: for the prototype, resource limits are per local
  machine only (concurrent containers, provider accounts).
- Q-015 is constrained: the local machine is typically behind NAT, so the
  prototype's Linear event path must work without a public endpoint
  (polling, a tunnel, or a relay) — the choice stays open but "webhook to
  the laptop directly" is excluded for the prototype.
- Design decisions must not bake in "single host" assumptions that would
  block the later server move (for example, workspace paths, credential
  lookup, and the ledger must be host-relative, not hard-coded to a laptop
  layout).
- Milestone ordering: local end-to-end loop first; server host second;
  multi-host third.

## D-018 — 2026-08-27 — Each repository carries a managed-work workflow file

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** A repository worked on by the manager may contain
`.jackin/workflow.toml` and an optional `.jackin/WORKFLOW.md`. The TOML
holds machine settings for managed runs in that repository: `[hooks]`
`after_create`, `before_run`, `after_run`, `before_remove`,
`timeout_seconds`; `[verify] command`; `[limits] max_concurrent`,
`max_concurrent_by_state` (for example `merging = 1`), `max_attempts`,
`max_continuations`, `minutes`; `[defaults] role`, `runtime`,
`base_branch`; `[states] review`, `merging`. The Markdown is a strict
template (variables `issue`, `attempt`, `attempt_kind`, `last_error`,
`checklist_path`) rendered around the issue's prompt and must end with
the repository's completion bar. The daemon reads both from the issue's
base branch at every dispatch; a change takes effect on the next attempt
and never alters an attempt in flight. A file that fails validation
holds that repository's issues with a comment and does not affect other
repositories. Absent files mean built-in defaults.

**Rationale.** Symphony §1, §5, §6.2: policy versioned with the code,
reloaded without restart. Tracker and agent-environment settings already
live elsewhere in our model (daemon config; the role), so only
repository-specific policy is left, and git provides the reload.

**Consequences.** Closes the "per-repository equivalent of WORKFLOW.md"
question. Q-014 gets its verification command location. Symphony's
`required_labels` stays daemon-level.

## D-019 — 2026-08-27 — The daemon keeps a local, non-authoritative run ledger

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** The tracker remains the only authority for what work
exists and its state (D-010). The daemon additionally persists a local
ledger (per host, SQLite or equivalent) of claims, attempts with kind
and terminal reason, blocked entries with their blocker brief, retry due
times, and container-to-issue bindings. On restart the daemon rebuilds
its view from the tracker, adopts running containers labeled with an
issue identifier, and reloads attempt counts and blocked entries from
the ledger; it never treats the ledger as proof that an issue is active.

**Rationale.** Symphony §7.4, §14.3 rebuild from tracker and filesystem
but lose retry timers and blocked state, which their own §18.2 marks
TODO. Bounded retries (D-021) and durable escalations (D-029) need the
counts to survive a restart.

**Consequences.** D-010 wording "holds no authoritative task state"
stands; the ledger is a cache with extras. The termrock TUI reads
history from the ledger.

## D-020 — 2026-08-27 — Dispatchability and issue states on Linear

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** The Linear adapter derives one boolean `dispatchable` per
issue. It is true only when: the issue's `delegate` is the jackin app
user (D-011); the workflow state has type `unstarted` or `started` and
is neither the repository's review state nor its merging state; every
issue in `inverseRelations` of type `blocks` has a state of type
`completed` or `canceled`; and the required fields of D-012 and D-014
validate. Terminal means state type `completed` or `canceled`: the run
is stopped and the workspace removed. Any other state, or removal of the
delegate, is non-active: the run is stopped and the workspace kept.
Blockers gate dispatch only; a running issue is not stopped because a
blocker reopened. The daemon's internal claim states are `unclaimed`,
`claimed`, `running`, `retry_queued`, `blocked`, `released`. An issue
held by a blocker or a validation failure gets one comment saying why;
the condition is re-evaluated every tick.

**Rationale.** Symphony §4.1.1, §8.2, §8.5, §11.3: adapter-owned
`dispatchable`, scheduler-owned everything else, blockers as a
dispatch-time gate re-evaluated each poll.

**Consequences.** Closes Q-004. `Human Review`-style states are simply
non-dispatchable, so no agent burns tokens while a human reviews.

## D-021 — 2026-08-27 — Retry, backoff, stall, and workspace reuse

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** After a clean agent exit with an incomplete checklist the
daemon starts a `continuation` attempt after 1 s, up to
`max_continuations` (default 20). After a failure the delay is `min(10 s
* 2^(attempt-1), 5 min)`, up to `max_attempts` (default 3); only
agent-class failures count (D-027). A run with no capsule status
transition for `stall_timeout` (default 5 min) is killed and retried; a
run in capsule state `Blocked` is escalated (D-029) instead. Each
attempt is a new container session in the same workspace directory on
the same branch; the workspace is reset to the base branch only for
`rework` attempts (closed or merged PR) and removed only on terminal
state. The prompt receives `attempt`, `attempt_kind`, and `last_error`.
When attempts are exhausted the issue enters `blocked` with a blocker
brief.

**Rationale.** Symphony §7.1, §8.4, §8.5, §9.1, §12.3 minus the
unbounded retries their own implementation is criticized for. Reuse is
what makes "resume from the current workspace state" possible; D-014
already reuses the branch.

**Consequences.** Closes Q-008. Supersedes the
fresh-container-per-attempt lean in `analysis/symphony.md` §10.

## D-022 — 2026-08-27 — Concurrency caps and dispatch order

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** Slots are enforced at four levels, all from configuration:
per host (`max_concurrent_agents`, daemon), per repository
(`[limits].max_concurrent`), per repository state
(`max_concurrent_by_state`, with `merging = 1` the expected use), and
per provider account (daemon, using jackin's usage broker). Candidates
are sorted by Linear priority 1..4, then oldest `createdAt`, then
identifier. When every host is at capacity the manager waits; it never
falls back to another execution mode.

**Rationale.** Symphony §8.2, §8.3, Appendix A.2.

**Consequences.** Narrows Q-010 to "which per-container resource limits
to pass to jackin", which is jackin's `[docker.grants]` surface.

## D-023 — 2026-08-27 — Tracker credentials never enter the container; the daemon is the only tracker writer

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** The Linear token is held by the daemon only. The daemon
pre-fetches everything the agent needs from the issue into the workspace
(`.jackin/issue/ISSUE.md`, the checklist file, linked documents,
attachment URLs) before launch. All tracker writes (acknowledgement,
plan, checklist ticks, state changes, PR links, elicitations,
completion, errors) are made by the daemon. If a role needs a tracker
read the daemon did not pre-fetch, it is exposed as a `jackin-exec`
binding executed host-side with a scope limited to the current issue;
the raw token is never in the container environment or filesystem.

**Rationale.** Symphony §3.3, §10.5, §11.5, §15.3 scrub tracker secrets
from the child and execute tools host-side; D-013 already made the
daemon the writer.

**Consequences.** The Linear adapter gains a small write surface. GitHub
credentials are unchanged: jackin forwards them so the agent can push
and open or merge PRs.

## D-024 — 2026-08-27 — Managed runs are ordinary attachable jackin sessions

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** The daemon starts every managed run as a jackin instance
whose agent runs interactively on the capsule PTY with the rendered
prompt delivered into that session at start. The daemon never uses a
harness's non-interactive print or exec mode. Continuation guidance and
human replies from Linear `prompted` events are sent into the same PTY.
A human can `hardline` into any managed container at any time and see
the exact prompt and the live session; the fleet view exposes the attach
target for every running row.

**Rationale.** Fixed difference 3. Symphony §10 owns the session through
a protocol; we own it through the capsule, which already exists.

**Consequences.** jackin needs prompt delivery and text injection into a
session (see the gap list).

## D-025 — 2026-08-27 — The daemon exposes a state snapshot; no UI is on the correctness path

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** The daemon answers a synchronous state query over its
socket returning `running`, `retrying`, `blocked`, per-host totals,
provider rate limits, and `generated_at`; each row carries issue id and
identifier, issue URL, repository, branch, attempt and kind, host,
container, capsule agent state, last event and its time, usage, and the
attach target. Per-issue detail and a "refresh now" trigger are also
provided. The termrock TUI, desktop, and phone surfaces read this; the
daemon runs and is correct with none of them present. Logs are
structured and carry `issue_id`, `issue_identifier`, `attempt`, `host`,
`container`, and `session_id`.

**Rationale.** Symphony §13.1, §13.3, §13.4, §13.7.

**Consequences.** Fixes the daemon side of Q-011; the product-side scope
of the TUI stays open.

## D-026 — 2026-08-27 — Multi-host: one manager, one jackin daemon per host

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** The manager talks to one jackin daemon per host. A run's
identity is `(issue, host, attempt)`. Placement picks the least-loaded
host with capacity; retries prefer the previous host because the
workspace lives there. A host that fails before an attempt produced side
effects is replaced by another host transparently; after side effects,
the rerun is a new attempt. A dead or saturated host reduces capacity
and never causes duplicate execution or fallback to local execution. The
snapshot (D-025) shows which host owns each run and its workspace.

**Rationale.** Symphony Appendix A, whose "problems to consider" are
exactly a multi-host jackin's problems. Roles remove the
environment-drift problem SSH workers have.

**Consequences.** Narrows Q-001: the manager is a client of N daemon
interfaces; whether it ships in the same binary as the daemon on the
first host remains open.

## D-027 — 2026-08-27 — Failure classes decide recovery

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** Failures are classified as workflow/config, workspace (git
preparation, hooks), agent (exit, stall, timeout, blocked past
deadline), tracker, or observability. Agent failures retry with backoff
and consume attempts. Config and workspace failures are reported on the
issue and hold it until the cause changes; they consume no attempts.
Tracker failures skip the tick or keep workers running and are retried
next tick. Observability failures never stop the daemon.

**Rationale.** Symphony §14.1, §14.2, §11.4.

**Consequences.** Part of Q-008's closure.

## D-028 — 2026-08-27 — Agent-proposed follow-up issues never dispatch by themselves

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** A role may propose follow-up work. The daemon creates such
issues in Linear on the agent's behalf, unassigned, in a backlog state,
linked as related (and `blocks` when stated) to the current issue. They
become work only when a human assigns them to jackin (D-011).

**Rationale.** Symphony's reference workflow files follow-ups into a
non-active state; combined with §8.2 this is the cheapest guard against
runaway self-generated work.

**Consequences.** Narrows Q-005: planner roles are allowed; their output
is issues awaiting human assignment.

## D-029 — 2026-08-27 — Escalation is a blocker brief delivered as a Linear elicitation

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** When a run reaches capsule state `Blocked`, exhausts
attempts, or the prompt frame's escape-hatch conditions are met, the
daemon posts a Linear `elicitation` activity containing a blocker brief:
what is missing, why it blocks the acceptance criteria, and the exact
human action needed. The issue enters the persisted `blocked` state. The
human's reply arrives as a `prompted` event and is sent into the same
session's PTY, which resumes the run; a `stop` signal ends it. The
prompt frame lists what may not be escalated (GitHub access is not a
valid blocker until documented fallbacks are exhausted).

**Rationale.** Symphony reference workflow "Blocked-access escape
hatch"; §10.5's "never stall indefinitely"; Linear's native elicitation
and session states (`analysis/linear-agents.md` A3).

**Consequences.** Narrows Q-009: the inbox is Linear's session UI first;
the termrock TUI mirrors it from the ledger.

## D-030 — 2026-08-27 — Completion bar for the agent, verification command for the daemon

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** Two distinct gates. The prompt frame's completion bar
(checklist done and mirrored, tests green, branch pushed, PR open and
linked, review comments addressed) is what the agent must satisfy before
it declares the checklist complete. Independently, when the local
checklist is complete the daemon runs the repository's `[verify]
command` inside the same container via exec-with-result and accepts only
a final line `status: DONE`. Only then does the daemon mark the PR ready
and move the issue to the repository's review state. Verification
failure is an agent-class failure with the script output as
`last_error`. Checklist items carry no individual verification; the
agent's own verification subagents (D-007) cover items, and the daemon
proves the whole.

**Rationale.** Symphony verifies nothing itself and relies on the
completion bar plus human review; our D-003 contract is stronger and the
two compose.

**Consequences.** Closes Q-014. Narrows Q-006: the verification command
is repository-owned and committed on the base branch, so the
implementing agent cannot rewrite it on its task branch.

## D-031 — 2026-08-27 — Merge is a human-triggered, agent-executed, daemon-confirmed attempt

*Proposed in `concept/borrowed-from-symphony.md`; adopted by D-053.*

**Decision.** A human moves an issue to the repository's `merging`
state. The daemon dispatches a `merge` attempt (same role and runtime,
same workspace, prompt frame section "land"), capped at one per
repository. The agent brings the branch up to date with the base branch,
resolves conflicts, repairs CI, addresses review comments, and merges
the PR with the GitHub credential jackin forwards. The daemon confirms
through GitHub that the PR is merged, moves the issue to `Done`, and
removes the workspace. Issues blocked by this one become dispatchable on
the next tick.

**Rationale.** Symphony's `land` and `pull` skills and its per-state cap
on `Merging`; D-014's PR ownership; D-023's credential rule.

**Consequences.** Narrows Q-007: no integration branch and no merge
queue in the first version; the cap serializes merges per repository.

## D-032 — 2026-08-27 — Implementation is verified visually with agent-browser on a persistent profile

**Decision.** During implementation, every step is verified against the
real Linear and GitHub user interfaces with `agent-browser` (visual
verification by the implementing agent), not only through API responses.
The browser uses one static profile that stays logged in to Linear and
GitHub for a long time; either a single long-lived session or several
sessions sharing that one profile. The same rule applies to both Linear and
GitHub.

**Rationale.** The human's view of progress is the Linear issue and the
GitHub pull request; if those do not look right, the feature is not done
regardless of what the API returned. A persistent logged-in profile removes
repeated logins and two-factor prompts from the verification loop.

**Consequences.**

- The implementation plan includes, for each milestone, a browser-based
  verification step (issue shows checklist ticks, agent session activities,
  elicitation, state transitions; PR opened, linked, merged).
- A dedicated browser profile directory for `agent-browser`, logged in to
  Linear and GitHub, is part of the development environment setup; its
  credentials come from 1Password and it is never committed.
- Roles used to implement this project (for example `the-architect`) must
  ship `agent-browser` and be able to reuse that profile.
- This applies to the implementation phase; it does not make the manager
  itself depend on a browser at runtime.

## D-033 — 2026-08-27 — This product is built with its own workflow

**Decision.** The manager is built using the workflow it implements: work
is defined as Linear issues with repository, branch, role, runtime, prompt,
and checklist; issues are assigned to jackin; jackin roles execute them in
containers; progress is pushed back to Linear; results arrive as pull
requests on GitHub. As soon as any part of the loop works, it is used to
build the next part. Until the daemon exists, the same issue contract is
executed by hand through `jackin load` with the same prompts.

**Rationale.** Dogfooding is a Tailrocks principle and the fastest way to
find where the workflow is wrong. A workflow the builders will not use is
not worth shipping.

**Consequences.** The Linear workspace, the repositories (jackin, termrock,
this one), the roles, and the browser profile (D-032) are set up first, as
the first milestone. Every later milestone is a set of Linear issues.

## D-034 — 2026-08-27 — Iterate fast and locally on the latest jackin

**Decision.** All work targets the latest jackin version and improves from
it; nothing is built against an older release. Changes to jackin go to its
`main` branch through one or more pull requests, and a new jackin version
is released when needed, but the preferred mode is a single working branch
that is installed locally from the branch (jackin supports local install
from a branch) and used to verify everything on the local machine. Nothing
waits for CI/CD to build or publish; local builds and local verification
are the default, and CI is confirmation, not a gate on iteration speed.

**Rationale.** Speed of iteration is the constraint that matters in this
phase. CI is slow relative to a local build; a locally installed branch
gives the same binary minutes earlier.

**Consequences.**

- Development environment setup includes building and installing jackin
  from the working branch locally, plus rebuilding roles locally instead of
  waiting for `jackin-role-action` to publish images.
- Branch discipline: one long-lived working branch per repository for this
  effort where possible; split into several pull requests only when a
  piece is independently releasable.
- Releases of jackin happen when a milestone needs a published version
  (for example for a role image that pins one), not on a schedule.
- `SPEC.md` and the implementation plan record "verified locally" as the
  completion criterion for a step; CI green is recorded afterwards.

## D-035 — 2026-08-27 — Every credential is created into 1Password

**Decision.** Whenever a credential is created — Linear agent app client id
and secret, OAuth tokens, GitHub tokens, browser profile logins, API keys
for any provider, anything else — it is stored in 1Password at creation
time and referenced from there (`op://` references) by every component
that uses it. No credential is written into a config file, an environment
file committed to git, a role image, a Markdown document, or a chat.

**Rationale.** 1Password is the credential provider for every Tailrocks
product (vision); a credential that exists outside it is a leak waiting to
happen and cannot be rotated or audited.

**Consequences.**

- Setup steps that create credentials (`concept/workflow.md` section 0)
  end with "stored in 1Password as `op://<vault>/<item>`" and nothing
  else.
- The daemon resolves credentials from 1Password at runtime, as jackin
  already does for roles (`analysis/jackin.md`).
- Any agent or subagent that creates a credential during implementation
  must store it in 1Password in the same step; a step that leaves a
  credential elsewhere is not done.

## D-036 — 2026-08-27 — Work is done through subagents, heavily

**Decision.** In this workflow, every unit of work is carried out by
delegated agents: subagents inside a session, or separate agents spawned
through jackin (`jackin load <role>` today, the daemon later) when the
work needs its own container, role, or runtime. Research, analysis,
design proposals, implementation of each checklist item, verification,
and review are all delegated. The top-level agent in a session
coordinates, delegates, integrates, and decides; it does not do the bulk
of the work itself. Building this product itself follows the same rule
from the first iteration, so each iteration also proves the workflow. This applies to planning in this repository, to
implementation of jackin, termrock, and the daemon, and to the agents the
daemon runs on issues.

**Rationale.** Observed (VISION.md): agents with a small, clear scope are
markedly more accurate, and subagents for research and verification raise
quality further. Heavy delegation keeps each context small and each result
checkable.

**Consequences.**

- Prompts and roles used by the daemon instruct the agent to delegate
  each checklist item and its verification to subagents (extends D-007).
- Skills used for planning and implementation are written to spawn
  subagents by default.
- `AGENTS.md` in this repository records the rule for work done here.

## D-037 — 2026-08-27 — Milestones are ordered proofs of the loop

**Decision.** The product is built as a sequence of milestones, each one a
verified proof that a part of the loop works, in this order:

1. **Linear setup verified.** The Linear agent app exists, is installed in
   the workspace, credentials are in 1Password, and an issue can be
   assigned to jackin and observed (browser-verified, D-032).
2. **jackin daemon listens and reacts to Linear.** The daemon receives the
   assignment event (by whatever path Q-015 decides) and reacts visibly.
3. **Issue spawns a local agent.** Creating and assigning a task in Linear
   spawns a jackin agent locally: a new jackin instance in Docker with a new
   session, using the role and runtime named on the issue.
4. **Capsule passes prompts to a specific agent.** Through the jackin
   capsule, a prompt can be delivered into a chosen agent's session, and
   every step of the instance can be managed through the capsule. This is
   what lets the prompt on the Linear issue reach the agent.

Later milestones (checklist mirroring and write-back, verification, pull
requests, merge, TUI, server host, multi-host) follow once these four are
proven.

**Rationale.** Each milestone removes one unknown. Milestone 4 is the
capability everything else depends on and is the largest jackin gap
(`analysis/linear-agents.md`: no initial-prompt path exists today).

**Consequences.** `ROADMAP.md` holds the milestones and their tasks; each
task is a folder under `tasks/` (D-038) and becomes a Linear issue when it
is ready to execute.

## D-038 — 2026-08-27 — Tasks live in `tasks/`, indexed by a README with status

*Amended by D-111: `tasks/README.md` and `PROGRESS.md` are generated
projections of the state store, never hand-edited. Amended by D-118: the
permitted task-folder files are listed there.*

**Decision.** This repository has a `tasks/` folder. `tasks/README.md` is
the index: a list of every task subfolder with its status. Each subfolder
is one task, containing what an agent needs to do it (description,
references, checklist, verification). An agent that starts a task follows
this structure: read the index, read its task folder, work only on that
task, update the status in the index when done. When execution starts, each
task is turned into a Linear issue (D-010) that points at its folder; the
folder is the plan content, Linear is the execution tracker.

**Rationale.** The detailed plan must exist, with dependencies resolved,
before execution; a folder per task is the format already observed to work
(VISION.md) and is what the issue contract mirrors locally (D-013).

**Consequences.**

- D-001 is amended: runnable files are permitted only as verification
  scripts inside `tasks/<task>/`; everything else stays Markdown.
- `concept/task-format.md` gains an "authoring in `tasks/`" section that
  matches the issue contract field for field.
- Planning proceeds in two steps: first a small plan of which tasks exist,
  what process they follow, and their dependencies (`ROADMAP.md`); only
  after that is finalized are the task folders created and delegated.
- Which jackin agent roles are needed to build this product (existing
  roles or new ones) is decided during that planning; see Q-016.

## D-039 — 2026-08-27 — Build in parallel across accounts, agents, and models

**Decision.** The build runs as many tasks in parallel as the dependency
graph allows. Parallelism uses the multiple provider accounts already on
this machine — jackin supports configuring and logging into several
accounts — currently:

- `~/.claude` (Claude Code)
- `~/.codex`, `~/.codex-chainargos`, `~/.codex-chainargos2` (Codex)

The models used for this project are: Fable 5, Opus 5, Sonnet 5 (Claude),
and GPT-5.6 Sol, GPT-5.6 Terra, GPT-5.6 Luna (Codex). All of them run at
**medium** reasoning for work on this project. Every task is planned with
subagents, and the plan assigns tasks across different agents and different
models rather than defaulting to one; independent tasks are spread over
accounts so that no single account's quota serializes the build.

**Rationale.** Wall-clock speed is the constraint (D-034). Quota per
account is the practical ceiling on parallelism, so spreading over
accounts raises it; using several agents and models keeps D-015 real and
exposes runtime-specific problems early. Medium reasoning is the agreed
cost/quality point for this phase.

**Consequences.**

- `ROADMAP.md` and each task folder record the assigned agent runtime,
  model, and account lane; the per-milestone "parallel groups" are spread
  across lanes.
- jackin's multi-account configuration is part of milestone 1 setup, and
  the daemon's per-provider-account concurrency cap (proposed D-022) is
  needed by milestone 3.
- Prompts and role configuration pin reasoning effort to medium for every
  runtime that exposes it.
- Adding accounts or models later is a one-line change to this decision.

## D-040 — 2026-08-27 — One Linear project, issues with explicit dependencies mirroring `tasks/`

**Decision.** All work for this effort lives in one Linear project. Each
task folder under `tasks/` (D-038) becomes one issue in that project. The
dependencies recorded in `tasks/README.md` and `ROADMAP.md` are mirrored in
Linear as blocking relations, so the dependency graph is identical in the
repository and in Linear. Milestones (D-037) map to Linear project
milestones.

**Rationale.** One project gives one place to see the whole plan, its
progress, and its critical path; mirrored dependencies let the daemon gate
dispatch on Linear relations (D-004) while the repository stays the
authored plan.

**Consequences.** The task that turns folders into issues (ROADMAP M1-12)
creates the project, its milestones, the issues, and the blocking
relations, and browser-verifies the result (D-032). A change to a
dependency is made in the repository first, then mirrored to Linear.

## D-041 — 2026-08-27 — The goal is a production-ready product and process

**Decision.** This repository exists to reach a production-ready product
and a production-ready process: building software with Linear + jackin,
where issues are the work, jackin roles do it, and humans decide. Prototype
milestones are steps toward that, not the destination.

**Rationale.** States the bar explicitly so that "works on my laptop" is
never mistaken for done.

**Consequences.** Later milestones (server host, multi-host, TUI,
credentials via service accounts, retry and escalation policy) are in
scope, not optional. `VISION.md` states the goal.

## D-042 — 2026-08-27 — The preview jackin is removed; only the branch build runs here

**Decision.** The Homebrew preview install of jackin (`jackin-preview`,
currently `0.6.4-preview.1100+6b0dfe1` at `/opt/homebrew/bin/jackin`) is
uninstalled from this computer. From then on the only jackin on the machine
is the locally built one from the working branch where this effort lands
(`feat/managed-execution`, Q-020), kept current by rebuilding from the
branch. All managed-execution support is added to jackin on that branch and
merged to `main` through pull requests (D-034).

**Rationale.** Two jackins on one machine invite testing the wrong binary.
The branch build is the product being built; it must be the one in daily
use (D-033).

**Consequences.** ROADMAP M1-02 (local jackin build from branch) includes
uninstalling `jackin-preview` and installing the branch build on `PATH`
first; `jackin-dev` (the workflow plugin) stays. Roles built locally must
target the branch's construct base. If the branch build breaks, the fix is
to fix the branch, never to reinstall the preview.

## D-043 — 2026-08-27 — The issue also names the model and the effort level

**Decision.** Extending D-012: an issue that jackin executes names the
jackin role, the agent runtime, the **model**, and the **reasoning effort
level** to use. The daemon starts the role with exactly those; a missing
model or effort falls back to the lane defaults recorded for the project
(D-039: medium effort) and is reported on the issue as a defaulted value.

**Rationale.** Model and effort decide cost and quality per task; the
human chooses them where the task is defined, not in daemon config.

**Consequences.** Two more fields in the issue contract (convention
Q-013, for example labels `model:*` and `effort:*`). `LoadOptions` (ROADMAP
M3-01, Q-024) carries `model` and `effort`; each runtime adapter maps the
effort level to its own flag where the runtime exposes one.

## D-044 — 2026-08-27 — Delivery mode: `/goal` by default, plain prompt on request

**Decision.** When the daemon starts a task, the default is to deliver the
issue's prompt to the agent as a `/goal` execution: `/goal <prompt>`, the
iterate-until-done runner already used in today's workflow (VISION.md;
`jackin-dev` skills call it the external spec-runner). An issue may
override this with a delivery option: `prompt` sends the text as a plain
first message with no `/goal` wrapper. The issue therefore decides how its
text is posted; the daemon never guesses.

Classification for this project's own tasks (`ROADMAP.md`):

- **goal** — tasks with a checklist and a verification that must iterate
  until `status: DONE`: every implementation task in jackin, termrock, and
  role repositories, and authoring tasks in this repository.
- **prompt** — one-shot operator actions, observation and proof runs, and
  reviews that end in a verdict rather than a verified artifact.

**Rationale.** `/goal` is what makes an agent keep working until the
verification passes, which is the behavior wanted for implementation. A
proof run, a one-time setup click-through, or a review does not have a
loop to run and is clearer as a plain prompt.

**Consequences.**

- Delivery mode is an issue field (default `goal`); `concept/task-format.md`
  and the `tasks/` folder format carry it.
- `/goal` is a Claude Code command today. For other runtimes (D-015) the
  daemon maps `goal` to that runtime's equivalent, or to the plain prompt
  prefixed with the same iterate-until-DONE instruction when no equivalent
  exists; ROADMAP M4-05 (runtime matrix for prompt delivery) covers this.
- `ROADMAP.md` lists the delivery mode per task.

## D-045 — 2026-08-27 — New purpose-built roles under the `donbeave` GitHub account

**Decision.** The jackin agent roles used to build this product are new
roles created in the `donbeave` GitHub account, designed purely for this
project. Existing roles (`the-architect`, `agent-smith`, `sentinel`) are not
modified for it. The new roles are intended to become the basis for working
on projects of this kind in the future.

**Rationale.** `the-architect` is jackin's own development role and should
not accumulate project-specific tooling such as `agent-browser`. Roles
designed for "build a product through Linear + jackin" are reusable beyond
this effort, so they deserve their own identity and repositories.

**Consequences.** Q-016 is closed as to ownership and reuse; the set of
roles, their names, and their contents are decided from the analysis in
`analysis/roles/` and recorded in `concept/roles.md`. ROADMAP §4 and tasks
M1-04/M1-05 are replaced accordingly once the set is decided.

## D-046 — 2026-08-27 — Any jackin-project or tailrocks repository may be changed to make this work

*Amended by D-112: work reaches an involved repository through a per-task
worktree and branch and one integrator lease per repository.*

**Decision.** Whenever this effort needs something from an involved
project, the project is changed to provide it. This applies to every
repository under https://github.com/jackin-project and every repository
under https://github.com/tailrocks. Anything in those projects that does
not work as needed (for example `jackin-exec` not working out of the box)
is treated as a bug and fixed in the project where the fix belongs;
anything missing is added as an extension there. Work is never routed
around a defect in an involved project.

**Rationale.** These are our projects; the point of dogfooding (D-033) is
that the product forces its dependencies to become correct. A workaround
in the manager would hide a bug that every other user of the project
would hit.

**Consequences.**

- Task authors and agents are free to open changes in any involved
  repository; the task records which repositories it touched.
- `analysis/*.md` findings marked "absent" or "partial" become extension
  tasks; findings that contradict documentation become bug tasks.
- Q-020 is closed by D-047 for branch naming.

## D-047 — 2026-08-27 — One branch everywhere: `feat/managed-execution`; ecosystem on `main`

*Amended by D-112: each task uses its own branch `managed/<run-id>/<task-id>`
from the locked base SHA; workers never push `feat/managed-execution`.*

**Decision.** In every involved repository that receives changes for this
effort (jackin-project and tailrocks organizations, and the new role
repositories under `donbeave`), all work lands on one branch named
`feat/managed-execution`, always. Pull requests from that branch to `main`
are made when a milestone needs a merge or release (D-034); the branch is
never renamed or split. The exception is this repository
(https://github.com/donbeave/ecosystem): every change goes directly to
`main`, always; no feature branches. This is a rule in `AGENTS.md`.

**Rationale.** One known branch name removes coordination cost across a
dozen repositories and lets local installs, role builds, and daemon
launches pin the same ref (D-042). The planning repository has no reason
for branches: its content is decisions, and a decision either is recorded
or is not.

**Consequences.**

- Q-020 is closed; the earlier "roles use `feat/agent-browser`" wording is
  withdrawn.
- termrock's trunk-only `CONTRIBUTING.md` conflicts with the branch rule;
  it is amended on `feat/managed-execution` in termrock to allow this
  branch and pull requests for agent-authored changes (D-046).
- Role repositories created for this effort start on `main` and use
  `feat/managed-execution` for subsequent changes like every other
  involved repository.

*Amended by D-074: role repositories are effective on `main`; jackin and
termrock PRs stay open during the run.*

## D-048 — 2026-08-27 — jackin development always uses `jackin-the-architect`

**Decision.** Every task that changes the jackin repository (and its
sibling repositories in jackin-project that `the-architect` already
covers) runs in the existing `jackin-the-architect` role, always. The role
is used as it is; it is not extended with project-specific tooling
(D-045). The new `donbeave` roles cover the rest: termrock and ecosystem
authoring (builder), Linear/GitHub/1Password/browser work (operator), and
reviews (reviewer).

**Rationale.** `the-architect` is jackin's own development environment,
maintained with jackin and already carrying its toolchain, rule files, and
skills; a second Rust role for jackin would drift from it.

**Consequences.**

- `concept/roles.md`: `crew-builder` scope is termrock, ecosystem, and the
  role repositories — not jackin. Its toolchain shrinks to termrock's.
- ROADMAP tasks with repository `jackin` keep role `the-architect`;
  the-architect's `agents` list must include `codex` for Codex lanes (it
  already lists six runtimes, `analysis/roles/jackin-dev-needs.md`).
- Browser proofs for jackin tasks stay with the operator (D-032 amendment
  pending the roles decision).
- Fixes the-architect needs for this effort (for example `default_agent`
  after M3-02) are made in `jackin-project/jackin-the-architect` on
  `feat/managed-execution` (D-046, D-047).

## D-049 — 2026-08-27 — Live status of every run is synced to Linear; stuck and blocked are visible there

**Decision.** The jackin daemon continuously syncs the status of every
in-progress issue back to Linear so that Linear alone shows what is going
on: which issue is being worked, by which role, runtime, model, and
account, on which host and container, since when, and in which state —
starting, working, waiting for input, blocked, stuck (no progress within
the stall window), failed, verifying, done. A stuck or blocked agent must
be recognizable at a glance from the Linear issue and project view without
opening a terminal. This is designed as a first-class feature, not a side
effect of checklist ticks.

**Rationale.** The human's goal is to see from Linear who is working on
what and whether anyone is stuck or blocked. Attach (D-016) shows the
truth for one agent; Linear must show the truth for all of them.

**Consequences.**

- Mapping onto Linear's agent-session model
  (`analysis/linear-agents.md`): daemon-driven `thought`/`action`
  activities for state changes, `elicitation` for waiting-for-input and
  blocked (session `awaitingInput`), `error` for failed, `response` for
  done; the session `plan` mirrors the checklist; `externalUrls` carries
  the attach target and the container identity; a periodic heartbeat
  keeps the session out of `stale` and carries "last progress at". Stuck
  is surfaced explicitly (activity plus a label or state the project view
  can filter on), not inferred by the human from silence.
- The project view must answer "who is working on what, who is stuck" via
  labels or states the daemon maintains (convention decided with Q-013).
- D-013 is amended: the daemon still reads the issue once at pickup and
  makes no reads while working, but it writes on every status change and
  heartbeat in addition to checklist-item completion. Write volume stays
  bounded by the state machine, not by agent chatter.
- This becomes its own milestone in `ROADMAP.md`, placed right after the
  prompt reaches the agent (M4) and before or together with checklist
  write-back (M5), since it is what makes the whole fleet observable.
- Stall detection (proposed D-021) is a prerequisite: "stuck" needs a
  definition the daemon can compute.

## D-050 — 2026-08-27 — Unattended end to end; operator needs are collected up front

**Decision.** The whole implementation is carried out without asking the
operator (the human) for anything mid-way, until everything is finished.
To make that possible, every milestone and every task begins with a
preflight: determine exactly what must come from the operator to run the
task independently — credentials and logins, consents, trust grants,
accounts, physical steps on the host — and obtain all of it before the
task starts. Those items are gathered into one operator checklist per
milestone (the `host` rows in `ROADMAP.md`), executed by the human in one
sitting before the milestone's agents start. An agent that discovers a
missing operator input mid-task records it as a preflight defect (the
preflight should have caught it), completes everything not depending on
it, and marks the task blocked with the exact missing item.

**Rationale.** Being blocked by obvious things (a login, a token, a
consent) is the main way unattended work stalls. Moving all of it to a
known moment at the front keeps the agents running and the human's
involvement predictable.

**Consequences.**

- `ROADMAP.md` gains, per milestone, an "operator preflight" list; task
  folders carry a `preflight` section listing operator inputs with their
  `op://` references or host actions.
- Open design questions are not a reason to stop: recommended answers are
  adopted by default (D-053) and may be overridden later.
- Applies to planning work in this repository as well: proposals are
  recorded with their recommended answer instead of waiting.

## D-051 — 2026-08-27 — A blocked agent is a Linear-visible state

**Decision.** When an agent inside a managed run is blocked — for example
`/goal` in Claude Code or Codex stops on a permission prompt, a tool
refusal, a confirmation, or any wait for input that the daemon did not
cause — the daemon detects it through the capsule's agent state and sets
the issue's run status to blocked in Linear (D-049), with the reason as
far as it is known and the attach target, so the human knows to connect
to that container and verify. The state is cleared automatically when the
agent resumes.

**Rationale.** Runtime-level blocks are invisible from outside the
container; without this the human only notices by silence. D-049 makes
stuck visible; this makes blocked-by-the-harness visible too.

**Consequences.** The capsule must expose a "waiting for input / blocked"
signal for every runtime (ROADMAP M4-05 runtime matrix extends to block
detection); "blocked" and "stuck" are distinct states in Linear; the M5
status milestone includes this case in its proof.

## D-052 — 2026-08-27 — The Linear issue carries the assigned container identity

**Decision.** Every issue being worked on shows the identity of the jackin
Docker container assigned to it: the container id, the jackin instance
name, and the host, kept current by the daemon from launch to removal,
including across retries (each attempt's container is recorded). The
identity is shown where a human reads it (session activity and an
external URL / attach target) and in a machine-readable place the daemon
maintains.

**Rationale.** The human must know which container is working on which
task in order to attach (D-016, D-051).

**Consequences.** Part of the M5 status-sync milestone; the container
label ↔ issue binding (ROADMAP M3-04) is the source; the convention for
where the identity lives on the issue is fixed with Q-013.

## D-053 — 2026-08-27 — Recommended answers are adopted as defaults

**Decision.** Under D-050, every open question and proposal that has a
recommended answer in `ROADMAP.md` §7, `concept/roles.md`, or
`concept/borrowed-from-symphony.md` is adopted as the working decision
now, so that task authoring and execution are not blocked. Specifically
adopted: the role set (family `crew`: `crew-builder`, `crew-operator`,
`crew-reviewer`, template repo, local-only builds, role `host` for human
steps); the D-032 amendment (browser proof by the operator role); the
Symphony proposals D-018..D-031 as written in
`concept/borrowed-from-symphony.md` (with their numbers kept as
references, marked adopted); and the recommended answers to Q-001, Q-006,
Q-007, Q-008, Q-010, Q-011, Q-013 (extended with `model:*`, `effort:*`,
`delivery:*`, and daemon-maintained status labels and container identity
per D-049/D-052), Q-014, Q-015, Q-017, Q-018, Q-019, Q-021, Q-022, Q-023,
Q-024, Q-025. Each adopted answer is recorded in the relevant concept
document and `SPEC.md`; any of them may be overridden by a later decision
here. Questions that have no recommended answer (Q-002 name, Q-009
delivery beyond Linear, Q-005 planner-approval detail) stay open and do
not block anything.

**Rationale.** The human has reviewed the recommendations twice without
objection and has asked for independent execution; waiting on explicit
per-item confirmation is exactly the blocking D-050 forbids.

**Consequences.** `OPEN-QUESTIONS.md` keeps only the genuinely open
items; `ROADMAP.md` §7 is reduced accordingly; `SPEC.md` is updated to
state the adopted answers; `concept/borrowed-from-symphony.md` proposals
are marked adopted.

## D-054 — 2026-08-27 — The roadmap is finalized

**Decision.** `ROADMAP.md` is final. Task ids and the dependency graph are
frozen; the scope text of a task may still be edited. Any change to a task
id, the addition or removal of a task, or a change to `depends_on` requires
a new entry in this file. The roadmap status line reads FINAL.

**Rationale.** D-038 makes task folders and Linear issues depend on a
finalized roadmap; a frozen id space and graph are what M1-01 and M1-12 key
on. Scope text stays editable because tasks are refined while they are
executed.

**Consequences.** Task folders may be authored (D-062); ids are stable
references in Linear, task folders, and evidence; the status line of
`ROADMAP.md` names this decision.

*Amended by D-072: M1-01 loses its dependency; M1-09 gains M1-10 and
M1-13; M1-12 gains M1-13.*

## D-055 — 2026-08-27 — Agents merge; reviews never block; no releases before M11

**Decision.** Agents merge pull requests to `main` themselves whenever the
roadmap needs a merge, using the forwarded `gh` identity. Work that does not
block the roadmap stays unmerged on `feat/managed-execution`. No jackin
release and no Homebrew tap publish happens before M11; only branch builds
run. There is no human review gate anywhere: `crew-reviewer` tasks run in
parallel with the following work and never block the next task; their
findings become follow-up checklist items on the issue they reviewed.

**Rationale.** D-050 forbids waiting on the human mid-way; a review gate or
a human merge is exactly such a wait. Branch builds are sufficient until the
server milestone needs published artifacts.

**Consequences.** Review tasks are marked `non-blocking` in `ROADMAP.md` and
appear in no `depends_on`; `SPEC.md` §9d and §6 step 12 drop the human
merge; the termrock `CONTRIBUTING.md` clause (D-047, D-053) reads "agent
merges after `crew-reviewer` review has been requested", not "human
merges"; `AGENTS.md` rule 9 is unchanged for this repository.

## D-056 — 2026-08-27 — The host is OrbStack; laptop caps are 6/3/1/1

Amended by D-071: the `~/.claude` cap for this run is 2, not 3, because the
host session is a permanent consumer of that account home.

**Decision.** The developer machine runs OrbStack 2.2.3 (18 CPU, about
122 GiB available to Docker, 1.6 TiB free disk; Docker context `orbstack`;
no Docker Desktop). jackin treats it as a plain Docker daemon
(`crates/jackin/src/preflight.rs:217`). Laptop caps: `max_concurrent_agents
= 6`, `~/.claude` 3, each Codex home 1, `donbeave/crew-operator` 1.

**Rationale.** The earlier caps of 2 assumed Docker Desktop's resource
limits; OrbStack on this machine has room for six role containers plus
DinD, and one Claude account can carry three concurrent sessions.

**Consequences.** Every "Docker Desktop" mention in the preflights is
replaced by the OrbStack facts; M3-05 and `SPEC.md` §6 carry the new caps;
wave planning in `ROADMAP.md` §3 may schedule up to two `~/.claude`
container tasks at once (three minus the host session, D-071).

## D-057 — 2026-08-27 — Automatic lane fallback on quota exhaustion or stuck

**Decision.** The daemon detects provider quota exhaustion and stuck runs
(D-021, D-049) and re-launches the task on a fallback lane automatically.
Fallback chains cover the account, the agent runtime, and the model: L1 →
L2 → L3 → L4 → L5 → L6 → L1 (Claude lanes fall through the Claude account
first, then to Codex), and L4 → L5 → L6 → L1 → L2 → L3 → L4 (Codex lanes
fall through the other Codex homes first, then to Claude). `ROADMAP.md` §5
gains a `fallback` column per lane and task folders carry `fallback_lane`.
A new M6 task implements the daemon-side fallback; until it exists the host
session re-lanes a task by hand and records it as a preflight defect.

**Rationale.** Quota exhaustion and stalls are the two ways an unattended
run stops without a human; a defined next lane turns both into a retry
instead of a wait.

**Consequences.** M6 gains task M6-05 (depends on M3-05 and M7-02);
`SPEC.md` §6 step 8 and `concept/manager.md` describe the fallback; the
retry ledger (D-019) records the lane of every attempt.

*Amended by D-071: a hand re-lane is recorded in `PROGRESS.md` only, never
as a preflight defect; quota fallback is per account home and consumes no
attempt.*

## D-058 — 2026-08-27 — Model ids and effort knobs are discovered by M1-13

**Decision.** The exact model identifiers and reasoning-effort knobs for
every lane are discovered and recorded by M1-13, not stated in
`ROADMAP.md`. `model:*` label values follow what M1-13 records. Minimal
edits to `jackin-the-architect` on its `feat/managed-execution` branch are
allowed under the D-048 consequences; the role already lists `codex`.

**Rationale.** Model ids and effort environment variables change with
provider releases; the roadmap names lanes by intent (runtime, family,
account) and M1-13 binds them to current values.

**Consequences.** `ROADMAP.md` §5 keeps model family names only; M1-13's
task folder records ids and knobs; M1-09 creates `model:*` labels from that
record.

## D-059 — 2026-08-27 — Evidence is text in task folders; media on the issue

**Decision.** Task folders hold text evidence only: GraphQL JSON, `.cast`
recordings, logs, and `verify.sh` output. Screenshots and video recordings
are attached to the Linear issue, not committed. D-001 and D-038 are
unchanged.

**Rationale.** Binary media bloats a Markdown repository and is more useful
next to the issue it proves.

**Consequences.** Every "screenshot in `tasks/<id>/`" in `ROADMAP.md`
reads as "screenshot attached to the issue, reference in `tasks/<id>/`";
`.gitattributes` needs no LFS.

## D-060 — 2026-08-27 — Linear structure: team `JACKIN`, one project, milestones M1..M12

**Decision.** A new Linear team `JACKIN` hosts the work; one project holds
this effort; project milestones are M1..M12. M1 tasks never get Linear
issues: they are executed by hand from their task folders. Issues start at
M2; M1-12 creates the M2+ issues. Before any issue is created, subagents
verify the current state of the work in the involved repositories, and the
issue reflects what is already done.

**Rationale.** M1 is the bootstrap that makes the daemon and roles exist;
issuing it in Linear would be bookkeeping with nothing to consume it. A
verified state avoids issues that ask for work already landed.

**Consequences.** M1-12 scope and `SPEC.md` §10a are updated; the team key
`JACKIN` replaces "the Linear team key … recorded in `tasks/M1-09/`".

## D-061 — 2026-08-27 — Host-only verification runs in the host session

**Decision.** `verify.sh` of host-only tasks (M1-02a, M1-05d, M1-06,
M1-11, and every other `host` row) is run by the host Claude Code session
that drives this roadmap (the `/goal` session on the Mac); its output is
filed in the task folder.

**Rationale.** These tasks have no container; the host session is the only
place their checks can run and it already holds the evidence.

**Consequences.** `host` rows in `ROADMAP.md` name the host session as the
verifier; the task-format `verify.sh` contract states the host exception.

*Amended by D-081: every host-side check (Linear token, `op`, daemon
socket, host `docker`) runs in the host session whatever the task's role.*

## D-062 — 2026-08-27 — Task folders for M1..M5 now; later milestones when reached

*Amended by D-114: all 81 task bundles are materialised before any product
task runs; there is no runtime authoring phase.*

**Decision.** Task folders are authored now for M1..M5 (task M1-01); M6..M12
folders are authored when those milestones are reached. Milestones may
overlap in execution; operator preflights are merged per sitting rather
than executed strictly per milestone.

**Rationale.** Later scopes will change as the daemon takes shape;
authoring them now would be rewritten. Overlap is what the dependency
graph already allows.

**Consequences.** M1-01 scope is unchanged; `SPEC.md` §9e and §10b state
the overlap and the merged preflights.

## D-063 — 2026-08-27 — Stuck rule: analyze with subagents before escalating

**Decision.** When a task stalls or takes too long, the agent always spawns
subagents to analyze why and to find a solution before anything is
escalated. This applies to container agents and to the host session; in
managed runs the daemon's stuck signal (D-049) triggers it. Prompt frames
and every `TASK.md` carry the instruction.

**Rationale.** Most stalls are solvable inside the session (a wrong
assumption, a missing file, a flaky check); escalating first wastes the
human's attention and violates D-050.

**Consequences.** `AGENTS.md` rule 11; `concept/task-format.md` gains a
"When stuck" section in the `TASK.md` template; `SPEC.md` §9f; the M5
stuck transition and the M6-05 fallback are preceded by this analysis
step.

## D-064 — 2026-08-27 — CI for this roadmap runs on GitHub-hosted runners, not velnor

**Decision.** For every involved repository — all repositories under
github.com/jackin-project and github.com/tailrocks that this effort
touches, the `donbeave` role repositories, and this repository —
continuous integration runs on GitHub-hosted runners. velnor self-hosted runners are not used for
this work. Where a repository's workflows currently target velnor runners
(for example termrock's CI delegating to velnor `ci-code.yml`), the
workflows are switched to GitHub-hosted runners on `feat/managed-execution`
(D-046, D-047).

**Rationale.** velnor is itself under development in this ecosystem; CI for
this roadmap must not depend on it. GitHub-hosted runners are always
available and need no operator preflight. Local verification stays the
default (D-034); CI is confirmation.

**Consequences.**

- Tasks that first touch a repository's workflows (M1-02 for jackin, the
  first termrock task, the role repositories from creation) include
  "runs-on: GitHub-hosted" as part of scope.
- Role image validation (`jackin-role-action`) continues to run on
  GitHub-hosted runners as it does today.
- `analysis/roles/termrock-and-docs-needs.md` item on velnor CI is
  superseded for this effort.

## D-065 — 2026-08-27 — Every repository we create is public

**Decision.** Every repository created for this effort is public from
creation: the `donbeave/jackin-crew-*` role repositories, the
`donbeave/jackin-role-template` repository, and this repository
(`donbeave/ecosystem`, created private on 2026-08-27 and switched to public
under this decision). No private repositories are created for this work.

**Rationale.** Tailrocks builds in the open (vision, Apache-2.0 from day
one); a public repository also lets `jackin load donbeave/<name>` resolve
without credentials and lets role images build in public CI.

**Consequences.** Nothing sensitive may be committed — already required by
D-035 (credentials in 1Password only) and D-059 (text-only evidence).
Repository creation tasks (M1-04a, M1-05a..c) specify `--public`. The
browser profile, tokens, and service-account secrets stay outside git.

## D-066 — 2026-08-27 — No separate product name: it is the jackin daemon, "managed execution"

**Decision.** The manager has no name of its own. It is jackin's daemon
(`jackin daemon`) and the feature is called "managed execution". Q-002 is
closed; "the manager" in older documents means the jackin daemon's
managed-execution logic.

**Rationale.** D-009 and Q-001 placed it inside jackin; a second brand adds
nothing.

**Consequences.** New text says "jackin daemon" or "managed execution";
old text is not rewritten.

## D-067 — 2026-08-27 — Roadmap issues are created and assigned by agents; follow-ups dispatch only under `auto-dispatch`

**Decision.** Closing Q-005 in line with unattended execution (D-050): the
issues for this roadmap are created by M1-12 from the task folders and are
also assigned to jackin by that task, in dependency order, so no human
assignment is needed for the roadmap to run. Follow-up issues that agents
create during work (D-028) are left unassigned in the backlog unless the
parent issue carries the label `auto-dispatch`, in which case the creating
agent may assign the follow-up to jackin. Every roadmap issue carries
`auto-dispatch`. Outside this roadmap the default stays: a human assigns
(D-011).

**Rationale.** The human asked for the whole work to be executed without
being disturbed; requiring a human click per issue contradicts that. The
label keeps D-011's protection for everything that is not this roadmap
and keeps self-generated work from dispatching by accident.

**Consequences.** M1-12 scope: create, label (`auto-dispatch` included),
relate, and assign. Q-013 label set gains `auto-dispatch`. D-028
consequence amended accordingly.

*Amended by D-073: M1-12 sets no delegate; the host session delegates when
the daemon can serve the issue and closes finished tasks' issues.*

## D-068 — 2026-08-27 — Escalation stays in Linear; the host session handles it

**Decision.** Closing Q-009: blocked, stuck, and elicitations are
delivered in Linear only (D-029, D-049, D-051). No email, Slack, push, or
phone channel is added in this roadmap. During this roadmap the host
Claude Code session that drives the work watches Linear and the daemon,
answers elicitations it can answer, applies the stuck rule (D-063), and
records anything only the human can answer as a preflight defect
(D-050) — it does not interrupt the human. A push/phone surface is a
post-M12 backlog item, not an open question.

**Rationale.** The human wants the work done without being disturbed;
Linear already holds every state; the host session is the operator for
the duration.

**Consequences.** `OPEN-QUESTIONS.md` is empty. ROADMAP §6 process notes
that the host session is the first responder to escalations.

## D-069 — 2026-08-27 — One root `verify.sh` and a `goal/` package drive the unattended run

*Amended by D-110: the root `verify.sh` derives four terminal classes, not
two. Amended by D-118: the permitted machine files are listed there.*

**Decision.** D-001 is amended a second time: besides the task-level
`tasks/<id>/verify.sh` (D-038), exactly one more runnable file is permitted
in this repository — `verify.sh` at the repository root. It is the gate of
the whole roadmap run: it passes only when every task id in the `ROADMAP.md`
task tables has a `tasks/README.md` row in status `done` and a
`tasks/<id>/verify.sh` exists, and it prints `status: DONE` or
`status: PENDING <n> remaining` as its last line. It is read-only and has
no dependencies beyond POSIX `sh` and `awk`. The run itself is defined by
Markdown only: `GOAL.md` (the `/goal` prompt, under 4000 characters, run
with the one-line invocation printed in `GOAL.md`, which since D-083
carries the two terminal facts the runner's judge checks), `goal/EXECUTION.md` (session start, per-task
procedure, wave order, execution paths, resume), `goal/PREFLIGHT.md` (the
human's one-time operator checklist consolidated from `ROADMAP.md`),
`PROGRESS.md` (append-only ledger, one row per task), and
`PREFLIGHT-DEFECTS.md` (the only condition under which the run stops,
D-050). Every other rule of D-001 stands: no source code, prototypes, or
scaffolding here.

**Rationale.** `/goal` is a model-judged loop: it keeps working until a
model accepts that the stated condition holds. A condition stated in prose
("all tasks done") is judged from the transcript; a condition stated as the
last line of one deterministic script is judged from a fact. The task-level
scripts already exist for that reason (D-003, D-038); the roadmap needs the
same fact at its own level, and the only place a fact about eighty task
folders can be computed is a script next to them. The `goal/` package exists
because the prompt cap of 4000 characters (the `jackin-goal-prompt` skill's
limit) cannot carry the wave order and the operator checklist, and because
a resumable run needs its state (`PROGRESS.md`, `PREFLIGHT-DEFECTS.md`) in
files, not in a session's memory (D-050, D-061, D-068).

**Consequences.** `AGENTS.md` rule 1 names the root script as the second
exception; `README.md` and `AGENTS.md` map the new files; `ROADMAP.md` §6
names `GOAL.md` as the entry point and the two ledgers; `tasks/README.md`
keeps its `Task` and `Status` columns with lowercase status values because
the root script parses them by header name. The script and the `goal/`
files are frozen during a run except through a decision here.

## D-070 — 2026-08-27 — The run has two terminal outcomes; a task can be `exhausted`

Adopted under D-053 (bulletproofing round 1). Amended by D-083 (the
BLOCKED predicate also requires no `in-progress` or `waiting` row and the
BLOCKED message ends on script output) and D-084 (attempts are counted per
epoch; an `exhausted:` row has no proof command and is closed by the next
session start; `blocked` never propagates to dependents).

**Decision.** The `/goal` run ends in exactly one of two outcomes, both of
which satisfy the run's goal condition for the current session: COMPLETE —
root `sh verify.sh` prints `status: DONE`; or BLOCKED — no task is
runnable and at least one row is `blocked` on an open `PREFLIGHT-DEFECTS.md`
row. A row becomes `blocked` for one of two reasons: a missing operator
input (D-050), or exhaustion — `verify.sh` still fails after
`limits.attempts` attempts (`task.toml`, default 3; the count in `SPEC.md`
§6 step 8), each attempt on the next lane of the D-057 chain and each
preceded by the D-063 analysis, without wrapping past the starting lane.
Exhaustion is recorded as a `PREFLIGHT-DEFECTS.md` row of kind
`exhausted: <id>` carrying the last `tasks/<id>/verify.out` path and the
analysis summary; the human resolves it like a defect (or edits the task)
and re-runs the invocation of `GOAL.md`. Attempts are counted in the
`PROGRESS.md` result cell so a resume never resets them within an epoch
(D-084). A provider quota
or rate-limit wait is neither an attempt nor a block (D-071).

**Rationale.** A model-judged loop with no turn cap and a single STOP
condition has no exit for a task that can never pass; a bounded attempt
count with a named terminal row gives it one without weakening the
"fix, never route around" bias (D-046, D-063), because the row is filed only
after the analysis has run on every attempt.

**Consequences.** `GOAL.md` prompt states both outcomes and both `blocked`
reasons; `goal/EXECUTION.md` §5 step 5 and §6 mirror them;
`PREFLIGHT-DEFECTS.md` accepts the `exhausted:` kind; `AGENTS.md` is
unchanged.

## D-071 — 2026-08-27 — Quota fallback is per account home, consumes no attempt, and is never a preflight defect

Adopted under D-053 (bulletproofing round 1). Amends D-057 and the D-027
interpretation in `SPEC.md` §6 step 8. Amended by D-090: the reset-time
command is `jackin usage host snapshot --agent <claude|codex> --format
json` (there is no `jackin usage host accounts`), the host session applies
a headroom reserve rule before drawing on `~/.claude`, and a limit hit on
the session itself is survived by Claude Code's auto-continue setting, not
by a poll the limited session could not run.

**Decision.** Provider quota exhaustion is an infrastructure-class failure:
it consumes no attempt. The re-launch skips every lane whose account home
matches the exhausted one: L1/L2/L3 → L4 → L5 → L6 → L1; L4 → L5 → L6 →
L1; L5 → L6 → L1 → L4; L6 → L1 → L4 → L5. The stuck chain of D-057
(L1→L2→…→L6→L1) is unchanged. A model-only hop (L1→L2→L3) is used only
when the runtime reports a model-specific limit while the account has
headroom. Fallback hops respect the D-056 caps (one task per Codex home);
a task whose whole chain is throttled is `waiting`, not `blocked`: the
session reads the earliest reset time (`jackin usage host accounts
--format json` where it exposes one, otherwise the runtime's own limit
message, otherwise a fixed 30-minute backoff), waits with a Monitor loop,
and retries. Until M6-05 lands, the host session re-lanes by hand and
records the hop in the task's `PROGRESS.md` result cell (`L1 quota → L4`);
a lane fallback is never a preflight defect and never sets a row
`blocked`. The same rule binds the host session itself: a 5-hour-window
limit message in this session is a wait, not a defect and not a failure;
only a weekly-cap message whose reset is more than 24 hours away is a
billing action and therefore a preflight defect. The host session counts
as a permanent consumer of `~/.claude`: while it is active, at most two
L1..L3 container tasks run at once (the daemon's laptop cap for
`~/.claude` is set to 2 for this run), host-side subagents are capped at
three in flight, and research and verification subagents on Claude use
the cheapest model.

**Rationale.** L1..L3 share one account, so a quota hop between them wastes
the attempt cap on the same exhausted account; the earlier "record a
preflight defect" wording would stop the run on the first quota event with
a row the human cannot resolve. The host session and its subagents draw on
the same `~/.claude` budget as the L1..L3 containers.

**Consequences.** `ROADMAP.md` §5 prose and M6-05 scope, `SPEC.md` §6 step
8, `goal/EXECUTION.md` §4 and §6, `GOAL.md` prompt, and `concept/manager.md`
carry this wording; `tasks/README.md` gains the status `waiting`; M6-05's
tests assert the per-account-home chain and an unchanged attempt counter.

## D-072 — 2026-08-27 — Graph amendments: M1-01 is wave 0; M1-09 and M1-12 depend on M1-13; M1-09 depends on M1-10

*Amended by D-114: M1-01 is no longer an authoring task; every task bundle
exists before the run starts.*

Adopted under D-053 (bulletproofing round 1). Amends D-054. Amended by
D-088: M1 wave 5 is split because throwaway loads count as lane use, and
M1-01's verify clause "n = total − 1" is replaced by a state-independent
check (the row is still `in-progress` when its verify runs).

**Decision.** Three edges of the frozen graph change because the findings
proved an impossible ordering or a missing edge. (1) M1-01 has no
dependency and runs first (wave 0) on the `host` path: it changes only this
repository and needs no role container; before it ran, no task could
satisfy the done rule (no folder, no `verify.sh`, no `tasks/README.md`
row). (2) M1-09 gains `M1-10` (its verify uses M1-10's workspace token and
its template pre-sets the app user as delegate, which exists only after
the `actor=app` authorize) and `M1-13` (M1-09 creates the `model:*` label
values from M1-13's record, D-058). (3) M1-12 gains `M1-13` (it applies
those label values; a guessed label is frozen by the idempotent skip).
No cycle results: M1-13 depends on M1-02 and M1-05d only; M1-10 on M1-07.
M1 waves become {M1-01}; {M1-02}; {M1-02a, M1-04a}; {M1-05a, M1-05b,
M1-05c}; {M1-05d}; {M1-03, M1-06, M1-08, M1-13}; {M1-07}; {M1-10};
{M1-09}; {M1-11, M1-12}.

**Rationale.** D-054 allows graph changes only through a decision; each
edge here removes a guaranteed stall (unsatisfiable done rule, a verify
that runs before its input exists, a label baked from a guess).

**Consequences.** `ROADMAP.md` §2 rows M1-01, M1-09, M1-12, the §3 mermaid
graph, wave table, and critical-path paragraph are updated; `GOAL.md` drops
the "tasks that precede M1-01" rule; `goal/EXECUTION.md` §3 table starts
with wave 0; M1-01's verify becomes machine-checkable (three files per id,
`sh -n` clean `verify.sh` ending in a `status:` line, required `task.toml`
keys, required `TASK.md` sections, one `tasks/README.md` row per id, root
`sh verify.sh` printing a `status: PENDING` line — the exact clause is the
state-independent one of D-088, since this row is `in-progress` at verify
time).

## D-073 — 2026-08-27 — Issues are delegated to jackin only when the daemon can serve them; the host session closes issues; M1-12 re-runs after every authoring

Adopted under D-053 (bulletproofing round 1). Amends D-067 and D-060.
Amended by D-087 (the host session completes every finished task's issue
for the whole run, not only until M9-01; the daemon creates the agent
session for a delegated issue itself; a `response` is posted only when a
session exists) and D-088 (the early-start tasks M3-01, M3-03, M4-02,
M4-03 may run before M1-12 exists; every other M2+ task waits for it).

**Decision.** M1-12 creates, labels (`auto-dispatch` included), relates,
and links every M2+ issue but sets no delegate; issues for tasks already
`done` are created directly in the team's `completed`-type state. Delegation
to jackin (`issueUpdate(delegateId)` with the workspace token read by the
host session through `op read`, D-023 holds because the host is not a
container) happens per issue when the `daemon` path is active (M3-05 and
M3-06 merged on `feat/managed-execution`, the branch build installed, and
`jackin daemon status` answering) and the issue's task row is `ready`, in
dependency order, and only for tasks whose delivery the daemon supports at
that time (M4-01 for prompt delivery, M7-01 for verify, M8-02 for PRs). A
task executed on any non-daemon path never carries the delegate. On every
path, until M9-01 is merged and running, the host session moves the task's
issue to the `completed`-type state (queried by `type`, not by name) and
posts one `response` activity on its session in the same step that sets
the `tasks/README.md` row `done`; a `blocked` task keeps its issue with
the delegate removed. Before the daemon is started against the real
workspace for the first time and at every session start, the session
reconciles: every `done` row's issue is completed, no `in-progress` or
`blocked` row's issue carries the delegate. Every `<milestone>-00
authoring` ends with an idempotent re-run of the M1-12 procedure so each
new `ready` row has its Linear URL, labels, and relations before its
milestone's first task starts; the re-run is recorded in the authoring's
`PROGRESS.md` row. Live daemon runs in M2 and M3 use scratch issues only
and assert that no roadmap issue changed state.

**Rationale.** Delegating ~60 issues before a daemon exists creates stale
agent sessions, mass-acknowledges them on the first live run, and
re-dispatches work already finished by hand; open issues of finished tasks
keep every dependent non-dispatchable (D-020), so the daemon path would
wait forever. M6..M12 folders are authored after M1-12 ran once, so their
issues need a re-run.

**Consequences.** `ROADMAP.md` M1-12 and M2-02/M2-06/M3-05 rows, §6 item 8,
`SPEC.md` §10c, `goal/EXECUTION.md` §3, §4 and §5 steps 1, 7, 8,
`GOAL.md` prompt.

## D-074 — 2026-08-27 — Role repositories are effective on `main`; jackin and termrock PRs stay open during the run

*Amended by D-112: a change to a role repository is still made in a per-task
worktree and branch and integrated under the repository's integrator lease.*

Adopted under D-053 (bulletproofing round 1). Amends D-047, D-048, D-055,
D-058. Amended by D-088 (M11-01a merges jackin `feat/managed-execution`
into `main` once, before M11-02, because the role-publishing validator is
built from `main`) and D-089 (the-architect's CI switch happens in M1-13,
its first merge; `delete_branch_on_merge` is turned off on three
repositories; merge protocol and the single DCO `--force-with-lease`
exception).

**Decision.** `jackin load` builds a role from the cached default branch
only and `--role-branch` is interactive-only, so a role change is effective
only on `main`. The `donbeave/jackin-crew-*` and
`donbeave/jackin-role-template` repositories commit directly to `main`
(they are new, unprotected, and owned by the human). For
`jackin-project/jackin-the-architect` the task opens the PR from
`feat/managed-execution` and merges it in the same task (D-055) after
switching its CI to GitHub-hosted runners (D-064) so `ci-required` can
pass; every role task ends with `jackin load <role> --rebuild` and its
verify checks the cached checkout (`~/.jackin/roles/<ns>/<name>/default`)
against the pushed `main` commit. In `jackin` and `termrock`, one pull
request `feat/managed-execution` → `main` per repository is opened by the
host session (non-draft) before the first review task of the repository
and stays open, unmerged, for the whole run; every "Review <Mx> pull
request" task reviews that PR's diff since the SHA recorded by the previous
review and records the PR number and head SHA in `tasks/<review-id>/pr.txt`.
Nothing merges `feat/managed-execution` into `main` during the run unless
a task's scope names the merge; if a merge happens, the merging task also
merges `origin/main` back into the branch and pushes it, and the human
sets `delete_branch_on_merge=false` on jackin and termrock in preflight so
the branch survives a squash. Push protocol on the shared branch: `git
fetch origin && git rebase origin/feat/managed-execution` before every
push, up to five retries, never `--force`.

**Rationale.** The plan committed role changes to a branch jackin never
reads (M3-02, M3-02a, M11-02 could not pass); jackin uses squash merges
and deletes branches on merge, which would remove the D-042/D-047 pin;
GitHub allows one open PR per head→base, so the milestone reviews are
reviews of one long-lived PR at successive commits.

**Consequences.** `GOAL.md` prompt, `AGENTS.md` rule 10, `SPEC.md` §9d,
`ROADMAP.md` M3-02, M3-02a, M11-02, M1-13 note, §6 step 6, `concept/roles.md`
§4, `goal/EXECUTION.md` §4 rules and §5 step 6a, `goal/PREFLIGHT.md` §2.

## D-075 — 2026-08-27 — Golden-frame blessing is pre-approved; the host session blesses

Adopted under D-053 (bulletproofing round 1).

**Decision.** The human's `goal/PREFLIGHT.md` §5 checkbox is the recorded
approval for blessing termrock golden frames for M10-03 and M10-04. The
host session (never a container role; the crew-builder image still never
sets the variable) runs `mise run bless-previews` once in the termrock
checkout after the M10-03 story lands, and again if M10-04 changes
flagship output, commits the goldens on `feat/managed-execution`, files the
rendered frame text in `tasks/M10-03/` and `tasks/M10-04/`, and attaches
the lookbook export to the M10-06 review issue for post-hoc review. M10-03
extends the flagship set so the M10 exit criterion stays checkable.
Blessing is never a task gate, never a preflight defect, and never a STOP.

**Rationale.** A mid-run human approval contradicts the unattended goal
(D-050) and guaranteed a STOP before M10-04 with thirty tasks remaining.

**Consequences.** `goal/PREFLIGHT.md` §5 and §6, `ROADMAP.md` M10 milestone
proof, M10 preflight paragraph, M10-03 verify, `concept/roles.md` builder
threat-model cell.

## D-076 — 2026-08-27 — Human-only GitHub and 1Password steps move into preflight

Adopted under D-053 (bulletproofing round 1). Amended by D-089 (the App
is installed with access to all repositories; the scratch repository is
named) and D-090 (item (3): auto-lock Never is mandatory with no
service-account fallback; item (5): M11-01 verifies and records, M11-03
wires the server daemon; the laptop config never switches).

**Decision.** (1) The GitHub App `jackin-daemon` is created and installed
by the human in preflight for each of `jackin-project` and `tailrocks`
(sudo mode and owner consent are human-only); the private key and ids are
stored by the human as `op://jackin/github-app-jackin-daemon-jackin-project`
and `op://jackin/github-app-jackin-daemon-tailrocks` (D-108). M8-01
becomes verify-and-mint only. GitHub sudo-mode and Google re-auth prompts
are never answered by the operator role (it has no `Private` access by
design); one that appears mid-run is a preflight defect. (2) Vault `jackin`
and the operator service account are created by the human before the run;
M1-05d verifies them (`op vault get jackin`, exactly one vault of that
name) and never runs `op vault create`. (3) 1Password desktop auto-lock is
set to Never and the macOS screen lock disabled before the run, proven by a
prompt-free `op read` with stdin closed after idle; if the account policy
forbids Never, the daemon service account (#17) is created in the M1
preflight instead of M11 and the laptop daemon runs with
`OP_SERVICE_ACCOUNT_TOKEN` so per-tick reads never touch the desktop app.
(4) The standing `op` check uses a unique item and a full field reference:
`op read "op://Private/Context7/API Keys/Claude"`; the operator token is
always `op://tailrocks/op-service-account-jackin-operator/credential`.
(5) The M11 and M12 preflight items are named per field in
`concept/credentials.md` §4 (`claude-daemon/api key`,
`codex-daemon/api key`, `registry-dockerhub/username` and `/token`,
`server-host-1/address`, `/ssh user`, `/private key`, `server-host-2/*`,
`op://tailrocks/op-service-account-jackin-daemon/credential`); M11-01
verifies that they resolve and switches daemon config, it creates nothing.

**Rationale.** Each of these was either assigned to an agent that cannot
perform it or specified without the name the agent would look up.

**Consequences.** `goal/PREFLIGHT.md` §1, §2, §4, §5; `ROADMAP.md` M1-05d,
M8-01, M11-01, M8 and M11 preflight paragraphs; `concept/credentials.md` §4.

## D-077 — 2026-08-27 — Browser session travels as agent-browser storage state; the operator image uses Debian Chromium

Adopted under D-053 (bulletproofing round 1). Amends D-032/Q-017 wiring.
Amended by D-090: the login commands use `open <url>` (a bare
`agent-browser --headed --profile … --session operator` does nothing) and
the standing proof reads `agent-browser state --help`, since the top-level
`--help` of 0.35.1 lists no `state save`/`state load`.

**Decision.** A Chrome user-data directory created on macOS is not readable
by Linux Chromium (cookies are encrypted with an OS-bound key). The
portable credential is agent-browser's OS-independent storage state: after
the headed login on the host into a host-only profile, the human runs
`agent-browser --profile ~/.jackin/agent-browser-host-profile --session
operator state save ~/.jackin/agent-browser-profile/state.json` (mode
0600) and closes the browser; the mounted `~/.jackin/agent-browser-profile`
otherwise starts empty so Linux Chromium creates it. `crew-operator`'s
`preflight.sh` loads `state.json` when `agent-browser open
https://linear.app` lands on a login page and refuses with a message naming
the M1-06 re-login step if it still does. The preflight proof is
Linux-side: `jackin load donbeave/crew-operator --agent claude` and, inside,
`agent-browser open https://linear.app && agent-browser get url` shows the
workspace, same for github.com. Chrome for Testing publishes no Linux arm64
build and this host builds native arm64 images, so `crew-operator`
installs Debian `chromium` (plus `fonts-noto-cjk fonts-noto-color-emoji`)
on both architectures, never runs `agent-browser install`, and sets
`AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium` as a manifest env
default.

**Rationale.** Without this every browser task fails inside the container
while the host-only proof passes; the CfT gap would stop M1-05b, which is
on the critical path.

**Consequences.** `goal/PREFLIGHT.md` §2, `ROADMAP.md` M1-05b and M1-06,
`concept/roles.md` §3.1 and §3.2, `analysis/roles/operator-needs.md`.

## D-078 — 2026-08-27 — Lane mechanics: workspace env, Codex hook, privileged DinD, hand-written on-demand binding

Adopted under D-053 (bulletproofing round 1). Amends D-039/D-058 wiring.
Amended by D-085 (item (1): a lane is a template merged into a per-task
saved workspace `task-<id>`, because a saved workspace is selected only by
name and pins one `workdir`), D-090 (item (4): the file is
`~/.config/jackin/config.toml`), and D-091 (item (3): the DinD grant never
serves a nested `jackin load`; launch-based verifies are host parts).

**Decision.** jackin has no per-workspace model or effort knob today; the
only model source is the manifest's `--model`. Therefore: (1) M1-13 writes
`sync_source_dir` directly into `~/.config/jackin/workspaces/<lane>.toml`
and sets Claude lanes' model and effort by workspace `env`
(`ANTHROPIC_MODEL=<id>`, `CLAUDE_CODE_EFFORT_LEVEL=medium`); `[claude].model`
is removed from `jackin-the-architect` (D-074) and from the three crew
manifests so the env applies. (2) Codex lanes get their model and effort
from a role `hooks/source.sh` step that idempotently writes `model` and
`model_reasoning_effort = "medium"` into `$CODEX_HOME/config.toml` from
workspace env (`JACKIN_LANE_CODEX_MODEL`), because jackin syncs only
`auth.json`; the reviewer's hook rule widens to include `config.toml`.
M3-01's `LoadOptions.model`/`effort` supersede both. Before M1-13, no model
flag is passed (the account home's default is the lane's model) and effort
is pinned the same way. (3) Rootless DinD is unproven under OrbStack and
jackin's sidecar spec has no seccomp or capability knob, so builder lanes
use `[docker.grants] dind = "privileged"`; M1-13 proves `docker info` and
`docker run --rm hello-world` inside one builder-lane load and files
`tasks/M1-13/dind.out`, which later tasks cite as the tier of record.
(4) The on-demand `OP_SERVICE_ACCOUNT_TOKEN` binding is written by hand
into `~/.config/jackin/config.toml` (the file jackin reads, `paths.rs`;
corrected by D-090 from the earlier `~/.jackin/config.toml`) under
`[roles."donbeave/crew-operator".env]`
as `{ op = "op://tailrocks/op-service-account-jackin-operator/credential",
path = "tailrocks/op-service-account-jackin-operator/credential",
on_demand = true }` (`path` is mandatory); `jackin config env set` is not
used for this key because it stores a launch-time value; a `--on-demand`
flag is a D-046 jackin extension owned by M3-01. The crew-operator manifest
does not declare the variable as interactive (the value arrives at exec
time), so the launch has no env prompt. (5) The three `jackin load
--dry-run --format json` verifies are replaced by checks against surfaces
that exist (`jq -r .data.role`, `jackin role published-image`, `docker
image inspect` label, real launches for `default_agent`).

**Rationale.** Each item names a knob or output the plan assumed and the
code does not have; leaving them would make M1-05d, M1-13, M3-02a, and
M11-02 fail their own verify.

**Consequences.** `ROADMAP.md` M1-05b, M1-05d, M1-13, M3-01, M3-02a, M11-02,
§4, §5, M1 preflight; `SPEC.md` §9c; `concept/roles.md` §3.1, §3.2, §5, §7;
`concept/task-format.md` example; `analysis/roles/jackin-dev-needs.md` §3.

## D-079 — 2026-08-27 — Reviewer identity and verdicts before M8; merge authorization lives in the task text

Adopted under D-053 (bulletproofing round 1). Amends D-055 wiring.

**Decision.** While the reviewer's `gh` identity equals the PR author
(every review before M8-01, and any later PR opened by the forwarded `gh`),
the review event is always `COMMENT`; the verdict is the first body line
`verdict: REQUEST_CHANGES|COMMENT` plus `blocking:`/`major:`/`minor:`
prefixes on inline comments; a 422 from the Reviews API is never retried
with the same event. Real `REQUEST_CHANGES` is used only when `gh api user`
login differs from the PR author. Review verify: a review by the configured
login whose `commit_id` equals the head SHA in `tasks/<review-id>/pr.txt`
and whose body carries a `verdict:` line; the checklist lines from the
review's final message are appended to the Linear issue by the host session
(M6-02 write-back once it exists), never by the reviewer, which has no
Linear access. The reviewer's `gh` is the same repo-scope token as the
builder's; policy and the read-only mount, not scope, limit it. A task
prompt that names a merge is the operator's per-PR "merge it": the
`TASK.md` template gains a fixed "Authorization (D-055)" section, the crew
role `AGENTS.md.d/00-common.md` and the `.jackin/WORKFLOW.md` land frame
carry the same sentence, and the crew-builder threat model reads "merges
its own PR when the task says so".

**Rationale.** GitHub rejects `REQUEST_CHANGES` and `APPROVE` from the PR
author; jackin's own `.github/AGENTS.md` demands a per-PR operator "merge
it", which the GOAL prompt forbids asking for, so the authorization must be
in the artifact the agent reads.

**Consequences.** `concept/roles.md` §1, §3.1, §3.2 verdict flow, §6;
`analysis/roles/review-role-and-conventions.md` A.5;
`analysis/roles/jackin-dev-needs.md`; `concept/task-format.md` template;
`ROADMAP.md` review rows, M1-05a, M1-05c, §4 role table.

## D-080 — 2026-08-27 — Linear OAuth wiring: loopback redirect, placeholder webhook URL, secret never in argv

Adopted under D-053 (bulletproofing round 1).

**Decision.** The Linear OAuth app's callback URL is the literal
`http://localhost:53682/callback` (nothing serves it; the authorization code
is read from the browser's final URL with `agent-browser url` after the
expected connection-refused page). Webhooks are enabled with the category
"Agent session events" on the fixed, intentionally unreachable URL
`https://jackin-webhook.invalid/linear`; Linear auto-disables it after
failed deliveries, which polling (Q-015, D-053) tolerates; the signing
secret is stored anyway, so `concept/credentials.md` row 2 becomes CREATE
(stored, unused until a relay exists). The token exchange passes the client
secret through `curl --config -` fed from `jackin-exec op read` on stdin,
never as an argument. The item is the single
`linear-workspace`, whose `url key` field holds the `organization.urlKey`
from `viewer` (D-108). The whole procedure lives in the M1-10
row so M1-01 copies it into `tasks/M1-10/TASK.md`.

**Rationale.** Without a redirect URI and a capture procedure the agent
would invent a public URL or stop; two documents disagreed on whether the
webhook secret exists.

**Consequences.** `ROADMAP.md` M1-07, M1-10, M1-11; `concept/credentials.md`
rows 1 and 2.

## D-081 — 2026-08-27 — Host-side verification parts, evidence secret scan, and read-count wording

Adopted under D-053 (bulletproofing round 1). Amends D-061 and D-013.
Amended by D-086 (item (1): `verify.sh` takes `container|host` and the
host part asserts the container verdict, so the concatenation can never
mask a failure; the in-container part runs through `docker exec`, never
typed into the TUI), D-087 (item (3): a fourth log tag `pre-read`, one
`write` line per logical write with a `kind`), and D-091 (item (1): a
launch of or attach to a jackin instance is always a host part).

**Decision.** (1) D-061 extends from `host` rows to host-side checks: any
verify part that needs the Linear token, `op`, the host daemon socket, or
host `docker ps` runs in the host session whatever the task's role; the
in-container part holds unit and fixture checks only. Affected rows split
their verify into `container:` and `host (D-061):` sentences; both outputs
are concatenated into `tasks/<id>/verify.out` and the last line is the host
part's verdict when one exists. Before M4-03 exists, the in-container part
on the container path runs through `tmux send-keys` and `capture-pane`;
from M4-03 through `jackin daemon exec`. (2) `verify.sh` never runs with
`set -x`, never uses `curl -v`/`--trace`, and passes secrets only via
`-H @-`/`--config -` from stdin; before any evidence file is committed the
session runs `gitleaks detect --no-git --source tasks/<id>` (or the fixed
regex `(lin_api_|lin_oauth_|ops_|ghp_|github_pat_|eyJ[A-Za-z0-9_-]{20,})`);
a hit deletes the file, files a preflight defect for rotation, and blocks
the commit. Field non-emptiness is checked with `jq -e '(.value // "") |
length > 0'`, never `has("value")`. (3) D-013's "reads once" means one
issue-content read at pickup; the M2-03 candidate, session, and activity
polls and the M6-02 pre-write `description` read are not issue-content
reads; writes are exactly one per transition, heartbeat, or tick. The
daemon's structured log tags `poll`, `issue.read`, and `write` events so
proof-run verifies count them with `grep -c`. (4) M2-02 gains a fourth
read: per non-terminal session, `agentSession(id){activities(filter:
{createdAt:{gt:$since}})}` with a per-session watermark, aliased into one
request per tick, emitting `prompted` events; on the daemon path, the host
session answers an elicitation by PTY injection through `jackin hardline
<instance>` (or `jackin daemon exec`), and Linear-UI replies are made by
the proof task's own `crew-operator`; an answer only the human can give
files the `exhausted`/defect row instead of waiting. (5) M6-02 is
read-modify-write on the fresh description, aborting only if the matching
`- [ ]` line is gone; M5-04 changes labels in one `issueUpdate` carrying
`addedLabelIds` and `removedLabelIds` together.

**Rationale.** The daemon under test runs on the host and the Linear token
never enters a container (D-023), so live checks cannot run inside;
`verify.out` is committed to a public repository (D-065); the literal
"one read, nothing else" was unsatisfiable by the polling design.

**Consequences.** `ROADMAP.md` M1-07, M2-02, M2-06, M3-05, M3-06, M4-01,
M4-03, M4-04, M4-05, M5-04, M5-06, M6-02, M6-03, M7-03, §1 M5/M6 proof cells;
`SPEC.md` §7 read sentence; `concept/task-format.md` `verify.sh` contract;
`goal/EXECUTION.md` §5.

## D-082 — 2026-08-27 — Execution mechanism per runtime, container-path dialog handling, and resume checks

Adopted under D-053 (bulletproofing round 1). Amends D-036 wiring.
Amended by D-085 (items (1)–(2): the `CODEX_HOME=`/`CLAUDE_CONFIG_DIR=`
prefixes select nothing in `jackin load`; the account comes from the
per-task workspace; the prefixes remain only for the `codex exec` interim
and the host probes of item (4)) and D-086 (item (2): one-line prompt
pointing at the staged `.jackin/task/TASK.md`, eject by container name
recorded in `tasks/<id>/container.txt`, teardown before any re-launch;
item (3): an idle surviving tmux session is a finished attempt).

**Decision.** (1) In-session subagents are always Claude on this session's
`~/.claude`; the `subagents` path therefore serves Claude lanes only
(L1..L3, model per subagent, counted against the `~/.claude` cap). Codex
lanes (L4..L6) run through the `container` path with the lane's account
home (`CODEX_HOME=<home> jackin load <role> --agent codex`, `the-architect`
for the bootstrap tasks) and, only while no loadable role exists or the
D-046 interim requires it, as a detached host process
`CODEX_HOME=<home> codex exec --dangerously-bypass-approvals-and-sandbox
-C ~/.jackin/managed/<id>/<repo> -c model_reasoning_effort=medium
'<prompt>'` in `tmux`, output tee'd to `tasks/<id>/codex.log`; one process
per Codex home. A fallback that crosses runtimes changes the mechanism,
not the path name; the `PROGRESS.md` lane cell records where the work
actually ran (`L4 → L1 (host)`), never silently. (2) The container path
launches `tmux new-session -d -s <id> -x 200 -y 50 "env -u CI
TERM=xterm-256color JACKIN_NO_MOTION=1 jackin load <role> --agent
<runtime>"`, polls `tmux capture-pane -p` until the capsule tab strip and
the runtime prompt are visible (15-minute cold-build budget) before
`send-keys -l '<prompt>'` + `Enter`; it answers capsule dialogs itself
(trust → confirm; jackin-exec picker → verify the command is the task's
`op` invocation, then `Space`, `Enter`; restore picker → new instance;
anything else → `Escape` and the stuck rule); a capsule dialog is never a
preflight defect; every unexpected dialog is filed as a jackin gap owned
by M3-01; after `verify.sh` prints DONE the session runs `jackin eject
<role>` then kills the tmux session. Streaming build and pull output counts
as evidence for the 30-minute stuck clock. (3) On resume, an `in-progress`
row without a `PROGRESS.md` row is checked for a surviving run (`tmux
has-session -t <id>`, `docker ps` by issue label, `jackin daemon status
--format json`) and re-attached before anything is restarted; a README row
not `done` whose id has a `done` `PROGRESS.md` row is restored to `done`;
the session runs each open `PREFLIGHT-DEFECTS.md` proof command itself and
fills `Resolved` when it passes; after any context compaction the session
repeats §1 steps 2–3 before dispatching. (4) Forwarded logins: an
in-container login failure is a preflight defect only when the host-side
probe (`claude -p ok` under `CLAUDE_CONFIG_DIR`, `codex exec 'print ok'`
under `CODEX_HOME`) also fails; otherwise the attempt is re-launched with
re-synced state and `re-sync` noted in the result cell. M1-13 evaluates
jackin's OAuth-token mode (`claude setup-token`, `jackin workspace
claude-token setup`) for L1..L3 and copies a rotated Codex `auth.json` back
to the lane home after each run (D-046 fix if absent).

**Rationale.** Claude Code subagents cannot switch runtime or account home;
the launch TUI raises dialogs a blind `send-keys` lands in; a restart
without checking for a surviving run dispatches the same task twice.

**Consequences.** `goal/EXECUTION.md` §1, §2, §3 table, §4, §5, §6;
`goal/PREFLIGHT.md` §1; `GOAL.md` prompt; `ROADMAP.md` M1-13;
`analysis/roles/operator-needs.md` §8 wording.

## D-083 — 2026-08-27 — The `/goal` argument carries the terminal facts; BLOCKED needs a quiet run and ends on script output

Adopted under D-053 (bulletproofing round 2). Amends D-069 and D-070.

**Decision.** The invocation is no longer `/goal Follow GOAL.md` but the
one-line argument printed in `GOAL.md`: the goal is reached only when the
current turn ends with (A) the literal output of `sh verify.sh` whose last
line is `status: DONE`, or (B) a final message whose first line is `GOAL
BLOCKED`, followed by the open `PREFLIGHT-DEFECTS.md` rows and the literal
`sh verify.sh` output (`status: PENDING <n> remaining`); any other turn end
is not the goal. (B) additionally requires that no row is `in-progress` or
`waiting` — the session waits on those with a Monitor loop until each
reaches `done` or `blocked` — and that no row is runnable. If the runner
re-prompts after a BLOCKED end, the session repeats `goal/EXECUTION.md` §1
steps 1–4 (proof commands may now pass; an `exhausted:` row opens a new
epoch, D-084) and continues if anything became runnable; otherwise it
prints the same `GOAL BLOCKED` block again and ends the turn. The session
is not required to keep a turn open through a quota wait: with a
fact-based condition a mid-wait turn end is safe because the judge cannot
accept it and re-prompts.

**Rationale.** The runner's stop condition is the argument text judged
against the transcript; "Follow GOAL.md" is satisfiable by any turn that
reads like a summary, so the loop could stop with containers still
running, and if the judge did not accept a BLOCKED statement the old
"repeat the statement and do nothing" rule looped without bound. Putting
both outcomes on script output makes either verdict a fact, and requiring
a quiet run keeps D-071 true (a quota wait or a live container is never a
reason to end).

**Consequences.** `GOAL.md` invocation line, prose, and prompt (B);
`goal/EXECUTION.md` §1 step 6, §6, §7; `goal/PREFLIGHT.md` line 3 and §6;
`ROADMAP.md` §6 entry point; `README.md`; `PREFLIGHT-DEFECTS.md` header.
Every document points at that one line instead of copying it, so the text
cannot drift.

*Clarified 2026-08-27: the line is printed in `README.md` "Start the run";
`GOAL.md` holds only the prompt the runner executes. The rule is unchanged.*

## D-084 — 2026-08-27 — Attempt epochs; `exhausted:` rows have no proof command; `blocked` never propagates

Adopted under D-053 (bulletproofing round 2). Amends D-070.

**Decision.** (1) An `exhausted: <id>` row carries `re-run` in its proof
cell instead of a proof command: `sh tasks/<id>/verify.sh` cannot pass
until the task is re-executed, so it could never clear the row. At the
next session start, if the row's task is still `blocked` and `Resolved` is
empty, the session fills `Resolved` with its start timestamp, sets the task
to `ready`, and opens a new attempt epoch recorded in the `PROGRESS.md`
result cell (`epoch 2: 0/3`); `limits.attempts` applies per epoch; a
second exhaustion files a new row. If the human finished the task by hand
(`verify.sh host` already passes), the session closes it instead. The
crash-resume protection of D-070 is untouched: an interrupted `in-progress`
task never passes through an `exhausted:` row and keeps its count. (2) A
dependent of a `blocked` task keeps its own status (`ready`) and is merely
not runnable; only a row with its own open `PREFLIGHT-DEFECTS.md` row is
ever `blocked`, so the singular reset of §1 step 2 is correct by
construction, and a `blocked` row whose id appears in no open row is
reset to `ready` at session start.

**Rationale.** With the verify script as proof and a counter at its cap
that never resets, every exhaustion was a permanent stall across every
resume. With propagation, resolving one row un-blocked only the task named
in it, leaving dependents `blocked` with no open row — a state that is
neither (A) nor (B), on which the loop would spin.

**Consequences.** `goal/EXECUTION.md` §1 step 2, §3, §6; `GOAL.md` prompt
clause (b); `PROGRESS.md` and `PREFLIGHT-DEFECTS.md` headers;
`tasks/README.md` status legend; `goal/PREFLIGHT.md` §6.

## D-085 — 2026-08-27 — A lane is a template merged into a per-task saved workspace `task-<id>`

Adopted under D-053 (bulletproofing round 2). Amends D-078 (1) and D-082
(1)–(2).

**Decision.** `jackin load` resolves a saved workspace only when it is
named as `TARGET` (`jackin load <role> <name>`) or when the current
directory equals the profile's `workdir` exactly; `LoadArgs` has no
`--workspace` flag; the account folder comes only from
`resolve_sync_source_dir` (workspace × role → workspace → global config),
and jackin reads `CLAUDE_CONFIG_DIR`/`CODEX_HOME` of the launching process
nowhere. One profile per lane therefore cannot serve many task checkouts.
Instead: before every container launch the host session registers the
saved workspace `task-<id>` (`jackin workspace create task-<id> --workdir
~/.jackin/managed/<id> --mount ~/.jackin/managed/<id>`) and merges the
lane's template into `~/.config/jackin/workspaces/task-<id>.toml`. Before
M1-13 the template is `tasks/M1-02a/lanes/L<n>.toml`, written by M1-02a
(host, wave 2) and holding only `[claude]`/`[codex] sync_source_dir` — the
sole account selector for the multi-Codex waves 3 and 5; from M1-13 on it
is `tasks/M1-13/lanes/L<n>.toml` with `sync_source_dir`, `[env]` (model
id, effort), and `[docker.grants]`. The launch is `jackin load <role>
task-<id> --agent <runtime>` from `$HOME` (the name `task-<id>` cannot
collide with a directory the target classifier would pick), and
`--dry-run --format json` must report `.data.workspace == "task-<id>"`; an
ad-hoc load is a plan defect. Host `CODEX_HOME`/`CLAUDE_CONFIG_DIR`
prefixes are dropped from the container command and remain only for the
`codex exec` interim (argv) and the host-side login probes. M1-13's verify
proves one throwaway per-task-style workspace per lane (account, model,
and, for builder lanes, the DinD grant in the plan) instead of `jackin
workspace show <lane>`. The workspace is removed (`jackin workspace remove`) after the `PROGRESS.md`
row.

**Rationale.** Without this, waves 2–3 ran three tasks on one Codex
account, fallback hops landed on the exhausted account, and after M1-13
every lane's model, account, and DinD setting was silently absent for
every container-path task.

**Consequences.** `goal/EXECUTION.md` §2, §3 table, §4 container row and
lane rule; `ROADMAP.md` §2 intro, M1-02a, M1-13, §5 prose; `SPEC.md` §9c;
`GOAL.md` prompt.

## D-086 — 2026-08-27 — Container-path mechanics: staged task folder, two-part `verify.sh`, one-line prompt, eject by name, host build refresh, single writer

*Amended by D-111: the single-writer rule applies to the state store; the
Markdown ledgers are generated projections.*

Adopted under D-053 (bulletproofing round 2). Amends D-074 (push protocol
for this repository), D-081 (1), D-082 (2)–(3).

**Decision.** (1) The container never sees this repository, so the host
session stages `tasks/<id>/TASK.md`, `task.toml`, `verify.sh`, the
`## References` files (under `refs/`), and for reviews `pr.txt` into
`<workspace>/.jackin/task/` (excluded through `.git/info/exclude`) before
the launch; `TASK.md` is authored container-relative
(`.jackin/task/refs/<name>`); M1-12 embeds the full `TASK.md` text in the
issue description; M4-04 pre-fetches into the same `.jackin/task/` layout,
so both paths share one prompt shape. (2) `verify.sh` is POSIX `sh`
(`dash -n`, `shellcheck -s sh`), takes `container` or `host` as `$1`, and
when a container part exists the host part first asserts that
`verify.container.out` ends with `status: DONE`; `verify.out` is the
concatenation and the task is verified only when its last line is
`status: DONE`. The container part runs through `docker exec -u agent -w
/workspace <container> sh .jackin/task/verify.sh container` (from M4-03
`jackin daemon exec`), never as keystrokes into the runtime TUI;
`capture-pane` serves progress reading only. (3) The prompt is one line
sent with `send-keys -l` and confirmed in the input box before `Enter`:
for `goal` delivery the `/goal Read this file: .jackin/task/TASK.md …`
line, for `prompt` delivery `Read .jackin/task/TASK.md and follow it as
your task prompt`; a multi-line `TASK.md` is never typed (the first
newline submits, the rest lands as stray turns). (4) After the runtime
prompt appears the session records the container name in
`tasks/<id>/container.txt`; eject is always `jackin eject "$(cat
tasks/<id>/container.txt)"`, never by role class (which errors when two
instances of the role run) and never `--all`. Before any re-launch of the
same id the previous attempt is torn down (`tmux kill-session`, then
`jackin eject` by name); a surviving tmux session whose runtime is idle
with the prompt answered is a finished attempt and goes straight to
verify. (5) For every task whose `repos` include `jackin`, the host build
is refreshed before the host part (`git checkout --detach
origin/feat/managed-execution` in the checkout recorded in
`tasks/M1-02/checkout.txt`, `CI=1 cargo install --path crates/jackin
--locked --force` and the same for `jackin-capsule`, sha assertion, daemon
restart plus D-073 reconciliation); a stale binary consumes no attempt.
(6) This repository has one writer: the host session. Container, subagent,
and daemon tasks leave ecosystem changes in their managed checkout or emit
files (`tasks/M1-12/issues.json`), the session imports and commits them,
and before every edit of `tasks/README.md`, `PROGRESS.md`, or
`PREFLIGHT-DEFECTS.md` it runs `git fetch origin && git rebase origin/main`
(replace-by-id for the README, append for the ledgers, never `--force`).

**Rationale.** Each item removes a proven stall: an absent `tasks/<id>/`
inside the container, a host verdict masking a failed container part,
bash-isms passing macOS `sh -n` and failing dash, a multi-line prompt
submitting on its first newline, `jackin eject <role>` erroring on two
concurrent the-architect instances, `tmux new-session` failing on a
duplicate name, host parts calling daemon features the stale binary lacks,
and two writers racing on `tasks/README.md`.

**Consequences.** `goal/EXECUTION.md` §1 step 2, §2, §4 container row and
rules, §5 steps 0, 4a, 5, 6a, 7; `concept/task-format.md` `TASK.md` and
`verify.sh` contracts; `ROADMAP.md` M1-01, M1-02, M1-12, M4-04;
`tasks/README.md` header; `goal/PREFLIGHT.md` §1 (`dash`, `shellcheck`);
`GOAL.md` prompt.

## D-087 — 2026-08-27 — Linear mechanics: client-credentials tokens everywhere, daemon-created sessions, one document per tick, rate-limit handling, `pre-read` tag, host closes every issue

Adopted under D-053 (bulletproofing round 2). Amends D-073 and D-081
(3)–(4).

**Decision.** (1) Tokens: the M1-10 authorization-code exchange installs
the app; every consumer then uses a `grant_type=client_credentials` token
(30 days, same scopes). The host session stores its token as `access
token` plus `expires at` in `op://jackin/linear-workspace` and
re-mints when fewer than 48 hours remain; each daemon instance (laptop,
M11, M12) mints its own in memory at start and at the threshold. Nobody
uses the refresh-token grant and nothing is written back, so no consumer
can invalidate another's token (Linear rotates refresh tokens on every use
with a 30-minute grace). (2) Sessions: Linear documents no agent session
for an `issueUpdate(delegateId)` made with the app token, so the daemon
treats a delegated issue in an active state with no non-terminal session
of the app user as a candidate and calls `agentSessionCreateOnIssue`
itself (skipped when a session exists); the host delegation step is the
one `issueUpdate`. M1-11 records whether API delegation creates a session
(a finding either way), and M2-07 and M3-05 exercise one host-delegated
scratch issue. A `response` activity is posted only when a session exists.
(3) Rate budget: Linear's 5,000 requests per hour is per app user per
workspace, shared by every poller and writer. All reads of a tick are
aliased root fields of one GraphQL document (one request per tick, about
720 per hour); `RATELIMITED` arrives as HTTP 400 with
`errors[].extensions.code` and `X-RateLimit-Requests-Reset`, and the tick
pauses until that reset, logs `poll ratelimited until <t>`, and queues
heartbeats and writes; in M12 only the manager host polls. (4) Log tags:
`poll`, `issue.read`, `pre-read` (the M6-02 pre-write description read),
and `write`, one `write` line per logical write with a `kind` even when a
tick issues several mutations; proof-run verifies count these tags and
treat `poll ratelimited` as a `poll` line. (5) Closing: the host session
moves every finished task's issue to the `completed`-type state on every
path for the whole run; M9-01's Done-on-merge serves scratch issues only,
because D-074 keeps `feat/managed-execution` unmerged and a roadmap issue
is never moved to `merging`; the D-073 reconciliation also runs at every
daemon restart and at §5 step 9.

**Rationale.** The 24-hour access token would 401 the first host write
after M1-10; a single rotating refresh token cannot be shared by four
consumers; a session-first daemon never dispatched a host-delegated issue;
a literal "nothing else" log assertion was unsatisfiable next to `poll`
lines and heartbeats; and after M9-01 nothing closed roadmap issues, so
their `blocks` relations never resolved.

**Consequences.** `ROADMAP.md` M1-10, M1-11, M2-01, M2-02, M2-03, M2-07,
M3-05, M5-06, M6-03, M12-02, §1 M5/M6 proof cells, §6 item 8;
`goal/EXECUTION.md` §4 daemon row and Linear-token rule, §5 steps 7 and 9;
`concept/credentials.md` row 3 and §5.4; `SPEC.md` §5, §6 step 12, §10c;
`GOAL.md` prompt.

## D-088 — 2026-08-27 — Graph amendments: M11-01a; M1 wave 5 split; M2+ tasks wait for M1-12; M11-01 starts with M11; M10-02 owns the CONTRIBUTING clause; M1-01's verify is state-independent

*Amended by D-114: no `<milestone>-00 authoring` task remains in the graph.*

Adopted under D-053 (bulletproofing round 2). Amends D-054, D-072, D-073.

**Decision.** (1) New task M11-01a "Merge jackin `feat/managed-execution`
to `main` and republish the preview validator" (the-architect, L2,
`depends_on` M10-05), and M11-02 gains `depends_on` M11-01a: the
`jackin-role-action` validator used by every role `ci.yml` and by
`publish.yml` is built by jackin's `preview.yml` from `main` only, `main`
knows manifests up to `v1alpha6`, and the crew manifests are `v1alpha7`
from M3-02a, so without the merge M11-02 could never publish (a missing
edge; the branch-artifact alternative fails `publish.yml`'s attestation
check against `refs/heads/main`). D-055 forbids releases and tap
publishes, which this merge is not. Role `ci.yml` is expected red from
M3-02a until M11-01a and is never a stuck signal. The task count is 81.
(2) M1 wave 5 splits into {M1-06, M1-08} then {M1-03, M1-13}, because a
throwaway `jackin load` inside a task is lane use (Codex-home cap 1,
`crew-operator` cap 1): M1-06's operator load ejects before M1-03 starts,
and M1-13's per-lane loads run one at a time, each only when that lane's
account home has no running container. (3) Every M2+ task except M3-01,
M3-03, M4-02, M4-03 is runnable only when the M1-12 row is `done` (an
implicit dependency, so no `depends_on` cell changes); those four may run
before their issues exist, on the `subagents` or `container` path only,
and M1-12 creates their issues afterwards in the state matching the row
(its scope covers every non-`planned` M2+ row). No M6..M12 authoring
begins before M1-12 is `done`; an authoring step that fails its check
three times is filed `exhausted: <milestone>-00`. A runnable task of the
lowest unfinished milestone always takes a free slot before an early-start
task. (4) M11-01 is not an early-start task: it starts with M11 after
M10-05, and its scope records the per-role `op://` mapping without
switching any configuration (the switch lives in M11-03, server config
only). (5) M10-02's first commit writes the termrock `CONTRIBUTING.md`
agent-authored-changes clause; M10-03 starts once that commit is on
`origin/feat/managed-execution` (a prose gate on the same lane pair, no
new edge). (6) M1-01's verify no longer asserts `PENDING <total − 1>`:
its row is `in-progress` when step 5 runs, so the clause was false by
construction; it now asserts `tasks: <total> expected, <d> done` with `d`
the count of `done` rows, a `status: PENDING` last line, and no missing
row or script for any M1..M5 id, and no task verify ever asserts the
remaining count or its own row status.

**Rationale.** D-054 allows graph changes only through a decision; each
item removes a proven stall (an unpublishable image, a violated cap, an
M1-12 re-run demanded before M1-12 could exist, a laptop config switch
that would break every later forwarded login, an unowned gate, and a
deterministic first-task failure).

**Consequences.** `ROADMAP.md` M1-01, M1-06, M1-13, M3-02, M3-02a, M10
milestone row, M10-02, M11 preflight, M11-01, M11-01a, M11-02, counts, §3
wave table, §5 lane table; `goal/EXECUTION.md` §3, §5 step 1;
`concept/roles.md` §4, §7, §8; `GOAL.md` prompt.

## D-089 — 2026-08-27 — GitHub mechanics: the-architect CI switch in M1-13, three repositories keep the branch, merge protocol, DCO hook, named workflows, scratch repository under `jackin-project`, App on all repositories

Adopted under D-053 (bulletproofing round 2). Amends D-064, D-065, D-074,
D-076 (1).

**Decision.** (1) `jackin-project/jackin-the-architect` `main` requires
`ci-required` and `DCO` with no bypass actors, and its `ci.yml` routes
`pull_request` to an offline velnor runner; the switch to GitHub-hosted
runners therefore happens in the first the-architect PR of the run
(M1-13), in the same PR as the manifest change, before `gh pr checks
--watch` and `gh pr merge --squash`; M3-02 inherits it. (2)
`delete_branch_on_merge` is turned off in preflight on `jackin`,
`jackin-the-architect`, and `termrock`; the merging task still merges
`origin/main` back and confirms the branch exists. (3) Merges to a
protected `main` use only `gh pr merge --squash` after the required checks
are green; `--admin` never works; a check pending on a self-hosted label
is the task's own CI defect. (4) DCO: the role images install a
`prepare-commit-msg` sign-off hook (template `githooks/` via
`core.hooksPath`; the-architect in M1-13), every `TASK.md` says `git
commit -s`, and a pre-push gate counts trailers; the single exception to
"never `--force`" is `git rebase --signoff` plus `--force-with-lease` on
the-architect's single-writer branch to add missing trailers. (5) M1-04a
ships exactly three named workflows on `ubuntu-latest`, never the velnor
fleet templates; `publish.yml` of `jackin-role-action` defaults every
runner input to `velnor-target-mvp`, so every caller passes GitHub-hosted
labels explicitly (M11-02). (6) The scratch repository is
`jackin-project/jackin-managed-scratch`, created by M3-07 with no branch
protection and recorded in `tasks/M3-07/scratch-repo.txt`, which every
later scratch issue reads; the `jackin-daemon` App is installed with
`repository_selection == all` in both organizations and not on the
`donbeave` account, so no `donbeave/*` repository is ever a daemon target;
M8-01 asserts the scratch repository is reachable with the `jackin-project`
installation token; M9 merges use that token. D-065's "every repository we
create is public" now includes this organization-owned one.

**Rationale.** Verified live: the M1-13 merge would wait forever on an
offline runner, the first squash would delete the pinned branch, one
unsigned Codex commit would make the merge unreachable, and a scratch
repository created under `donbeave` would 404 every App-token push.

**Consequences.** `goal/PREFLIGHT.md` §2; `goal/EXECUTION.md` §4 branch
and DCO rules; `ROADMAP.md` M1-04a, M1-13, M3 preflight, M3-02, M3-07,
M4-06, M6-03, M7/M9 preflights, M8-01, M8-03, M9-02, M11-02, M11-04,
M12-03, §6 step 6; `concept/roles.md` §4, §7; `concept/task-format.md`
template.

## D-090 — 2026-08-27 — Operator and host facts: auto-lock Never is mandatory, corrected tool commands, runtimes in use, server host contract, M11-01 verifies and M11-03 wires, `op` by direct download, session reserve rule

Adopted under D-053 (bulletproofing round 2). Amends D-071, D-076 (3) and
(5), D-077, D-078 (4).

**Decision.** (1) 1Password auto-lock Never (and lock-on-sleep off) is a
hard precondition with no fallback: the host session's `op read` of the
operator binding in `tailrocks` and of every Linear token in `jackin`
need the unlocked desktop app, and a service account cannot serve
`tailrocks` or `Private`; if the policy forbids Never the run cannot be
unattended and is not started; a lock during the run is a preflight
defect. (2) agent-browser 0.35.1: the login commands are `agent-browser
--headed --profile … --session operator open <url>` for Linear and GitHub
(a bare invocation does nothing), the standing proof reads `agent-browser
state --help`, `close --all` names the session, and a cookie count on
`state.json` proves the state is not empty; the same commands are the
M1-06 re-login. (3) The operator config file is
`${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml`; `~/.jackin/` is
state only and `~/.jackin/config.toml` is never created; M1-05d's verify
is authoritative on `jackin config env list --format json`, with the grep
as a secondary check. (4) Runtimes in use = `claude`, `codex`, plus every
runtime whose `tasks/M4-05/` matrix row is not `skipped`; M11-01 verifies
exactly that set and files no defect for others. The server host contract
(`goal/PREFLIGHT.md` §5): SSH user in the `docker` group, passwordless
`apt-get`, `git`, `curl`, `build-essential`, `clang`, `pkg-config`,
outbound HTTPS, the `arch` field; the host session materialises the SSH
key from 1Password; the branch build is compiled on the server (no release
exists for the branch and this Mac cross-compiles nothing); the human
never runs `jackin daemon install`. M11-01 records the per-role `op://`
mapping and changes nothing; M11-03 writes it into the server daemon's
config only; the laptop keeps `auth_forward = "sync"` for the whole run,
and early-started tasks never touch `~/.config/jackin/config.toml`. D-055's
"no release before M11" reads "no release or tap publish in this run; M11
uses branch builds". (5) `op` 2.39.0 is installed in the operator image by
direct download of the versioned zip from `cache.agilebits.com` with
per-arch sha256 (`concept/roles.md` §3.1 records the values), because the
apt repository keeps only the current version. The operator manifest
sketch drops `[claude] model` and the `[env.OP_SERVICE_ACCOUNT_TOKEN]`
table (`EnvVarDecl` has no `secret` key; an interactive declaration would
raise a launch prompt) and gains `AGENT_BROWSER_EXECUTABLE_PATH`. (6) The
host session's own `~/.claude` budget: before dispatching anything that
draws on it the session reads `jackin usage host snapshot --agent claude
--format json` (there is no `jackin usage host accounts`) and shrinks the
caps at 40 % and 20 % remaining; Claude Code's "Continue automatically at
usage limit" setting is a preflight item, because a limited session cannot
run a poll; time spent limited counts against no task's stuck clock.

**Rationale.** Each item was verified on the host or in the code: the
failing `--help` grep would have filed a defect at every start, the wrong
config path would have exhausted M1-03 on the critical path, the
service-account fallback covered only the daemon, the apt pin fails on the
next `op` release, and the polled recovery from a session limit was
impossible by construction.

**Consequences.** `goal/PREFLIGHT.md` §1, §2, §5; `goal/EXECUTION.md` §1
step 4, §4 reserve and login rules, §6; `ROADMAP.md` M1 and M2 preflight
paragraphs, M1-05b, M1-05d, M1-06, M11 and M12 preflights, M11-01, M11-03,
§6 step 6; `concept/roles.md` §3.1, §3.2, §5, §7; `concept/task-format.md`
example; `analysis/roles/operator-needs.md` §2 and install list;
`DECISIONS.md` D-078 (4) text.

## D-091 — 2026-08-27 — Verify contracts: launch-based checks are host parts, temporal checks assert on snapshots, `lanes.json`, reviews pin the SHA in `pr.txt`

Adopted under D-053 (bulletproofing round 2). Amends D-058, D-078 (3),
D-079, D-081 (1).

**Decision.** (1) Any verify that launches a jackin instance, calls
`jackin hardline`, or asserts on a real container is a `host (D-061):`
part run by the host session from the checkout in
`tasks/M1-02/checkout.txt`: jackin never mounts the host Docker socket,
the DinD sidecar shares only the TLS certs volume with the role container,
and a nested `jackin load` bind-mounts paths from the launcher's own
filesystem, so the capsule sockets never reach a test inside the sidecar.
The `container:` sentences of M3-01, M3-04, M3-05, M4-02, M4-04 name
fakes or in-process capsule sessions; the DinD grant serves `docker
build`/`docker run` work only, and no DinD volume persists for nested
launches. (2) A verify that asserts a transient live state is written
against a snapshot the task files while the state holds (M5-06
`view-during.json`/`view-after.json`, M1-11 `issue.json`/`session.json`,
M3-04 `status-before/after.json`), never against the live query at verify
time, so a resume cannot fail a finished proof. (3) M1-13 records the lane
facts in `tasks/M1-13/lanes.json` (`L1..L6` → `runtime`, `model_id`,
`effort`, `label` = `model:<model_id>`, `account_home`); M1-09 and M1-12
compare label sets with `jq -r '.[].label'`; the `model:*` label value is
the exact model id, never a short name. (4) Reviews: `pr.txt` is three
lines (URL, head SHA to review, previous review SHA), never rewritten on a
retry; the reviewer receives it staged in `.jackin/task/`, reviews `git
diff <line 3>..<line 2>`, and posts one JSON payload with `commit_id` =
line 2 (`gh api --input -`, since `-f` cannot be mixed with `--input`);
the verify accepts that `commit_id` or a later head that has it as an
ancestor, so concurrent pushes to the rolling branch cannot fail eleven
review tasks.

**Rationale.** Each unfixed item was a deterministic three-attempt
exhaustion: nested launches under DinD, "exactly three issues" asserted
after the task itself cleared one, an unnamed record that two verifies
grep for weeks before it exists, and a `commit_id` compared with a head
that moves before the review is posted.

**Consequences.** `ROADMAP.md` M1-09, M1-11, M1-12, M1-13, M3-01, M3-04,
M3-05, M4-02, M4-04, M5-06, all eleven review rows; `goal/EXECUTION.md`
§4 subagents row, §5 steps 5 and 6a; `concept/task-format.md` model row
and `verify.sh` contract; `concept/roles.md` §3.2 verdict flow; `SPEC.md`
§4 model row; `analysis/roles/jackin-dev-needs.md` §3; `GOAL.md` prompt.

## D-092 — 2026-08-27 — The host session is Fable at medium effort; every subagent is Opus

*Amended by D-095: the exact model ids and the effort are pinned there.*

Adopted under D-053. Amends the last sentence of D-071 ("research and
verification subagents on Claude use the cheapest model") and D-036.

**Decision.** The `/goal` run is driven by one Claude Code session on the
host Mac running Fable 5 at medium effort. Fable capacity is the scarce
resource of the run, so the session spends it on coordination only:
every subagent it spawns is launched with `model: "opus"`, whatever the
subagent does — reading a large file, researching, implementing,
verifying, or producing proof. The cheapest-model clause of D-071 is
replaced by this rule; the D-071 reserve rule and the three-in-flight cap
on host subagents are unchanged, because both count `~/.claude` draw, not
model price. The session's own reading is capped: `GOAL.md`, `AGENTS.md`,
`goal/EXECUTION.md`, `goal/PREFLIGHT.md`, `tasks/README.md`,
`PROGRESS.md`, `PREFLIGHT-DEFECTS.md`, and the current `tasks/<id>/`
folder. It never `Read`s `ROADMAP.md`, `SPEC.md`, `DECISIONS.md`,
`concept/*`, or `analysis/*`; it may `grep` one literal out of them, and
anything larger is a subagent's job. Every subagent returns at most 15
lines: verdict, evidence paths, next action.

**Rationale.** A session that reads `ROADMAP.md` (117 KB) and
`DECISIONS.md` (118 KB) once per wave exhausts the account before M3, and
a compaction then destroys exactly the state the run depends on. Opus
subagents carry that cost on a budget that is not the bottleneck, and a
15-line contract keeps their output from re-importing what was delegated
away.

**Consequences.** `AGENTS.md` "Delegation law" and "Token economy",
`GOAL.md` prompt, `SPEC.md` §6, and `goal/EXECUTION.md` §2 delegation
bullet plus the new §8 host-session budget carry this wording; D-071's
cheapest-model sentence is struck.

## D-093 — 2026-08-27 — Exhausted rows are closed by the human; fixed final-message shape; task-folder files are not "implementation"

Adopted under D-053; applies the `/goal`-semantics findings of
`analysis/bulletproof-round3-findings.md` (R3-38, R3-62 documentation
part, R3-63, R3-66, R3-67). Amends D-084, D-083, D-069, D-038.

**Decision.** (1) Resume: an `exhausted: <id>` row in
`PREFLIGHT-DEFECTS.md` is closed only when the human has filled its
`Resolved` cell. The session never fills it and never opens a new attempt
epoch on its own; at a session start a still-open `exhausted:` row keeps
its task `blocked`, and a re-prompt with nothing else runnable reprints
the same `GOAL BLOCKED` block. A row whose `Resolved` cell is filled
re-opens the task as `ready` in a new epoch (`epoch 2: 0/3`). This
replaces the auto-close clause of D-084; the missing-input half of D-084
is unchanged — those rows still have a proof command the session re-runs
and fills itself. (2) The attempt counter of a task lives in
`tasks/<id>/attempts.log` (append-only, one line per attempt: epoch,
attempt, lane, verify.out path, UTC), never in session context, so a
resume after a compaction or a crash re-derives it from the file.
(3) Final message shape, both outcomes: line 1 is `GOAL COMPLETE` or
`GOAL BLOCKED`; then the report of `goal/EXECUTION.md` §7; then the open
`PREFLIGHT-DEFECTS.md` rows (BLOCKED only); then the literal output of
`sh verify.sh` as the last lines, with nothing after it. (4) Files under
`tasks/<id>/` — `verify.sh`, `task.toml`, and text evidence (`.out`,
`.log`, `.json`, `.toml`, `.txt`, `.cast`) — and the root `verify.sh` are
the complete set of non-Markdown files this repository may hold; the
"no implementation" rule of D-038/D-045 excepts them all, not only
`verify.sh`. (5) Run mode: any `tasks/README.md` row that is not
`planned` means a run is under way and this session is the host session;
after a compaction or a re-prompt it re-reads `GOAL.md` and
`goal/EXECUTION.md` §1 and §5 and re-derives state from
`tasks/README.md`, `PROGRESS.md`, `tasks/<id>/attempts.log`, and
`git log` only.

**Rationale.** Auto-closing an `exhausted:` row makes BLOCKED
non-terminal: a runner that re-prompts gets a fresh epoch on a task
nothing has changed, and the run spins on the same failure until the
account is empty. An attempt count held in context is lost by the
compaction that a long run guarantees. A fixed final-message shape is the
only thing a judge can check without reading prose.

**Consequences.** `AGENTS.md` two-modes table, run-mode item, stuck rule;
`GOAL.md` prompt clause (b) and both terminal clauses; `goal/EXECUTION.md`
§1 step 2, §5 steps 3 and 5, §6, §7 and the new §8;
`PREFLIGHT-DEFECTS.md` and `tasks/README.md` header prose; `SPEC.md` §6
step 8; `README.md` working rules. The remaining findings of
`analysis/bulletproof-round3-findings.md` stay unapplied and keep their
archive status.

## D-094 — 2026-08-27 — `GOAL.md` is the pure `/goal` prompt; the invocation lives in `README.md`

**Decision.** `GOAL.md` contains only the prompt the `/goal` runner executes
(≤4000 characters: mission, sources of truth, laws, task loop, resume,
termination, never). Everything about how to start the run — prerequisites,
the exact line to paste, the two outcomes — lives in `README.md` "Start the
run" and `goal/EXECUTION.md` §1. Supersedes the D-083 wording "the
invocation line of GOAL.md".

**Rationale.** A prompt that explains itself wastes its own character
budget and dilutes instructions; the human reads README, the runner reads
GOAL.md.

**Consequences.** Pointers updated in PREFLIGHT-DEFECTS.md, ROADMAP.md §6,
goal/PREFLIGHT.md, AGENTS.md. Task count in GOAL.md follows `verify.sh`
(81 ids incl. M1-01's wave-0 row).

## D-103 — 2026-08-28 — Every normative decision lives in `DECISIONS.md`

**Decision.** D-018..D-031 are moved into `DECISIONS.md` as `## D-0NN`
headings in id order, between D-017 and D-032. No normative decision text
lives outside `DECISIONS.md`; a concept document may elaborate a decision
and must point at the heading instead of restating it.

**Rationale.** `README.md` ("If it is not in `DECISIONS.md`, it is not
decided") and `AGENTS.md` ("Whether a point is decided: `DECISIONS.md`
only") already assert this invariant, while fourteen decisions cited as
normative by `SPEC.md` and `ROADMAP.md` sat only in
`concept/borrowed-from-symphony.md` with no anchors (K-39).

**Consequences.** `concept/borrowed-from-symphony.md` keeps a pointer in
place of the draft text; `SPEC.md` line 8 cites `DECISIONS.md` for
D-018..D-031. Any future proposal drafted in a concept document is moved
into `DECISIONS.md` when it is adopted.

## D-107 — 2026-08-28 — `D-056` is amended by `D-071`; amendments are reciprocal

**Decision.** The `~/.claude` concurrency cap for this run is 2. `D-056`
carries an "Amended by D-071" note directly under its heading, and
`SPEC.md` §6 step 2 states 2 rather than 3. Every decision that amends or
supersedes another carries the forward note in the amending decision and
the reciprocal note in the amended one, in the same commit.

**Rationale.** `ROADMAP.md` §3, `GOAL.md` and `goal/EXECUTION.md` already
enforce 2 citing D-071, while `SPEC.md` still said 3 citing D-056 and
D-056 recorded no amendment. A reader following the precedence rules
reached the wrong number (K-41).

**Consequences.** `SPEC.md` §6 step 2 and `DECISIONS.md` D-056 are
corrected here. Any later amendment adds both notes; the cross-document
invariant lint (D-105) checks caps and reciprocal amendment notes.


## D-104 — 2026-08-28 — Decision recording is delegated; the session only commits

**Decision.** The host session never edits `DECISIONS.md` or `SPEC.md`
directly. When a decision has to be recorded (D-053), the session
delegates the edit to a subagent, which appends the decision to
`DECISIONS.md` and corrects `SPEC.md` in the working tree and returns the
decision id and the touched paths. The session then commits and pushes
both files in one commit.

**Rationale.** The host session budget forbids reading `DECISIONS.md` and
`SPEC.md`, yet also required the session to write them when D-053 applies.
An in-place edit requires a read, so the pair was unsatisfiable and no
escape hatch was named (K-42).

**Consequences.** `goal/EXECUTION.md` §8 drops `DECISIONS.md` and
`SPEC.md` from the session's "Write" bullet and states the delegation;
`AGENTS.md` and `GOAL.md` say the same. Committing a file the session did
not read stays allowed, because the subagent reports what it wrote.

## D-108 — 2026-08-28 — 1Password item names carry no unresolvable slug

**Decision.** No `op://` path in this repository contains an unresolved
`<org>` placeholder. The Linear workspace item is the single item
`op://jackin/linear-workspace`; the organization `urlKey`, the app user
id, and the organization id are fields of that item and are also written
to `tasks/M1-10/linear-org.txt` as non-secret evidence. GitHub App items
are named with the literal organization: `github-app-jackin-daemon-jackin-project` and `github-app-jackin-daemon-tailrocks`.

**Rationale.** `<org>` appeared in eleven `op://` paths and was never
resolved, so no host verify could name the item deterministically (K-36).
The GitHub organizations are literals today (`gh api user/orgs`), but the
Linear `urlKey` does not exist until M1-10 runs the authorize flow and
`op` may be signed out on the host, so an item name that embeds it can
never be written in advance. Removing the slug from the name makes the
path a constant and keeps the workspace identity as data inside the item.

**Consequences.** `goal/EXECUTION.md` §4, `ROADMAP.md` M1-09, M1-10,
M8-01 and its §5 preflight paragraph, and `concept/credentials.md` §5.1,
§5.3, §5.4 use the literal names. M1-10 additionally files
`tasks/M1-10/linear-org.txt`. Only one Linear workspace is in scope; a
second one would need a new decision, not a slug.

## D-095 — 2026-08-28 — Host model, subagent model, permission mode, allowlist

**Decision.** The run is launched with `claude-fable-5` at effort high for
the host session, and every subagent is launched with `claude-opus-5`;
both are exact model ids, not family aliases. The permission mode is
`dontAsk`, and the allowlist that mode uses is committed in
`.claude/settings.json` in this repository, together with `"model":
"claude-fable-5"` and a deny list for `git push --force` and `git push
-f`. `README.md` "Start the run" names the launcher flags.

**Rationale.** The repository named no permission mode and no launcher
flags at all, and pinned the models only as family aliases (K-23, K-24,
K-25). An unattended run that must never prompt cannot rely on a mutable
alias or on whatever mode the operator happens to start in, and a
permission profile that is not committed cannot be reviewed or resumed.

**Consequences.** `.claude/settings.json` is the second non-Markdown file
allowed in this repository (with the root `verify.sh` and `tasks/<id>/`);
`AGENTS.md` and `README.md` say so. `AGENTS.md` and `goal/EXECUTION.md`
now read `model: "claude-opus-5"` where they read `model: "opus"`. D-092
is amended by this decision. A tool the run needs that the allowlist does
not cover is added to `.claude/settings.json` in the same commit as the
task that needs it, never answered by a prompt.

## D-109 — 2026-08-28 — A readiness-hardening run precedes the implementation run (plan proposal D-096)

**Decision.** A readiness-hardening run precedes the implementation run.
The implementation `/goal` is armed only after a static readiness gate and
a live host readiness gate both print `status: READY` for the same lock
hash. The static gate reads the committed plan, the compiled graph, and
the task bundles; the live gate runs on the host that will execute the
run and proves the tools, credentials, accounts, and permission profile
are actually present. Either gate printing anything other than
`status: READY`, or the two naming different lock hashes, leaves the
implementation run unarmed.

**Rationale.** The previous arrangement had the implementation run compile
its own plan and write its own oracle inside the same run, so a defect in
the plan could not be distinguished from a defect in the work, and nothing
proved the host was capable before the first product task started (K-03).

**Consequences.** `SPEC.md` §9e states the two gates and the shared lock
hash. `run/LOCK.toml` carries the lock hash both gates print. No product
task of M1..M12 runs during the readiness-hardening run.

## D-110 — 2026-08-28 — Four machine terminal classes derived by `verify.sh` (plan proposal D-097)

**Decision.** The run has four machine terminal classes, replacing the two
current ones: `DONE`, `BLOCKED HUMAN`, `FAILED SYSTEM`, and `PENDING`.
Each is derived by `verify.sh` from the state store, never asserted by the
model. `DONE` means every task is `done` with its evidence; `BLOCKED
HUMAN` means the only open reason is a `PREFLIGHT-DEFECTS.md` row naming
an input only a human can provide; `FAILED SYSTEM` means a plan, tool, or
environment defect stopped the run and no human input would unblock it;
`PENDING` means work remains and is runnable. `verify.sh` prints the class
as its last line.

**Rationale.** With only `DONE` and `PENDING`, a plan defect could be
filed as a human prerequisite and end the run as BLOCKED, so a defect in
the plan masqueraded as a missing operator input (K-27).

**Consequences.** D-069 is amended by this decision: the root `verify.sh`
gate has four outcomes, not two. `SPEC.md` §9e and `GOAL.md`'s termination
text name the four classes; `README.md` "Start the run" keeps COMPLETE and
BLOCKED as the human-facing names of `DONE` and `BLOCKED HUMAN` and adds
`FAILED SYSTEM`. A model may not write a terminal class into any file.

## D-111 — 2026-08-28 — Run state is an atomic store; the ledgers are generated projections (plan proposal D-098)

**Decision.** Authoritative run state lives in an atomic state store under
`run/` — `run/state.db` or `run/events.jsonl`, text preferred. Its records
carry, per task, the status, the `leased`, `resource-waiting`, and
`failed-system` flags, the lease owner, the epoch, the fencing token, and
the attempt history. `tasks/README.md` and `PROGRESS.md` are generated
projections of that store and are never hand-edited; regenerating them
from the store is the only way their content changes.

**Rationale.** A task transition previously required editing several files
by hand in one commit, so an interruption left the repository in a state
no rule described, and restart reconciliation depended on reading prose
(K-26).

**Consequences.** D-038 and D-086 are amended by this decision:
`tasks/README.md` and `PROGRESS.md` become generated, and the single-writer
rule applies to the state store rather than to the Markdown ledgers.
`SPEC.md` §8 describes the store and its fields; `AGENTS.md` names the
three added statuses. A hand edit to a projection is a defect, not a
transition.

## D-112 — 2026-08-28 — One worktree and branch per task; one integrator lease per repository (plan proposal D-099)

**Decision.** Each task works in its own git worktree on its own branch
`managed/<run-id>/<task-id>`, created from the base SHA locked in
`run/LOCK.toml`. Workers never push the integration branch
`feat/managed-execution`; they push only their own task branch. Merging a
task branch into the integration branch is done by an integrator that
holds the single integrator lease for that repository, one lease per
repository at a time. Verification runs against the integrated SHA, not
against a worker's branch tip.

**Rationale.** D-046, D-047, and D-074 permit several concurrent writers
on one shared branch, so two tasks running in parallel in the same
repository could rebase, force, or clobber each other, and a verify could
pass on a tree nobody ever integrated (K-16).

**Consequences.** D-046, D-047, and D-074 are amended by this decision.
`SPEC.md` §9d states the worktree, the branch name, the lease, and the
integrated-SHA rule; `AGENTS.md` "Repositories, branches, commits" says
the same. Role repositories keep `main` as their effective branch (D-074),
but a task that changes one still works in its own worktree and branch and
reaches `main` through the integrator lease.

## D-113 — 2026-08-28 — Idempotency keys on external mutations; leases carry fencing tokens (plan proposal D-100)

**Decision.** Every external mutation — a push, a merge, a pull request, a
Linear write, a release — carries an idempotency key equal to
`hash(run, task, attempt, operation)`. Every runnable task holds a lease
recorded in the state store with an owner, an epoch, and a monotonically
increasing fencing token; a mutation whose fencing token is lower than the
one the store holds for that task is refused.

**Rationale.** Nothing prevented a superseded agent — one whose lease had
expired after a stall, a compaction, or a container restart — from pushing,
merging, or writing to Linear after its replacement had started, and a
retried mutation could take effect twice (K-28).

**Consequences.** `SPEC.md` §8 and §9d state the key and the fencing rule.
The state store fields of D-111 hold the lease owner, epoch, and fencing
token. An operation that cannot carry an idempotency key must be made
naturally idempotent before it is used.

## D-114 — 2026-08-28 — All 81 task bundles are content-addressed and materialised before any product task runs (plan proposal D-101)

**Decision.** All 81 task bundles are content-addressed, materialised in
full before any product task runs, and their hashes recorded in
`run/LOCK.toml`. There is no runtime task-authoring phase: no task
authors another task's bundle while the run is under way.

**Rationale.** M1-01 and the `<milestone>-00 authoring` tasks made the run
compile parts of its own plan mid-flight, so the plan the gate checked was
not the plan that ran, and a bundle could change under a task that had
already read it (K-01, K-05).

**Consequences.** D-062, D-072, and D-088 are amended by this decision:
task folders for every milestone exist before the run starts, M1-01 is no
longer an authoring task, and no `<milestone>-00 authoring` task remains
in the graph. `SPEC.md` §10b drops the "materialises them for M1..M5
first" clause. A bundle whose hash does not match `run/LOCK.toml` fails
the static readiness gate of D-109.

## D-115 — 2026-08-28 — Every `analysis/` findings archive needs a disposition file (plan proposal D-102)

**Decision.** Every findings archive under `analysis/` must have a
disposition file, `findings/disposition.toml`, with one row per finding —
the finding id, its disposition (`fixed`, `superseded`, `rejected`,
`open`), and the evidence for that disposition — before any run that
touches the archive may start.

**Rationale.** 71 of the 76 R3 findings had no traceable disposition, so
"probably fixed" was indistinguishable from "never looked at", and a run
could start on top of an unreviewed defect list (K-47).

**Consequences.** `findings/disposition.toml` is a permitted machine file
(D-118). The static readiness gate of D-109 fails when an archive a run
touches has no disposition file or has a finding with no row.

## D-116 — 2026-08-28 — A cross-document invariant lint runs in CI (plan proposal D-105)

**Decision.** A cross-document invariant lint runs in CI and fails when
two authoritative documents disagree. It checks at least: the status of
every question in `OPEN-QUESTIONS.md` against `DECISIONS.md`; every
concurrency cap stated in more than one file; every existence claim about
a file or a repository; and every decision citation, including that each
cited id exists and that amendments carry both notes (D-107).

**Rationale.** The precedence rules of `AGENTS.md` alone did not prevent
K-40, K-41, K-45, or K-46: a reader following them still reached the wrong
number, because nothing mechanically compared the documents.

**Consequences.** The lint is a CI job of this repository. A disagreement
is a CI failure, fixed by correcting the documents, never by relaxing the
lint.

## D-117 — 2026-08-28 — `main` is protected; volatile run state is published as generated snapshots (plan proposal D-106)

**Decision.** `main` of this repository is protected by a GitHub ruleset.
Volatile run state — the projections of D-111 and the run ledgers — is
published as generated snapshots rather than committed to `main` after
every task transition. The plan of record on `main` changes only through
a reviewed, rule-checked change.

**Rationale.** The plan of record and the mutable ledger shared one
unprotected branch, so the record a gate reads could be rewritten by any
routine ledger write (K-22).

**Consequences.** The `AGENTS.md` rule "commit and push this repository
after every task transition" applies to the state store and its published
snapshots, not to a `main` commit per transition. The ruleset itself is a
human prerequisite and is filed in `goal/PREFLIGHT.md`.

## D-118 — 2026-08-28 — The Execution mode permits machine files at exactly these paths

**Decision.** The `AGENTS.md` "Two modes" Execution row is amended: machine
files are permitted at exactly these paths and nowhere else —

- `tools/` — the DAG compiler, the state store, the supervisor, and the
  fixture runner, written in POSIX `sh` or Python 3 standard library only;
- `tests/fixtures/` — the fixtures the fixture runner accepts and rejects;
- `run/LOCK.toml` — the lock the readiness gates of D-109 share;
- `run/state.db` or `run/events.jsonl` — the state store of D-111, text
  preferred;
- `findings/disposition.toml` — the disposition file of D-115;
- `.claude/settings.json` — the permission profile of D-095;
- the root `verify.sh` (D-069);
- under `tasks/<id>/`: `TASK.md`, `task.toml`, `verify.sh`,
  `expected-evidence.toml`, `evidence.json`, `refs/`, and text evidence
  (`.out`, `.log`, `.json`, `.toml`, `.txt`, `.cast`).

**Rationale.** D-109 through D-117 require runnable tooling and machine
state that the previous Execution row did not permit, and an open-ended
permission would return this repository to being a codebase. An exact list
keeps the planning character of the repository while letting the readiness
tooling exist.

**Consequences.** D-038, D-069, and D-095 are amended by this decision.
`AGENTS.md` "Two modes" and `README.md` "Working rules" carry the list;
`concept/task-format.md` names `expected-evidence.toml` and
`evidence.json`. A machine file at any other path is a defect. No
binaries, archives, or generated artifacts (D-059).

## D-119 — 2026-08-28 — One runnable predicate, quoted verbatim wherever it is stated

**Decision.** Whether a `tasks/README.md` row may be dispatched is decided
by a single predicate paragraph, headed `Runnable predicate (D-119)`. Its
text is: a row is runnable iff its status is `ready`; every `depends_on`
id is `done`; a lane slot is free under the caps — at most two host
subagents drawing on `~/.claude` and at most three host subagents in
flight (D-071) — plus the §4 reserve rule of `goal/EXECUTION.md`; and, for
M2+ ids other than M3-01, M3-03, M4-02, M4-03, the M1-12 row is `done`
(D-088); rows `planned`, `blocked`, `waiting` or `in-progress` are not
runnable and do not count as `done` (D-084). `GOAL.md` "Task loop" and
`goal/EXECUTION.md` §3 carry that paragraph byte-identically, and
`tools/roadmap_compile.py` and the state store cite it rather than
restating it. Wave order, milestone priority, and early starts are
scheduling policy in `goal/EXECUTION.md` §3, not part of the predicate.

**Rationale.** `GOAL.md` gated M2+ tasks on `depends_on`, caps, and M1-12
only, while `goal/EXECUTION.md` §3 added a status condition, a
lowest-unfinished-milestone priority, and a closed early-start set, and
`AGENTS.md` gave no precedence between the two files — two schedulers for
one run (K-14). `GOAL.md` also stated no host-subagent cap, so the D-071
reserve was invisible at the entry point (I-22).

**Consequences.** Any change to runnability edits the paragraph in both
files in one commit; the cross-document invariant lint (D-116) compares
them byte for byte. D-084 and D-088 are cited by the predicate and
unchanged.
