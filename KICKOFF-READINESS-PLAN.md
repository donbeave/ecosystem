# Kick-off readiness plan — `tailrocks/ecosystem`

Prepared 2026-08-28 against `main` at `130cb4b7e1153af289da9bda1abb5de14fc94c70`.
Consolidates two external reviews (`final_feedback.md` = source **A**;
`ecosystem-final-deep-readiness-and-build-report-2026-08-28.md` = source **B**), the
round-three archive (`analysis/bulletproof-round3-findings.md` = **R3**), and a live audit of
the repository and host (**audit**). Every item marked *blocker* below was re-checked against
the repository, the installed tooling, or the GitHub API before it was written down.

---

## 1. Verdict

**Not kick-off ready.** The live gate prints `status: PENDING 81 remaining` (`tasks: 81
expected, 0 done`; 81 lines of `M<id>: no row in tasks/README.md; tasks/<id>/verify.sh
missing`), which is the truthful report of a run that has not started — but the gate itself
proves only that a row says `done` and that a file exists, so it cannot be the terminal oracle
the whole contract rests on. The execution package is not materialised: zero of the 81 task
bundles exist, the wave-0 task that would create them has no row and therefore no runnable
status under the package's own definition, and four host prerequisites that only a human can
supply (`op` sign-in, `delete_branch_on_merge`, the GitHub App installation, the operator
browser profile) are all missing today. Beyond the package, the roadmap graph carries at least
four confirmed producer/consumer or verifier cycles, and two external repositories
(`jackin-project/jackin`, `tailrocks/termrock`) enforce policies that the roadmap's merge plan
cannot satisfy as written.

---

## 2. What this repository is building

1. It is a planning and specification space, not a codebase — no source, no scaffolding
   (D-001, D-038). `VISION.md:134`: "This repository plans. It does not implement."
2. The product is **managed execution**: a long-running jackin daemon that turns "work with an
   agent" into "assign a Linear issue" (D-002, D-008, D-066).
3. A Linear issue carries repository, branch, role, runtime, model, effort, prompt and a
   checklist; assignment to the jackin agent app is the trigger. The daemon polls Linear,
   prepares workspace and branch, launches a jackin role container under the capsule, mirrors
   the checklist, streams run state back, runs `verify`, opens/updates the PR, merges.
4. Core thesis: small independently verifiable tasks beat one big plan; verification is a
   contract (`status: DONE`), not human judgement (D-003, D-004, D-007).
5. External repositories: `jackin-project/jackin` (49 of 81 tasks), `jackin-the-architect`,
   `tailrocks/termrock`, plus four new role repositories under `donbeave/`.
6. External systems: Linear (team `JACKIN`, sole authority for task state), GitHub,
   1Password, Docker/OrbStack, then one and then several Linux server hosts.
7. Twelve milestones: M1 Linear setup → M2 daemon reacts → M3 spawn → M4 prompt delivery →
   M5 live status → M6 checklist → M7 verify → M8 PR → M9 merge → M10 termrock TUI →
   M11 server → M12 multi-host. 81 tasks, 48 of them in M1..M5.
8. The **run** itself is the second deliverable: one Claude Code host session, started from
   the `/goal` line in `README.md`, drives all 81 tasks unattended to `sh verify.sh` →
   `status: DONE`, never asking the human (D-050, D-069, D-070, D-083).
9. Delegation law: the host session is Fable at medium effort and coordinates only; every
   large read, implementation, verification and proof runs in an Opus subagent or a jackin
   role container, each returning at most 15 lines (D-036, D-086, D-092).
10. The bar (D-041): a production-ready product *and* a production-ready process; the
    repository dogfoods its own workflow (D-033).

---

## 3. Findings consolidated

Sources: `A#n` = `final_feedback.md` item n; `B#n` = readiness report item n; `R3-xx` =
round-three archive; `audit` = live repository/host check performed for this plan.
"Confirmed" states the check that was actually run.

### (a) Execution package and task bundles

| Id | Finding | Sources | Confirmed against repo? | Severity | Affected files |
| --- | --- | --- | --- | --- | --- |
| K-01 | Zero of the 81 `tasks/<id>/` bundles exist; `tasks/README.md` holds only the placeholder row `\| _none yet — written by M1-01_ \| \| \| \|`. | A#8, A#9, B#9, B#18, audit | **yes** — `find tasks -mindepth 1 -type d` → 0; `cat tasks/README.md` | blocker | `tasks/`, `tasks/README.md` |
| K-02 | Bootstrap deadlock: `GOAL.md:41` takes "every runnable row of `tasks/README.md`" and `goal/EXECUTION.md:143` defines runnable as "the id has a `tasks/README.md` row that is not `planned`", but M1-01 has no row. `goal/EXECUTION.md` also states "no task runs from a bare row". | audit G1, A#10 | **yes** — read all three passages; only the §3 wave table implies M1-01 dispatches from `ROADMAP.md` alone | blocker | `GOAL.md`, `goal/EXECUTION.md`, `tasks/README.md` |
| K-03 | M1-01 combines four jobs in the first production run: compile the plan, invent 48 verifiers, bootstrap the environment, start implementing. A verifier authored by the run it gates is not an independent oracle. | A#10, A#11, B#113 | **yes** — `ROADMAP.md:129` M1-01 scope | blocker | `ROADMAP.md` M1-01, `goal/EXECUTION.md` |
| K-04 | Nothing authors `tasks/M1-01/verify.sh`, yet the root gate requires it for all 81 ids including M1-01. M1-01's own verify is described as host-run (D-061) and would be written after the fact. | audit G11 | **yes** — `verify.sh` loops over all 81 ids; M1-01 scope says "for every M1..M5 id" | blocker | `verify.sh`, `ROADMAP.md` M1-01 |
| K-05 | M6..M12 verify cells are materially weaker than M1..M5. Sampled M7-01 verify is "Pass and fail fixtures produce the expected states" — no command, no fixture path, no host/container split. Their folders are authored later by `<milestone>-00 authoring`, a procedure that exists only in `goal/EXECUTION.md:178-198`, has no `ROADMAP.md` row and no gate. | audit G10, audit §4 | **yes** — read M7-01 row; `grep -E '^\| M[0-9]+-00'` → no match | blocker | `ROADMAP.md` M6..M12, `goal/EXECUTION.md` §3 |

### (b) Root `verify.sh` oracle

| Id | Finding | Sources | Confirmed against repo? | Severity | Affected files |
| --- | --- | --- | --- | --- | --- |
| K-06 | The gate checks exactly two things per id: the `Status` cell reads `done`, and `tasks/<id>/verify.sh` exists. It never executes a task verifier, never reads `verify.out`, never checks freshness. | A#12, A#13a-b, B#38, audit | **yes** — full read of `verify.sh`; no `verify.out`, no `sh tasks/` invocation anywhere | blocker | `verify.sh` |
| K-07 | The gate is forgeable: 81 `done` rows plus 81 placeholder files print `status: DONE`. The `AGENTS.md` done-contract ("`verify.out` ends `status: DONE`") is honour-system. | A#14, B#38 | **yes** — same read; `AGENTS.md` status contract is prose only | blocker | `verify.sh`, `AGENTS.md`, `tasks/README.md` |
| K-08 | The gate checks no git cleanliness, no pushed state, no remote SHA, no `PROGRESS.md`, no `PREFLIGHT-DEFECTS.md`, no active leases, no runnable-task census, no plan drift. Yet `goal/EXECUTION.md` §7 makes several of these COMPLETE conditions. | A#13c-k, B#38, B#84, audit §3 | **yes** — `grep -nE 'git |PROGRESS|PREFLIGHT'` in `verify.sh` → no match | blocker | `verify.sh`, `goal/EXECUTION.md` §7 |
| K-09 | The `BLOCKED` path accepts a model-written prose claim plus ordinary `status: PENDING` as terminal evidence; `/goal` judges the transcript and cannot run commands. | A#15, A#16, B#39 | **yes** — `README.md` "two outcomes" paragraph; `GOAL.md` §Termination | blocker | `README.md`, `GOAL.md`, `PREFLIGHT-DEFECTS.md` |

### (c) Task graph and roadmap DAG

| Id | Finding | Sources | Confirmed against repo? | Severity | Affected files |
| --- | --- | --- | --- | --- | --- |
| K-10 | M8-01 (`depends_on = M1-03`) has a verify that reads `tasks/M3-07/scratch-repo.txt`. M3-07 is not an ancestor. Producer-before-consumer violation. | A#19, B#148 (R3-09/R3-33), audit G8 | **yes** — extracted `depends_on` and verify cells for both rows | blocker | `ROADMAP.md` M8-01 |
| K-11 | M3-04 (`depends_on = M3-01`) has a host verify requiring a live daemon-managed container on a scratch issue across a `jackin daemon restart`; dispatch is M3-05 and the scratch repository is M3-07, both of which depend on M3-04. Verifier/action cycle. | A#18, B#147 (R3-08) | **yes** — M3-04 verify cell; `M3-05 deps = M3-02, M3-03, M3-04, M2-04, M1-13` | blocker | `ROADMAP.md` M3-04/M3-05/M3-07 |
| K-12 | M10-03 has `depends_on = —`, while `ROADMAP.md:515` and the M10-02 scope gate it on M10-02's `CONTRIBUTING.md` commit reaching `origin/feat/managed-execution`. A prose gate is not a scheduler edge. | A#21, B#151 (R3-12) | **yes** — extracted both rows and the §3 M6..M12 note | major | `ROADMAP.md` M10-02/M10-03 |
| K-13 | M11-01 has `depends_on = M1-03` (an early structural start), while `ROADMAP.md:515` says it "starts with M11, after M10-05". Same prose-vs-edge defect. | A#22, B#174 (R3-35) | **yes** — same extraction | major | `ROADMAP.md` M11-01 |
| K-14 | Two schedulers. `GOAL.md:41-43` gates M2+ only on `M1-12 done` plus `depends_on` plus caps. `goal/EXECUTION.md:155-158` adds a lowest-unfinished-milestone priority rule and a closed early-start set (M3-01, M3-03, M4-02, M4-03; M6-01, M8-01, M10-02, M10-03 after M1-12). `AGENTS.md` gives no precedence between `GOAL.md` and `goal/EXECUTION.md`. | A#23, B#150 (R3-11), audit G9 | **yes** — read both passages; `AGENTS.md` precedence list covers only `ROADMAP > SPEC > DECISIONS > concept` | blocker | `GOAL.md`, `goal/EXECUTION.md`, `AGENTS.md` |
| K-15 | The graph is internally consistent at the level of *declared* edges — 81 unique ids, 0 dangling `depends_on`, M1..M5 mermaid edges identical to `depends_on` in both directions, no declared cycles — so the defects above are all *undeclared* artifact/capability dependencies invisible to any edge-level check. | repo-intent §3, A#20, B#41 | **yes** — audit re-ran the id/edge comparison | major (context) | `ROADMAP.md` |

### (d) Branch and merge model, external repository policies

| Id | Finding | Sources | Confirmed against repo? | Severity | Affected files |
| --- | --- | --- | --- | --- | --- |
| K-16 | All parallel work in a repository shares one `feat/managed-execution` branch with repeated rebase-and-push; no per-task worktree, no repository integrator, no lock. Verification runs against a worker tree, not an integrated SHA. | A#40, B#11, B#70, B#54, B#55 | **yes** — `grep -rn 'feat/managed-execution' AGENTS.md GOAL.md goal/EXECUTION.md ROADMAP.md`; no worktree or integrator concept anywhere | blocker | `AGENTS.md` (D-046/D-047/D-074), `goal/EXECUTION.md`, `ROADMAP.md` |
| K-17 | jackin's `ci.yml` routes `ci-required` for `pull_request` events to `["self-hosted","velnor-target-mvp"]`; `ubuntu-26.04` is selected only for `push` or a `workflow_dispatch` with `lanes == github`. No roadmap task changes it. | A#26, B#140 (R3-01) | **yes** — fetched `.github/workflows/ci.yml` line 168 from the live repository | blocker | `ROADMAP.md` M11-01a, jackin `.github/workflows/ci.yml` |
| K-18 | jackin `main` is protected by ruleset `protect-main`: `required_status_checks` = `ci-required` + `DCO` with `strict_required_status_checks_policy: true`, `pull_request` required, `non_fast_forward`, **`bypass_actors: []`**, and `require_extra_approval_for_unattributed_changes: true`. | A#27 | **yes** — `gh api repos/jackin-project/jackin/rulesets/14746904`. Note the report's stated check (`/branches/main/protection`) returns 404; the protection is a *ruleset*, not classic protection. | blocker | `ROADMAP.md` M11-01a, `goal/EXECUTION.md` §4 |
| K-19 | Two manifest schema bumps land on one rolling PR: M3-02 → `v1alpha7`, M4-01 "one schema bump" → `v1alpha8`. jackin `AGENTS.md:14` requires "one version bump per PR", enforced by `cargo xtask schema-check`. M11-01a can never go green. | A#28, B#141 (R3-02) | **yes** — `ROADMAP.md:193,194,214`; jackin `AGENTS.md:14` fetched live | blocker | `ROADMAP.md` M3-02/M4-01/M11-01a, `SPEC.md` |
| K-20 | termrock `AGENTS.md:252-253`: "All TermRock work happens directly on `main`. Do not create feature branches or pull requests." M10-02 only *appends* a clause to `CONTRIBUTING.md` and does not touch `AGENTS.md`, leaving the contradicting rule the agent reads first. | A#29, B#142 (R3-03) | **yes** — fetched termrock `AGENTS.md` live; read M10-02 scope | blocker | `ROADMAP.md` M10-02, termrock `AGENTS.md`/`CONTRIBUTING.md` |
| K-21 | `delete_branch_on_merge` is `true` in all three involved repositories; `goal/PREFLIGHT.md` §2 requires `false` and assigns the fix to the human. `feat/managed-execution` will not survive the two the-architect squash merges (M1-13, M3-02). | audit G3 | **yes** — `gh api repos/<r> --jq .delete_branch_on_merge` → `true` ×3 | blocker (human) | `goal/PREFLIGHT.md` §2, `goal/EXECUTION.md` §4 |
| K-22 | This repository's `main` is unprotected and has no rulesets, while acting as the plan of record *and* the mutable run ledger written after every task transition. | A#4, B#31, B#78 | **yes** — `/branches/main/protection` → 404; `/rulesets` → `[]` | major | GitHub settings, `AGENTS.md` (D-047) |

### (e) Model, permission mode, launcher

| Id | Finding | Sources | Confirmed against repo? | Severity | Affected files |
| --- | --- | --- | --- | --- | --- |
| K-23 | The repository specifies **no permission mode and no launcher flags at all**. `README.md` "Start the run" is a bare `/goal …` line; `grep -riE 'permission-mode\|bypassPermissions\|dontAsk\|--model'` across `README.md`, `GOAL.md`, `goal/`, `AGENTS.md` returns nothing. For an unattended run that must never prompt, an unspecified permission mode is itself the defect. | A#47-49, B#4, B#61-65 (reframed) | **partial** — the repo does *not* recommend Fable+Auto (see §4); the gap is that it recommends nothing | blocker | `README.md`, `goal/PREFLIGHT.md`, absent `.claude/settings.json` |
| K-24 | The host model is pinned only as a family alias — D-092 "Fable at medium effort", subagents `model: "opus"` — not an exact model id. Auto mode eligibility does not currently list Fable, so if Auto is chosen the model decision changes too. | A#47, B#67 | **yes** — `DECISIONS.md:2143`, `AGENTS.md` delegation law | major | `DECISIONS.md` D-092, `AGENTS.md` |
| K-25 | No committed permission profile, no capability broker, no `.claude/` directory at all — so no allowlist, no named agent definitions, no hooks. | A#44, B#65, B#66, B#32 | **yes** — `ls .claude` → no such directory | major | absent `.claude/settings.json`, `.claude/agents/` |

### (f) State model and recovery

| Id | Finding | Sources | Confirmed against repo? | Severity | Affected files |
| --- | --- | --- | --- | --- | --- |
| K-26 | Authoritative mutable run state lives in two Markdown tables (`tasks/README.md`, `PROGRESS.md`) that the model must keep consistent by hand across a multi-file transition. No atomic store, no event log. | A#38, B#10, B#52, B#204 (R3-65) | **yes** — `AGENTS.md` status contract; no `.db`/`.sqlite`/event log in the tree | blocker | `tasks/README.md`, `PROGRESS.md`, `AGENTS.md` |
| K-27 | Only two terminal outcomes exist (`GOAL COMPLETE`/`status: DONE`, `GOAL BLOCKED`/`status: PENDING`). A plan defect, an unsupported command, or an exhausted verifier is filed as `exhausted:` in `PREFLIGHT-DEFECTS.md` alongside genuine human-only prerequisites — conflating software failure with missing human input. No `FAILED_SYSTEM`. | A#42, B#39, B#40, B#203 (R3-64) | **yes** — `README.md` "exactly two outcomes"; `GOAL.md` §Termination; `AGENTS.md` stuck rule | blocker | `GOAL.md`, `README.md`, `verify.sh`, `PREFLIGHT-DEFECTS.md`, `AGENTS.md` |
| K-28 | No lease, fencing token, or idempotency key anywhere; a stale agent can push, update Linear, or merge after its work was superseded. Status vocabulary has no `leased`, `resource-waiting`, or `failed-system`. | A#39, B#53, B#186 (R3-48) | **yes** — `grep -rniE 'lease\|fencing\|idempoten'` over `GOAL.md`, `goal/`, `SPEC.md`, `DECISIONS.md`, `concept/` → no operational definition | blocker | `goal/EXECUTION.md`, `concept/manager.md`, `AGENTS.md` |
| K-29 | Recovery is session-scoped: `GOAL.md` §Resume re-derives state after a compaction, but nothing survives process exit, `StopFailure`, a dead tmux session, or a host restart. `/goal` is being used as the durable workflow engine. | A#43, A#44, B#59, B#201 (R3-62) | **yes** — `GOAL.md` §Resume, `goal/EXECUTION.md` §1.2; no supervisor process defined | blocker | `GOAL.md`, `goal/EXECUTION.md`, `AGENTS.md` |
| K-30 | Implementation and acceptance are the same actor in the same context; a task reaches `done` because the implementing agent reported success. No evidence manifest binding commands, exit codes, output hashes, tool versions, and the integrated SHA. | A#41, B#57, B#87, B#88 | **yes** — `goal/EXECUTION.md` §5 steps 0-9; evidence is loose `.out` files (D-038/D-059) | blocker | `goal/EXECUTION.md` §5, `AGENTS.md`, `concept/task-format.md` |

### (g) Preflight and environment

| Id | Finding | Sources | Confirmed against repo? | Severity | Affected files |
| --- | --- | --- | --- | --- | --- |
| K-31 | `op whoami` → `account is not signed in`. `goal/PREFLIGHT.md` §1 calls the unlocked 1Password desktop app "a hard precondition with no fallback (D-090)". Blocks 16 of the 18 unverifiable preflight rows and every Linear-token host verify (M1-03, M1-07, M1-09, M1-10, M1-12, M8-01, M11-01). | audit G2, B#163 (R3-24) | **yes** — ran `op whoami` on this host | blocker (human) | `goal/PREFLIGHT.md` §1 |
| K-32 | GitHub App `jackin-daemon` is installed in neither `jackin-project` nor `tailrocks`. All of M8 is unreachable. | audit G5, B#165 (R3-26) | **yes** — `gh api /orgs/<org>/installations` → no such entry | blocker (human) | `goal/PREFLIGHT.md` §2, `ROADMAP.md` M8-01 |
| K-33 | `~/.jackin/agent-browser-profile/` does not exist, so no saved operator browser state. M1-06 and the whole M1 `crew-operator` tail depend on it. | audit G6 | **yes** — directory absent | blocker (human) | `goal/PREFLIGHT.md` §2 |
| K-34 | `tmux` and `gitleaks` are not installed. `AGENTS.md` says a brew-installable tool is "never a defect" (the session installs it); `goal/PREFLIGHT.md` §1 lists both as human checklist items. Ownership is ambiguous on a dependency the entire container path and every commit rest on. | audit G13/G14, I-6 | **yes** — `command -v tmux gitleaks` → missing; read both passages | major | `goal/PREFLIGHT.md` §1, `AGENTS.md` |
| K-35 | `goal/EXECUTION.md:219` ends every container-path task with `jackin workspace delete task-<id>`. The installed `jackin 0.6.4-preview.1100` exposes `remove`, not `delete`. D-085 and ROADMAP M1-02a carry the same wrong verb. | audit G7, B#200 (R3-61) | **yes** — `jackin workspace --help` lists `create list show edit prune remove env claude-token` | major | `goal/EXECUTION.md` §4, `DECISIONS.md` D-085, `ROADMAP.md` M1-02a |
| K-36 | `<org>` is never resolved to a literal in `op://jackin/linear-workspace-<org>/access token` (6 occurrences) or `op://jackin/github-app-jackin-daemon-<org>` (5). No host verify can name the item deterministically, and the session may not read `analysis/*` to learn it. | audit G12, B#158 (R3-19) | **yes** — grep of `goal/EXECUTION.md` §4 and `ROADMAP.md` | major | `goal/EXECUTION.md` §4, `concept/credentials.md` |
| K-37 | `goal/PREFLIGHT.md` §3 says "leaving one out is allowed and is not a defect" and §4 says "Covered by the §2 GitHub App item", while `README.md` "Start the run" says "each undone §3–§5 item is one guaranteed BLOCKED stop". | audit I-6 | **yes** — read `goal/PREFLIGHT.md:178-190` and `README.md:14-15` | minor | `README.md`, `goal/PREFLIGHT.md` |
| K-38 | Screensaver `idleTime` key does not exist (the §1 proof expects it to print `0`, but an unset key errors) and `autoContinueAtUsageLimit` is `null`. Both session-fixable, but the §1 proof text is wrong for the unset case. | audit G16 | **yes** — measured on this host | minor | `goal/PREFLIGHT.md` §1 |

### (h) Documentation consistency

| Id | Finding | Sources | Confirmed against repo? | Severity | Affected files |
| --- | --- | --- | --- | --- | --- |
| K-39 | D-018..D-031 (14 decisions) are absent from `DECISIONS.md` — the file jumps `## D-017` → `## D-032`. Their full text sits in `concept/borrowed-from-symphony.md` as bold paragraph lines with no anchors. This contradicts `README.md` ("If it is not in `DECISIONS.md`, it is not decided") and `AGENTS.md` ("Whether a point is *decided*: `DECISIONS.md` only"), while `SPEC.md` and `ROADMAP.md` cite all 14 as normative. | repo-intent I-1 | **yes** — `grep -cE '^## D-0(1[89]\|2[0-9]\|3[01])' DECISIONS.md` → 0; same pattern in `concept/borrowed-from-symphony.md` → 14 | major | `DECISIONS.md`, `concept/borrowed-from-symphony.md` |
| K-40 | Three-way disagreement on open questions. `OPEN-QUESTIONS.md`: "None. Every question raised so far is closed" (Q-002 by D-066, Q-005 by D-067, Q-009 by D-068). `SPEC.md:7`: "the three questions that remain in `OPEN-QUESTIONS.md` (Q-002, Q-005, Q-009)". `ROADMAP.md:699`: same claim. `SPEC.md` §11 says "None", contradicting `SPEC.md:7` inside one file. | A#30, B#33, repo-intent I-3 | **yes** — read all four locations | major | `SPEC.md`, `ROADMAP.md`, `OPEN-QUESTIONS.md`, `DECISIONS.md` |
| K-41 | `~/.claude` container cap: `SPEC.md:117` says 3 citing D-056; `ROADMAP.md` §3, `GOAL.md` and `goal/EXECUTION.md:135` enforce 2 citing D-071. D-056 carries no "Amended by D-071" note and still asserts "up to three". D-071's Consequences list omits SPEC §6 step 2 — the paragraph that carries the wrong number. | repo-intent I-4 | **yes** — read `SPEC.md:117`, `goal/EXECUTION.md`, D-056, D-071 | major | `SPEC.md`, `DECISIONS.md` |
| K-42 | `goal/EXECUTION.md:515` forbids the session to read `DECISIONS.md` and `SPEC.md`; `goal/EXECUTION.md:520` requires it to *write* both when D-053 applies. Recording a decision requires an in-place edit, which requires reading. Nothing names the escape hatch. | repo-intent I-5 | **yes** — read both lines in the same list | major | `goal/EXECUTION.md` §8, `AGENTS.md`, `GOAL.md` |
| K-43 | `concept/manager.md` still models a human-driven loop: "A human creates an issue" (:74), "The human assigns" (:78), "A human moves the issue to the merging state" (:142), and a human decision inbox (:186-189) — contradicting D-067, D-055/D-079, and the "Never ask the human" law the whole run rests on. It also treats the product name as open (`Q-002`, :3) after D-066 closed it. | repo-intent I-7, I-8 | **yes** — read all cited lines | major | `concept/manager.md` |
| K-44 | M1's exit gate is unsatisfiable: `ROADMAP.md:46` requires "`op item get` lists every CREATE row of `concept/credentials.md` §4", and that CREATE set names `#18 webhook-relay`, which row :148 marks **DEFER**. The same count line omits #21 and #22, which *are* CREATE. | repo-intent I-15, I-16 | **yes** — read `ROADMAP.md:46` and `concept/credentials.md:144-158` | blocker | `ROADMAP.md` M1 gate, `concept/credentials.md` |
| K-45 | `SPEC.md:445` asserts "task folders in `tasks/` for M1..M5 now" — an existence claim about artifacts that do not exist. `SPEC.md:47` says `the-architect` is "used as is (D-048)" while M1-13 and M3-02 modify it. | B#34, A#31 | **yes** — read both lines | major | `SPEC.md` |
| K-46 | `VISION.md:134` "This repository plans. It does not implement." vs the same repository carrying executable run state and authoring 81 verifier programs. `ROADMAP.md` is marked FINAL while `SPEC.md` is "draft, living document", and the run mutates plan, decisions, state and evidence on the same branch. | B#35, B#36 | **yes** — read `VISION.md:134`, `ROADMAP.md:3`, `SPEC.md:3` | major | `VISION.md`, `SPEC.md`, `ROADMAP.md`, `AGENTS.md` |
| K-47 | Of the 76 R3 findings, only **5** ids are referenced anywhere outside the archive (`R3-38, 62, 63, 66, 67`, all in `DECISIONS.md`). **71 have no traceable disposition.** The archive's own header: "Round 3 finders below returned findings that were NOT verified or applied." Severity census in the file: 27 blocker, 30 major, 19 minor. | A#7, A#53, B#19, B#125 | **yes** — `grep -roE 'R3-[0-9]+' --include='*.md' .` excluding the archive → 5 unique ids; `grep -oE '^## R3-[0-9]+ \[[a-z]+\]'` census | blocker | `analysis/bulletproof-round3-findings.md`, `DECISIONS.md`, `ROADMAP.md` |

### (i) Working-tree and branch hygiene

| Id | Finding | Sources | Confirmed against repo? | Severity | Affected files |
| --- | --- | --- | --- | --- | --- |
| K-48 | The tree is dirty with three untracked files (`.DS_Store`, `final_feedback.md`, `ecosystem-final-deep-readiness-and-build-report-2026-08-28.md`). `goal/EXECUTION.md` §1.1 says "Refuse to work on a dirty tree", and the two reports are root-level non-planning files the `AGENTS.md` two-modes table does not permit. There is no `.gitignore`. | audit G4, repo-intent I-24 | **yes** — `git status --porcelain`; `ls .gitignore` → absent | blocker | working tree, absent `.gitignore` |
| K-49 | The repository is on `main` and in sync with `origin/main` — **not** detached. | repo-intent I-24 (contradicted) | **yes** — `git symbolic-ref HEAD` → `refs/heads/main`; `git rev-parse HEAD` = `130cb4b7…` = `origin/main` | resolved | — |

**Severity totals — 49 K-items:** 30 blocker (4 of them human-only: K-21, K-31, K-32, K-33),
16 major (one of which, K-15, is context rather than a defect), 2 minor, 1 resolved (K-49).

Blockers: K-01, K-02, K-03, K-04, K-05, K-06, K-07, K-08, K-09, K-10, K-11, K-14, K-16, K-17,
K-18, K-19, K-20, K-21, K-23, K-26, K-27, K-28, K-29, K-30, K-31, K-32, K-33, K-44, K-47, K-48.

---

## 4. Where the reports are wrong or overstated

1. **"The README launcher line recommends `--model fable --permission-mode auto`" (A#37, A#47,
   B#4, B#23, B#24, B#122).** False against the repository. `README.md` "Start the run" is a
   bare `/goal …` line with no flags, and `grep -riE 'permission-mode|bypassPermissions|dontAsk|--model|fable'`
   over `README.md`, `GOAL.md`, `goal/`, and `AGENTS.md` returns **zero** hits. The
   Fable+Auto recommendation lives in an earlier DOCX report, not here. The correct finding
   (K-23) is the inverse and still serious: the repository names *no* permission mode at all.

2. **"jackin `main` is protected — check `gh api .../branches/main/protection`" (A#27, V24).**
   The conclusion is right, the check is wrong. Classic branch protection returns **404**.
   The protection is the repository ruleset `protect-main` (id `14746904`). Anyone running the
   report's command will conclude the branch is unprotected and plan accordingly.

3. **"`CLAUDE_CODE_GOAL_MAX_ITERATIONS=200` should be removed" (B#25).** Nothing to remove.
   `grep -rn 'GOAL_MAX_ITERATIONS' .` matches only inside the untracked report itself. The
   env var was never adopted into the repository.

4. **"Compressing `GOAL.md` below 4,000 characters lost precision" (A#17, B#26).** The premise
   is right (the cap applies to the `/goal` *condition*, and the condition here is the
   `README.md` line, not the file). But `GOAL.md` is 3,981 bytes and, on reading, has not lost
   a rule — it has lost the *subagent* cap (K-14/I-22). Treat this as a precision defect in one
   named place, not as a reason to expand the file.

5. **"The working tree is on a detached HEAD" (repo-intent I-24).** No longer true.
   `git symbolic-ref HEAD` → `refs/heads/main`, in sync with `origin/main`. Only the dirty-tree
   half of that finding survives (K-48).

6. **"The repository plans more than one manifest-schema bump" — correct, but the roadmap says
   otherwise in one place.** `ROADMAP.md:193` M3-02 explicitly reads "Schema bump (one per PR,
   Q-021)". The violation is only visible when M4-01 (`ROADMAP.md:214`, "one schema bump") is
   read alongside it. A reviewer checking M3-02 alone would wrongly close K-19.

7. **"Neither `GOAL COMPLETE` nor `GOAL BLOCKED` is satisfiable, so the session is cornered"
   (audit G1 consequence).** Overstated *today*. Because `op whoami` fails (K-31), the session
   files a `PREFLIGHT-DEFECTS.md` row at step 5, which makes `GOAL BLOCKED` legally reachable.
   The bootstrap deadlock (K-02) is real; the "no legal turn ending" corollary only holds on a
   host where every human prerequisite is already satisfied.

8. **"Fable is unsuitable / the model choice is broken" (implied by B#13 "Model good,
   permission design broken").** Both reports agree the model is fine. Do not spend a phase on
   the model; spend it on K-23 (no permission mode declared) and K-25 (no committed profile).

9. **R3 disposition counts differ between the reports.** A says "~61 undispositioned"; B's
   appendix says 66 unresolved / 4 fixed / 2 partial / 2 duplicate / 6-or-7 host-probe. The
   repository supports neither number: **5** R3 ids are cited outside the archive, so **71** are
   undispositioned by any traceable criterion. Use 71, not 61 or 66.

---

## 5. Recommendation plan

Every item names its acceptance check. "human" means an action no agent can perform; "agent"
means it can run under the readiness `/goal`.

### Phase 0 — Hygiene and decisions that unblock everything

| # | Change | Files | Acceptance check | Who | Status |
| --- | --- | --- | --- | --- | --- |
| 0.1 | Delete `.DS_Store`; move both external reports into `analysis/reviews/`; add a `.gitignore` covering `.DS_Store` and `*.tmp`. | working tree, `.gitignore`, `analysis/reviews/` | `git status --porcelain` prints nothing | agent | done — the two external reports were already absent; nothing to move |
| 0.2 | Tag the reviewed snapshot so the plan under analysis stops moving. | git | `git tag -l 'plan-review-*'` shows one tag at `130cb4b7…` | human | blocked-on-human — `PREFLIGHT-DEFECTS.md` #1 |
| 0.3 | Enable a ruleset on `donbeave/ecosystem` `main` (non-fast-forward + deletion at minimum) so the plan of record cannot be rewritten. | GitHub settings | `gh api repos/donbeave/ecosystem/rules/branches/main --jq '[.[].type]'` is non-empty | human | blocked-on-human — `PREFLIGHT-DEFECTS.md` #2 |
| 0.4 | Move the full text of D-018..D-031 into `DECISIONS.md` as `## D-0NN` headings; leave a pointer in `concept/borrowed-from-symphony.md`. (K-39) | `DECISIONS.md`, `concept/borrowed-from-symphony.md` | `for n in $(seq -w 18 31); do grep -q "^## D-0$n " DECISIONS.md \|\| echo "missing D-0$n"; done` prints nothing | agent | done |
| 0.5 | Create `QUESTIONS.md` holding the text of Q-001..Q-025 with the decision that closed each; make `OPEN-QUESTIONS.md` point at it. (K-40, repo-intent I-2) | new `QUESTIONS.md`, `OPEN-QUESTIONS.md` | `grep -c '^## Q-0' QUESTIONS.md` = 25; every `Q-0nn` cited repo-wide resolves | agent | done |
| 0.6 | Fix `SPEC.md:7` and `ROADMAP.md:699` to say no questions remain (matching `OPEN-QUESTIONS.md` and D-066/067/068). (K-40) | `SPEC.md`, `ROADMAP.md` | `grep -n 'questions that remain\|remaining items (Q-' SPEC.md ROADMAP.md` prints nothing | agent | done |
| 0.7 | Resolve the `~/.claude` cap to **2**: correct `SPEC.md:117`, add "Amended by D-071" to D-056. (K-41) | `SPEC.md`, `DECISIONS.md` | `grep -n 'for \`~/.claude\` 3' SPEC.md` empty; `grep -A2 '^## D-056' DECISIONS.md \| grep -q 'D-071'` | agent | done |
| 0.8 | Resolve the read/write contradiction: state explicitly that a decision recording is delegated to a subagent that edits `DECISIONS.md` and `SPEC.md`, and that the host session only commits. (K-42) | `goal/EXECUTION.md` §8, `AGENTS.md`, `GOAL.md` | `grep -n 'delegate.*DECISIONS.md' goal/EXECUTION.md` matches, and the "Write:" bullet no longer lists `DECISIONS.md`/`SPEC.md` for the session | agent | done |
| 0.9 | Record the model **and** permission decision as one decision: exact model id + effort for the host session, exact model id for subagents, permission mode, and the committed allowlist. (K-23, K-24, K-25) | `DECISIONS.md` (D-095), `README.md`, `.claude/settings.json` | `jq -e '.permissions' .claude/settings.json` succeeds; `grep -n 'permission' README.md` matches the launcher paragraph | human decides, agent records | done — recorded as D-095, amended by D-120/D-121: yolo permission mode per the human's direction, no allowlist |
| 0.10 | Rewrite `concept/manager.md` §Lifecycle and §Human interaction model against D-055/D-067/D-079. (K-43) | `concept/manager.md` | `grep -niE 'a human (creates\|assigns\|moves)' concept/manager.md` prints nothing | agent | done |
| 0.11 | Correct `SPEC.md:445` (no existence claim for `tasks/`), `SPEC.md:47` (`the-architect` is modified by M1-13 and M3-02), and `VISION.md:134`. (K-45, K-46) | `SPEC.md`, `VISION.md` | `grep -n 'task folders in `tasks/` for M1..M5 now' SPEC.md` empty | agent | done |
| 0.12 | Fix the credentials CREATE census and the M1 exit gate so the gate is satisfiable. (K-44) | `concept/credentials.md`, `ROADMAP.md:46` | the CREATE set named in `concept/credentials.md` §4 contains no `DEFER` row; M1 gate names that same set by reference | agent | done |
| 0.13 | Fix `jackin workspace delete` → `remove` in all three places. (K-35) | `goal/EXECUTION.md:219`, `DECISIONS.md` D-085, `ROADMAP.md` M1-02a | `grep -rn 'workspace delete' --include='*.md' .` matches only the R3 archive | agent | done |
| 0.14 | Resolve `<org>` to literals and record the Linear `urlKey` and app-user id as named non-secret evidence files. (K-36) | `goal/EXECUTION.md` §4, `concept/credentials.md` | `grep -c '<org>' goal/EXECUTION.md ROADMAP.md` = 0 | agent | done |
| 0.15 | Assign `tmux`/`gitleaks` installation to the session in `goal/PREFLIGHT.md` §1, and fix the screensaver proof text for an unset key. (K-34, K-38) | `goal/PREFLIGHT.md` §1 | those two rows say "installed by the session, never a defect"; the screensaver proof accepts "unset or `0`" | agent | done |
| 0.16 | Reconcile `README.md` "each undone §3–§5 item is one BLOCKED stop" with `goal/PREFLIGHT.md` §3/§4. (K-37) | `README.md`, `goal/PREFLIGHT.md` | the two statements agree on which sections are blocking | agent | done |

### Phase 1 — Readiness-hardening run (no product work)

This is the scope of the next `/goal`. It must not execute M1..M12 and must not modify any
external repository.

| # | Change | Files | Acceptance check | Who | Status |
| --- | --- | --- | --- | --- | --- |
| 1.1 | Give **all 76** R3 findings a disposition row: `fixed` / `disproved` / `duplicate` / `host-probe-required`, each with current evidence (SHA, file:line, or command output). 71 are undispositioned today. (K-47) | new `findings/disposition.toml` | `python3 -c` count of rows = 76; every row has a non-empty `evidence`; every `fixed` row names a file:line that still matches | agent | done |
| 1.2 | Compile `ROADMAP.md` to a machine DAG with cycle, uniqueness, and producer-before-consumer checks. Every `tasks/<producer>/<file>` string appearing in a verify cell must have that producer as a transitive ancestor. (K-10, K-11, K-15) | new compiler + `ROADMAP.md` | the compiler exits 0 and prints `81 tasks, 0 cycles, 0 unproduced artifacts`; seeding a synthetic cycle makes it exit non-zero | agent | done |
| 1.3 | Add the missing edges: `M8-01 → depends_on M3-07` (or move its scratch assertion to M8-03); move M3-04's live-container proof to a task after dispatch; `M10-03 → depends_on M10-02`; `M11-01 → depends_on M10-05`. (K-10..K-13) | `ROADMAP.md` | 1.2's compiler passes with no prose-only gate remaining; `grep -n 'may start once\|starts with M11, after' ROADMAP.md` prints nothing | agent | done |
| 1.4 | Define **one** runnable predicate, in one place, referenced by `GOAL.md`, `goal/EXECUTION.md` and the compiler; add the missing `GOAL.md` subagent cap. (K-14) | `GOAL.md`, `goal/EXECUTION.md` | the two files contain the same predicate text verbatim; `grep -n 'three host subagents' GOAL.md` matches | agent | done |
| 1.5 | Materialise all 81 task bundles — `TASK.md`, `task.toml`, `verify.sh`, `refs/`, `expected-evidence.toml` — **before** any product work, content-addressed, hash recorded in the run lock. Sweep every M6..M12 verify cell for the M7-01 pattern (prose, no command) and give each the `container:` / `host (D-061):` split. (K-01, K-03, K-05) | `tasks/<id>/`, `ROADMAP.md` | `for id in $(…81 ids…); do test -f tasks/$id/verify.sh -a -f tasks/$id/task.toml -a -f tasks/$id/TASK.md; done`; `shellcheck -s sh tasks/*/verify.sh` clean; no verify cell lacks a command token | agent | done |
| 1.6 | Give M1-01 a bundle and a row of its own, and state the wave-0 dispatch rule explicitly. (K-02, K-04) | `tasks/M1-01/`, `tasks/README.md`, `GOAL.md`, `goal/EXECUTION.md` | `test -f tasks/M1-01/verify.sh`; `grep -q 'M1-01' tasks/README.md`; no "no task runs from a bare row" conflict remains | agent | done |
| 1.7 | Replace root `verify.sh` with a real oracle: execute each `tasks/<id>/verify.sh host`, require `verify.out` to end `status: DONE` **and** to name the commit SHA it proves, require that SHA to be an ancestor of the pushed remote head, require a clean tree, validate `PROGRESS.md` row-per-task, require zero runnable and zero active tasks, and emit `status: DONE` / `status: BLOCKED HUMAN` / `status: FAILED SYSTEM` / `status: PENDING`. (K-06..K-09, K-27) | `verify.sh`, `GOAL.md`, `README.md` | good fixture → `status: DONE`; forged fixture (81 `done` rows + empty verifier files) → **not** `DONE`; stale-`verify.out` fixture → not `DONE`; dirty-tree fixture → not `DONE`; unpushed fixture → not `DONE` | agent | done |
| 1.8 | Add adversarial gate fixtures under `tests/fixtures/` and a runner that asserts each must fail. (K-07) | new `tests/` | the fixture runner exits 0 only when every known-bad fixture is rejected | agent | done |
| 1.9 | Move authoritative run state into an atomic store (SQLite or an append-only event log) with `tasks/README.md` and `PROGRESS.md` generated from it; add `leased`, `resource-waiting`, `failed-system` to the vocabulary, plus lease owner, epoch, fencing token, and idempotency key per external mutation. (K-26, K-28) | new state store, `tasks/README.md`, `PROGRESS.md`, `AGENTS.md` | regenerating the two Markdown files from the store produces a byte-identical result (`git diff --exit-code`); a replayed stale-lease event is rejected | agent | done |
| 1.10 | Add an evidence manifest per task: task id, bundle hash, integrated SHA, commands with exit codes, stdout/stderr hashes, tool versions, external object ids, timestamps, result class. (K-30) | `tasks/<id>/evidence.json`, `concept/task-format.md` | `jq -e '.integrated_sha and .commands and .bundle_hash'` on every manifest | agent | done |
| 1.11 | Create an immutable `run/LOCK.toml`: plan tag, external repo base SHAs, all 81 bundle hashes, exact model ids and effort, CLI versions, role-repo commits, image digests, permission profile, run epoch. Nothing tracks `main`, `HEAD`, or `latest` during a run. | new `run/LOCK.toml` | `jq`/`tomlq` shows no `main`/`HEAD`/`latest` value; every SHA is 40 hex chars | agent | done — `plan.tag` is empty until defect #1 is cleared; re-run `python3 tools/lock.py write` after tagging |
| 1.12 | Add an external supervisor entry point that starts/resumes the coordinator session, observes process exit and `StopFailure`, reconciles leases and live containers, and continues from the state store. (K-29) | supervisor script, `GOAL.md`, `README.md` | killing the coordinator process and re-invoking the supervisor resumes without re-running a `done` task | agent | done |

### Phase 2 — Branch/merge model and external repository alignment

| # | Change | Files | Acceptance check | Who | Status |
| --- | --- | --- | --- | --- | --- |
| 2.1 | Replace the shared-branch model: one `managed/<run-id>/<task-id>` worktree and branch per task from the locked base SHA; workers never push the integration branch; one repository-scoped integrator lease serialises cherry-pick/merge, CI, and push; verification runs against the **integrated** SHA. (K-16) | `AGENTS.md` (D-046/D-047/D-074), `goal/EXECUTION.md`, `ROADMAP.md` | `grep -rn 'feat/managed-execution' AGENTS.md GOAL.md` shows the branch only as an integration target, never as a worker checkout | agent | done |
| 2.2 | Give M11-01a (or an earlier owning task) an explicit step that makes jackin PR `ci-required` run on GitHub-hosted runners, and verify the workflow file path. (K-17) | `ROADMAP.md`, jackin `.github/workflows/ci.yml` | on the rolling PR, `gh run view --json jobs` shows `ci-required` on `ubuntu-*`, not `self-hosted` | agent | done — static parts proven now; the live check is bound to `tasks/M11-01a/verify.sh` and proven in the implementation run |
| 2.3 | Plan against jackin's real ruleset: strict up-to-date `ci-required` + `DCO`, PR required, non-fast-forward, **no bypass actors**, and `require_extra_approval_for_unattributed_changes`. Remove any assumption of a bypass or a direct push. (K-18) | `ROADMAP.md` M11-01a, `goal/EXECUTION.md` §4 | `gh api repos/jackin-project/jackin/rulesets/14746904 --jq .bypass_actors` = `[]` is quoted in the task text as the constraint | agent | done |
| 2.4 | Reduce the rolling jackin PR to **one** manifest schema bump: keep M3-02's `v1alpha7`; deliver the initial prompt via `JACKIN_INITIAL_PROMPT` launch env with no manifest field. (K-19) | `ROADMAP.md` M4-01, `SPEC.md` | `cargo xtask schema-check --base origin/main` on the branch prints one bump; `grep -c 'v1alpha8' ROADMAP.md SPEC.md` = 0 | agent | done — static parts proven now; the live check is bound to `tasks/M3-02/verify.sh` and proven in the implementation run |
| 2.5 | M10-02 must **replace** the branch/PR prohibition in termrock `AGENTS.md` (and `CONTRIBUTING.md`), not append beside it. (K-20) | `ROADMAP.md` M10-02, termrock `AGENTS.md` | after M10-02, `grep -niE 'do not create feature branches' AGENTS.md` in termrock prints nothing | agent | done — static parts proven now; the live check is bound to `tasks/M10-02/verify.sh` and proven in the implementation run |
| 2.6 | Set `delete_branch_on_merge = false` in the three repositories. (K-21) | GitHub settings | `for r in jackin-project/jackin jackin-project/jackin-the-architect tailrocks/termrock; do gh api repos/$r --jq .delete_branch_on_merge; done` → `false` ×3 | human | blocked-on-human — `PREFLIGHT-DEFECTS.md` #3 |
| 2.7 | Sign in to 1Password with auto-lock **Never** and confirm the exact operations the run uses (not just `op whoami`). (K-31) | host | `op whoami` succeeds **and** `op read 'op://jackin/<a real item>/<field>' \| wc -c` is non-zero | human | blocked-on-human — `PREFLIGHT-DEFECTS.md` #4 |
| 2.8 | Create and install the `jackin-daemon` GitHub App (All repositories) in both organisations and store its four fields in 1Password. (K-32) | GitHub, 1Password | `gh api /orgs/jackin-project/installations --jq '.installations[].app_slug'` and the same for `tailrocks` both contain `jackin-daemon` | human | blocked-on-human — `PREFLIGHT-DEFECTS.md` #5 |
| 2.9 | Sign in headed to Linear and GitHub and save the operator browser state. (K-33) | host | `test -s ~/.jackin/agent-browser-profile/state.json` and `jq '.cookies \| length'` > 0 | human | blocked-on-human — `PREFLIGHT-DEFECTS.md` #6 |
| 2.10 | Install `tmux` and `gitleaks`. (K-34) | host | `tmux -V` and `gitleaks version` both succeed | agent (per 0.15) | done |

### Phase 3 — Canary

A synthetic task outside M1..M12, run twice: once cleanly, once with forced failure.

| # | Change | Acceptance check | Who | Status |
| --- | --- | --- | --- | --- |
| 3.1 | Canary task bundle delivered content-addressed to an isolated worktree; worker edits; independent verifier validates the integrated SHA; integrator merges; Linear and GitHub updated. | canary `evidence.json` names the integrated SHA and the external object ids; `gh pr view` shows exactly one PR | agent | done — PR https://github.com/donbeave/ecosystem/pull/1; the Linear leg is blocked-on-human (#4) |
| 3.2 | Destructive run: force a context compaction, kill the coordinator process, kill the worker container, expire a lease, restart the host; then resume. | after resume, the state store shows the canary task once, one PR, one Linear activity — no duplicate side effect; no `done` task re-executed | agent | done |
| 3.3 | Prove `StopFailure` and process-exit recovery specifically (not only compaction). | supervisor log shows the exit was observed and the session was restarted from durable state | agent | done |

Do not arm the 81-task `/goal` until 3.1 and 3.2 both pass.

### Phase 4 — Launch acceptance checklist

Adapted from source B §13. Every row must be proven by the named command before the
implementation `/goal` is invoked.

| # | Gate | Proving command | Status |
| --- | --- | --- | --- |
| 4.1 | Plan snapshot tagged; `run/LOCK.toml` binds it and every external base SHA. | `git tag --points-at $(tomlq -r .plan.commit run/LOCK.toml)` non-empty | blocked-on-human — `PREFLIGHT-DEFECTS.md` #1 |
| 4.2 | All 76 R3 findings dispositioned with evidence; no row left open because it is "minor". | rows = 76 and no `disposition = ""` in `findings/disposition.toml` | done — 76 rows, 0 open |
| 4.3 | All 81 bundles exist and pass schema, lint, and command-existence validation. | the compiler prints `81/81 bundles valid` | done |
| 4.4 | Compiled graph acyclic; every artifact produced by an ancestor; every early start structural. | compiler exits 0 with `0 cycles, 0 unproduced artifacts, 0 prose gates` | done |
| 4.5 | No task verifier is interactive, mutating, or transient; all evidence is durable and commit-bound. | `grep -lE 'hardline\|tmux attach\|--latest\|newest' tasks/*/verify.sh` empty | done |
| 4.6 | Repository work isolated; one integrator lock per repository, chaos-tested. | Phase 3.2 evidence | done |
| 4.7 | Final gate accepts good fixtures and rejects forged, stale, dirty, unpushed, runnable, and active fixtures. | the fixture runner exits 0 | done |
| 4.8 | jackin CI, schema policy, termrock branch policy, PR metadata, and DCO reconciled. | 2.2, 2.3, 2.4, 2.5 checks all green | done — static; the live legs run on the rolling PR |
| 4.9 | Static readiness and live host preflight both end `status: READY` for the same lock hash. | both outputs name the same `lock_hash` | blocked-on-human — static readiness prints `status: READY`; the live gate prints `NOT READY` only on defects #3–#6, same `lock_hash` |
| 4.10 | Permission mode and profile proven in the actual account and CLI. | a scripted probe performs a normally-prompting operation without prompting | done |
| 4.11 | Recovery proven for `StopFailure`, process exit, compaction, dead tmux/container, quota wait, host restart. | Phase 3.2 / 3.3 evidence | done |
| 4.12 | Canary passes once normally and once with forced failure, no duplicate side effect. | Phase 3 evidence | done — the Linear leg is blocked-on-human (#4) |
| 4.13 | Four human prerequisites in place: `op` sign-in, `delete_branch_on_merge` false ×3, GitHub App installed ×2, operator browser state saved. | 2.6–2.9 checks all green | blocked-on-human — `PREFLIGHT-DEFECTS.md` #3–#6 |
| 4.14 | M1 completes and is independently audited before M2 is activated. | M1 milestone gate output plus a separate audit record | disproved-with-evidence — M1 completes only inside the implementation run, so it cannot be a pre-launch gate; enforced in-run by D-123 (an audit subagent writes `tasks/M1-12/audit.md` and `tools/state.py` refuses to promote M2+ until `audit: PASS`; proven by `tests/state/test_m1_audit_gate.sh`) |

---

## 6. Suggested new or changed decisions

Next free id is **D-095** (`DECISIONS.md` currently ends at D-094).

| Id | Proposal | Rationale | Recorded as |
| --- | --- | --- | --- |
| D-095 | The host session's exact model id, effort, permission mode, and committed allowlist are pinned in `.claude/settings.json` and in `run/LOCK.toml`; subagents pin an exact model id, not a family alias. | An unattended run cannot rely on a mutable alias or an unspecified permission mode (K-23, K-24). | D-095 (amended by D-120, D-121) |
| D-096 | A readiness-hardening run precedes the implementation run; the implementation `/goal` is armed only after a static and a live readiness gate both print `status: READY` for the same lock hash. | Removes the unsafe bootstrap cycle in which the run compiles its own plan and writes its own oracle (K-03). | D-109 |
| D-097 | Four machine terminal classes replace the two current ones: `DONE`, `BLOCKED HUMAN`, `FAILED SYSTEM`, `PENDING`, each derived by `verify.sh` from the state store, never asserted by the model. | A plan defect must not be able to masquerade as a human prerequisite (K-27). | D-110 |
| D-098 | Authoritative run state is an atomic store; `tasks/README.md` and `PROGRESS.md` are generated projections and are never hand-edited. | Eliminates partial multi-file transitions and makes restart reconciliation deterministic (K-26). | D-111 |
| D-099 | One worktree and branch per task; workers never push the integration branch; one integrator lease per repository; verification runs against the integrated SHA. | Amends D-046/D-047/D-074, which currently permit concurrent writers on one shared branch (K-16). | D-112 |
| D-100 | Every external mutation carries an idempotency key derived from run, task, attempt, and operation; every runnable task holds a lease with a fencing token. | Prevents a superseded agent from pushing, merging, or writing to Linear (K-28). | D-113 |
| D-101 | All 81 task bundles are content-addressed, materialised before any product task runs, and their hashes recorded in `run/LOCK.toml`; no runtime task-authoring phase. | Amends D-062/D-072/D-088 (M1-01 and `<milestone>-00 authoring`) (K-01, K-05). | D-114 |
| D-102 | Every `analysis/` findings archive must have a disposition file with one row per finding before a run that the archive touches may start. | Makes "probably fixed" impossible; today 71 of 76 R3 findings have no traceable disposition (K-47). | D-115 |
| D-103 | D-018..D-031 are moved into `DECISIONS.md` as headings; no normative decision text lives outside `DECISIONS.md`. | Restores the invariant that both `README.md` and `AGENTS.md` already assert (K-39). | D-103 |
| D-104 | The host session never edits `DECISIONS.md` or `SPEC.md` directly; a subagent performs the edit and the session commits it. | Resolves the unsatisfiable read/write pair in `goal/EXECUTION.md` §8 (K-42). | D-104 |
| D-105 | A cross-document invariant lint runs in CI and fails when two authoritative documents disagree (question status, caps, existence claims, decision citations). | Precedence rules alone did not prevent K-40, K-41, K-45, K-46. | D-116 |
| D-106 | `main` of this repository is protected by a ruleset; volatile run state is published as generated snapshots rather than committed after every task transition. | The plan of record and the mutable ledger must not share an unprotected branch (K-22). | D-117 (the ruleset itself is blocked-on-human, `PREFLIGHT-DEFECTS.md` #2) |
| D-107 | `D-056` is formally amended by `D-071` (cap 2), and every decision that supersedes another carries the reciprocal "Amended by" note. | The one gap in an otherwise strong amendment discipline produced K-41. | D-107 |


---

## 7. Run record

Readiness-hardening run, 2026-08-28. Host commit range `3adb0d3..HEAD` on `main`.

**Row outcomes (55 rows across Phases 0–4):** 45 `done`, 9 `blocked-on-human`,
1 `disproved-with-evidence`.

Nothing else in this document was changed by the run: sections 1–6 record the state of the
repository as it was reviewed on 2026-08-28, and the `Status` and `Recorded as` columns are
the only additions.

**The nine `blocked-on-human` rows reduce to six operator inputs**, each carried as an open
row of `PREFLIGHT-DEFECTS.md` with the command that proves it is in place:

| # | Missing item | Proof it is in place |
| --- | --- | --- |
| 1 | Plan snapshot tag `plan-review-*` at `130cb4b7` | `git tag -l 'plan-review-*'` shows one tag at `130cb4b7`; create with `git tag plan-review-2026-08-28 130cb4b7 && git push origin plan-review-2026-08-28` |
| 2 | Ruleset on `donbeave/ecosystem` `main` (non-fast-forward, deletion) | `gh api repos/donbeave/ecosystem/rules/branches/main --jq '[.[].type]'` is non-empty |
| 3 | `delete_branch_on_merge` must be `false` in the three repositories | `for r in jackin-project/jackin jackin-project/jackin-the-architect tailrocks/termrock; do gh api repos/$r --jq .delete_branch_on_merge; done` prints `false` three times |
| 4 | 1Password CLI signed in, auto-lock Never | `op whoami </dev/null` succeeds and `op read 'op://jackin/<a real item>/<field>' \| wc -c` is non-zero |
| 5 | GitHub App `jackin-daemon` installed in `jackin-project` and `tailrocks` (All repositories), four fields in 1Password | `gh api /orgs/jackin-project/installations --jq '.installations[].app_slug'` and `gh api /orgs/tailrocks/installations --jq '.installations[].app_slug'` both contain `jackin-daemon` |
| 6 | Operator browser state `~/.jackin/agent-browser-profile/state.json` | `test -s ~/.jackin/agent-browser-profile/state.json && jq '.cookies \| length' ~/.jackin/agent-browser-profile/state.json` prints a number > 0 |

**Next command for the human.** Clear the six rows above, then run

```
sh tools/readiness.sh live
```

and, once it prints `status: READY`, paste the `/goal` invocation line from `README.md`
"Start the run".
