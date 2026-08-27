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
| agent runtime inside the role | yes | label `agent:<runtime>`, e.g. `agent:claude`; until per-launch account selection exists, the lane value, e.g. `agent:codex-chainargos` (Q-024) |
| model | yes, lane default if absent | label `model:<name>`, e.g. `model:opus-5` (D-043) |
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
  issue's checklist.
- `task.toml` — machine-readable fields mirroring the issue: `repo`,
  `branch`, `base`, `role`, `runtime`, `model`, `effort`, `delivery`,
  `depends_on`, `lane`.
- `verify.sh` — the task's verification (D-003); for repositories with
  `.jackin/workflow.toml`, `[verify] command` points at it.
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

- op://tailrocks/op-service-account-jackin-operator — operator service
  account token; verify: `jackin config env list --scope donbeave/crew-operator`
  shows the on-demand entry.
- Trust: `jackin config trust grant donbeave/crew-operator` on this host.
- Browser profile `~/.jackin/agent-browser-profile` logged in to Linear and
  GitHub (M1-06); verify: `agent-browser open linear.app` shows the account.
- Host: Docker Desktop running; laptop set not to sleep for the proof run.
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
      020-api-contract/
        ...
      030-tui-screen/
        ...
```

### `TASK.md`

Written for the agent. Contains: the objective in one paragraph; the exact
scope (what is in, what is out); the references to satisfy, by path; the
steps the author expects; the definition of done in plain language, matching
what `verify.sh` checks; constraints (do not touch other tasks' areas).

### `task.toml`

Machine-readable. Minimal fields under consideration:

```toml
id = "020-api-contract"
depends_on = ["010-schema-migration"]
role = "the-architect"          # jackin role
runtime = "claude"              # optional hint; manager may override
limits = { attempts = 3, minutes = 90 }
```

### `verify.sh`

Runs inside the task's environment. Exit code is informational; the manager
reads the last line and accepts only `status: DONE`. Anything else is a
failure with the script output as evidence. Who authors this script and how
it is trusted: the verify command is repository-owned on the base branch,
run by the daemon, and reviewed by `crew-reviewer` when an agent authored
it (D-030, D-053).

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
