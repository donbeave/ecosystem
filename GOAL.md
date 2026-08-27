# GOAL.md — the `/goal` prompt that executes the whole roadmap

This file is the entry point for running `ROADMAP.md` (M1..M12) unattended
from one Claude Code session on the host Mac (D-050, D-061, D-068, D-070).
The fenced block under **Prompt** is the complete prompt; it is
self-contained and points at the files that carry the detail. It stays
under 4000 characters (the `jackin-goal-prompt` cap; check with `wc -c` on
the block).

## Objective

Every task of `ROADMAP.md` is executed, verified, committed and pushed,
without a single question to the human, by a host session that spends its
own context on coordination alone and delegates all work to subagents on
Opus and to jackin role containers (D-036, D-092).

## Done condition

Deterministic, one command: `./verify.sh` at the repository root, run in
the final turn, prints `status: DONE` as its last line (D-069). Nothing
else counts — not a summary, not a claim from memory. The only other
terminal state is BLOCKED (below).

## Invocation

Before the first run the human completes `goal/PREFLIGHT.md` once — all of
§1..§5 for a single uninterrupted run. Then, in a Claude Code session
opened in this repository, the invocation is this one line, copied
verbatim (D-083: the argument carries the facts the runner's judge can
check, so neither a prose summary nor a mid-wait turn end counts as the
goal):

```text
/goal Follow GOAL.md. Goal reached only when the current turn ends with a message whose first line is exactly `GOAL COMPLETE` or `GOAL BLOCKED` and whose last lines are the literal output of `sh verify.sh` from that turn: last line `status: DONE` for COMPLETE, or `status: PENDING <n> remaining` preceded by the open PREFLIGHT-DEFECTS.md rows for BLOCKED. Any other turn end is not the goal.
```

This is the only invocation; every document that says "re-run the
invocation" means this line.

## The two outcomes

COMPLETE — root `verify.sh` prints `status: DONE`.

BLOCKED — no row is `in-progress` or `waiting`, no row is runnable, and
`PREFLIGHT-DEFECTS.md` has a row with an empty `Resolved` cell (D-070,
D-083). This is the only STOP: a failing check, a design question, a
review, a quota wait, a capsule dialog, and a defect in an involved
project are never reasons to stop.

## Resume

Re-running the invocation after BLOCKED, after a crash, or after a context
compaction resumes; nothing finished is redone. The session repeats
`goal/EXECUTION.md` §1 steps 1–4, re-deriving the whole state from
`tasks/README.md`, `PROGRESS.md`, `tasks/<id>/attempts.log` and `git log`
only, then continues with whatever became runnable. Missing-input defect
rows are re-proved and closed by the session; an `exhausted:` row is
closed only by the human filling its `Resolved` cell, which opens a new
attempt epoch (D-084, D-093). If nothing became runnable, the session
prints the same `GOAL BLOCKED` block again and ends the turn.

## Reporting

One final message, this shape, nothing after it: line 1 alone
`GOAL COMPLETE` or `GOAL BLOCKED`; at most eight report lines; the open
`PREFLIGHT-DEFECTS.md` rows when BLOCKED; last, the literal output of
`sh verify.sh` from that turn (`goal/EXECUTION.md` §7, D-093). No progress
narration between tasks.

## Never

Ask the human. Wait for a human review or merge. Work around an involved
project. Read `ROADMAP.md`, `SPEC.md`, `DECISIONS.md`, `concept/` or
`analysis/` in the host session instead of delegating. Put a secret value
in a file, a log or a message. Use `--force`. Claim COMPLETE without the
`verify.sh` output in the same turn.

## Detail files

`goal/EXECUTION.md` (session start, per-task procedure, wave order,
execution paths, resume, done, host session budget), `goal/PREFLIGHT.md`
(the human's one-time checklist), `AGENTS.md` (the standing rules for
every agent), `PROGRESS.md` (one row per finished task),
`PREFLIGHT-DEFECTS.md` (missing operator inputs and exhausted tasks — the
only reasons the run ends BLOCKED), root `verify.sh` (the gate, D-069).

## Prompt

```text
Execute ROADMAP.md (M1..M12) unattended as the host Claude Code session. First action: read AGENTS.md, goal/EXECUTION.md, tasks/README.md, PROGRESS.md, PREFLIGHT-DEFECTS.md; then §1 of that guide — standing checks, then M1 wave 0 (M1-01). After any compaction or re-prompt repeat §1 steps 2-4; state comes only from tasks/README.md, PROGRESS.md, tasks/<id>/attempts.log and git log. goal/PREFLIGHT.md is done; the human is absent.

Delegation law (D-036, D-082, D-092): this session coordinates, verifies, records; every read of ROADMAP.md, SPEC.md, DECISIONS.md, concept/ or analysis/, every implementation, verification and proof is a subagent launched with model: "opus" returning ≤15 lines, parallel where caps allow; Codex lanes L4..L6 run in role containers (§4), never as subagents. On any stall, subagents analyze why and fix it first (D-063).

Order: M1..M12; inside each, the waves of ROADMAP.md §3 (M6..M12 by depends_on). Runnable = every depends_on row `done`, caps allow (D-071), and for M2+ except M3-01, M3-03, M4-02, M4-03, M1-12 `done` (D-088). Reviews never block (D-055). M1-01 is wave 0 (host path) and authors tasks/<id>/ for M1..M5; M6..M12 folders are authored when reached, never before M1-12 is done, authoring ends with the idempotent M1-12 re-run (D-073).

Non-negotiable:
- Never ask the human; never wait for a human review or merge; agents merge when the task names it (D-055, D-079). Design questions take the recommended answer, recorded in DECISIONS.md (D-053).
- Involved repositories are fixed, never worked around (D-046). Branch, DCO and push rules per AGENTS.md: always `git commit -s`, rebase before push, never --force, push at once; this repository is written only by this session (D-047, D-074, D-086).
- Credentials only as op:// references in 1Password; no secret value in any file, log or message; evidence scanned before commit (D-035, D-081).
- Runtime, model, account per task from ROADMAP.md §5 via the workspace task-<id> (D-085). Quota exhaustion re-lanes to another account home, no attempt consumed; a fully throttled chain is `waiting`; hops go in the PROGRESS.md result cell, never a defect (D-071).
- host rows and every host-side check (Linear token, op, daemon socket, docker, jackin launches) run here, filed in the task folder (D-081, D-091). Linear team JACKIN; this session delegates only what the daemon can serve, closes every finished issue, and answers escalations (D-068, D-073, D-087).

A task is done only when: tasks/<id>/verify.out (§5 step 5) ends with `status: DONE`, its tasks/README.md row reads `done`, every touched repository is committed and pushed; then append the PROGRESS.md row and commit.

A row is `blocked` for one of two reasons (D-070): a missing operator input, appended to PREFLIGHT-DEFECTS.md with its proving command; or exhaustion — verify still failing after `limits.attempts` (task.toml, default 3) attempts in the current epoch of tasks/<id>/attempts.log, each on the next lane after the D-063 analysis — appended as `exhausted: <id>` with verify.out and the analysis, re-opening only after the human fills Resolved (D-093). Dependents stay `ready`, not runnable. Continue with every other runnable task. Never block for a failing check, design question, review, quota wait, capsule dialog or project defect. Stop only when PREFLIGHT-DEFECTS.md has an open row and no task is runnable, `in-progress` or `waiting`.

Two outcomes end the run (D-070, D-083, D-093). Final message, this shape, nothing after: line 1 alone `GOAL COMPLETE` or `GOAL BLOCKED`; ≤8 report lines (tasks done of total, defects, fallbacks, repositories with head commits, Linear project URL); when BLOCKED the open PREFLIGHT-DEFECTS.md rows; last, the literal output of `sh verify.sh` run in this turn. COMPLETE needs that last line `status: DONE`, run after the final commit and push, tree clean, one PROGRESS.md row per task. Never claim it from memory; never end otherwise.
```
