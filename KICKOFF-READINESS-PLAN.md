# Kick-off readiness plan — `tailrocks/ecosystem`

The readiness run of 2026-08-28 completed. It consolidated two external reviews, the
round-three findings (now dispositioned in `findings/disposition.toml`) and a live audit of
the repository and host into 55 rows, and applied every row that an agent could apply; the
resulting changes are the commit range `3adb0d3..397effa` on `main`. The findings tables,
the recommendation plan and the proposed decisions that made up sections 1–6 of this
document were consumed by that run and have been removed; what they decided lives in
`DECISIONS.md`, `SPEC.md` and `ROADMAP.md`, and what they measured lives in
`findings/disposition.toml`.

## Run record

Readiness-hardening run, 2026-08-28. Host commit range `3adb0d3..397effa` on `main`.

**Row outcomes (55 rows across Phases 0–4):** 45 `done`, 9 `blocked-on-human`,
1 `disproved-with-evidence`.

The nine `blocked-on-human` rows reduce to six operator inputs. Open operator items: see
`PREFLIGHT-DEFECTS.md`, where each is carried as an open row with the command that proves
it is in place.

**Next command for the human.** Clear those rows, then run

```
sh tools/readiness.sh live
```

and, once it prints `status: READY`, paste the `/goal` invocation line from `README.md`
"Start the run".
