# Tasks

Index of every task with its status (D-038); M1-01 (wave 0) writes one row
per M1..M5 id before any other task starts (D-072). An
agent starting a task reads this file, then its task folder, and works only
on that task; the host session, the only writer of this repository, updates
the status here (`goal/EXECUTION.md` §5, D-086). Tasks are created only
after `ROADMAP.md` is finalized; each becomes a Linear issue when it is
ready to execute.

Statuses: `planned`, `ready`, `in-progress`, `waiting` (every lane of the
chain throttled, D-071), `blocked` (missing operator input or exhausted,
D-070; only a row with its own open `PREFLIGHT-DEFECTS.md` row is ever
`blocked` — dependents stay `ready` and are simply not runnable, D-084; an
`exhausted:` row stays `blocked` until the human fills its `Resolved`
cell, D-093),
`done` — lowercase, exactly these. The root `verify.sh` (D-069) parses this table by the
`Task` and `Status` header names, reads the task id from the `Task` cell
(a link is fine), and requires `done` plus an existing
`tasks/<id>/verify.sh` for every id in `ROADMAP.md`. Columns may be added
(for example the Linear URL from M1-12); these two must stay.

| Task | Milestone | Depends on | Status |
| --- | --- | --- | --- |
| _none yet — written by M1-01_ | | | |
