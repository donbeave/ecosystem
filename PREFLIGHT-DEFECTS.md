# Preflight defects

Operator inputs discovered missing during the `/goal` run (D-050) and
tasks exhausted after the attempt cap (rows whose "Missing item" starts
with `exhausted: <id>`, D-070). An open row here is the only condition
under which the run ends BLOCKED rather than COMPLETE, and only once no
other task is runnable (`goal/EXECUTION.md` §6). The host session appends
rows; the human clears the item (the `Resolved` cell may stay empty: the
session re-runs each missing-input proof command at the next start and
fills it; an `exhausted:` row has `re-run` in its proof cell and
is closed only by the human filling `Resolved`; until then its task stays
`blocked` and is never re-attempted, D-084, D-093) and re-runs the `/goal` invocation line of `README.md` "Start the run". Lane fallbacks, quota waits, and capsule
dialogs are never rows here (D-071, D-082). Never a secret value: item names, `op://`
references, commands, and UI paths only (D-035).

| # | Task | Missing item | Proof it is in place | Recorded (UTC) | Resolved (UTC) |
| --- | --- | --- | --- | --- | --- |
| 1 | plan row 0.2 | Plan snapshot tag `plan-review-*` at 130cb4b7 (human-only: tagging the reviewed snapshot) | `git tag -l 'plan-review-*'` shows one tag at `130cb4b7`; create with `git tag plan-review-2026-08-28 130cb4b7 && git push origin plan-review-2026-08-28` | 2026-08-28 | 2026-08-28 |
| 2 | plan row 0.3 | Ruleset on `donbeave/ecosystem` `main` (non-fast-forward, deletion) — repository settings UI, human-only | `gh api repos/donbeave/ecosystem/rules/branches/main --jq '[.[].type]'` is non-empty | 2026-08-28 | 2026-08-28 |
| 3 | plan row 2.6 | `delete_branch_on_merge` is `true` in jackin-project/jackin, jackin-project/jackin-the-architect, tailrocks/termrock; must be `false` (repository settings, human-only) | `for r in jackin-project/jackin jackin-project/jackin-the-architect tailrocks/termrock; do gh api repos/$r --jq .delete_branch_on_merge; done` prints `false` three times | 2026-08-28 | 2026-08-28 |
| 4 | plan row 2.7 | 1Password CLI not signed in (`op whoami` → "account is not signed in"); sign in, set auto-lock Never, confirm the operations the run uses (human-only) | `op read "op://Private/Context7/API Keys/Claude" </dev/null >/dev/null && echo ok` prints `ok` (`op whoami` is not used: it fails on desktop-app integration with no CLI account, `goal/PREFLIGHT.md` §1) | 2026-08-28 | 2026-08-28 |
| 5 | plan row 2.8 | GitHub App `jackin-daemon` not installed in `jackin-project` or `tailrocks` (installed apps today: `claude`, `dco-2`); create + install (All repositories) and store its four fields in 1Password (human-only) | `gh api /orgs/jackin-project/installations --jq '.installations[].app_slug'` and `gh api /orgs/tailrocks/installations --jq '.installations[].app_slug'` both contain `jackin-daemon` | 2026-08-28 | 2026-08-28 |
| 6 | plan row 2.9 | `~/.jackin/agent-browser-profile/state.json` absent; sign in headed to Linear and GitHub and save the operator browser state (human-only) | `test -s ~/.jackin/agent-browser-profile/state.json && jq '.cookies \| length' ~/.jackin/agent-browser-profile/state.json` prints a number > 0 | 2026-08-28 | 2026-08-28 |
| 7 | M1-05d | 1Password item `op-service-account-jackin-operator` absent from vault `tailrocks` (`op read op://tailrocks/op-service-account-jackin-operator/credential` fails: not an item in the vault); create the service account and store its token there (`goal/PREFLIGHT.md` §2, human-only) | `op read op://tailrocks/op-service-account-jackin-operator/credential </dev/null \| wc -c` is non-zero | 2026-08-28 | 2026-08-28 |
| 8 | M1-04a | 1Password desktop app stopped authorizing the CLI mid-run: `op read "op://Private/Context7/API Keys/Claude"` fails with `error initializing client: authorization timeout`, so `jackin load` cannot resolve the global `[env]` references (CONTEXT7_API_KEY, KIMI_CODE_API_KEY, MINIMAX_API_KEY, ZAI_API_KEY) and the container never starts; unlock the 1Password app, approve the CLI integration prompt, set auto-lock to Never (`goal/PREFLIGHT.md` §1, human-only) | `op read "op://Private/Context7/API Keys/Claude" </dev/null >/dev/null && echo ok` prints `ok` within 10 s | 2026-08-28 | |
| 9 | M3-03 | Same item as row 8: `jackin load the-architect task-M3-03 --agent codex` (container path, L4) cannot start while the 1Password desktop app refuses CLI authorization (`authorization timeout`); no attempt consumed | `op read "op://Private/Context7/API Keys/Claude" </dev/null >/dev/null && echo ok` prints `ok` within 10 s | 2026-08-28 | |
| 10 | M4-03 | Same item as row 8: `jackin load the-architect task-M4-03 --agent codex` (container path, L4) cannot start while the 1Password desktop app refuses CLI authorization (`authorization timeout`); no attempt consumed | `op read "op://Private/Context7/API Keys/Claude" </dev/null >/dev/null && echo ok` prints `ok` within 10 s | 2026-08-28 | |
| 11 | M3-01 | Same item as row 8: the host part (`cargo nextest … load_options_launch` launching `the-architect` on host Docker) fails in operator env resolution with `op read … authorization timeout`; implementation is pushed on `managed/goal-run-1/M3-01` @ 78690bf2892d421228a831b30ac09db71ba6ca9f and not yet integrated (D-112: verify first) | `op read "op://Private/Context7/API Keys/Claude" </dev/null >/dev/null && echo ok` prints `ok` within 10 s | 2026-08-28 | |
