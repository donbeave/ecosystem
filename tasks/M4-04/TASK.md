# M4-04 Prompt rendering and delivery from the issue

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M4 |
| depends on | M4-01, M4-02, M2-04, M1-13, M3-07 |
| role | `the-architect` |
| lane | L1 |
| runtime | claude |
| fallback lane | L2 |
| delivery | goal |
| size | M |
| repositories | jackin |
| branch | `feat/managed-execution` |

## Objective

Prompt rendering and delivery from the issue.

## Scope

Pre-fetch issue content into `<workspace>/.jackin/task/TASK.md` and the checklist file — the same layout the host session stages by hand on the container path (D-086), so both paths share one prompt shape — plus, for roadmap issues, the task's `task.toml`, `verify.sh` and reference files from the issue attachments M1-12 created (titles `task.toml`, `verify.sh`, `refs/<name>`, raw URLs pinned to the sha of the description's first `task_source:` line), fetched by the daemon over HTTPS — never from inside the container, which needs no token because the repository is public (D-065) — into `<workspace>/.jackin/task/` and `<workspace>/.jackin/task/refs/`; a task whose issue carries no `verify.sh` attachment is refused with an `error` activity rather than launched; render per the issue's delivery mode (D-044): `goal` → `/goal Read this file: .jackin/task/TASK.md — implement it fully until sh .jackin/task/verify.sh container prints status: DONE` plus the issue prompt (frame from `.jackin/WORKFLOW.md`, D-018), `prompt` → `Read .jackin/task/TASK.md and follow it as your task prompt`; deliver via M4-01 at launch; forward Linear `prompted` replies (from the M2-02 activity read) via M4-02; on `stop` signal, stop the container. Linear token never enters the container (D-023).

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
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `attach.txt` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> rendering tests from a fixture issue; a "prompted" fixture reaches an in-process capsule PTY (no Docker). container: a fixture test also proves the attachment fetch stages `.jackin/task/verify.sh` and `refs/*` before launch

Host part (run by the host Claude Code session, D-061):

> the task launches from a scratch issue on the host daemon and files `tasks/M4-04/attach.txt`, which contains the rendered prompt; the "prompted" round trip is proven in-process by the container fixture only, because Linear forbids an agent from creating a "prompt" activity and no actor on this run can post one at this point — the live reply is proven in M4-06, whose crew-operator posts it

When a container part exists the host part first asserts that
`tasks/M4-04/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M4-04/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M4-04/attach.txt` (container part)

## Proof (browser/attach)

See M4-06.

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
