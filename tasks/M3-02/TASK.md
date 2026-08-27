# M3-02 `default_agent` in the role manifest

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M3 |
| depends on | M3-01 |
| role | `the-architect` |
| lane | L2 |
| runtime | claude |
| fallback lane | L3 |
| delivery | goal |
| size | M |
| repositories | jackin, jackin-the-architect |
| branch | `feat/managed-execution` |

## Objective

`default_agent` in the role manifest.

## Scope

Schema bump (one per PR, Q-021) adding `default_agent` to `RoleManifest`, validated against `agents`; launch precedence becomes issue runtime → workspace `default_agent` → manifest `default_agent` → single agent. B5.4. Update `jackin-the-architect`: its CI `pull_request` lane already runs on GitHub-hosted runners since M1-13 (D-064, D-089); open the PR from `feat/managed-execution`, `gh pr checks <n> --watch --fail-fast`, merge it to `main` in this task (D-074: `jackin load` resolves the default branch only), merge `origin/main` back into the branch and push it, then `jackin load the-architect --rebuild`. The jackin change itself stays on `feat/managed-execution`; the-architect's `main` manifest is branch-build-only until M11, so its `Publish Image` workflow on `main` is expected red from this task until M11-01a (the `jackin-role-action` validator comes from jackin's `preview` release built from `main`, which knows `v1alpha6` only) — non-gating, never a stuck signal.

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
- [ ] container check passes: `cargo xtask schema-check --base origin/main`
- [ ] container check passes: `jackin role validate`
- [ ] container check passes: `jackin status --format json`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> Manifest tests pass; `cargo xtask schema-check --base origin/main` reports exactly this one bump to `v1alpha7` (it is the run's only manifest schema bump, Q-021); `jackin role validate` on the cached `~/.jackin/roles/…/the-architect/default` checkout (HEAD equals the merged "main" commit) passes and it contains "default_agent"; a real launch without `--agent` picks the manifest default (`jackin status --format json` shows the agent; dry-run never reads the manifest)

Host part (run by the host Claude Code session, D-061):

> none

When a container part exists the host part first asserts that
`tasks/M3-02/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M3-02/verify.container.out` (container part, containing `status: DONE`)

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
