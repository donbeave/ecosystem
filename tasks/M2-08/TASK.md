# M2-08 Review M2 pull request

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M2 |
| depends on | M2-07 |
| role | `donbeave/crew-reviewer` |
| lane | L6 |
| runtime | codex |
| fallback lane | L1 |
| delivery | prompt |
| size | S |
| repositories | jackin |
| branch | `feat/managed-execution` |

## Objective

Review M2 pull request.

## Scope

Non-blocking (D-055). Review the diff of the rolling jackin PR `feat/managed-execution` → `main` (opened by the host session, number and head SHA in `tasks/M2-08/pr.txt`, D-074) since the previous review, with the code-review plugin through the Reviews API; verdict flow of D-079 (`COMMENT` event with a `verdict:` first line while the forwarded `gh` login is the PR author — always before M8-01; never `REQUEST_CHANGES`/`APPROVE` from the author identity). Findings are emitted as checklist lines in the final message; the host session appends them to the reviewed issue (the reviewer has no Linear access); the review never gates the next task.

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
- [ ] container check passes: `gh api repos/<o>/<r>/pulls/<n>/reviews`
- [ ] container check passes: `git diff <line 3>..<line 2>`
- [ ] container check passes: `git merge-base --is-ancestor <line 2> <commit_id>`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `pr.txt` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> `gh api repos/<o>/<r>/pulls/<n>/reviews` contains a review by the configured reviewer login whose "commit_id" equals line 2 of `tasks/M2-08/pr.txt` (the SHA pinned by the host session and handed to the reviewer in `.jackin/task/pr.txt`; concurrent pushes move the PR head, so the reviewer posts with that "commit_id" and reviews `git diff <line 3>..<line 2>`; a review posted at a later head is accepted when `git merge-base --is-ancestor <line 2> <commit_id>` holds, D-091) and whose body starts with `verdict:`

Host part (run by the host Claude Code session, D-061):

> none

When a container part exists the host part first asserts that
`tasks/M2-08/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M2-08/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M2-08/pr.txt` (container part)

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
