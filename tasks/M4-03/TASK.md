# M4-03 Exec-with-result inside an instance

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M4 |
| depends on | M1-02 |
| role | `the-architect` |
| lane | L4 |
| runtime | codex |
| fallback lane | L5 |
| delivery | goal |
| size | M |
| repositories | jackin |
| branch | `feat/managed-execution` |

## Objective

Exec-with-result inside an instance.

## Scope

Generalize `ExecCommand` into "run this command in the instance, return exit code, stdout, stderr, duration", with a timeout, over the control socket; expose as `jackin daemon exec <instance> -- <cmd>`. Gap 4.

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
- [ ] The container part of the verify contract below holds.
- [ ] host check passes: `jackin load the-architect probe-M4-03 --agent claude`
- [ ] host check passes: `jackin daemon exec <that probe> -- sh -c 'echo status: DONE'`
- [ ] host check passes: `jq -e '.exit == 0 and (.stdout | test("status: DONE"))' tasks/M4-03/exec.json`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `exec.json` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> protocol round-trip test

Host part (run by the host Claude Code session, D-061):

> the task itself starts the host daemon from the branch build if it is not running (`goal/EXECUTION.md` §5 step 4a applies from the earlier of M2-03 and this task, since M4-03 may start as soon as M1-02 exists), loads one probe instance (`jackin load the-architect probe-M4-03 --agent claude`), runs `jackin daemon exec <that probe> -- sh -c 'echo status: DONE'`, files the result as `tasks/M4-03/exec.json` ("exit", "stdout", "stderr", "duration") and ejects the probe; the verify asserts only `jq -e '.exit == 0 and (.stdout | test("status: DONE"))' tasks/M4-03/exec.json`

When a container part exists the host part first asserts that
`tasks/M4-03/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M4-03/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M4-03/exec.json` (container part)

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
