# M1-09 Create Linear team, labels, workflow states, and issue template

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | M1-07, M1-08, M1-10, M1-13 |
| role | `donbeave/crew-operator` |
| lane | L5 |
| runtime | codex |
| fallback lane | L6 |
| delivery | prompt |
| size | S |
| repositories | Linear |
| branch | `main` |

## Objective

Create Linear team, labels, workflow states, and issue template.

## Scope

Create team `JACKIN` through the browser profile as a public team, so the app user and every later member reach it without a per-member invite (the app token has no `admin` scope, D-060); the workspace plan's team and issue headroom is the human's preflight item (`goal/PREFLIGHT.md` §2) and a workspace at its cap is never a run-time defect this task can clear; on the app details page grant the app user access to the new team (analysis/linear-agents.md A8); create the label groups the convention needs (`role`, `agent`, `model` with values from `tasks/M1-13/` (D-058), `lane` with one value `lane:L<n>` per lane of `tasks/M1-13/lanes.json`, `effort`, `delivery`, `repo`, `auto-dispatch`, and the `run` group for M5), per team a `Review` and a `Merging` workflow state, both of type `started` and both positioned after `In Progress` and after every other pre-existing `started` state, with their ids recorded in `tasks/M1-09/states.json` (the daemon picks up the lowest-position `started` state, and a Review state ahead of it would make every acknowledged issue non-dispatchable, SPEC §6.1), and an issue template with a checklist skeleton (no delegate pre-set, D-073).

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
- [ ] host check passes: `op read`
- [ ] host check passes: `curl --config -`
- [ ] host check passes: `jq -r '.[].label' tasks/M1-13/lanes.json`
- [ ] host check passes: `jq -e '.[0].name != "Review" and .[0].name != "Merging"'`
- [ ] `states.json` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none

Host part (run by the host Claude Code session, D-061):

> GraphQL under the Linear-token rule of `goal/EXECUTION.md` §4 (host `op read` piped into `curl --config -`, never inside a container) lists the team `JACKIN`, the labels (the set of `model:*` values equals `jq -r '.[].label' tasks/M1-13/lanes.json`, D-091), and the states by name; `team(id){members}` contains the app user id from `op://jackin/linear-workspace`; the response of `workflowStates(filter:{team:{key:{eq:$key}}, type:{eq:"started"}})` sorted by "position" is filed as `tasks/M1-09/states.json` and `jq -e '.[0].name != "Review" and .[0].name != "Merging"'` on it exits 0

## Evidence expected (D-118)

- `tasks/M1-09/states.json` (host part)

## Proof (browser/attach)

Label groups and template visible in team settings.

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
