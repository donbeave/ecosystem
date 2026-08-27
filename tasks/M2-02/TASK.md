# M2-02 Linear adapter: reads and normalization

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M2 |
| depends on | M2-01 |
| role | `the-architect` |
| lane | L2 |
| runtime | claude |
| fallback lane | L3 |
| delivery | goal |
| size | M |
| repositories | jackin |
| branch | `feat/managed-execution` |

## Objective

Linear adapter: reads and normalization.

## Scope

Implement the reads: `issues` filtered by delegate and active state types (scoped by a configurable team or project and required label so scratch runs never touch roadmap issues, D-073), `issues` by ids, the `agentSessions` page-and-diff read from `analysis/linear-agents.md` C5 (a session is new when it has no app-user activity, whether `pending` or `stale`), and a fourth read per non-terminal session — `agentSession(id){activities(filter:{createdAt:{gt:$since}}){nodes{id type body signal createdAt}}}` with a per-session watermark — emitting `prompted` events (body, `signal: stop`) (D-081). All reads of one tick are aliased root fields of one GraphQL document (`sessions:`, `delegated:`, `a<n>:`), so a tick is one request (about 720 per hour at 5 s against Linear's 5,000-per-hour app-user budget, D-087). A delegated issue in an active state type with no non-terminal session of this app user is a candidate too: the adapter calls `agentSessionCreateOnIssue(input:{issueId})` itself (skipped when a non-terminal session exists) and uses the returned id for the ack, so UI delegation, automation, and host-API delegation converge on one path (D-087; Linear documents no session for an `issueUpdate(delegateId)` made by the app token). Normalize to the issue model with `dispatchable` (D-020). The structured log tags every tracker call `poll`, `issue.read`, `pre-read` (the M6-02 pre-write description read), or `write`; a `write` line is emitted once per logical write (transition, heartbeat, or tick) with a `kind` field even when a tick issues several mutations, and each `poll` line records `X-RateLimit-Requests-Remaining`.

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
- [ ] `verify.container.out` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> Adapter unit tests with recorded GraphQL fixtures pass (one request per tick; session creation for a delegated issue without a session; no duplicate creation when one exists); pagination order and label lowercasing tests from Symphony §17.3 adopted

Host part (run by the host Claude Code session, D-061):

> none

When a container part exists the host part first asserts that
`tasks/M2-02/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M2-02/verify.container.out` (container part, containing `status: DONE`)

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
