# M5-06 M5 proof run

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M5 |
| depends on | M5-02, M5-03, M5-04, M5-05, M4-05, M3-07 |
| role | `donbeave/crew-operator` |
| lane | L3 |
| runtime | claude |
| fallback lane | L4 |
| delivery | prompt |
| size | S |
| repositories | ecosystem, Linear |
| branch | `main` |

## Objective

M5 proof run.

## Scope

First checklist item: open the Linear app settings page named in `tasks/M1-07/app-url.txt` and, if the Agent-session-events webhook shows Disabled, re-enable it and note that in the task folder (never a preflight defect). Create a saved project view filtered on the `run:*` labels; assign one issue that works normally, one whose prompt makes the agent sleep past the stall window, one that asks a question, and one whose prompt makes the harness stop on a permission prompt the daemon did not cause (D-051); leave the first idle 40 minutes; while all three states are live, capture the session panels, `externalUrls`, the project view through its GraphQL filter (`tasks/M5-06/view-during.json`) and the daemon log; then answer the permission prompt through `hardline`, watch the state clear, and capture `view-after.json` (D-091: a verify never asserts on a transient live state, only on the snapshot the task filed while it held).

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
- [ ] host check passes: `jq -e`
- [ ] host check passes: `grep -c issue.read`
- [ ] host check passes: `grep -c ' write '`
- [ ] `view-during.json` is filed in the task folder.
- [ ] `daemon.log` is filed in the task folder.
- [ ] `writes.txt` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none

Host part (run by the host Claude Code session, D-061):

> `jq -e` on `tasks/M5-06/view-during.json` lists exactly three issue ids carrying `run:stuck`, `run:waiting`, `run:blocked` respectively and `view-after.json` no longer lists the blocked one; on the tagged daemon log copied to `tasks/M5-06/daemon.log`: `grep -c issue.read` equals the number of scratch issues, `grep -c ' write '` equals the transition and heartbeat count listed in `tasks/M5-06/writes.txt`, and every other line is "poll" (including "poll ratelimited") (D-081, D-087)

## Evidence expected (D-118)

- `tasks/M5-06/view-during.json` (host part)
- `tasks/M5-06/daemon.log` (host part)
- `tasks/M5-06/writes.txt` (host part)

## Proof (browser/attach)

Session shows role, runtime, model, account, host, instance name, container id, attempt, and attach command (D-052); heartbeat activity every 10 minutes and the session never `stale`; the sleeping agent shows `run:stuck` and the stuck activity within the window; the asking agent shows the elicitation and `run:waiting`; the permission-prompt agent shows `run:blocked` with the reason and attach target, then returns to `run:working` after the prompt is answered in the container; the saved view lists exactly those three while they last.

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
