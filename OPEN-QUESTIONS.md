# Open questions

Undecided points that affect the design. Each entry names the question, why
it matters, and known options. Closing a question means recording a decision
in `DECISIONS.md` and removing the entry here.

## Q-001 — Where does the manager live?

Narrowed by D-008: the manager is a client of the jackin daemon's
programmatic interface. Remaining options: (a) manager logic compiled into
the jackin daemon binary; (b) a separate binary in the jackin-project
organization that connects to one or more jackin daemons. Affects release
cadence, breaking-change exposure (jackin is pre-stable), and whether one
manager can drive daemons on several hosts. Leaning: (a) for the first
version, not final.

## Q-002 — What is the project's name?

Placeholder in all documents: "the manager".

## Q-004 — How are dependencies between tasks declared?

Narrowed by D-010: dependencies between issues use Linear blocking
relations (`inverseRelations.type == "blocks"`). Remaining: does
the daemon refuse to start a blocked issue, or is assignment alone the gate
(Symphony collapses blocks into a `dispatchable` bool)? Within one issue,
checklist order is the dependency order unless stated otherwise.

## Q-005 — Who produces the decomposition?

Narrowed by D-013: the issue author writes the checklist. Remaining: whether
a planner agent may be assigned an issue whose output is a set of new
issues or a checklist (Symphony's follow-up pattern), and whether the human
must approve before those become assignable.

## Q-006 — Who writes the verification scripts, and how are they trusted?

A verification script written by the same agent that implements the task
proves little. Options: scripts authored during planning before execution;
scripts reviewed by a separate verifier agent; a mix of task-level scripts
and plan-level integration verification.

## Q-007 — How do parallel task results merge?

Options: one branch per task merged by the manager after `DONE`; one
worktree per task on a shared branch; task results as pull requests reviewed
by a review role (for example agent-smith) before merge. Affects conflict
handling and what "done" means for the plan as a whole.

## Q-008 — What is the failure and retry policy?

What happens when verification never reaches `DONE`: retry with the same
agent, retry with a different runtime or model, split the task, or escalate
to the human. Limits on attempts, time, and tokens per task.

## Q-009 — What decisions are escalated to the human, and how?

The vision says the human answers only genuine decisions. Which events
qualify, how the inbox is presented (TUI, desktop, phone), and how an answer
flows back to a paused agent.

## Q-010 — How are resources bounded?

Narrowed by D-017: local machine only for the prototype. Remaining: limits
on concurrent agent containers per host, per provider account, and per
Linear project or team; whether limits live in a repository-level policy
file, a daemon config, or Linear.

## Q-011 — What does the manager's terminal interface show?

Minimum: roadmap and task graph, per-task status and live log, approval
inbox, agent fleet. Which of these are termrock gaps versus product widgets
is listed in `analysis/termrock.md`; the product-side scope is undecided.

## Q-013 — How are role, runtime, and prompt expressed on a Linear issue?

D-012 requires role, runtime, and prompt; D-014 adds repository, branch,
and optional base branch. Options: labels (`role:the-architect`,
`agent:claude`), issue template fields, a fenced block or front matter in
the description, or a project-level default with per-issue override.
Facts from `analysis/linear-agents.md`: Linear has no custom fields and no
structured checklist; labels are the only structured per-issue property a
template can pre-set. Proposal on the table: label groups
`role:<selector>` and `agent:<runtime>`, prompt = issue description
verbatim, first `- [ ]` list = checklist. Awaiting decision.

## Q-014 — How do checklist items relate to verification scripts?

D-013 makes the checklist the unit of progress; D-003 makes `verify.sh` the
unit of proof. Options: one verification per issue run by the daemon after
the checklist is complete; a verification reference per checklist item; the
agent's own verification subagent per item with the daemon verifying only at
the end.

## Q-015 — Webhook or polling?

Facts from `analysis/linear-agents.md`: Linear delivers `AgentSessionEvent`
webhooks only to a public HTTPS endpoint (HMAC-signed, 3 retries), requires
HTTP 200 within 5 s and a first activity within 10 s, and marks sessions
`stale` after 30 min idle; no long-poll or websocket exists; polling
`issues(filter:{delegate})` works but `agentSessions` has no filter.
D-017 excludes direct webhooks to the laptop for the prototype. Options: a
small relay service that receives webhooks and lets daemons pull; a tunnel
per host; polling only. Awaiting decision.

## Q-016 — Which jackin agent roles build this product?

D-033 and D-036 require the product to be built by agents through jackin.
Options: reuse `the-architect` (jackin's own development role) for jackin
and daemon work, and add roles for termrock work, for Linear/GitHub setup
with `agent-browser`, and for verification/review (for example
`agent-smith`); or one role with everything. Decide during `ROADMAP.md`
planning, before task folders are created.

