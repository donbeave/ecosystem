# M11-05 Review M11 pull requests

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M11 |
| depends on | M11-04 |
| role | `donbeave/crew-reviewer` |
| lane | L4 |
| runtime | codex |
| fallback lane | L5 |
| delivery | prompt |
| size | S |
| repositories | jackin, role repositories |
| branch | `feat/managed-execution` |

## Objective

Review M11 pull requests.

## Scope

Non-blocking (D-055). Review daemon install and role publishing for credential handling (D-035) and image pinning.

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
- [ ] container check passes: `gh pr review`
- [ ] container check passes: `gh api repos/jackin-project/jackin/pulls/<n>/reviews --jq '.[-1].commit_id'`
- [ ] container check passes: `gh api repos/donbeave/jackin-crew-<p>/commits/<sha>/comments --input -`
- [ ] host check passes: `grep -q '^verdict:' tasks/M11-05/review.<repo>.md`
- [ ] host check passes: `sed -n 2p`
- [ ] host check passes: `git merge-base --is-ancestor`
- [ ] host check passes: `gh api repos/donbeave/jackin-crew-<p>/commits/<sha>/comments --jq '[.[]|select(.body|startswith("verdict:"))]|length >= 1'`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> one review record per reviewed repository, staged as `.jackin/task/refs/pr.txt` for jackin and `.jackin/task/refs/pr.<repo>.txt` for each role repository. jackin has the rolling PR, so its review is posted with `gh pr review` as in M2-08 and `gh api repos/jackin-project/jackin/pulls/<n>/reviews --jq '.[-1].commit_id'` equals line 2 of `pr.txt` (or a later head that has it as an ancestor, D-091). Role repositories commit straight to "main" and never have a PR (D-074, D-112), so line 1 of their record is the literal "commit" and the review is posted on the reviewed commit range with `gh api repos/donbeave/jackin-crew-<p>/commits/<sha>/comments --input -`, `<sha>` being line 2 of that record; every body carries a `verdict:` first line (D-079) and is filed as `tasks/M11-05/review.<repo>.md`

Host part (run by the host Claude Code session, D-061):

> for each reviewed repository `grep -q '^verdict:' tasks/M11-05/review.<repo>.md`, `sed -n 2p` of its record names a commit that `git merge-base --is-ancestor` confirms is in the reviewed head, and for the role repositories `gh api repos/donbeave/jackin-crew-<p>/commits/<sha>/comments --jq '[.[]|select(.body|startswith("verdict:"))]|length >= 1'` exits 0; checklist lines from the final message are appended to the issue by the host session (D-055)

When a container part exists the host part first asserts that
`tasks/M11-05/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M11-05/verify.container.out` (container part, containing `status: DONE`)

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
