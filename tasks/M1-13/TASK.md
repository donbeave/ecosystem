# M1-13 Configure jackin multi-account lanes

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | M1-02, M1-02a, M1-05d |
| role | `the-architect` |
| lane | L1 |
| runtime | claude |
| fallback lane | L2 |
| delivery | goal |
| size | M |
| repositories | jackin, jackin-the-architect, host |
| branch | `feat/managed-execution` |

## Objective

Configure jackin multi-account lanes.

## Scope

jackin has no per-workspace model or effort knob today (D-078), and a saved workspace is selected only by name with one fixed `workdir`, so a lane cannot be one profile shared by many checkouts (D-085). Therefore a lane is a template: extend the six `tasks/M1-02a/lanes/L<n>.toml` into `tasks/M1-13/lanes/L<n>.toml`, each carrying `[claude]`/`[codex] sync_source_dir` (all four homes of D-039), `[env]` — Claude lanes `ANTHROPIC_MODEL=<id>`, `CLAUDE_CODE_EFFORT_LEVEL=medium`; Codex lanes `JACKIN_LANE_CODEX_MODEL=<id>`, consumed by the roles' `hooks/source.sh` writing `model`/`model_reasoning_effort = "medium"` into `$CODEX_HOME/config.toml` (host `config.toml` is not synced, only `auth.json`) — and nothing else: a lane is runtime plus model plus account home and every lane serves builder, operator, and reviewer tasks, so Docker grants cannot live in a lane template. Grants are per role, in `tasks/M1-13/grants/<role>.toml`: `the-architect` and `donbeave/crew-builder` get `[docker.grants] dind = "privileged"` (rootless is unproven under OrbStack and jackin's sidecar spec has no seccomp or capability knob), `donbeave/crew-operator` gets the network allowlist grant (Linear, Google, GitHub, 1Password hosts), `donbeave/crew-reviewer` gets neither; the host session merges the lane template and then the task's role grant file into every per-task workspace `~/.config/jackin/workspaces/task-<id>.toml` before `jackin load <role> task-<id>` (`goal/EXECUTION.md` §4). First the-architect PR of the run (D-089): before anything else, in `jackin-the-architect/.github/workflows/ci.yml` make the `ci-required` job and the three `lane:` inputs resolve to GitHub-hosted `ubuntu-26.04` for `pull_request` events (D-064; a `pull_request` run executes the PR's own workflow file, so the switch takes effect on this PR; the file is generator-rendered and the override is intentional), the same for the `config` matrices of `precommit.yml`; remove `[claude].model` so the env applies; `git commit -s`, `gh pr create`, `gh pr checks <n> --watch --fail-fast` until `ci-required` and `DCO` are green, `gh pr merge <n> --squash` (when `gh pr view <n> --json mergeStateStatus --jq .mergeStateStatus` is `BEHIND`, first `git fetch origin && git merge --no-ff --signoff origin/main && git push` and wait for the new `ci-required` run — never a rebase of the shared branch, which would need the forbidden `--force`), merge `origin/main` back into `feat/managed-execution` and push it, then `jackin load the-architect --rebuild`; record that per-launch `model`/`effort` argv is M3-01 work. The DinD grant serves `docker build`/`docker run`/testcontainers work only: the sidecar shares no filesystem with the role container, so a nested `jackin load` (the e2e `pty_runner`, `dind_e2e`) cannot work there and every test that launches or attaches to a jackin instance is a host part (D-091). Inside one builder-lane throwaway workspace run `docker info`, `docker run --rm hello-world`, and `docker run --rm --privileged docker:29-dind docker --version` against the sidecar and file `tasks/M1-13/dind.out` naming the tier that worked (later tasks cite it as the tier of record; no preflight defect). Run one throwaway per-task-style workspace per lane (workdir = a scratch checkout under `~/.jackin/managed/probe-L<n>`), one at a time and only when that lane's account home has no running container (throwaway loads count against the caps, D-088), and capture the runtime's reported model and account (`/status` for Claude; `codex --version` plus `/model` for Codex). Evaluate jackin's OAuth-token mode for L1..L3 (`claude setup-token`, `jackin workspace claude-token setup`, D-082) so no container holds a copy of the host session's rotating grant, and confirm whether Codex rotates its refresh token in-container; if so, copy the container's `auth.json` back to the lane home after each run (jackin fix on `feat/managed-execution` if absent, D-046). Record the exact model identifier and effort knob per lane in `tasks/M1-13/lanes.json`: one key per lane L1..L6, each `{"runtime","model_id","effort","label","account_home"}` where `label` is the literal Linear label value `model:<model_id>` (D-058, D-091: this record, not this document, is what `model:*` labels follow). Record what jackin supports today and what the daemon needs (per-launch account selection, Q-024).

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
- [ ] host check passes: `jackin load <role> probe-L<n> --dry-run --format json`
- [ ] host check passes: `jackin usage cache accounts --format json`
- [ ] host check passes: `docker info`
- [ ] host check passes: `jq -e 'keys==["L1","L2","L3","L4","L5","L6"] and all(.[]; .model_id!="" and .effort=="medium" and .label==("model:"+.model_id))' tasks/M1-13/lanes.json`
- [ ] host check passes: `gh pr view <n> -R jackin-project/jackin-the-architect --json state --jq .state`
- [ ] host check passes: `gh api repos/jackin-project/jackin-the-architect/contents/.github/workflows/ci.yml --jq .content | base64 -d | grep -c velnor-target-mvp`
- [ ] host check passes: `git show origin/main:jackin.role.toml`
- [ ] host check passes: `gh api repos/jackin-project/jackin-the-architect/branches/feat/managed-execution`
- [ ] `dind.out` is filed in the task folder.
- [ ] `lanes.json` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none (host row, D-061)

Host part (run by the host Claude Code session, D-061):

> six templates `tasks/M1-13/lanes/L<n>.toml` and four grant files `tasks/M1-13/grants/<role>.toml` exist; for each lane a throwaway per-task workspace makes `jackin load <role> probe-L<n> --dry-run --format json` print `.data.workspace` = `probe-L<n>`; four role probes show the grants of `tasks/M1-13/grants/<role>.toml` — the-architect and crew-builder the "dind" grant, crew-operator the network allowlist, crew-reviewer neither; the per-lane capture files in `tasks/M1-13/` show six distinct intended model ids and the intended account; `jackin usage cache accounts --format json` lists four distinct provider accounts after the throwaway loads; `tasks/M1-13/dind.out` shows `docker info` from inside a builder-lane container; `jq -e 'keys==["L1","L2","L3","L4","L5","L6"] and all(.[]; .model_id!="" and .effort=="medium" and .label==("model:"+.model_id))' tasks/M1-13/lanes.json`; `gh pr view <n> -R jackin-project/jackin-the-architect --json state --jq .state` is `MERGED`, `gh api repos/jackin-project/jackin-the-architect/contents/.github/workflows/ci.yml --jq .content | base64 -d | grep -c velnor-target-mvp` shows none on the "pull_request" path, `git show origin/main:jackin.role.toml` has no `[claude].model`, and `gh api repos/jackin-project/jackin-the-architect/branches/feat/managed-execution` returns 200

## Evidence expected (D-118)

- `tasks/M1-13/dind.out` (host part)
- `tasks/M1-13/lanes.json` (host part)

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
