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
| 1 | plan row 0.2 | Plan snapshot tag `plan-review-*` at 130cb4b7 (human-only: tagging the reviewed snapshot) | `git tag -l 'plan-review-*'` shows one tag at `130cb4b7`; create with `git tag plan-review-2026-08-28 130cb4b7 && git push origin plan-review-2026-08-28` | 2026-08-28 | |
| 2 | plan row 0.3 | Ruleset on `donbeave/ecosystem` `main` (non-fast-forward, deletion) — repository settings UI, human-only | `gh api repos/donbeave/ecosystem/rules/branches/main --jq '[.[].type]'` is non-empty | 2026-08-28 | |
