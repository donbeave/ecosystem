# Progress

Ledger of the `/goal` run (`GOAL.md`). One row per finished, blocked, or
waiting task. This file is a generated projection of the run-state store
`run/events.jsonl` and is never hand-edited: `python3 tools/state.py render`
rewrites it from the log (D-098). There is no authoring run to record: all
81 bundles are materialised before the run starts (D-114).
Attempts (`n/limit`, the exhaustion counter of D-070, never reset within an
epoch: a resume after a crash keeps the count, and only the closing of an
`exhausted:` row at a session start opens a new epoch, recorded as `epoch 2:
0/3`, D-084), lane fallbacks and quota hops (D-057, D-071), `re-sync`
re-launches, and `prompt landed: file` go into the result cell, never into
separate rows; the lane cell names where the work actually ran
(`L4 → L1 (host)`).

| Task | Lane | Path | Result | Evidence | When (UTC) |
| --- | --- | --- | --- | --- | --- |
