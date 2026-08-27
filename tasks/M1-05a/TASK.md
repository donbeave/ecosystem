# M1-05a Create `donbeave/crew-builder`

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | M1-04a |
| role | `the-architect` |
| lane | L4 |
| runtime | codex |
| fallback lane | L5 |
| delivery | goal |
| size | M |
| repositories | jackin-crew-builder (new) |
| branch | `main` |

## Objective

Create `donbeave/crew-builder`.

## Scope

Per `concept/roles.md` §3: construct base, `agents = ["claude","codex"]`, no `[claude].model` (the lane sets it, D-078), termrock's mise toolchain (D-048: not jackin's), `tailrocks-skills` (marketplace `source = "tailrocks/tailrocks-skills"`; Codex skills-dir clone pinned to the commit `ARG TAILROCKS_SKILLS_SHA`, whose value this task writes to `tasks/M1-05a/tailrocks-skills-sha.txt` — the file `goal/PREFLIGHT.md` §1 reads, so no standing check ever carries a placeholder) and official plugins, Codex skills as files, `[docker] min_profile = "standard"`, `preflight.sh`, `hooks/source.sh` writing the lane's Codex `model`/`model_reasoning_effort` into `$CODEX_HOME/config.toml` (D-078; the hook is sourced, not executed: it opens with `CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"`, never sets `-e` and never calls `exit`, and is a no-op when `JACKIN_LANE_CODEX_MODEL` is unset), env defaults; `AGENTS.md` with threat model stating that the agent merges its own PR when the task says so (D-055, D-079). The repository commits directly to `main` (D-074). No `agent-browser`, no `op`.

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
- [ ] container check passes: `jackin workspace create task-<id> --workdir /workspace --mount <ws>:/workspace`
- [ ] container check passes: `git -C /workspace log -1 --format=%B`
- [ ] host check passes: `jackin role validate ~/.jackin/roles/donbeave/crew-builder/default`
- [ ] host check passes: `docker exec -u agent "$(cat tasks/M1-05a/throwaway.txt)" sh -c '…'`
- [ ] host check passes: `mise install`
- [ ] host check passes: `grep -cE 'installing|downloading'`
- [ ] host check passes: `cargo nextest --version`
- [ ] host check passes: `cargo public-api --version`
- [ ] host check passes: `! command -v agent-browser`
- [ ] host check passes: `! command -v op`
- [ ] host check passes: `test -s tasks/M1-05a/tailrocks-skills-sha.txt`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `tailrocks-skills-sha.txt` is filed in the task folder.
- [ ] `throwaway.txt` is filed in the task folder.
- [ ] `smoke.out` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> container (cwd `/workspace`, from `jackin workspace create task-<id> --workdir /workspace --mount <ws>:/workspace`): the role's own files are present under `/workspace` and `git -C /workspace log -1 --format=%B` carries a `Signed-off-by:` trailer

Host part (run by the host Claude Code session, D-061):

> `jackin role validate ~/.jackin/roles/donbeave/crew-builder/default` passes on the host, never inside a container; the host session performs the throwaway load of `goal/EXECUTION.md` §4 (workspace `probe-M1-05a` with the termrock clone at `~/.jackin/managed/M1-05a/termrock` mounted at `/workspace`, name recorded in `tasks/M1-05a/throwaway.txt`) and files `tasks/M1-05a/smoke.out`, the output of `docker exec -u agent "$(cat tasks/M1-05a/throwaway.txt)" sh -c '…'` running `mise install` in that clone with `grep -cE 'installing|downloading'` over its output equal to 0 (the pre-warmed toolchain is exactly termrock's own `mise.toml` plus `rust-toolchain.toml` 1.97.1 and "cargo-public-api 0.52.0", D-048: nothing from jackin's `mise.toml`), `cargo nextest --version`, `cargo public-api --version`, `rustup run 1.97.1 cargo --version`, and `! command -v agent-browser` and `! command -v op`; `test -s tasks/M1-05a/tailrocks-skills-sha.txt`; the probe is ejected by the session before the verify runs, so `verify.sh` itself never launches, attaches, or ejects

When a container part exists the host part first asserts that
`tasks/M1-05a/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M1-05a/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M1-05a/tailrocks-skills-sha.txt` (container part)
- `tasks/M1-05a/throwaway.txt` (container part)
- `tasks/M1-05a/smoke.out` (container part)

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
