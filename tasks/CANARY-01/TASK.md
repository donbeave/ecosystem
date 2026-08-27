# CANARY-01 — canary

Synthetic task used to rehearse the delivery path end to end. It belongs to no
milestone and to no roadmap row, so the compiler must keep yielding 81 tasks
and the roadmap gate must ignore this id.

## What the worker does

Write the file `tasks/CANARY-01/canary.txt` containing exactly the line below, commit it
with a sign-off on the task branch, push that branch, and open one pull request
against the integration branch.

    canary CANARY-01 readiness-2026-08-28

## What proves it

`sh tasks/CANARY-01/verify.sh host` checks the file and its content at the commit under
verification and prints `status: DONE` as its last line. The evidence manifest
names the integrated commit and the external objects the task created.
