# M8-01 GitHub App `github-app-jackin-daemon`

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M8 |
| depends on | M1-03 |
| role | `donbeave/crew-operator` |
| lane | L6 |
| runtime | codex |
| fallback lane | L1 |
| delivery | prompt |
| size | S |
| repositories | GitHub, 1Password |
| branch | `main` |

## Objective

GitHub App `github-app-jackin-daemon`.

## Scope

Verify-and-mint only (D-076): for each organization read `app id`, `installation id`, and `PEM private key` from `op://jackin/github-app-jackin-daemon-jackin-project` and `op://jackin/github-app-jackin-daemon-tailrocks` via `jackin-exec op read` on stdin (never argv), mint the JWT with `openssl`, exchange it for an installation token, and record the App's permissions and installed repositories in `tasks/M8-01/`; browser check of the org's installed-apps page needs no sudo mode. No creation in-run.

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
- [ ] container check passes: `op read`
- [ ] container check passes: `openssl`
- [ ] container check passes: `gh api /installation/repositories`
- [ ] host check passes: `gitleaks detect --no-git --source tasks/M8-01`
- [ ] host check passes: `grep -c repository_selection tasks/M8-01/app.md`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `app.md` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> for both organizations `op read` on stdin supplies app id, installation id and PEM, `openssl` mints the JWT, and the installation token makes `gh api /installation/repositories` list the repositories; `tasks/M8-01/app.md` records "repository_selection" = "all" per organization

Host part (run by the host Claude Code session, D-061):

> `gitleaks detect --no-git --source tasks/M8-01` is clean and `grep -c repository_selection tasks/M8-01/app.md` is 2 (D-081)

When a container part exists the host part first asserts that
`tasks/M8-01/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M8-01/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M8-01/app.md` (container part)

## Proof (browser/attach)

The App appears under the org's installed apps.

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
