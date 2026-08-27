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
says so.

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
shows clear progress. The daemon does not make repeated requests to the
tracker while working; it reads once and writes on completion of items.

**Rationale.** One read plus write-on-progress keeps tracker traffic and
rate-limit exposure minimal, keeps the agent's working state local and
fast, and gives the human progress in the tool they already watch.

**Consequences.** The checklist format is part of the task contract
(`concept/task-format.md`). Write-back is idempotent (re-pushing the same
checklist is safe). Per-item verification (`verify.sh`, D-003) applies to
checklist items where present; how checklist items and verification
scripts relate is Q-014.

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
