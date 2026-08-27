# M1-05d Grant trust, create vault and operator service account, configure host bindings

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | M1-05a, M1-05b, M1-05c |
| role | `host` |
| lane | host (no lane) |
| runtime | host |
| fallback lane | none |
| delivery | prompt |
| size | S |
| repositories | host, 1Password |
| branch | `main` |

## Objective

Grant trust, create vault and operator service account, configure host bindings.

## Scope

On the host: `jackin config trust grant` for the three `donbeave/crew-*` selectors (Q-022); confirm the vault and operator service account the human created in preflight (`op vault get jackin`; never run `op vault create` — a duplicate name makes `--vault jackin` ambiguous; a missing vault or token is a preflight defect, D-076); write the on-demand binding by editing the file jackin reads, `"${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml"` (`paths.rs`: `~/.jackin/` is state only — roles, workspaces, cache — and a `~/.jackin/config.toml` is never created or read; no CLI flag exists; `jackin config env set` would store a launch-time value; `path` is mandatory, D-078, D-090): edit in place with no `jackin` process running (`config.lock` sits next to the file), preserve `version` and the existing `[roles.*]` and `[docker.mounts]` tables, and append under the quoted selector table that `jackin config trust grant` created: `[roles."donbeave/crew-operator".env]` / `OP_SERVICE_ACCOUNT_TOKEN = { op = "op://tailrocks/op-service-account-jackin-operator/credential", path = "tailrocks/op-service-account-jackin-operator/credential", on_demand = true }`; add the profile mount `~/.jackin/agent-browser-profile` → `/home/agent/.agent-browser-profile` scoped to `donbeave/crew-operator` (Q-017).

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
- [ ] host check passes: `jackin config trust list`
- [ ] host check passes: `grep -A2 '^[roles."donbeave/crew-<p>"]' "${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml" | grep -q 'trusted = true'`
- [ ] host check passes: `jackin config`
- [ ] host check passes: `op vault list --format json | jq '[.[]|select(.name=="jackin")]|length'`
- [ ] host check passes: `op read op://tailrocks/op-service-account-jackin-operator/credential | wc -c`
- [ ] host check passes: `jackin config env list --role donbeave/crew-operator --format json`
- [ ] host check passes: `grep -E 'OP_SERVICE_ACCOUNT_TOKEN *= *{.*on_demand *= *true' "${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml"`
- [ ] host check passes: `test ! -e ~/.jackin/config.toml`
- [ ] host check passes: `jackin load donbeave/crew-<p> --dry-run --format json | jq -r .data.role`
- [ ] host check passes: `tmux`
- [ ] host check passes: `script`
- [ ] host check passes: `! grep -qE '^[env.OP_SERVICE_ACCOUNT_TOKEN]' ~/.jackin/roles/donbeave/crew-operator/default/jackin.role.toml`
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none

Host part (run by the host Claude Code session, D-061):

> `jackin config trust list` lists the three selectors and, for each, `grep -A2 '^[roles."donbeave/crew-<p>"]' "${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml" | grep -q 'trusted = true'` matches (bare `jackin config` is subcommand-only and prints usage); `op vault list --format json | jq '[.[]|select(.name=="jackin")]|length'` prints 1; `op read op://tailrocks/op-service-account-jackin-operator/credential | wc -c` non-zero; primary: `jackin config env list --role donbeave/crew-operator --format json` lists `OP_SERVICE_ACCOUNT_TOKEN` with its on-demand marker (proves the file jackin reads is the one edited and still parses); secondary: `grep -E 'OP_SERVICE_ACCOUNT_TOKEN *= *{.*on_demand *= *true' "${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml"` matches under the crew-operator role table and `test ! -e ~/.jackin/config.toml`; the mount exists; for each of the three roles `jackin load donbeave/crew-<p> --dry-run --format json | jq -r .data.role` prints the selector (run under `tmux` or `script`, the command needs a rich terminal); `! grep -qE '^[env.OP_SERVICE_ACCOUNT_TOKEN]' ~/.jackin/roles/donbeave/crew-operator/default/jackin.role.toml` (the dry-run JSON has no env field)

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
