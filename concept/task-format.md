# Issue and checklist format

Elaborates D-003, D-004, D-012, D-013, D-014, D-043, D-044, D-049..D-053.
Since D-010 the source of truth is Linear; GitHub only hosts the repository and the pull request. This
document describes what an issue must contain and
what its local working copy looks like. The folder layout further down is
the local mirror the daemon creates from the issue, not something the human
authors in git.

## What an issue must contain (convention adopted, Q-013 / D-053)

| Field | Required | Where on the issue |
| --- | --- | --- |
| GitHub repository to work on | yes | label `repo:<owner/name>` (D-014, Q-023) |
| branch name to use | yes | Linear's own `branchName`; overridden by a `branch: <name>` line in the description; reused if it exists on the remote, otherwise created (D-014) |
| base branch for a new branch | no, default `main` | `base: <name>` line in the description (D-014) |
| jackin role to spawn | yes | label `role:<selector>`, e.g. `role:the-architect`, `role:donbeave/crew-builder` (D-012) |
| agent runtime inside the role | yes | label `agent:<runtime>`, value `claude` or `codex` only, never a lane value (Q-024); M2-05 rejects a runtime outside the role's `agents` |
| lane | yes | label `lane:L<n>` (`L1`..`L6`) taken from the task's `task.toml` `lane`; the account home, model, and effort come from `tasks/M1-13/lanes.json`, and the daemon resolves the account home from `[lanes.L<n>] account_home` in its config (M3-05) |
| model | yes, lane default if absent | label `model:<model_id>`, the exact identifier from `tasks/M1-13/lanes.json`, never a short name (D-043, D-058, D-091) |
| effort | default medium | label `effort:<level>` (D-043) |
| delivery | default `goal` | label `delivery:goal` or `delivery:prompt` (D-044) |
| prompt handed to the agent | yes | the issue description, verbatim; rendered inside the repository's `.jackin/WORKFLOW.md` frame when one exists (D-012, D-018) |
| checklist of tasks | yes | the first Markdown task list (`- [ ]`) in the description (D-013) |
| references (schemas, contracts, designs) | recommended | links or paths in the description (D-003) |
| verification | daemon-run | `.jackin/workflow.toml` `[verify] command` on the repository's base branch; last line `status: DONE` (D-018, D-030) |
| dependencies on other issues | when relevant | Linear blocking relations; gate dispatch through `dispatchable` (D-004, D-020) |

Fields the daemon maintains on the issue and a human never edits (D-049,
D-051, D-052):

| Field | Where on the issue | Values |
| --- | --- | --- |
| run state | exactly one label from the group `run:*`; removed on terminal states | `run:starting`, `run:working`, `run:waiting` (elicitation posted, D-029), `run:blocked` (harness stopped on a prompt the daemon did not cause, D-051), `run:stuck` (no activity within the stall window, D-021), `run:failed`, `run:verifying`, `run:done` |
| container identity | one session `externalUrls` entry per attempt, replaced on re-dispatch; the ledger (D-019) holds the machine-readable binding | host, jackin instance name, container id, attempt, since, attach command (`jackin hardline <instance>`) |

The daemon rejects, with one `error` activity naming the missing field, any
assigned issue missing a required field; the issue is not started and the
condition is re-evaluated every tick (D-020).

## Authoring in `tasks/` (D-038, D-050)

A task folder `tasks/<id>/` is the authored plan content that M1-12 turns
into an issue with the convention above. It contains:

- `TASK.md` — objective, scope, references, expected steps, definition of
  done, constraints; its first task list is the checklist that becomes the
  issue's checklist. It is authored container-relative: the container never
  sees this repository, so every reference to another file is written as
  `.jackin/task/refs/<name>` and the host session stages `TASK.md`,
  `task.toml`, `verify.sh`, the referenced files, and (for reviews)
  `pr.txt` into `<workspace>/.jackin/task/` before the launch (D-086); the
  same path is what M4-04 pre-fetches on the daemon path. Its Constraints
  section says `git commit -s` (D-089).
- `task.toml` — machine-readable fields mirroring the issue: `repo`,
  `branch`, `base`, `role`, `runtime`, `model`, `effort`, `delivery`,
  `depends_on`, `lane`, `fallback_lane` (the lane the daemon re-launches
  on after a stuck run, from the `fallback` column of `ROADMAP.md` §5,
  D-057; quota exhaustion follows the per-account-home chain of D-071),
  `limits` (`attempts`, default 3, the exhaustion cap of D-070).
- `expected-evidence.toml` — the evidence the task must produce, declared
  before it runs: one row per artefact with its path and the check that
  accepts it. `verify.sh` reads it and fails when a declared artefact is
  missing (D-118).
- `evidence.json` — the evidence manifest: the machine record of what the
  run actually produced for the task, written by `verify.sh` through
  `tools/evidence_manifest.py` and read by the run state store when the
  task's terminal class is derived (D-110, D-111, D-118). Its schema is
  below.
- `refs/` — the files `TASK.md` references, staged into
  `<workspace>/.jackin/task/refs/` before the launch (D-086, D-118). Every
  reference is resolved relative to the container working directory, which
  is `/workspace` on every path: the launch is `jackin workspace create
  task-<id> --workdir /workspace --mount <ws>:/workspace` and every exec is
  `docker exec -u agent -w /workspace …` (goal/EXECUTION.md §4), so the
  staged folder appears as `/workspace/.jackin/task/` and a reference is
  written `.jackin/task/refs/<name>`, never as a host path and never with a
  leading `/` of its own. `<ws>` — the mount source — is the task's worktree
  for a task that changes a repository and the evidence directory for an
  operator or evidence task, so repository files are `./…` in both cases.
- `verify.sh` — the task's verification (D-003); for repositories with
  `.jackin/workflow.toml`, `[verify] command` points at it. It is POSIX
  `sh` (`#!/bin/sh`, `set -u`; checked by M1-01 with `dash -n` and
  `shellcheck -s sh`, because the container `sh` is dash) and takes one
  argument, `container` or `host`, running only that part through
  `case "$1"`; a single-part task accepts both. The container part ends
  with `status: DONE` or `status: FAILED` and is filed as
  `verify.container.out`. It reads nothing outside `/workspace`: repository
  files as `./…` and any evidence file the host produced as
  `.jackin/task/refs/<name>`, staged there as a ref by the host session; it
  never names `tasks/<id>/…`, which does not exist in the container. The
  host part's working directory is this repository's root. The host part, whenever a container part exists,
  first asserts `tail -n1 tasks/<id>/verify.container.out` is
  `status: DONE` and otherwise prints `status: FAILED` and exits 1, so a
  passing host part can never mask a failed container part (D-086). For
  `host` rows it is run by the host Claude Code session and its output is
  filed in the folder (D-061); any check that needs the Linear token,
  `op`, the host daemon socket, host `docker`, or that launches or
  attaches to a jackin instance is a host part (`host (D-061):` sentence
  of the roadmap verify column) run by the host session whatever the
  task's role, and only unit or fixture checks stay in-container (D-081,
  D-091). A verify column that names a review or a manual check becomes
  a checklist item whose written result is filed in the folder;
  `verify.sh` checks the filed text, never a transcript, and a verify that
  asserts a transient live state (a view, a session state) is written
  against a snapshot the task files at the moment the state holds, never
  against the live query at verify time (D-091). It never asserts on its
  own `tasks/README.md` row or on the root `verify.sh` remaining count
  (D-088). Evidence another task's verify consumes is named in the
  producing row (`tasks/M1-13/lanes.json`, `dind.out`, `pr.txt`,
  `scratch-repo.txt`) and M1-01 copies the name verbatim into both
  folders. `verify.sh` never runs with `set -x`, never uses `curl -v`/
  `--trace`, and passes secrets only via `-H @-`/`--config -` from stdin;
  field non-emptiness is `jq -e '(.value // "") | length > 0'`; the host
  session scans the folder with `gitleaks` before committing any evidence
  (D-081).
- "When stuck" section in `TASK.md` — the stuck rule (D-063), present in
  every task: when the task stalls or takes too long, spawn subagents to
  analyze why and to find a solution before escalating anything.
- `preflight` section in `TASK.md` — the operator inputs this task needs
  before it starts (D-050): every credential or login as an `op://`
  reference (never a value), every trust grant (`jackin config trust grant
  <selector>`), every consent or account the human must provide, and every
  physical step on the host, each with the command or UI path that proves
  it is in place. The milestone's "Operator preflight" list in `ROADMAP.md`
  is the union of its tasks' `preflight` sections. A task whose preflight
  is empty says `preflight: none`. An input discovered missing mid-task is
  a preflight defect: the agent finishes what does not depend on it and
  marks the task blocked with the exact item.

Example `preflight` block:

```markdown
## Preflight (D-050)

- op://tailrocks/op-service-account-jackin-operator/credential — operator
  service account token; verify: `jackin config env list --role
  donbeave/crew-operator --format json` lists `OP_SERVICE_ACCOUNT_TOKEN`
  with its on-demand marker, and `grep -E 'OP_SERVICE_ACCOUNT_TOKEN *= *\{.*on_demand *= *true' "${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml"`
  matches under `[roles."donbeave/crew-operator".env]` (the file jackin
  reads; `~/.jackin/` holds state only, D-078, D-090).
- Trust: `jackin config trust grant donbeave/crew-operator` on this host.
- Browser state `~/.jackin/agent-browser-profile/state.json` saved from
  the host login (M1-06, D-077); verify: inside `crew-operator`,
  `agent-browser open https://linear.app && agent-browser get url` shows
  the workspace URL.
- Host: OrbStack running (`docker context orbstack`, D-056); laptop set not to sleep for the proof run.
```

## Local working copy

## Principles

- **One task, one folder, one agent.** A task is the unit of dispatch. An
  agent sees the whole repository for context but is instructed to work on
  exactly one task.
- **Verification is executable.** Every task has a script whose final output
  line `status: DONE` is the only accepted proof of completion.
- **References are explicit.** A task names the source-of-truth artifacts it
  must satisfy (schemas, API contracts, TUI designs) so the agent verifies
  against them instead of guessing.
- **Dependencies are declared.** The manager never infers ordering.

## Proposed layout

Placement of the plan tree inside the repository, and whether status lives in
files or in the daemon, was Q-003, closed by D-010: Linear is the task
system and this layout is only the local mirror the daemon creates.

```text
<repo>/
  plan/
    PLAN.md                      # goal, scope, references, plan-level verification
    verify.sh                    # plan-level integration verification (optional)
    tasks/
      010-schema-migration/
        TASK.md                  # what to build, how, definition of done
        task.toml                # id, dependencies, role, runtime hints, limits
        verify.sh                # prints "status: DONE" on success
        expected-evidence.toml   # evidence the task must produce (D-118)
        evidence.json            # what it actually produced (D-110, D-118)
        refs/                    # files TASK.md references (D-086)
      020-api-contract/
        ...
      030-tui-screen/
        ...
```

### `TASK.md`

Written for the agent. Contains: the objective in one paragraph; the exact
scope (what is in, what is out); the references to satisfy, by path; the
steps the author expects; the definition of done in plain language, matching
what `verify.sh` checks; constraints (do not touch other tasks' areas); the
preflight (D-050); and a "When stuck" section (D-063).

Template:

```markdown
# <id> <title>

## Objective
## Scope
## References
## Steps
## Checklist
- [ ] ...
## Definition of done
## Constraints
Always `git commit -s` (DCO is a required check, D-089).
## Preflight (D-050)
## Authorization (D-055, D-079)

This task text is the operator's per-PR authorization: when a step names
a merge, merge the pull request yourself with `gh pr merge` once every
required check is green; do not wait for a further "merge it"; never
bypass a failed check. Role repositories commit to `main` (D-074).

## When stuck (D-063)

If this task stalls or takes longer than expected, do not escalate first.
Spawn subagents to analyze why (wrong assumption, missing input, failing
check, environment) and to propose a solution; apply it; only then, if it
is a genuine operator input, mark the task blocked with the exact item.
```

### `task.toml`

Machine-readable. Minimal fields under consideration:

```toml
id = "020-api-contract"
depends_on = ["010-schema-migration"]
role = "the-architect"          # jackin role
runtime = "claude"              # optional hint; manager may override
lane = "L1"                     # ROADMAP §5
fallback_lane = "L2"            # D-057: next lane on a stuck run (quota: D-071 chain)
limits = { attempts = 3, minutes = 90 }   # attempts = exhaustion cap (D-070)
```

### `verify.sh`

Runs inside the task's environment with the argument `container` or
`host` (D-086). Exit code is informational; the manager
reads the last line and accepts only `status: DONE`. The run-level
`verify.sh` derives one of four terminal classes — `DONE`,
`BLOCKED HUMAN`, `FAILED SYSTEM`, `PENDING` — from the run state store
(D-110). Anything else is a
failure with the script output as evidence. Who authors this script and how
it is trusted: the verify command is repository-owned on the base branch,
run by the daemon, and reviewed by `crew-reviewer` when an agent authored
it (D-030, D-053).

### `evidence.json`

The evidence manifest binds a task's claim of success to what actually
ran. Without it, implementation and acceptance are the same actor in the
same context and a task reaches `done` because the implementing agent
reported success; with it, acceptance is a check over recorded commands,
exit codes, output hashes, tool versions and the integrated SHA.

| Field | Type | Meaning |
| --- | --- | --- |
| `task` | string | the task id, matching the folder name and the `tasks/README.md` row |
| `bundle_hash` | 40- or 64-hex string | hash of the task bundle (`TASK.md`, `task.toml`, `verify.sh`, `refs/`) the run was launched from |
| `integrated_sha` | 40-hex string | the commit the verification ran against, never the agent's working tree (D-112) |
| `commands` | array of objects | one entry per command the verification ran, in order |
| `commands[].cmd` | array of strings | the argument vector, unquoted and unshelled |
| `commands[].exit_code` | integer | the process exit status |
| `commands[].stdout_sha256` | 64-hex string | SHA-256 of the raw stdout bytes |
| `commands[].stderr_sha256` | 64-hex string | SHA-256 of the raw stderr bytes |
| `commands[].started`, `.finished` | RFC 3339 UTC strings | when the command started and finished |
| `tool_versions` | object | tool name to version line, captured at run time (`git`, `jq`, `python3`, `gitleaks`, `gh`, `docker` when present) |
| `external_object_ids` | object | every external object the run created or touched: pull request URLs, Linear issue ids, container ids |
| `created`, `updated` | RFC 3339 UTC strings | when the manifest was first written and last written |
| `result_class` | enum | exactly one of `DONE`, `BLOCKED HUMAN`, `FAILED SYSTEM`, `PENDING` (D-110) |
| `attempt` | integer | the attempt within the epoch (`limits.attempts`, D-070) |
| `epoch` | integer | the run epoch (D-113) |
| `fencing_token` | integer | the lease's fencing token at write time (D-113) |

No secret value is ever written to the manifest: commands are recorded as
they were invoked, so a secret is passed on stdin and never as an argument
(D-035, D-081), and the folder is scanned with `gitleaks` before commit.

`tools/evidence_manifest.py` (Python 3 standard library only) writes and
checks it:

```sh
tools/evidence_manifest.py run --task <id> --bundle-hash <h> \
    --integrated-sha <sha> --dir tasks/<id> [--attempt N --epoch N \
    --fencing-token N --result-class DONE --external pr_url=<url>] \
    -- <cmd...> [-- <cmd...>]
tools/evidence_manifest.py validate tasks/<id>/evidence.json
tools/evidence_manifest.py validate --all
```

`run` executes each command, streams its output through, hashes stdout and
stderr, records the exit code and timestamps, and writes the manifest
atomically (temporary file in the same directory, then `os.replace`), so a
killed run never leaves a half-written manifest; a repeated `run` appends
to `commands`. It exits non-zero when any recorded command failed.
`validate` enforces the acceptance semantics of
`jq -e '.integrated_sha and .commands and .bundle_hash'` — each field
present and non-empty — plus the 40-hex shape of `integrated_sha`, the
hex shape of the output hashes, and the `result_class` enum, and exits
non-zero on failure.

The acceptance condition over *every* manifest is not a per-task check: it
is enforced by the root oracle, which validates the manifest of every task
whose `tasks/README.md` row is `done` and refuses `status: DONE` for the
run while any of them is missing or invalid.

## Status

Status values the manager tracks per task: `draft`, `ready`, `runnable`,
`running`, `verifying`, `done`, `failed`, `blocked` (waiting on a human
decision). Status lives in Linear (D-010) as the `run:*` label group and
workflow states (D-049); the local ledger is a non-authoritative cache
(D-019).

## What today's prompts become

Today's whole-plan prompt is retired. The per-task prompt already in use is
kept as the canonical shape and generated by the manager from the task
folder rather than typed by hand.
