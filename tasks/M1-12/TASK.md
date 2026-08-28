# M1-12 Mirror locked task bundles into Linear issues

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

Mirror locked task bundles into Linear issues.

## Scope

In team `JACKIN`, create the one Linear project and milestones M1..M12. Mandatory pre-step: subagents verify the current state of every involved repository so each issue reflects what is already merged or present on `feat/managed-execution`. Read the immutable source commit from `[plan].commit` in `run/LOCK.toml`; it contains the locked SPEC, ROADMAP, and task bundles (CTRL-002), and must never be replaced with `HEAD`. For every M2+ `tasks/<id>/` row, regardless of current durable state, create or reconcile exactly one issue: title `<id> <title>`; description first line `task_source: https://github.com/tailrocks/ecosystem/tree/<plan.commit>/tasks/<id>` followed by the locked `TASK.md`; canonical role, agent, model, lane, effort, delivery, repository, and auto-dispatch labels; workflow state matching every exact durable status (`planned`, `ready`, `resource-waiting`, `blocked`, or `failed-system` → ordinary `unstarted`; `leased`, `in-progress`, or `waiting` → ordinary first `started`; `done` → `completed`); and blocking relations from `depends_on` except non-blocking reviews. Attach immutable raw links, idempotent by title, for `task.toml`, `verify.sh`, `expected-evidence.toml`, and every `refs/<name>`, all pinned to that same `<plan.commit>` (ISSUE-006, ISSUE-014). Never preset a delegate or rerun an early-start task; backfill it at its current durable status. The host coordinator performs GraphQL with its own client-credentials token under `goal/EXECUTION.md` §4; the manager daemon mints its separate in-memory runtime token, and no role container or worker receives either token. Run reconciliation twice and write the two GraphQL observations to `tasks/M1-12/issues.json`: one object with `team{id,key}`, `project{id,milestones[{id,name}]}`, `workflow_states{unstarted,first_started,completed}` (each `{id,name,type}`), and exactly two `passes`; each pass contains `early_start_attempts` for the four early ids and one issue per mirrored task with `task_id,id,identifier,url,title,team_id,project_id,milestone,milestone_id,source_commit,task_source,description,labels,state_type,state_id,delegate_id,blockers,attachments[{title,url}]`. `issues.json` is the idempotent task-id-to-issue-URL map consumed by dispatch; the second pass must retain every issue identity, source commit, and early-start attempt count. This is the sole channel by which daemon-dispatched roadmap tasks receive their locked verifier, evidence declaration, and references.

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
- [ ] host check passes: `python3 tools/verify_issue_mirror.py tasks/M1-12/issues.json`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `issues.json` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> container (cwd `/workspace`, from `jackin workspace create task-M1-12 --workdir /workspace --mount <ws>:/workspace`): the signed-in browser proves the project, milestones, and representative issue ids/URLs match the captured mirror; the container receives no Linear credential

Host part (run by the host Claude Code session, D-061):

> under the §4 Linear-token rule, perform two idempotent GraphQL reconciliation passes, file their complete observations as `tasks/M1-12/issues.json`, then `python3 tools/verify_issue_mirror.py tasks/M1-12/issues.json` exits 0, proving the exact locked task set, each task bundle's bytes at `plan.commit` against its `run/LOCK.toml` hash, the captured full GraphQL description against the locked `TASK.md`, issue identity, team/project/milestone membership, canonical labels, ordinary workflow-state projection, null delegate, blockers, immutable attachment set, second-pass idempotence, and unchanged early-start attempt counts

When a container part exists the host part first asserts that
`tasks/M1-12/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M1-12/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M1-12/issues.json` (container part)

## Proof (browser/attach)

The M2+ issue mirror matches ISSUE-006, ISSUE-014, ACC-001, and ACC-013, including all planned rows and locked-source early-start backfill.

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
