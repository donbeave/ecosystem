# GOAL.md — the `/goal` prompt that executes the whole roadmap

This file is the entry point for running `ROADMAP.md` (M1..M12) unattended
from one Claude Code session on the host Mac (D-050, D-061, D-068). The
fenced block below is the complete prompt; it is self-contained and points
at the files that carry the detail. It stays under 4000 characters so it
can be pasted inline (the `jackin-goal-prompt` cap).

Before running it, the human completes `goal/PREFLIGHT.md` once. Then, in a
Claude Code session opened in this repository:

```text
/goal Follow GOAL.md
```

or, equivalently, `/goal ` followed by the block below pasted verbatim. Both
forms run the same prompt. Re-running the same command after a STOP resumes
from `tasks/README.md` and `PROGRESS.md`; nothing is redone.

Detail files: `goal/EXECUTION.md` (session start, per-task procedure, wave
order, execution paths, resume), `goal/PREFLIGHT.md` (the human's one-time
checklist), `PROGRESS.md` (one row per finished task), `PREFLIGHT-DEFECTS.md`
(the only reason the run may stop), root `verify.sh` (the goal's gate,
D-069).

## Prompt

```text
Execute the whole roadmap of this repository (ROADMAP.md, FINAL, M1..M12) unattended, as the host Claude Code session on this Mac. Read first, in this order: GOAL.md, goal/EXECUTION.md, AGENTS.md, tasks/README.md, PROGRESS.md, PREFLIGHT-DEFECTS.md. Source of truth: ROADMAP.md, SPEC.md, DECISIONS.md, AGENTS.md. The human has completed goal/PREFLIGHT.md and is not available.

Order: milestones M1..M12; inside each, the waves of ROADMAP.md §3. A task starts when every depends_on row is done and the lane caps allow (D-056: ~/.claude 3, each Codex home 1, crew-operator 1, 6 total). Review tasks never block anything (D-055). Tasks are executed from tasks/<id>/ (TASK.md, task.toml, verify.sh). M1 tasks that precede M1-01 are executed from their ROADMAP.md row and get their folder when M1-01 runs. M6..M12 folders are authored when the milestone is reached (D-062), the same way M1-01 authors M1..M5.

Non-negotiable:
- Delegate every unit of work to subagents or role containers; this session coordinates, verifies, records (D-036). When anything stalls or takes too long, spawn subagents to analyze why and to find a solution before any other action (D-063).
- Never ask the human anything; never wait for a human review or merge; agents merge (D-055). A design question is answered with the recommended answer (D-053) and recorded in DECISIONS.md.
- Involved repositories (github.com/jackin-project/*, github.com/tailrocks/*, donbeave/jackin-*) are fixed, never worked around (D-046). Their work lands on feat/managed-execution; this repository commits to main; always `git commit -s`, push at once (D-047).
- Credentials exist only in 1Password as op:// references (D-035); no secret value in any file, log, or message. Repositories created are public (D-065). CI on GitHub-hosted runners (D-064).
- Runtime, model, account per task from ROADMAP.md §5 lanes; quota exhaustion or stuck (after the D-063 analysis) re-runs on the lane's fallback and is logged in PROGRESS.md.
- host rows: run their verify.sh in this session and file the output in the task folder (D-061). Evidence is text in tasks/<id>/; media on the Linear issue (D-059). Linear team JACKIN; M1-12 creates and assigns issues under auto-dispatch (D-060, D-067); this session is first responder to Linear escalations (D-068).

A task is done only when, in this session: `sh tasks/<id>/verify.sh` prints `status: DONE` as its last line; its row in tasks/README.md reads `done`; all changes in every touched repository are committed and pushed. Then append one row to PROGRESS.md (id, lane, result, evidence path) and commit.

A missing operator input (login, consent, credential, UI-only step, host hardware) is a preflight defect: append it to PREFLIGHT-DEFECTS.md with the exact item and the command that proves it is in place, set the task row to `blocked`, finish everything not depending on it, continue with every other runnable task.

STOP only when no task is runnable and at least one is blocked on an open PREFLIGHT-DEFECTS.md item: commit, push, print the open items, end. Never stop for a design question, a failing check, a review, or a defect in an involved project.

Done: `sh verify.sh` at the repository root prints `status: DONE` as its last line, run in the current turn after the final commit and push; the working tree is clean; PROGRESS.md has a row per task. Completion is claimed only from that output, never from memory or an earlier run.
```
