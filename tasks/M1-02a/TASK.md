# M1-02a Remove `jackin-preview`; branch build on `PATH`; lane templates (D-042, D-085)

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | M1-02 |
| role | `host` |
| lane | host (no lane) |
| runtime | host |
| fallback lane | none |
| delivery | prompt |
| size | S |
| repositories | host |
| branch | `main` |

## Objective

Remove `jackin-preview`; branch build on `PATH`; lane templates (D-042, D-085).

## Scope

`brew uninstall jackin-preview`, keep `jackin-dev`; `which jackin` and `jackin --version` show the branch build. Write the six lane templates `tasks/M1-02a/lanes/L<n>.toml`, each holding only the account selector — `[claude]` `sync_source_dir = "/Users/donbeave/.claude"` for L1..L3, `[codex]` `sync_source_dir = "/Users/donbeave/.codex"` (L4), `…/.codex-chainargos` (L5), `…/.codex-chainargos2` (L6) — plus, for the Rust lanes, `[[mounts]]` lines for a per-lane cargo registry and target volume (`~/.jackin/cargo/L<n>/registry` → `/home/agent/.cargo/registry`, `~/.jackin/cargo/L<n>/target` → `/workspace/target`) and `[env] CARGO_TARGET_DIR=/workspace/target`, so a retry is not a cold build — which the host session merges into every per-task workspace `~/.config/jackin/workspaces/task-<id>.toml` until M1-13 replaces them (host `CODEX_HOME`/`CLAUDE_CONFIG_DIR` on the launching process select nothing in `jackin load`). Enable jackin's own DCO trailer injection once for the host, `jackin config git dco enable`, so every container launched here carries `JACKIN_GIT_DCO=1` and the capsule's `prepare-commit-msg` hook signs off (D-089 (4) amended: the role image ships no sign-off hook of its own, because jackin's `--global core.hooksPath` would shadow it). `jackin-preview` stays uninstalled for the rest of the run even though M11-01a's merge refreshes the rolling `preview` release and the `jackin-preview` tap formula automatically. Confirm `jackin-the-architect`'s `agents` list includes `codex` (note below).

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
- [ ] host check passes: `! brew list --formula | grep -qx jackin-preview`
- [ ] host check passes: `grep -q 'dco = true' "${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml"`
- [ ] host check passes: `jackin workspace remove task-probe >/dev/null 2>&1; jackin workspace create task-probe --workdir ~/.jackin/managed/probe --mount ~/.jackin/managed/probe`
- [ ] host check passes: `script -q /dev/null jackin load the-architect task-probe --agent codex --dry-run --format json </dev/null | grep -q '"workspace": *"task-probe"'`
- [ ] host check passes: `jackin workspace remove task-probe`
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none

Host part (run by the host Claude Code session, D-061):

> the same sha check as M1-02; `! brew list --formula | grep -qx jackin-preview`; `grep -q 'dco = true' "${JACKIN_CONFIG_DIR:-$HOME/.config/jackin}/config.toml"`; six template files exist; a throwaway workspace "task-probe" created from the L5 template (`jackin workspace remove task-probe >/dev/null 2>&1; jackin workspace create task-probe --workdir ~/.jackin/managed/probe --mount ~/.jackin/managed/probe`, template merged, the leading remove keeps a stale probe from pre-existing) makes the dry-run load, folded into one check that runs under a pty and leaves no stray typescript file in the tree (`script -q /dev/null jackin load the-architect task-probe --agent codex --dry-run --format json </dev/null | grep -q '"workspace": *"task-probe"'`), print `.data.workspace` = "task-probe"; the workspace is removed afterwards with `jackin workspace remove task-probe`

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
