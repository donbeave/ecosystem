# Preflight defects

Operator inputs discovered missing during the `/goal` run (D-050) and
tasks exhausted after the attempt cap (rows whose "Missing item" starts
with `exhausted: <id>`, D-070). An open row here is the only condition
under which the run ends BLOCKED rather than COMPLETE, and only once no
other task is runnable (`goal/EXECUTION.md` §6). The host session appends
rows; the human clears the item (the `Resolved` cell may stay empty: the
session re-runs each proof command at the next start and fills it) and
re-runs `/goal Follow GOAL.md`. Lane fallbacks, quota waits, and capsule
dialogs are never rows here (D-071, D-082). Never a secret value: item names, `op://`
references, commands, and UI paths only (D-035).

| # | Task | Missing item | Proof it is in place | Recorded (UTC) | Resolved (UTC) |
| --- | --- | --- | --- | --- | --- |
