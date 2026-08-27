# M11-01 Runtime credentials and daemon service account

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M11 |
| depends on | M10-05 |
| role | `donbeave/crew-operator` |
| lane | L6 |
| runtime | codex |
| fallback lane | L1 |
| delivery | prompt |
| size | M |
| repositories | 1Password |
| branch | `main` |

## Objective

Runtime credentials and daemon service account.

## Scope

Verify that the preflight-created items resolve (`op://jackin/<runtime>-daemon/api key` for the runtimes in use — `claude`, `codex`, plus every runtime whose `tasks/M4-05/` matrix row is not `skipped`; no defect for any other — `op://jackin/registry-dockerhub/{username,token}`, `op://jackin/server-host-1/*` including `arch`, and the daemon service account `op://tailrocks/op-service-account-jackin-daemon/credential`; credentials #8..#13, #15, #17, D-076) and record the per-role `op://` → env-key mapping (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, … per runtime; `jackin config env set <KEY> "op://jackin/<runtime>-daemon/api key" --role <role>`, credentials §5.2) in `tasks/M11-01/daemon-credentials.md`. It changes no configuration: the laptop keeps `auth_forward = "sync"` for the whole run and M11-03 applies the mapping to the server daemon only (D-090). The operator container can neither read nor write vault `tailrocks`, so the daemon-account check runs on the `host` path (D-081); this task creates nothing and its `depends_on = M10-05` places it at the head of M11 (D-088).

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
- [ ] host check passes: `op read`
- [ ] host check passes: `wc -c`
- [ ] host check passes: `grep -c 'auth_forward *= *"sync"' "${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml"`
- [ ] `daemon-credentials.md` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none (host row, D-061)

Host part (run by the host Claude Code session, D-061):

> with `OP_SERVICE_ACCOUNT_TOKEN` of the daemon account and no desktop app, `op read` resolves every referenced field of the in-use set (`wc -c` non-zero, values never shown); `tasks/M11-01/daemon-credentials.md` exists; `grep -c 'auth_forward *= *"sync"' "${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml"` is unchanged from the run start

## Evidence expected (D-118)

- `tasks/M11-01/daemon-credentials.md` (host part)

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
