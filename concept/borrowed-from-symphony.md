# What we borrow from Symphony, section by section

Date: 2026-08-27. Source: `SPEC.md` of https://github.com/openai/symphony (Draft v1,
HEAD `8001b52`), read in full. `analysis/symphony.md` already describes the project and its Elixir
implementation; this document does not repeat that. It walks the specification section by section
and records, for each, what Symphony specifies, whether we adopt, adapt, or reject it, and which of
our contract rules (`SPEC.md`, D-NNN) and open questions (`OPEN-QUESTIONS.md`, Q-NNN) it touches.
Every claim about Symphony cites a SPEC section. A few items the prompt asked about (the
"Completion bar", the `land`/`pull` skills) are not in the SPEC; they come from the reference
`elixir/WORKFLOW.md` and `.codex/skills/` and are treated in a separate section at the end of the
walk.

> **Status (D-053, 2026-08-27): ADOPTED.** Every proposal below, D-018..D-031, is adopted as
> written by D-053, keeping its number as the reference; the question closures and
> narrowings for Q-004..Q-015 are adopted with them. The polling answer for Q-015 is the adopted
> event path. "PROPOSED" wording that survives in the walk is historical; the headings under
> "Consolidated proposals" carry the adopted status. Any item may be overridden by a later adopted
> rule recorded under the same domain-ownership policy.

Decisions D-018 onward and question closures are collected at the end; they were drafted here
before D-053 adopted them.

## Fixed differences from Symphony

Recorded as D-015 (any runtime, no harness), D-016 (capsule attach preserved), D-010/D-014 (Linear only, GitHub repo+PR), D-017 (local-first prototype).

These are decided and frame every verdict below. Where a Symphony rule conflicts with one of them,
the difference wins and the verdict is ADAPT or REJECT.

1. **Any agent runtime, not Codex only.** We run Claude Code, Codex, Amp, Kimi, OpenCode, and Grok.
   We never build a harness; we build the ecosystem around existing harnesses. Symphony's §3.3 and
   §10 are written against the Codex app-server protocol; nothing we take depends on that protocol.
2. **We talk to agents through jackin and jackin agent roles.** A role is a Dockerfile plus
   `jackin.role.toml` carrying environment, skills, and plugins. There is no per-agent RPC channel
   from the manager to the harness; the role fixes the environment and the prompt fixes the work.
3. **Every agent runs inside a jackin container, and a human can attach to it.** jackin's capsule
   (the in-container PID 1) lets a human `hardline` into a specific container and watch the live
   session: the exact prompt passed, what the agent is doing. This visibility is critical and comes
   from jackin out of the box. The manager must preserve it; it never runs agents headless in a way
   that kills attach.
4. **Task source is Linear only** (agent app installed with `app:assignable`). GitHub is the
   repository host and the pull-request carrier, nothing else. The issue defines role, runtime,
   prompt, checklist, repository, branch, and base branch (D-012, D-013, D-014).

Verdict vocabulary: **ADOPT** means take the rule as written. **ADAPT** means take the idea, and the
text says how it changes under the four differences. **REJECT** means we do not take it, with the
reason.

## The walk

### §1 Problem Statement

**Symphony.** A long-running service reads work from a tracker, creates an isolated workspace per
issue, and runs a coding-agent session inside it. Four operational problems: daemon workflow instead
of scripts; per-issue isolation; policy in-repo (`WORKFLOW.md`); observability for concurrent runs.
The "important boundary": Symphony is "a scheduler/runner and tracker reader"; ticket writes are
"typically performed by the coding agent through provider-native tools executed by Symphony with the
configured tracker credential"; a successful run "can end at a workflow-defined handoff state (for
example `Human Review`), not necessarily `Done`".

**Verdict: ADAPT.** The four problems are ours verbatim (VISION.md "The target"). Two boundary
points change. First, the agent does not write the tracker; D-013 already makes the daemon the
single Linear writer (read once, write on checklist progress), so the "agent writes tickets through
host-executed tools" pattern becomes "daemon writes; agent edits a local file". Second, we adopt the
handoff-state idea fully: a successful run ends with a pull request and the issue in a review state,
not `Done` (see §7 and §11.5 below for the concrete states).

**Touches.** D-010, D-013, D-014. Feeds Q-007 (who merges) and Q-009 (what a handoff to a human
looks like).

### §2 Goals and Non-Goals

**Symphony.** Goals (§2.1): fixed-cadence polling with bounded concurrency; one authoritative
orchestrator state; deterministic per-issue workspaces preserved across runs; stop runs when the
issue becomes ineligible; exponential backoff; repo-owned `WORKFLOW.md`; structured logs; restart
recovery from tracker and filesystem "without requiring a persistent database; exact in-memory
scheduler state is not restored". Non-goals (§2.2): rich web UI, multi-tenant control plane,
general workflow engine, built-in ticket/PR business logic, mandated sandbox beyond what the agent
and host OS provide.

**Verdict: ADOPT the goals, ADAPT two non-goals.** All eight goals map onto D-005, D-008, D-010,
and D-014. The non-goal "no sandbox beyond agent and host OS" is where we are strictly stronger:
isolation is a jackin container per run (difference 3), so we drop that non-goal rather than inherit
it. The non-goal "no persistent database" we soften: the tracker stays authoritative (D-010) but the
daemon keeps a local, non-authoritative run ledger so attempt counts and blocked state survive a
restart (Symphony loses both, §14.3; `analysis/symphony.md` §11 lists this as a limitation). A UI is
not a goal of the daemon; it is a goal of the manager's termrock interface (D-006), which reads a
snapshot (§13.4 below).

**Touches.** D-008, D-010. Proposed D-019 (ledger).

### §3 System Overview

**Symphony.** §3.1 names eight components: Workflow Loader, Config Layer, Issue Tracker Adapter,
Orchestrator, Workspace Manager, Agent Runner, optional Status Surface, Logging. §3.2 orders them in
six layers (policy, configuration, coordination, execution, integration, observability). §3.3 lists
external dependencies: one tracker API, local filesystem, optional VCS tooling, a coding-agent
executable "that supports the targeted Codex app-server mode", and host authentication whose
tracker secrets "SHOULD NOT be inherited by the coding-agent child process".

**Verdict: ADOPT the component split and layering; REJECT the Codex dependency.** The split is a
good decomposition for the manager and matches `concept/manager.md` "Division of labor". Mapping:
Workflow Loader and Config Layer become the repo workflow file reader (§5); the Tracker Adapter is
the Linear adapter (single, D-010); the Orchestrator is the manager's scheduler; the Workspace
Manager is the daemon's git preparation (D-014) plus jackin mount isolation; the Agent Runner is
"start a jackin role with a prompt" (difference 2); Status Surface is the termrock TUI; Logging is
structured logs plus OTLP that jackin already emits (`analysis/jackin.md` §3.9). The dependency on a
Codex app-server executable is replaced by a dependency on a jackin daemon on each host (D-008). The
secret-inheritance rule is adopted (see §15.3).

**Touches.** D-002, D-008, D-009, Q-001.

### §4 Core Domain Model

**Symphony.** §4.1.1 defines the normalized `Issue`: opaque `id`, optional `native_ref`, unique
human `identifier` (names the workspace), `title`, `description`, `priority`, `state`,
`branch_name`, `url`, `assignee_id`, lowercase `labels`, best-effort `blocked_by`, and a REQUIRED
adapter-derived `dispatchable` boolean "for provider-specific rules that the generic scheduler
cannot infer safely, such as assignment, board membership, or blocker semantics". §4.1.4-4.1.8
define Workspace (`path`, `workspace_key`, `created_now`), Run Attempt (`attempt` null on first run,
`>=1` afterwards), Live Session (session id, last event, last timestamp, token counters,
`turn_count`), Retry Entry (`attempt`, `due_at_ms`, `error`), and the single in-memory Orchestrator
Runtime State (`running`, `claimed`, `retry_attempts`, `completed`, totals). §4.2 fixes
normalization: workspace key from `identifier` by replacing characters outside `[A-Za-z0-9._-]`
with `_` plus a 64-bit hash suffix when sanitization changed anything; states compared trimmed and
lowercased; session id `<thread_id>-<turn_id>`.

**Verdict: ADOPT the entities and normalization; ADAPT `Issue` fields.** The `Issue` model gains
our required fields: `role`, `runtime`, `repository`, `branch`, `base_branch`, `checklist` (D-012,
D-013, D-014). `dispatchable` stays as the one boolean the scheduler trusts, and it is where D-011
(delegated to jackin), Q-004 (no open blocker), and field validation (D-012) are folded in.
`workspace_key` is derived from the Linear identifier exactly as §4.2 says. Live Session is
redefined around jackin: `instance_id`, `container`, `host`, capsule session id, capsule agent state
(`Working | Blocked | Done | Idle | Unknown`, `analysis/jackin.md` §6), last status timestamp, and
usage from the jackin usage broker rather than Codex token events. Run Attempt gains a `kind`
(`first | retry | continuation | rework | merge`) because §12.3 admits the core `attempt` cannot
tell a continuation from a failure retry.

**Touches.** D-011, D-012, D-013, D-014. Q-004 (dispatchable folds blockers). Proposed D-020.

### §5 Workflow Specification (`WORKFLOW.md`)

**Symphony.** §5.1: the file is found by explicit path or `./WORKFLOW.md`, "expected to be
repository-owned and version-controlled". §5.2: Markdown with optional YAML front matter; body is
the prompt template. §5.3: top-level keys `tracker`, `polling`, `workspace`, `hooks`, `agent`,
`codex`; unknown keys ignored. §5.3.1 `tracker.kind`, `provider`, `required_labels`,
`active_states`, `terminal_states`. §5.3.2 `polling.interval_ms` (30 s). §5.3.3 `workspace.root`.
§5.3.4 hooks `after_create`, `before_run`, `after_run`, `before_remove`, `timeout_ms` (60 s).
§5.3.5 `agent.max_concurrent_agents` (10), `max_turns` (20), `max_retry_backoff_ms` (5 min),
`max_concurrent_agents_by_state`. §5.3.6 `codex.*` pass-through. §5.4: the body is a strict Liquid
template with `issue` and `attempt`; unknown variables fail rendering. §5.5: file read/YAML errors
block new dispatches; template errors fail only the affected attempt.

**Verdict: ADAPT into a repository workflow file, with a different split of what lives where.**
The strong idea is policy-as-code in the repository, versioned with the code. In our model most of
Symphony's front matter already has a home: tracker config belongs to the daemon (one Linear
installation, D-010); the agent environment belongs to the role (`jackin.role.toml`, difference 2);
the prompt belongs to the issue (D-012). What has no home today and genuinely belongs to the
repository is: workspace bootstrap and teardown (Symphony's hooks), the verification command
(Q-014), per-repository concurrency caps, a default role and runtime when the issue omits them, and
a standing prompt frame ("how this repository wants managed work done": branch conventions, the
completion bar, what may not be escalated). Proposal, D-018: `.jackin/workflow.toml` in the
repository, read from the base branch at dispatch time, plus an optional `.jackin/WORKFLOW.md`
prompt frame rendered around the issue's prompt. TOML rather than YAML front matter because every
other file in the ecosystem (`jackin.role.toml`, `task.toml`) is TOML. Symphony's `required_labels`
gate is kept as a daemon-level setting (an issue must carry the daemon's required labels to be
dispatched), not per repository. Strict templating with `issue` and `attempt` is adopted for the
prompt frame (§12). Template errors fail only the attempt (§5.5) is adopted verbatim; a broken
workflow file is a workspace-class failure reported on the issue (§14.1).

**Touches.** D-012, D-013, D-014, Q-013, Q-014. Proposed D-018.

### §6 Configuration

**Symphony.** §6.1 resolution pipeline: select file, parse, apply defaults, resolve `$VAR` only
where a value explicitly references it, coerce and validate; relative `workspace.root` resolves
against the file's directory. §6.2 dynamic reload is REQUIRED: detect `WORKFLOW.md` changes,
re-read and re-apply without restart for future dispatch, retries, reconciliation, hooks, and
launches; in-flight sessions need not restart; invalid reloads keep the last known good
configuration and emit an operator-visible error; re-validate defensively before dispatch. §6.3
preflight validation at startup (fail startup) and per tick (skip dispatch, keep reconciliation).

**Verdict: ADOPT the semantics; ADAPT the mechanism.** Because our workflow file lives in the
repository and is read from the base branch at each dispatch (D-018), "hot reload" is automatic:
every new attempt sees the file as committed, and no file watcher exists. In-flight attempts keep
the snapshot they started with (§10.5's "bound to one session snapshot" rule, adopted). Daemon-level
config (Linear credentials, host caps, workspace root, required labels) is jackin config and follows
jackin's existing `$VAR` / `op://` resolution (`analysis/jackin.md` §3.5), which is a superset of
§6.1. Last-known-good on invalid reload and per-tick preflight are adopted as written: a repository
whose `.jackin/workflow.toml` fails validation gets its issues held with a comment, and the rest of
the fleet keeps running.

**Touches.** D-009 (jackin config unchanged, daemon config additive). Proposed D-018.

### §7 Orchestration State Machine

**Symphony.** §7.1: internal claim states `Unclaimed`, `Claimed`, `Running`, `RetryQueued`,
`Released`, explicitly distinct from tracker states. The nuance: "A successful worker exit does not
mean the issue is done forever." While the issue is active the worker loops turns on the same thread
up to `max_turns`; the first turn gets the full prompt, continuation turns get "only continuation
guidance"; after a normal exit a 1 s continuation retry re-checks the tracker. §7.2 run-attempt
phases from `PreparingWorkspace` through `Succeeded | Failed | TimedOut | Stalled |
CanceledByReconciliation`, with "distinct terminal reasons" because retry and logs differ. §7.3
triggers: poll tick, normal exit, abnormal exit, agent event, retry timer, reconciliation refresh,
stall timeout. §7.4: one mutation authority; `claimed` and `running` checked before any launch;
reconciliation before dispatch every tick; restart recovery from tracker and filesystem.

**Verdict: ADOPT the claim states, phases, triggers, and idempotency rules; ADAPT the turn loop.**
The claim state machine and the "one authority mutates" rule go into the manager as written; the
Elixir implementation's extra `blocked` state (`analysis/symphony.md` §4) is adopted as a sixth
state and, unlike Symphony, persisted (D-019). The turn loop changes because we drive agents through
a PTY, not through a turn API: a jackin session is one long interactive run, so "continue on the
same thread" means "the session is still alive and the daemon sends continuation guidance into the
PTY", and "worker exit" means the agent process exited. Continuation retry after a clean exit is
adopted: on exit the daemon re-reads the issue; if it is still dispatchable and the checklist is not
complete, it starts a new attempt of kind `continuation` in the same workspace. `max_turns` becomes
`max_continuations` per issue. The phase vocabulary is adopted and extended with `Verifying`
(D-003 runs a verification after the checklist completes, §14 and Q-014).

**Touches.** D-003, D-008, D-013. Q-008. Proposed D-019, D-020, D-021.

### §8 Polling, Scheduling, and Reconciliation

**Symphony.** §8.1 tick: reconcile running issues, preflight validate, fetch candidates in active
states, sort, dispatch while slots remain, notify observers. §8.2 eligibility: required fields;
state in active and not terminal; `dispatchable`; required labels; not running; not claimed; global
and per-state slots; sort by `priority` 1..4, then oldest `created_at`, then identifier. §8.3
concurrency: `available_slots = max(max_concurrent_agents - running_count, 0)`, per-state map
overrides. §8.4 retry: cancel existing timer; continuation delay 1000 ms; failure delay
`min(10000 * 2^(attempt-1), max_retry_backoff_ms)`; on timer, refresh the issue by id and release,
clean, requeue, or dispatch accordingly. §8.5 reconciliation: stall detection (no event for
`stall_timeout_ms` kills the worker and queues a retry) and tracker refresh (terminal: kill and clean
workspace; active and routable: update snapshot; active but unroutable, or neither: kill without
cleanup; refresh failure: keep workers). §8.6 startup sweep deletes workspaces of terminal issues.

**Verdict: ADOPT nearly verbatim; ADAPT the inputs.** This is the heart of what we borrow. The tick
order (reconcile first, then dispatch), the eligibility list, the sort, the slot arithmetic, the
backoff formula, the retry-timer refresh, and the reconciliation table are adopted as the manager's
loop. Adaptations: (a) "active states" become a Linear predicate: `delegate == jackin` and
`state.type in {unstarted, started}` and the state is not the repository's configured review state;
"terminal" is `state.type in {completed, canceled}`; anything else (triage, backlog, delegate
removed) is "non-active", which stops the run without cleanup exactly as §8.5 says. (b) Stall
detection uses the capsule's agent-status stream (last transition timestamp) rather than Codex
events; an `Idle` or `Blocked` state for longer than the stall timeout is the trigger, and `Blocked`
routes to escalation (Q-009) rather than a blind retry. (c) Retries are bounded (D-021): Symphony
has no attempt cap (`analysis/symphony.md` §6), which is a known token sink; after `max_attempts`
the issue enters `blocked` with a blocker brief. (d) Per-state caps are adopted and extended to
per-role and per-provider-account caps (Q-010). (e) The startup sweep is adopted; because our
workspaces are git checkouts under the daemon's workspace root and containers are labeled with the
issue identifier, the sweep also ejects orphaned containers (D-008 reconciliation).

**Touches.** D-004, D-005, D-008, D-010, D-011. Q-004, Q-008, Q-010, Q-015. Proposed D-019, D-021,
D-022.

### §9 Workspace Management and Safety

**Symphony.** §9.1: `<workspace.root>/<workspace_key>`; "Workspaces are reused across runs for the
same issue. Successful runs do not auto-delete workspaces." §9.2: derive key, ensure directory,
`created_now` gates `after_create`. §9.3: population (clone, deps) is implementation-defined and
typically done by hooks; reused workspaces "SHOULD NOT be destructively reset on population failure".
§9.4 hooks run `sh -lc` in the workspace with a 60 s timeout; `after_create` and `before_run`
failures are fatal to creation/attempt, `after_run` and `before_remove` failures are logged. §9.5
three invariants: agent cwd equals the workspace path; workspace path stays under the root; key is
sanitized.

**Verdict: ADOPT the layout, reuse policy, and invariants; ADAPT hooks and population.** Layout and
key derivation are adopted. Reuse across attempts is adopted, and this deliberately supersedes the
lean in `analysis/symphony.md` §10 (Q-008 row) toward a fresh container per attempt: D-014 already
reuses the branch, uncommitted work between attempts is exactly what a retry should resume from, and
jackin containers persist after exit anyway (`analysis/jackin.md` §3.2). The rule becomes: one
attempt equals one container session; the workspace directory (clone or worktree under the daemon's
root, on the issue's branch) persists across attempts and is removed only on terminal state. The
container image is rebuilt only when the role or runtime on the issue changed. Population is not a
hook: D-014 specifies it (fetch, reuse or create branch from base). Hooks are adopted as
`.jackin/workflow.toml` `[hooks]` with Symphony's four names and semantics, but they run *inside the
container* via the daemon's exec-with-result path, not on the host with the daemon's privileges;
§15.4's "hooks are fully trusted configuration" therefore becomes "hooks are repository code and run
with the agent's container privileges", which is the correct trust level for us. Invariant 1 (cwd is
the workspace) is enforced by the mount, invariant 2 by the daemon, invariant 3 by the key rule.

**Touches.** D-008, D-014. Q-008 (workspace reuse). Proposed D-018 (hooks), D-021 (reuse).

### §10 Agent Runner Protocol

**Symphony.** The section binds Symphony to the Codex app-server: §10.1 launch `bash -lc
<codex.command>` in the workspace; §10.2 session startup (initialize, start thread with cwd, first
turn with the rendered prompt, continuation turns with guidance, titles, advertised client tools);
§10.3 streaming and completion signals; §10.4 emitted events (`session_started`, `turn_completed`,
`turn_input_required`, `approval_auto_approved`, `unsupported_tool_call`, ...); §10.5 approval and
user-input policy is implementation-defined but "MUST NOT leave a run stalled indefinitely";
provider-native tracker tools are executed host-side, bound to one session snapshot, with tracker
secrets scrubbed from the child environment; §10.6 timeouts (`read`, `turn` silence, `stall`) and
error categories; §10.7 the runner contract (create workspace, build prompt, start session,
forward events, fail on any error).

**Verdict: REJECT the protocol; ADAPT the responsibilities.** Differences 1-3 make the app-server
binding inapplicable, and we do not replace it with another RPC to the harness. What survives is
the list of responsibilities, remapped onto jackin: launch is "start a jackin instance of role R
with runtime A, mounts for the workspace, and the rendered prompt delivered into the session"
(D-012); the "first turn" is the prompt injected at start, "continuation guidance" is text the daemon
sends into the PTY; events come from the capsule agent-status arbitration and exit codes; timeouts
map to `stall_timeout` on status inactivity and a per-attempt wall-clock cap (the `limits.minutes`
already sketched in `concept/task-format.md`). §10.5 is adopted in spirit: an agent that reaches
`Blocked` (waiting for input) never stalls forever; the daemon converts it into an escalation
(Q-009) with a deadline after which the attempt fails. The credential rule ("child never reads raw
tracker tokens") is adopted as D-023. Crucially, the runner never uses a harness's print or exec
mode (`claude -p`, `codex exec`): the session runs on the capsule PTY so a human can `hardline` in
and see the exact prompt and live activity (difference 3, proposed D-024). Approvals are moot: jackin
already runs every agent with permission bypass and moves safety to the container
(`analysis/jackin.md` §3.7).

**Touches.** D-008, D-009, D-012. Q-008, Q-009. Proposed D-023, D-024. Large jackin gap list
(see the end).

### §11 Issue Tracker Integration Contract

**Symphony.** §11.1 exactly two REQUIRED reads: `fetch_issues_by_states` (with scope and
pagination; include `dispatchable=false` issues because the scheduler owns that filter) and
`fetch_issues_by_ids` (full snapshots for reconciliation; omission means "no longer visible";
malformed requested records fail the call rather than vanish). §11.2 the adapter owns auth,
scope, normalization, `dispatchable`, and must publish a documented profile; the orchestrator "MUST
NOT inspect provider payloads". §11.3 normalization rules (non-empty required fields, lowercase
labels, priority integer, RFC 3339 timestamps, `blocked_by` best-effort, `dispatchable` explicit).
§11.4 error categories; candidate-fetch failure skips the tick, refresh failure keeps workers.
§11.5 "Symphony does not require first-class tracker write APIs in the orchestrator"; mutations are
done by the agent through tools; success "often means reached the next handoff state".

**Verdict: ADOPT the read kernel and normalization; REJECT the write boundary.** The two reads are
exactly right for Linear: `issues(filter: {delegate: {id: {eq: appUserId}}, state: {type: {in:
[...]}}})` and `issues(filter: {id: {in: [...]}})` with the field set in `analysis/linear-agents.md`
C5. The "orchestrator never inspects provider payloads" rule keeps Linear specifics (label groups,
`inverseRelations`, workflow-state types) inside the adapter. The write boundary is rejected because
D-013 decided that the daemon writes the tracker (checklist progress, PR link, completion,
elicitations) and the agent edits a local file. This is the safer of the two designs for
credentials (§15.3) and keeps rate-limit exposure in one place. The adapter therefore also has a
small write surface: `ack_session`, `update_plan`, `tick_checklist_item`, `set_state`,
`add_external_url`, `elicit`, `respond`, `error`. The single-adapter reality (D-010) means the
"publish a profile" requirement collapses into one document: the Linear adapter profile, which
`analysis/linear-agents.md` Parts A and C already largely are.

**Touches.** D-010, D-013. Q-004 (blocker semantics live in the adapter's `dispatchable`).
Proposed D-020, D-023.

### §12 Prompt Construction and Context Assembly

**Symphony.** §12.1 inputs: template, normalized `issue`, optional `attempt`. §12.2 strict
rendering; nested arrays preserved for iteration. §12.3 `attempt` is a 1-based count on retries and
continuations, null on the first run; a `retry_kind` field is an optional extension. §12.4 a render
failure fails the attempt and the orchestrator retries.

**Verdict: ADAPT.** The issue prompt is the issue description (D-012, Q-013 proposal), so the
template is the repository's prompt frame (D-018) rendered with `issue` (all normalized fields
including checklist, blockers, repository, branch), `attempt`, `attempt_kind` (the `retry_kind`
extension, made mandatory), `last_error` (the previous attempt's terminal reason, absent on first
run), and `checklist_path` (the local mirror the agent updates through `/goal`, D-013). The frame's
job is the Symphony reference prompt's job: say how to route on state, what the completion bar is,
and what "resume from workspace state" means on a retry. Rendering strictness and "render failure
fails only this attempt" are adopted.

**Touches.** D-012, D-013, Q-013. Proposed D-018.

### §13 Logging, Status, and Observability

**Symphony.** §13.1 every issue-related log carries `issue_id` and `issue_identifier`, session logs
carry `session_id`; stable `key=value` phrasing. §13.2 sinks are free; sink failure must not stop the
service. §13.3 a snapshot with `running` rows (including `turn_count` and issue URL), `retrying`
rows, totals, rate limits, and `timeout | unavailable` error modes. §13.4 a human-readable status
surface "SHOULD draw from orchestrator state/metrics only and MUST NOT be REQUIRED for correctness".
§13.5 token accounting prefers absolute totals over deltas. §13.6 humanized summaries are
observability-only. §13.7 optional HTTP: `GET /api/v1/state`, `GET /api/v1/<issue_identifier>`,
`POST /api/v1/refresh`; loopback bind by default; "MUST NOT become REQUIRED for orchestrator
correctness".

**Verdict: ADOPT, with jackin-specific fields.** Log context fields are adopted and extended with
`container`, `instance_id`, `host`, and `attempt`. The snapshot shape is adopted as the daemon's
state query (over its Unix socket; an HTTP listener is an optional extension exactly as §13.7) and
becomes the contract the termrock TUI reads (Q-011). Each running row additionally carries the
`hardline` attach target so that "watch this agent live" is one keystroke away from the fleet view
(difference 3). The `blocked` list joins `running` and `retrying`. Token accounting comes from the
jackin usage broker per instance rather than from agent events; the "absolute totals, not deltas"
rule still applies. The principle that the UI is never on the correctness path is adopted as a
decision (D-025) because it settles a structural question for Q-011: the TUI is a client of the
daemon snapshot, and the daemon must run headless without it.

**Touches.** D-006, D-008. Q-011. Proposed D-025.

### §14 Failure Model and Recovery Strategy

**Symphony.** §14.1 five failure classes: workflow/config, workspace (including hooks),
agent-session (handshake, turn, timeout, input required, exit, stall), tracker, observability.
§14.2 recovery per class: config failures skip dispatch but keep the service alive; worker failures
retry with backoff; tracker failures skip the tick or keep workers; dashboard failures never crash
the orchestrator. §14.3 restart recovery is tracker- and filesystem-driven, no timers or sessions
survive. §14.4 operator levers: edit `WORKFLOW.md`, change issue state (terminal stops and cleans,
non-active stops without cleanup), restart.

**Verdict: ADOPT the classes and per-class recovery; ADAPT restart.** The class taxonomy is
adopted and made part of the retry policy (D-027): only agent-class failures consume retry attempts;
config- and workspace-class failures are reported on the issue and hold it (retrying a broken
workflow file is pointless); tracker failures are transient and never touch attempt counts. Restart
recovery is adopted with one strengthening: the daemon adopts still-running containers labeled with
an issue identifier instead of assuming no session is recoverable (D-008 already requires this), and
persisted attempt counts and blocked entries are reloaded from the local ledger (D-019). The
operator levers map one-to-one: commit a change to `.jackin/workflow.toml`, move the issue in
Linear, restart the daemon.

**Touches.** D-008, D-010. Q-008. Proposed D-019, D-027.

### §15 Security and Operational Safety

**Symphony.** §15.1 each implementation states its trust boundary. §15.2 mandatory filesystem
rules (workspace under root, cwd is workspace, sanitized names); recommended dedicated OS user and
volume. §15.3 secrets: `$VAR` indirection, never log tokens, execute tracker tools in the host
process, never pass tracker credentials through the child environment, declare secret env names so
launchers scrub them, never put literal credentials in a repo-owned file. §15.4 hooks are trusted,
run in the workspace, output truncated, timeouts required. §15.5 hardening guidance: tighten
approvals and sandbox, add OS/container/VM isolation and network restrictions, filter eligible
issues, narrow tracker tools, minimize credentials and paths available to the agent; "SHOULD NOT
assume that tracker data, repository contents, prompt inputs, or tool arguments are fully
trustworthy".

**Verdict: ADOPT, and note we already exceed it.** Nearly every §15.5 recommendation is jackin's
default: container per agent, capability drops, egress allowlist, credentials over host-owned
sockets, no host Docker socket (`analysis/jackin.md` §1, §3.4, §3.5). The specific rules we adopt as
decisions: the Linear token never enters the container; the daemon is the only tracker writer; if
an agent ever needs a tracker read beyond what the daemon pre-fetched into the workspace, it goes
through a `jackin-exec` binding executed host-side with a narrow scope (D-023). The "filter eligible
issues" recommendation is the daemon-level `required_labels` gate plus D-011 (assignment only).
Hook safety is stronger than §15.4 because hooks run in the container (§9 above). The trust
statement §15.1 asks for is this document's fixed differences plus jackin's security profile.

**Touches.** D-008, D-013. Proposed D-023.

### §16 Reference Algorithms

**Symphony.** Language-neutral pseudocode for startup (§16.1: validate, startup cleanup, immediate
tick), the tick (§16.2), reconciliation (§16.3), dispatch (§16.4: spawn worker, record running
entry, claim), the worker attempt (§16.5: workspace, `before_run`, session, turn loop with tracker
re-check after each turn, `after_run`), and exit and retry handling (§16.6: normal exit schedules
continuation attempt 1; abnormal exit schedules backoff; retry timer refreshes the issue and
releases, requeues on no slots, or dispatches).

**Verdict: ADOPT as the manager's reference algorithms**, substituting the jackin calls: `spawn_worker`
becomes "ask the host's jackin daemon to start an instance"; `app_server.run_turn` becomes "inject
prompt, wait on capsule agent-status and process exit"; `after_run` and `before_run` are container
execs. §16.5's "re-fetch the issue after each turn and stop if it is no longer active" becomes
"re-fetch on every checklist write-back and on every reconciliation tick", which D-013's
write-on-progress cadence already provides. The pseudocode is the right starting point for the
implementation plan when D-001 lifts.

**Touches.** D-001, D-008, D-013.

### §17 Test and Validation Matrix

**Symphony.** Core conformance tests for config parsing (path precedence, reload, last-known-good),
workspace (deterministic path, reuse, hook semantics, sanitization collisions), adapter (empty
inputs make no provider call, pagination order, label normalization, malformed-record rules),
orchestrator (sort order, `dispatchable=false` excluded, terminal cleans, non-active stops without
cleanup, continuation retry, backoff cap, stall kill, slot exhaustion requeue), app-server client,
observability (UI never affects correctness), CLI; plus a recommended real-integration profile with
isolated identifiers and skipped-not-passed reporting.

**Verdict: ADOPT as the acceptance list for the manager**, minus §17.5 (app-server client) which
is replaced by jackin-daemon client tests: start instance with prompt, inject text, exec with
result, adopt container after restart, attach still works while managed. The Linear adapter tests
take §17.3 verbatim. The "skipped real-integration test is reported as skipped, never as passed"
rule is worth adopting across the ecosystem.

**Touches.** D-001 (this becomes part of the implementation plan, not code now).

### §18 Implementation Checklist

**Symphony.** §18.1 REQUIRED: workflow loader, typed config with `$` resolution, dynamic reload,
polling orchestrator with single-authority state, adapter with state-list and id-refresh reads,
sanitized workspaces, four hooks with timeout, app-server client, strict prompt rendering with
`issue` and `attempt`, exponential retry with continuation, reconciliation on terminal/non-active,
workspace cleanup, structured logs. §18.2 RECOMMENDED: HTTP extension, provider-native tools with
host-side auth, and three TODOs: persist retry queue and session metadata across restarts,
configurable observability, extract common tools only after duplication appears.

**Verdict: ADOPT as our definition of done, with the app-server line replaced and the first TODO
promoted to required.** Symphony's own TODO "persist retry queue and session metadata across process
restarts" is the gap D-019 closes. The third TODO ("do not preemptively replace provider-native
tools with generic CRUD") supports D-010's single-tracker stance: we build one Linear adapter, not an
abstraction over trackers.

**Touches.** D-010. Proposed D-019.

### Appendix A: SSH Worker Extension

**Symphony.** A.1: one central orchestrator remains the single source of truth; `worker.ssh_hosts`
lists candidate hosts; each run is assigned to one host, which "becomes part of the run's effective
execution identity along with the issue workspace"; `workspace.root` is interpreted on the remote
host; the app-server is launched over SSH stdio so the orchestrator still owns the session
lifecycle; continuation turns stay on the same host. A.2: hosts are a pool; prefer the previous host
on retry; a per-host cap; "When all SSH hosts are at capacity, dispatch SHOULD wait rather than
silently falling back to a different execution mode"; a rerun after side effects "SHOULD be treated
as a new attempt, not as invisible failover". A.3 problems: environment drift, workspace locality,
path and quoting safety, distinguishing host-connectivity failure from in-workspace failure "so the
same ticket is not accidentally re-executed on multiple hosts", host health, cleanup ownership.

**Verdict: ADOPT the model, with jackin daemons in place of SSH.** This is the closest analogue to
our multi-host shape: one manager, one jackin daemon per host (D-008), each daemon owning its
workspace root and containers. Every A.1 and A.2 rule maps directly: run identity is
`(issue, host, attempt)`; placement is least-loaded with previous-host preference on retry (workspace
locality is why); per-host caps; wait rather than fall back; host failure before side effects is
re-placement, after side effects is a new attempt. Environment drift is solved by roles: every host
runs the same published role image, which SSH workers cannot promise. Transport is the jackin daemon
interface (Q-001), not SSH stdio; jackin's own research already prefers a remote daemon over SSH
(`analysis/jackin.md` §10 row 9). The A.3 list becomes the acceptance criteria for multi-host
support (D-026).

**Touches.** D-008, Q-001, Q-010. Proposed D-026.

## Outside the SPEC: the reference prompt and skills

These are in `elixir/WORKFLOW.md` and `.codex/skills/`, not in `SPEC.md`; they are what makes the
reference deployment work and the prompt asked for them explicitly. `analysis/symphony.md` §5-§7
describes them; only the verdicts are recorded here.

**Completion bar before Human Review** (`elixir/WORKFLOW.md` "Completion bar before Human Review"):
a fixed list the agent must satisfy before moving the ticket on: checklist complete and reflected
in the workpad, acceptance criteria and ticket-provided validation done, tests green on the latest
commit, PR feedback sweep clean, PR checks green, branch pushed and PR linked, required label
present. **ADAPT** as the mandatory closing section of the repository prompt frame (D-018) and as
the input to Q-014: the agent's self-check is the completion bar; the daemon's proof is the
repository's verification command run after the checklist completes. The two are different things
and both exist (D-030).

**Blocked-access escape hatch** ("GitHub is not a valid blocker by default"; a blocker brief with
what is missing, why it blocks, and the exact human action): **ADOPT** as the escalation format
(D-029) and as the rule that the prompt frame enumerates what may not be escalated.

**Rework flow and "closed PR means fresh branch"** ("If a branch PR exists and is CLOSED or MERGED,
treat prior branch work as non-reusable"; create a new branch from `origin/main`): **ADOPT** as an
attempt kind `rework` that resets the workspace to the base branch; this is the one case where
workspace reuse (§9) is deliberately broken.

**`land` and `pull` skills** (agent merges `origin/main`, resolves conflicts, waits for checks,
addresses review comments, squash-merges, then moves the ticket to `Done`; merging serialized by a
per-state cap of 1): **ADAPT** for Q-007. D-014 makes PR creation a daemon job, but conflict
resolution and CI repair need an agent. Proposal: merge is triggered by a human moving the issue to
a `Merging` state; the daemon dispatches a `merge` attempt (same role, same workspace, prompt frame
section "land") capped at one per repository; the daemon, not the agent, confirms the PR is merged
through GitHub and moves the issue to `Done`. The agent never holds the tracker credential and never
declares the issue done; it only makes the PR mergeable and merges it with the GitHub credential
jackin already forwards (`analysis/jackin.md` §3.5). This preserves Symphony's mechanism and our
credential and authority rules.

**Workpad comment as single progress record**: **REJECT** in favor of D-013's local checklist
mirrored to the issue description and the Linear session plan (`analysis/linear-agents.md` A3),
which Linear renders natively; a free-form workpad would be a second progress record.

## Consolidated proposals

### Adopted rules D-018..D-031

All dated 2026-08-27, adopted by D-053 with these numbers as references. Numbering continues from D-017.

The normative effects of D-018..D-031 are incorporated into their owning
product, graph, or run-procedure documents; `SPEC.md` holds their canonical
definitions (D-103). This section records only that these fourteen rules
originated as proposals in the walk above and were adopted by D-053.

### Closures and narrowings for Q-004..Q-015 (adopted, D-053)

Q-004..Q-015 are closed or narrowed by D-053 through D-020..D-031. The full
text of each question and its closing outcome is in `QUESTIONS.md`; owning
documents carry normative effects and `SPEC.md` carries canonical definitions.
No normative closure text is kept here (D-103).

### What Symphony has that jackin lacks

Cross-checked against `analysis/jackin.md` §10 (gap table rows in parentheses) and
`analysis/linear-agents.md` B5 and C6. Each is something the daemon needs from jackin to implement
the adopted rules above; none of it exists today.

1. **Programmatic, headless launch** (`analysis/jackin.md` §10 rows 2 and 3; B5.1). Symphony's
   `spawn_worker` (§16.4) has no equivalent: `jackin load` demands a TTY of at least 80x24 and
   interactive dialogs for agent choice, trust, env, and dirty trees. Needed: a `LoadOptions` entry
   into `launch_pipeline` with every decision pre-supplied, returning the instance identity.
2. **Prompt delivery into the session** (row 15; B5.2, C6.2). Symphony renders a prompt and starts
   the first turn with it (§10.2, §12); jackin has no mechanism to pass an initial prompt: not a
   flag, env, file, or stdin path (B5.2). Needed: a manifest or launch field that the entrypoint turns
   into the runtime's positional prompt, keeping the session interactive on the PTY (D-024).
3. **Text injection and event subscription on a live session** (row 1). Continuation guidance
   (§7.1, §10.2) and Linear replies (D-029) must reach the agent; `ClientMsg` has no
   `session.send` or `events`. The terminal-observation research designed them; nothing shipped.
4. **Exec with result inside an instance** (row 12). Hooks (§9.4) and the verification command
   (D-030) need "run this command in the container, return exit code and output"; `ExecCommand`
   exists only for credential-bearing commands.
5. **A real host daemon interface** (row 3; D-008). Symphony's orchestrator state (§4.1.8) needs
   list, start, stop, status stream, and adopt-after-restart from each host; `jackin daemon` is an
   empty shell with `Hello/Status/TelemetryHealth/AttentionSnapshot/Shutdown`.
6. **Issue-keyed workspaces and container labels.** Symphony's workspace key (§4.2, §9.1) and
   restart sweep (§8.6) need workspaces addressed by issue identifier and containers labeled with
   it; jackin's mounts are keyed by workspace config, and labels are `jackin.role`, `jackin.image`,
   `jackin.kind` only.
7. **Stall signal for every runtime.** Symphony's stall detection (§8.5) relies on a continuous
   event stream; jackin's agent-status hooks exist for three of six runtimes and are graded complete
   for only two (`analysis/jackin.md` §3.8). D-021 needs all six.
8. **Structured completion marker** (B5.5; `agent-tag-protocol` roadmap). Symphony gets
   `turn_completed` from the protocol (§10.4); jackin has exit codes and a status heuristic. The
   checklist file plus exit code covers most of it; a marker would remove ambiguity.
9. **Narrow tracker binding through `jackin-exec`** (C6.3; §15.3). Partially implemented, one
   materialization gap, no smoke pass; a Linear binding scoped to one issue does not exist.
10. **Remote daemon mode** (row 9; Appendix A). `jackin-remote` is a design with no code; D-026
    needs a daemon reachable from another host.
11. **Per-launch resource overrides** (row 16). `[docker.grants]` memory, cpus, pids exist as
    config, not as launch parameters; Q-010 wants them per issue.
12. **Usage attribution per run.** Symphony aggregates tokens per session (§13.5); jackin's usage
    broker is per instance and host, so attribution per issue attempt needs the instance-to-issue
    binding from item 6.
13. **`default_agent` in the role manifest** (B5.4). Symphony has one runtime; we need a role to
    say which of its listed runtimes is the default when the issue and repository omit it.

Things Symphony has that we deliberately do not need: five tracker adapters (D-010), a Codex
app-server client (differences 1-2), a web dashboard (the termrock TUI reads the snapshot instead),
and host-side shell hooks (they run in the container).
