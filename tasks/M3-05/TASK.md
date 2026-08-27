# M3-05 Dispatch: issue → prepared workspace → launched instance

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M3 |
| depends on | M3-02, M3-03, M3-04, M2-03, M2-04, M1-13 |
| role | `the-architect` |
| lane | L2 |
| runtime | claude |
| fallback lane | L3 |
| delivery | goal |
| size | M |
| repositories | jackin |
| branch | `feat/managed-execution` |

## Objective

Dispatch: issue → prepared workspace → launched instance.

## Scope

On a dispatchable issue: prepare workspace (M3-03), resolve role and runtime (M3-02), choose the account home per launch from the issue's `lane:L<n>` label against a `[lanes]` table in `~/.config/jackin/config.toml` (one entry per lane: runtime, model, effort, account home; seeded from `tasks/M1-13/lanes.json` by the host session in `goal/EXECUTION.md` §5 step 4a, so the daemon never guesses a home) and count running instances per account against `[daemon.accounts."<home>"] max`, which is configuration rather than a constant — this run sets 2 for `~/.claude` and 1 per Codex home (D-022 account half, D-056, amended by D-071), launch (M3-01), bind (M3-04), post `action` `launch` and the instance external URL; enforce a per-host cap (`max_concurrent_agents`, default 6 for the laptop, D-056) and a per-role cap of 1 for `donbeave/crew-operator` (Chrome `SingletonLock`).

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
- [ ] host check passes: `jackin daemon status --format json`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `session.json` is filed in the task folder.
- [ ] `status.json` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> dispatch test with a stub role in an isolated daemon against the recorded tracker fake and the `DockerApi` fake (no real launch), two operator issues in the fixture: one launches, the other waits

Host part (run by the host Claude Code session, D-061):

> a live smoke on one scratch issue only, delegated from the host by `issueUpdate(delegateId)`; within one interval the session poll filed as `tasks/M3-05/session.json` shows exactly one session of the app user on that issue whose first activity is a "thought" by the app user — the session status is never asserted as "pending" or "active", because the daemon acknowledges inside the same tick that creates it; `jackin daemon status --format json`, filed as `tasks/M3-05/status.json`, lists zero issues whose `tasks/README.md` row is "done"

When a container part exists the host part first asserts that
`tasks/M3-05/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M3-05/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M3-05/session.json` (container part)
- `tasks/M3-05/status.json` (container part)

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
