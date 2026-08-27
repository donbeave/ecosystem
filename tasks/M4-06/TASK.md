# M4-06 M4 proof run

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M4 |
| depends on | M4-04, M4-05, M1-13, M3-07 |
| role | `donbeave/crew-operator` |
| lane | L3 |
| runtime | claude |
| fallback lane | L4 |
| delivery | prompt |
| size | S |
| repositories | ecosystem, Linear |
| branch | `main` |

## Objective

M4 proof run.

## Scope

First checklist item: open the Linear app settings page named in `tasks/M1-07/app-url.txt` and, if the Agent-session-events webhook shows Disabled, re-enable it and note that in the task folder (never a preflight defect). Assign a scratch issue (`repo:` from `tasks/M3-07/scratch-repo.txt`) whose prompt asks the agent to create a named file and print a token; attach and record the session; post the reply in the session panel — this is the run's only actor that can create a Linear `prompt` activity, so the M4-04 live round trip is proven here — and file `tasks/M4-06/reply-delta.json` holding the activity `createdAt` and the daemon's `prompted` log timestamp; run `jackin daemon exec` for a check and file its output as `tasks/M4-06/exec.out`; file the workspace listing that shows the named file as `tasks/M4-06/workspace-ls.txt`.

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
- [ ] host check passes: `grep -q '<named file>' tasks/M4-06/workspace-ls.txt`
- [ ] host check passes: `jq -e '.delta_seconds <= 5' tasks/M4-06/reply-delta.json`
- [ ] `reply-delta.json` is filed in the task folder.
- [ ] `exec.out` is filed in the task folder.
- [ ] `workspace-ls.txt` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none

Host part (run by the host Claude Code session, D-061):

> `grep -q '<named file>' tasks/M4-06/workspace-ls.txt`, `tasks/M4-06/exec.out` is non-empty, and `jq -e '.delta_seconds <= 5' tasks/M4-06/reply-delta.json` exits 0 — all three read filed snapshots, never live daemon or workspace state

## Evidence expected (D-118)

- `tasks/M4-06/reply-delta.json` (host part)
- `tasks/M4-06/exec.out` (host part)
- `tasks/M4-06/workspace-ls.txt` (host part)

## Proof (browser/attach)

Attach recording shows the rendered prompt as the first turn and the reply arriving; browser shows the reply as `prompted` and the session continuing.

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
