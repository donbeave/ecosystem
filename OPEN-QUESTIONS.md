# Open questions

Undecided points that affect the design. Each entry names the question, why
it matters, and known options. Closing a question means recording a decision
in `DECISIONS.md` and removing the entry here.

## Q-001 — Where does the manager live?

Options: (a) a jackin subcommand plus daemon mode inside the jackin binary;
(b) a separate binary in the jackin-project organization that talks to
jackin; (c) a separate Tailrocks product. Affects release cadence, breaking
change exposure (jackin is pre-stable), and whether the manager can be used
without jackin. Leaning: part of jackin (D-002), not final.

## Q-002 — What is the project's name?

Placeholder in all documents: "the manager".

## Q-003 — What is the machine-readable source of truth for roadmap state?

Options: task folders and status files on a git branch that the daemon polls
or watches; a local database owned by the daemon with the git branch as
input; a mix where git is the plan and the daemon owns runtime state.
Affects: how the human marks "ready", how multiple machines share state, how
history is kept.

## Q-004 — How are dependencies between tasks declared?

Options: a manifest per task listing prerequisite task identifiers; a
plan-level graph file; inferred from folder order. Also: can a task depend on
an external condition (a CI run, a human approval) rather than another task?

## Q-005 — Who produces the decomposition?

Options: the human with planning skills in a jackin session (today's
approach, formalized); a planner agent run by the manager from a high-level
goal; both, with the planner proposing and the human approving. Affects
whether the manager needs a "planning" phase distinct from "execution".

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

## Q-010 — Where do agents run and how are resources bounded?

Local machine only at first, or remote hosts via jackin from the start?
Limits on concurrent agents per host, per provider account, and per plan.

## Q-011 — What does the manager's terminal interface show?

Minimum: roadmap and task graph, per-task status and live log, approval
inbox, agent fleet. Which of these are termrock gaps versus product widgets
is listed in `analysis/termrock.md`; the product-side scope is undecided.

## Q-012 — How does the manager relate to jackin's existing session model?

Depends on `analysis/jackin.md` (pending). Whether a "task run" maps to one
jackin session, whether sessions can be created and observed
programmatically, and what jackin must add.
