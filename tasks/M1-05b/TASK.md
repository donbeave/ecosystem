# M1-05b Create `donbeave/crew-operator`

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | M1-04a |
| role | `the-architect` |
| lane | L5 |
| runtime | codex |
| fallback lane | L6 |
| delivery | goal |
| size | M |
| repositories | jackin-crew-operator (new) |
| branch | `main` |

## Objective

Create `donbeave/crew-operator`.

## Scope

Per `concept/roles.md` §3: construct base, `gh` (present), `npm i -g agent-browser@0.35.1` with no `agent-browser install` (Chrome for Testing publishes no Linux arm64 build; this host builds native arm64): apt `chromium fonts-noto-cjk fonts-noto-color-emoji` on both architectures and manifest env default `AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium` (D-077); `op` CLI 2.39.0 by direct download, never the apt repository (it keeps only the current version, so a pin fails on the next release, D-090): `ARG OP_CLI_VERSION=2.39.0`, `ARG OP_CLI_SHA256_ARM64=829baeff1c07e055cfa132031b1d9f2282ccdf5076258e482caf2fda70aea5d0`, `ARG OP_CLI_SHA256_AMD64=6fba7f376b6c6dec49f41b06408930a43ad064cce103c6a2ce5b3d0413a86434`, `RUN arch=$(dpkg --print-architecture) && curl -fsSLo /tmp/op.zip "https://cache.agilebits.com/dist/1P/op2/pkg/v${OP_CLI_VERSION}/op_linux_${arch}_v${OP_CLI_VERSION}.zip" && echo "<sha for arch>  /tmp/op.zip" | sha256sum -c && unzip -o /tmp/op.zip -d /usr/local/bin op && chmod 755 /usr/local/bin/op` (`cache.agilebits.com` named as a trust anchor in `AGENTS.md`); node; `agents = ["claude","codex"]`, no `[claude].model`; `OP_SERVICE_ACCOUNT_TOKEN` is not declared in the manifest `[env]` (the value arrives at exec time through the on-demand `jackin-exec` binding of M1-05d, so a launch prompt has nothing to collect, D-078; `EnvVarDecl` has no `secret` key and an interactive declaration would raise a launch prompt — the `concept/roles.md` §3.2 sketch is the corrected shape); no `[claude].model`; `AGENT_BROWSER_*` defaults; `python3` (the one-shot loopback listener M1-10's authorize step needs on `127.0.0.1:53682`); `preflight.sh` running `agent-browser doctor --json` and loading `/home/agent/.agent-browser-profile/state.json` when `agent-browser open https://linear.app` lands on a login page — it exits non-zero for one cause only, a live `SingletonLock` PID; a missing profile directory, a missing `state.json` or a still-logged-out session make it print `[operator-preflight] WARNING: no browser session — run the M1-06 re-login` and exit 0, because jackin's entrypoint exits the container on a non-zero preflight and the profile mount only arrives in M1-05d (D-077; the logged-in assertion belongs to M1-06 and to each operator task's own checklist); threat model naming the profile and `state.json` as secrets. Commits directly to `main` (D-074). No Rust.

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
- [ ] container check passes: `jackin role validate && ! grep -qE '^[env.OP_SERVICE_ACCOUNT_TOKEN]' jackin.role.toml && ! grep -qE '^model *=' jackin.role.toml && grep -q AGENT_BROWSER_EXECUTABLE_PATH jackin.role.toml`
- [ ] host check passes: `jackin load donbeave/crew-operator probe-M1-05b --agent claude --mount ~/.jackin/agent-browser-profile:/home/agent/.agent-browser-profile`
- [ ] host check passes: `docker logs <name>`
- [ ] host check passes: `docker exec -u agent <name> sh -c '…'`
- [ ] host check passes: `gh --version`
- [ ] host check passes: `agent-browser --version`
- [ ] host check passes: `python3 --version`
- [ ] host check passes: `test -x /usr/bin/chromium`
- [ ] host check passes: `agent-browser doctor --json`
- [ ] host check passes: `agent-browser open about:blank`
- [ ] host check passes: `! command -v cargo`
- [ ] `verify.container.out` is filed in the task folder.
- [ ] `throwaway/status.json` is filed in the task folder.
- [ ] `throwaway/preflight.out` is filed in the task folder.
- [ ] `throwaway/inside.out` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> In the role checkout: `jackin role validate && ! grep -qE '^[env.OP_SERVICE_ACCOUNT_TOKEN]' jackin.role.toml && ! grep -qE '^model *=' jackin.role.toml && grep -q AGENT_BROWSER_EXECUTABLE_PATH jackin.role.toml`

Host part (run by the host Claude Code session, D-061):

> the host session performs the throwaway load of `goal/EXECUTION.md` §5 step 4b (`jackin load donbeave/crew-operator probe-M1-05b --agent claude --mount ~/.jackin/agent-browser-profile:/home/agent/.agent-browser-profile`, counted against the operator cap) and files `tasks/M1-05b/throwaway/status.json` showing role `donbeave/crew-operator`; `tasks/M1-05b/throwaway/preflight.out` (from `docker logs <name>`) contains an "operator-preflight" line and the container is still running, proving the hook never aborts the entrypoint; `tasks/M1-05b/throwaway/inside.out`, the output of `docker exec -u agent <name> sh -c '…'` running `[ "$(op --version)" = "2.39.0" ]`, `gh --version`, `agent-browser --version`, `python3 --version`, `test -x /usr/bin/chromium`, `agent-browser doctor --json` naming `/usr/bin/chromium`, `agent-browser open about:blank` headless, a write into the profile path, and `! command -v cargo`, ends with the line `inside: ok`; the probe is ejected by the session before the verify runs

When a container part exists the host part first asserts that
`tasks/M1-05b/verify.container.out` ends with `status: DONE`, so a
passing host part can never mask a failed container part (D-086).

## Evidence expected (D-118)

- `tasks/M1-05b/verify.container.out` (container part, containing `status: DONE`)
- `tasks/M1-05b/throwaway/status.json` (container part)
- `tasks/M1-05b/throwaway/preflight.out` (container part)
- `tasks/M1-05b/throwaway/inside.out` (container part)

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
