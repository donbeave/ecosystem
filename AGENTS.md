# AGENTS.md

Rules for any agent or person editing this repository.

## What this repository is

A planning and research repository for the Tailrocks agent manager concept.
It contains only Markdown. It is the single source of truth for the vision,
decisions, and concept of the project before implementation starts.

## Hard rules

1. **No implementation.** Do not add source code, build files, scripts,
   scaffolding, or prototypes. Shell snippets inside Markdown that illustrate a
   contract are fine; runnable files are not — except verification scripts
   inside `tasks/<task>/` (D-038).
2. **Decisions are explicit.** A point is decided only when it is recorded in
   `DECISIONS.md` with a date and a short rationale. `SPEC.md` states only
   decided points and marks the rest *open (Q-NNN)*. Concept documents must
   not contradict `DECISIONS.md`; when they would, update the decision first.
3. **Open questions are tracked.** Anything undecided that affects the design
   goes into `OPEN-QUESTIONS.md`. Closing a question means recording a
   decision and deleting the question.
4. **Incremental improvement.** After every conversation that reaches
   agreement, update the affected documents. Do not rewrite documents from
   scratch when an edit suffices; keep the history readable through git.
5. **Analyses are factual.** Files under `analysis/` describe existing
   repositories with `path:line` citations. Mark each capability as
   implemented, partial, documented only, or absent. Opinions are labeled.
6. **Normal prose.** Documents are for humans; write complete sentences.
7. **Delegate heavily.** Research, analysis, drafting, and verification are
   done by subagents; the top-level agent coordinates, integrates, and
   records decisions (D-036).
8. **Credentials go to 1Password.** Any credential created while working on
   this project is stored in 1Password at creation and referenced as
   `op://`; never in files, images, documents, or chat (D-035).
9. **Commit and push every change, on `main`.** Use `git commit -s`, then
   push to `origin main` immediately. This repository never uses feature
   branches; every change goes directly to `main` (D-047). Nothing stays
   local.
10. **Fix involved projects, do not work around them.** Any repository under
    github.com/jackin-project or github.com/tailrocks may be changed when
    this effort needs it; defects there are bugs to fix, gaps are
    extensions to add (D-046). All such changes land on the branch
    `feat/managed-execution` in that repository (D-047).
11. **Stuck rule.** When a task stalls or takes too long, spawn subagents
    to analyze why and to find a solution before anything is escalated.
    This binds every container agent and the host session; in managed
    runs the daemon's stuck signal triggers it (D-063).

## Where things go

| Content | File |
| --- | --- |
| Problem statement, insights, target state | `VISION.md` |
| Agreed decisions | `DECISIONS.md` |
| The specification (decided points only, open points marked) | `SPEC.md` — update it in the same change as any new decision |
| Undecided design questions | `OPEN-QUESTIONS.md` |
| How the manager works | `concept/manager.md` |
| Plan and task on-disk format, verification contract | `concept/task-format.md` |
| Today's workflow versus target workflow | `concept/workflow.md` |
| Milestones, task list, dependencies | `ROADMAP.md` |
| One folder per task, indexed with status | `tasks/README.md`, `tasks/<task>/` |
| Facts about existing repositories | `analysis/<repo>.md` |
