# M3-07 M3 proof run

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M3 |
| depends on | M3-05, M3-06, M1-13 |
| role | `donbeave/crew-operator` |
| lane | L3 |
| runtime | claude |
| fallback lane | L4 |
| delivery | prompt |
| size | S |
| repositories | ecosystem, Linear, GitHub |
| branch | `main` |

## Objective

M3 proof run.

## Scope

First checklist item: open the Linear app settings page named in `tasks/M1-07/app-url.txt` and, if the Agent-session-events webhook shows Disabled, re-enable it and note that in the task folder (never a preflight defect). The operator role creates the scratch repository `gh repo create jackin-project/jackin-managed-scratch --public` (skip when present; no branch protection; D-089) and records `jackin-project/jackin-managed-scratch` in `tasks/M3-07/scratch-repo.txt`; creates and delegates a scratch issue with `role:the-architect`, `agent:claude`, and `repo:jackin-project/jackin-managed-scratch`; captures `docker ps` labels, `hardline` session, workspace branch, and screenshots of the `launch` action and external URL; while that container runs it performs a `jackin daemon restart` and files `tasks/M3-07/status-before.json` and `status-after.json`, the binding proof M3-04 cannot run itself (K-11).

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
- [ ] host check passes: `gh repo view "$(cat tasks/M3-07/scratch-repo.txt)" --json owner --jq .owner.login`
- [ ] host check passes: `gh api repos/jackin-project/jackin-managed-scratch/branches/main/protection`
- [ ] host check passes: `jq -e`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `scratch-repo.txt` is filed in the task folder.
- [ ] `status-before.json` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> Checks labels and branch

Host part (run by the host Claude Code session, D-061):

> `gh repo view "$(cat tasks/M3-07/scratch-repo.txt)" --json owner --jq .owner.login` prints "jackin-project" and `gh api repos/jackin-project/jackin-managed-scratch/branches/main/protection` returns 404; `jq -e` over `tasks/M3-07/status-before.json` and `status-after.json` shows both bind the same container id to the same issue across the restart

When a container part exists the host part first asserts that
`tasks/M3-07/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M3-07/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M3-07/scratch-repo.txt` (container part)
- `tasks/M3-07/status-before.json` (container part)

## Proof (browser/attach)

Attach shows the role's interactive session; browser shows the `launch` action and the external URL.

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
