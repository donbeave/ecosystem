# M1-12 Turn finalized task folders into Linear issues (D-038, D-040, D-060)

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | M1-01, M1-09, M1-10, M1-13 |
| role | `donbeave/crew-operator` |
| lane | L5 |
| runtime | codex |
| fallback lane | L6 |
| delivery | goal |
| size | M |
| repositories | ecosystem, Linear |
| branch | `main` |

## Objective

Turn finalized task folders into Linear issues (D-038, D-040, D-060).

## Scope

In team `JACKIN`, create the one Linear project and its milestones M1..M12. Mandatory pre-step: subagents verify the current state of the work in every involved repository (what is already merged or on `feat/managed-execution`) and each issue reflects it. Then, for every M2+ `tasks/<id>/` whose `tasks/README.md` row is not `planned` (M1 tasks never get issues; they run by hand from their folders), create an issue from the template: title `<id> <title>`, description whose first line is `task_source: https://github.com/tailrocks/ecosystem/tree/<sha of HEAD>/tasks/<id>` (refreshed on every idempotent re-run) followed by the full `TASK.md` text (the container never sees this repository, D-086) including the checklist and the Authorization section (D-079), labels per convention (role, agent, model per `tasks/M1-13/lanes.json` only — never a guessed value (D-058, D-091), `lane:<the lane of the task's own `task.toml`>`, effort, delivery, `auto-dispatch`), a workflow state matching the row (`ready` and `blocked` → `Todo`, type `unstarted`, a `blocked` row with a comment naming its `PREFLIGHT-DEFECTS.md` row; `in-progress`/`waiting` → the first `started`-type state; `done` → the `completed`-type state), blocking relations from `depends_on` (review tasks are never a blocker, D-055). For every issue, `attachmentCreate` one link per staged bundle file, idempotent by title — `task.toml`, `verify.sh`, and `refs/<name>` for each `## References` entry — with url `https://raw.githubusercontent.com/tailrocks/ecosystem/<that sha>/tasks/<id>/<file>` (the repository is public, D-065, so the daemon fetches them over HTTPS with no token); reconcile titles and urls on re-run. This is the only channel by which a daemon-dispatched task receives its `verify.sh` and references (M4-04 fetches them). No delegate is set: the host session delegates each issue when the daemon can serve it (D-073). Write the id → issue URL map to `tasks/M1-12/issues.json` (merged on re-run); the host session, the only writer of this repository, merges the URLs into `tasks/README.md` in the same commit that sets this row (D-086). Repeatable and idempotent (skips ids that already have an issue; reconciles labels and state on existing ones); re-run whenever a row gains `ready` (D-073, D-114).

## References

The container never sees this repository, so every reference below is
container-relative (D-086).

- `.jackin/task/refs/sources.txt` — the roadmap row and the decisions
  this task is bound by.
- `.jackin/task/TASK.md` — this file.
- `.jackin/task/verify.sh` — the verification this task must pass.
- `.jackin/task/expected-evidence.toml` — the evidence it must file.

## Steps

1. Read the scope above and the references it names.
2. Do the work in the repositories listed, on the branch named above.
3. File the expected evidence in the task folder.
4. Run `sh verify.sh container` (and, host-side, `sh verify.sh host`)
   until the last line is `status: DONE`.

## Checklist

- [ ] The scope above is implemented in the listed repositories.
- [ ] container check passes: `jackin workspace create task-M1-12 --workdir /workspace --mount <ws>:/workspace`
- [ ] host check passes: `jq -r '.[].label' tasks/M1-13/lanes.json`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `issues.json` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> container (cwd `/workspace`, from `jackin workspace create task-M1-12 --workdir /workspace --mount <ws>:/workspace`): `/workspace/issues.json`, which the host session files as `tasks/M1-12/issues.json`, has one URL per non-"planned" M2+ row

Host part (run by the host Claude Code session, D-061):

> after the merge, every non-"planned" M2+ row in `tasks/README.md` has a Linear URL, no M1 row has one, no issue carries a delegate, every issue's description starts with its `task_source:` line and carries attachments titled `task.toml` and `verify.sh`, the set of `model:*` label values equals `jq -r '.[].label' tasks/M1-13/lanes.json`, and GraphQL confirms team, project, milestone, labels, states, and `inverseRelations`

When a container part exists the host part first asserts that
`tasks/M1-12/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M1-12/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M1-12/issues.json` (container part)

## Proof (browser/attach)

The M2 issues exist in the `JACKIN` project with correct labels, milestone, and blockers.

## Definition of done

The scope is implemented, the evidence above is filed, every touched
repository is committed and pushed, and `verify.sh` prints
`status: DONE` as its last line for every part this task has.

## Constraints

Always `git commit -s` (DCO is a required check, D-089). Work only on
this task; do not touch another task's area. Fix an involved project
rather than working around it (D-046). No secret value in any file,
log, message, or image: every credential is an `op://` reference
(D-035, D-081).

## Preflight (D-050)

preflight: none beyond the milestone's "Operator preflight" list in
`ROADMAP.md`. An input only a human can provide that is discovered
missing mid-task is a preflight defect: finish what does not depend on
it and mark the task blocked with the exact item.

## Authorization (D-055, D-079)

This task text is the operator's per-PR authorization: when a step
names a merge, merge the pull request yourself with `gh pr merge` once
every required check is green; do not wait for a further "merge it";
never bypass a failed check. Role repositories commit to `main`
(D-074).

## When stuck (D-063)

If this task stalls or takes longer than expected, do not escalate
first. Spawn subagents to analyze why (wrong assumption, missing input,
failing check, environment) and to propose a solution; apply it; only
then, if it is a genuine operator input, mark the task blocked with the
exact item.
