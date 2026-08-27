# GOAL.md — the `/goal` prompt that executes the whole roadmap

This file is the entry point for running `ROADMAP.md` (M1..M12) unattended
from one Claude Code session on the host Mac (D-050, D-061, D-068, D-070).
The fenced block below is the complete prompt; it is self-contained and
points at the files that carry the detail. It stays under 4000 characters
(the `jackin-goal-prompt` cap; check with `wc -c` on the block).

Before running it, the human completes `goal/PREFLIGHT.md` once — all of
§1..§5 for a single uninterrupted run. Then, in a Claude Code session
opened in this repository:

```text
/goal Follow GOAL.md
```

This is the only invocation. The run ends in one of two outcomes (D-070):
COMPLETE (root `verify.sh` prints `status: DONE`) or BLOCKED (nothing is
runnable and `PREFLIGHT-DEFECTS.md` has an open row). Re-running the same
command after BLOCKED resumes from `tasks/README.md` and `PROGRESS.md`;
nothing is redone. If the runner re-prompts after BLOCKED and nothing
changed, the session repeats the BLOCKED statement and performs no other
action.

Detail files: `goal/EXECUTION.md` (session start, per-task procedure, wave
order, execution paths, resume), `goal/PREFLIGHT.md` (the human's one-time
checklist), `PROGRESS.md` (one row per finished task), `PREFLIGHT-DEFECTS.md`
(missing operator inputs and exhausted tasks — the only reasons the run
ends BLOCKED), root `verify.sh` (the goal's gate, D-069).

## Prompt

```text
Execute the whole roadmap (ROADMAP.md, M1..M12) unattended as the host Claude Code session on this Mac. Read first, in order: GOAL.md, goal/EXECUTION.md, AGENTS.md, tasks/README.md, PROGRESS.md, PREFLIGHT-DEFECTS.md; after any context compaction repeat goal/EXECUTION.md §1 steps 2-3. Source of truth: ROADMAP.md, SPEC.md, DECISIONS.md. The human completed goal/PREFLIGHT.md and is not available.

Order: milestones M1..M12; inside each, the waves of ROADMAP.md §3. A task is runnable when every depends_on row is `done` and the lane caps allow (D-071: ~/.claude 2 while this session runs, each Codex home 1, crew-operator 1, 6 total). Reviews never block (D-055). M1-01 runs first (wave 0, host path) and authors tasks/<id>/ for M1..M5; every task runs from its folder. M6..M12 folders are authored when reached; the authoring ends with the idempotent M1-12 re-run so each new row has its issue (D-073).

Non-negotiable:
- Delegate every unit of work to subagents or role containers on the goal/EXECUTION.md §4 path; this session coordinates, verifies, records (D-036, D-082). When anything stalls, spawn subagents to analyze why and find a fix before any other action (D-063).
- Never ask the human anything; never wait for a human review or merge; agents merge when a task names the merge (D-055, D-079). A design question gets the recommended answer, recorded in DECISIONS.md (D-053).
- Involved repositories (jackin-project/*, tailrocks/*, donbeave/jackin-*) are fixed, never worked around (D-046). Work lands on feat/managed-execution, role repositories on main (D-074), this repository on main; always `git commit -s`, rebase before push, never --force, push at once (D-047).
- Credentials only in 1Password as op:// references; no secret value in any file, log, or message; evidence scanned before commit (D-035, D-081). Created repositories public; CI on GitHub-hosted runners.
- Runtime, model, account per task from ROADMAP.md §5. Quota exhaustion re-runs on the next lane of another account home, consumes no attempt; a fully throttled chain waits for the reset (`waiting`); hops go into the PROGRESS.md result cell, never a defect (D-071). A stuck attempt re-runs on the fallback after the D-063 analysis.
- host rows and every host-side check (Linear token, op, daemon socket, docker) run in this session, output filed in the task folder (D-081). Text evidence in tasks/<id>/, media on the issue. Linear team JACKIN; M1-12 creates issues without delegate; this session delegates only what the daemon can serve, closes every finished task's issue, and is first responder to escalations (D-068, D-073).

A task is done only when, in this session: `sh tasks/<id>/verify.sh` prints `status: DONE` as its last line; its tasks/README.md row reads `done`; every touched repository is committed and pushed. Then append one PROGRESS.md row (id, lane, path, result with attempts, evidence) and commit.

A row is `blocked` for one of two reasons (D-070): (a) a missing operator input (login, consent, credential, UI-only step, hardware): append it to PREFLIGHT-DEFECTS.md with the exact item and the proving command; (b) exhaustion: verify still fails after `limits.attempts` (task.toml, default 3) attempts, each on the next lane after the D-063 analysis: append a row `exhausted: <id>` with the last verify.out path and analysis summary. Then continue with every other runnable task. Never block for one failing check, a design question, a review, a quota wait, a capsule dialog, or an involved-project defect.

Done, one of two outcomes, both end this run (D-070): (A) COMPLETE: root `sh verify.sh` prints `status: DONE` as its last line, run in the current turn after the final commit and push; tree clean; PROGRESS.md has a row per task. (B) BLOCKED: `sh verify.sh` prints `status: PENDING`, no row is runnable, PREFLIGHT-DEFECTS.md has a row with empty Resolved cell: commit, push, print "GOAL BLOCKED" plus those rows, end. Never claim (A) from memory; never end without (A) or (B).
```
