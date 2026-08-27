# M7-02 Failure classes, retry, stall recovery, blocked

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M7 |
| depends on | M7-01, M5-03 |
| role | `the-architect` |
| lane | L2 |
| runtime | claude |
| fallback lane | L3 |
| delivery | goal |
| size | M |
| repositories | jackin |
| branch | `feat/managed-execution` |

## Objective

Failure classes, retry, stall recovery, blocked.

## Scope

Implement the retry policy (D-021, D-027: 3 attempts, 20 continuations, 5-minute stall, agent-class failures only) with the persisted ledger (D-019); a `stuck` run (M5-03) past the recovery threshold is killed and retried.

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
- [ ] container check passes: `cargo nextest run -p jackin-daemon retry::`
- [ ] host check passes: `tail -n1 tasks/M7-02/verify.container.out`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `verify.container.out` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> `cargo nextest run -p jackin-daemon retry::` passes: backoff and the three-attempt cap, twenty continuations, and a stalled fixture killed after the five-minute window and retried, with the ledger persisted across a restart

Host part (run by the host Claude Code session, D-061):

> `tail -n1 tasks/M7-02/verify.container.out` is `status: DONE` and the file is committed as the task's evidence

When a container part exists the host part first asserts that
`tasks/M7-02/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M7-02/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M7-02/verify.container.out` (container part)

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
