# M2-01 Daemon Linear credentials from 1Password

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M2 |
| depends on | M1-02, M1-10 |
| role | `the-architect` |
| lane | L1 |
| runtime | claude |
| fallback lane | L2 |
| delivery | goal |
| size | M |
| repositories | jackin |
| branch | `feat/managed-execution` |

## Objective

Daemon Linear credentials from 1Password.

## Scope

Add daemon config for the Linear adapter: `op://` references for client id and client secret (`op://jackin/linear-agent-app`) and for the workspace item; each daemon instance mints its own `grant_type=client_credentials` token (30 days, same scopes as M1-10) at start and again when fewer than 48 hours remain, keeps it in memory, and never uses the refresh-token grant nor writes anything back to 1Password (D-087: the host session, the laptop daemon, and the M11/M12 server daemons therefore never contend on one rotating refresh token; credentials §5.4). Reuse jackin's existing `op://` resolution.

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
- [ ] container check passes: `cargo nextest run -p jackin-daemon linear::auth`
- [ ] host check passes: `op`
- [ ] host check passes: `gitleaks detect --no-git --source tasks/M2-01`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `viewer.json` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> `cargo nextest run -p jackin-daemon linear::auth` passes with a stubbed 1Password resolver and a fake token endpoint (mint at start, re-mint at the threshold, nothing written back to 1Password)

Host part (run by the host Claude Code session, D-061):

> the real client secret is readable by host `op` only, so the live pass is a host part — `tasks/M2-01/viewer.json`, filed by the host session from the daemon's redacted "viewer" log line, has `.data.viewer.id` equal to the id in `tasks/M1-10/app-user-id.txt`, and `gitleaks detect --no-git --source tasks/M2-01` is clean

When a container part exists the host part first asserts that
`tasks/M2-01/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M2-01/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M2-01/viewer.json` (container part)

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
