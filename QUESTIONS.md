# Questions Q-001..Q-025

Every design question raised while planning, with the text it was asked in
and the decision that closed it. Nothing here is open: `OPEN-QUESTIONS.md`
holds the open list and it is empty. A `Q-0nn` reference anywhere in this
repository resolves to a heading below. New questions are appended here with
their closing decision, in `DECISIONS.md` order.

## Q-001 — Where does the manager live?

Is the manager logic compiled into the jackin daemon binary, or is it a
separate binary in the jackin-project organization that connects to one or
more jackin daemons? Affects release cadence, breaking-change exposure
(jackin is pre-stable), and whether one manager can drive daemons on
several hosts.

**Closed by D-053** (recommended answer adopted): inside the jackin daemon
binary for the prototype, revisited at M12. Narrowed first by D-008 (the
manager is a client of the daemon's programmatic interface) and D-026 (one
manager, one daemon per host). D-066 settles that there is no second
product: it is the jackin daemon and the feature is "managed execution".

## Q-002 — What is the project's name?

Every document used the placeholder "the manager"; does the product get its
own name and brand?

**Closed by D-066**: no separate product name. It is the jackin daemon
(`jackin daemon`) and the feature is called "managed execution"; a second
brand would add surface without adding capability.

## Q-003 — What is the machine-readable source of truth for roadmap state?

Task folders and status files on a git branch that the daemon polls or
watches, a local database owned by the daemon with the git branch as input,
or a mix where git is the plan and the daemon owns runtime state? Affects
how the human marks "ready", how several machines share state, and how
history is kept.

**Closed by D-010**: an issue tracker is the source of truth, and Linear is
the only tracker. The daemon holds no authoritative task state and rebuilds
its view from the tracker and local workspaces after restart; the task-folder
layout of `concept/task-format.md` is the local working copy of an issue.

## Q-004 — How are dependencies between tasks declared?

A manifest per task listing prerequisite task identifiers, a plan-level graph
file, or inferred from folder order? Can a task depend on an external
condition (a CI run, a human approval) rather than on another task? Narrowed
by D-010 to Linear blocking relations; the remaining half was whether the
daemon refuses to start a blocked issue or assignment alone is the gate.

**Closed by D-020**: dispatchability is computed from Linear blocking
relations and issue state; the daemon refuses to dispatch an issue that is
still blocked, and `Human Review`-style states are simply non-dispatchable
states.

## Q-005 — Who produces the decomposition?

The issue author writes the checklist (D-013), but may a planner agent be
assigned an issue whose output is a set of new issues or a checklist
(Symphony's follow-up pattern), and must the human approve before those
become assignable?

**Closed by D-067**: roadmap issues are created and assigned by agents;
planner roles are allowed (D-028), and agent-proposed follow-up issues
dispatch by themselves only when carrying the `auto-dispatch` label. No
human approval step sits in the loop (D-050).

## Q-006 — Who writes the verification scripts, and how are they trusted?

A verification script written by the same agent that implements the task
proves little. Options: scripts authored during planning before execution,
scripts reviewed by a separate verifier agent, or a mix of task-level scripts
and plan-level integration verification.

**Closed by D-053** (recommended answer adopted), narrowed by D-030: the
verification command is fixed by the issue author before execution, the
daemon runs it, and the agent's own completion bar is separate from it.
Reviews by a separate reviewer role are non-blocking (D-055).

## Q-007 — How do parallel task results merge?

One branch per task merged by the manager after `DONE`, one worktree per task
on a shared branch, or task results as pull requests reviewed by a review
role before merge? Affects conflict handling and what "done" means for the
plan as a whole.

**Closed by D-053** (recommended answer adopted), narrowed by D-014 (a task
names its repository and branch) and D-031 (merge is an agent-executed,
daemon-confirmed attempt): no integration branch and no merge queue; a task
delivers a pull request on its own branch, and agents merge it (D-055).

## Q-008 — What is the failure and retry policy?

What happens when verification never reaches `DONE`: retry with the same
agent, retry with a different runtime or model, split the task, or escalate
to the human? What limits apply on attempts, time, and tokens per task?

**Closed by D-021** (retry, backoff, stall detection, and workspace reuse),
completed by D-027 (failure classes decide recovery) and D-057 (automatic
lane fallback on quota exhaustion or a stuck run).

## Q-009 — What decisions are escalated to the human, and how?

Which events qualify as a genuine decision, how the inbox is presented (TUI,
desktop, phone), and how an answer flows back to a paused agent.

**Closed by D-068**: escalation stays in Linear and the host session handles
it; blocked, stuck, and elicitations are Linear-visible states (D-029,
D-049, D-051). No separate inbox surface is built.

## Q-010 — How are resources bounded?

Limits on concurrent agent containers per host, per provider account, and per
Linear project or team; whether those limits live in a repository-level
policy file, a daemon config, or Linear. Narrowed by D-017 (local machine
only for the prototype) and D-022 (concurrency caps and dispatch order).

**Closed by D-053** (recommended answer adopted): daemon config
`max_concurrent_agents = 2` on the laptop plus a per-role cap of 1 for
`crew-operator`, nothing else until M11. D-056 later fixes the host caps for
this run.

## Q-011 — What does the manager's terminal interface show?

Minimum: roadmap and task graph, per-task status and live log, approval
inbox, agent fleet. Which of these are termrock gaps versus product widgets
is listed in `analysis/termrock.md`; the product-side scope was undecided.

**Closed by D-053** (recommended answer adopted), bounded by D-016 (attach
through the capsule is a first-class action) and D-025 (the daemon exposes a
state snapshot; no UI is on the correctness path).

## Q-012 — How does the manager relate to jackin's existing session model?

Does a "task run" map to one jackin session, can sessions be created and
observed programmatically, and what must jackin add?

**Closed by D-008**: a task run maps to a container started by the daemon and
observed through the daemon; the daemon owns container lifecycle, status, and
reconciliation after restart.

## Q-013 — How are role, runtime, and prompt expressed on a Linear issue?

Labels, issue template fields, a fenced block or front matter in the
description, or a project-level default with per-issue override? Linear has
no custom fields and no structured checklist; labels are the only structured
per-issue property a template can pre-set.

**Closed by D-053** (recommended answer adopted): label groups `role:*`,
`agent:*`, `model:*`, `effort:*`, `delivery:*`, `repo:<owner/name>`, and
daemon-maintained `run:*`; branch defaults to Linear's own `branchName`,
overridable by a `branch:` line, with an optional `base:` line; the prompt is
the issue description and the checklist is the first task list. Fed by D-012,
D-014, D-043, D-044, D-049, and D-052.

## Q-014 — How do checklist items relate to verification scripts?

One verification per issue run by the daemon after the checklist is complete,
a verification reference per checklist item, or the agent's own verification
subagent per item with the daemon verifying only at the end?

**Closed by D-030**: the checklist is the agent's completion bar and the
issue's single verification command is the daemon's proof; the daemon
verifies once, at the end.

## Q-015 — Webhook or polling?

Linear delivers `AgentSessionEvent` webhooks only to a public HTTPS endpoint
(HMAC-signed, 3 retries, HTTP 200 within 5 s, first activity within 10 s,
sessions `stale` after 30 min idle); no long-poll or websocket exists;
polling `issues(filter:{delegate})` works but `agentSessions` has no filter.
D-017 excludes direct webhooks to the laptop. Options: a relay service, a
tunnel per host, or polling only.

**Closed by D-053** (recommended answer adopted): polling only is the
correctness path (5 s for sessions, 30 s for reconciliation); a relay is a
later accelerator, and no public endpoint is required. D-080 fixes the
unreachable webhook URL and loopback callback used at app creation.

## Q-016 — Which jackin agent roles build this product?

The exact set of roles (one per project type, one operator, one reviewer?),
their names, and their contents. Narrowed by D-045: new roles under the
`donbeave` GitHub account, existing roles untouched.

**Closed by D-045 for ownership and reuse and by D-050 for the set**: three
`crew` roles under `donbeave` from a template repository, loaded from their
default branch with trust pre-granted, unpublished until M11; the operator
performs every browser proof.

## Q-017 — Where does the `agent-browser` profile directory live, and how is it mounted?

A persistent browser profile is needed for the browser proofs (D-032); where
it lives on the host, which roles may mount it, and how it is protected.

**Closed by D-053** (recommended answer adopted): `~/.jackin/
agent-browser-profile` on the host, mounted read-write and scoped to
`donbeave/crew-operator` only, listed as a secret in the operator's
`AGENTS.md`, never backed up to 1Password. D-077 amends the wiring: the
browser session travels as agent-browser storage state and the operator image
uses Debian Chromium.

## Q-018 — How does an agent write to 1Password from inside a container?

Credentials must be created into 1Password (D-035) by tasks that run in a
container (M1-03, M1-07, M1-10, M8-01, M11-01), while no long-lived token may
sit inside that container.

**Closed by D-053** (recommended answer adopted): a 1Password service account
scoped to vault `jackin` (read + write) with its token in `tailrocks`,
delivered per invocation by an on-demand `jackin-exec` binding that resolves
the `op://` value on the host and injects it into the one in-container `op`
command with redacted output; the daemon's separate read-only account arrives
with M11-01.

## Q-019 — Does the Linear agent app live in a dedicated workspace or the existing one?

Linear recommends a dedicated workspace for agent apps; the existing
workspace is already in daily use.

**Closed by D-053** (recommended answer adopted): the existing workspace — a
single admin owns it, so the dedicated-workspace argument does not apply yet.

## Q-020 — Which working-branch names does the effort use?

One branch name across jackin, termrock, the role repositories, and this
repository, or a per-repository choice?

**Closed by D-047**: `feat/managed-execution` in every involved repository;
this repository commits to `main` directly. The earlier "roles use
`feat/agent-browser`" wording is withdrawn; role repositories are effective
on `main` (D-074).

## Q-021 — Two schema bumps under jackin's one-bump-per-PR rule

`default_agent` (M3-02) and the initial prompt field (M4-01) are two manifest
schema bumps, and jackin allows one bump per pull request.

**Closed by D-053** (recommended answer adopted): land them in one PR as
`v1alpha7` if M3-02 and M4-01 ship together, otherwise accept two consecutive
versions. Round-3 review (`analysis/bulletproof-round3-findings.md`) narrows
this further: `default_agent` is the single manifest bump of the run, and
M4-01 carries the prompt in the launch env `JACKIN_INITIAL_PROMPT` with no
manifest field, because `cargo xtask schema-check` diffs against `main` at
merge time.

## Q-022 — How does the daemon launch a locally rebuilt role non-interactively?

Role-branch loads require an interactive trust dialog, which no daemon can
answer.

**Closed by D-053** (recommended answer adopted): roles load from their
default branch with trust pre-granted per host by `jackin config trust grant
<selector>` (no wildcard); `--role-branch` is unusable non-interactively, and
the daemon reports a missing grant as a validation failure.

## Q-023 — Repository-to-issue mapping: explicit on the issue or a team default?

Every task names the repository it works on (D-014); does that name live on
each issue or in a team-level default?

**Closed by D-053** (recommended answer adopted): an explicit
`repo:<owner/name>` label on the issue (part of the Q-013 convention); a team
default is added later only if the label becomes noise.

## Q-024 — How does the daemon pick an account and model per issue?

jackin selects the account per workspace (`sync_source_dir`), not per launch,
and has no per-workspace model or effort knob.

**Closed by D-043 and D-053**: the issue names model and effort (D-043), and
`LoadOptions` gains `account`, `model`, and `effort` in M3-01 so the daemon
chooses per launch; until then one lane template per lane (M1-13) with the
lane expressed as an `agent:*` label value such as `agent:codex-chainargos`,
and effort pinned to medium by lane env (`CLAUDE_CODE_EFFORT_LEVEL`, Codex
`model_reasoning_effort`), the exact knobs verified in M1-13 (D-058). D-078
records that the Codex knobs are written in-container by the role hook, not
by a manifest field.

## Q-025 — How is host-side evidence collected from an operator container?

`docker ps`, `hardline` captures, and daemon logs are host-side, but proof
runs execute in the operator container.

**Closed by D-053** (recommended answer adopted): until a host bridge exists
the host session collects them into the proof-run folder (D-033, D-061), and
`jackin daemon evidence <instance>` is planned with M10-01 so proof runs
become fully containerized.
