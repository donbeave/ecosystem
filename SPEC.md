# jackin managed execution — final product specification

Status: **normative final-state contract**

This file is the sole authority for the product this repository delivers and
for the evidence required to accept that product. `ROADMAP.md` may define work
breakdown, dependencies, and delivery order. `GOAL.md` and `goal/EXECUTION.md`
may define how the delivery run operates. `concept/`, `VISION.md`, and
`analysis/` may explain context. None may add, weaken, or override a product
requirement or acceptance condition in this file.

The keywords **MUST**, **MUST NOT**, **SHALL**, **SHALL NOT**, **SHOULD**, and
**MAY** are normative only inside a definition introduced as
`- **<PREFIX>-<three digits>**`. A table, ordered list, code block, or schema is
normative only when that definition explicitly owns it as “the following”. All
other prose is explanatory. A requirement identifier is stable. Changing
behavior requires changing the applicable requirement and its acceptance row
together.

## 1. Product, scope, and authority

### 1.1 Product definition

`jackin managed execution` is the manager built into the jackin daemon. It
turns assignment of a well-formed Linear issue into an unattended, observable,
isolated agent run that produces and verifies a GitHub pull request. It scales
from one local Docker host to multiple remote daemon hosts without duplicate
execution.

The delivered system comprises:

- manager and Linear/GitHub adapters in the jackin daemon;
- programmatic, attachable agent sessions through the jackin capsule;
- the additive daemon and remote-control surfaces in the jackin CLI;
- a termrock fleet view and terminal attach surface;
- purpose-built builder, operator, and reviewer roles;
- server and multi-host operation using 1Password-backed credentials; and
- this repository's deterministic readiness, state, evidence, supervision,
  and final-acceptance control plane.

This repository contains product specifications and proof-plane tooling. Product
code lives in the involved jackin, termrock, and role repositories.

### 1.2 Product outcomes

- **PRD-001** The system MUST let a person hand over work by assigning a
  conforming Linear issue to the jackin app.
- **PRD-002** The system MUST select, start, observe, guide, verify, retry, and
  finish isolated agents without requiring a foreground jackin CLI session.
- **PRD-003** Independent work MUST run concurrently within declared
  dependencies, capacity, credential, and merge-safety limits.
- **PRD-004** Linear MUST show current progress, run state, ownership, host,
  container, and attach information. A terminal MUST remain available for the
  exact live session.
- **PRD-005** Completion MUST be established by executable verification and
  durable evidence, never by an agent's unverified assertion.
- **PRD-006** Local, server, restart, and multi-host operation MUST preserve the
  same issue, session, security, and verification contracts.

### 1.3 Non-goals

- **PRD-010** The product MUST NOT implement an agent harness. It launches
  supported vendor harnesses as shipped.
- **PRD-011** Existing interactive jackin commands and role loading behavior
  MUST remain backward compatible. Managed execution is additive.
- **PRD-012** Linear is the only task tracker. GitHub hosts repositories,
  branches, checks, reviews, and pull requests; GitHub Issues is not a task
  source.
- **PRD-013** A webhook, TUI, browser, or evidence viewer MUST NOT be required
  for scheduler correctness.
- **PRD-014** No product behavior may depend on one laptop, one filesystem
  layout, one provider, one model, or one host.

## 2. Terms and identities

- **PRD-020** The following term table defines the vocabulary used by every
  requirement and acceptance assertion.

| Term | Normative meaning |
| --- | --- |
| task / issue | One Linear issue and one independently verifiable unit of work. |
| manager | Scheduling, policy, verification, and tracker logic in the jackin daemon. |
| daemon | One long-running jackin process on a host. It monitors all jackin containers on that host and may execute managed work. |
| manager host | The sole host that polls Linear and places work across daemon hosts. |
| role | Versioned jackin container environment, tools, skills, grants, and allowed runtimes. |
| runtime | Vendor agent harness selected from the role's `agents` list. |
| lane | Configuration record resolving runtime, account home, model, effort, and fallback. |
| run | Execution of one issue from claim through release. |
| attempt / attempt ordinal | One container session for a run, numbered monotonically from 1 across every attempt kind. |
| retry budget | Counter incremented only by agent-class failures; independent of attempt ordinal and continuation count. |
| session | Interactive runtime process on the capsule PTY and its Linear agent session. |
| instance / container | jackin identity and Docker container for one attempt. |
| workspace | Host checkout reused across attempts for one issue. |
| dispatchable | Adapter-derived eligibility predicate in SCHED-000. |
| product `run:waiting` | Daemon requested human input through a Linear elicitation. This is not a delivery-task status. |
| product `run:blocked` | Runtime stopped for input the daemon did not request. This is not a delivery-task status. |
| product `run:stuck` | No capsule activity within the configured stall window. |
| delivery-task status | Proof-plane lifecycle value in CTRL-012; it never denotes a product run state, attempt kind, claim state, or Linear elicitation state. |
| terminal issue | Linear workflow state whose type is `completed` or `canceled`. |
| proof plane | This repository's locked bundles, event store, evidence, supervisor, and root oracle. |

- **PRD-021** Identifiers MUST be immutable within a run. Every log, event,
  activity, claim record, and evidence record MUST carry enough of `run_id`,
  issue id and identifier, attempt ordinal, host, instance, and session id to
  correlate it without parsing prose.

## 3. Actors, authority, and trust boundaries

### 3.1 Authority matrix

- **AUTH-010** The following authority matrix is exhaustive. A component may
  cache or project another authority but MUST NOT silently promote that cache or
  projection into an authority.

| Actor or store | Authority | MUST NOT be treated as authority for |
| --- | --- | --- |
| Human | Authors or approves work; assigns ordinary issues; supplies human-only credentials/consent; answers elicitations; authorizes a merge by moving the issue to the merging state or by explicit task text. | Agent progress, verification, or retry state. |
| Linear | Which product work exists; issue fields, relations, delegate, workflow state, description, and agent-session records. | Git commit contents, PR merge fact, local attempt records. |
| GitHub | Repository refs, commit ancestry, checks, reviews, and PR state. | Work eligibility or Linear completion. |
| Repository base branch | `.jackin/workflow.toml`, optional `.jackin/WORKFLOW.md`, and verification policy used for an attempt. | Live issue content. |
| Manager | Claims, schedules, writes Linear run projection, invokes verification, and confirms GitHub effects. | Inventing task fields or bypassing required checks. |
| Manager-host ledger | Current product-run claim/placement record, attempt ordinals, bindings, retry times, and recovery hints while one manager is active. | Whether work still exists or remains active in Linear; a distributed compare-and-swap or global lease. |
| Worker-host ledger | Idempotent start record and local container binding for commands placed by the manager. | Product-run claim ownership or permission to re-place work. |
| Capsule | Live PTY, runtime state, activity, exit, and command execution for an instance. | Task eligibility or issue status. |
| Agent | Repository changes and local checklist progress within its role boundary. | Final acceptance, tracker writes, or credential policy. |
| Proof-plane event store | Authoritative state of this repository's delivery run only. | Product issue state in Linear. |
| `SPEC.md` | Product requirements and final acceptance. | Delivery order and task dependency graph. |

- **AUTH-001** Only the manager may write tracker activities, run labels,
  checklist progress, PR links, and managed workflow transitions during a run.
  A human may author or edit the issue and reply to an elicitation.
- **AUTH-002** The Linear token MUST remain on the manager host. It MUST NOT be
  present in a role environment, workspace, image, command argument, or log.
- **AUTH-003** Every issue description, repository file, PR diff, browser page,
  hook, and model response is untrusted input.
- **AUTH-004** Full-auto runtime flags are permitted only inside the explicit
  host or container boundary. Approval prompts are not a security boundary;
  filesystem, network, mount, role, and credential grants are.
- **AUTH-005** No observer surface may mutate scheduler state merely by being
  opened, refreshed, attached, or queried.

## 4. Architecture and component contracts

### 4.1 Required components

- **ARCH-001** The delivered product MUST contain every component and behavior
  in the following component table.

| Component | Required final behavior |
| --- | --- |
| Linear adapter | Polls and normalizes eligible issues and agent sessions; creates missing sessions; performs bounded, idempotent writes. |
| Manager | Computes eligibility, claims work, schedules lanes and hosts, drives state, verifies, retries, escalates, and manages PRs. |
| Per-host daemon | Uses the shared jackin launch pipeline; monitors CLI- and daemon-started instances; reconciles after restart; exposes local control and snapshot APIs. |
| Remote transport | Lets the manager query and command another daemon; an unreachable peer is an explicit error. |
| Capsule | Preserves an interactive PTY; accepts initial and later input; publishes state and activity; executes commands with captured result. |
| GitHub adapter | Mints installation tokens, pushes branches, opens or updates PRs, links them to Linear, reads checks, and confirms merge. |
| Manager-host ledger | Persists the active manager's claim/placement record, attempt ordinals, retry deadlines, blocker briefs, lanes, and worker bindings. |
| Worker-host ledger | Persists idempotent placed-command and container bindings local to one daemon host. |
| termrock console | Renders the daemon snapshot and attaches to the selected capsule session using termrock components. |
| Roles | Separate code-building, privileged browser/operator, and read-only review capabilities. |
| Proof plane | Locks plan inputs, serializes delivery state, supervises the coordinator, records evidence, and derives final acceptance. |

### 4.2 jackin compatibility and capsule API

- **ARCH-010** Existing jackin CLI commands MUST keep their behavior. The
  daemon and CLI MUST use the same internal container-creation path.
- **ARCH-011** Programmatic launch MUST accept a fully resolved role, runtime,
  account source, model, effort, grants, mounts, trust resolution, environment,
  on-demand bindings, prompt, and force policy without a TTY or dialog.
- **ARCH-012** A managed runtime MUST run interactively on the capsule PTY. A
  harness print/exec mode that removes attachability is forbidden.
- **ARCH-013** Initial prompt delivery MUST preserve the live session. Later
  continuation guidance and Linear replies MUST enter that same PTY.
- **ARCH-014** Capsule control MUST provide `session.send`, an event stream
  containing agent state, exit, and last activity, and exec-with-result
  containing exit code, stdout, stderr, duration, and timeout outcome.
- **ARCH-015** `jackin daemon exec <instance> -- <command>` MUST expose
  exec-with-result. `jackin hardline <instance>` MUST attach to the exact PTY.
- **ARCH-016** Managed containers MUST be labeled with issue id, issue
  identifier, run id, attempt, host, and instance identity.
- **ARCH-017** Role manifest `default_agent` MUST validate against `agents`.
  Runtime precedence is issue runtime, workspace `default_agent`, manifest
  `default_agent`, then the sole allowed runtime.
- **ARCH-018** The shared launch and capsule-control contracts MUST cover all
  jackin runtimes: Claude Code, Codex, Amp, Kimi, OpenCode, and Grok. Initial
  prompt delivery, attachability, activity/exit reporting, and blocked-state
  detection MUST have a conformance fixture for each runtime. A runtime that
  cannot accept the initial positional prompt MUST receive it through
  `session.send` immediately after the PTY becomes ready.
- **ARCH-019** The launch pipeline MUST carry the initial prompt through the
  launch-only `JACKIN_INITIAL_PROMPT` environment value. The container
  entrypoint consumes it into the runtime's first interactive turn and removes
  it before later child processes can inherit it. No prompt field is added to
  the role manifest, and the raw prompt MUST NOT persist in workspace config,
  container labels, or fleet-wide logs.

### 4.3 Daemon interfaces

- **ARCH-023** The daemon MUST expose structured JSON for local and remote
  clients using the following minimum interface schema.

| Interface | Minimum response |
| --- | --- |
| status / snapshot | `generated_at`, host health and capacity, totals by state, rate-limit/reset data, and one row per run. |
| run row | issue id/identifier/URL, repository, branch, role, runtime, lane, account, model, effort, run state, claim state, attempt/kind, host, instance, container id, session id, last event/time, last progress, usage, retry time, and attach target. |
| detail | Prior states, attempts, blocker brief, verification result, PR, and external object ids for one issue/run. |
| events | Ordered structured events after a supplied cursor. |
| refresh | Requests an immediate reconciliation tick without changing eligibility. |
| evidence | Docker labels, attach/session capture, and redacted daemon log excerpt for an instance. |
| exec | Captured command result defined by ARCH-014. |

- **ARCH-020** Snapshot reads MUST be synchronous and side-effect free except
  for the explicit refresh request.
- **ARCH-021** The daemon MUST remain correct when the console, browser, and
  all snapshot clients are absent.
- **ARCH-022** Remote transport MUST authenticate peers, preserve the same
  schemas, surface timeouts and unreachable peers, and MUST NOT silently fall
  back to local execution.

## 5. Linear issue and repository contracts

### 5.1 Issue schema

- **ISSUE-001** The Linear integration MUST be installed as OAuth agent app
  `jackin-daemon`
  with scopes `read`, `write`, `issues:create`, `comments:create`,
  `app:assignable`, and `app:mentionable`, a stable app user identity, and
  agent-session events enabled. Polling remains the correctness path: webhook
  absence, failure, or an unreachable callback MUST NOT prevent
  acknowledgement or dispatch.
- **ISSUE-002** The manager MUST scope every candidate, session, activity, and
  mutation to the configured Linear organization, team/project, and app user.
  It MUST NOT infer scope from a model response or repository content.
- **ISSUE-003** The app contract is exactly: redirect URI
  `http://localhost:53682/callback`; agent-session-events webhook
  `https://jackin-webhook.invalid/linear`; OAuth authorization with
  `actor=app`, a checked random `state`, and the ISSUE-001 scopes. The
  authorize step starts a one-shot listener bound to `127.0.0.1:53682`,
  verifies the returned `state`, extracts the one-time code, and deletes the
  callback log before any commit. One authorization-code exchange returns a
  refresh token stored only as
  `installation seed` and is never used; then 30-day client-credentials tokens
  re-minted when fewer than 48 hours remain. Webhook delivery is discarded and
  polling remains authoritative.
- **ISSUE-004** Team/project setup MUST be one public Linear team `JACKIN`, one
  project, milestones `M1` through `M12`, label groups `role`, `agent`, `model`,
  `lane`, `effort`, `delivery`, `repo`, and `run`, plus `auto-dispatch`.
  `Review` and `Merging` MUST both be `started` states positioned after the
  ordinary first `started` state. The app user MUST be a team member. The issue
  template MUST contain the checklist skeleton and MUST NOT pre-set a delegate.

- **ISSUE-005** The following issue schema is normative. Label groups are
  case-insensitive for parsing and canonical for writing. There MUST be exactly
  one resolved value for every required field and at most one explicit value
  for every optional single-value group. Missing resolution, duplicate,
  conflicting, or unknown values are validation failures.

| Field | Input | Cardinality and resolution |
| --- | --- | --- |
| repository | `repo:<owner/name>` | Exactly one; GitHub repository. |
| branch | Linear `branchName`, overridden by `branch: <name>` in description | Exactly one resolved value. Existing remote branch is reused; otherwise created. |
| base branch | `base: <name>` | Optional; defaults to `main`. |
| role | `role:<selector>` | Exactly one required label naming a trusted, resolvable role. Workspace or manifest defaults do not replace this managed-issue label. |
| runtime | `agent:<runtime>` | Exactly one required label. Its value MUST be in the resolved role's `agents`; missing runtime is `missing_agent`, and an unknown or disallowed value is `invalid_agent`. Product code MUST NOT hard-code only Claude or Codex. Workspace/manifest `default_agent` applies only to launches that do not use the managed-issue contract. |
| lane | `lane:<name>` | Exactly one configured lane whose runtime agrees with the resolved runtime. |
| model | `model:<exact-id>` | Optional; lane default when absent; resolved value is reported. |
| effort | `effort:<level>` | Optional; lane default, otherwise `medium`; resolved value is reported. |
| delivery | `delivery:goal` or `delivery:prompt` | Optional; defaults to `goal`. |
| prompt | Issue description | Required non-empty text, rendered verbatim inside the repository frame. |
| checklist | First Markdown task list in description | Required; at least one item. Stable item identity is source order plus normalized text. |
| references | Links, paths, documents, or attachments | Optional but MUST be prefetched when declared. |
| verification | Base branch `.jackin/workflow.toml` `[verify].command` | Required for a verified run. |
| dependencies | Linear `blocks` relations | Every blocking issue MUST be terminal before dispatch. |
| auto-dispatch | `auto-dispatch` label | Allows agent-created follow-ups to be delegated automatically. |

- **ISSUE-006** This repository's delivery graph MUST be mirrored into the
  public `JACKIN` Linear team and its one managed-execution project as follows.
  Roadmap task `M1-12` is the sole implementation and verification owner of
  this mirror.
  Foundation tasks in milestone M1 MUST remain repository-only task bundles and
  MUST NOT have Linear issues. `M3-01`, `M3-03`, `M4-02`, and `M4-03` MAY run
  from their locked bundles before the issue mirror exists. Every other
  non-`planned` M2-or-later task bundle MUST
  have exactly one issue in its matching `M2` through `M12` milestone, titled
  `<task-id> <task-title>`. Its description MUST begin
  `task_source: https://github.com/tailrocks/ecosystem/tree/<40-hex-commit>/tasks/<task-id>`
  and then contain the bundle's `TASK.md`; its `blocks` relations MUST equal
  `depends_on` except non-blocking review relationships; its canonical
  role/agent/model/lane/effort/delivery/repository labels MUST equal the bundle;
  and it MUST have the raw attachments required by ISSUE-014. Bundle state MUST
  project as `ready|blocked` to the ordinary `unstarted` state,
  `in-progress|waiting` to the ordinary first `started` state, and `done` to the
  `completed` state. No mirrored issue may pre-set a delegate. A content-addressed
  issue map MUST bind task id, Linear issue id/identifier/URL, milestone, and
  source commit so reruns update the same issue instead of creating another.
  When the mirror is created, it MUST backfill those four early-start tasks at
  their current durable status without delegating or rerunning them.

- **ISSUE-010** Assignment to the jackin app user is the trigger. Creation,
  mention, or label alone MUST NOT dispatch work.
- **ISSUE-011** The parser MUST validate repository syntax, branch/base names,
  role/runtime resolution and trust, lane existence and compatibility, model
  and effort support, delivery, prompt, checklist, dependencies, and workflow.
- **ISSUE-012** Validation failure MUST create exactly one `error` activity
  naming the stable field and code, MUST NOT create a container, and MUST be
  reconsidered on later ticks. Missing role and runtime labels MUST report
  `missing_role` and `missing_agent`; an unparsable, unavailable, or
  role-incompatible runtime MUST report `invalid_agent`.
- **ISSUE-013** Defaulted model and effort MUST appear in the run identity and
  Linear activity; defaults MUST NOT remain implicit after claim.
- **ISSUE-014** A task-bundle-backed issue MUST also provide immutable raw
  attachments titled `task.toml`, `verify.sh`, `expected-evidence.toml`, and
  `refs/<name>` for every declared reference, pinned by `task_source` to the
  locked source commit. Missing required attachments MUST fail validation
  before launch.

### 5.2 Daemon-maintained Linear projection

- **ISSUE-015** Only the manager writes the following Linear projection, with
  the stated cardinality and replay behavior.

| Projection | Contract |
| --- | --- |
| run label | At most one of `run:starting`, `run:working`, `run:waiting`, `run:blocked`, `run:stuck`, `run:failed`, `run:verifying`, `run:done`. Added and removed in one issue update; absent after terminal cleanup. |
| plan | Full replacement mirroring the current local checklist. |
| activity | One logical activity per state transition, checklist tick, heartbeat, validation error, fallback, PR link, or escalation. Replay emits none. |
| external URL | One current entry containing role, runtime, model, effort, lane/account, host, instance, container, attempt, since, and attach command. Re-dispatch replaces it. |
| PR link | Current GitHub PR URL, written idempotently. |

### 5.3 Repository workflow

- **ISSUE-019** The daemon MUST read the following repository workflow schema
  from the issue's base branch at each dispatch. An in-flight attempt keeps the
  validated version it started with.

```toml
[hooks]
after_create = "..."       # optional, runs in container
before_run = "..."         # optional
after_run = "..."          # optional
before_remove = "..."      # optional
timeout_seconds = 900       # optional

[verify]
command = "sh .jackin/task/verify.sh container"

[limits]
max_concurrent = 0          # 0 = use daemon default
max_continuations = 20
max_attempts = 3
minutes = 0                 # 0 = no additional run deadline

[limits.max_concurrent_by_state]
merging = 1

[defaults]
role = "..."               # optional for launches outside the managed-issue contract
runtime = "..."            # optional for launches outside the managed-issue contract
base_branch = "main"

[states]
review = "Review"
merging = "Merging"
```

- **ISSUE-020** Invalid workflow syntax, an unknown key, invalid state, invalid
  command, or invalid limit MUST hold every issue for that repository with one
  explanatory activity and MUST NOT affect other repositories.
- **ISSUE-021** Optional `.jackin/WORKFLOW.md` MUST be a deterministic prompt
  frame supporting `issue`, `attempt`, `attempt_kind`, `last_error`, and
  `checklist_path`, and MUST end with the repository completion bar.
- **ISSUE-022** The daemon MUST stage `TASK.md`, checklist, workflow-selected
  verifier as `verify.sh`, `task.toml`, `expected-evidence.toml`, and references
  under `<workspace>/.jackin/task/`; the container sees them under
  `/workspace/.jackin/task/` and MUST NOT require host paths.
- **ISSUE-023** Hooks and verification run inside the role boundary. Tracker
  and 1Password tokens MUST NOT be introduced to satisfy a hook.

## 6. Eligibility, scheduling, and concurrency

### 6.1 Dispatchable predicate

- **SCHED-000** An issue is dispatchable if and only if all conditions in the
  following list hold:

1. delegate equals the jackin app user;
2. workflow state type is `unstarted` or `started`, but the state is neither
   the configured review state nor merging state;
3. every inverse `blocks` relation has workflow type `completed` or `canceled`;
4. issue and repository workflow validation pass; and
5. the manager-host ledger has no active claim for the issue.

  A terminal state (`completed` or `canceled`) stops the run and removes the
  workspace. Any other non-active state, or delegate removal, stops the run and
  retains the workspace. Reopening a blocker does not stop a run already active.

- **SCHED-001** Dispatchability MUST be computed by the Linear adapter as one
  value with reason codes. The scheduler MUST NOT duplicate the predicate.
- **SCHED-002** A held issue MUST receive at most one activity for the same
  unchanged hold reason. It is re-evaluated each reconciliation tick.

### 6.2 Capacity and order

- **SCHED-005** The scheduler MUST enforce independently configurable limits
  per manager host, daemon host, repository, repository workflow state,
  provider account home, and role. The delivered profile is:

- `max_concurrent_agents = 6` per host;
- `max = 2` for the shared `~/.claude` account home;
- `max = 1` for each Codex account home; and
- `max = 1` for `donbeave/crew-operator`.

  These are configuration values, not compiled constants. Candidate order is
  Linear priority (1 first, no priority last), then oldest `createdAt`, then
  identifier. A saturated scheduler waits; it does not change execution mode.
- **SCHED-006** The following six lane profiles are exact. The accepted
  `tasks/M1-13/lanes.json` MUST record the same `model_id`, effort, account home,
  and corresponding literal `model:<model_id>` Linear label.

| Lane | Runtime | Model | Account home | Effort | Stuck fallback |
| --- | --- | --- | --- | --- | --- |
| L1 | Claude Code | `claude-fable-5` | `~/.claude` | medium | L2 |
| L2 | Claude Code | `claude-opus-5` | `~/.claude` | medium | L3 |
| L3 | Claude Code | `claude-sonnet-5` | `~/.claude` | medium | L4 |
| L4 | Codex | `gpt-5.6-sol` | `~/.codex` | medium | L5 |
| L5 | Codex | `gpt-5.6-terra` | `~/.codex-chainargos` | medium | L6 |
| L6 | Codex | `gpt-5.6-luna` | `~/.codex-chainargos2` | medium | L1 |

- **SCHED-007** Stuck fallback follows exactly
  `L1→L2→L3→L4→L5→L6→L1`. Quota fallback skips every lane sharing the
  exhausted account home: from L1/L2/L3 it is `L4→L5→L6→L1`; from L4 it is
  `L5→L6→L1`; from L5 it is `L6→L1→L4`; from L6 it is `L1→L4→L5`.
  A model-only limit MAY select another model on the same account home only
  when provider headroom is proven. A busy candidate is skipped and the task
  returns ready at its wave priority until a slot frees; a fully throttled chain
  enters `waiting` until the earliest reset. Busy and quota fallback consume no
  retry budget.

- **SCHED-010** Lane configuration MUST resolve `runtime`, exact `model`,
  `effort`, `account_home`, and `fallback`. Launch MUST use the resolved record
  atomically and record it on the attempt.
- **SCHED-011** Account capacity MUST be counted by account home, not model or
  lane label. Lanes sharing one home share one quota and one configured cap.
- **SCHED-012** Merge attempts MUST be serialized to one per repository.
- **SCHED-013** No candidate may starve behind later work of equal priority;
  deterministic order MUST be preserved whenever a slot becomes free.
- **SCHED-014** A lane is a template merged into the per-task saved workspace
  `task-<id>`; the saved workspace, not a launcher environment prefix, selects
  its account home. Claude lanes set exact model and effort through workspace
  `ANTHROPIC_MODEL` and `CLAUDE_CODE_EFFORT_LEVEL=medium`. Codex lanes pass
  `JACKIN_LANE_CODEX_MODEL`; an idempotent sourced role hook writes only
  `model` and `model_reasoning_effort = "medium"` in `$CODEX_HOME/config.toml`
  and never modifies auth. Role grants remain separate from lane templates.
  The operator's on-demand binding MUST be stored in
  `~/.config/jackin/config.toml` under
  `[roles."donbeave/crew-operator".env]` with
  `op = "op://tailrocks/op-service-account-jackin-operator/credential"`,
  `path = "tailrocks/op-service-account-jackin-operator/credential"`, and
  `on_demand = true`; it MUST NOT be a persistent role environment value.

### 6.3 Product claims and replay control

- **SCHED-020** Exactly one active manager host owns product claim and placement
  choices. It MUST append the issue claim and next attempt ordinal to its
  durable manager-host ledger atomically before asking any daemon to launch.
  Linear remains authoritative for eligibility; no product requirement assumes
  a distributed lease service, global compare-and-swap, or external fencing
  token.
- **SCHED-021** A placed launch command MUST carry `(run_id, issue_id,
  attempt_ordinal)`. A worker-host ledger MUST make repeated receipt of that
  exact tuple return the original binding or a no-op, never a second container.
- **SCHED-022** The exact product mutations requiring replay protection are:
  Linear session creation, acknowledgement/activity, plan replacement,
  checklist tick, run-label/external-URL/PR-link update, state transition; and
  GitHub branch push plus PR create/update. Each MUST use its stable external
  object id and read-before-write or an adapter idempotency record scoped to
  `(run_id, issue_id, attempt_ordinal, operation)`.
- **SCHED-023** Merge is not retried blindly. The manager MUST read the PR and
  required checks, request merge only while it is open and green, record the
  returned merge result, and confirm GitHub's merged state before any Linear
  completion write.
- **SCHED-024** On manager/worker timeout or partition, the manager MUST keep
  the existing claim and reconcile the same placed tuple. It may re-place the
  same attempt only after proving the first host produced no container or
  external effect. Unknown outcome waits; proven side effects require a new
  attempt ordinal. Unsupported manager failover MUST fail closed rather than
  run two managers.

## 7. Managed-run state machines

### 7.1 Run states

- **STATE-000** The following table is the complete visible product-run state
  machine.

| State | Entry | Legal next states | Linear activity |
| --- | --- | --- | --- |
| `starting` | Claimed; workspace or launch in progress | `working`, `waiting`, `blocked`, `failed` | `thought` acknowledgement, then `action` launch |
| `working` | Capsule reports activity | `waiting`, `blocked`, `stuck`, `verifying`, `failed` | `action` on transition only |
| `waiting` | Manager posted elicitation | `working`, `failed` | `elicitation`; reply produces `action` |
| `blocked` | Runtime waits for input not requested by manager | `working`, `waiting`, `failed` | `elicitation` or `action` with reason and attach target |
| `stuck` | No capsule activity for stall window | `working`, `failed`, retry/fallback | `action` with last progress and window |
| `verifying` | Checklist complete and completion bar satisfied | `done`, `failed`, retry | `action` |
| `failed` | Attempt failed | retry/continuation/fallback, `waiting`, released | `error` once per failure |
| `done` | Verification passed and PR is ready/review transition completed | released or merging workflow | `response` |

- **STATE-001** Illegal transitions MUST be rejected. Replaying the same
  transition MUST emit no tracker write.
- **STATE-002** `waiting`, `blocked`, and `stuck` are distinct. A runtime
  permission prompt is `blocked`; a manager elicitation is `waiting`; silence
  past the activity window is `stuck`.
- **STATE-003** Runtime resumption MUST clear `blocked` or `stuck` to `working`
  automatically and update label plus activity atomically.
- **STATE-004** The default stall window is 5 minutes and MUST be configurable.
  Heartbeats do not count as capsule progress.
- **STATE-005** The claim state enum is `unclaimed`, `claimed`, `running`,
  `retry_queued`, `blocked`, `released`. Claim state and visible run state MUST
  be stored separately and reconciled explicitly.

### 7.2 Attempt kinds and lifecycle

- **STATE-010** The following attempt-kind table is exhaustive for product
  runs.

| Attempt kind | Trigger | Workspace |
| --- | --- | --- |
| initial | First valid claim | Clone/create or reuse clean issue workspace. |
| continuation | Clean runtime exit with incomplete checklist | Same branch and workspace; new container after 1 second. |
| retry | Agent-class failure | Same branch and workspace after backoff. |
| fallback | Quota or recovered stuck condition | Same branch/workspace; new lane and container. |
| rework | PR closed or merged while issue becomes active again | Reset workspace to current base, then use declared branch policy. |
| merge | Issue enters merging state or task text authorizes merge | Same workspace; merge prompt frame. |

- **STATE-011** Every attempt MUST increment the attempt ordinal, create a new
  attachable container and session, preserve prior records, and replace the
  current Linear external URL while retaining all bindings in the ledger.
  Continuation count, retry budget, and attempt ordinal MUST be stored as three
  separate counters.

## 8. End-to-end workflows

### 8.1 Poll, acknowledge, and claim

- **EXEC-001** Polling is the correctness path. Defaults are 5 seconds for
  delegated issues, pending/non-terminal sessions, and prompted activities,
  plus 30 seconds for full reconciliation.
- **EXEC-002** All reads for one tick MUST be aliases in one GraphQL request:
  delegated candidates, app-user-filtered sessions, activity reads after each
  session watermark, and requested issue detail. Pages MUST be exhausted in a
  stable order.
- **EXEC-003** A delegated active issue without a non-terminal session for the
  app user MUST cause one idempotent `agentSessionCreateOnIssue` call. An
  existing non-terminal session suppresses creation.
- **EXEC-004** The first observation of a pending/new session MUST receive a
  `thought` acknowledgement within 10 seconds. Validation then runs before
  workspace or container creation.
- **EXEC-005** Linear `RATELIMITED` may arrive as HTTP 400. The manager MUST
  read `errors[].extensions.code` and the reset header, pause all tracker
  traffic until reset, queue ordered writes and heartbeats, and log the reset.
  Rate limiting MUST NOT consume an attempt.
- **EXEC-006** In multi-host mode only the manager host polls Linear. Worker
  daemons receive placed candidates over the remote transport.

### 8.2 Workspace and launch

- **EXEC-009** Every launch MUST perform the following ordered transaction; a
  failure resumes at the first uncommitted step without duplicating a published
  effect.

1. Resolve and lock the issue, workflow, lane, role, and host.
2. Clone or reuse a workspace keyed by a sanitized issue identifier.
3. Fetch. Reuse and update the remote branch when present; otherwise create it
   from the declared base. The agent never chooses a branch.
4. Run validated creation/before-run hooks in the container boundary.
5. Read issue content once for pickup and stage the local task tree and
   references. The manager retains the content hash used by the attempt.
6. Launch with all choices pre-supplied through the shared jackin pipeline.
7. Persist container binding before publishing launch activity and external
   URL. If publication fails, reconciliation retries the same logical write.

- **EXEC-010** Dirty, corrupt, or origin-divergent workspaces MUST be held with
  a workspace error; the manager MUST NOT discard uncommitted data silently.
- **EXEC-011** Launch MUST run Claude Code with
  `--dangerously-skip-permissions` and Codex CLI with
  `--dangerously-bypass-approvals-and-sandbox` inside role containers. Future
  runtimes MUST declare an equivalent non-interactive approval mode before use.
- **EXEC-012** Initial delivery `goal` MUST instruct the runtime to read the
  staged task and continue until its verifier prints `status: DONE`. Delivery
  `prompt` sends one plain first turn. Runtime-specific mapping MUST preserve
  meaning and attachability.
- **EXEC-013** Container-path capsule dialogs MUST be handled by the
  coordinator: confirm an expected trust prompt; approve an on-demand binding
  only after the displayed command and credential path match the task; replace
  an invalid restore target with a new instance; and dismiss any other dialog
  before applying the stuck rule. A capsule dialog is never human input by
  itself. Before any relaunch or resume, the coordinator MUST reconcile the
  exact recorded Herdr agent/pane, product container, daemon binding, and task
  status; a surviving live attempt is attached, never duplicated. A host auth
  probe that succeeds turns an in-container login failure into a `re-sync`
  relaunch, not a human blocker.

### 8.3 Checklist and progress

- **EXEC-020** The first Markdown task list MUST be extracted to a local file.
  One newly changed unchecked-to-checked item emits one tick event; unchanged or
  replayed content emits none.
- **EXEC-021** Before checking an item, the agent MUST establish that item's
  completion using relevant tests, inspection, and independent verification.
  Checklist items do not have separate daemon-run verifier commands; the
  issue-level verifier proves the whole task.
- **EXEC-022** For each tick, the manager MUST replace the Linear session plan
  and perform a read-modify-write on a freshly read description and `updatedAt`.
  It matches normalized task-list text, changes only the matching unchecked
  line, and aborts if that line no longer exists.
- **EXEC-023** One tick produces one `pre-read` log and one logical `write`
  record. Concurrent human edits outside the matched task line MUST survive.
- **EXEC-024** The issue content is read once at pickup. Candidate/session/
  activity polling and the pre-write description read are separately tagged
  and MUST NOT be counted as additional pickup reads.
- **EXEC-025** The staged task and prompt frame MUST require the working agent
  to delegate research, implementation, and independent verification for each
  checklist item. The verifier MUST be a fresh context distinct from the
  implementation context; its evidence is required before the item is checked.

### 8.4 Verification and completion

- **EXEC-030** Verification begins only after every checklist item is checked
  and the agent completion bar is satisfied: changes committed and pushed,
  required tests green, PR open/updated, and addressed review findings recorded.
- **EXEC-031** The manager MUST read `[verify].command` from the base-branch
  workflow selected for the attempt and execute it in the same container through
  exec-with-result with a configurable timeout.
- **EXEC-032** Verification passes only when the last complete stdout line is
  exactly `status: DONE`. Exit code, stdout, stderr, duration, tool versions,
  and hashes MUST be retained as evidence; no other text is a pass.
- **EXEC-033** On pass, the manager marks the PR ready, writes the PR link,
  moves the issue to its configured review state, posts one response, and
  releases run capacity while retaining the workspace for merge/rework.
- **EXEC-034** Verification failure is an agent-class failure and supplies
  captured output as redacted `last_error` to the next attempt.
- **EXEC-035** The verifier used to accept an attempt MUST come from the
  locked base-branch snapshot. A verifier authored or changed by the
  implementing agent cannot prove that same attempt; it MUST first receive an
  independent `crew-reviewer` review, reach the base branch through its normal
  protected path, and be selected by a later attempt.

### 8.5 Retry, continuation, fallback, and exhaustion

- **EXEC-040** Clean exit with incomplete checklist queues a continuation after
  1 second, up to 20 continuations by default.
- **EXEC-041** Agent-class failure retries after
  `min(10 seconds * 2^(retry_budget_index-1), 5 minutes)`, up to 3 consumed
  retry-budget entries by default. Exit, timeout, recovered stall, and
  verification failure increment the retry budget and the next attempt ordinal;
  continuation and quota fallback increment only attempt ordinal and their own
  counters.
- **EXEC-042** Workflow/config and workspace failures hold the issue without
  consuming attempts. Tracker failure delays tracker work while active agents
  continue. Observability failure MUST NOT stop execution.
- **EXEC-043** Provider quota exhaustion is infrastructure-class, consumes no
  attempt, and skips every lane sharing the exhausted account home. A fully
  throttled chain waits until the earliest known reset and is never blocked.
- **EXEC-044** After diagnostic analysis, a stuck attempt past its recovery
  threshold uses the ordered lane fallback, switching account home, runtime,
  and model together. Stuck fallback consumes an attempt and remains bounded.
- **EXEC-045** Every fallback MUST honor caps, record both lanes and reason in
  ledger and Linear, and create a new container. It MUST NOT silently change
  runtime or reuse a failed container.
- **EXEC-046** Exhaustion enters persisted blocked claim state and emits one
  elicitation with a blocker brief: missing fact/action, why it blocks the
  contract, exact human action, last evidence, and safe resume method.
- **EXEC-047** Before any stuck fallback or exhaustion escalation, fresh
  diagnostic agents MUST independently test the current assumption, missing
  input, failing check, and environment hypotheses. Their evidence and selected
  fix MUST be recorded; fallback or escalation before this analysis is invalid.

### 8.6 Escalation, replies, stop, and follow-ups

- **EXEC-050** A Linear elicitation is the canonical request for human input.
  A prompted reply MUST be delivered to the same PTY and transition the run to
  working. `signal: stop` MUST stop and release the run without pretending it
  completed.
- **EXEC-051** A host/operator injection through the capsule MUST follow the
  same waiting-to-working transition and produce an activity so Linear records
  remains complete.
- **EXEC-052** Agent-originated follow-up issues MUST be created unassigned in a
  backlog state and linked to the parent. They may be delegated automatically
  only when the parent carries `auto-dispatch`.

### 8.7 Pull request and merge

- **EXEC-060** The GitHub adapter MUST use an organization-scoped installation
  token with contents-write, pull-requests-write, and metadata-read only. It
  MUST push the declared branch and idempotently create or update one PR titled
  with the issue identifier.
- **EXEC-061** Verification MUST precede ready-for-review. The PR URL MUST be
  attached to the Linear issue.
- **EXEC-062** A merge attempt is authorized only by entry into the configured
  merging state or explicit task text. It MUST use the same role, runtime, and
  workspace; update from base; address checks, conflicts, and review findings;
  and MUST NOT bypass a failed required check.
- **EXEC-063** One merge attempt per repository may run at a time. The manager
  MUST confirm the PR's merged state through GitHub before moving the issue to
  `Done`, removing the workspace, and releasing blocking issues.
- **EXEC-064** Closing or merging a PR while work becomes active again creates
  a rework attempt from current base rather than continuing a stale tree.

## 9. Durability, recovery, and multi-host operation

### 9.1 Local ledger and reconciliation

- **REC-001** Every daemon host MUST persist a non-authoritative ledger of
  attempts/kinds/reasons, lanes, blocker briefs, retry deadlines, verification
  results, watermarks, replay records, and container-to-issue bindings. The
  manager-host ledger additionally persists the active claims and placements
  defined by SCHED-020; worker-host ledgers do not own product claims.
- **REC-002** Startup and every reconciliation tick MUST compare Linear active
  work, ledger claims, and backend containers. A labeled live container is
  adopted only when its run id, issue id, attempt ordinal, host, and recorded
  worker binding agree.
- **REC-003** A ledger row alone MUST NOT revive inactive work. A missing
  container for active work is marked lost and follows failure policy. An
  unlabeled or mismatched container is quarantined and surfaced, never adopted
  by guess.
- **REC-004** Watermarks, named adapter replay records, retry deadlines, blocker
  briefs, attempt ordinals, continuation counts, and retry-budget counts MUST
  survive daemon restart.
- **REC-005** Reconciliation MUST never start a second live attempt for the
  same `(run_id, issue_id, attempt_ordinal)` tuple.

### 9.2 Multi-host placement

- **REC-010** One manager MUST place runs across one daemon per host. Run
  identity includes issue, host, and attempt.
- **REC-011** Placement selects the least-loaded eligible host, breaks ties
  deterministically, prefers the prior host on retry while its workspace is
  usable, and waits when all hosts are saturated.
- **REC-012** A host lost before external side effects may be replaced within
  the same logical attempt. After any external side effect, replacement MUST be
  a new recorded attempt with a new attempt ordinal.
- **REC-013** During a network partition or delayed daemon response, the sole
  manager MUST retain its current claim, reconcile the existing placement, and
  wait while the outcome is unknown. The worker MUST refuse a second container
  for an already bound placement tuple. Unsupported manager failover MUST fail
  closed; this contract does not require distributed consensus or a global
  compare-and-swap service.
- **REC-014** Host-relative workspace, socket, config, credential, and ledger
  paths MUST permit the same daemon binary to run on a laptop or Linux server.

## 10. Security, credentials, roles, and supply chain

### 10.1 Secret handling

- **SEC-001** 1Password under a stable `op://` reference, one item per rotation
  unit, MUST be the source of every credential. Raw secret bytes MAY exist only
  in 1Password; runtime process memory; stdin while an authorized command is
  consuming it; the operating-system keychain; provider-owned authentication
  state in `~/.claude`, the declared Codex homes, `~/.amp`, `~/.kimi-code`,
  `~/.opencode`, `~/.grok`, and GitHub CLI auth state; the protected
  `~/.jackin/agent-browser-profile` browser state; or the mode-0600
  `~/.config/jackin/daemon.env` file in SEC-012. Configuration and task files MAY contain stable
  `op://` references but never their resolved bytes. Raw secrets MUST NOT
  appear in any repository, workspace, staged task, Markdown, issue text, model
  message, image, log, evidence, argv, URL, or container label.
- **SEC-002** Secrets used by commands MUST be supplied on stdin or through a
  host-side binding with redacted output. Verification MUST disable shell
  tracing and MUST NOT use verbose HTTP tracing.
- **SEC-003** Evidence directories MUST be scanned with gitleaks before
  publication. A hit invalidates the evidence, requires credential rotation,
  and blocks publication.
- **SEC-004** Runtime credentials MUST be resolved per launch so rotation takes
  effect. They MUST NOT be cached across daemon restart.
- **SEC-005** The browser profile and its portable storage-state file are
  secrets. They MUST be mode-restricted, never committed, and mounted read-write
  only into the operator role.

### 10.2 1Password contract

- **SEC-009** The following table is the complete stable item and field-name
  contract for the delivered environments. Additional provider items require a
  new normative requirement; every item and field MUST retain the exact spelling
  and case shown, including `Key` and `PEM private key`.

| Purpose | Stable item/reference contract |
| --- | --- |
| Linear app `linear-agent-app` | `op://jackin/linear-agent-app/client id`; `op://jackin/linear-agent-app/client secret`; `op://jackin/linear-agent-app/app url`; `op://jackin/linear-agent-app/webhook signing secret`; `op://jackin/linear-agent-app/redirect uri` |
| Linear workspace `linear-workspace` | `op://jackin/linear-workspace/access token`; `op://jackin/linear-workspace/expires at`; `op://jackin/linear-workspace/installation seed`; `op://jackin/linear-workspace/app user id`; `op://jackin/linear-workspace/organization id`; `op://jackin/linear-workspace/url key` |
| GitHub App `jackin-daemon`, `jackin-project` installation | `op://jackin/github-app-jackin-daemon-jackin-project/app id`; `op://jackin/github-app-jackin-daemon-jackin-project/client id`; `op://jackin/github-app-jackin-daemon-jackin-project/installation id`; `op://jackin/github-app-jackin-daemon-jackin-project/PEM private key` |
| GitHub App `jackin-daemon`, `tailrocks` installation | `op://jackin/github-app-jackin-daemon-tailrocks/app id`; `op://jackin/github-app-jackin-daemon-tailrocks/client id`; `op://jackin/github-app-jackin-daemon-tailrocks/installation id`; `op://jackin/github-app-jackin-daemon-tailrocks/PEM private key` |
| Claude runtime | `op://jackin/claude-daemon/api key` |
| Codex runtime | `op://jackin/codex-daemon/api key` |
| Amp runtime | `op://jackin/amp-daemon/api key` |
| Kimi runtime | `op://jackin/kimi-daemon/api key` |
| OpenCode runtime | `op://jackin/opencode-daemon/api key` |
| Grok runtime | `op://jackin/grok-daemon/api key` |
| Registry | `op://jackin/registry-dockerhub/username`; `op://jackin/registry-dockerhub/token` |
| Server host 1 | `op://jackin/server-host-1/address`; `op://jackin/server-host-1/ssh user`; `op://jackin/server-host-1/private key`; `op://jackin/server-host-1/arch` |
| Server host 2 | `op://jackin/server-host-2/address`; `op://jackin/server-host-2/ssh user`; `op://jackin/server-host-2/private key`; `op://jackin/server-host-2/arch` |
| Operator service account | `op://tailrocks/op-service-account-jackin-operator/credential` |
| Daemon service account | `op://tailrocks/op-service-account-jackin-daemon/credential` |
| Human browser setup | `Private/Linear` Google-SSO item; `Private/GitHub`; GitHub OTP at `op://Private/GitHub/Key` |

- **SEC-010** The dedicated `jackin` vault contains runtime material only.
  Item names MUST contain no unresolved organization slug.
- **SEC-011** The operator service account may read and write only vault
  `jackin`; its token is stored in `tailrocks` and injected per approved
  `jackin-exec op` invocation, never as a persistent role environment value.
- **SEC-012** A server daemon service account may read only vault `jackin`.
  Its token is stored outside the vault it unlocks, materialized once into a
  mode-0600 `~/.config/jackin/daemon.env` file, and never passed in argv.
- **SEC-013** Only the manager daemon may mint and hold a Linear
  client-credentials token. It MUST mint in memory at startup and when fewer
  than 48 hours remain, MUST NOT use the refresh-token grant, and MUST NOT write
  minted tokens back to 1Password. Worker daemons and role containers MUST hold
  no Linear credential. The one authorization-code exchange stores its refresh
  token only in the `installation seed` field and no runtime may use that seed.
- **SEC-014** Rotating a Linear client secret invalidates and re-mints all
  client-credentials tokens. GitHub App keys MUST support add-switch-remove
  rotation. Provider keys SHOULD rotate at least every 90 days.
- **SEC-015** GitHub access MUST use one separately installed App and one
  separately named 1Password item per organization. The delivered proof
  environment requires distinct `jackin-project` and `tailrocks` installations;
  a token or installation id from one organization MUST NOT authorize the
  other.
- **SEC-016** Human-only authority MUST create, consent to, or supply before
  execution: the `jackin` vault; the `jackin-daemon` GitHub App installed with
  all-repository access in both organizations; both 1Password service accounts;
  provider/registry keys; both server-host items; browser SSO, TOTP, and consent;
  and any billing or physical hosts. Agents MUST only verify and consume those
  exact objects. A sudo-mode, Google re-authentication, consent, OTP, or missing
  human-created credential encountered later creates the task's own preflight
  defect; it MUST NOT be answered from an operator role or replaced by an
  invented credential.

### 10.3 Role separation

- **ROLE-000** The following table is the complete minimum role payload and
  isolation matrix. Every final role MUST satisfy its row in addition to
  ROLE-001 through ROLE-016.

| Role | MUST contain | MUST NOT contain / boundary |
| --- | --- | --- |
| `the-architect` | jackin development toolchain; supported runtimes; DCO-capable git; project skills. | Browser profile or Linear workspace token. |
| `donbeave/crew-builder` | Claude and Codex; termrock toolchain; code/review/commit skills; standard network; privileged DinD only through an explicit role grant. | `agent-browser`, `op`, Linear token, operator service token, browser profile. |
| `donbeave/crew-operator` | Claude and Codex; `agent-browser`; Debian Chromium on supported architectures; `op`; network allowlist; browser storage state. | Rust/compiler toolchain, private/personal vault access, persistent service token, DinD. |
| `donbeave/crew-reviewer` | Claude and Codex review tooling; read-only workspace; GitHub review/comment capability. | Compiler or build-script execution, `op`, browser profile, Linear token, write mount, approval from same PR author. |
| `host` | Human-only or host-only action marker; no role image. | Dispatch as a container role. |

- **ROLE-001** GitHub-backed role selectors are fully qualified; the canonical
  built-in selector `the-architect` is also valid. Trust grants are per exact
  resolved selector, never wildcard. Non-interactive launch of an untrusted
  role fails validation.
- **ROLE-002** Model and effort are lane/workspace choices, not hard-coded in a
  reusable role manifest. Codex hooks may write only model/effort config and
  staged agents, never auth state.
- **ROLE-003** Operator browser preflight may warn about missing login but may
  fail launch only when the profile is unsafe or unwritable. Stale Chromium
  singleton files MUST be removed only when the operator cap proves no live
  holder.
- **ROLE-004** Reviewer verdict body starts with
  `verdict: REQUEST_CHANGES|COMMENT`. When reviewer identity equals PR author,
  the GitHub event MUST be `COMMENT`, never `APPROVE` or `REQUEST_CHANGES`.
  Review is pinned to the supplied commit and diff range.
- **ROLE-005** Final role images MUST be public multi-architecture images,
  built on GitHub-hosted runners, signed keylessly, and labeled with source git
  SHA. Pull freshness is checked against that label.
- **ROLE-006** The reviewer MUST emit confirmed findings in stable
  `blocking`, `major`, or `minor` form and MUST NOT hold a Linear credential.
  The manager or authorized operator converts findings into checklist items;
  review prose alone MUST NOT mutate issue state or authorize merge.
- **ROLE-010** `donbeave/jackin-role-template` MUST be a public GitHub
  template, MUST NOT contain `jackin.role.toml`, and MUST provide the shared
  digest-pinned `construct:0.36-trixie` Dockerfile material, instruction
  fragments, source hook, pre-commit/marketplace audit, Renovate config, and
  exactly CI, precommit, and publish-image workflows on GitHub-hosted runners.
- **ROLE-011** Each `donbeave/jackin-crew-*` repository MUST derive from that
  template, use manifest `v1alpha7`, set `agents = ["claude", "codex"]` and
  `default_agent = "claude"`, omit manifest model pins, assemble runtime-neutral
  instructions, and contain no build-time or runtime credential literal.
- **ROLE-012** `crew-builder` MUST be able to install and run the complete
  termrock locked toolchain without downloading prewarmed tools, including Rust
  1.97.1, nightly, `wasm32-unknown-unknown`, nextest, public-api, semver checks,
  wasm-pack, bun/node, Python/uv, REUSE, gitleaks, and lychee. It MUST contain
  the pinned Tailrocks skills and required code/git/Rust plugins, and MUST NOT
  contain `agent-browser` or `op`.
- **ROLE-013** `crew-operator` MUST contain `agent-browser` 0.35.1, Debian
  Chromium on amd64 and arm64, `op` 2.39.0 verified by per-architecture
  checksum, `gh`, Node, and Python, and MUST NOT contain Rust tooling. Its
  manifest MUST select `/usr/bin/chromium`, the persistent profile and evidence
  paths, and MUST NOT declare `OP_SERVICE_ACCOUNT_TOKEN`.
- **ROLE-014** `crew-reviewer` MUST contain pinned Tailrocks review skills and
  review-crucible plus the Claude/Codex review surfaces, and only the runtime
  support needed to review. Its workspace is read-only; `cargo`, `op`, and
  `agent-browser` MUST be absent.
- **ROLE-015** Docker grants are role-owned, never lane-owned:
  `the-architect` and `crew-builder` may receive explicit privileged DinD;
  `crew-operator` receives only the required Linear, Google, GitHub, and
  1Password network allowlist plus its browser-profile mount; `crew-reviewer`
  receives neither. Lane-owned cache mounts MUST isolate concurrent writers by
  account/lane.
- **ROLE-016** Every sourced role hook MUST default `CODEX_HOME` safely, be
  idempotent, be a no-op when its lane model is absent, and MUST NOT use
  `set -e`, call `exit`, or modify authentication. Operator preflight may fail
  only for an unsafe/unwritable profile; missing login is a warning. Operator
  teardown MUST close browser processes before removing stale singleton files.
- **ROLE-017** Every change to `jackin-project/jackin` and sibling
  jackin-project repositories within the established development scope MUST run
  in `the-architect`. `crew-builder` owns termrock, this repository, and the
  crew-role repositories, not jackin. `crew-operator` owns browser, Linear,
  GitHub-settings, and 1Password operations; `crew-reviewer` owns review. The
  only permitted project-driven changes to `jackin-the-architect` are the CI
  runner/model/DCO changes and `default_agent` change in DEP-027.
- **ROLE-018** Every product milestone MUST include a real Linear/GitHub browser
  proof performed by `donbeave/crew-operator` with the persistent portable
  storage state, never by the implementing role. The operator MUST first open
  the Linear app settings URL and re-enable the intentionally failing
  agent-session webhook when disabled; that maintenance is not a defect. Media
  stays on the access-controlled Linear issue and only text references enter
  task evidence. Browser proof is a delivery acceptance surface, not a runtime
  dependency of the manager.

### 10.4 Isolation and untrusted execution

- **SEC-020** Yolo runtime mode MUST NOT broaden mounts, network, Docker, or
  credential grants. The role/workspace policy is the security boundary.
- **SEC-021** Repository hooks, builds, and verifiers run only inside the
  declared container/DinD boundary. Reviewer content MUST NOT execute build
  scripts.
- **SEC-022** GitHub and role supply-chain refs MUST be immutable commits,
  digests, or signed images. CI for delivered repositories MUST use
  GitHub-hosted runners, not a private runner dependency.
- **SEC-023** Every created repository and published role image is public.
  Public evidence MUST remain text-only; screenshots and recordings belong on
  access-controlled issue surfaces when they may expose user state.

## 11. Open questions

None.

- **PRD-030** No final-product question is open. Any future ambiguity MUST be
  resolved in this specification before it can change product behavior or
  acceptance.

## 12. Observability and operator experience

- **OBS-001** Every state transition, tracker read/write, launch, fallback,
  verification, PR operation, merge, claim change, and recovery action MUST emit
  a structured event with UTC timestamp and correlation identities.
- **OBS-002** Tracker logs use tags `poll`, `issue.read`, `pre-read`, and
  `write`. One logical write emits one `write` record with a `kind`, even when
  several mutations share one GraphQL request.
- **OBS-003** Active runs emit a heartbeat every 10 minutes by default, below
  Linear's stale threshold, carrying last capsule progress time. Heartbeat stops
  after the run leaves active states.
- **OBS-004** Logs, activities, snapshots, and evidence MUST redact secrets and
  untrusted control characters. Raw prompt content MUST not be copied into
  fleet-wide logs.
- **OBS-005** Linear alone MUST answer who is working, where, since when, on
  which attempt, and whether the run is working, waiting, blocked, stuck,
  verifying, or failed.
- **OBS-006** The termrock console MUST render fleet rows from the snapshot,
  use termrock's host-loop drain/subscription contract, use a reusable
  `TerminalPane` with scrollback/follow/selection/input outcomes, and attach to
  a selected capsule session with one action. It MUST NOT duplicate generic
  termrock widgets inside jackin.
- **OBS-007** `jackin daemon evidence <instance>` MUST produce redacted,
  durable text suitable for a proof bundle without requiring manual terminal
  capture.
- **OBS-008** termrock `runtime::run` MUST provide a synchronous,
  runtime-neutral drain/subscription seam that lets a host apply queued daemon
  events before update/render without a private terminal loop. It MUST NOT own
  Tokio, transport, or process policy, and an empty source MUST add no idle
  redraw.
- **OBS-009** termrock `TerminalPane` MUST render a borrowed
  `TerminalCellSource` without owning VT parsing or a PTY; provide bounded
  scrollback, tail follow, pause/unseen indication, selection/copy, focus, and
  resize behavior; and classify input as either consumed by pane interaction or
  returned as bytes/actions for the product to forward. Scrolling suspends
  follow and an explicit tail action resumes it.
- **OBS-010** Human preflight approval authorizes the host session, and only the
  host session, to run `mise run bless-previews` in the termrock checkout after
  the fleet story and again after a flagship-output change. The host MUST commit
  the resulting golden text on the integration branch, file rendered frame text
  in the producing task folders, and attach the lookbook export to the review
  issue. No container role may set the blessing variable. Blessing is neither a
  human gate nor a defect; review of the blessed output is post-hoc.

## 13. Deployment, upgrades, repositories, and release boundary

### 13.1 Deployment profiles

- **DEP-000** The following deployment profiles are required final
  configurations, not examples; every profile MUST retain the same issue,
  isolation, state, replay, verification, and observability contracts.

- **DEP-001** **Local.** One daemon and manager run against a local Docker backend
  using forwarded provider and GitHub logins. The same schemas and behavior as
  server mode apply.
- **DEP-002** **Server.** A Linux Docker host runs the branch/release binary,
  capsule, and published roles. Provider auth uses per-runtime 1Password API
  keys, not forwarded laptop login. Daemon configuration and data paths are
  host-relative. The service is restartable and exposes remote status.
- **DEP-003** **Multi-host.** One manager polls Linear and places work across at
  least two daemon hosts. Capacity, host failure, previous-host preference,
  and duplicate-prevention requirements of REC-010..REC-014 apply.
- **DEP-004** Health/readiness MUST distinguish config validity, tracker auth,
  backend reachability, role availability, remote peer reachability, and
  degraded observability. A degraded observer MUST not make execution unhealthy.

### 13.2 Manifest and CLI compatibility
- **DEP-012** Role manifest schema `v1alpha7` adds `default_agent`, validated
  against `agents`. All published crew roles MUST use that schema and declare
  `default_agent = "claude"`; this is the sole manifest schema increment in the
  delivered source set.
- **DEP-013** CLI interactive paths MUST retain regression coverage whenever
  shared launch code changes.

### 13.3 Repository and release state

- **DEP-020** Changes are delivered in the repository that owns the behavior;
  manager code MUST NOT work around a defect in jackin, termrock, or a role.
- **DEP-021** Protected default branches are reached only through a pull request
  with required checks and DCO attribution. No force push or bypass is part of
  normal delivery.
- **DEP-022** Agent-authored merge authorization MUST be explicit in task text.
  A review may run concurrently and MUST NOT become an implicit human gate.
- **DEP-023** The delivered crew images are published. The delivered termrock
  changes may have a GitHub release; publishing termrock 0.14 to crates.io and
  creating a crates.io token are outside this product contract.
- **DEP-024** Both organization-scoped GitHub App installations MUST use
  `repository_selection=all`: one installation for `jackin-project`, one for
  `tailrocks`. The adapters MUST still request only the permissions in
  EXEC-060 and MUST scope every token to its literal organization installation.
- **DEP-025** Destructive live GitHub proofs MUST use only the public repository
  `jackin-project/jackin-managed-scratch`. That scratch repository MUST have no
  branch protection so branch/PR/merge cleanup can be exercised. Product and
  roadmap repositories MUST NOT be used as destructive proof targets.
- **DEP-026** The release validator MUST merge the protected `jackin` default
  branch only through a green DCO-attributed PR, prove the preview release
  target equals `origin/main`, then use a fresh preview `jackin-role` to validate
  every final `v1alpha7` crew role and rerun the crew CI gates green against the
  previewed jackin source.
- **DEP-027** Repository ownership has one reciprocal role-bootstrap exception:
  the managed-execution lane setup MAY change `jackin-the-architect` CI runner,
  model-selection, and DCO gates, and the jackin `default_agent` schema delivery
  MAY set `default_agent` in `jackin-the-architect` after jackin supports it.
  These are the exact authorized cross-repository changes; no broader exception
  to DEP-020 is authorized.
- **DEP-028** The executing development host MUST have one effective jackin
  binary: the locally rebuilt `feat/managed-execution` branch build. A Homebrew
  `jackin-preview` installation MUST be absent, and work MUST NOT select an old
  release or wait for a preview package when the branch owns the required
  behavior. Protected-main and release validation remain governed by DEP-021
  and DEP-026.

## 14. Proof-plane contracts for this repository

This section specifies shipped control-plane behavior.

### 14.1 Locked inputs and readiness

- **CTRL-001** Every task bundle consists of `TASK.md`, `task.toml`,
  `verify.sh`, `expected-evidence.toml`, and `refs/`. All bundles MUST be fully
  materialized and content-addressed before product execution begins.
- **CTRL-002** `run/LOCK.toml` MUST bind the roadmap/graph, every bundle hash,
  the plan commit containing this specification, repository base SHAs, required
  tool/protocol versions, and one `lock_hash`. The locked `plan.commit` is the
  SPEC-content binding; no separate mutable specification snapshot may replace
  it. A locked input changing without a new lock invalidates readiness and
  evidence.
- **CTRL-003** Static readiness MUST verify graph completeness and acyclicity,
  produced/consumed artifact closure, bundle hashes, lock integrity, disposition
  coverage, shell portability, proof fixtures, invariant lint, state-store
  integrity, and verifier policy without network or host mutation.
- **CTRL-004** Live readiness MUST verify the executing host's container
  backend, required CLIs, credentials, runtime logins, Herdr, permission flags,
  wake/lock prerequisites, role trust, and external applications without
  launching an agent or task.
- **CTRL-005** Both readiness gates MUST name the same lock hash and end exactly
  `status: READY`; otherwise start/resume is refused. Readiness may print but
  MUST NOT invoke the next command.
- **CTRL-006** The locked delivery run MUST require an independent foundation
  audit before post-foundation work other than `M3-01`, `M3-03`, `M4-02`, and
  `M4-03` becomes ready. A fresh, context-isolated
  `claude-opus-5` auditor MUST rerun every M1 host verifier, compare the locked
  creation set and exit gate, and write `tasks/M1-12/audit.md` with last
  non-empty line exactly `audit: PASS`. A missing, stale, mismatched, or failing
  artifact MUST keep every non-exempt M2-or-later task unready. The four exempt
  tasks use their locked bundles before M1-12 and MUST be backfilled into the
  Linear mirror by ISSUE-006.
- **CTRL-007** Proof-plane machine files MAY exist only in `tools/`, `tests/`,
  `run/`, `findings/`, `.claude/`, the root `verify.sh`, and the declared files
  under `tasks/<id>/`. Tooling and verifiers MUST use POSIX `sh` or Python 3
  standard library only. Evidence MUST use the text formats declared by the
  bundle and MUST NOT introduce binaries, archives, or generated product
  artifacts into this repository.
- **CTRL-008** The shipped delivery coordinator profile MUST be
  `claude-fable-5` at `high` effort. Every large-file read, research operation,
  implementation checklist item, verification, proof, and contract edit MUST
  be delegated to a fresh `claude-opus-5` subagent, one subagent per checklist
  item, with research, implementation, and verification in independent
  contexts. Codex lanes L4 through L6 MUST run in their jackin role containers
  with the exact SCHED-006 profiles and MUST NOT run as host subagents. The
  coordinator integrates results but MUST NOT substitute its own unverified
  work for a mandated delegate.

### 14.2 Authoritative event store and projections

- **CTRL-009** `run/events.jsonl` MUST be the authoritative delivery state. Each
  line MUST be one canonical JSON object. All event types MUST carry `seq`,
  `ts`, `type`, and `prev`; event-specific fields are subordinate to this
  requirement and MUST use the following exact names.

```json
{
  "seq": 0,
  "ts": "RFC3339 UTC",
  "type": "init|transition|lease|release|event|lock_epoch|rejected",
  "prev": "sha256-of-previous-canonical-object-or-64-zero-genesis"
}
```

  `init` carries `run_id`, `idempotency`, and `tasks`. `transition` carries
  `task`, `status`, `lane`, `path`, `result`, `evidence`, `attempt`, `token`,
  and `idempotency`. `lease` carries `task`, `owner`, `token`, `epoch`, `ttl`,
  and `expires_at`; `release` carries `task` and `token`; `event` carries
  `task`, `operation`, `attempt`, `token`, `result`, `evidence`, and
  `idempotency`. `lock_epoch` carries `epoch`, `lock_hash`, `previous_epoch`,
  `previous_lock_hash`, `bootstrap`, `fences`, `quiescence`, `resets`, and
  `idempotency`; each fence has `task`, `from_token`, and `to_token`, and each
  reset has `task`, `from_status`, `to_status`, `from_attempt_epoch`, and
  `to_attempt_epoch`. `rejected` carries `reason` plus the flattened detail
  fields supplied by the refused operation and is not required to carry an
  idempotency key. `seq` is zero-based and equals the line index. The store
  does not carry a separate `hash` field.

- **CTRL-010** Only `tools/state.py` may append. It MUST take an exclusive
  flock, open with `O_APPEND`, write one complete line, `fsync`, close, and
  release the flock. `prev` MUST equal SHA-256 of the previous complete canonical JSON
  object excluding its newline; the first event uses 64 zeroes.
- **CTRL-011** The store is append-only. Invalid JSON, sequence gap, broken hash
  chain, illegal transition, duplicate idempotency key, or stale fencing token
  is `failed-system`; repair MUST NOT rewrite prior events.
- **CTRL-012** Task status values are exactly `planned`, `ready`, `leased`,
  `in-progress`, `waiting`, `resource-waiting`, `blocked`, `failed-system`, and
  `done`. Lease and resource-wait facts MUST also remain
  independently derivable, not inferred from prose. Their meanings are:
  `planned` is not promoted; `ready` satisfies promotion but is not claimed;
  `leased` has an active proof-plane lease; `in-progress` has an executing
  delivery attempt; `waiting` means every lane in the fallback chain is
  throttled; `resource-waiting` means a host, role, repository, or account cap
  is the only constraint; `blocked` requires that task's own open human-input
  or `exhausted:` defect; `failed-system` is proof/control-plane invalidity;
  and `done` has accepted evidence. These values MUST NOT encode product
  `run:*` state, attempt kind, claim state, or an elicitation.

  The following table is the complete legal task-status transition relation.
  Any other edge MUST be rejected and audited without changing task state.

| Current status | Legal next status | Authority |
| --- | --- | --- |
| `planned` | `ready` | Internal `arm` or `promote` only. |
| `ready` | `leased`, `resource-waiting` | Atomic lease acquisition alone owns `leased`; the scheduler records `resource-waiting` internally before lease acquisition. |
| `leased` | `in-progress`, `ready`, `blocked`, `failed-system` | Current lease holder. |
| `in-progress` | `waiting`, `resource-waiting`, `ready`, `blocked`, `failed-system`, `done` | Current lease holder. |
| `waiting` | `in-progress`, `ready`, `blocked`, `failed-system`, `done` | Current lease holder. |
| `resource-waiting` | `ready` | Internal scheduler cap bookkeeping before lease acquisition. |
| `blocked` | `ready` | Current lease holder after the task's human-input or exhaustion row is resolved. |
| `failed-system` | none | Terminal. |
| `done` | none | Terminal. |

  `init` creates only `planned`; `lock_epoch` MAY reset an interrupted
  `leased`, `in-progress`, `waiting`, or `resource-waiting` task to `ready`
  while opening its next attempt epoch. Existing valid events replay under the
  schema that accepted them; this table governs new events.
- **CTRL-013** `tasks/README.md` and `PROGRESS.md` are generated projections.
  They MUST be reproducible byte-for-byte from the event store and MUST NOT be
  hand-edited.
- **CTRL-014** A task becomes runnable only from `ready`, after every declared
  dependency is `done`, while its lane slot is free, no more than two host
  subagents using `~/.claude` and no more than three host subagents total are
  already in flight, and CTRL-015 permits the resource use. Every M2-or-later
  task except `M3-01`, `M3-03`, `M4-02`, and `M4-03` additionally requires
  `M1-12` to be `done`, the CTRL-006 audit to pass, and its Linear issue mirror
  to exist. The four named tasks are exempt from all three conditions and run
  from locked bundles. `planned`, `blocked`, `waiting`, `in-progress`, and
  terminal states are not runnable. A dependency's block does not copy
  `blocked` onto dependents.
- **CTRL-015** Before dispatching any `~/.claude` consumer, the coordinator MUST
  refresh the Claude usage snapshot and read the session-bucket
  `remaining_percent`. Below 40%, the Claude-container cap and host-subagent cap
  are each one. Below 20%, only Codex-lane work may dispatch, no host subagent
  may spawn, and diagnostics use one idle Codex home. A weekly bucket below 15%
  has the same restriction until its recorded reset. A quota-limited running
  pane remains live and idle time caused by quota is not stuck; only a weekly
  reset more than 24 hours away is human-input blocking.
- **CTRL-016** `python3 tools/state.py arm` MUST be idempotent and initially
  promote only `M1-01` from `planned` to `ready`. When `M1-01` becomes `done`,
  `M1-02`, `M10-02`, and `M10-03` become promotion candidates, subject to every
  other predicate including M1-12, audit, and issue gates for M10. The four
  CTRL-014 early-start tasks promote as soon as their declared dependencies are
  done without those three gates. Every later `done` transition
  MUST atomically promote each `planned` task whose dependencies and audit gate
  are satisfied. No bare or `planned` row may be dispatched.
- **CTRL-017** Within runnable work, wave and declared critical-path order MUST
  be stable. The lowest unfinished milestone gets each free slot before a later
  early-start task; early-start work may consume only a slot that would
  otherwise idle. The reserved L4 slot for `M1-04a`, `M1-05a`, and `M1-08`
  MUST remain free until `M1-08` is done.
- **CTRL-018** No new evidence for 30 minutes, or three consecutive verifier
  failures, MUST pause further task action and launch fresh diagnostic
  subagents to test assumptions, missing inputs, failing checks, and environment.
  The proven fix MUST be applied before dispatch, retry, fallback, or exhaustion.
- **CTRL-019** Proof-plane leases and fencing tokens apply only to authoritative
  event-store transitions, task claims, repository integration, and the named
  proof mutations `push`, `pull-request create/update`, `merge`, Linear mirror
  write, and release publication. Each such mutation MUST pass the state gate
  with current proof lease/fencing token. Its task-scoped idempotency key MUST
  be SHA-256 of the UTF-8 values `run_id`, `lock_epoch`, `task`,
  `attempt_epoch`, `attempt_ordinal`, and `operation`, in that order separated
  by byte `0x1f`, exactly as `tools/state.py task_idempotency_key` computes it.
  Initialization alone uses SHA-256 of `run_id`, `*`, `0`, and `init` with the
  same separator; lock-epoch changes use their caller-supplied audited key.
  `init`, `arm`, `promote`, `lock_epoch`, rejection-audit append, atomic lease
  acquisition, and scheduler-owned `ready`/`resource-waiting` cap bookkeeping
  are host-internal authoritative operations and MAY run without a pre-existing
  task lease. Every other invocation of `tools/state.py transition` and every
  external-effect `event`, whether requested by a host or worker, MUST carry
  the exact token of an active, unexpired lease for that task. A normal
  `release` has the same requirement. The internal reconciler MAY instead run
  an audited `release --expired` only after proving the stored lease's
  `expires_at` has passed and only with that exact stored token; an omitted,
  stale, mismatched, or future token MUST still be rejected and audited.
  Internal promotion transitions and lock-epoch resets are not external
  transition invocations. A named external proof mutation MUST also carry its
  operation idempotency key.
  This requirement does not create a product-daemon global lease or fence
  beyond SCHED-020 through SCHED-024.

### 14.3 Task isolation and repository integration

- **CTRL-020** Every implementation task MUST use a dedicated worktree and
  branch `managed/<run-id>/<task-id>` from the base SHA in `run/LOCK.toml`.
  Workers push only that branch.
- **CTRL-021** Each repository has one integrator lease. Only its current
  fencing-token holder may merge a task branch into the integration target.
  Verification runs against the resulting integrated SHA, never a worker tip.
- **CTRL-022** Integration retries MUST fetch and merge without force. A stale
  integrator lease or divergent unrecorded commits fail closed.
- **CTRL-023** Product repositories use their declared integration branch;
  role repositories integrate to their loadable default branch. This repository
  remains single-writer for planning and proof artifacts.

### 14.4 Verification and evidence

- **CTRL-029** Every task folder MUST declare expected evidence before
  execution in `expected-evidence.toml` and MUST record actual evidence in
  `evidence.json`. The declaration MUST contain `task` and zero or more
  `[[evidence]]` entries with exactly `path`, `part`, and `contains`: `path` is
  relative to `tasks/<id>/`, `part` is `container` or `host`, the file is
  non-empty, and a non-empty `contains` marker occurs in it. The generated task
  verifier checks those declarations. The manifest validator requires only the
  fields marked required below; the supported producer MAY also emit the
  optional fields shown and MUST NOT invent another acceptance schema.

| Field | Contract |
| --- | --- |
| `task` | Required non-empty string equal to folder/id. |
| `bundle_hash` | Required non-empty 40- or 64-lowercase-hex hash matching `run/LOCK.toml`. |
| `integrated_sha` | Required 40-lowercase-hex scalar; when `repositories[]` exists, equals its first SHA. |
| `repositories[]` | Optional; when present, one object per touched repository with `repo`, `branch`, `integrated_sha`, and `checkout`; scalar `integrated_sha` equals the first entry. |
| `commands[]` | Required non-empty array; each entry has non-empty string-array `cmd`, integer `exit_code`, 64-lowercase-hex raw-byte `stdout_sha256` and `stderr_sha256`, and non-empty `started`/`finished` timestamp strings. |
| `tool_versions` | Optional object of exact relevant version lines; MAY be empty. |
| `external_object_ids` | Optional object containing Linear issue/session, PR, container, release, or other external ids; MAY be empty. |
| `attempt`, `epoch`, `fencing_token` | Optional integer values current when evidence was written. |
| `result_class` | Required; one of `DONE`, `BLOCKED HUMAN`, `FAILED SYSTEM`, `PENDING`. |
| `created`, `updated` | Optional UTC timestamp strings written by the manifest producer. |

- **CTRL-030** Evidence writing MUST be atomic through a same-directory
  temporary file and `os.replace`. Output hashes cover raw bytes. A failed
  command is recorded and makes evidence generation fail non-zero.
- **CTRL-031** Task `verify.sh` MUST be POSIX `sh`, accept `container` or
  `host`, run only that part, and end with `status: DONE` on pass or a
  non-DONE status on failure. When both parts exist, host verification MUST
  first prove the container output ended `status: DONE`.
- **CTRL-032** A task verifier MUST not assert its own projection status or the
  root remaining count. Transient external state MUST be accepted only through
  a timestamped snapshot captured while it held.
- **CTRL-033** Composite `verify.out` MUST identify proof-plane commit,
  `bundle_hash`, and every integrated SHA before captured outputs. Its final
  line is authoritative only when `evidence.json` validates.
- **CTRL-034** A task may become `done` only when verifier output ends
  `status: DONE`, expected evidence exists, manifest and bundle validate,
  integrated SHAs are ancestors of current pushed integration heads, every
  touched repository is clean/pushed, and required commits carry DCO.

### 14.5 Attempt epochs and human blockers

- **CTRL-040** Attempt record is append-only and includes epoch, attempt,
  limit, lane, path, verifier output, and UTC time. Resume derives counts from
  durable state, never model context.
- **CTRL-041** A task is `blocked` only when it has its own unresolved
  `PREFLIGHT-DEFECTS.md` row. Missing human input rows carry a proof command;
  the coordinator reruns it and may fill `Resolved` after it passes.
- **CTRL-042** An `exhausted: <id>` row carries `re-run`, last evidence, and
  analysis. Only a human may fill its `Resolved` cell. Until then no new epoch
  or attempt may start. A human-filled row opens a new epoch.
- **CTRL-043** Failing tests, design choices, project defects, reviews, quota
  waits, runtime dialogs, stale binaries, and installable missing tools are not
  human blockers.

### 14.6 Root oracle

- **CTRL-049** Root `verify.sh` MUST derive, never accept as input or model
  assertion, exactly one terminal class using the following table.

| Last line | Exact meaning |
| --- | --- |
| `status: DONE` | Every locked task is `done`; all CTRL-030..CTRL-034 evidence and repository checks pass; projections match; no active/runnable work; tree is clean. |
| `status: BLOCKED HUMAN` | No active, waiting, or runnable work remains; at least one task is blocked solely on an unresolved human-input or human-cleared exhaustion row; integrity checks otherwise pass. |
| `status: FAILED SYSTEM` | Store, lock, graph, bundle, evidence, repository, projection, or tool integrity is invalid and no human input row is the cure. |
| `status: PENDING` | Work remains, is active, is resource-waiting, or can become runnable; none of the terminal classes applies. |

- **CTRL-050** The oracle MUST print a census before the final line and MUST be
  read-only.
- **CTRL-051** Adversarial fixtures MUST prove all four classes, precedence,
  forged/stale evidence rejection, dirty/unpushed repository rejection, blocker
  semantics, and projection mismatch.
- **CTRL-052** No model or task may write its desired root result class into the
  authoritative store or evidence to cause acceptance.
- **CTRL-053** `status: DONE` additionally requires every acceptance row in
  Section 15 to be supported by the locked Roadmap-owned task verifiers and
  permitted task evidence that prove its positive, negative, and fault
  assertions. No separate acceptance store or invented acceptance script is
  authoritative. Missing, invalid, stale, or semantically insufficient proof
  when all locked tasks otherwise claim completion is `status: FAILED SYSTEM`,
  never `DONE`; while required work remains it is `status: PENDING`.

### 14.7 Herdr supervisor and resume

- **CTRL-060** Herdr 0.8.2 is the sole host PTY/process owner for the delivery
  coordinator, pre-daemon tasks, probes, and interim processes. tmux and
  headless print-mode coordinators are forbidden.
- **CTRL-061** `tools/supervisor.sh start` and `resume` are the only ignition
  points. They MUST reconcile leases, print the exact launch/attach plan before
  launch, create or reuse the isolated `ecosystem-coordinator` Herdr session,
  start one interactive coordinator with yolo permission flags, submit the
  canonical goal prompt, and attach.
- **CTRL-062** `status` and `read` are non-mutating. `stop` terminates only the
  named isolated Herdr session and its panes. `--dry-run` previews reconciliation
  and launch, writes no event, and starts nothing.
- **CTRL-063** `resume` MUST attach a surviving coordinator. If absent, it
  reconciles durable state and relaunches only after explicit operator invocation.
  Completed tasks MUST never lose `done`, regain a lease, or rerun.
- **CTRL-064** A task survivor is live only when its exact lowercase task alias
  is active or its pane foreground command contains boundary-delimited task id
  plus declared runtime. Pane existence alone is insufficient. Idle/done after
  prompt delivery proceeds to verification; working resumes; dead restarts as a
  new attempt after teardown.
- **CTRL-065** Attach failure returns 4 and preserves the live coordinator and
  session. Failure cleanup stops only resources created by that invocation.
- **CTRL-066** Start/resume MUST refuse a live legacy coordinator PID and, when
  the named Herdr coordinator is absent, any coordinator runtime whose cwd is
  exactly this repository. Detection is read-only and names the processes.
- **CTRL-067** `GOAL.md` MUST contain the canonical coordinator prompt and
  nothing else. The documented `README.md` invocation MUST deliver its whole
  text through the goal runner; shortening it to a pointer is invalid.
  `goal/EXECUTION.md` may define procedure but MUST NOT be embedded into or
  replace the prompt. Start and resume MUST submit the same canonical invocation.

### 14.8 Cross-document integrity

- **CTRL-070** CI MUST lint that derived documents do not contradict this file,
  every cited stable alias exists, question status is consistent, caps and
  schemas agree, claimed files exist, and generated projections match the store.
- **CTRL-071** Every findings archive used by a run MUST have one disposition
  row per finding with status and evidence before readiness can pass.
- **CTRL-072** Volatile delivery state MUST be published as generated snapshots;
  it MUST NOT weaken protection of the plan of record.
- **CTRL-073** The coordinator MUST delegate every normative `SPEC.md` edit to
  a fresh contract subagent. That subagent MUST update the affected requirement
  and synchronize any contradictory procedure, graph pointer, or non-normative
  elaboration; the coordinator then commits and pushes the coherent set. The
  coordinator MUST NOT directly edit the specification or commit a known
  cross-document contradiction.

## 15. Final acceptance matrix

- **ACC-000** This matrix is the exhaustive semantic acceptance oracle. Each
  row MUST be owned by the named product component and proved by the listed
  concrete Roadmap task bundles. The Roadmap selects and orders producers; it
  cannot weaken any assertion in this matrix. A producer MUST record its executable verifier
  and proof only in the proof-plane locations permitted by **CTRL-007** and
  **CTRL-029**: `tasks/<id>/expected-evidence.toml`, `verify.sh`,
  `verify.container.out`, `verify.out`, `evidence.json`, `refs/`, and permitted
  text evidence. Shared fixtures and tools MAY live in `tests/` and `tools/`,
  but their result bytes MUST be captured by the owning task bundle.

  Every row requires positive (`P`), negative (`N`), and injected-fault (`F`)
  proof. Proof is fresh only when its bundle hash matches the locked bundle,
  every integrated SHA identifies the pushed integration head tested by the
  verifier, the proof-plane commit named by **CTRL-033** contains the exact
  artifact bytes and remains pushed, the verifier is rerunnable and ends in
  `status: DONE`, and live observations identify the tested service, account,
  host, and capture time.
  Browser media MUST be attached to the owning Linear issue and represented by
  a text reference or JSON record in the task bundle. A missing assertion
  class, stale source, unverifiable live identity, absent allowed artifact, or
  invalid evidence manifest fails that criterion.

| ID | Owner repository / component | Roadmap proof producers | Required P / N / F acceptance | Allowed and fresh evidence |
| --- | --- | --- | --- | --- |
| **ACC-001** | `jackin-project/jackin` / Linear adapter and ecosystem mirror | M1-07, M1-09 through M1-12, M2-05, M2-07 | P: exact app, callback, token, JACKIN team/project/milestones, issue mirror, required labels, workflow defaults, assignment trigger, and four permitted backfills work. N: absent webhook, invalid or missing labels, M1 issue, and pre-delegation mirror launch nothing. F: rate limit and stale mirror-map replay remain bounded and idempotent. | Owning task verifiers, GraphQL/text snapshots, mirror-map bytes, webhook/token transcripts, and Linear browser references captured in the producing attempt. |
| **ACC-002** | `jackin-project/jackin` / manager Linear poller | M2-02 through M2-04, M2-07 | P: one aliased paginated request per tick, app-user session filtering, ten-second acknowledgement, watermarks, and sole-manager polling work. N: workers and webhooks never decide correctness. F: HTTP-400 `RATELIMITED` pauses until reset and ordered writes resume without consuming an attempt. | Owning task verifiers plus request, fake-clock, watermark, and event transcripts tied to tested adapter SHA and live workspace identity where used. |
| **ACC-003** | `jackin-project/jackin` / launch, capsule, daemon, and remote APIs | M3-01, M4-01 through M4-05, M10-01, M12-01 | P: interactive CLI compatibility, resolved non-TTY launch, six-runtime attach/prompt/event/exec/blocked behavior, and remote schemas work. N: prompt residue, observer mutation, and remote-to-local fallback are rejected. F: post-ready prompt, timeout, and unreachable peer return explicit outcomes. | Owning task verifiers, binary/version text, runtime labels, protocol transcripts, and live runtime-matrix outputs tied to tested binary and source SHAs. |
| **ACC-004** | `jackin-project/jackin` / scheduler and manager/worker ledgers | M3-05, M5-01, M6-05, M7-02, M12-02 | P: exact runnable predicate, order, caps, lanes, fallbacks, legal states, distinct monotonic counters, tuple replay, and merge serialization work. N: no unsupported product-global lease, CAS, fence, or second bound tuple exists. F: busy, quota, partition, delayed response, and manager failover wait or fail closed without duplicate effects. | Owning task verifiers plus deterministic fake-clock, provider, backend, ledger, and concurrency traces bound to integrated SHA. |
| **ACC-005** | `jackin-project/jackin` / checklist and plan projection | M6-01 through M6-03 | P: first-list extraction, mandatory delegated research/implementation/fresh verification, one tick/event, fresh read-modify-write, and plan replacement work. N: unrelated human edits and unchanged items survive without writes. F: conflicting edit aborts and replay remains idempotent. | Owning task verifiers, checklist fixtures, delegate records, and write logs captured under current bundle and integrated SHA. |
| **ACC-006** | `jackin-project/jackin` / verifier, retry, fallback, and diagnostics | M7-01 through M7-04 | P: locked verifier provenance, exact final line/evidence, continuation cap, retry budget, stall timer, exact lane fallback chains, fresh diagnostics, and one exhaustion elicitation work. N: quota and continuation do not consume retry budget; unverifiable agent-written verifier cannot pass. F: exit, timeout, stall, verification, quota, and throttle faults select the specified retry, fallback, wait, or exhaustion outcome. | Owning task verifiers plus fake-clock, attempt-ledger, diagnostic-subagent, and verifier-stream evidence bound to the attempt and tested SHA. |
| **ACC-007** | `jackin-project/jackin` / capsule guidance and Linear escalation | M4-06, M7-03, M7-04 | P: elicitation/reply and host guidance reach the same PTY with complete activity; stop releases resources; safe follow-up is linked and unassigned. N: no implicit auto-delegation occurs. F: duplicate reply and stop are replay-safe. | Owning task verifiers plus live PTY/session/activity records identifying issue, run, capsule, host, and capture time. |
| **ACC-008** | `jackin-project/jackin` / GitHub adapter and release validator | M8-01 through M8-04, M9-01 through M9-03, M11-01a | P: both `repository_selection=all` installations, scoped tokens, idempotent scratch branch/PR/link, authorized green merge, confirmation, cleanup, preview-main, and all-role validation work. N: non-scratch destructive targets, failed checks, unauthorized merge, and cross-organization installation are refused. F: retry after ambiguous PR or merge reads and reconciles before mutation. | Owning task verifiers, GitHub API/text records, scratch PR/check/merge evidence, preview validator output, and browser references captured against live installations. |
| **ACC-009** | `jackin-project/jackin` / reconciliation and multi-host placement | M3-07, M12-01 through M12-04 | P: restart adoption by exact tuple, persisted counters/watermarks, least-load and prior-host selection, and saturation wait work. N: mismatched or unlabeled containers are quarantined; ledger state alone never revives work. F: pre-effect loss may re-place, post-effect loss uses a new ordinal, and unknown partition waits without duplication. | Owning task verifiers plus two-host chaos transcripts, ledgers, container inventories, and effect logs tied to host identities and tested daemon SHAs. |
| **ACC-010** | `tailrocks/termrock` and `jackin-project/jackin` / fleet observability | M5-02 through M5-06, M10-01 through M10-06 | P: complete side-effect-free snapshot/detail/event/evidence, heartbeat timeline, distinct waiting/blocked/stuck, host-loop drain, TerminalPane behavior, fleet rows, and one-action attach work. N: absent console and empty source do not alter execution or redraw. F: control characters, secret canaries, dropped peers, and attachment failures remain redacted and explicit. | Owning task verifiers, forty-minute live timeline, host-blessed golden text, performance output, and attach transcripts tied to source and service identity. |
| **ACC-011** | `jackin-project/jackin` plus `donbeave/jackin-crew-builder`, `donbeave/jackin-crew-operator`, and `donbeave/jackin-crew-reviewer` / credential and trust boundary | M1-03, M1-05b through M1-05d, M1-06, M1-07, M1-10, M8-01, M11-01, M11-03 | P: exact 1Password items/fields, manager-only Linear mint, allowed secret stores, stdin/binding flow, role/network/mount separation, and immutable supply refs work. N: worker role/reviewer tokens, forbidden files, cross-organization App use, and broader yolo grants are rejected. F: canaries, rotation, malicious input, gitleaks hit, and unsafe browser profile fail safely. | Owning task verifiers, redacted inspections/scans, threat fixtures, rotation results, and live service-account tests; no secret value may appear in proof. |
| **ACC-012** | `donbeave/jackin-role-template`, `donbeave/jackin-crew-builder`, `donbeave/jackin-crew-operator`, `donbeave/jackin-crew-reviewer`, and `jackin-project/jackin` / roles and deployment | M1-04a, M1-05a through M1-05d, M3-02, M3-02a, M11-01a through M11-03 | P: exact role matrix, tools, hooks, grants, `v1alpha7` defaults, public signed multi-architecture images, local/server/multi-host profiles, and locked tool versions work. N: forbidden tools, credentials, and grants are rejected without mutation. F: restart, remote loss, and unsafe profile handling preserve workspaces and credential boundaries. | Owning task verifiers, manifests, image attestations, CI output, and live smoke records tied to immutable image/source identities. |
| **ACC-013** | `tailrocks/ecosystem` / locked bundles and Linear issue mirror | M1-01, M1-12 | P: all 81 generated bundles match the graph and lock, and M1-12 creates the exact locked-source issue mirror including four early-task backfills. N: missing or drifted bundles, duplicate issues, wrong source commits, preset delegates, and mismatched labels, states, blockers, or attachments fail verification. F: mirror rerun reconciles existing issues idempotently without creating another issue or rerunning an early task. | M1-01 and M1-12 verifiers, M1-12 issue-map JSON evidence, GraphQL/text snapshots, and permitted task evidence bound to `plan.commit`. |
| **ACC-014** | `tailrocks/ecosystem` / repository integration and task evidence | Every Roadmap implementation task that touches a repository, plus M1-01 proof-plane conformance | P: per-task worktrees, one integrator lease, integrated-SHA verification, expected-evidence closure, atomic evidence, DCO/pushed ancestry, and durable epochs work. N: worker-tip, stale lease, secret hit, unpushed or dirty tree, and agent-cleared exhaustion cannot pass. F: parallel integration, verifier failure, replacement crash, and stale external proof mutation fail closed or recover. | Each owning task's allowed verifier/evidence files plus repository ancestry, state events, evidence manifests, and text fault logs tied to current bundle and integrated SHA. |
| **ACC-018** | `jackin-project/jackin`, `tailrocks/termrock`, all four `donbeave/jackin-*` role repositories, and `tailrocks/ecosystem` / end-to-end managed execution | M4-06, M5-06, M6-03, M7-04, M8-03, M9-02, M10-05, M11-04, M12-03 | P: one local and one server issue each complete assignment, attachable agent, verified checklist, and linked PR while two hosts run two issues concurrently. N: no observer, webhook, foreground CLI, or human review is required for correctness. F: one-host failure causes no duplicate run/effect and recovery preserves exact state and evidence. | Owning task verifiers plus live issue/session/container/PR/two-host timeline, source identities, and milestone browser references captured by crew-operator. |

  The product MUST be accepted only when **ACC-001** through **ACC-014** and
  **ACC-018** all have fresh, valid proof and the root `verify.sh` confirms
  every owning task and repository under **CTRL-049** through **CTRL-053**. Milestone state, task
  prose, review opinion, screenshots alone, or any model claim MUST NOT
  substitute for semantic proof.

# Stable reference aliases

This non-normative index resolves derived-document citations to current
requirement IDs. It adds no behavior.

## D-001
PRD-014; CTRL-007; CTRL-023; CTRL-029.
## D-002
PRD-001..PRD-006.
## D-003
EXEC-020..EXEC-025; EXEC-030..EXEC-035; CTRL-001.
## D-004
PRD-003; ISSUE-010; SCHED-000..SCHED-002; SCHED-005..SCHED-007; SCHED-010..SCHED-014.
## D-005
EXEC-001..EXEC-006; OBS-001..OBS-005.
## D-006
OBS-006..OBS-010.
## D-007
EXEC-021; EXEC-025; CTRL-008.
## D-008
ARCH-001; ARCH-010..ARCH-023; REC-001..REC-005; REC-010..REC-014.
## D-009
PRD-011; ARCH-010.
## D-010
AUTH-001; ISSUE-001..ISSUE-006; ISSUE-010..ISSUE-015; ISSUE-019..ISSUE-023.
## D-011
ISSUE-010.
## D-012
ISSUE-005; ISSUE-010..ISSUE-014; EXEC-012.
## D-013
EXEC-020..EXEC-024.
## D-014
ISSUE-005; ISSUE-019..ISSUE-023; EXEC-060..EXEC-064.
## D-015
PRD-010; ISSUE-005; ARCH-018.
## D-016
ARCH-012..ARCH-015; OBS-006.
## D-017
DEP-001; REC-014.
## D-018
ISSUE-019..ISSUE-023.
## D-019
SCHED-020..SCHED-024; REC-001..REC-005.
## D-020
SCHED-000; STATE-000..STATE-005.
## D-021
STATE-004; EXEC-040..EXEC-047.
## D-022
SCHED-005..SCHED-007; SCHED-010..SCHED-014.
## D-023
AUTH-001..AUTH-003; SEC-001..SEC-005.
## D-024
ARCH-012..ARCH-019.
## D-025
ARCH-020..ARCH-023; OBS-006..OBS-010.
## D-026
REC-010..REC-014; DEP-003.
## D-027
EXEC-041..EXEC-047.
## D-028
EXEC-052.
## D-029
EXEC-046; EXEC-050.
## D-030
EXEC-021; EXEC-030..EXEC-035.
## D-031
EXEC-062..EXEC-064.
## D-032
ROLE-018; SEC-005.
## D-033
PRD-005; CTRL-049..CTRL-053; ACC-018.
## D-034
DEP-001; DEP-012; DEP-013; DEP-028.
## D-035
SEC-001..SEC-005; SEC-009..SEC-016.
## D-036
EXEC-025; CTRL-008.
## D-037
ACC-000.
## D-038
CTRL-001; CTRL-029..CTRL-034.
## D-039
SCHED-005..SCHED-007; SCHED-010..SCHED-014; ROLE-002.
## D-040
ISSUE-004; ISSUE-006; SCHED-000.
## D-041
PRD-001..PRD-006; ACC-018.
## D-042
DEP-028.
## D-043
ISSUE-005; ISSUE-013; SCHED-006; SCHED-010; SCHED-014.
## D-044
EXEC-012; ARCH-018; ARCH-019.
## D-045
ROLE-000..ROLE-006; ROLE-010..ROLE-018.
## D-046
DEP-020.
## D-047
CTRL-020..CTRL-023.
## D-048
ROLE-017; DEP-027.
## D-049
ISSUE-015; OBS-003..OBS-005; STATE-000..STATE-005.
## D-050
CTRL-041..CTRL-043; SEC-016.
## D-051
STATE-002; STATE-003; ARCH-018.
## D-052
ISSUE-015; ARCH-016.
## D-053
PRD-030.
## D-054
CTRL-001; CTRL-002.
## D-055
DEP-022; ROLE-006; EXEC-062.
## D-056
SCHED-005.
## D-057
SCHED-007; EXEC-043..EXEC-045.
## D-058
SCHED-006; ISSUE-013.
## D-059
SEC-003; SEC-023; CTRL-007; CTRL-029.
## D-060
ISSUE-004; ISSUE-006.
## D-061
CTRL-031..CTRL-034.
## D-062
CTRL-001.
## D-063
EXEC-044..EXEC-047; CTRL-018.
## D-064
SEC-022; ROLE-005.
## D-065
SEC-023; DEP-025.
## D-066
PRD-001.
## D-067
EXEC-052.
## D-068
EXEC-050; EXEC-051.
## D-069
CTRL-049..CTRL-053; CTRL-060..CTRL-067.
## D-070
EXEC-041; EXEC-046; CTRL-042.
## D-071
SCHED-005; SCHED-007; SCHED-011; CTRL-015.
## D-072
CTRL-014; CTRL-016.
## D-073
ISSUE-006; ISSUE-010; REC-002; REC-005.
## D-074
CTRL-023; ROLE-005.
## D-075
OBS-010.
## D-076
SEC-016.
## D-077
SEC-005; ROLE-003; ROLE-013; ROLE-018.
## D-078
SCHED-014; ROLE-002; ROLE-015; ROLE-016.
## D-079
ROLE-004; ROLE-006; EXEC-062.
## D-080
ISSUE-001; ISSUE-003; SEC-009; SEC-013.
## D-081
SEC-002; SEC-003; CTRL-029..CTRL-034; OBS-002.
## D-082
EXEC-011; EXEC-013; CTRL-064.
## D-083
CTRL-049..CTRL-053; CTRL-067.
## D-084
CTRL-012; CTRL-014; CTRL-040..CTRL-042.
## D-085
ISSUE-022; CTRL-020.
## D-086
ISSUE-022; CTRL-023; CTRL-031.
## D-087
ISSUE-003; EXEC-002..EXEC-005; SEC-009; SEC-013.
## D-088
CTRL-001..CTRL-006; CTRL-014..CTRL-016.
## D-089
DEP-012; DEP-021; CTRL-034.
## D-090
DEP-001..DEP-003; SEC-012; SEC-016.
## D-091
CTRL-032..CTRL-034.
## D-092
CTRL-008; CTRL-060..CTRL-067.
## D-093
CTRL-040..CTRL-042.
## D-094
CTRL-061; CTRL-063; CTRL-067.
## D-095
CTRL-008; CTRL-061.
## D-096
CTRL-001..CTRL-006.
## D-097
CTRL-049..CTRL-053.
## D-098
CTRL-009..CTRL-019.
## D-099
CTRL-020..CTRL-023.
## D-100
SCHED-020..SCHED-024; CTRL-019.
## D-101
CTRL-001; CTRL-002.
## D-102
CTRL-071.
## D-103
PRD-030; CTRL-070.
## D-104
CTRL-073.
## D-105
CTRL-070.
## D-106
CTRL-072.
## D-107
CTRL-070; CTRL-073.
## D-108
SEC-009..SEC-016.
## D-109
CTRL-001..CTRL-006.
## D-110
CTRL-049..CTRL-053.
## D-111
CTRL-009..CTRL-013.
## D-112
CTRL-020..CTRL-023.
## D-113
CTRL-019..CTRL-023.
## D-114
CTRL-001; CTRL-002.
## D-115
CTRL-071.
## D-116
CTRL-070.
## D-117
CTRL-072.
## D-118
CTRL-007; CTRL-029.
## D-119
CTRL-006; CTRL-014..CTRL-017.
## D-120
CTRL-061; AUTH-004.
## D-121
AUTH-004; EXEC-011; SEC-020.
## D-122
DEP-023.
## D-123
CTRL-006.
## D-124
CTRL-060..CTRL-067.
