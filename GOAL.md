# GOAL.md — the `/goal` prompt that executes the whole roadmap

This file is the entry point for running `ROADMAP.md` (M1..M12) unattended
from one Claude Code session on the host Mac (D-050, D-061, D-068, D-070).
The fenced block below is the complete prompt; it is self-contained and
points at the files that carry the detail. It stays under 4000 characters
(the `jackin-goal-prompt` cap; check with `wc -c` on the block).

Before running it, the human completes `goal/PREFLIGHT.md` once — all of
§1..§5 for a single uninterrupted run. Then, in a Claude Code session
opened in this repository, the invocation is this one line, copied
verbatim (D-083: the argument carries the two facts the runner's judge can
check, so neither a prose summary nor a mid-wait turn end counts as the
goal):

```text
/goal Follow GOAL.md. Goal reached only when the current turn ends with either (A) the literal output of `sh verify.sh` whose last line is `status: DONE`, or (B) a final message whose first line is `GOAL BLOCKED`, followed by the open PREFLIGHT-DEFECTS.md rows and the literal output of `sh verify.sh` (last line `status: PENDING <n> remaining`). Any other turn end is not the goal.
```

This is the only invocation; every document that says "re-run the
invocation" means this line. The run ends in one of two outcomes (D-070,
D-083): COMPLETE (root `verify.sh` prints `status: DONE`) or BLOCKED (no
row is `in-progress` or `waiting`, nothing is runnable, and
`PREFLIGHT-DEFECTS.md` has an open row). Re-running the invocation after
BLOCKED resumes from `tasks/README.md` and `PROGRESS.md`; nothing is
redone. If the runner re-prompts after BLOCKED, the session repeats
`goal/EXECUTION.md` §1 steps 1–4 (proof commands may now pass; an
`exhausted:` row starts a new attempt epoch, D-084) and continues if
anything became runnable; otherwise it prints the same `GOAL BLOCKED`
block again and ends the turn.

Detail files: `goal/EXECUTION.md` (session start, per-task procedure, wave
order, execution paths, resume), `goal/PREFLIGHT.md` (the human's one-time
checklist), `PROGRESS.md` (one row per finished task), `PREFLIGHT-DEFECTS.md`
(missing operator inputs and exhausted tasks — the only reasons the run
ends BLOCKED), root `verify.sh` (the goal's gate, D-069).

## Prompt

```text
Execute the whole roadmap (ROADMAP.md, M1..M12) unattended as the host Claude Code session on this Mac. Read first, in order: GOAL.md, goal/EXECUTION.md, AGENTS.md, tasks/README.md, PROGRESS.md, PREFLIGHT-DEFECTS.md; after any context compaction repeat goal/EXECUTION.md §1 steps 2-3. Source of truth: ROADMAP.md, SPEC.md, DECISIONS.md. goal/PREFLIGHT.md is done; the human is absent.

Order: milestones M1..M12; inside each, the waves of ROADMAP.md §3 (M6..M12 by depends_on). Runnable = every depends_on row `done`, lane caps allow (D-071; throwaway loads count) and, for M2+ ids except M3-01, M3-03, M4-02, M4-03, M1-12 `done` (D-088). Reviews never block (D-055). M1-01 runs first (wave 0, host path) and authors tasks/<id>/ for M1..M5. M6..M12 folders are authored when reached, never before M1-12 is done; authoring ends with the idempotent M1-12 re-run (D-073).

Non-negotiable:
- Delegate every unit of work to subagents or role containers on the goal/EXECUTION.md §4 path; this session coordinates, verifies, records (D-036, D-082). When anything stalls, subagents analyze why and find a fix before any other action (D-063).
- Never ask the human anything; never wait for a human review or merge; agents merge when a task names the merge (D-055, D-079). Design questions get the recommended answer, recorded in DECISIONS.md (D-053).
- Involved repositories (jackin-project/*, tailrocks/*, donbeave/jackin-*) are fixed, never worked around (D-046). Work lands on feat/managed-execution, role repositories on main (D-074), this repository on main, written only by this session (D-086); always `git commit -s`, rebase before push, never --force (sole exception: the DCO repair of EXECUTION §4), push at once (D-047).
- Credentials only in 1Password as op:// references; no secret value in any file, log, or message; evidence scanned before commit (D-035, D-081).
- Runtime, model, account per task from ROADMAP.md §5 via the per-task workspace task-<id> (D-085). Quota exhaustion re-runs on the next lane of another account home, no attempt consumed; a fully throttled chain waits (`waiting`); hops go in the PROGRESS.md result cell, never a defect (D-071).
- host rows and every host-side check (Linear token, op, daemon socket, docker, jackin launches) run in this session, output filed in the task folder (D-081, D-091). Linear team JACKIN; M1-12 creates issues without delegate; this session delegates only what the daemon can serve, closes every finished task's issue for the whole run, and answers escalations (D-068, D-073, D-087).

A task is done only when, in this session: tasks/<id>/verify.out, produced per goal/EXECUTION.md §5 step 5, ends with `status: DONE`; its tasks/README.md row reads `done`; every touched repository is committed and pushed. Then append the PROGRESS.md row and commit.

A row is `blocked` for one of two reasons (D-070): (a) a missing operator input: append it to PREFLIGHT-DEFECTS.md with the item and proving command; (b) exhaustion: verify still fails after `limits.attempts` (task.toml, default 3) attempts in the current epoch, each on the next lane after the D-063 analysis: append `exhausted: <id>` with verify.out path and analysis summary (a resume starts a new epoch, D-084). Dependents of a blocked row stay `ready` (not runnable). Continue with every other runnable task. Never block for a failing check, design question, review, quota wait, capsule dialog, or involved-project defect.

Done, one of two outcomes, both end this run (D-070, D-083): (A) COMPLETE: root `sh verify.sh` prints `status: DONE` as its last line, run in the current turn after the final commit and push; tree clean; PROGRESS.md has a row per task. (B) BLOCKED: no row `in-progress` or `waiting` (wait for those first), no row runnable, PREFLIGHT-DEFECTS.md has a row with empty Resolved cell: commit, push, print `GOAL BLOCKED`, those rows, and the literal `sh verify.sh` output; end. Never claim (A) from memory; never end otherwise.
```
