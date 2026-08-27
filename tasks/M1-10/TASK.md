# M1-10 Authorize the app into the workspace

Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`
(D-114). Do not edit by hand: an edit here is lost on the next
generation and makes `tools/bundle.py verify --all` fail. Change the
roadmap row instead.

| Field | Value |
| --- | --- |
| milestone | M1 |
| depends on | M1-07 |
| role | `donbeave/crew-operator` |
| lane | L6 |
| runtime | codex |
| fallback lane | L1 |
| delivery | prompt |
| size | S |
| repositories | Linear, 1Password |
| branch | `main` |

## Objective

Authorize the app into the workspace.

## Scope

Run the `actor=app` authorize flow (D-080): read `client id` and `redirect uri` from `op://jackin/linear-agent-app` via `jackin-exec op read`; `agent-browser open` `https://linear.app/oauth/authorize?client_id=…&redirect_uri=http://localhost:53682/callback&response_type=code&actor=app&scope=read,write,issues:create,comments:create,app:assignable,app:mentionable&state=<random>` (comma-separated scopes), before clicking Authorize, start a one-shot loopback listener inside the operator container so the redirect is actually served — `python3 -m http.server 53682 --bind 127.0.0.1 >tasks/M1-10/callback.log 2>&1 &` — because Chromium replaces the main-frame URL with `chrome-error://chromewebdata/` on `ERR_CONNECTION_REFUSED` and `agent-browser url` would lose the query string; grant access to all teams on the consent screen, click Authorize, then read `code` and `state` from the `GET /callback?code=…&state=…` request line in `callback.log`, check `state`, and delete `callback.log` before any commit (it holds a one-time code, D-081); exchange at `https://api.linear.app/oauth/token` with `grant_type=authorization_code` using `curl --config -` fed from stdin so the client secret never appears in argv or in the task folder (this exchange installs the app into the workspace; its refresh token is stored as `installation seed` and never used afterwards); then mint the token every consumer uses: `grant_type=client_credentials` with the same scope list (an `actor=app` token valid 30 days, D-087, `analysis/linear-agents.md`), stored as `access token` and `expires at`; query `viewer { id organization { id urlKey } }`; store access token, expires at, installation seed, app user id, organization id, and that `urlKey` as `url key` in the single item `op://jackin/linear-workspace` via `jackin-exec op item create` (the item name carries no organization slug, so every later consumer can name it without knowing the workspace, D-108). Every later host-side call follows the Linear-token rule of `goal/EXECUTION.md` §4 (re-mint when fewer than 48 hours remain; the refresh grant is never used).

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
- [ ] host check passes: `op read "op://jackin/linear-workspace/access token"`
- [ ] host check passes: `curl --config -`
- [ ] host check passes: `gitleaks detect --no-git --source tasks/M1-10`
- [ ] host check passes: `test ! -e tasks/M1-10/callback.log`
- [ ] `callback.log` is filed in the task folder.
- [ ] `app-user-id.txt` is filed in the task folder.
- [ ] `org.txt` is filed in the task folder.
- [ ] Every touched repository is committed and pushed.
- [ ] `sh verify.sh` prints `status: DONE` for each part.

## Verify contract

Container part (run inside the task container):

> none

Host part (run by the host Claude Code session, D-061):

> under the Linear-token rule of `goal/EXECUTION.md` §4, `op read "op://jackin/linear-workspace/access token"` fed into `curl --config -` (never in argv, never through "jackin-exec") makes "query Me { viewer { id } }" return the app user id recorded in the item, which is also filed as `tasks/M1-10/app-user-id.txt` for later consumers; the organization `urlKey` is filed as `tasks/M1-10/org.txt`; "expires at" is more than 20 days out; `gitleaks detect --no-git --source tasks/M1-10` is clean and `test ! -e tasks/M1-10/callback.log`

## Evidence expected (D-118)

- `tasks/M1-10/callback.log` (host part)
- `tasks/M1-10/app-user-id.txt` (host part)
- `tasks/M1-10/org.txt` (host part)

## Proof (browser/attach)

The app appears under workspace integrations.

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
