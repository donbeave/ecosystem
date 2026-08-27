# Progress

Append-only ledger of the `/goal` run (`GOAL.md`). One row per finished,
blocked, or waiting task, written by the host session right after the
task's `tasks/README.md` row changes (`goal/EXECUTION.md` §5). Authoring
runs for M6..M12 folders (including their M1-12 re-run) are recorded as
`<milestone>-00 authoring`. Attempts (`n/limit`, the exhaustion counter of
D-070, never reset by a resume), lane fallbacks and quota hops (D-057,
D-071), and `re-sync` re-launches go into the result cell, never into
separate rows; the lane cell names where the work actually ran
(`L4 → L1 (host)`).

| Task | Lane | Path | Result | Evidence | When (UTC) |
| --- | --- | --- | --- | --- | --- |
