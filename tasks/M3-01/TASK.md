# M3-01 Programmatic launch (`LoadOptions`)

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M3 |
| depends on | M1-02 |
| role | `the-architect` |
| lane | L1 |
| runtime | claude |
| fallback lane | L2 |
| delivery | goal |
| size | L |
| repositories | jackin |
| branch | `feat/managed-execution` |

## Objective

Programmatic launch (`LoadOptions`).

## Scope

Add a non-TTY entry into `launch_pipeline` with every decision pre-supplied: role selector, agent, `account` (source folder) and `model`, `effort` (D-043, Q-024; `LoadOptions.model`/`effort` override the manifest model and, for Codex, write or pass the same `config.toml` keys as the role hook so hook and daemon never disagree, D-078), trust already granted (Q-022; missing grant is a validation failure), env values including pre-approved on-demand bindings (today `collect_on_demand_bindings` is reached only through the interactive picker, D-082), mounts, `--force`; returns the instance identity. Add `--on-demand` to `jackin config env set` / `jackin workspace env set` and an on-demand column to `env list`; extend the dry-run JSON with `image_decision` and `published_image` resolved after manifest load (D-078). Shared path the CLI keeps using (D-009). `analysis/jackin.md` §10 rows 2..3, B5.1.

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
- [ ] host check passes: `jackin status <instance id> --format json > tasks/M3-01/status.json`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `status.json` is filed in the task folder.
- [ ] `launch.txt` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> unit tests for `LoadOptions` validation and the dry-run JSON ("image_decision", "published_image") pass against the `DockerApi` fake (no Docker)

Host part (run by the host Claude Code session, D-061):

> `cd "$(cat tasks/M1-02/checkout.txt)" && CI=1 cargo nextest run -p jackin --features e2e --profile docker-e2e -E 'test(load_options_launch)'` with no TTY launches "the-architect" against the host Docker, prints an instance id, and the non-interactive `jackin status <instance id> --format json > tasks/M3-01/status.json` files that instance as running, with the launch output kept in `tasks/M3-01/launch.txt`; the proof is these files, never an interactive attach (a nested launch under the DinD sidecar cannot work: it bind-mounts the launcher's own filesystem)

When a container part exists the host part first asserts that
`tasks/M3-01/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M3-01/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M3-01/status.json` (container part)
- `tasks/M3-01/launch.txt` (container part)

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
