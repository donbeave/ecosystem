# Specification — jackin managed execution

Status: **draft, living document**. This specification is improved in every
conversation that reaches agreement. It states only what is decided in
`DECISIONS.md`; undecided points are marked *open (Q-NNN)* and link to
`OPEN-QUESTIONS.md`. Proposals not yet accepted live in
`concept/borrowed-from-symphony.md` and are not part of this specification.

## 1. Purpose

The bar is a production-ready product and process for building software
with Linear + jackin (D-041).

Turn "work with an agent" into "assign an issue". A human creates a Linear
issue that names a repository, a branch, a jackin agent role, an agent
runtime, a prompt, and a checklist, then assigns it to jackin. A jackin
daemon on a host with Docker picks the issue up, prepares the branch, starts
the role in an isolated container with the prompt, mirrors the checklist
locally, pushes progress back to the issue as items complete, verifies the
result, and manages the pull request on GitHub. The human watches through
the Linear issue, the jackin terminal interface, or by attaching to the
container, and answers only when asked. (D-002, D-005, D-010..D-014)

## 2. Non-goals

- Building an agent harness. Vendor harnesses (Claude Code, Codex, Amp,
  Kimi, OpenCode, Grok) are used as shipped. (D-015)
- Redesigning jackin's interactive commands. They stay unchanged; the daemon
  is additive. (D-009)
- Any task source other than Linear. GitHub hosts repositories and pull
  requests only. (D-010, D-014)
- Multi-host operation in the first prototype. (D-017)

## 3. Components

| Component | Responsibility | Status |
| --- | --- | --- |
| Linear | Source of truth for issues, their fields, status, comments, and agent sessions. | exists |
| GitHub | Hosts repositories and pull requests. | exists |
| jackin CLI | Interactive sessions; unchanged. | exists |
| jackin daemon | Long-running per host. Monitors every agent container on the host (CLI- or daemon-started); listens to Linear for issues assigned to jackin; prepares workspaces; spawns roles through the same container mechanism as the CLI; pushes progress; runs verification; manages pull requests. | to build (D-008, D-009) |
| jackin capsule | In-container PID 1; the attach point for live visibility. | exists (D-016) |
| jackin agent roles | Dockerfile + `jackin.role.toml`: environment, skills, plugins. Selected per issue. jackin development itself always uses `jackin-the-architect` (D-048); other work uses new `donbeave` roles (D-045, set pending). | exists (D-012) |
| termrock TUI | Fleet, issue, log, and attach surface for the daemon. | to build (D-006) |

Placement of the manager logic (in the daemon binary or beside it) is
*open (Q-001)*.

## 4. Issue contract

An issue that jackin executes must define:

| Field | Required | Meaning |
| --- | --- | --- |
| repository | yes | GitHub repository the work is done in. (D-014) |
| branch | yes | Branch to work on. Reused (pulled) if it exists on the remote; created otherwise. (D-014) |
| base branch | no, default `main` | Where a new branch is created from. (D-014) |
| role | yes | jackin agent role to spawn, resolvable by name to a published image. (D-012) |
| runtime | yes | Agent runtime inside the role. (D-012) |
| model | yes, lane default if absent | Model the runtime uses. (D-043) |
| effort | yes, default medium | Reasoning effort level. (D-043) |
| prompt | yes | Text passed to the agent. (D-012) |
| delivery | no, default `goal` | `goal` = deliver as `/goal <prompt>` (iterate until verified); `prompt` = plain first message. (D-044) |
| checklist | yes | Markdown task list of the work; the unit of progress. (D-013) |
| references | recommended | Schemas, contracts, designs the result must satisfy. (D-003) |
| verification | recommended | Executable check whose last line `status: DONE` is the only proof of completion. (D-003) |
| dependencies | when relevant | Linear blocking relations. (D-004) |

How each field is expressed on a Linear issue is *open (Q-013)*. A missing
required field is a validation failure reported on the issue; the issue is
not started.

## 5. Trigger

Assignment of the issue to the jackin Linear agent app (scope
`app:assignable`) starts work. Creation alone does not. (D-011) The event
path for a daemon behind NAT is *open (Q-015)*; direct webhooks to the
laptop are excluded for the prototype. (D-017)

## 6. Execution

1. The daemon validates the issue contract (section 4).
2. The daemon prepares the workspace: clone or reuse the repository, pull
   and reuse the branch if it exists on the remote, otherwise create it from
   the base branch. The agent never chooses branches. (D-014)
3. The daemon reads the issue once and stores the checklist Markdown in the
   workspace. (D-013)
4. The daemon spawns the named role with the named runtime through the same
   container mechanism the CLI uses, under the capsule, and hands the agent
   the prompt via `/goal`, pointing at the local checklist. (D-009, D-012,
   D-016)
5. The agent works one checklist item at a time, using research and
   verification subagents. (D-007) It updates the local checklist only when
   an item is finished; the daemon pushes each such update to the issue. No
   other tracker traffic occurs while working. (D-013)
6. Verification runs when the checklist is complete; relation of
   verification to items is *open (Q-014)*. Failure policy is
   *open (Q-008)*.
7. The daemon opens or updates the pull request on GitHub from the branch.
   Merge strategy is *open (Q-007)*.

Independent issues run in parallel, each in its own container. (D-004)
Resource limits for the prototype are per local machine; details
*open (Q-010)*.

## 7. Visibility

A human can attach to any managed container at any time and see the exact
prompt and the live session. Programmatic launch must preserve this; runs
that only capture stdout are not acceptable. The TUI lists running
containers and offers attach. (D-016)

## 8. State

Linear is the only authority for what work exists and its status. The
daemon holds no authoritative task state and rebuilds its view from Linear
and local workspaces after restart. (D-010) Whether it keeps a local
non-authoritative ledger is proposed, not decided.

## 9. Deployment

Prototype: everything on the developer's computer with local Docker.
Then one server host with Docker. Then several hosts, one daemon each.
No decision may bake in single-host assumptions that block the move.
(D-017)

## 9a. Credentials

Every credential is created into 1Password and referenced as `op://`;
none lives in files, images, documents, or chat. The daemon resolves
credentials from 1Password at runtime. (D-035)

Inventory of what exists and what must be created is in
`concept/credentials.md` (metadata only, never values). Summary as of
2026-08-27: Linear workspace login exists (Google SSO,
alexey@chainargos.com); no Linear OAuth agent app yet; two GitHub Apps
exist with the wrong scope for PR management; provider runtimes use
jackin's host login forwarding (`auth_forward = "sync"`), fine for the
laptop prototype, to be replaced by `op://` provider keys at the server
step; no `jackin` vault yet. Proposed: vault `jackin`, one item per
rotation unit (`linear-agent-app`, `github-app-jackin-daemon`,
`<runtime>-daemon`, ...).

## 9b. Delegation

All work — planning here, implementation, and the agents the daemon runs —
is carried out by delegated agents: subagents in a session, or agents
spawned through jackin when the work needs its own container, role, or
runtime. The top-level agent coordinates and decides. Building this
product follows the same rule from the first iteration, so every
iteration is also a proof of the workflow. (D-033, D-036)

## 9c. Parallelism, accounts, models

The build runs as many tasks in parallel as dependencies allow, spread over
the provider accounts on the machine (`~/.claude`; `~/.codex`,
`~/.codex-chainargos`, `~/.codex-chainargos2`) using jackin's multi-account
support. Models: Fable 5, Opus 5, Sonnet 5, GPT-5.6 Sol, GPT-5.6 Terra,
GPT-5.6 Luna, all at medium reasoning. Tasks are assigned across agents,
models, and account lanes. (D-039)

## 9d. Involved projects and branches

Any repository under github.com/jackin-project or github.com/tailrocks is
changed when this effort needs it; defects are bugs to fix there, gaps are
extensions (D-046). All such changes land on `feat/managed-execution` in
each repository; this repository commits directly to `main` (D-047).

## 10. How the product is built

The product is built with its own workflow: Linear issues, jackin roles,
pull requests (D-033). Work targets the latest jackin, installed locally
from the working branch; local build and verification are the default and
CI is confirmation, not a gate (D-034). Every milestone is verified visually
in the real Linear and GitHub UIs with `agent-browser` on one persistent
logged-in profile (D-032). The end-to-end workflow is written out in
`concept/workflow.md`.

## 10a. Linear project

All work for this effort is one Linear project; each `tasks/` folder is one
issue; dependencies are mirrored as blocking relations; milestones map to
project milestones. (D-040) The preview jackin is uninstalled; only the
branch build (`feat/managed-execution`) runs on the machine. (D-042)

## 10b. Milestones

Ordered proofs (D-037): (1) Linear setup verified; (2) daemon listens and
reacts to Linear; (3) an assigned issue spawns a local jackin agent in
Docker; (4) the capsule delivers a prompt into a specific agent's session.
Then checklist write-back, verification, pull requests, merge, TUI, server
host, multi-host. Details and tasks: `ROADMAP.md`; task folders: `tasks/`
(D-038).

## 11. Open questions

See `OPEN-QUESTIONS.md`. Highest impact for the prototype: Q-013 (issue
field convention), Q-015 (event path), Q-014 (checklist versus
verification), Q-008 (retry), Q-007 (merge).
