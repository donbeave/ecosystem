# Preflight defects

Operator inputs discovered missing during the `/goal` run (D-050). A row
here is the only condition under which the run stops, and only once no
other task is runnable (`goal/EXECUTION.md` §6). The host session appends
rows; the human clears the item, fills the `Resolved` cell, and re-runs
`/goal Follow GOAL.md`. Never a secret value: item names, `op://`
references, commands, and UI paths only (D-035).

| # | Task | Missing item | Proof it is in place | Recorded (UTC) | Resolved (UTC) |
| --- | --- | --- | --- | --- | --- |
