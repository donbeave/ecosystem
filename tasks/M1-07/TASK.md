# M1-07 Create the Linear OAuth agent app

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | M1-03, M1-06 |
| role | `donbeave/crew-operator` |
| lane | L6 |
| runtime | codex |
| fallback lane | L1 |
| delivery | prompt |
| size | M |
| repositories | Linear, 1Password |
| branch | `main` |

## Objective

Create the Linear OAuth agent app.

## Scope

Through the browser profile: create the OAuth application with callback URL exactly `http://localhost:53682/callback` (loopback; nothing serves it; stored in the item's `redirect uri` field, D-080); enable webhooks with the "Agent session events" category on the fixed, intentionally unreachable URL `https://jackin-webhook.invalid/linear` (Linear auto-disables it after failed deliveries; polling is the correctness path, Q-015; if the form rejects the placeholder, use `https://github.com/donbeave/jackin`, deliveries are discarded either way); in the same step write client id, client secret, webhook signing secret, and `redirect uri` into `op://jackin/linear-agent-app` via `jackin-exec op item edit` (D-035). Workspace ownership per Q-019.

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
- [ ] container check passes: `op item get linear-agent-app --vault jackin --fields label=<f> --format json | jq -e '(.value // "") | length > 0' >/dev/null`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> For each of the three secret fields `op item get linear-agent-app --vault jackin --fields label=<f> --format json | jq -e '(.value // "") | length > 0' >/dev/null` (value never printed, D-081); the "redirect uri" field equals the literal above

Host part (run by the host Claude Code session, D-061):

> none

When a container part exists the host part first asserts that
`tasks/M1-07/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M1-07/verify.container.out` (container part, containing `status: DONE`)

## Proof (browser/attach)

The application appears under Linear API settings with the two agent scopes available (screenshot attached to the M1-11 test issue once it exists, never committed, D-059; the reference goes in `tasks/M1-07/`).

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
