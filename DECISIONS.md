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
wave planning in `ROADMAP.md` §3 may schedule up to three `~/.claude` tasks
at once.

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

## D-062 — 2026-08-27 — Task folders for M1..M5 now; later milestones when reached

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

**Decision.** D-001 is amended a second time: besides the task-level
`tasks/<id>/verify.sh` (D-038), exactly one more runnable file is permitted
in this repository — `verify.sh` at the repository root. It is the gate of
the whole roadmap run: it passes only when every task id in the `ROADMAP.md`
task tables has a `tasks/README.md` row in status `done` and a
`tasks/<id>/verify.sh` exists, and it prints `status: DONE` or
`status: PENDING <n> remaining` as its last line. It is read-only and has
no dependencies beyond POSIX `sh` and `awk`. The run itself is defined by
Markdown only: `GOAL.md` (the `/goal` prompt, under 4000 characters, run as
`/goal Follow GOAL.md`), `goal/EXECUTION.md` (session start, per-task
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
