# M1-05c Create `donbeave/crew-reviewer`

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | M1-04a |
| role | `the-architect` |
| lane | L6 |
| runtime | codex |
| fallback lane | L1 |
| delivery | goal |
| size | S |
| repositories | jackin-crew-reviewer (new) |
| branch | `main` |

## Objective

Create `donbeave/crew-reviewer`.

## Scope

Per `concept/roles.md` §3: construct base, node only, `code-review` and `pr-review-toolkit` plugins, `tailrocks-skills` (marketplace `source = "tailrocks/tailrocks-skills"`, skills clone pinned by commit), `review-crucible` pinned by commit (`ARG REVIEW_CRUCIBLE_SHA=5936f0e069946db0ee4408e72122b134800336e4`, the repository has no tags and its default branch is `port/cross-agent-dry`; `git init /opt/review-crucible && git -C /opt/review-crucible fetch --depth 1 https://github.com/tailrocks/review-crucible $REVIEW_CRUCIBLE_SHA && git -C /opt/review-crucible checkout FETCH_HEAD`, then `/opt/review-crucible/skills/review-crucible` linked to `/home/agent/.agents/skills/review-crucible`), `hooks/source.sh` staging Codex agents and the lane's `config.toml` keys (D-078); workspace read-only; Reviews API verdict flow of D-079 (`COMMENT` event with a `verdict:` first line while the `gh` login equals the PR author — always before M8-01; never retry a 422 with the same event; never `APPROVE`). `AGENTS.md` encodes the identity check. Commits directly to `main` (D-074). No compiler, no `op`, no `agent-browser`.

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
- [ ] container check passes: `test -f /home/agent/.agents/skills/review-crucible/SKILL.md`
- [ ] container check passes: `git -C /opt/review-crucible rev-parse HEAD`
- [ ] container check passes: `cargo`
- [ ] container check passes: `op`
- [ ] container check passes: `agent-browser`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> Validate passes; loads on both runtimes; `test -f /home/agent/.agents/skills/review-crucible/SKILL.md` and `git -C /opt/review-crucible rev-parse HEAD` equals the `REVIEW_CRUCIBLE_SHA` recorded in `tasks/M1-05c/`; `$CODEX_HOME/agents/` populated after `source.sh`; no `cargo`, `op`, or `agent-browser`

Host part (run by the host Claude Code session, D-061):

> none

When a container part exists the host part first asserts that
`tasks/M1-05c/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M1-05c/verify.container.out` (container part, containing `status: DONE`)

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
