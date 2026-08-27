# M2-06 `jackin daemon status` lists managed issues

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M2 |
| depends on | M2-03, M2-05 |
| role | `the-architect` |
| lane | L5 |
| runtime | codex |
| fallback lane | L6 |
| delivery | goal |
| size | S |
| repositories | jackin |
| branch | `feat/managed-execution` |

## Objective

`jackin daemon status` lists managed issues.

## Scope

Extend the host daemon socket with a query returning seen issues, their parsed fields, and last event time; print via `jackin daemon status --format json`. Seed of the state snapshot (D-025).

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
- [ ] host check passes: `jackin daemon status --format json | jq -e --arg id "$SCRATCH" '[.issues[]|select(.identifier==$id)]|length==1'`
- [ ] `scratch-issue.txt` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none

Host part (run by the host Claude Code session, D-061):

> `jackin daemon status --format json | jq -e --arg id "$SCRATCH" '[.issues[]|select(.identifier==$id)]|length==1'` with `$SCRATCH` read from `tasks/M2-06/scratch-issue.txt` (the scratch issue is created and delegated by this task's operator step; roadmap issues carry no delegate, D-073)

## Evidence expected (D-118)

- `tasks/M2-06/scratch-issue.txt` (host part)

## Proof (browser/attach)

None for this task.

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
