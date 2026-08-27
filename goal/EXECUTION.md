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
   `in-progress` with no `PROGRESS.md` row is an interrupted task. First
   check for a surviving run: `tmux has-session -t <id>`, `docker ps
   --filter label=<issue label>` (M3-04 labels; before M3, the jackin
   instance list for the workspace `~/.jackin/managed/<id>`), and on the
   daemon path `jackin daemon status --format json`. If one exists, resume
   waiting on it (§5 step 4) — never dispatch a second run for the same
   id. If none exists, re-run `sh tasks/<id>/verify.sh`: `status: DONE`
   closes it (§5 steps 6–7), anything else restarts it as a new attempt
   counted in the result cell (D-070). A README row not `done` whose id
   has a `done` `PROGRESS.md` row is restored to `done`, never re-run.
   Open `PREFLIGHT-DEFECTS.md` rows: run each row's proof command; when it
   passes, fill `Resolved` and set the row's task back to `ready` — the
   human need not edit the file. When the daemon path is active, reconcile
   Linear per D-073 (every `done` row's issue completed; no `in-progress`
   or `blocked` row's issue carries the delegate).
3. Run `sh verify.sh`; its last line is the current distance to done.
4. Run the standing checks of `goal/PREFLIGHT.md` §1 (Docker, `gh`,
   provider logins with a real call, `op` with stdin closed, the 1Password
   auto-lock setting, `tmux`, awake host). A failed check that the session
   can fix (for example `caffeinate` not running, `defaults -currentHost
   write com.apple.screensaver idleTime 0`) is fixed; one that needs the
   human is a preflight defect (§6).
5. Start `caffeinate -dims` in the background for the session's lifetime.
6. Pick the next runnable tasks (§3) and dispatch them (§4).

After any context compaction, repeat steps 2 and 3 before dispatching
anything: the wave state lives in the files, not in memory.

## 2. What "one task" means

- Input: `tasks/<id>/TASK.md`, `task.toml`, `verify.sh`, and the task's
  `ROADMAP.md` row. M1-01 (wave 0) writes the three files for every M1..M5
  id before any other task starts (D-072); no task runs from a bare row.
- Output: the task's changes committed and pushed in every touched
  repository (`feat/managed-execution` there, `main` in role repositories
  and here, D-047, D-074); text evidence in `tasks/<id>/` (D-059);
  `verify.sh` output filed as `tasks/<id>/verify.out` with `status: DONE`
  as its last line; the `tasks/README.md` row set to `done`; one
  `PROGRESS.md` row.
- Every task is delegated (D-036): one subagent researches the touched
  code, one subagent per checklist item implements, one subagent verifies
  against `verify.sh` and the references; the session integrates. Host
  subagents: at most three in flight; research and verification subagents
  on Claude use the cheapest model (D-071). Reviews are `crew-reviewer`
  tasks and never gate the next task (D-055).
- Stuck rule (D-063): a task that has produced no new evidence for 30
  minutes, or whose verify has failed three times in a row, gets an
  analysis pass by fresh subagents (assumption, missing input, failing
  check, environment) and the proposed fix is applied. New lines in a
  container's tmux pane, including docker build or pull output during a
  role's first load, count as evidence. Only a genuine operator input
  becomes a preflight defect; a verify that still fails after
  `limits.attempts` attempts is exhaustion (D-070, §6).

## 3. Order of work

Milestones M1..M12, waves inside each milestone exactly as `ROADMAP.md`
§3 lists them (table "Parallel waves per milestone"), with the
concurrency rules of that section (at most one task per Codex lane per
wave, at most two `~/.claude` container tasks while this session is
active, one `crew-operator` at a time, six containers total, D-056,
D-071). Runnable means every `depends_on` row is `done`; `blocked`,
`waiting`, and `in-progress` do not count, so a blocked upstream
propagates: a dependent of a `blocked` task is marked `blocked`
referencing the same `PREFLIGHT-DEFECTS.md` row, without a new row. Tasks
from a later milestone start early where §3 says they may (M3-01, M3-03,
M4-02, M4-03, M10-02, M10-03, M8-01, M11-01, M6-01). Within a wave, start
the critical-path task first (`ROADMAP.md` §3 "Critical path").

M1 wave order (D-072), with the execution path of §4 per task:

| Wave | Tasks | Path |
| --- | --- | --- |
| 0 | M1-01 | host path: subagents draft the folders, the session commits; its verify runs here |
| 1 | M1-02 | subagents on a host checkout of jackin (L1) |
| 2 | M1-02a, M1-04a | M1-02a: host commands in this session; M1-04a: Codex mechanism (§4 `container`, `the-architect --agent codex`, or the `codex exec` interim) |
| 3 | M1-05a, M1-05b, M1-05c | Codex mechanism, one per Codex home; each role verified with a throwaway load |
| 4 | M1-05d | host commands in this session (trust grants, bindings); vault and service account exist from preflight §2 and are only verified |
| 5 | M1-03, M1-06, M1-08, M1-13 | M1-03: `crew-operator` container; M1-06: verify only (login and state save done in preflight); M1-08: Codex mechanism; M1-13: subagents plus throwaway loads |
| 6 | M1-07 | `crew-operator` container |
| 7 | M1-10 | `crew-operator` container (critical path) |
| 8 | M1-09 | `crew-operator` container; needs M1-10's token and app user and M1-13's model record |
| 9 | M1-11, M1-12 | `crew-operator` container, sequential; M1-11 verify runs here (D-061) |

M6..M12 folders: when the first task of a milestone becomes runnable and
`tasks/<id>/` does not exist, run an authoring task first, in two
sequential steps: (1) same procedure as M1-01, lane L3, subagents, writes
every folder of that milestone and sets its rows `ready`; (2) re-run the
M1-12 procedure (idempotent, `crew-operator`, L5, cap 1) so every new
`ready` row has its Linear URL, labels, and relations (no delegate,
D-073). Record both in one `PROGRESS.md` row `<milestone>-00 authoring`
(the result cell lists the folder count and the issue count). It is not
a roadmap task and gets no `tasks/README.md` row. A milestone's first
task starts only after its row carries a Linear URL. Several milestones
may be authored together when their scopes are stable, but each
milestone's issues exist before its first task starts. M1-01 writes
M2..M5 rows as `ready`; authoring writes M6..M12 rows as `ready`;
`planned` is reserved for rows whose folder does not exist.

## 4. Execution paths

Exactly one path per task, chosen by this table. Record the path in the
`PROGRESS.md` row.

| Path | When | How |
| --- | --- | --- |
| `host` | `role` is `host`, or the task only changes this repository | This session runs the commands (delegating research and verification to subagents). Host-only `verify.sh` runs here and its output is filed (D-061). A host command that creates a named resource runs the corresponding `get` first and skips when present. |
| `subagents` | Claude lanes (L1..L3) only: the task changes an involved repository and needs no role-only tool (`agent-browser`, `op` inside a container, DinD) and the daemon cannot dispatch it yet (before M3-05 is merged) | In-session subagents with the lane's model, working in `~/.jackin/managed/<id>/<repo>` (clone or fetch, branch `feat/managed-execution`, D-047). They all share this session's `~/.claude`, so each such task counts against the `~/.claude` cap and an L1→L2→L3 fallback is a model change only. Codex lanes never use this path (D-082). |
| `container` | The task's scope or verify names a role container, `agent-browser`, `jackin-exec`, or the profile mount (every `crew-operator` task; role smoke tests), or the task's lane is a Codex lane (L4..L6), and the daemon cannot dispatch it yet | From the prepared workspace: `tmux new-session -d -s <id> -x 200 -y 50 "env -u CI TERM=xterm-256color JACKIN_NO_MOTION=1 CODEX_HOME=<lane home> jackin load <role> --agent <runtime>"` (Codex lanes; Claude lanes set `CLAUDE_CONFIG_DIR` instead). `<role>` is the task's role, or `the-architect` for the bootstrap tasks M1-04a and M1-05a..c (`ROADMAP.md` §4). Preconditions so no dialog appears: trust granted (M1-05d), every manifest `[env]` var satisfied, no mount source under jackin's sensitive list. Poll `tmux capture-pane -p -t <id>` every 5 s until the capsule tab strip and the runtime's input prompt are visible (15-minute budget for a cold build); only then `tmux send-keys -t <id> -l '<prompt>'` followed by `tmux send-keys -t <id> Enter`. Prompt shape: the `ROADMAP.md` `delivery` column (`goal` → `/goal Read this file: tasks/<id>/TASK.md — implement it fully until sh verify.sh prints status: DONE`; `prompt` → `TASK.md` content verbatim). Read progress with `capture-pane -p -S -200`; when `verify.sh` is `DONE` run `jackin eject <role>` (so the next load never meets the restore picker) then `tmux kill-session -t <id>`. Interim when no loadable role exists (M1-04a before `the-architect` supports the task, or a D-046 gap): a detached `tmux` session running `CODEX_HOME=<home> codex exec --dangerously-bypass-approvals-and-sandbox -C ~/.jackin/managed/<id>/<repo> -c model_reasoning_effort=medium "$(cat tasks/<id>/TASK.md)" 2>&1 \| tee tasks/<id>/codex.log`; the session reads the log and runs `verify.sh` here. One process per Codex home at a time. |
| `daemon` | From the moment M3-05 and M3-06 are merged on `feat/managed-execution`, the branch build is installed, and `jackin daemon status` answers on this host, for every M2+ task whose row carries a Linear URL and whose delivery the daemon supports at that time (M4-01 for prompt delivery, M7-01 for verify, M8-02 for PRs, D-073) | This session delegates the issue to jackin (`issueUpdate(delegateId)` with the workspace token via host `op read`, D-023 holds) when the task becomes runnable, watches `jackin daemon status --format json` and Linear, answers elicitations by PTY injection through `jackin hardline <instance>` or `jackin daemon exec` (never as a Linear `prompt`, which only a human actor can post; Linear-UI replies are made by the proof task's own `crew-operator`), applies the stuck rule, and files evidence when the run reaches `done`. Nothing is started by hand that the daemon can dispatch; a task the daemon cannot serve takes the `subagents` or `container` path with no delegate set. Before the first daemon start against the real workspace, and at every session start, reconcile per D-073. |

Capsule dialogs on the `container` path (D-082) — the session answers
them itself from the capture, never files them as preflight defects, and
records every unexpected one in the task folder as a jackin gap owned by
M3-01: role or branch trust → confirm (should not appear after M1-05d);
jackin-exec credential picker → verify the displayed command is the task's
expected `jackin-exec op …` invocation and the binding is
`OP_SERVICE_ACCOUNT_TOKEN`, then `tmux send-keys -t <id> Space` followed
by `tmux send-keys -t <id> Enter` (Space first: rows start unselected);
any other command → `Escape` and the stuck rule; skippable env prompt →
`Enter` on empty; restore picker → new instance; exit or restore dialog on
agent exit → confirm exit. The picker works on OrbStack (the `SO_PEERCRED`
check is Linux-only inside the container). From the daemon path on, the
picker is a jackin gap owned by M3-01/M4-03: a launch option pre-approving
the configured on-demand bindings; M11-01 stays on the `container` path
until it exists.

Rules that hold on every path:

- Lane assignment is `ROADMAP.md` §5. Before M1-13 exists, pass no model
  flag (the account home's default model is the lane's model) and pin
  effort with `CLAUDE_CODE_EFFORT_LEVEL=medium` / Codex
  `model_reasoning_effort = "medium"`; M1-13 is the first task that pins a
  model id (D-078). After M1-13, use its workspace profile for `container`
  and `daemon` launches.
- Fallback (D-057, D-071): a quota-exhausted attempt is re-run at once on
  the next lane of another account home (L1/L2/L3 → L4 → L5 → L6 → L1;
  L4 → L5 → L6 → L1; …), consuming no attempt; a stuck attempt is re-run,
  after the D-063 analysis, on the lane's `fallback` column. Each hop is
  one entry in the `PROGRESS.md` row's `result` cell (`L1 quota → L4`).
  A fallback that crosses runtimes changes the mechanism (`subagents` ↔
  `container`), never silently: the lane cell names where the work ran
  (`L4 → L1 (host)`). A chain fully throttled makes the row `waiting`:
  read the earliest reset (`jackin usage host accounts --format json`
  where exposed, else the runtime's limit message, else 30 minutes), wait
  with a Monitor loop, retry. Never a defect, never a STOP.
- Provider limit on this session (D-071): a 5-hour-window limit message
  here is neither a defect nor a failure; record the reset time in
  `PROGRESS.md`, keep dispatched containers running, poll `claude -p ok`
  under `CLAUDE_CONFIG_DIR=~/.claude` with a Monitor loop, resume; spawn no
  D-063 subagents until reset. Only a weekly-cap message with a reset more
  than 24 hours away is a preflight defect (billing action).
- Nothing an involved project lacks is worked around: a missing jackin
  capability needed by a path (for example non-interactive prompt
  delivery, the `--on-demand` env flag, pre-approved on-demand bindings)
  is built in jackin on `feat/managed-execution` as part of the roadmap
  task that owns it (M3-01, M4-01, M4-03), and `tmux` is the interim path,
  not a permanent one (D-046).
- Every container path reuses the host's forwarded `gh` login and never
  sees the Linear token or a 1Password secret value (D-023, D-035).
- Branches (D-074): before every push to `feat/managed-execution`, `git
  fetch origin && git rebase origin/feat/managed-execution` (up to five
  retries), never `--force`. Role repositories (`donbeave/jackin-crew-*`,
  `donbeave/jackin-role-template`) commit directly to `main`;
  `jackin-the-architect` changes are merged from `feat/managed-execution`
  to `main` in the same task; every role change ends with `jackin load
  <role> --rebuild`. No pull request from `feat/managed-execution` to
  `main` is merged in `jackin` or `termrock` during this run unless the
  task's scope names the merge; if one is, the same task merges
  `origin/main` back into the branch and pushes it.
- Forwarded logins (D-082): a login failure inside a container is a
  preflight defect only when the host-side probe also fails (`claude -p
  ok` under the lane's `CLAUDE_CONFIG_DIR`; `codex exec 'print ok'` under
  the lane's `CODEX_HOME`); otherwise re-launch the attempt so the fresh
  host state is re-synced and note `re-sync` in the result cell.

## 5. Per-task procedure

1. Set the `tasks/README.md` row to `in-progress`; commit and push. If the
   task is M2+ and its row has no Linear URL, run the M1-12 procedure
   first (idempotent, `crew-operator`, L5, cap 1); a task without an issue
   is never dispatched on any path once the daemon path is active.
2. Read `TASK.md` and its `preflight` section; check every item with its
   stated command. Missing item → §6, then continue with what does not
   depend on it.
3. Dispatch on the path of §4 with the lane's runtime, model, and account.
4. Wait for evidence; apply the stuck rule (§2) on stall.
5. Run `sh tasks/<id>/verify.sh`. In-container part: through the task's
   own runner (`jackin daemon exec` from M4-03; before that `tmux
   send-keys` and `capture-pane`) for container and daemon paths; here for
   host and subagent paths. Host part (`host (D-061):` sentence of the
   verify column, or any check that needs the Linear token, `op`, the
   daemon socket, or host `docker`): here, always (D-081). Concatenate both
   outputs into `tasks/<id>/verify.out`; the last line must be `status:
   DONE` (the host part's verdict when one exists). Otherwise fix and
   repeat: after the D-063 analysis, the next attempt runs on the next
   lane of the D-057 chain; after `limits.attempts` attempts (default 3,
   `task.toml`; `SPEC.md` §6 step 8) without wrapping past the starting
   lane, the task is exhausted (§6, D-070). `verify.sh` runs with `set +x`,
   never `curl -v`/`--trace`, secrets only via `-H @-`/`--config -` from
   stdin.
6. Confirm every touched repository is committed and pushed on the right
   branch (`git status --porcelain` empty, `git log origin/<branch>..`
   empty; role repositories on `main`, D-074).
6a. Before a `crew-reviewer` task launches: ensure one open, non-draft
   PR `feat/managed-execution` → `main` exists in each repository the
   review covers (`gh pr list --head feat/managed-execution --state open`,
   else `gh pr create --title feat/managed-execution --body "Rolling PR;
   reviewed per milestone (D-055, D-074)"`); write its URL and the current
   head SHA to `tasks/<review-id>/pr.txt`, plus the SHA the previous
   review recorded so the review covers the diff since then. After the
   review, the session appends the checklist lines of the reviewer's final
   message to the reviewed Linear issue (M6-02 write-back once it exists,
   before that `issueUpdate` via host `op read`).
6b. Scan the evidence before committing: `gitleaks detect --no-git
   --source tasks/<id>` or the D-081 regex over every file in the folder;
   a hit deletes the file, files a preflight defect naming the credential
   to rotate, and blocks the commit.
7. Set the row to `done`; if the task has a Linear issue and the daemon did
   not finish it (every path before M9-01 is merged and running; any
   non-`daemon` path afterwards), move the issue to the team's
   `completed`-type state (`issueUpdate` with the workspace token via host
   `op read`, D-023 holds; query `team.states` by `type`), post one
   `response` activity on its session, remove any `run:*` label (D-073);
   append the `PROGRESS.md` row; commit and push this repository.
8. If the task is a proof run or created a scratch issue: close the
   scratch issue, attach media to the issue (D-059), and record the URL in
   the task folder. Live daemon runs in M2 and M3 touch scratch issues
   only; the task asserts by GraphQL that no roadmap issue changed state.
9. Start the next runnable tasks.

`PROGRESS.md` row format (one line, no prose):

```text
| <id> | <lane; where the work actually ran, e.g. L4 → L1 (host)> | <path> | <done|blocked|waiting> — <attempts n/limit, fallbacks, re-sync> | tasks/<id>/verify.out | <UTC timestamp> |
```

## 6. Preflight defects, exhaustion, and BLOCKED

A preflight defect is an operator input that only the human can provide:
a login or OTP, a consent screen, a GitHub sudo-mode or Google re-auth
prompt, a credential created in a UI, a physical host or device, a billing
action (including a weekly provider cap). It is never: a failing test, a
design choice (apply D-053), a defect in an involved project (fix it,
D-046), a missing tool that `brew install` provides, a review, a lane
fallback or quota wait (D-071), a capsule dialog (D-082), a golden-frame
blessing (D-075), or a 1Password lock the session can prove is a settings
issue (then it is the §1 auto-lock item).

Exhaustion (D-070) is the second reason a row is `blocked`: `verify.sh`
still fails after `limits.attempts` attempts, each on the next lane of the
D-057 chain and each preceded by the D-063 analysis with fresh subagents.
It is filed in `PREFLIGHT-DEFECTS.md` as `exhausted: <id>` with the last
`tasks/<id>/verify.out` path and the analysis summary in the "Missing
item" cell; the proof command is `sh tasks/<id>/verify.sh`. The human
resolves it like a defect (fixes the cause or edits the task) and re-runs
`/goal Follow GOAL.md`. On the daemon path, a blocker elicitation (M7-03)
the session cannot answer is filed the same way instead of waiting.

Handling: append the row (task, exact item, the command or UI path that
proves it is in place), set the task row to `blocked`, finish the parts of
the task that do not depend on it, commit, and continue with every other
runnable task. The run ends BLOCKED only when no task is runnable and at
least one is `blocked`: commit, push, print `GOAL BLOCKED` followed by the
open rows of `PREFLIGHT-DEFECTS.md`, and end. The human clears the items
(or leaves the `Resolved` cell empty — the session re-runs each proof
command at the next start and fills it) and re-runs `/goal Follow
GOAL.md`; the session sets those rows back to `ready` and resumes.

## 7. Done

The run ends in exactly one of two outcomes (D-070). COMPLETE: `sh
verify.sh` at the repository root prints `status: DONE` as its last line
in the current turn after the final commit and push, the tree is clean,
and `PROGRESS.md` has one row per roadmap task. BLOCKED: as §6. In both
cases the final message lists: tasks done, preflight defects open and
resolved, fallbacks and waits taken, repositories touched with their
`feat/managed-execution` (or `main`, D-074) head commits, and the Linear
project URL.
