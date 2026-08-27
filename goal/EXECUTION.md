# Execution guide for the `/goal` run

Read by the host Claude Code session after `GOAL.md`. It restates nothing
that `ROADMAP.md`, `SPEC.md`, or `DECISIONS.md` decide; it only wires the
prompt in `GOAL.md` to those files and fixes the mechanical procedure so
every run behaves the same way. Where this file and a decision disagree,
the decision wins and this file is corrected in the same commit.

## 1. Session start (every run, including a resume or a re-prompt)

The run is started by the one invocation line printed in `README.md` "Start
the run", copied verbatim, in a Claude Code session opened in this
repository after the human has completed `goal/PREFLIGHT.md` §1..§5. It is
never shortened to `/goal Follow GOAL.md`: the argument carries the two
terminal facts the runner's judge checks (D-083). `GOAL.md` holds the
prompt the runner executes and nothing else; every document that says "the
invocation line of `GOAL.md`" means that line in `README.md`. Re-running it
after a BLOCKED end, a crash, or a context compaction resumes the run:
steps 1–4 below re-derive the whole state and nothing finished is redone.
The two outcomes are §7.

1. `git fetch origin && git rebase origin/main` in this repository (never
   `--force`; a diverged local tree is rebased onto `origin/main`, not
   refused). Refuse to work on a dirty tree: commit or stash-drop leftovers
   from a crashed run first, then record what happened in `PROGRESS.md`.
2. Read `tasks/README.md`, `PROGRESS.md`, `PREFLIGHT-DEFECTS.md`. A row
   `in-progress` with no `PROGRESS.md` row is an interrupted task. First
   check for a surviving run: `tmux has-session -t <id>`, `docker ps
   --filter label=<issue label>` (M3-04 labels; before M3, `docker ps
   --format '{{.Names}}'` for the name in `tasks/<id>/container.txt`), and
   on the daemon path `jackin daemon status --format json`. A surviving
   tmux session whose capture shows the runtime idle at its prompt with the
   task prompt already answered is a finished attempt, not a running one:
   go to §5 step 5 at once. One whose pane is still working is resumed (§5
   step 4). One whose pane is dead, or whose agent exited, is torn down (§4
   container row) and the task restarts as a new attempt. Never dispatch a
   second run for the same id. If no run survives, run §5 step 5:
   `status: DONE` closes the task (§5 steps 6–7), anything else restarts it
   as a new attempt counted in the result cell (D-070). A README row not
   `done` whose id has a `done` `PROGRESS.md` row is restored to `done`,
   never re-run.
   Open `PREFLIGHT-DEFECTS.md` rows (D-084, D-093): a missing-input row
   has a proof command — run it; when it passes, fill `Resolved` and set
   that row's task back to `ready`. An `exhausted: <id>` row has no proof
   command (its proof cell reads `re-run`) and is closed by the human
   alone: while its `Resolved` cell is empty the task stays `blocked` and
   is never re-attempted — never fill that cell, never open an epoch on
   your own. When the human has filled it, set the task to `ready` and
   open a new attempt epoch (`epoch 2: 0/3` in the result cell and a new
   `epoch` line in `tasks/<id>/attempts.log`; `limits.attempts` applies
   per epoch); if `sh tasks/<id>/verify.sh host` already passes because
   the human finished the task by hand, close it through §5 steps 6–7
   instead.
   Invariant: a `blocked` row whose id appears in no open
   `PREFLIGHT-DEFECTS.md` row is set to `ready`. When the daemon path is
   active, reconcile Linear per D-073 (every `done` row's issue completed;
   no `in-progress` or `blocked` row's issue carries the delegate).
3. Run `sh verify.sh`; its last line is the current distance to done.
4. Run the standing checks of `goal/PREFLIGHT.md` §1 (Docker, `gh`,
   provider logins with a real call, `op` with stdin closed, the 1Password
   auto-lock setting, `tmux`, `dash`, `shellcheck`, awake host, the
   usage-limit auto-continue setting). Two more standing checks: the
   installed `jackin --version` embeds the sha of
   `origin/feat/managed-execution` in the jackin checkout of
   `tasks/M1-02/checkout.txt` (from wave 1 on; otherwise refresh per §5 step
   4a), and the `~/.claude` session bucket has headroom (§4 reserve rule:
   below 40 % the caps shrink, below 20 % only Codex lanes dispatch). A
   failed check that the session can fix (for example `caffeinate` not
   running, `defaults -currentHost write com.apple.screensaver idleTime 0`)
   is fixed; one that needs the human is a preflight defect (§6).
5. Start `caffeinate -dims` in the background for the session's lifetime.
6. Pick the next runnable tasks (§3) and dispatch them (§4). After a
   re-prompt that follows a BLOCKED end: if steps 2–4 made nothing
   runnable, print the same `GOAL BLOCKED` block (§7) and end the turn.

After any context compaction, and after any re-prompt, re-read `GOAL.md`
and this file's §1 and §5, then repeat steps 2 and 3 before dispatching
anything. The whole state of the run is re-derived from `tasks/README.md`,
`PROGRESS.md`, `tasks/<id>/attempts.log`, and `git log` — never from
memory, and never by re-reading `ROADMAP.md`, `SPEC.md`, or `DECISIONS.md`
in this session (§8, D-092, D-093).

## 2. What "one task" means

- Input: `tasks/<id>/TASK.md`, `task.toml`, `verify.sh`, and the task's
  `ROADMAP.md` row. M1-01 (wave 0) writes the three files for every M1..M5
  id before any other task starts (D-072); no task runs from a bare row.
  `TASK.md` references other files container-relative as
  `.jackin/task/refs/<name>` (`concept/task-format.md`), because the
  container never sees this repository.
- Workspace: the touched repository checkout under
  `~/.jackin/managed/<id>/<repo>` (D-047; for operator tasks the evidence
  directory `~/.jackin/managed/<id>/`), registered once as the saved
  jackin workspace `task-<id>` (workdir and one shared mount
  `~/.jackin/managed/<id>`) that carries the lane's account, env, and
  grants (§4, D-085).
- Output: the task's changes committed and pushed in every touched
  repository (`feat/managed-execution` there, `main` in role repositories,
  D-047, D-074); text evidence in `tasks/<id>/` (D-059); the composite
  `tasks/<id>/verify.out` (container part, then host part) with
  `status: DONE` as its last line; the `tasks/README.md` row set to `done`;
  one `PROGRESS.md` row. This repository has one writer: this session
  (D-086). A container, subagent, or daemon task whose `repos` include
  `ecosystem` never pushes it; it leaves its changes in
  `~/.jackin/managed/<id>/ecosystem` or emits files (for example
  `tasks/M1-12/issues.json`), and the session imports them (`git -C
  ~/.jackin/managed/<id>/ecosystem diff origin/main | git apply`, or a copy
  of `tasks/<id>/`), scans them (§5 step 6b), and commits them in §5
  step 7.
- Every task is delegated (D-036, D-092): one subagent researches the
  touched code, one subagent per checklist item implements, one subagent
  verifies against `verify.sh` and the references; the session integrates.
  Every host subagent is launched with `model: "claude-opus-5"` (D-095),
  whatever it does,
  and returns at most 15 lines (verdict, evidence paths, next action).
  Host subagents: at most three in flight (fewer under the §4 reserve
  rule). Reviews are `crew-reviewer` tasks and never gate the next task
  (D-055).
- Stuck rule (D-063): a task that has produced no new evidence for 30
  minutes, or whose verify has failed three times in a row, gets an
  analysis pass by fresh subagents (assumption, missing input, failing
  check, environment) and the proposed fix is applied. New lines in a
  container's tmux pane, including docker build or pull output during a
  role's first load, count as evidence; time this session spends limited
  (§4) does not count against any task's clock. Only a genuine operator
  input becomes a preflight defect; a verify that still fails after
  `limits.attempts` attempts in the current epoch is exhaustion (D-070,
  D-084, §6).

## 3. Order of work

Milestones M1..M12. M1..M5 waves exactly as `ROADMAP.md` §3 lists them
(table "Parallel waves per milestone"); M6..M12 waves are derived from
`depends_on` and the lane caps, honouring the early-start notes of the
M6..M12 row. Concurrency rules of that section: at most one task per Codex
lane per wave, at most two `~/.claude` container tasks while this session
is active, one `crew-operator` at a time, six containers total (D-056,
D-071). The caps count every running container, including a throwaway
`jackin load` inside a task (M1-05a..c, M1-06, M1-13): a task that loads a
lane or the operator role holds that resource for the load's duration, and
before every load the session checks `docker ps` for a live container on
the same account home or role.

Runnable predicate (D-119). A `tasks/README.md` row is runnable iff: its
status is `ready`; every `depends_on` id is `done`; a lane slot is free
under the caps — at most two host subagents drawing on `~/.claude` and at
most three host subagents in flight (D-071) — plus the §4 reserve rule of
`goal/EXECUTION.md`; and, for M2+ ids other than M3-01, M3-03, M4-02,
M4-03, the M1-12 row is `done` (D-088). Rows `planned`, `blocked`,
`waiting` or `in-progress` are not runnable and do not count as `done`
(D-084).

A dependent of a `blocked` task keeps its own status (`ready`) and gets no
row of its own in `PREFLIGHT-DEFECTS.md`. Tasks from a later milestone
start early where `ROADMAP.md` §3 says they may (M3-01, M3-03, M4-02,
M4-03 after their `depends_on`; M6-01, M8-01, M10-02, M10-03 after M1-12
is `done` and their milestone is authored). Priority: within a wave the
critical-path task first (`ROADMAP.md` §3 "Critical path"); across milestones, a runnable task of
the lowest unfinished milestone always takes a free slot before an
early-start task of a later milestone, and early-start tasks fill only
slots that would otherwise idle (L4 stays free for M1-04a, M1-05a, M1-08
until M1-08 is done).

M1 wave order (D-072 as amended by D-088), with the execution path of §4
per task:

| Wave | Tasks | Path |
| --- | --- | --- |
| 0 | M1-01 | host path: subagents draft the folders, the session commits; its verify runs here |
| 1 | M1-02 | subagents on a host checkout of jackin (L1); records `tasks/M1-02/checkout.txt` |
| 2 | M1-02a, M1-04a | M1-02a: host commands in this session, including the six lane templates of D-085; M1-04a: Codex mechanism (§4 `container`, `the-architect --agent codex` in workspace `task-M1-04a`, or the `codex exec` interim) |
| 3 | M1-05a, M1-05b, M1-05c | Codex mechanism, one per Codex home; each role verified with a throwaway load |
| 4 | M1-05d | host commands in this session (trust grants, bindings); vault and service account exist from preflight §2 and are only verified |
| 5 | M1-06, M1-08 | M1-06: host, with one throwaway `crew-operator` load (the load ejects before wave 5b starts); M1-08: Codex mechanism on L4 |
| 5b | M1-03, M1-13 | M1-03: `crew-operator` container on L6; M1-13: subagents plus throwaway loads, one at a time, each only when its lane's account home has no running container (L4 only after M1-08 ejected, L6 only after M1-03 ejected, at most one `~/.claude` throwaway at a time, the operator throwaway only when no other `crew-operator` container exists) |
| 6 | M1-07 | `crew-operator` container |
| 7 | M1-10 | `crew-operator` container (critical path) |
| 8 | M1-09 | `crew-operator` container; needs M1-10's token and app user and `tasks/M1-13/lanes.json` |
| 9 | M1-11, M1-12 | `crew-operator` container, sequential; M1-11 verify runs here (D-061) |

M6..M12 folders: no authoring and no M6..M12 task begins before the M1-12
row is `done`. When the first task of a milestone would otherwise be
runnable and `tasks/<id>/` does not exist, run an authoring task first, in
two sequential steps: (1) same procedure as M1-01, lane L3, subagents,
writes every folder of that milestone (idempotent: existing folders are
kept) and sets its rows `ready`, checked with the M1-01 verify shape for
that milestone; (2) re-run the M1-12 procedure from `tasks/M1-12/`
(idempotent, `crew-operator`, L5, cap 1) so every new row has its Linear
URL, labels, and relations (no delegate, D-073), checked with the M1-12
verify. Record both in one `PROGRESS.md` row `<milestone>-00 authoring`
(the result cell lists the folder count and the issue count). It is not a
roadmap task and gets no `tasks/README.md` row, but it has a terminal
state: a step that fails its check three times is filed `exhausted:
<milestone>-00` in `PREFLIGHT-DEFECTS.md` and the milestone's rows stay
`planned`. A milestone's first task starts only after its row carries a
Linear URL; the four early-start tasks named above may run before M1-12
exists, and M1-12 creates their issues afterwards. Several milestones may
be authored together when their scopes are stable, but each milestone's
issues exist before its first task starts. M1-01 writes M2..M5 rows as
`ready`; authoring writes M6..M12 rows as `ready`; `planned` is reserved
for rows whose folder does not exist.

## 4. Execution paths

Exactly one path per task, chosen by this table. Record the path in the
`PROGRESS.md` row. Decide in this order, first match wins:

1. `role` is `host`, or the task's `repos` are only `ecosystem` → `host`.
2. The daemon can serve it (row conditions below) → `daemon`.
3. The task's lane is a Codex lane (L4, L5, L6) → `container`, always; a
   Codex lane is never run as a Claude subagent (D-082).
4. The task's scope or verify names a role container, `agent-browser`,
   `jackin-exec`, DinD, or the profile mount → `container`.
5. Otherwise the lane is a Claude lane (L1, L2, L3) → `subagents`,
   except a verify that launches or attaches a jackin instance, which is a
   host part and runs here (D-091).

| Path | When | How |
| --- | --- | --- |
| `host` | `role` is `host`, or the task only changes this repository | This session runs the commands (delegating research and verification to subagents). Host-only `verify.sh` runs here and its output is filed (D-061). A host command that creates a named resource runs the corresponding `get` first and skips when present. Only this session commits to this repository (D-086). |
| `subagents` | Claude lanes (L1..L3) only: the task changes an involved repository and needs no role-only tool (`agent-browser`, `op` inside a container, DinD) and the daemon cannot dispatch it yet (before M3-05 is merged) | In-session subagents with the lane's model, working in `~/.jackin/managed/<id>/<repo>` (clone or fetch, branch `feat/managed-execution`, D-047). They all share this session's `~/.claude`, so each such task counts against the `~/.claude` cap and an L1→L2→L3 fallback is a model change only. Codex lanes never use this path (D-082). A task whose verify launches or attaches to a jackin instance takes this path (host Docker) before M3-05, never `container` (D-091). |
| `container` | The task's scope or verify names a role container, `agent-browser`, `jackin-exec`, or the profile mount (every `crew-operator` task; role smoke tests), or the task's lane is a Codex lane (L4..L6), and the daemon cannot dispatch it yet | **Workspace (D-085).** `jackin workspace show task-<id>` or, when absent, `jackin workspace create task-<id> --workdir ~/.jackin/managed/<id> --mount ~/.jackin/managed/<id>`; then merge the lane template into `~/.config/jackin/workspaces/task-<id>.toml`: `tasks/M1-13/lanes/L<n>.toml` once M1-13 is done, before that `tasks/M1-02a/lanes/L<n>.toml` (only `[codex] sync_source_dir` or `[claude] sync_source_dir`; that is the sole account selector before M1-13, and host `CODEX_HOME`/`CLAUDE_CONFIG_DIR` select nothing in `jackin load`). `jackin load <role> task-<id> --agent <runtime> --dry-run --format json` must report `.data.workspace == "task-<id>"`; an ad-hoc load (no workspace name) is a plan defect, never retried. **Staging.** `mkdir -p <ws>/.jackin/task && cp tasks/<id>/TASK.md tasks/<id>/task.toml tasks/<id>/verify.sh <ws>/.jackin/task/`, the `## References` files into `<ws>/.jackin/task/refs/`, `tasks/<id>/pr.txt` for reviews, and `echo .jackin/ >> <ws>/.git/info/exclude` (for the read-only reviewer mount the copy is still host-side). **Teardown before any launch of the same id** (retry, fallback, re-sync, resume): `tmux kill-session -t <id>` if `has-session` succeeds, then `jackin eject "$(cat tasks/<id>/container.txt)"` if that file names a live container; never start a second load for the same id while one is loaded. **Launch.** `tmux new-session -d -s <id> -x 200 -y 50 "env -u CI TERM=xterm-256color JACKIN_NO_MOTION=1 jackin load <role> task-<id> --agent <runtime>"` from `$HOME` (never from a directory containing an entry named `task-<id>`). `<role>` is the task's role, or `the-architect` for the bootstrap tasks M1-04a and M1-05a..c (`ROADMAP.md` §4). Preconditions so no dialog appears: trust granted (M1-05d), every manifest `[env]` var satisfied, no mount source under jackin's sensitive list. Poll `tmux capture-pane -p -t <id>` every 5 s until the capsule tab strip and the runtime's input prompt are visible (15-minute budget for a cold build); then record the container: `docker ps --format '{{.Names}}' \| grep -- "-task-<id slug>-"` (the newest name, launches inside a wave are sequential; or `jackin status --format json` filtered by workspace `task-<id>`) → `tasks/<id>/container.txt`. **Prompt.** One line only, never the multi-line `TASK.md` as keystrokes: `goal` delivery → `tmux send-keys -t <id> -l '/goal Read this file: .jackin/task/TASK.md — implement it fully until sh .jackin/task/verify.sh container prints status: DONE'`; `prompt` delivery → `tmux send-keys -t <id> -l 'Read .jackin/task/TASK.md and follow it as your task prompt; the container check is sh .jackin/task/verify.sh container'`; confirm with `capture-pane` that the line sits in the input box, then `tmux send-keys -t <id> Enter`; note `prompt landed: file` in the result cell. Read progress with `capture-pane -p -S -200`. **Container verify** is never typed into the TUI: `docker exec -u agent -w /workspace "$(cat tasks/<id>/container.txt)" sh .jackin/task/verify.sh container > tasks/<id>/verify.container.out 2>&1` (from M4-03: `jackin daemon exec <instance> -- sh .jackin/task/verify.sh container`). **End.** When `verify.out` is `DONE` run `jackin eject "$(cat tasks/<id>/container.txt)"` — always by container name, never by role class, never `--all` (two `the-architect` instances run concurrently in most M3/M4 waves; an eject error is filed as a jackin gap and the run continues) — then `tmux kill-session -t <id>`; `jackin workspace remove task-<id>` after the `PROGRESS.md` row. Interim when no loadable role exists (M1-04a before `the-architect` supports the task, or a D-046 gap): a detached `tmux` session running `CODEX_HOME=<home> codex exec --dangerously-bypass-approvals-and-sandbox -C ~/.jackin/managed/<id>/<repo> -c model_reasoning_effort=medium "$(cat tasks/<id>/TASK.md)" 2>&1 \| tee tasks/<id>/codex.log` (argv, not keystrokes; the only place the host `CODEX_HOME` selects the account); the session reads the log and runs `verify.sh` here. One process per Codex home at a time. |
| `daemon` | From the moment M3-05 and M3-06 are merged on `feat/managed-execution`, the branch build is installed (§5 step 4a), and `jackin daemon status` answers on this host, for every M2+ task whose row carries a Linear URL and whose delivery the daemon supports at that time (M4-01 for prompt delivery, M7-01 for verify, M8-02 for PRs, D-073) | This session delegates the issue to jackin (`issueUpdate(id, input:{delegateId})` with the workspace token obtained per the Linear-token rule below, D-023 holds) when the task becomes runnable; the daemon itself creates the agent session for a delegated issue that has none (`agentSessionCreateOnIssue`, M2-02, D-087), so the host step is the one mutation. It watches `jackin daemon status --format json` and Linear, answers elicitations by PTY injection through `jackin hardline <instance>` or `jackin daemon exec` (never as a Linear `prompt`, which only a human actor can post; Linear-UI replies are made by the proof task's own `crew-operator`), applies the stuck rule, and files evidence when the run reaches `done`. Nothing is started by hand that the daemon can dispatch; a task the daemon cannot serve takes the `subagents` or `container` path with no delegate set. Before the first daemon start against the real workspace, at every daemon restart, and at every session start, reconcile per D-073. |

Capsule dialogs on the `container` path (D-082) — the session answers
them itself from the capture, never files them as preflight defects, and
records every unexpected one in the task folder as a jackin gap owned by
M3-01: role or branch trust → confirm (should not appear after M1-05d);
jackin-exec credential picker → verify the displayed command is the task's
expected `jackin-exec op …` invocation and the binding is
`OP_SERVICE_ACCOUNT_TOKEN`, then `tmux send-keys -t <id> Space` followed
by `tmux send-keys -t <id> Enter` (Space first: rows start unselected);
any other command → `Escape` and the stuck rule; skippable env prompt →
`Enter` on empty; restore picker → should not appear (the previous
instance was ejected by container name); if it does, new instance and a
gap note; exit or restore dialog on agent exit → confirm exit. The picker
works on OrbStack (the `SO_PEERCRED` check is Linux-only inside the
container). From the daemon path on, the picker is a jackin gap owned by
M3-01/M4-03: a launch option pre-approving the configured on-demand
bindings; M11-01 stays on the `container` path until it exists.

Rules that hold on every path:

- Lane assignment is `ROADMAP.md` §5, applied through the per-task
  workspace `task-<id>` (D-085). Before M1-13 exists, the workspace carries
  only `sync_source_dir` (no model flag: the account home's default model is
  the lane's model) and effort is pinned with `CLAUDE_CODE_EFFORT_LEVEL=medium`
  / Codex `model_reasoning_effort = "medium"`; M1-13 is the first task that
  pins a model id (D-078) and its lane templates add `[env]`, grants, and
  model ids that every later `task-<id>.toml` copies. Host env vars on the
  launching process select nothing in jackin.
- Fallback (D-057, D-071): a quota-exhausted attempt is re-run at once on
  the next lane of another account home (L1/L2/L3 → L4 → L5 → L6 → L1;
  L4 → L5 → L6 → L1; …), consuming no attempt; a stuck attempt is re-run,
  after the D-063 analysis, on the lane's `fallback` column. Each hop is
  one entry in the `PROGRESS.md` row's `result` cell (`L1 quota → L4`).
  A fallback that crosses runtimes changes the mechanism (`subagents` ↔
  `container`), never silently: the lane cell names where the work ran
  (`L4 → L1 (host)`). A chain fully throttled makes the row `waiting`:
  read the earliest reset (`jackin usage host snapshot --agent
  <claude|codex> --format json` where exposed — never `--no-refresh`, a
  cold cache returns no buckets — else the runtime's limit message, else 30
  minutes), wait with a Monitor loop, retry. Never a defect, never a STOP,
  and never a reason to end the run while the row is `waiting`.
- Reserve rule for this session's own account (D-071, D-090): before
  dispatching anything that draws on `~/.claude` (a `subagents`-path task,
  an L1..L3 container, a host subagent, a D-063 analysis) run `jackin usage
  host snapshot --agent claude --format json` and read the `session`
  bucket's `remaining_percent`: below 40, the `~/.claude` container cap is
  1 and host subagents are capped at 1; below 20, dispatch Codex-lane tasks
  only, spawn no host subagents, and run D-063 analyses as
  `CODEX_HOME=<idle Codex home> codex exec -C <checkout> '<analysis
  prompt>' | tee tasks/<id>/analysis.log`; a `weekly` bucket below 15
  behaves like "below 20" until its reset; the snapshot's `resets_at` goes
  into `PROGRESS.md`. If the limit is reached anyway, this session cannot
  act until the reset: dispatched tmux containers keep running (their idle
  time does not count as stuck), Claude Code continues the turn itself when
  the auto-continue setting of `goal/PREFLIGHT.md` §1 is on, and the first
  thing after the reset is §1 steps 2–3 (re-attach to surviving tmux
  sessions, re-run verify). A limit message inside a Claude container's
  pane is a quota hop, not stuck. Only a weekly-cap message with a reset
  more than 24 hours away is a preflight defect (billing action).
- Linear token (D-087): every host-side GraphQL call reads `op://jackin/
  linear-workspace/access token`, a client-credentials token (30
  days); before the call the session reads `…/expires at` and, when fewer
  than 48 hours remain, mints a new one (`grant_type=client_credentials`,
  same scope list, `curl --config -` fed from `op read` on stdin) and `op
  item edit`s both fields first. The refresh-token grant is never used by
  the host; each daemon instance mints its own client-credentials token in
  memory (M2-01), so no consumer ever writes back a rotated refresh token
  that another holds.
- Nothing an involved project lacks is worked around: a missing jackin
  capability needed by a path (for example non-interactive prompt
  delivery, the `--on-demand` env flag, pre-approved on-demand bindings)
  is built in jackin on `feat/managed-execution` as part of the roadmap
  task that owns it (M3-01, M4-01, M4-03), and `tmux` is the interim path,
  not a permanent one (D-046).
- Every container path reuses the host's forwarded `gh` login and never
  sees the Linear token or a 1Password secret value (D-023, D-035). Early-
  started tasks never modify `~/.config/jackin/config.toml` or any lane
  template; the laptop stays on forwarded logins (`auth_forward = "sync"`)
  for the whole run (D-090).
- Branches (D-074, D-089): before every push to `feat/managed-execution`,
  `git fetch origin && git rebase origin/feat/managed-execution` (up to
  five retries), never `--force`. Role repositories (`donbeave/jackin-crew-*`,
  `donbeave/jackin-role-template`) commit directly to `main`;
  `jackin-the-architect` changes are merged from `feat/managed-execution`
  to `main` in the same task, and because that repository deletes the head
  branch on a squash merge unless preflight turned it off, the merging
  task ends with `git fetch origin main && git merge origin/main && git
  push -u origin feat/managed-execution` and confirms `gh api
  repos/jackin-project/jackin-the-architect/branches/feat/managed-execution`
  returns 200 (recreate the branch from `origin/main` when it is gone);
  every role change ends with `jackin load <role> --rebuild`. Merges to a
  protected `main` (jackin-project, tailrocks) happen only through `gh pr
  merge <n> --squash` after `gh pr checks <n> --watch --fail-fast` reports
  `ci-required` and `DCO` green; the rulesets have no bypass actors, so
  `--admin` never works, and a check pending on a self-hosted runner label
  is a defect of the task's own CI edit (fix it in the PR, D-064), never a
  preflight defect. No pull request from `feat/managed-execution` to
  `main` is merged in `jackin` or `termrock` during this run unless the
  task's scope names the merge (M11-01a does for jackin); if one is, the
  same task merges `origin/main` back into the branch and pushes it.
- DCO (D-089): the role images install a `prepare-commit-msg` hook that
  appends `Signed-off-by:` (M1-04a template, M1-13 for the-architect) and
  every `TASK.md` says `git commit -s`; before any push or PR the session
  checks `test "$(git log origin/main..HEAD --format=%B | grep -c
  '^Signed-off-by:')" -eq "$(git rev-list --count origin/main..HEAD)"`. The
  single sanctioned exception to "never `--force`": a missing trailer on
  `jackin-project/jackin-the-architect` `feat/managed-execution` only (a
  single-writer branch) is repaired with `git rebase --signoff origin/main`
  and `git push --force-with-lease`, recorded in the `PROGRESS.md` result
  cell.
- Forwarded logins (D-082): a login failure inside a container is a
  preflight defect only when the host-side probe also fails (`claude -p
  ok` under the lane's `CLAUDE_CONFIG_DIR`; `codex exec 'print ok'` under
  the lane's `CODEX_HOME`); otherwise re-launch the attempt (teardown
  first) so the fresh host state is re-synced and note `re-sync` in the
  result cell.

## 5. Per-task procedure

A strict checklist. Run every step, in this order, for every task; skip a
step only where its own text says it does not apply. A subagent handed this
section follows it verbatim.

0. `git fetch origin && git rebase origin/main` in this repository before
   every edit of `tasks/README.md`, `PROGRESS.md`, or
   `PREFLIGHT-DEFECTS.md` (never `--force`; on a conflict keep both sides'
   rows — the README table is replace-by-id, the ledgers are append-only —
   and note the conflict in the result cell).
1. Set the `tasks/README.md` row to `in-progress`; commit and push. If the
   task is M2+, its row has no Linear URL, and M1-12 is `done`, run the
   M1-12 procedure first (idempotent, `crew-operator`, L5, cap 1). Before
   M1-12 is `done`, only M3-01, M3-03, M4-02, and M4-03 dispatch without
   an issue (`subagents` or `container` path; M1-12 creates their issues
   afterwards, in the state that matches the row). A task without an issue
   is never dispatched on the daemon path.
2. Read `TASK.md` and its `preflight` section; check every item with its
   stated command. Missing item → §6, then continue with what does not
   depend on it.
3. Append the attempt to `tasks/<id>/attempts.log` (one line: `epoch <n>
   attempt <k>/<limit> lane <L> path <path> <UTC>`), then dispatch on the
   path of §4 with the lane's runtime, model, and account. The attempt
   count is read from this file, never from context (D-093).
4. Wait for evidence; apply the stuck rule (§2) on stall.
4a. Host build refresh, for every task whose `repos` include `jackin`
   (and at session start when the standing check fails): `git -C "$(cat
   tasks/M1-02/checkout.txt)" fetch origin && git -C "$(cat
   tasks/M1-02/checkout.txt)" checkout --detach origin/feat/managed-execution`,
   then `CI=1 cargo install --path crates/jackin --locked --force` and the
   same for `crates/jackin-capsule`; assert `jackin --version | grep -q
   "+$(git rev-parse --short=7 HEAD)"`; if `jackin daemon status` answers,
   `jackin daemon restart` (else, from M2-03 on, `jackin daemon start`) and
   re-run the D-073 reconciliation. A failed rebuild is a defect of the
   task that pushed the commit (fix the branch, D-042), not a lane fallback;
   a host-part failure whose D-063 analysis names a stale host binary is
   fixed by this step alone and consumes no attempt and no lane hop. The
   version line is the first line of the host part of `verify.out`.
5. Verify (D-081, D-086). `verify.sh` takes one argument, `container` or
   `host`, and runs only that part; a single-part task accepts both.
   Container part: through the task's own runner (`docker exec` into the
   container named in `tasks/<id>/container.txt`, `jackin daemon exec` from
   M4-03) on the container and daemon paths, here on the host and
   subagents paths; output to `tasks/<id>/verify.container.out`. Host part
   (the `host (D-061):` sentence of the verify column, or any check that
   needs the Linear token, `op`, the daemon socket, host `docker`, or a
   launch of or attach to a jackin instance, D-091): here, always, `sh
   tasks/<id>/verify.sh host > tasks/<id>/verify.host.out 2>&1`; when a
   container part exists the host part first asserts that
   `verify.container.out` ends with `status: DONE`, else prints `status:
   FAILED`. `verify.out` is `cat verify.container.out verify.host.out`; the
   task is verified only when its last line is `status: DONE`. Otherwise
   fix and repeat: after the D-063 analysis, the next attempt runs on the
   next lane of the D-057 chain; after `limits.attempts` attempts (default
   3, `task.toml`; `SPEC.md` §6 step 8) counted in
   `tasks/<id>/attempts.log` for the current epoch, without wrapping past
   the starting lane, the task is exhausted (§6, D-070, D-084, D-093). `verify.sh` is POSIX `sh` (`dash -n` and `shellcheck -s sh`
   clean), runs with `set +x`, never `curl -v`/`--trace`, secrets only via
   `-H @-`/`--config -` from stdin, and never asserts on its own
   `tasks/README.md` row or on the root `verify.sh` remaining count.
6. Confirm every touched repository is committed and pushed on the right
   branch (`git status --porcelain` empty, `git log origin/<branch>..`
   empty; role repositories on `main`, D-074) and that every commit carries
   `Signed-off-by:` (§4 DCO rule).
6a. Before a `crew-reviewer` task launches: ensure one open, non-draft
   PR `feat/managed-execution` → `main` exists in each repository the
   review covers (`gh pr list --head feat/managed-execution --state open`,
   else `gh pr create --title feat/managed-execution --body "Rolling PR;
   reviewed per milestone (D-055, D-074)"`); write `tasks/<review-id>/pr.txt`
   as three lines — the PR URL, the head SHA to review, the SHA the
   previous review recorded (empty for the first) — and never rewrite line
   2 on a retry, so the target cannot drift; stage the file into
   `.jackin/task/` and `git fetch` the workspace so both SHAs exist in the
   read-only mount. The reviewer posts with `commit_id` equal to line 2
   (D-091). After the review, the session appends the checklist lines of
   the reviewer's final message to the reviewed Linear issue (M6-02
   write-back once it exists, before that `issueUpdate` with the token of
   the §4 Linear-token rule).
6b. Scan the evidence before committing: `gitleaks detect --no-git
   --source tasks/<id>` or the D-081 regex over every file in the folder;
   a hit deletes the file, files a preflight defect naming the credential
   to rotate, and blocks the commit.
7. Step 0, then set the row to `done`; if the task has a Linear issue that
   is not already in a `completed`-type state, move it there on every path,
   for the whole run (`issueUpdate` with the §4 token; query `team.states`
   by `type`; a review-state issue left by the daemon after M7-01 is
   completed here, never moved to `merging`, because D-074 keeps
   `feat/managed-execution` unmerged and M9-01's Done-on-merge serves
   scratch issues only, D-087), post one `response` activity on its session
   when one exists, remove the delegate and any `run:*` label (D-073);
   import any ecosystem changes the task produced (§2), append the
   `PROGRESS.md` row; commit and push this repository. A task that finished
   before M1-12 ran gets its issue from the next M1-12 run, created in the
   `completed`-type state.
8. If the task is a proof run or created a scratch issue: close the
   scratch issue, attach media to the issue (D-059), and record the URL in
   the task folder. Live daemon runs in M2 and M3 touch scratch issues
   only; the task asserts by GraphQL that no roadmap issue changed state.
9. Re-run the D-073 reconciliation when the daemon path is active, then
   start the next runnable tasks.

`PROGRESS.md` row format (one line, no prose):

```text
| <id> | <lane; where the work actually ran, e.g. L4 → L1 (host)> | <path> | <done|blocked|waiting> — <attempts n/limit, epoch, fallbacks, re-sync, prompt landed: file> | tasks/<id>/verify.out | <UTC timestamp> |
```

## 6. Preflight defects, exhaustion, and BLOCKED

A preflight defect is an operator input that only the human can provide:
a login or OTP, a consent screen, a GitHub sudo-mode or Google re-auth
prompt, a credential created in a UI, a physical host or device, a billing
action (including a weekly provider cap), or a 1Password desktop app that
locks during the run (the §1 auto-lock item of `goal/PREFLIGHT.md` is a
precondition the session cannot change). It is never: a failing test, a
design choice (apply D-053), a defect in an involved project (fix it,
D-046), a missing tool that `brew install` provides, a review, a lane
fallback or quota wait (D-071), a capsule dialog (D-082), a golden-frame
blessing (D-075), or a stale host binary (§5 step 4a).

Exhaustion (D-070, D-084) is the second reason a row is `blocked`:
`verify.sh` still fails after `limits.attempts` attempts in the current
epoch, each on the next lane of the D-057 chain and each preceded by the
D-063 analysis with fresh subagents. It is filed in `PREFLIGHT-DEFECTS.md`
as `exhausted: <id>` with the last `tasks/<id>/verify.out` path and the
analysis summary in the "Missing item" cell and `re-run` in the proof
cell: it has no proof command. The human fixes the cause or edits the task,
fills the row's `Resolved` cell, and re-runs the invocation; only then does
the next session start re-open the task in a new attempt epoch (§1 step 2).
While `Resolved` is empty the task stays `blocked` and a re-prompt reprints
the same `GOAL BLOCKED` block (D-093). A second exhaustion files a new row. On the daemon path, a blocker elicitation
(M7-03) the session cannot answer is filed the same way instead of waiting.

Handling: append the row (task, exact item, the command or UI path that
proves it is in place, or `re-run`), set the task row to `blocked`
(dependents keep their status), finish the parts of the task that do not
depend on it, commit, and continue with every other runnable task. The run
ends BLOCKED only when every row is `done` or `blocked` or not yet
runnable, no row is `in-progress` or `waiting` (wait on those first, with
a Monitor loop, until each reaches `done` or `blocked`), and at least one
row is `blocked` on an open `PREFLIGHT-DEFECTS.md` row: commit, push,
print the `GOAL BLOCKED` block (§7), and end. The human clears the items
(leaving the `Resolved` cell empty is fine for missing-input rows — the
session re-runs each proof command at the next start and fills it; an
`exhausted:` row is closed only by the human filling `Resolved`, D-093)
and re-runs the invocation; the session sets those rows back to `ready`
and resumes.

## 7. Done

The run ends in exactly one of two outcomes (D-070, D-083). COMPLETE: `sh
verify.sh` at the repository root prints `status: DONE` as its last line
in the current turn after the final commit and push, the tree is clean,
and `PROGRESS.md` has one row per roadmap task. BLOCKED: as §6, and the
last line of `sh verify.sh` is `status: PENDING <n> remaining`.

The final message has one fixed shape in both cases (D-093), and nothing
follows it:

1. Line 1, alone: `GOAL COMPLETE` or `GOAL BLOCKED`.
2. The report, at most eight lines: tasks done out of total, preflight
   defects open and resolved, fallbacks and waits taken, repositories
   touched with their `feat/managed-execution` (or `main`, D-074) head
   commits, and the Linear project URL.
3. BLOCKED only: the open rows of `PREFLIGHT-DEFECTS.md` verbatim.
4. Last: the literal output of `sh verify.sh` run in the current turn.

Any other turn end — a summary, a mid-wait pause, a partial report — is
not the goal (D-083).

## 8. Host session budget (D-092)

What this session may do itself, and nothing more:

- Read: `GOAL.md`, `AGENTS.md`, this file, `goal/PREFLIGHT.md`,
  `tasks/README.md`, `PROGRESS.md`, `PREFLIGHT-DEFECTS.md`, and the
  current `tasks/<id>/` folder (its `TASK.md`, `task.toml`, `verify.*.out`,
  `attempts.log`, `container.txt`, `pr*.txt`).
- Never read in this session: `ROADMAP.md`, `SPEC.md`, `DECISIONS.md`,
  `concept/*`, `analysis/*`, or any file in an involved repository. A
  single literal may be `grep`ed out of them (`grep -n '^| M3-05 ' ROADMAP.md`);
  anything larger is a subagent's job, and the subagent returns at most 15
  lines.
- Run: git on this repository, `sh verify.sh`, `sh tasks/<id>/verify.sh
  host`, `docker`/`tmux`/`jackin`/`gh`/`op` host commands of §4, the
  standing checks of §1 step 4, and `caffeinate`.
- Write: `tasks/README.md`, `PROGRESS.md`, `PREFLIGHT-DEFECTS.md`, and
  `tasks/<id>/` files — in this repository only, then commit and push at
  once (D-086).
- Recording a decision (D-053 applies): the session never edits
  `DECISIONS.md` or `SPEC.md` itself, because it may not read them. It
  delegates the edit of `DECISIONS.md` and `SPEC.md` to a subagent, which
  appends the decision and corrects the specification in the working tree
  and returns the id and the touched paths; the session then commits and
  pushes both files in one commit (D-104).
- Delegate: everything else, with `model: "claude-opus-5"` (D-092, D-095),
  in parallel up
  to three host subagents in flight and the §4 reserve rule.
- Never: answer from memory what a file states, re-read a large file after
  a compaction instead of delegating it, or ask the human anything.
