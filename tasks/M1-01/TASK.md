# M1-01 Seed the run state store and verify all 81 task bundles

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | none |
| role | `donbeave/crew-builder` |
| lane | L3 |
| runtime | claude |
| fallback lane | L4 |
| delivery | goal |
| size | M |
| repositories | ecosystem |
| branch | `main` |

## Objective

Seed the run state store and verify all 81 task bundles.

## Scope

Wave 0 (D-072, D-114), `host` path: every one of the 81 `tasks/<id>/` bundles — `TASK.md`, `task.toml`, `verify.sh`, `expected-evidence.toml`, `refs/` per `concept/task-format.md` — is materialised from this document by `tools/bundle.py` before the run starts and is content-addressed, so no task authors another task's bundle while the run is under way (D-114). This task authors nothing: it seeds the run state store (D-111) with one entry per id, asserts that every bundle is present and still matches this document, and records the bundle hashes it verified alongside the ones in `run/LOCK.toml`. Evidence another task's verify consumes is named in the producing row (produces: `tasks/M1-13/lanes.json`, `dind.out`, `pr.txt`, `scratch-repo.txt`) and is already staged in both folders by the generator. `TASK.md` references every other file container-relative as `.jackin/task/refs/<name>` and carries the constraint `git commit -s` (D-086); `verify.sh` is POSIX `sh`, takes `$1` in {`container`, `host`} and runs only that part (a single-part task accepts both), and when a container part exists the host part first asserts that `tasks/<id>/verify.container.out` ends with `status: DONE`. The generated `tasks/README.md` carries one row per id (`ready`; M1 rows never get a Linear URL).

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
- [ ] host check passes: `python3 tools/roadmap_compile.py --bundles 2>&1 | grep -q '81/81 bundles valid'`
- [ ] host check passes: `python3 tools/bundle.py verify --all`
- [ ] host check passes: `dash -n tasks/M1-01/verify.sh`
- [ ] host check passes: `shellcheck -s sh -S warning tasks/M1-01/verify.sh`
- [ ] host check passes: `grep -qE '^ *echo "?status: DONE' tasks/M1-01/verify.sh`
- [ ] host check passes: `grep -qE '^ *echo "?status: FAILED' tasks/M1-01/verify.sh`
- [ ] host check passes: `grep -q 'case "$1"' tasks/M1-01/verify.sh`
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none (host row, D-061)

Host part (run by the host Claude Code session, D-061):

> `python3 tools/roadmap_compile.py --bundles 2>&1 | grep -q '81/81 bundles valid'` matches; `python3 tools/bundle.py verify --all` exits 0, so no bundle has drifted from this document; `dash -n tasks/M1-01/verify.sh` exits 0 and `shellcheck -s sh -S warning tasks/M1-01/verify.sh` exits 0 (severity floor "warning": "style" and "info" hints never fail a bundle, D-114); `grep -qE '^ *echo "?status: DONE' tasks/M1-01/verify.sh`, `grep -qE '^ *echo "?status: FAILED' tasks/M1-01/verify.sh` and `grep -q 'case "$1"' tasks/M1-01/verify.sh` all match; the run state store lists one entry per id and `tasks/README.md` has one row per id (state-independent: this row is still in progress when its verify runs, D-088; a task verify never asserts the remaining count or its own row status)

## Evidence expected (D-118)

- The verify output of each part, filed in the task folder.

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
