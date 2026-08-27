# M1-06 Verify the persistent `agent-browser` browser state

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | M1-05b, M1-05d |
| role | `host` |
| lane | host (no lane) |
| runtime | host |
| fallback lane | none |
| delivery | prompt |
| size | M |
| repositories | host |
| branch | `main` |

## Objective

Verify the persistent `agent-browser` browser state.

## Scope

The headed login and `state save` are a preflight item (`goal/PREFLIGHT.md` §2, D-077): the human logs in on the host into `~/.jackin/agent-browser-host-profile` and saves `~/.jackin/agent-browser-profile/state.json` (0600). This task verifies it Linux-side: a throwaway `crew-operator` load whose `preflight.sh` loads the state and whose `agent-browser open https://linear.app && agent-browser get url` shows the workspace, same for `github.com`; record the paths in the environment notes; the directory and `state.json` are secrets (never committed, used only by `crew-operator` and the host session, one process at a time, not backed up to 1Password). Session expiry mid-run = the human repeats the preflight item with the exact `open`/`get url`/`state save` commands of `goal/PREFLIGHT.md` §2 (D-090); the session files it as a preflight defect (the one planned re-login). The throwaway load counts as the one `crew-operator` instance and is ejected before M1-03 starts (wave 5b, D-088).

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
- [ ] host check passes: `test -s ~/.jackin/agent-browser-profile/state.json`
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none

Host part (run by the host Claude Code session, D-061):

> `test -s ~/.jackin/agent-browser-profile/state.json`; the directory is excluded by `.gitignore` in every repository the roles mount; no host process holds a profile; the in-container "get url" outputs (workspace URL, not a login page) are filed in `tasks/M1-06/`

## Evidence expected (D-118)

- The verify output of each part, filed in the task folder.

## Proof (browser/attach)

Inside `crew-operator`: `agent-browser open linear.app` and `github.com` show the logged-in account without a prompt (checked again in M1-11).

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
