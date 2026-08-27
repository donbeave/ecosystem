# M11-03 Install and run the daemon on the server host

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M11 |
| depends on | M11-01, M11-02, M10-01, M1-13 |
| role | `the-architect` |
| lane | L1 |
| runtime | claude |
| fallback lane | L2 |
| delivery | prompt |
| size | M |
| repositories | jackin, host |
| branch | `feat/managed-execution` |

## Objective

Install and run the daemon on the server host.

## Scope

Branch build, no release (D-055, D-090): the host session materialises the key (`op read 'op://jackin/server-host-1/private key' > ~/.ssh/jackin-server-1`, mode 0600, never in the task folder, D-081) and every `ssh`/`scp` uses `-i`; on the server, `git clone --branch feat/managed-execution` jackin at the sha of `origin/feat/managed-execution` at task start (recorded in `tasks/M11-03/`), install Rust from the repo's `mise.toml` (`mise install`, or `rustup` when mise is absent), `CI=1 cargo install --path crates/jackin --locked` and the same for `crates/jackin-capsule` (the `arch` field of the item says which target; this Mac cross-compiles nothing, `goal/PREFLIGHT.md` §1), then `jackin daemon install`; workspace root, credential lookup, and ledger host-relative (D-017 consequence); write the `tasks/M11-01/daemon-credentials.md` mapping into the server's `~/.config/jackin/config.toml` only (`auth_forward = "api_key"` per runtime with `op://jackin/<runtime>-daemon/api key` bindings; skipped runtimes are omitted; the laptop config is untouched, D-090); roles pulled from M11-02. Since the ssh key and `op` live on the host, the server steps are `host (D-061)` parts run by the host session with the-architect's subagents doing the analysis.

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
- [ ] host check passes: `ssh -i ~/.ssh/jackin-server-1 <ssh user>@<address> jackin --version`
- [ ] host check passes: `jackin daemon status`
- [ ] host check passes: `grep -c 'auth_forward *= *"api_key"' "${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml"`
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none (host row, D-061)

Host part (run by the host Claude Code session, D-061):

> `ssh -i ~/.ssh/jackin-server-1 <ssh user>@<address> jackin --version` contains the same `+<sha>` recorded in `tasks/M11-03/` and not "preview"; `jackin daemon status` on the server lists the daemon and resolves every `op://` reference of the in-use runtime set; on the laptop `grep -c 'auth_forward *= *"api_key"' "${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml"` prints 0

## Evidence expected (D-118)

- The verify output of each part, filed in the task folder.

## Proof (browser/attach)

See M11-04.

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
