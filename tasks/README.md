# Tasks

Index of every task with its status (D-038). This file is a generated
projection of the run-state store `run/events.jsonl` and is never
hand-edited: `python3 tools/state.py render` rewrites it from the log, so a
hand edit is silently discarded at the next render (D-111). An agent
starting a task reads this file, then its task folder, and works only on
that task; the host session, the only writer of this repository, records the
status change as an event and re-renders (`goal/EXECUTION.md` §5, D-086).

Statuses: `planned`, `ready`, `leased` (a fencing token is held, D-113),
`in-progress`, `waiting` (every lane of the chain throttled, D-071),
`resource-waiting` (a cap, not a lane, is the constraint), `blocked`
(missing operator input or exhausted, D-070; only a row with its own open
`PREFLIGHT-DEFECTS.md` row is ever `blocked` — dependents stay `ready` and
are simply not runnable, D-084; an `exhausted:` row stays `blocked` until
the human fills its `Resolved` cell, D-093), `failed-system` (the
infrastructure, not the task, failed), `done` — lowercase, exactly these.
The root `verify.sh` (D-069) parses this table by the `Task` and `Status`
header names, reads the task id from the `Task` cell (a link is fine), and
requires `done` plus an existing `tasks/<id>/verify.sh` for every id in
`ROADMAP.md`. Columns may be added (for example the Linear URL from M1-12);
these two must stay.

| Task | Milestone | Depends on | Status |
| --- | --- | --- | --- |
| M1-01 | M1 | — | done |
| M1-02 | M1 | — | done |
| M1-02a | M1 | M1-02 | ready |
| M1-03 | M1 | M1-05d | planned |
| M1-04a | M1 | M1-02 | ready |
| M1-05a | M1 | M1-04a | planned |
| M1-05b | M1 | M1-04a | planned |
| M1-05c | M1 | M1-04a | planned |
| M1-05d | M1 | M1-05a, M1-05b, M1-05c | planned |
| M1-06 | M1 | M1-05b, M1-05d | planned |
| M1-07 | M1 | M1-03, M1-06 | planned |
| M1-08 | M1 | M1-05d | planned |
| M1-09 | M1 | M1-07, M1-08, M1-10, M1-13 | planned |
| M1-10 | M1 | M1-07 | planned |
| M1-11 | M1 | M1-09, M1-10 | planned |
| M1-12 | M1 | M1-01, M1-09, M1-10, M1-13 | planned |
| M1-13 | M1 | M1-02, M1-05d | planned |
| M10-01 | M10 | M5-01, M7-02 | planned |
| M10-02 | M10 | — | planned |
| M10-03 | M10 | — | planned |
| M10-04 | M10 | M10-01, M10-02, M10-03 | planned |
| M10-05 | M10 | M10-04 | planned |
| M10-06 | M10 | M10-05 | planned |
| M11-01 | M11 | M1-03 | planned |
| M11-01a | M11 | M10-05 | planned |
| M11-02 | M11 | M11-01, M11-01a | planned |
| M11-03 | M11 | M1-13, M10-01, M11-01, M11-02 | planned |
| M11-04 | M11 | M11-03 | planned |
| M11-05 | M11 | M11-04 | planned |
| M12-01 | M12 | M11-03 | planned |
| M12-02 | M12 | M12-01 | planned |
| M12-03 | M12 | M12-02 | planned |
| M12-04 | M12 | M12-03 | planned |
| M2-01 | M2 | M1-02, M1-10 | planned |
| M2-02 | M2 | M2-01 | planned |
| M2-03 | M2 | M2-02 | planned |
| M2-04 | M2 | M2-02, M2-05 | planned |
| M2-05 | M2 | M1-08 | planned |
| M2-06 | M2 | M2-03, M2-05 | planned |
| M2-07 | M2 | M2-04, M2-06 | planned |
| M2-08 | M2 | M2-07 | planned |
| M3-01 | M3 | M1-02 | planned |
| M3-02 | M3 | M3-01 | planned |
| M3-02a | M3 | M3-02 | planned |
| M3-03 | M3 | M1-02 | planned |
| M3-04 | M3 | M3-01 | planned |
| M3-05 | M3 | M1-13, M2-04, M3-02, M3-03, M3-04 | planned |
| M3-06 | M3 | M3-05 | planned |
| M3-07 | M3 | M1-13, M3-05, M3-06 | planned |
| M3-08 | M3 | M3-07 | planned |
| M4-01 | M4 | M3-01 | planned |
| M4-02 | M4 | M1-02 | planned |
| M4-03 | M4 | M1-02 | planned |
| M4-04 | M4 | M1-13, M2-04, M4-01, M4-02 | planned |
| M4-05 | M4 | M4-01, M4-02 | planned |
| M4-06 | M4 | M1-13, M4-04, M4-05 | planned |
| M4-07 | M4 | M4-06 | planned |
| M5-01 | M5 | M2-04, M4-04 | planned |
| M5-02 | M5 | M4-02, M5-01 | planned |
| M5-03 | M5 | M5-02 | planned |
| M5-04 | M5 | M1-09, M5-01 | planned |
| M5-05 | M5 | M3-04, M3-05, M5-01 | planned |
| M5-06 | M5 | M4-05, M5-02, M5-03, M5-04, M5-05 | planned |
| M5-07 | M5 | M5-06 | planned |
| M6-01 | M6 | M4-04 | planned |
| M6-02 | M6 | M5-01, M6-01 | planned |
| M6-03 | M6 | M1-13, M6-02 | planned |
| M6-04 | M6 | M6-03 | planned |
| M6-05 | M6 | M3-05, M7-02 | planned |
| M7-01 | M7 | M4-03, M6-02 | planned |
| M7-02 | M7 | M5-03, M7-01 | planned |
| M7-03 | M7 | M7-02 | planned |
| M7-04 | M7 | M7-03 | planned |
| M7-05 | M7 | M7-04 | planned |
| M8-01 | M8 | M1-03 | planned |
| M8-02 | M8 | M7-01, M8-01 | planned |
| M8-03 | M8 | M8-02 | planned |
| M8-04 | M8 | M8-03 | planned |
| M9-01 | M9 | M8-02 | planned |
| M9-02 | M9 | M9-01 | planned |
| M9-03 | M9 | M9-02 | planned |
