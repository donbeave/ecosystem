# Tasks

Index of every task folder in this directory with its status (D-038). An
agent starting a task reads this file, then its task folder, works only on
that task, and updates the status here when done. Tasks are created only
after `ROADMAP.md` is finalized; each becomes a Linear issue when it is
ready to execute.

Statuses: `planned`, `ready`, `in-progress`, `blocked`, `done` — lowercase,
exactly these. The root `verify.sh` (D-069) parses this table by the
`Task` and `Status` header names, reads the task id from the `Task` cell
(a link is fine), and requires `done` plus an existing
`tasks/<id>/verify.sh` for every id in `ROADMAP.md`. Columns may be added
(for example the Linear URL from M1-12); these two must stay.

| Task | Milestone | Depends on | Status |
| --- | --- | --- | --- |
| _none yet — roadmap not finalized_ | | | |
