# Execution guide for the `/goal` run

Read by the host Claude Code session after `GOAL.md`. It restates nothing
that `ROADMAP.md`, `SPEC.md`, or `DECISIONS.md` decide; it only wires the
prompt in `GOAL.md` to those files and fixes the mechanical procedure so
every run behaves the same way. Where this file and a decision disagree,
the decision wins and this file is corrected in the same commit.

## 1. Session start (every run, including a resume)

1. `git pull --ff-only origin main`; refuse to work on a dirty tree
   (commit or stash-drop leftovers from a crashed run first, then record
   what happened in `PROGRESS.md`).
2. Read `tasks/README.md`, `PROGRESS.md`, `PREFLIGHT-DEFECTS.md`. A row
   `in-progress` with no `PROGRESS.md` row is an interrupted task: re-run
   its `verify.sh`; `status: DONE` closes it, anything else restarts it.
3. Run `sh verify.sh`; its last line is the current distance to done.
4. Run the standing checks of `goal/PREFLIGHT.md` §1 (Docker, `gh`,
   provider logins, `op`, `tmux`, awake host). A failed check that the
   session can fix (for example `caffeinate` not running) is fixed; one
   that needs the human is a preflight defect (§6).
5. Start `caffeinate -dims` in the background for the session's lifetime.
6. Pick the next runnable tasks (§3) and dispatch them (§4).

## 2. What "one task" means

- Input: `tasks/<id>/TASK.md`, `task.toml`, `verify.sh`, and the task's
  `ROADMAP.md` row. Before M1-01 has run, the row alone is the input and
  the four files are written by M1-01 afterwards from what was done.
- Output: the task's changes committed and pushed in every touched
  repository (`feat/managed-execution` there, `main` here, D-047); text
  evidence in `tasks/<id>/` (D-059); `verify.sh` output filed as
  `tasks/<id>/verify.out` with `status: DONE` as its last line; the
  `tasks/README.md` row set to `done`; one `PROGRESS.md` row.
- Every task is delegated (D-036): one subagent researches the touched
  code, one subagent per checklist item implements, one subagent verifies
  against `verify.sh` and the references; the session integrates. Reviews
  are `crew-reviewer` tasks and never gate the next task (D-055).
- Stuck rule (D-063): a task that has produced no new evidence for 30
  minutes, or whose verify has failed three times in a row, gets an
  analysis pass by fresh subagents (assumption, missing input, failing
  check, environment) and the proposed fix is applied. Only a genuine
  operator input becomes a preflight defect.

## 3. Order of work

Milestones M1..M12, waves inside each milestone exactly as `ROADMAP.md`
§3 lists them (table "Parallel waves per milestone"), with the
concurrency rules of that section (at most one task per Codex lane per
wave, at most three `~/.claude` tasks, one `crew-operator` at a time,
six containers total, D-056). Tasks from a later milestone start early
where §3 says they may (M3-01, M3-03, M4-02, M4-03, M10-02, M10-03,
M8-01, M11-01, M6-01). Within a wave, start the critical-path task first
(`ROADMAP.md` §3 "Critical path").

M1 wave order, with the execution path of §4 per task:

| Wave | Tasks | Path |
| --- | --- | --- |
| 1 | M1-02 | subagents on a host checkout of jackin |
| 2 | M1-02a, M1-04a | M1-02a: host commands in this session; M1-04a: subagents |
| 3 | M1-05a, M1-05b, M1-05c | subagents; each role verified with `jackin load … --dry-run` and a throwaway load |
| 4 | M1-05d | host commands in this session (trust grants, vault, bindings); the service account was created in preflight |
| 5 | M1-01, M1-03, M1-06, M1-08, M1-13 | M1-01, M1-08: subagents; M1-03: `crew-operator` container; M1-06: verify only (login done in preflight); M1-13: subagents plus throwaway loads |
| 6 | M1-07 | `crew-operator` container |
| 7 | M1-09, M1-10 | `crew-operator` container, sequential (cap 1) |
| 8 | M1-11, M1-12 | `crew-operator` container, sequential; M1-11 verify runs here (D-061) |

M6..M12 folders: when the first task of a milestone becomes runnable and
`tasks/<id>/` does not exist, run an authoring task first (same procedure
as M1-01, lane L3, `crew-builder`) that writes every folder of that
milestone; record it in `PROGRESS.md` as `<milestone>-00 authoring`.
It is not a roadmap task and gets no `tasks/README.md` row.

## 4. Execution paths

Exactly one path per task, chosen by this table. Record the path in the
`PROGRESS.md` row.

| Path | When | How |
| --- | --- | --- |
| `host` | `role` is `host`, or the task only changes this repository | This session runs the commands (delegating research and verification to subagents). Host-only `verify.sh` runs here and its output is filed (D-061). |
| `subagents` | The task changes an involved repository and needs no role-only tool (`agent-browser`, `op` inside a container, DinD) and the daemon cannot dispatch it yet | Subagents work in `~/.jackin/managed/<id>/<repo>` (clone or fetch, branch `feat/managed-execution`, D-047) on the lane's runtime and model, using the lane's account home (`CLAUDE_CONFIG_DIR` / `CODEX_HOME` of `ROADMAP.md` §5). |
| `container` | The task's scope or verify names a role container, `agent-browser`, `jackin-exec`, or the profile mount (every `crew-operator` task; role smoke tests) and the daemon cannot dispatch it yet | `tmux new-session -d -s <id> "jackin load <role> --agent <runtime> …"` in the prepared workspace, the task prompt delivered with `tmux send-keys`, progress read with `tmux capture-pane -p`, the session killed when `verify.sh` is `DONE`. Prompt shape: the `ROADMAP.md` `delivery` column (`goal` → `/goal Read this file: tasks/<id>/TASK.md — implement it fully until sh verify.sh prints status: DONE`; `prompt` → `TASK.md` content verbatim). |
| `daemon` | From the moment M3-05 is merged on `feat/managed-execution` and the daemon runs on this host, for every task that has a Linear issue (M2 onward, created by M1-12) | The issue is already assigned under `auto-dispatch` (D-067); this session watches `jackin daemon status --format json` and Linear, answers elicitations it can answer, applies the stuck rule, and files evidence when the run reaches `done`. Nothing is started by hand that the daemon can dispatch. |

Rules that hold on every path:

- Lane assignment is `ROADMAP.md` §5; before M1-13 exists, the lane's
  runtime and account home are set by hand with the same environment
  variables M1-13 later pins. After M1-13, use its workspace profile.
- Fallback (D-057): after the D-063 analysis, a quota-exhausted or stuck
  attempt is re-run on the lane's `fallback` column; each attempt is one
  line in the `PROGRESS.md` row's `result` cell (`L1 quota → L2`).
- Nothing an involved project lacks is worked around: a missing jackin
  capability needed by a path (for example non-interactive prompt
  delivery) is built in jackin on `feat/managed-execution` as part of the
  roadmap task that owns it (M3-01, M4-01, M4-03), and `tmux` is the
  interim path, not a permanent one (D-046).
- Every container path reuses the host's forwarded `gh` login and never
  sees the Linear token or a 1Password secret value (D-023, D-035).

## 5. Per-task procedure

1. Set the `tasks/README.md` row to `in-progress`; commit and push.
2. Read `TASK.md` (or the roadmap row) and its `preflight` section; check
   every item with its stated command. Missing item → §6, then continue
   with what does not depend on it.
3. Dispatch on the path of §4 with the lane's runtime, model, and account.
4. Wait for evidence; apply the stuck rule (§2) on stall.
5. Run `sh tasks/<id>/verify.sh` (inside the container for container and
   daemon paths via the task's own runner; here for host and subagent
   paths). Save the output as `tasks/<id>/verify.out`. Last line must be
   `status: DONE`; otherwise fix and repeat (fallback lane after the
   D-063 analysis, at most the D-027 attempt cap).
6. Confirm every touched repository is committed and pushed on the right
   branch (`git status --porcelain` empty, `git log origin/<branch>..`
   empty).
7. Set the row to `done`; append the `PROGRESS.md` row; commit and push
   this repository.
8. If the task is a proof run or created a Linear issue: close the scratch
   issue, attach media to the issue (D-059), and record the URL in the
   task folder.
9. Start the next runnable tasks.

`PROGRESS.md` row format (one line, no prose):

```text
| <id> | <lane or host> | <path> | <done|blocked> — <attempts, fallbacks> | tasks/<id>/verify.out | <UTC timestamp> |
```

## 6. Preflight defects and STOP

A preflight defect is an operator input that only the human can provide:
a login or OTP, a consent screen, a credential created in a UI, a physical
host or device, a billing action. It is never: a failing test, a design
choice (apply D-053), a defect in an involved project (fix it, D-046), a
missing tool that `brew install` provides, or a review.

Handling: append a row to `PREFLIGHT-DEFECTS.md` (task, exact item, the
command or UI path that proves it is in place), set the task row to
`blocked`, finish the parts of the task that do not depend on it, commit,
and continue with every other runnable task. The session stops only when
no task is runnable and at least one is `blocked`: it commits, pushes,
prints the open rows of `PREFLIGHT-DEFECTS.md`, and ends. The human clears
the items, marks them resolved in the same file, and re-runs
`/goal Follow GOAL.md`; the session then sets those rows back to `ready`
and resumes.

## 7. Done

The goal is complete when `sh verify.sh` at the repository root prints
`status: DONE` as its last line in the current turn after the final commit
and push, the tree is clean, and `PROGRESS.md` has one row per roadmap
task. The final message lists: tasks done, preflight defects resolved,
fallbacks taken, repositories touched with their `feat/managed-execution`
head commits, and the Linear project URL.
