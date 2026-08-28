# Execution guide for the `/goal` run

Read by the host Claude Code session after `GOAL.md`. `SPEC.md` alone defines
the final product and its acceptance conditions. `ROADMAP.md` supplies only
the derived graph and order. This file owns mechanical run procedure and does
not add product requirements. Any conflicting derived wording is corrected to
match `SPEC.md` in the same commit.

## 1. Session start (every run, including a resume or a re-prompt)

After the human completes `goal/PREFLIGHT.md` §1..§5 and both readiness
gates report READY, the run is started only by the operator running `sh
tools/supervisor.sh start` from this repository. The launcher creates the
Herdr session, starts interactive Claude, and submits the one invocation
line printed in `README.md` "Start the run", copied verbatim. It is never
shortened to `/goal Follow GOAL.md`: the argument carries the two
terminal facts the runner's judge checks (D-083). `GOAL.md` holds the
prompt the runner executes and nothing else; every document that says "the
invocation line of `GOAL.md`" means that line in `README.md`. After a
BLOCKED end or crash, the operator runs `tools/supervisor.sh resume`, which
submits that line when relaunch is needed; after a context compaction the
live coordinator re-runs it. In every case,
steps 1–4 below re-derive the whole state and nothing finished is redone.
The terminal classes are §7.

1. `git fetch origin && git rebase origin/main` in this repository (never
   `--force`; a diverged local tree is rebased onto `origin/main`, not
   refused). Refuse to work on a dirty tree: commit or stash-drop leftovers
   from a crashed run first, then record what happened in `PROGRESS.md`.
2. Read `tasks/README.md`, `PROGRESS.md`, `PREFLIGHT-DEFECTS.md`. A row
   `in-progress` with no `PROGRESS.md` row is an interrupted task. First
   check for a surviving run: `herdr agent get "$(cat
   tasks/<id>/herdr-agent.txt)"` (or `herdr pane get "$(cat
   tasks/<id>/herdr-pane.txt)"` before agent detection), `docker ps
   --filter label=<issue label>` (M3-04 labels; before M3, `docker ps
   --filter label=jackin.managed=true --filter label=jackin.kind=role
   --format '{{.Names}}'` for the name in `tasks/<id>/container.txt`), and
   on the daemon path `jackin daemon status --format json`. A surviving
   Herdr agent counts only when its name equals the lowercase task id exactly
   (`M2-01` → `m2-01`). A pane-only survivor counts only when `herdr pane
   process-info` reports a foreground command containing boundary-delimited
   `task-<id>` and the runtime from `tasks/<id>/task.toml`; pane existence
   alone is never liveness. A surviving Herdr agent whose state is `idle` or `done` with the task prompt already
   answered is a finished attempt, not a running one:
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
   provider authentication, `op` with stdin closed, the 1Password
   auto-lock setting, Herdr 0.8.2, `dash`, `shellcheck`, awake host, the
   usage-limit auto-continue setting). Two more standing checks: the
   installed `jackin --version` embeds the sha of
   `origin/feat/managed-execution` in the jackin checkout of
   `tasks/M1-02/checkout.txt` (from wave 1 on; otherwise refresh per §5 step
   4a), and the `~/.claude` session bucket has headroom (§4 reserve rule:
   below 40 % the caps shrink, below 20 % only Codex lanes dispatch). One
   more, from M1-07 on: the Linear app is still an agent, which requires its
   Agent-session-events webhook to be enabled. The webhook points at an
   intentionally unreachable URL (Q-015; polling is the correctness path),
   and Linear disables it after three failed deliveries, so this is checked
   every session with the §4 token by delegating a scratch issue to the app
   user (`issueUpdate` with `delegateId`, reverted at once); if it fails,
   the next `crew-operator` task re-enables the webhook on the app settings
   page named in `tasks/M1-07/app-url.txt` — that page is the first
   checklist item of every `crew-operator` proof task — and the check is
   re-run. A disabled webhook is never a preflight defect. A
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
memory, and never by re-reading `ROADMAP.md` or `SPEC.md`
in this session (§8, D-092, D-093).

Every agent runtime runs in its yolo mode — Claude Code with
`--dangerously-skip-permissions`, Codex CLI with
`--dangerously-bypass-approvals-and-sandbox` — on the host and in every
container; isolation comes from the container, not from approvals, and no
permission allowlist exists anywhere (D-121).

### Supervisor (K-29)

Re-reading state survives a compaction but not the death of the process
that holds it. Herdr 0.8.2 owns every host terminal process so an attached
client may detach or close without ending the coordinator, a task, or a
probe (D-124). No readiness command starts it. Only the operator's explicit
`sh tools/supervisor.sh start` or `resume` may launch anything.

`start` first reconciles the durable state store: an expired lease is
released with an audit event, and a leased task whose container (`docker
ps`) and recorded Herdr agent/pane are both gone loses its lease too. It
prints the exact Herdr server, workspace, Claude, `/goal`, and attach
commands before the first launch. It starts the isolated named session
with `herdr --session ecosystem-coordinator server`, creates the repository
workspace with `herdr --session ecosystem-coordinator workspace create
--cwd <repo> --label ecosystem-coordinator --no-focus` (recording its root
pane in ignored `run/logs/coordinator-<session-key>.pane`, workspace id in
`run/logs/coordinator-<session-key>.workspace`, and server pid in
`run/logs/herdr-server-<session-key>.pid`; the default key is
`ecosystem-coordinator`), and starts the coordinator
alias with `herdr --session ecosystem-coordinator agent start
ecosystem-coordinator --kind claude --pane <pane-id> --timeout 120000 --
--dangerously-skip-permissions --settings
'{"skipDangerousModePermissionPrompt":true}' --model claude-fable-5`, waits
for `idle`, submits the canonical line with `herdr --session
ecosystem-coordinator agent prompt ecosystem-coordinator '<README /goal
line>'`, then attaches with `herdr session attach ecosystem-coordinator`.
The launch flags are explicit; the
script does not depend on `claude-yolo`. `-p`/`--print` is forbidden.

Herdr persists panes after `Ctrl-b`, then `q`, or after the client window
closes. `tools/supervisor.sh resume` attaches when the named agent survives;
otherwise it reconciles and relaunches it from durable state before
attaching. It never relaunches in the background without that operator
command. If attach fails, it returns 4, leaves the coordinator/session live,
logs `interactive attach failed; coordinator preserved; retry command: herdr
session attach ecosystem-coordinator`, and makes no destructive rollback.
On another launch failure, rollback closes only the workspace this invocation
created and stops the session only when it started that server. In a
pre-existing session it interrupts only a coordinator it created, never the
session or unrelated task/probe panes.
`status` reports named-session, coordinator-agent, and run state;
`read` uses `herdr --session ecosystem-coordinator agent read
ecosystem-coordinator --source recent-unwrapped`; `stop` uses `herdr
session stop ecosystem-coordinator --json` and therefore terminates every pane process in that
session. `--dry-run` previews reconciliation, writes no event, and launches
nothing; `--coordinator-cmd` replaces Claude for tests
(`sh tests/supervisor/test_resume.sh`). Logs are host artifacts in
ignored `run/logs/herdr-<session-key>.log` and
`run/logs/supervisor-<session-key>.log` (default key
`ecosystem-coordinator`, D-059). On every resume, assert that `done` never
decreases and no `done` task takes a new lease; refusal is
`failed-system`.

## 2. What "one task" means

- Input: `tasks/<id>/TASK.md`, `task.toml`, `verify.sh`,
  `expected-evidence.toml`, and the task's `ROADMAP.md` row. M1-01 (wave 0)
  materializes the bundle files for every M1..M12
  id before any other task starts (D-072); no task runs from a bare row —
  which is why a row reaches `ready` only through arming or promotion, see
  the arming rule under the runnable predicate in §3.
  `TASK.md` references other files container-relative as
  `.jackin/task/refs/<name>` (`concept/task-format.md`), because the
  container never sees this repository.
- Workspace: the touched repository's per-task worktree under
  `~/.jackin/managed/<id>/<repo>`, on branch `managed/<run-id>/<id>` from
  the `run/LOCK.toml` base SHA (D-112; for operator tasks the evidence
  directory `~/.jackin/managed/<id>/`), registered once as the saved
  jackin workspace `task-<id>` (workdir and one shared mount
  `~/.jackin/managed/<id>`) that carries the lane's account, env, and
  grants (§4, D-085).
- Output: the task's changes committed and pushed on the task branch in
  every touched repository, then merged into that repository's integration
  target (`feat/managed-execution`, or `main` in role repositories) by the
  holder of its integrator lease. `tasks/<id>/evidence.json` carries one
  `repositories[]` object per involved repository — `repo`, `branch`, the
  exact integration head at this task's transition as `integrated_sha`, and
  `checkout`; the scalar `integrated_sha` equals `repositories[0].integrated_sha`
  for compatibility (D-112, D-074). Repeated `--repository <repo> <branch>
  <sha> <checkout>` arguments to `tools/evidence_manifest.py run` produce
  that array; never collapse multiple repositories into one record. Text
  evidence in `tasks/<id>/` (D-059); the composite
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
  container's Herdr pane, including docker build or pull output during a
  role's first load, count as evidence; an active `cargo` or `rustc`
  process in `docker top` of the task's container counts as evidence too;
  time this session spends limited (§4) does not count against any task's
  clock, and neither does time a task spends waiting for a lane cap or for
  another task's container to eject (for example M1-13's per-lane probes):
  that wait is recorded as `waiting on <lane>` in the result cell and
  stops its clock.
  Never poll a container pane in a model loop: waiting is done by
  `herdr pane wait-output` or `herdr agent wait` (§4), whose blocking wait
  costs no model turn. Only a genuine operator
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
D-071). The caps count role containers only, and every one of them, including a
throwaway `jackin load` inside a task (M1-05a..c, M1-06, M1-13): a task
that loads a lane or the operator role holds that resource for the load's
duration. The one countable list is `docker ps --filter
label=jackin.managed=true --filter label=jackin.kind=role --format
'{{.Names}}'`; a `jackin.kind=dind` sidecar (every builder lane with `dind
= "privileged"` has one) never counts, or a session would see twice the
load and stop dispatching at three tasks. No container name carries its
account home, so the mapping is made through this repository: each name's
`-task-<id slug>-` (or `-probe-<id slug>-`) segment gives the task id, that
id's `tasks/<id>/task.toml` gives the `lane`, and the lane template gives
the account home. Before every load the session builds that list and
refuses a load whose lane's account home, or whose role where the cap is
per role, already appears in it.

Runnable predicate (D-119). A row is Runnable (D-119) iff its status is `ready`; every
`depends_on` id is `done`; a lane slot is free under the caps (at most two
host subagents on `~/.claude`, at most three in flight, D-071) and the §4
reserve rule; and, except for M3-01, M3-03, M4-02, M4-03, an M2+ row has
M1-12 `done`, a valid lock-bound CTRL-006 audit, and one matching issue in
both passes of `tasks/M1-12/issues.json`. Those four ids
bypass both gates, run locked bundles, and receive issue backfill from M1-12
without rerun (ISSUE-006, CTRL-006, CTRL-014). `planned`, `leased`, `blocked`,
`waiting`, `resource-waiting`, `in-progress`, `failed-system`, and `done` are
not runnable (D-084).

Arming and promotion. Nothing dispatches a `planned` row, so wave 0 is
armed once, by `python3 tools/state.py arm`: it moves every task whose
`depends_on` is empty from `planned` to `ready`, and is idempotent. D-072
makes M1-01 author every task bundle before any other task starts, so
`arm` promotes M1-01 alone; the other dependency-free ids (M1-02, M10-02,
M10-03) are promoted when M1-01 turns `done`. From then on the promotion
is automatic: a leased `python3 tools/state.py transition <id> done --token
<token>` promotes every
`planned` task whose dependencies are all `done` to `ready` in the same
locked append. So a row is `ready` before it is ever dispatched, and "no
task runs from a bare row" and "a runnable row is not `planned`" say the
same thing rather than contradicting each other.

M1 exit audit (CTRL-006). Promotion of a non-exempt M2+ row requires M1-12's
audit to bind the current state and immutable-lock epoch/hash, the exact locked
M1 id/bundle set, every rerun output, and the exit-gate output; its last
non-empty line is `audit: PASS`. `tools/state.py` refuses promotion otherwise, in both
`arm` and the auto-promotion of `transition <id> done`, so a non-exempt M2+ row
physically cannot reach `ready` before the audit passes and nothing has to
remember the rule. M3-01, M3-03, M4-02, and M4-03 are exempt from both the
M1-12 row, mirror, and audit gates; they run from their locked bundles before M1-12,
which later backfills their issues at their durable state without delegation or
rerun (ISSUE-006, CTRL-006, CTRL-014). §5 step 7a says who writes the file.

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
| 5b | M1-03 | `crew-operator` container on L6 |
| 6 | M1-07 | `crew-operator` container |
| 7 | M1-10 | `crew-operator` container (critical path) |
| 8 | M1-13 | subagents plus throwaway loads, one at a time, each only when its lane's account home has no running container (L4 only after M1-08 ejected, L6 only after M1-03, M1-07 and M1-10 have ejected, at most one `~/.claude` throwaway at a time, the operator throwaway only when no other `crew-operator` container exists). It has its own wave because those loads queue behind the whole L6 chain; nothing in M1-07 or M1-10 needs M1-13, so the critical path is unchanged (CTRL-017). |
| 9 | M1-09 | `crew-operator` container; needs M1-10's token and app user and `tasks/M1-13/lanes.json` |
| 10 | M1-11, M1-12 | `crew-operator` container, sequential; M1-11 verify runs here (D-061) |

M6..M12 folders: there is no authoring step. All 81 task bundles, M1..M12,
are materialised by `tools/bundle.py` and hash-locked in `run/LOCK.toml`
before the run starts (D-114); no task authors another task's bundle while
the run is under way. M1-01 authors nothing: it seeds the run-state store
and verifies that every bundle is present and matches its lock hash.
No M6..M12 task begins before the M1-12 row is `done`. Every non-exempt M2+
task starts only after both passes of `tasks/M1-12/issues.json` contain its
task id and Linear URL; the four early-start
tasks named above may run before M1-12 or its audit exists, and M1-12 creates
their issues afterwards at their durable state without rerunning them.
Rows are `ready` once M1-01 has seeded the store;
`planned` is reserved for rows the store has not armed yet.

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
| `subagents` | Claude lanes (L1..L3) only: the task changes an involved repository and needs no role-only tool (`agent-browser`, `op` inside a container, DinD) and the daemon cannot dispatch it yet (before M3-05 is merged) | In-session subagents with the lane's model, working in that task's own git worktree at `~/.jackin/managed/<id>/<repo>` (clone or fetch, then `git worktree add` on branch `managed/<run-id>/<id>` created from the base SHA locked in `run/LOCK.toml`; never a checkout of `feat/managed-execution`, D-112). They all share this session's `~/.claude`, so each such task counts against the `~/.claude` cap and an L1→L2→L3 fallback is a model change only. Codex lanes never use this path (D-082). A task whose verify launches or attaches to a jackin instance takes this path (host Docker) before M3-05, never `container` (D-091). |
| `container` | The task's scope or verify names a role container, `agent-browser`, `jackin-exec`, or the profile mount (every `crew-operator` task; role smoke tests), or the task's lane is a Codex lane (L4..L6), and the daemon cannot dispatch it yet | **Workspace (D-085).** `jackin workspace show task-<id>` or, when absent, `jackin workspace create task-<id> --workdir /workspace --mount <ws>:/workspace`. `<ws>` is the mount source of `/workspace`: the task's worktree `~/.jackin/managed/<id>/<repo>` for a task that changes a repository, the evidence directory `~/.jackin/managed/<id>` for an operator or evidence task; a review adds `:ro` (`<ws>:/workspace:ro`). The `:/workspace` half is never omitted: a bare `--mount <path>` mounts the directory at its own host path (a mount spec without `:dst` uses `dst = src`) and leaves `/workspace` empty, which breaks every `-w /workspace` exec, the container-relative `.jackin/task/...` prompt line, and the-architect's `MISE_TRUSTED_CONFIG_PATHS=/workspace` (an untrusted `mise.toml` means no Rust toolchain). Then merge the lane template into `~/.config/jackin/workspaces/task-<id>.toml`: `tasks/M1-13/lanes/L<n>.toml` once M1-13 is done, before that `tasks/M1-02a/lanes/L<n>.toml` (`[codex] sync_source_dir` or `[claude] sync_source_dir` — that is the sole account selector before M1-13, and host `CODEX_HOME`/`CLAUDE_CONFIG_DIR` select nothing in `jackin load` — plus the template's `[[mounts]]` lines, applied one by one with `jackin workspace edit task-<id> --mount <src>:<dst>`, which is how the per-lane cargo caches reach the container). Then merge the task's **role grant** file `tasks/M1-13/grants/<role>.toml` into the same workspace: a lane template carries `sync_source_dir` and `[env]` only, because every lane serves builder, operator, and reviewer tasks, so Docker grants are per role, not per lane (`the-architect` and `donbeave/crew-builder` get `[docker.grants] dind = "privileged"`, `donbeave/crew-operator` the network allowlist grant, `donbeave/crew-reviewer` neither). Before M1-13 is done no grant file exists and no task on this path needs one. `jackin load <role> task-<id> --agent <runtime> --dry-run --format json` must report `.data.workspace == "task-<id>"` and `jq -e '.data.mounts[]|select(.dst=="/workspace")'` must succeed; an ad-hoc load (no workspace name) is a plan defect, never retried. **Staging.** Into the same `<ws>`, so the folder appears in the container as `/workspace/.jackin/task/`: `mkdir -p <ws>/.jackin/task && cp tasks/<id>/TASK.md tasks/<id>/task.toml tasks/<id>/verify.sh tasks/<id>/expected-evidence.toml <ws>/.jackin/task/`, the `## References` files into `<ws>/.jackin/task/refs/`, `tasks/<id>/pr.txt` for reviews, and — only when `<ws>` is a git worktree — `echo .jackin/ >> <ws>/.git/info/exclude` (for the read-only reviewer mount the copy is still host-side). The container part of a `verify.sh` reads nothing outside `/workspace`: repository files as `./…`, any evidence file the host produced as `.jackin/task/refs/<name>`, staged here. **Teardown before any launch of the same id** (retry, fallback, re-sync, resume): when `tasks/<id>/herdr-tab.txt` names a live tab, `herdr tab close "$(cat tasks/<id>/herdr-tab.txt)"`; then, for a `crew-operator` container, `docker exec -u agent "$(cat tasks/<id>/container.txt)" agent-browser close --all` so Chromium releases the shared profile; then `jackin eject "$(cat tasks/<id>/container.txt)"` if that file names a live container. Never start a second load for the same id while one is loaded. Before every `crew-operator` launch, once `docker ps --filter label=jackin.role=donbeave/crew-operator` prints nothing, `rm -f ~/.jackin/agent-browser-profile/Singleton{Lock,Socket,Cookie}`: Chromium writes those as `<hostname>-<pid>`, the hostname is the container id, and a stale one makes the next container refuse to start with "profile in use on another computer". The cap of one `crew-operator` guarantees no live holder, so the removal is unconditional; a PID check is meaningless across PID namespaces. **Launch (Herdr 0.8.2, D-124).** Create a background tab in the coordinator workspace with `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$HOME" --label '<id>' --no-focus`; record `.result.tab.tab_id` in `tasks/<id>/herdr-tab.txt` and `.result.root_pane.pane_id` in `tasks/<id>/herdr-pane.txt`. Start the TUI with `herdr pane run "$(cat tasks/<id>/herdr-pane.txt)" "env -u CI TERM=xterm-256color JACKIN_NO_MOTION=1 jackin load <role> task-<id> --agent <runtime>"`. `<role>` is the task's role, or `the-architect` for bootstrap tasks M1-04a and M1-05a..c (`ROADMAP.md` §4). Preconditions so no dialog appears: trust granted (M1-05d), every manifest `[env]` var satisfied, no mount source under jackin's sensitive list. Wait without model polling: `herdr pane wait-output "$(cat tasks/<id>/herdr-pane.txt)" --regex '<runtime prompt regex>' --source recent-unwrapped --lines 200 --timeout 900000`. On timeout, read once with `herdr pane read ... --source recent-unwrapped --lines 200`; repeat one 900000 ms wait only when build/pull lines changed, otherwise apply the stuck rule. Once detected, rename the agent to exactly the lowercase task id (`M2-01` → `m2-01`) with `herdr agent rename "$(cat tasks/<id>/herdr-pane.txt)" '<id-lowercase>'` and write that exact alias to `tasks/<id>/herdr-agent.txt`. On resume, a pane without that agent is live only when `herdr pane process-info` shows a foreground command containing boundary-delimited `task-<id>` plus the task runtime; a recorded pane id alone proves nothing. Then record the container. The workspace component of a jackin container name is lowercased and stripped of every non-alphanumeric character, so `task-M2-01` appears as `taskm201` and a hyphenated pattern matches nothing: `slug=$(printf %s "task-<id>" \| tr -cd '[:alnum:]' \| tr '[:upper:]' '[:lower:]'); docker ps --filter label=jackin.managed=true --filter label=jackin.kind=role --format '{{.Names}}' \| grep -- "-${slug}-" \| head -1 > tasks/<id>/container.txt`. When two names match, `jackin status --format json` filtered by workspace `task-<id>` is authoritative and decides which one is written. **Prompt.** One line only, never multi-line `TASK.md`: `goal` delivery uses `herdr agent prompt "$(cat tasks/<id>/herdr-agent.txt)" '/goal Read this file: .jackin/task/TASK.md — implement it fully until sh .jackin/task/verify.sh container prints status: DONE'`; `prompt` delivery uses the same command with `Read .jackin/task/TASK.md and follow it as your task prompt; the container check is sh .jackin/task/verify.sh container`. `agent prompt` handles paste mode and Enter atomically; note `prompt landed: file` only after it reports success. Wait with `herdr agent wait "$(cat tasks/<id>/herdr-agent.txt)" --timeout 1800000`; inspect `blocked` with `herdr agent read ... --source recent-unwrapped --lines 200`; progress reads happen only after a wait returns. **Container verify** is never typed into the TUI: `docker exec -u agent -w /workspace "$(cat tasks/<id>/container.txt)" sh .jackin/task/verify.sh container > tasks/<id>/verify.container.out 2>&1` (from M4-03: `jackin daemon exec <instance> -- sh .jackin/task/verify.sh container`). **End.** When `verify.out` is `DONE`, run `jackin eject "$(cat tasks/<id>/container.txt)"` — always by container name, never by role class or `--all` — then `herdr tab close "$(cat tasks/<id>/herdr-tab.txt)"`; remove `task-<id>` after the `PROGRESS.md` row. Interim when no loadable role exists: create and record a Herdr tab/pane the same way, then `herdr pane run <pane-id> 'CODEX_HOME=<home> codex exec --dangerously-bypass-approvals-and-sandbox -C ~/.jackin/managed/<id>/<repo> -c model_reasoning_effort=medium "Task marker: task-<id>. $(cat tasks/<id>/TASK.md)" 2>&1 \| tee tasks/<id>/codex.log'`; inspect with `herdr pane process-info` and `herdr pane read`. One process per Codex home. |
| `daemon` | From the moment M3-05 and M3-06 are merged on `feat/managed-execution`, the branch build is installed (§5 step 4a), and `jackin daemon status` answers on this host, for every M2+ task mapped to a Linear URL in both passes of `tasks/M1-12/issues.json` and whose delivery the daemon supports at that time (M4-01 for prompt delivery, M7-01 for verify, M8-02 for PRs, D-073) | This session delegates the issue to jackin (`issueUpdate(id, input:{delegateId})` with the workspace token obtained per the Linear-token rule below, D-023 holds) when the task becomes runnable; the daemon itself creates the agent session for a delegated issue that has none (`agentSessionCreateOnIssue`, M2-02, D-087), so the host step is the one mutation. It watches `jackin daemon status --format json` and Linear, answers elicitations by PTY injection through `jackin hardline <instance>` or `jackin daemon exec` (never as a Linear `prompt`, which only a human actor can post; Linear-UI replies are made by the proof task's own `crew-operator`), applies the stuck rule, and files evidence when the run reaches `done`. Nothing is started by hand that the daemon can dispatch; a task the daemon cannot serve takes the `subagents` or `container` path with no delegate set. Before the first daemon start against the real workspace, at every daemon restart, and at every session start, reconcile per D-073. |

Throwaway load (role smoke test: M1-05a, M1-05b, M1-05c, M1-06, M1-13,
M3-02a). A role smoke test is not run inside the task's own container: the
task container is `the-architect` (it has `cargo` and no `jackin` binary),
while the checks are about the crew role. The session creates a second,
disposable workspace and loads the role under test into it: `jackin
workspace create probe-<id> --workdir /workspace --mount <checkout>:/workspace`
— M1-05a a termrock clone at `~/.jackin/managed/M1-05a/termrock`; M1-05b
`~/.jackin/managed/M1-05b` plus `--mount
~/.jackin/agent-browser-profile:/home/agent/.agent-browser-profile`; M1-05c
any checkout with `:ro` — merge the lane template as above, then create a
background Herdr tab labelled `<id>-probe`, record its tab and root pane as
`tasks/<id>/herdr-probe-tab.txt` and `herdr-probe-pane.txt`, and run
`herdr pane run <probe-pane-id> "env -u CI TERM=xterm-256color
JACKIN_NO_MOTION=1 jackin load donbeave/crew-<p> probe-<id> --agent
<runtime>"`. Wait with `herdr pane wait-output <probe-pane-id> --regex
'<runtime prompt regex>' --source recent-unwrapped --lines 200 --timeout
900000`, and record the container name the same way as above into
`tasks/<id>/throwaway.txt`. Every "inside: …" check of such a task's
verify column is a **host** part (D-061, D-091) that runs `docker exec -u
agent "$(cat tasks/<id>/throwaway.txt)" sh -c '<check>'`, and `jackin role
validate ~/.jackin/roles/donbeave/crew-<p>/default` runs on the host too,
never inside a container. The container part of these tasks is only what
holds in the task's own container: the sign-off check `git -C /workspace
log -1` and the presence of the role's files. End with `jackin eject
"$(cat tasks/<id>/throwaway.txt)"`, `herdr tab close "$(cat
tasks/<id>/herdr-probe-tab.txt)"`, `jackin workspace remove probe-<id>`
(and, for a `crew-operator` probe,
the `agent-browser close --all` and `Singleton*` removal of the Teardown
step). A throwaway load holds a container slot and its lane's account home
for its whole duration (§3).

Capsule dialogs on the `container` path (D-082) — the session answers
them itself from the capture, never files them as preflight defects, and
records every unexpected one in the task folder as a jackin gap owned by
M3-01: role or branch trust → confirm (should not appear after M1-05d);
jackin-exec credential picker → verify the displayed command is the task's
expected `jackin-exec op …` invocation and the binding is
`OP_SERVICE_ACCOUNT_TOKEN`, then `herdr pane send-keys <pane-id> space
enter` (Space first: rows start unselected); any other command → `herdr
pane send-keys <pane-id> esc` and the stuck rule; skippable env prompt →
`herdr pane send-keys <pane-id> enter` on empty; restore picker → should not appear (the previous
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
  L4 → L5 → L6 → L1; …), consuming no attempt. A hop skips any lane of the
  chain whose account home already has a live container and takes the
  first free one; when every lane of the chain is busy or throttled the row
  returns to `ready` at the head of its wave's priority and is dispatched
  on the first slot that frees — never `waiting`, which means throttled,
  not busy, and no attempt is consumed. A `~/.claude` limit that also
  limits this session is handled after auto-continue rather than by an
  immediate hop: re-lane only a container whose pane still shows the limit
  message; one whose pane is idle at its prompt has finished and is
  verified (§5 step 5), not re-laned, and never torn down to be relaunched
  on another lane. a stuck attempt is re-run,
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
  act until the reset: dispatched Herdr task panes keep running (their idle
  time does not count as stuck), Claude Code continues the turn itself when
  the auto-continue setting of `goal/PREFLIGHT.md` §1 is on, and the first
  thing after the reset is §1 steps 2–3 (inspect surviving Herdr agents,
  re-run verify). A limit message inside a Claude container's
  pane is a quota hop, not stuck. Only a weekly-cap message with a reset
  more than 24 hours away is a preflight defect (billing action).
- Linear tokens (D-087): the host coordinator and manager daemon are separate
  trusted control-plane actors and never share a minted token. Every host-side GraphQL call reads `op://jackin/
  linear-workspace/access token`, a client-credentials token (30
  days); before the call the session reads `…/expires at` and, when fewer
  than 48 hours remain, mints a new one (`grant_type=client_credentials`,
  same scope list, `curl --config -` fed from `op read` on stdin) and `op
  item edit`s both fields first. The refresh-token grant is never used by
  the host. The manager daemon mints its own client-credentials token from
  the same 1Password client-credential references, keeps it only in process
  memory, and refreshes it independently (M2-01). Raw tokens travel only by
  stdin or process memory, never files or argv; worker daemons and role
  containers receive no Linear credential.
- Nothing an involved project lacks is worked around: a missing jackin
  capability needed by a path (for example non-interactive prompt
  delivery, the `--on-demand` env flag, pre-approved on-demand bindings)
  is built in jackin on `feat/managed-execution` as part of the roadmap
  task that owns it (M3-01, M4-01, M4-03); Herdr panes are the interim
  host transport, not a product capability (D-046, D-124).
- Every container path reuses the host's forwarded `gh` login and never
  sees the Linear token or a 1Password secret value (D-023, D-035). Early-
  started tasks never modify `~/.config/jackin/config.toml` or any lane
  template; the laptop stays on forwarded logins (`auth_forward = "sync"`)
  for the whole run (D-090).
- Branches (D-112, amending D-047/D-074/D-089): a worker never checks out,
  rebases, or pushes an integration branch. Each task creates its own
  worktree and branch from the base SHA locked in `run/LOCK.toml` — `git
  worktree add -b managed/<run-id>/<task-id> ~/.jackin/managed/<id>/<repo>
  <base-sha>` — and pushes only that branch (`git push -u origin
  managed/<run-id>/<task-id>`), never `--force`.
- Integration (D-112): a task branch reaches a repository's integration
  target — `feat/managed-execution` in involved projects, `main` in role
  repositories (`donbeave/jackin-crew-*`, `donbeave/jackin-role-template`,
  D-074) — only through the holder of that repository's single integrator
  lease, taken with `python3 tools/state.py lease <id> --owner
  integrator:<repo> --ttl 300`; capture its JSON `token`, gate the merge/push
  with a keyed `state.py event <id> --token <token>`, then `state.py release
  <id> --token <token>`. The integrator
  fast-forwards where it can (`git merge --ff-only`), otherwise `git fetch
  origin && git merge` and push (up to five retries), never `--force`.
  Verification then runs against each exact integrated SHA — `git rev-parse
  HEAD` on each integration target immediately after that merge — never
  against a worker branch tip. Pass every repository as a repeated
  `--repository` argument to the evidence-manifest command; the task
  transition result records the same `<repo>=<exact-sha>` pairs. The final
  root gate accepts that historical SHA only while it remains an ancestor of
  the repository's later integration head; divergent history fails. Every
  role change ends with `jackin load <role>
  --rebuild`.
- jackin `main` is protected by ruleset 14746904, read 2026-08-28 with `gh
  api repos/jackin-project/jackin/rulesets/14746904`: `--jq
  '.rules[].type'` returns `deletion`, `pull_request`,
  `required_status_checks`, `non_fast_forward`, and `--jq .bypass_actors`
  returns exactly `[]`. `required_status_checks` names the contexts
  `ci-required` and `DCO` with `strict_required_status_checks_policy:
  true`; `pull_request` carries `require_extra_approval_for_unattributed_
  changes: true` with `required_approving_review_count: 0`. The constraint
  on the jackin path follows from that literal result: every change to
  jackin `main` lands through a pull request that the agent itself merges
  once `gh pr checks <n> --watch --fail-fast` reports `ci-required` and
  `DCO` green (D-055, D-079); the head branch must be up to date with
  `main` first (strict policy) — `git fetch origin main && git merge
  --no-ff --signoff origin/main`, then push; nothing may be pushed to `main`, `--admin` and
  every other bypass is unavailable to every actor because the bypass list
  is empty, and history is never rewritten (`non_fast_forward`). A commit
  without a `Signed-off-by:` trailer fails the `DCO` check, and an
  unattributed commit needs an extra approval, so every commit is
  attributed to the account that pushes it. The same PR-only rule holds
  for every protected `main` under jackin-project and tailrocks.
- `jackin-the-architect` changes are merged from `feat/managed-execution`
  to `main` in the same task; because that repository deletes the head
  branch on a squash merge unless preflight turned it off, the merging
  task ends with `git fetch origin main && git merge --no-ff --signoff
  origin/main && git push -u origin feat/managed-execution` and confirms `gh api
  repos/jackin-project/jackin-the-architect/branches/feat/managed-execution`
  returns 200 (recreate the branch from `origin/main` when it is gone). A
  check pending on a self-hosted runner label is a defect of the task's
  own CI edit (fix it in the PR, D-064), never a preflight defect. No pull
  request from `feat/managed-execution` to `main` is merged in `jackin` or
  `termrock` during this run unless the task's scope names the merge
  (M11-01a does for jackin); if one is, the same task merges `origin/main`
  back into the branch with `git fetch origin main && git merge --no-ff
  --signoff origin/main` and pushes it (the trailer keeps the merge-back
  itself signed off; the DCO gate above ignores merge commits either way).
- DCO (CTRL-034): the sign-off trailer comes from jackin's own
  feature, not from a hook a role image ships. M1-02a runs `jackin config
  git dco enable` once on this host (`grep -q 'dco = true'
  ~/.config/jackin/config.toml`), so every container launched here carries
  `JACKIN_GIT_DCO=1` and the capsule's `prepare-commit-msg` hook appends
  `Signed-off-by:`. A role image that installed its own hook would be
  shadowed anyway, because jackin sets `core.hooksPath` globally; the role
  repositories therefore ship none (`! grep -q 'core.hooksPath'
  Dockerfile`). The `codex exec` interim path of this section runs no
  capsule, so its `TASK.md` keeps `git commit -s`, as does every other
  `TASK.md`. The pre-push trailer count stays the gate: before any push or PR the session
  checks `test "$(git log --no-merges origin/main..HEAD --format=%B | grep
  -c '^Signed-off-by:')" -eq "$(git rev-list --no-merges --count
  origin/main..HEAD)"`. Merge commits are exempt: the check ignores them
  (`--no-merges` on both sides), because the merge-backs this file mandates
  after a squash merge are created by the session, not by an author. The
  single sanctioned exception to "never `--force`": a missing trailer on
  `jackin-project/jackin-the-architect` `feat/managed-execution` only (a
  single-writer branch) is repaired with `git rebase --signoff origin/main`
  and `git push --force-with-lease`, recorded in the `PROGRESS.md` result
  cell.
- Forwarded logins (D-082): a login failure inside a container is a
  preflight defect only when the host-side check also fails (`claude auth
  status` under the lane's `CLAUDE_CONFIG_DIR`, which starts no agent;
  `codex exec 'print ok'` under
  the lane's `CODEX_HOME`); otherwise re-launch the attempt (teardown
  first) so the fresh host state is re-synced and note `re-sync` in the
  result cell.

## 5. Per-task procedure

A strict checklist. Run every step, in this order, for every task; skip a
step only where its own text says it does not apply. A subagent handed this
section follows it verbatim.

Every host-authored status uses a short proof lease. Run `python3 tools/state.py
lease <id> --owner host:coordinator --ttl 300`, parse the returned JSON `token`,
pass that exact token to `state.py transition`, then immediately run `state.py
release <id> --token <token>` and `state.py render`. Acquisition projects a
`ready` row as `leased`; cancellation by release alone projects it back to
`ready`. `arm`, `promote`, initialization, and lock-epoch migration are the
only unfenced status writers.
The host-only `ready` ↔ `resource-waiting` cap bookkeeping edges are the one
transition exception: they carry no task lease because they claim no worker or
external resource.

0. `git fetch origin && git rebase origin/main` in this repository before
   every edit of `tasks/README.md`, `PROGRESS.md`, or
   `PREFLIGHT-DEFECTS.md` (never `--force`; on a conflict keep both sides'
   rows — the README table is replace-by-id, the ledgers are append-only —
   and note the conflict in the result cell).
1. Claim the `ready` row with the short-lease sequence above, transition it
   from `leased` to `in-progress`, release, render, commit, and push. If the
   task is non-exempt M2+, first require its task id exactly once in each
   `tasks/M1-12/issues.json` pass; when absent, rerun the M1-12 reconciliation
   and verifier before claim. Before M1-12 is `done`, only M3-01, M3-03,
   M4-02, and M4-03 dispatch without an issue (`subagents` or `container`
   path; M1-12 creates their issues afterwards, in the state that matches
   the row). No other M2+ task is dispatched by any path without its issue.
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
   `jackin daemon restart` (else, from the earlier of M2-03 or M4-03,
   `jackin daemon start`; M4-03 may start as soon as M1-02 exists and its
   host part needs a running daemon, `ROADMAP.md` §2 M4-03) and
   re-run the D-073 reconciliation. Before the first `jackin daemon start`
   on any host, write the per-account-home concurrency into
   `~/.config/jackin/config.toml` so the daemon obeys the same caps this
   file states (D-056, D-071): one `[daemon.accounts."<home>"]` table per
   account home, with `max = 2` for `~/.claude` and `max = 1` for each
   Codex home (`~/.codex`, `~/.codex-chainargos`, `~/.codex-chainargos2`).
   Verify with `jackin daemon status --format json | jq -e '.data.accounts'`
   showing those homes with those maxima; a daemon that reports different
   numbers is a jackin gap owned by M2-03, fixed on the branch (D-046),
   never worked around by hand-limiting dispatch.
   A failed rebuild is a defect of the
   task that pushed the commit (fix the branch, D-042), not a lane fallback;
   a host-part failure whose D-063 analysis names a stale host binary is
   fixed by this step alone and consumes no attempt and no lane hop. The
   version line is the first line of the host part of `verify.out`.
4c. Golden-frame blessing, M10-03 and M10-04 only (D-075, pre-approved by
   the human's `goal/PREFLIGHT.md` §2 checkbox; never a gate and never a
   defect). The container part of those tasks runs `mise run gate` minus the
   goldens (`cargo nextest run --workspace -E 'not test(goldens)'` plus the
   remaining gate steps), because the goldens the new story needs do not
   exist until the host blesses them. When the container's last message
   reports the story committed, this session — never a container role, which
   never sets `TERMROCK_BLESS_PREVIEWS` — runs in the task's own worktree
   `~/.jackin/managed/<id>/termrock`, on that task's `managed/<run-id>/<id>`
   branch (D-112): `git fetch origin && git pull --ff-only && mise install &&
   mise run bless-previews && git add crates/termrock-lookbook/goldens && git
   commit -s -m 'chore: bless previews for <id>' && git push`. The integrator
   lease then merges that branch into `feat/managed-execution` (§4
   Integration), which is where the task's verify reads the bless commit
   from. File the frame text in `tasks/<id>/` (text only, D-059), then
   step 5.
5. Verify (D-081, D-086). `verify.sh` takes one argument, `container` or
   `host`, and runs only that part; a single-part task accepts both.
   Container part: through the task's own runner (`docker exec -u agent -w
   /workspace` into the container named in `tasks/<id>/container.txt`,
   `jackin daemon exec` from M4-03) on the container and daemon paths;
   here on the host and subagents paths, where the session stages the same
   `.jackin/task/` folder and runs `cd <ws> && sh .jackin/task/verify.sh
   container`. The container part's working directory is `/workspace` — the
   `<ws>` of §4 — on every path, so a relative path in the script means the
   same file everywhere; the host part's working directory is this
   repository's root. Output to `tasks/<id>/verify.container.out`, always
   by shell redirection: evidence is what a command wrote to a file, never
   what a tool rendered on screen, and the session reads a result with
   `tail -n 1 tasks/<id>/verify.out` and files the file itself. Host part
   (the `host (D-061):` sentence of the verify column, or any check that
   needs the Linear token, `op`, the daemon socket, host `docker`, or a
   launch of or attach to a jackin instance, D-091): here, always, `sh
   tasks/<id>/verify.sh host > tasks/<id>/verify.host.out 2>&1`; when a
   container part exists the host part first asserts that
   `verify.container.out` ends with `status: DONE`, else prints `status:
   FAILED`. `verify.out` is `cat verify.container.out
   verify.host.out`, preceded by the header lines the root oracle reads: `commit: <40hex>`, the commit of
   this repository the evidence was recorded against, `bundle_hash: <hex>`,
   and — for a task whose `repos` name an involved repository — an
   `integrated_sha: <40hex>` line carrying the first repository's exact
   integration head at transition. It equals the manifest scalar and
   `repositories[0].integrated_sha`; every further repository is represented
   by another `repositories[]` object produced with a repeated `--repository`
   argument (D-112). A task confined
   to this repository records the same SHA in both places and needs no
   `integrated_sha:` line. The task is verified only when its last line is `status: DONE`. Otherwise
   fix and repeat: after the D-063 analysis, the next attempt runs on the
   next lane of the D-057 chain; after `limits.attempts` attempts (default
   3, `task.toml`; `SPEC.md` §8.5, EXEC-041) counted in
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
   else create it from that repository's own PR template, which its
   `.github/AGENTS.md` requires: `sed 's/<PR_NUMBER>/TBD/g'
   <repo>/.github/PULL_REQUEST_TEMPLATE.md > tasks/<review-id>/pr-body.md`
   — filling the `## Summary` section with `Rolling PR; reviewed per
   milestone (D-055, D-074)` and dropping the optional headings — then `gh
   pr create --title "feat: managed execution (rolling, D-074)" --body-file
   tasks/<review-id>/pr-body.md`, and immediately after creation `sed -i ''
   "s/TBD/<n>/g" tasks/<review-id>/pr-body.md && gh pr edit <n> --body-file
   tasks/<review-id>/pr-body.md` so the template's isolated `jackin-dev pr
   sync <PR_NUMBER>` checkout block carries the real number. A repository
   with no `.github/PULL_REQUEST_TEMPLATE.md` keeps the one-line body.
   Every squash merge of such a PR (M11-01a) keeps the PR number in the
   title and generates the body with the repository's own tooling:
   `jackin-pr-trailers <n> > tasks/<id>/squash-body.md && gh pr merge <n>
   --squash --subject "feat: managed execution (#<n>)" --body-file
   tasks/<id>/squash-body.md`, and that trailer command is recorded in the
   merging task's folder. Write one review record per reviewed repository,
   never one record for two repositories: `tasks/<review-id>/pr.txt` for the
   first repository named in the row's `repos`, and
   `tasks/<review-id>/pr.<repo>.txt` for each further one. Each record is
   three lines — line 1 the PR URL, line 2 the head SHA to review, line 3
   the SHA the previous review recorded (empty for the first) — and line 2
   is never rewritten on a retry, so the target cannot drift. A repository
   that has no pull request because it commits straight to `main` (the role
   repositories, D-074, D-112) gets the literal `commit` as line 1, and its
   review is posted as a commit comment on the sha in line 2 (`gh api
   repos/<owner>/<repo>/commits/<sha>/comments --input -`) whose body starts
   with the `verdict:` line (D-079) instead of as a PR review. Stage every
   record into `.jackin/task/` and `git fetch` each workspace so both SHAs
   exist in the read-only mount. On a pull request the reviewer posts with
   `commit_id` equal to that record's line 2 (D-091). After the review, the session appends the checklist lines of
   the reviewer's final message to the reviewed Linear issue (M6-02
   write-back once it exists, before that `issueUpdate` with the token of
   the §4 Linear-token rule).
6b. Scan the evidence before committing: `gitleaks detect --no-git
   --source tasks/<id>` or the D-081 regex over every file in the folder;
   a hit deletes the file, files a preflight defect naming the credential
   to rotate, and blocks the commit.
7. Step 0, then claim the current row. For M1-12, run step 7a under that
   proof lease before its `done` transition; every other M1 row is already
   `done` by the locked wave order. On audit PASS, append `python3 tools/state.py
   event M1-12 --operation foundation-audit --attempt <n> --token <token>
   --result PASS --evidence tasks/M1-12/audit.txt`, then transition M1-12 to
   `done` with result `audit: PASS` and that same evidence. For every
   other task, transition it to `done`. Then release,
   render, and continue; if the task has a Linear issue that
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
7a. M1 exit audit (CTRL-006). When M1-12 is otherwise ready to close and every
   other M1 row is `done`, launch one fresh subagent (`model: "claude-opus-5"`, no
   context from this run) that re-runs every M1 task's `sh
   tasks/<id>/verify.sh host`, checks the M1 exit gate of `ROADMAP.md` §2
   (the CREATE set), writing each complete verifier transcript to
   `tasks/M1-12/audit-<id>.out` and the exit-gate transcript to
   `tasks/M1-12/audit-exit-gate.out`; each ends `status: DONE` only on success.
   Write `tasks/M1-12/audit.txt` in exact order: `lock_epoch: <n>`, `lock_hash:
   <sha256>`, `exit_gate_sha256: <artifact-sha256>`, then one sorted line per
   locked M1 id as `<id>: bundle=<locked-sha256> verify=<artifact-sha256>`, then
   last line `audit: PASS` (use `audit: FAIL`, leave M1-12 `in-progress`, and
   do not promote on failure). Commit and push those files. Step 7 records the
   PASS and audit path in M1-12's fenced `foundation-audit` event and ordinary
   result/evidence cells, then run
   `python3 tools/state.py promote` to reconcile the external audit gate under
   the state lock after that PASS. Until
   it ends with `audit:
   PASS`, `tools/state.py` promotes no non-exempt M2+ row (§3); the four
   early-start ids remain eligible from their locked bundles. A failing audit is fixed as an ordinary defect of
   the M1 task it names — re-run the audit after the fix, which overwrites
   the file. The audit is not a roadmap task and gets no `tasks/README.md` or
   fictional `PROGRESS.md` row; M1-12's ordinary result and evidence cells own it.
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
action (including a weekly provider cap or a Linear plan limit — a team
cap or an issue cap reached in the workspace), or a 1Password desktop app
that locks during the run (the §1 auto-lock item of `goal/PREFLIGHT.md` is a
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
proves it is in place, or `re-run`), claim and transition the task row to `blocked`
(dependents keep their status), finish the parts of the task that do not
depend on it, commit, and continue with every other runnable task. The run
ends BLOCKED only when `sh verify.sh` says so: it counts the rows itself
and prints `status: BLOCKED HUMAN` only when no row is `in-progress` or
`waiting`, nothing is runnable, and at least one row is `blocked` on an
open `PREFLIGHT-DEFECTS.md` row (D-110). The session never asserts those
preconditions in prose: it waits out `in-progress` and `waiting` rows with
a Monitor loop until each reaches `done` or `blocked`, then commits,
pushes, re-runs `sh verify.sh`, and prints the `GOAL BLOCKED` block (§7)
only if that run's last line is `status: BLOCKED HUMAN`. The human clears the items
(leaving the `Resolved` cell empty is fine for missing-input rows — the
session re-runs each proof command at the next start and fills it; an
`exhausted:` row is closed only by the human filling `Resolved`, D-093)
and re-runs the invocation; the session claims and transitions those rows back to `ready`
and resumes.

## 7. Done

`sh verify.sh` at the repository root derives the outcome, never this
session (D-110, D-083). It prints one census line and then exactly one of
`status: DONE`, `status: BLOCKED HUMAN`, `status: FAILED SYSTEM`, or
`status: PENDING`; the clean tree, the per-task `PROGRESS.md` row, the
absence of active or runnable rows, and the open defect count are checks
inside that script, not claims made in the message. COMPLETE is
`status: DONE`, BLOCKED is `status: BLOCKED HUMAN`, `GOAL FAILED` is
`status: FAILED SYSTEM` (no human input clears it), and `status: PENDING`
means the run continues. `status: PENDING` with nothing runnable and every
M1 row `done` is the M1 exit audit outstanding (CTRL-006, §5 step 7a): write
`tasks/M1-12/audit.txt`, close M1-12 with that evidence, and run promotion; it is not
a terminal state and never ends the run.

The final message has one fixed shape in both cases (D-093), and nothing
follows it:

1. Line 1, alone: `GOAL COMPLETE`, `GOAL BLOCKED`, or `GOAL FAILED`, for
   `status: DONE`, `status: BLOCKED HUMAN`, and `status: FAILED SYSTEM`
   respectively.
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
  `attempts.log`, `container.txt`, `herdr-*.txt`, `pr*.txt`).
- Never read in this session: `ROADMAP.md`, `SPEC.md`,
  `concept/*`, `analysis/*`, or any file in an involved repository. A
  single literal may be `grep`ed out of them (`grep -n '^| M3-05 ' ROADMAP.md`);
  anything larger is a subagent's job, and the subagent returns at most 15
  lines.
- Run: git on this repository, `sh verify.sh`, `sh tasks/<id>/verify.sh
  host`, `docker`/`herdr`/`jackin`/`gh`/`op` host commands of §4, the
  standing checks of §1 step 4, and `caffeinate`.
- Write: `tasks/README.md`, `PROGRESS.md`, `PREFLIGHT-DEFECTS.md`, and
  `tasks/<id>/` files — in this repository only, then commit and push at
  once (D-086).
- Updating a product or acceptance rule (D-053 applies): the session never edits
  `SPEC.md` itself, because it may not read it. It delegates the edit to a
  subagent, which updates the sole contract in `SPEC.md`, synchronizes any
  affected derived graph or procedural pointer, corrects stale non-normative
  explanation, and returns the touched paths; the session then commits and
  pushes those files together (D-104).
- Delegate: everything else, with `model: "claude-opus-5"` (D-092, D-095),
  in parallel up
  to three host subagents in flight and the §4 reserve rule.
- Never: answer from memory what a file states, re-read a large file after
  a compaction instead of delegating it, or ask the human anything.
