# M1-02 Build and install jackin from `feat/managed-execution`

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | none |
| role | `the-architect` |
| lane | L1 |
| runtime | claude |
| fallback lane | L2 |
| delivery | goal |
| size | S |
| repositories | jackin, host |
| branch | `feat/managed-execution` |

## Objective

Build and install jackin from `feat/managed-execution`.

## Scope

Create the branch in jackin (D-047), build it from the `feat/managed-execution` checkout with the build-meta path that embeds the sha (`CI=1 cargo install --path crates/jackin --locked --force`, or `JACKIN_VERSION_OVERRIDE="0.6.4+$(git rev-parse --short=7 HEAD)"`; `crates/jackin-build-meta` drops the sha for non-CI local builds), install it as the `jackin` on PATH ahead of `/opt/homebrew/bin` (`~/.cargo/bin` first until M1-02a), build `jackin-capsule` from the same commit the same way so `jackin doctor` and `jackin load` resolve a matching capsule, run `jackin doctor`, confirm interactive commands are unchanged (D-009, D-034). Record the checkout path in `tasks/M1-02/checkout.txt` (the host checkout that `goal/EXECUTION.md` §5 step 4a refreshes and rebuilds before every host-side check, D-086) and the branch and commit in `tasks/M1-02/`. CI for jackin on `feat/managed-execution` uses GitHub-hosted runners (D-064).

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
- [ ] container check passes: `jackin --version`
- [ ] container check passes: `command -v jackin`
- [ ] container check passes: `jackin doctor`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `checkout.txt` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> `jackin --version` (piped, so no splash) contains `+$(git -C <checkout> rev-parse --short=7 HEAD)` and not "preview"; `command -v jackin` is not under `/opt/homebrew`; `jackin doctor` exits 0 (warn-tolerant)

Host part (run by the host Claude Code session, D-061):

> none

When a container part exists the host part first asserts that
`tasks/M1-02/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M1-02/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M1-02/checkout.txt` (container part)

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
