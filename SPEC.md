# Specification — jackin managed execution

Status: **draft, living document**. This specification is improved in every
conversation that reaches agreement. It states only what is decided in
`DECISIONS.md`. Under D-050 and D-053 every recommended answer that existed
on 2026-08-27 is a decided default and is stated here as such; the three
questions that remain in `OPEN-QUESTIONS.md` (Q-002, Q-005, Q-009) block
nothing. The Symphony-derived rules D-018..D-031 are adopted as written in
`concept/borrowed-from-symphony.md` (D-053) and are cited by their numbers.

## 1. Purpose

The bar is a production-ready product and process for building software
with Linear + jackin (D-041).

Turn "work with an agent" into "assign an issue". A human creates a Linear
issue that names a repository, a branch, a jackin agent role, an agent
runtime, a model, an effort level, a prompt, and a checklist, then assigns
it to jackin. A jackin daemon on a host with Docker picks the issue up,
prepares the branch, starts the role in an isolated container with the
prompt, mirrors the checklist locally, pushes progress and live status back
to the issue, verifies the result, and manages the pull request on GitHub.
The human watches through the Linear issue, the jackin terminal interface,
or by attaching to the container, and answers only when asked. (D-002,
D-005, D-010..D-014, D-043, D-049)

## 2. Non-goals

- Building an agent harness. Vendor harnesses (Claude Code, Codex, Amp,
  Kimi, OpenCode, Grok) are used as shipped. (D-015)
- Redesigning jackin's interactive commands. They stay unchanged; the daemon
  is additive. (D-009)
- Any task source other than Linear. GitHub hosts repositories and pull
  requests only. (D-010, D-014)
- Multi-host operation in the first prototype. (D-017)

## 3. Components

| Component | Responsibility | Status |
| --- | --- | --- |
| Linear | Source of truth for issues, their fields, status, comments, and agent sessions. | exists |
| GitHub | Hosts repositories and pull requests. | exists |
| jackin CLI | Interactive sessions; unchanged. | exists |
| Host (prototype) | The developer's Mac running OrbStack 2.2.3 (`docker context orbstack`; 18 CPU, about 122 GiB available to Docker, 1.6 TiB free; no Docker Desktop). jackin treats it as a plain Docker daemon (`crates/jackin/src/preflight.rs:217`). Host-only steps and host-only `verify.sh` are run by the host Claude Code session that drives the roadmap (D-056, D-061). | exists |
| jackin daemon | Long-running per host. Monitors every agent container on the host (CLI- or daemon-started); polls Linear for issues assigned to jackin; prepares workspaces; spawns roles through the same container mechanism as the CLI; pushes progress and status; runs verification; manages pull requests. The manager logic (scheduler, retry policy, escalation, state snapshot) is compiled into the daemon binary for the prototype; whether it splits out is revisited at M12 (Q-001 adopted (a), D-053; D-026). | to build (D-008, D-009) |
| jackin capsule | In-container PID 1; the attach point for live visibility; source of the agent-state signal (working, blocked, idle, exit) the daemon reads. | exists (D-016), extended (D-051) |
| jackin agent roles | Dockerfile + `jackin.role.toml`: environment, skills, plugins. Selected per issue. Roles for this build: `the-architect` for every jackin and jackin-project task (D-048, used as is); `donbeave/crew-builder` for termrock, ecosystem, and the role repositories; `donbeave/crew-operator` for Linear, GitHub settings, 1Password items, and every browser proof; `donbeave/crew-reviewer` for pull-request reviews; `host` names a step the human performs on the developer machine. All three `crew` roles are built from `donbeave/jackin-role-template`, load from their default branch with trust pre-granted per host, and stay unpublished until M11. (D-045, D-053; `concept/roles.md`) | `the-architect` exists; `crew` roles to build |
| termrock TUI | Fleet, issue, log, and attach surface for the daemon; a client of the daemon snapshot, never on the correctness path. | to build (D-006, D-025) |

## 4. Issue contract

An issue that jackin executes must define the fields below. The convention
(Q-013, adopted by D-053) is: Linear label groups for the enumerated
fields, the description for the prompt, the first task list in the
description for the checklist, and Linear's own branch name for the branch
unless overridden by a line in the description.

| Field | Required | Where on the issue | Meaning |
| --- | --- | --- | --- |
| repository | yes | label `repo:<owner/name>` | GitHub repository the work is done in. (D-014; Q-023 adopted: explicit label, no team default) |
| branch | yes | Linear `branchName`, overridden by a `branch: <name>` line in the description | Branch to work on. Reused (pulled) if it exists on the remote; created otherwise. (D-014) |
| base branch | no, default `main` | `base: <name>` line in the description | Where a new branch is created from. (D-014) |
| role | yes | label `role:<selector>` (for example `role:the-architect`, `role:donbeave/crew-builder`) | jackin agent role to spawn, resolvable by name to a local build or a published image. (D-012) |
| runtime | yes | label `agent:<runtime>` (until M3-01 the lane value, for example `agent:codex-chainargos`; Q-024 adopted) | Agent runtime inside the role. (D-012) |
| model | yes, lane default if absent | label `model:<model_id>`, the exact identifier recorded in `tasks/M1-13/lanes.json` (D-058, D-091) | Model the runtime uses; a defaulted value is reported on the issue. (D-043) |
| effort | yes, default medium | label `effort:<level>` | Reasoning effort level; a defaulted value is reported. (D-043) |
| prompt | yes | issue description verbatim | Text passed to the agent, rendered inside the repository's prompt frame when one exists. (D-012, D-018) |
| delivery | no, default `goal` | label `delivery:goal` or `delivery:prompt` | `goal` = deliver as `/goal <prompt>` (iterate until verified); `prompt` = plain first message. (D-044) |
| checklist | yes | first Markdown task list in the description | The unit of progress; mirrored locally and written back per item. (D-013) |
| references | recommended | links or paths in the description | Schemas, contracts, designs the result must satisfy. (D-003) |
| verification | daemon-run | `.jackin/workflow.toml` `[verify] command` on the base branch | Executable check whose last line `status: DONE` is the only proof of completion. (D-003, D-018, D-030) |
| dependencies | when relevant | Linear blocking relations | Gate dispatch through `dispatchable`. (D-004, D-020) |

Daemon-maintained fields, written by the daemon and never by a human
(D-049, D-052, D-053):

| Field | Where on the issue | Meaning |
| --- | --- | --- |
| run state | exactly one label from the group `run:*` (`run:starting`, `run:working`, `run:waiting`, `run:blocked`, `run:stuck`, `run:failed`, `run:verifying`, `run:done`), cleared on terminal states | The state of the current run, filterable in project views. (D-049, D-051) |
| container identity | session `externalUrls` entry naming host, jackin instance name, container id, attempt, and attach command; one entry per attempt, replaced on re-dispatch; the ledger holds the machine-readable binding | Which container works on the issue, from launch to removal, across retries. (D-052, D-019) |

A missing required field is a validation failure reported on the issue as
one `error` activity naming the field; the issue is not started and the
condition is re-evaluated every tick. (D-012, D-020)

## 5. Trigger

Assignment of the issue to the jackin Linear agent app (scope
`app:assignable`) starts work. Creation alone does not. (D-011)

Polling is the correctness path (Q-015 adopted, D-053): the daemon polls
Linear every tick, 5 s for pending agent sessions and delegated issues and
30 s for reconciliation refresh — all reads of one tick aliased into one
GraphQL document, a rate limit (`RATELIMITED`, HTTP 400) pausing the tick
until the reset, and in M12 only the manager host polling (D-087) — and
never depends on a webhook to be correct. No public HTTPS endpoint is required, which is what a daemon
behind NAT needs (D-017). A webhook relay may be added later as a latency
accelerator that only requests an immediate tick. The acknowledgement
`thought` is posted within Linear's 10 s window from the poll that first
sees a pending session.

## 6. Execution

1. **Eligibility.** The Linear adapter derives one boolean `dispatchable`
   per issue: delegate is the jackin app user; workflow state type
   `unstarted` or `started` and neither the repository's review nor
   merging state; every `blocks` relation resolved (`completed` or
   `canceled`); required fields valid. Terminal (`completed`, `canceled`)
   stops the run and removes the workspace; any other state, or removal of
   the delegate, stops the run and keeps the workspace. A held issue gets
   one comment saying why. (D-020)
2. **Caps and order.** Slots are enforced per host, per repository, per
   repository state (`merging = 1`), and per provider account. Candidates
   sort by Linear priority, then oldest `createdAt`, then identifier; when
   every host is at capacity the daemon waits. Laptop defaults (Q-010
   adopted, revised by D-056): `max_concurrent_agents = 6`, per Codex
   account home 1, for `~/.claude` 3, and a per-role cap of 1 for
   `donbeave/crew-operator` (one Chrome profile). (D-022, D-039, D-053,
   D-056)
3. **Workspace.** Clone or reuse under the daemon's workspace root keyed by
   the sanitized issue identifier; fetch; pull and reuse the branch if it
   exists on the remote, otherwise create it from the base branch. The
   agent never chooses branches. The repository may carry
   `.jackin/workflow.toml` (`[hooks]`, `[verify]`, `[limits]`,
   `[defaults]`, `[states]`) and `.jackin/WORKFLOW.md` (strict prompt frame
   ending in the completion bar), both read from the base branch at every
   dispatch; a file that fails validation holds that repository's issues.
   Hooks run inside the container. (D-014, D-018)
4. **Pre-fetch.** The daemon reads the issue once and stores
   `.jackin/issue/ISSUE.md` and the checklist file in the workspace. The
   Linear token never enters the container; the daemon is the only tracker
   writer. (D-013, D-023)
5. **Launch.** The daemon spawns the named role with the named runtime,
   model, effort, and account home through the same non-TTY entry the CLI
   path shares, under the capsule, as an ordinary interactive session on
   the capsule PTY; it never uses a harness's print or exec mode. The
   rendered prompt is delivered into the session at start per the delivery
   mode; later text (continuation guidance, Linear replies) is injected
   into the same PTY. Containers are labeled with issue id, identifier,
   and attempt. (D-009, D-012, D-024, D-043, D-044)
6. **Working.** The agent works one checklist item at a time with research
   and verification subagents (D-007, D-036), updates the local checklist
   only when an item is finished, and the daemon pushes each tick to the
   issue. (D-013)
7. **Verification.** When the local checklist is complete the daemon runs
   the repository's `[verify] command` inside the same container through
   exec-with-result and accepts only a final line `status: DONE`; only then
   is the PR marked ready and the issue moved to the review state. The
   agent's own completion bar (checklist done, tests green, branch pushed,
   PR open, review comments addressed) is a separate gate it must satisfy
   first. Checklist items carry no individual verification. (D-030; Q-014
   closed; Q-006: the verify command lives on the base branch and
   `crew-reviewer` signs off when an agent authored it)
8. **Retry and failure.** Clean exit with an incomplete checklist starts a
   `continuation` attempt after 1 s, up to 20. A failure retries after
   `min(10 s * 2^(attempt-1), 5 min)`, up to 3 attempts; only agent-class
   failures (exit, stall, timeout, blocked past deadline) consume attempts.
   Config and workspace failures hold the issue with a comment; tracker
   failures skip the tick; observability failures never stop the daemon.
   No capsule activity for 5 min is `stuck`: surfaced first (D-049), then
   killed and retried. A capsule `Blocked` state is surfaced (D-051) and
   escalated rather than retried. Each attempt is a new container session
   in the same workspace; `rework` (closed or merged PR) resets to the base
   branch; the workspace is removed only on terminal state. Exhausted
   attempts enter `blocked` with a blocker brief. (D-021, D-027; Q-008
   closed) Lane fallback (D-057): on provider quota exhaustion or a stuck
   run past the recovery threshold, and after the stuck rule (§9f) has
   run, the daemon re-launches the attempt on the lane's `fallback`
   (`ROADMAP.md` §5: L1→L2→L3→L4→L5→L6→L1; L4→L5→L6→L1→L2→L3→L4),
   switching account home, runtime, and model together; the ledger records
   the lane of every attempt. Quota exhaustion is infrastructure-class:
   it consumes no attempt and skips every lane sharing the exhausted
   account home (L1/L2/L3→L4→L5→L6→L1; L4→L5→L6→L1; …); a chain fully
   throttled waits for the reset instead of blocking (D-071). Implemented
   by M6-05; before that the host session re-lanes by hand and records the
   hop in the task's `PROGRESS.md` result cell — never a preflight defect
   (D-071). A task whose verify still fails after `limits.attempts` in the
   host-driven run is `exhausted` and filed as such; the attempt count for
   the current epoch lives in `tasks/<id>/attempts.log`, and an
   `exhausted:` row re-opens the task only after the human fills its
   `Resolved` cell (D-070, D-093).
9. **Escalation.** A blocker brief (what is missing, why it blocks, the
   exact human action) is posted as a Linear `elicitation`; the human's
   reply arrives as a `prompted` event and is sent into the same PTY; a
   `stop` signal ends the run. The prompt frame lists what may not be
   escalated. (D-029)
10. **Follow-ups.** Issues an agent proposes are created unassigned in a
    backlog state and become work only when a human assigns them. (D-028)
11. **Pull request.** The daemon pushes the branch and opens or updates the
    PR titled with the issue identifier, links it on the issue, and marks
    it ready after verification. (D-014)
12. **Merge.** The issue is moved to the repository's merging state (by
    the human, or by the agent whose roadmap work needs the merge, D-055;
    during this roadmap only proof tasks on scratch issues enter it, since
    D-074 keeps the rolling PRs open and roadmap issues are completed by
    the host session, D-087);
    the daemon dispatches one `merge` attempt per repository at a time
    (same role, runtime, workspace; prompt frame section "land"); the agent
    updates the branch, resolves conflicts, repairs CI, addresses review
    comments, and merges with the forwarded GitHub credential; the daemon
    confirms the merge through GitHub, moves the issue to `Done`, and
    removes the workspace. No integration branch and no merge queue in the
    first version. (D-031; Q-007 narrowed)

Independent issues run in parallel, each in its own container. (D-004)

## 7. Visibility

A human can attach to any managed container at any time and see the exact
prompt and the live session. Programmatic launch must preserve this; runs
that only capture stdout are not acceptable. The TUI lists running
containers and offers attach. (D-016, D-024)

Linear shows the live status of every run: who (role, runtime, model,
account), where (host, container, attach target), since when, and the
state — starting, working, waiting for input, blocked, stuck, failed,
verifying, done — through daemon-driven agent-session activities, the
session plan, external URLs, a heartbeat every 10 minutes carrying "last
progress at", and the `run:*` label group. (D-049)

Three distinct non-working states are visible without a terminal:

- **waiting for input** — the daemon posted an elicitation (blocker brief)
  and awaits the human's reply (D-029);
- **blocked** — the agent inside the container stopped on something the
  daemon did not cause: a permission prompt, a tool refusal, a
  confirmation, any wait for input. The daemon detects it through the
  capsule's agent state for every runtime, sets `run:blocked` with the
  reason as far as known and the attach target, and clears it automatically
  when the agent resumes (D-051);
- **stuck** — no capsule activity within the stall window (D-021, D-049).

Every issue being worked shows the identity of its container — container
id, jackin instance name, host — kept current by the daemon from launch to
removal and across retries, in the session `externalUrls` (human) and the
ledger (machine). (D-052)

The daemon reads the issue content once at pickup; the M2-03 candidate,
session, and activity polls and the M6-02 pre-write `description` read are
not issue-content reads; it writes on checklist completion, on every state
transition (exactly one write per transition), and on heartbeat, and its
log tags `poll`, `issue.read`, and `write` so proofs can count them.
(D-013, D-049, D-081)

The daemon answers a synchronous state snapshot over its socket (`running`,
`retrying`, `blocked`, `stuck`, totals, rate limits, attach target per row)
and structured logs carrying issue, attempt, host, container, and session.
The termrock TUI and later surfaces read this; the daemon is correct with
none of them present. (D-025)

## 8. State

Linear is the only authority for what work exists and its status. The
daemon holds no authoritative task state and rebuilds its view from Linear
and local workspaces after restart. (D-010) It keeps a local,
non-authoritative ledger per host (claims, attempts with kind and terminal
reason, blocked entries with their blocker brief, retry due times,
container-to-issue bindings); on restart it adopts running containers
labeled with an issue identifier and reloads attempt counts and blocked
entries from the ledger, never treating the ledger as proof that an issue
is active. Internal claim states: `unclaimed`, `claimed`, `running`,
`retry_queued`, `blocked`, `released`. (D-019, D-020)

## 9. Deployment

Prototype: everything on the developer's computer with local Docker.
Then one server host with Docker. Then several hosts, one daemon each, one
manager placing runs by `(issue, host, attempt)` with least-loaded
placement, previous-host preference on retry, and no duplicate execution.
No decision may bake in single-host assumptions that block the move.
(D-017, D-026)

## 9a. Credentials

Every credential is created into 1Password and referenced as `op://`;
none lives in files, images, documents, or chat. The daemon resolves
credentials from 1Password at runtime. (D-035)

Writing to 1Password from a container (Q-018 adopted, D-053): a 1Password
service account scoped to vault `jackin` (read + write), its token stored
in vault `tailrocks` as `op://tailrocks/op-service-account-jackin-operator`,
delivered per invocation by an on-demand `jackin-exec` binding that
resolves the `op://` value on the host and injects it into the one
in-container `op` command with redacted output. The daemon's separate
read-only service account (`op-service-account-jackin-daemon`) arrives at
M11. Tracker credentials never enter a container (D-023).

Inventory of what exists and what must be created is in
`concept/credentials.md` (metadata only, never values). Summary as of
2026-08-27: Linear workspace login exists (Google SSO,
alexey@chainargos.com); the existing workspace is used (Q-019 adopted); no
Linear OAuth agent app yet; two GitHub Apps exist with the wrong scope for
PR management, so one App per organization (`jackin-project`, `tailrocks`)
is created for the daemon (M8); provider runtimes use jackin's host login
forwarding (`auth_forward = "sync"`), fine for the laptop prototype, to be
replaced by `op://` provider keys at the server step; vault `jackin` is
created in M1, one item per rotation unit (`linear-agent-app`,
`linear-workspace-<org>`, `github-app-jackin-daemon`, `<runtime>-daemon`,
...). The `agent-browser` profile directory
(`~/.jackin/agent-browser-profile`, Q-017 adopted) is a secret on the host,
mounted read-write only into `donbeave/crew-operator`, never committed or
backed up to 1Password.

## 9b. Delegation

All work — planning here, implementation, and the agents the daemon runs —
is carried out by delegated agents: subagents in a session, or agents
spawned through jackin when the work needs its own container, role, or
runtime. The top-level agent coordinates and decides. Building this
product follows the same rule from the first iteration, so every
iteration is also a proof of the workflow. (D-033, D-036)

## 9c. Parallelism, accounts, models

The build runs as many tasks in parallel as dependencies allow, spread over
the provider accounts on the machine (`~/.claude`; `~/.codex`,
`~/.codex-chainargos`, `~/.codex-chainargos2`) using jackin's multi-account
support. Models: Fable 5, Opus 5, Sonnet 5, GPT-5.6 Sol, GPT-5.6 Terra,
GPT-5.6 Luna, all at medium reasoning. Tasks are assigned across agents,
models, and account lanes. Until per-launch selection exists (`LoadOptions`
gains `account`, `model`, `effort` in M3-01; Q-024 adopted) the account
is carried by `sync_source_dir` of a per-task saved workspace `task-<id>`
that the host session creates from the lane's template before every
launch (a saved workspace is selected only by name and has one fixed
`workdir`, D-085), and model and effort are set by workspace env for
Claude lanes and by a role hook writing `$CODEX_HOME/config.toml` for
Codex lanes; manifests carry no `[claude].model`. (D-039, D-043, D-078)

## 9d. Involved projects and branches

Any repository under github.com/jackin-project or github.com/tailrocks is
changed when this effort needs it; defects are bugs to fix there, gaps are
extensions (D-046). All such changes land on `feat/managed-execution` in
each repository; this repository commits directly to `main` (D-047).
Role repositories are the exception: jackin loads a role from its default
branch only, so `donbeave/jackin-crew-*` and `jackin-role-template` commit
directly to `main` and `jackin-the-architect` merges its PR in the same
task (D-074).
Manifest schema bumps are one per PR; `default_agent` and the launch
prompt field land together as `v1alpha7` when M3-02 and M4-01 ship
together, otherwise as two consecutive versions (Q-021 adopted). termrock's
trunk-only `CONTRIBUTING.md` is amended on `feat/managed-execution` with an
agent-authored-changes clause: branch, PR to `main`, `crew-reviewer`
review requested, agent merges (D-047, D-053, D-055).

Merges and releases (D-055, D-074): agents merge pull requests to `main`
themselves, through the forwarded `gh`, when a task's scope names the
merge (the task text is the per-PR authorization, D-079); one rolling PR
per repository stays open and is reviewed per milestone at successive head
SHAs; work that blocks nothing stays unmerged on `feat/managed-execution`;
no jackin release and no Homebrew tap publish before M11 — branch builds
only. There is no human review gate: `crew-reviewer` tasks run in parallel
and never block the next task; findings become follow-up checklist items
on the reviewed issue.

## 9d-ci. Continuous integration

CI for every repository this roadmap changes runs on GitHub-hosted
runners; velnor runners are not used for this work (D-064). Local
verification remains the default; CI is confirmation (D-034).

## 9d-pub. Repositories are public

Every repository created for this effort is public from creation (D-065);
nothing sensitive is ever committed (D-035, D-059).

## 9e. Unattended execution and operator preflight

The whole implementation runs without asking the operator for anything
mid-way. Every milestone and every task begins with a preflight that
determines exactly what must come from the operator — credentials and
logins (`op://` references), consents, trust grants, accounts, physical
steps on the host — and obtains all of it before the task starts. Each
milestone's items are collected into one operator preflight list in
`ROADMAP.md`, executed by the human in one sitting before that milestone's
agents start; task folders carry a `preflight` section
(`concept/task-format.md`). An agent that discovers a missing operator
input mid-task records it as a preflight defect, completes everything not
depending on it, and marks the task blocked with the exact missing item;
a task whose verify still fails after the attempt cap is `exhausted` and
filed the same way, and the run ends COMPLETE or BLOCKED (D-070). The host
session is Fable and spends its context on coordination only: every
subagent it spawns runs on Opus (`model: "opus"`) and returns at most 15
lines, and the session never reads `ROADMAP.md`, `SPEC.md`, `DECISIONS.md`,
`concept/`, or `analysis/` itself (D-092).
Open design questions never stop work: recommended answers are adopted by
default and may be overridden later. (D-050, D-053)

Further rules of the unattended run (D-060..D-063):

- Linear structure: team `JACKIN`, one project, project milestones
  M1..M12. M1 tasks never get issues — they run by hand from their task
  folders; issues start at M2 and are created by M1-12, which first has
  subagents verify the current state of the involved repositories so each
  issue reflects what is already done. (D-060)
- Host-only `verify.sh` (every `host` row) is run by the host Claude Code
  session that drives the roadmap; its output is filed in the task folder.
  (D-061)
- Task folders exist for M1..M5 now (M1-01) and for M6..M12 when reached;
  milestones may overlap; operator preflights are merged per sitting.
  (D-062)
- Evidence: text (GraphQL JSON, `.cast`, logs, verify output) in the task
  folder; screenshots and recordings attached to the Linear issue. (D-059)
- Model identifiers and effort knobs per lane are discovered and recorded
  by M1-13; `model:*` labels follow that record. (D-058)
- The stuck rule of §9f applies to every agent and to the host session.
  (D-063)

## 9f. Stuck rule

When a task stalls or takes too long, the agent always spawns subagents to
analyze why and to find a solution before anything is escalated. This binds
container agents and the host session alike; in managed runs the daemon's
stuck signal (D-049) triggers it, and lane fallback (D-057) or retry
(D-027) follows only after that analysis. Prompt frames and every
`TASK.md` carry the instruction. (D-063)

## 10. How the product is built

The product is built with its own workflow: Linear issues, jackin roles,
pull requests (D-033). Work targets the latest jackin, installed locally
from the working branch; local build and verification are the default and
CI is confirmation, not a gate (D-034). Every milestone is verified visually
in the real Linear and GitHub UIs with `agent-browser` on one persistent
logged-in profile; the proof is a checklist item executed by
`donbeave/crew-operator` in the milestone's proof-run task, never by the
implementing role (D-032 as amended by D-053). The end-to-end workflow is
written out in `concept/workflow.md`. Until a host bridge exists, host-side
evidence in proof runs (`docker ps`, `hardline` captures, daemon logs) is
collected by the human into the proof-run folder; a
`jackin daemon evidence <instance>` command is planned with M10-01 (Q-025
adopted).

## 10a. Linear project

All work for this effort is one Linear project in team `JACKIN`; each
`tasks/` folder from M2 onward is one issue (M1 runs by hand, D-060);
dependencies are mirrored as blocking relations, review tasks excepted
(D-055); milestones map to project milestones. (D-040) The preview jackin is uninstalled; only the
branch build (`feat/managed-execution`) runs on the machine. (D-042)

## 10b. Milestones

Ordered proofs (D-037, extended by D-049 and D-053; details and tasks in
`ROADMAP.md`, final under D-054; task folders in `tasks/` for M1..M5 now
and for later milestones when reached, D-038, D-062). Milestones may
overlap in execution; review tasks never gate the next milestone (D-055).

1. **M1 Linear setup verified** — agent app, credentials in 1Password,
   browser profile, branch-built jackin, the three `crew` roles; a test
   issue assigned and observed.
2. **M2 Daemon listens and reacts to Linear** — polling, acknowledgement
   within 10 s, contract validation, failures reported on the issue.
3. **M3 Issue spawns a local agent** — workspace prepared, role launched
   with runtime, model, effort, and account in local Docker, attachable.
4. **M4 Capsule passes prompts to a specific agent** — prompt delivered at
   start, text injected later, exec-with-result; block detection per
   runtime (D-051).
5. **M5 Live status in Linear** — run state machine, heartbeat, stuck and
   blocked visible, `run:*` labels, container identity in `externalUrls`
   (D-049, D-051, D-052).
6. **M6 Checklist mirrored and written back** — plus daemon lane fallback
   on quota exhaustion or stuck (M6-05, D-057).
7. **M7 Verification by verify command** — retry, ledger, escalation.
8. **M8 Pull request opened and updated** — GitHub App per organization.
9. **M9 Merge.**
10. **M10 termrock TUI: fleet and attach** — daemon snapshot, fleet route,
    one-key attach.
11. **M11 Server host** — `op://` runtime credentials, published role
    images, daemon installed on a Docker server.
12. **M12 Multi-host** — remote daemon transport, placement, no duplicate
    execution.

## 10c. Naming and escalation

There is no separate product name: the feature is the jackin daemon's
"managed execution" (D-066). Roadmap issues are created by M1-12 under
label `auto-dispatch` without a delegate; the host session delegates each
issue to jackin when the daemon can serve it and closes the issue of every
finished task for the whole run (D-067, D-073, D-087); agent-created follow-ups
dispatch only when the parent carries that label (D-067). Escalation is
Linear-only; the host session is first responder during the roadmap
(D-068).

## 11. Open questions

None (see `OPEN-QUESTIONS.md`).
