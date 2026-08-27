# M1-11 Assign a test issue and observe (M1 proof run)

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | M1-09, M1-10 |
| role | `donbeave/crew-operator` |
| lane | L3 |
| runtime | claude |
| fallback lane | L4 |
| delivery | prompt |
| size | S |
| repositories | Linear |
| branch | `main` |

## Objective

Assign a test issue and observe (M1 proof run).

## Scope

Create a throwaway issue from the template, assign it to jackin in the UI, observe that the delegate is jackin and a session exists in `pending`; query the session and issue over GraphQL and file the JSON *before* cancelling (`tasks/M1-11/issue.json`, `session.json`); create a second throwaway issue and delegate it from the host session by `issueUpdate(delegateId)` with the workspace token, then poll `agentSessions` for one interval and record whether a session appears (`tasks/M1-11/api-delegation.json`; either answer is a finding that settles the M2-02 design, D-087, never a stop); confirm the profile logins from M1-06; then cancel both issues (`cancel.json`).

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
- [ ] container check passes: `jq -e '.data.issue.delegate.id == $app' tasks/M1-11/issue.json`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `issue.json` is filed in the task folder.
- [ ] `api-delegation.json` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> Run by the host session (D-061), on the filed snapshots, never on live state (D-091): `jq -e '.data.issue.delegate.id == $app' tasks/M1-11/issue.json`; `session.json` shows `.state` equal to "pending" or the folder records `session: absent` (the webhook is intentionally undeliverable, D-080; a session that never appears is a finding, not a stop); `api-delegation.json` exists; `cancel.json` shows the cancelled state

Host part (run by the host Claude Code session, D-061):

> none

When a container part exists the host part first asserts that
`tasks/M1-11/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M1-11/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M1-11/issue.json` (container part)
- `tasks/M1-11/api-delegation.json` (container part)

## Proof (browser/attach)

Screenshot of the issue with jackin as delegate and the session panel; screenshots of `linear.app` and `github.com` logged in — attached to the test issue, not committed (D-059).

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
