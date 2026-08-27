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

Per `concept/roles.md` §3: construct base, `agents = ["claude","codex"]`, no `[claude].model` (the lane sets it, D-078), termrock's mise toolchain (D-048: not jackin's), `tailrocks-skills` (marketplace `source = "tailrocks/tailrocks-skills"`; Codex skills-dir clone pinned to the commit `ARG TAILROCKS_SKILLS_SHA`, recorded in `tasks/M1-05a/`) and official plugins, Codex skills as files, `[docker] min_profile = "standard"`, `preflight.sh`, `hooks/source.sh` writing the lane's Codex `model`/`model_reasoning_effort` into `$CODEX_HOME/config.toml` (D-078; the hook is sourced, not executed: it opens with `CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"`, never sets `-e` and never calls `exit`, and is a no-op when `JACKIN_LANE_CODEX_MODEL` is unset), env defaults; `AGENTS.md` with threat model stating that the agent merges its own PR when the task says so (D-055, D-079). The repository commits directly to `main` (D-074). No `agent-browser`, no `op`.

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
- [ ] host check passes: `jackin role validate`
- [ ] host check passes: `jackin load donbeave/crew-builder probe-M1-05a --agent claude`
- [ ] host check passes: `jackin status --format json`
- [ ] host check passes: `docker exec -u agent <name> sh -c '…'`
- [ ] host check passes: `mise install`
- [ ] host check passes: `git clone`
- [ ] host check passes: `grep -cE 'installing|downloading' <that output>`
- [ ] host check passes: `cargo nextest --version`
- [ ] host check passes: `cargo public-api --version`
- [ ] host check passes: `agent-browser`
- [ ] host check passes: `op`
- [ ] `throwaway/status.json` is filed in the task folder.
- [ ] `throwaway/inside.out` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none

Host part (run by the host Claude Code session, D-061):

> `jackin role validate` passes on the cached checkout; the host session performs the throwaway load of `goal/EXECUTION.md` §5 step 4b (`jackin load donbeave/crew-builder probe-M1-05a --agent claude`, with the termrock checkout mounted) and files `tasks/M1-05a/throwaway/status.json`, the `jackin status --format json` row, showing role `donbeave/crew-builder` and agent `claude`; `tasks/M1-05a/throwaway/inside.out`, the output of `docker exec -u agent <name> sh -c '…'` running `mise install` in a fresh `git clone` of termrock and asserting `grep -cE 'installing|downloading' <that output>` is 0 (the pre-warmed toolchain is exactly termrock's own `mise.toml` plus `rust-toolchain.toml` 1.97.1 and "cargo-public-api 0.52.0", D-048: nothing from jackin's `mise.toml`), `cargo nextest --version`, `cargo public-api --version` and `rustup run 1.97.1 cargo --version`, and asserting that neither `agent-browser` nor `op` is on PATH, ends with the line `inside: ok`; the probe is ejected by the session before the verify runs, so `verify.sh` itself never launches, attaches, or ejects

## Evidence expected (D-118)

- `tasks/M1-05a/throwaway/status.json` (host part)
- `tasks/M1-05a/throwaway/inside.out` (host part)

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
