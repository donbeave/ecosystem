# Tailrocks Ecosystem — Agent Manager concept

This repository holds the specification, derived implementation plan, and run
state for a manager that runs many AI coding agents on big tasks inside the
Tailrocks ecosystem (jackin, termrock, parallax, velnor, tailrocks-skills,
...). `SPEC.md` alone defines the final product and its acceptance conditions.
The other planning documents provide non-normative context or derive execution
order from that contract. The repository also holds the task bundles and
evidence of the `/goal` run, and the machine files that run and gate it — `tools/`,
`tests/`, `run/`, `findings/`, the root `verify.sh`, and `tasks/<id>/`, at
exactly the paths D-118 permits.

No product code lives here: that is written in the involved repositories
(github.com/jackin-project, github.com/tailrocks, donbeave/jackin-*). The
planning documents are improved incrementally — each conversation that reaches
agreement on a point updates the relevant file.

## Start the run

Prerequisites: complete `goal/PREFLIGHT.md` §1–§5. An undone §3–§5 item is not a guaranteed
stop: it becomes a `PREFLIGHT-DEFECTS.md` row that blocks only the tasks needing it, and ends
the run as BLOCKED only when nothing else is runnable (D-050, D-070). Run the commands below from
this repository; do not start Claude separately.

```text
/goal Follow GOAL.md. Goal reached only when the current turn ends with a message whose first line is exactly `GOAL COMPLETE` or `GOAL BLOCKED` and whose last lines are the literal output of `sh verify.sh` from that turn: last line `status: DONE` for COMPLETE, or `status: BLOCKED HUMAN` preceded by the open PREFLIGHT-DEFECTS.md rows for BLOCKED. Any other turn end is not the goal.
```

This one line is the only invocation; every document that says "the invocation line of
`GOAL.md`" means it, copied verbatim — never shortened to `/goal Follow GOAL.md`, because the
argument carries the two terminal facts the runner's judge checks (D-083). `GOAL.md` itself is
the prompt the runner executes and holds nothing else.

### Operator kickoff

Paste each command block below from any directory inside this checkout. Every block resolves the
repository root before running its lifecycle command. Start with the complete fresh-start sequence:

```sh
cd "$(git rev-parse --show-toplevel)" && \
  sh tools/readiness.sh static && \
  sh tools/readiness.sh live && \
  sh tools/supervisor.sh start --dry-run && \
  sh tools/supervisor.sh start
```

Neither gate launches an AI agent or makes an AI-provider request. The live gate checks command
versions, host/service state, `autoContinueAtUsageLimit`, presence of `claude-yolo`, and the
literal yolo flag/config setting in `tools/supervisor.sh`; it never starts Herdr, Claude, or a
roadmap task. Provider-login calls listed in `goal/PREFLIGHT.md` §1 are separate standing checks.
Fix every reported failure. Both readiness commands must end with:

```text
status: READY
```

They must also print the same `lock_hash`. The dry run must pass before the real `start` command.
It prints the launch plan without starting the coordinator. A successful readiness gate may print
the next command, but does not run it.

`start` is the only ignition point. Readiness never calls it. Before launching anything, it prints
the exact Herdr server/workspace commands, interactive Claude launch, canonical `/goal` line, and
attach command. It then creates the isolated Herdr 0.8.2 session `ecosystem-coordinator`, starts
Claude as the named Herdr agent `ecosystem-coordinator` without `-p`, waits for its input prompt,
submits the canonical `/goal` line, and attaches the terminal to the Herdr UI. If automatic
submission does not land, copy the printed `/goal` line and paste it into Claude.
Before launch, `start`/`resume` refuse a live legacy coordinator pid recorded
in `run/logs/coordinator.pid`. When the named Herdr coordinator is absent,
they also refuse any Claude pid whose cwd resolves exactly to this repository.
The detector is read-only and names every process to stop.

From another terminal, attach to the running Claude UI:

```sh
cd "$(git rev-parse --show-toplevel)" && \
  herdr session attach ecosystem-coordinator
```

Detach without stopping any pane by pressing `Ctrl-b`, releasing it, then pressing `q`. Closing
the terminal window also detaches. Reattach with the same command. Do not start a second
coordinator while this named session exists. Type the printed `/goal` line only when automatic
delivery failed.

Inspect durable run state without attaching:

```sh
cd "$(git rev-parse --show-toplevel)" && \
  sh tools/supervisor.sh status
```

Read the latest 200 lines of coordinator output without attaching:

```sh
cd "$(git rev-parse --show-toplevel)" && \
  sh tools/supervisor.sh read --lines 200
```

To stop intentionally, stop the named Herdr session and confirm the result:

```sh
cd "$(git rev-parse --show-toplevel)" && \
  sh tools/supervisor.sh stop && \
  status_output="$(sh tools/supervisor.sh status)" && \
  printf '%s\n' "$status_output" && \
  printf '%s\n' "$status_output" | grep -Fqx 'herdr: not running' && \
  printf '%s\n' "$status_output" | grep -Fqx 'coordinator: not running'
```

`stop` runs `herdr session stop ecosystem-coordinator --json`; Herdr terminates every pane process in
that isolated session, including Claude and task/probe panes. Status must report both Herdr and the
coordinator as not running before another kickoff.

After a crash, an intentional stop, or a BLOCKED result, first satisfy every open
`PREFLIGHT-DEFECTS.md` proof command. Then run the complete resume sequence from this repository:

```sh
cd "$(git rev-parse --show-toplevel)" && \
  sh tools/readiness.sh static && \
  sh tools/readiness.sh live && \
  sh tools/supervisor.sh resume --dry-run && \
  sh tools/supervisor.sh resume
```

Both readiness commands must end with `status: READY` for the same lock hash, and the resume dry
run must pass before the real `resume` command. `resume` is the authoritative continuation path;
after any stop, use `resume`, never `start`. Do not launch Claude separately or manually rerun the
`/goal` invocation.

`resume` attaches to a live coordinator; if none survives, it reconciles durable state, prints
every command again, relaunches the named Claude agent, submits the same `/goal`, and attaches.
If interactive attach fails, the command exits 4 but preserves the live coordinator and session;
retry from anywhere inside the checkout:

```sh
cd "$(git rev-parse --show-toplevel)" && \
  herdr session attach ecosystem-coordinator
```

Completed tasks are not repeated. Never run `start` or `resume` merely to inspect status. See
`goal/EXECUTION.md` §1 "Supervisor".

Herdr is a pinned host dependency for this run. Install it only when absent, then verify the
version before readiness:

```sh
cd "$(git rev-parse --show-toplevel)" && \
  brew install herdr && \
  herdr --version
```

The required output is `herdr 0.8.2`. Herdr's official direct installer is
`curl -fsSL https://herdr.dev/install.sh | sh`; use one install method, not both.

Wave 0 is armed once, by `python3 tools/state.py arm`: it moves every dependency-free task
— M1-01, which verifies the pre-materialised task bundles (D-072, D-114) — from
`planned` to `ready`, and is
idempotent. Every later `done` transition promotes each `planned` task whose dependencies
are all `done` to `ready`, so a row is `ready` before it is ever dispatched and no task
runs from a bare row.

The supervisor passes the model and permission mode pinned by D-095/D-120 through Herdr's
`agent start` command:

```text
claude --settings '{"skipDangerousModePermissionPrompt":true}' \
       --dangerously-skip-permissions --model claude-fable-5
```

Every agent runtime runs in its yolo mode
— Claude Code with `--dangerously-skip-permissions`, Codex CLI with
`--dangerously-bypass-approvals-and-sandbox` — on the host and in every container; isolation
comes from the container, not from approvals, and no permission allowlist exists anywhere
(D-121). `claude-fable-5` at effort high is
the host session; every subagent it launches runs `claude-opus-5` (`AGENTS.md` delegation
law). The permission mode is `bypassPermissions`, so an unattended run never stops on a
permission prompt and no tool allowlist is needed; `.claude/settings.json` is committed in
this repository and pins the host model, sets `skipDangerousModePermissionPrompt`, and
denies `git push --force` and `git push -f`. Only a new irreversible operation is ever
added to that file, as a `deny` entry.

The run's terminal class is derived by `verify.sh` from the run state store, never
asserted by an agent, and is one of `DONE`, `BLOCKED HUMAN`, `FAILED SYSTEM`, `PENDING`
(D-110). COMPLETE and BLOCKED below are the human-facing names of the first two;
`FAILED SYSTEM` means a plan, tool, or environment defect that no human input would
unblock. The implementation run is armed only after a static and a live readiness gate
both print `status: READY` for the same lock hash (D-109).

The run has exactly two good outcomes (D-069, D-070, D-083), and `verify.sh` decides which
one it reached from the state store and the repositories, not from anything an agent writes.
COMPLETE: `sh verify.sh` prints `status: DONE` as its last line in the final turn — every
task is `done`, its evidence names a commit that is an ancestor of the pushed head, its
recorded bundle hash still matches its bundle, the tree is clean, and `PROGRESS.md` holds one
row per done task. BLOCKED: `status: BLOCKED HUMAN` — no task is runnable, none is
`in-progress` or `waiting`, and `PREFLIGHT-DEFECTS.md` has a row with an empty `Resolved`
cell, the only reason the run stops. The two bad outcomes are `status: PENDING`, which means
work remains and the run has simply not finished, and `status: FAILED SYSTEM`, an integrity
failure — forged, stale, dirty, unpushed, or contradicting the state store — that no operator
input would clear. A failing check, a design question, a review, a quota
wait, a capsule dialog, and a defect in an involved project are never reasons to stop.
After BLOCKED, a crash, or an intentional stop, `sh tools/supervisor.sh resume` resumes durable
state; nothing finished is redone (`goal/EXECUTION.md` §1). A live coordinator handles context
compaction itself.

## Map

| File | Purpose |
| --- | --- |
| [SPEC.md](SPEC.md) | Sole source of truth for the final product, required behavior, invariants, and acceptance conditions. |
| [ROADMAP.md](ROADMAP.md) | Derived implementation graph: milestones, task ids, dependencies, order, roles, and lanes. It does not define product behavior or acceptance. |
| [VISION.md](VISION.md) | Non-normative problem statement, observations, and target summary. Start here for context. |
| [OPEN-QUESTIONS.md](OPEN-QUESTIONS.md) | Non-normative question inbox. A resolved product answer is authoritative only when incorporated into `SPEC.md`. |
| [concept/manager.md](concept/manager.md) | Non-normative explanation of the manager architecture and lifecycle. |
| [concept/task-format.md](concept/task-format.md) | Non-normative examples of issue, task, evidence, and verifier formats. |
| [concept/roles.md](concept/roles.md) | Non-normative rationale and examples for the roles used to build the product. |
| [concept/credentials.md](concept/credentials.md) | Dated 1Password inventory and readiness context; metadata only. |
| [concept/workflow.md](concept/workflow.md) | Non-normative walkthrough of the manual and target workflows. |
| [analysis/jackin.md](analysis/jackin.md) | Dated evidence about jackin, with cited gaps and historical recommendations. |
| [analysis/termrock.md](analysis/termrock.md) | Dated evidence about termrock, with cited gaps and historical recommendations. |
| [analysis/symphony.md](analysis/symphony.md) | Dated evidence about openai/symphony and historical recommendations. |
| [analysis/linear-agents.md](analysis/linear-agents.md) | Dated Linear and jackin evidence plus historical proposals. |
| [AGENTS.md](AGENTS.md) | Rules for agents (and humans) working in this repository: the two modes, the delegation law, the status contract, the token economy. `CLAUDE.md` is a symlink to it. |
| [GOAL.md](GOAL.md) | The `/goal` prompt and run-procedure entry point. It does not define the final product or acceptance. |
| [goal/EXECUTION.md](goal/EXECUTION.md) | Mechanical host-session procedure: start, per-task loop, execution paths, resume, STOP, and budget. |
| [goal/PREFLIGHT.md](goal/PREFLIGHT.md) | Everything the human provides once before the run (D-050), consolidated from `ROADMAP.md`. |
| [verify.sh](verify.sh) | Execution-completion gate: derives the run's terminal class from the state store, compiled graph, and repository. Product acceptance remains defined by `SPEC.md`. |
| [PROGRESS.md](PROGRESS.md) | Append-only ledger of the run: one row per task with lane, path, result, evidence. |
| [PREFLIGHT-DEFECTS.md](PREFLIGHT-DEFECTS.md) | Operator inputs found missing mid-run; the only reason the run stops. |

## Working rules

- Planning only in the planning documents. No source code, no prototypes, no scaffolding in this repository; that rule never forbids the run's own machine files, which are permitted at exactly these paths (D-118): `tools/` (POSIX `sh` or Python 3 stdlib only), `tests/` (fixtures and harnesses, same two languages), `run/LOCK.toml`, `run/state.db` or `run/events.jsonl`, `findings/disposition.toml`, `.claude/settings.json` (D-095), the root `verify.sh` (D-069), and under `tasks/<id>/` — `TASK.md`, `task.toml`, `verify.sh`, `expected-evidence.toml`, `evidence.json`, `refs/`, and text evidence (D-038, D-093).
- Authority is explicit: `SPEC.md` alone owns final-product behavior and acceptance; `ROADMAP.md` owns only the derived task graph and order; `GOAL.md` + `goal/EXECUTION.md` own procedure; `VISION.md`, `QUESTIONS.md`, `concept/`, and `analysis/` are non-normative context or evidence.
- Analyses cite files and lines in the real repositories; opinions are labeled as such.
