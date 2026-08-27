# Role needs: termrock development and ecosystem document authoring

Facts about what a jackin role must contain to (a) work on
`tailrocks/termrock` for ROADMAP M9-02 and M9-03 and (b) author planning
documents and task folders in this repository (M1-01, M1-08, and the
authoring half of M1-12). Every claim cites a file; opinions are marked
*(opinion)*. Paths: `T/` = `/Users/donbeave/Projects/tailrocks/termrock`,
`S/` = `/Users/donbeave/Projects/tailrocks/tailrocks-skills`,
`A/` = `/Users/donbeave/Projects/tailrocks/jackin-project/jackin-the-architect`.

## 1. termrock toolchain and tools

termrock pins everything itself; a role does not need to guess versions, it
needs `mise` plus the ability to run `mise install` against the checkout
(`T/mise.toml` has `lockfile = true`, `T/mise.lock` is committed). The table
lists what that resolves to today and which file mandates it.

| Tool | Version | Mandated by | Used by |
| --- | --- | --- | --- |
| Rust toolchain | `1.97.1`, components `clippy`, `rustfmt`, profile `minimal` | `T/rust-toolchain.toml`; `T/Cargo.toml` `rust-version = "1.97.1"`, edition 2024; mise picks it up through `idiomatic_version_file_enable_tools = ["rust"]` (`T/mise.toml:2`) | everything |
| Rust nightly (any) | latest nightly, minimal profile | `T/mise.toml` task `gate` (`rustup toolchain install nightly --profile minimal`) | `cargo public-api` only |
| target `wasm32-unknown-unknown` | — | `gate`: `cargo check -p termrock-lookbook-web --target wasm32-unknown-unknown` | gate only |
| cargo-nextest | 0.9.140 (aqua) | `T/mise.toml` `[tools]`; `T/.config/nextest.toml` (retries 0, hot-path binaries take all threads) | `check`, `test`, goldens, PNG baselines |
| cargo-deny | 0.20.2 | `T/mise.toml`; policy in `T/deny.toml` (yanked denied, license allowlist, wildcards denied, unknown registry/git denied) | `gate`, `T/.github/workflows/hygiene.yml` |
| cargo-hack | 0.6.45 | `T/mise.toml` | `gate` feature powerset |
| cargo-shear | 1.13.1 | `T/mise.toml` | `gate` unused deps |
| cargo-semver-checks | 0.48.0 | `T/mise.toml`; `T/RELEASING.md` "semver-candidate" gate | release boundary only |
| cargo-public-api | 0.52.0 via `mise x cargo:cargo-public-api@0.52.0` | `gate`; diff against `T/docs/api/public-api.txt` | any public API change (M9-02 and M9-03 both change the public API) |
| cargo-binstall | 1.21.0, `cargo.binstall_only = true` | `T/mise.toml:4-5` | installs the `cargo:*` tools above |
| wasm-pack | 0.15.0 | `T/mise.toml`; `T/docs/package.json` `build:preview-runtime` | docs build in `gate` |
| bun | 1.3.14 | `T/mise.toml`; `mise run docs-quality` runs `bun run docs/scripts/check-contracts.ts` and is the first line of `check` | **every `mise run check`**, not only docs |
| python 3.14 + uv 0.11.29 + `pipx:reuse` 6.2.0 | as listed | `T/mise.toml`; `T/REUSE.toml`; `T/TESTING.md` says CI verifies REUSE | REUSE lint: **documented only** — no `mise` task or local workflow invokes `reuse lint` (`T/.github/workflows/*.yml` contain no REUSE step; `ci.yml` only calls the velnor `ci-code.yml`, which runs `mise run build/test/lint/fmt`) |
| gitleaks | 8.30.1 | `T/mise.toml`; `T/.gitleaks.toml` | not invoked by any task; secret scan is advisory here |
| actionlint | 1.7.12 | `T/mise.toml` | workflow edits only |
| git-cliff | 2.13.1 | `T/mise.toml`; `T/RELEASING.md` changelog step | release prep only |
| `rg` | any | `T/scripts/check-experience-research.sh:4` | research doc gate; not part of `check`/`gate` |
| sccache + mold | 0.16.0 / v1 | `T/.github/workflows/hygiene.yml:30-45` | CI speed only; optional in a role |
| C toolchain | — | `termrock-raster` builds `swash`/`tiny-skia` (`T/Cargo.toml:37-38`, pure Rust); no `pkg-config`/OpenSSL need found in `T/Cargo.lock` consumers, but the architect image already ships `build-essential` (`A/Dockerfile:22-30`) | safe default |

Exact commands the role must be able to run (`T/mise.toml`, `T/TESTING.md`):

- Before every commit: `mise run check` = `mise run docs-quality`,
  `cargo fmt --all -- --check`,
  `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`,
  `cargo nextest run --workspace --all-features --locked`.
- Before every push: `mise run gate` = `check` plus `preview-goldens`,
  `png-baselines`, no-default-features and examples checks, wasm check,
  rustdoc `-D warnings`, nightly `cargo public-api` diff, `cargo hack`
  powerset, `cargo deny check advisories bans licenses sources`,
  `cargo shear`, `cargo package`, and a full docs site build
  (`bun install --frozen-lockfile && bun run build`, network required).
- Design gate: `T/crates/termrock/tests/design_gate.rs` is an ordinary
  nextest test in the `termrock` crate (~60 source-scanning laws); no extra
  tool, runs inside `check`.
- Performance budgets: `T/crates/termrock/tests/*_hot_path.rs` run inside
  `check` with `threads-required = "num-test-threads"`
  (`T/.config/nextest.toml`); they are wall-clock contracts, so a role
  running them needs an uncontended CPU (opinion: give the container at
  least the CPU count the host uses for one `cargo nextest` run, or the
  budgets fail spuriously).
- Goldens: `mise run preview-goldens` diffs 15 flagship stories against
  `T/crates/termrock-lookbook/goldens/`; `mise run bless-previews` sets
  `TERMROCK_BLESS_PREVIEWS=1` and rewrites them
  (`T/crates/termrock-lookbook/tests/goldens.rs:80-104`). PNG baselines are
  the same shape with `TERMROCK_BLESS_PNGS=1`
  (`T/crates/termrock-lookbook/tests/png_baselines.rs:25-26`).
- Frame preview for a human: `cargo run -p termrock-lookbook -- frame --story <id> --cols N --rows M`
  (`T/.github/workflows/hygiene.yml:79`); SVG/PNG export exists in the same
  crate (`analysis/termrock.md` §2.1).

Repository policy that binds the role (`T/CONTRIBUTING.md`): trunk-only, "use
`main`, never create or publish another branch, and never open a pull
request", run `mise run gate`, push every green commit immediately,
Conventional Commits, `git commit -s`. Public API changes must update
`docs/api/public-api.txt` and component docs in the same commit; breaking
changes add the next `T/migrations/000N-*.md` and a `T/MIGRATING.md` row
(`T/CONTRIBUTING.md`, `T/RELEASING.md`). Conflict to resolve before M9-02
starts: ROADMAP Q-020 names `feat/managed-execution` as the termrock working
branch and D-034 assumes pull requests, both of which `T/CONTRIBUTING.md`
forbids. Either termrock's policy is amended or the termrock role pushes to
`main` directly; the credential the role receives differs accordingly
(branch push vs. `main` push on a `tailrocks` org repository).

## 2. Skills and plugins

- `tailrocks-skills` plugin, version 0.28.0 (`S/.claude-plugin/plugin.json`,
  `S/.claude-plugin/marketplace.json`). One install channel per agent, never
  mixed (`S/INSTALL.md` "The one rule that prevents duplicates"). Claude:
  `claude plugin marketplace add tailrocks/tailrocks-skills` then
  `claude plugin install tailrocks-skills@tailrocks-skills`; pin with
  `…/tailrocks-skills.git#v0.28.0` (`S/INSTALL.md:147-204`). Codex:
  `codex plugin marketplace add tailrocks/tailrocks-skills[@v0.28.0]` then
  `codex plugin add tailrocks-skills` (`S/INSTALL.md:206-235`). jackin bakes
  the Claude form from `[claude].plugins` and `[[claude.marketplaces]]` in the
  manifest (`analysis/jackin.md:244`); the architect already lists both
  (`A/jackin.role.toml:13-27,39-41`).
- Skills that matter for termrock: `tailrocks-tui-design` (model-policy;
  design, bless, freeze), `tailrocks-tui-design-audit` (manual, read-only),
  `tailrocks-rust-best-practices`, `tailrocks-rust-review`,
  `tailrocks-rust-refactor` (`S/INSTALL.md:20-70`). There is no per-family
  install; the whole tree comes with the plugin.
- `rust-analyzer-lsp@claude-plugins-official` and `rustup component add rust-analyzer`
  as in the architect (`A/jackin.role.toml:22`, `A/Dockerfile:63`). Note the
  architect pins Rust `1.98.0` (`A/jackin-toolchain/rust-toolchain.toml`);
  termrock's `rust-toolchain.toml` overrides it per checkout, so the role
  should pre-install `1.97.1` as well or accept a rustup download at task
  start (network).
- Not needed for termrock or docs: OpenTofu, `ctx7`, headroom, `op`,
  `agent-browser`. Nothing in `T/` or this repository reads them.

## 3. What M9-02 and M9-03 need

| Task | Scope (ROADMAP) | Needs beyond §1/§2 | Human step outside the container? |
| --- | --- | --- | --- |
| M9-02 host-loop drain hook in `runtime::run` | `analysis/termrock.md` §8 item 5; verification "termrock tests and a preview story pass; migration note written" | Public API change: regenerate `docs/api/public-api.txt` (nightly + cargo-public-api), add `migrations/000N-*.md` + `MIGRATING.md` row, a lookbook story in `T/crates/termrock-lookbook/src/stories.rs`; docs page if a public type is added (`analysis/termrock.md` §6 completeness law) | No. Goldens are untouched unless a flagship story's paint changes. |
| M9-03 `TerminalPane` widget | §8 item 2; verification "Golden frames blessed by the human; story added" | Everything M9-02 needs plus new stories, a docs component page, contract entry (`docs/scripts/check-contracts.ts`), and adding the story to the flagship list if it is to be golden-tested (`goldens.rs` `FLAGSHIP` const); PNG baseline only if jackin uses it | **Yes, a decision, not a command.** |

The bless flow, precisely: the write is `TERMROCK_BLESS_PREVIEWS=1` on a
nextest run (`goldens.rs:81`); nothing in termrock checks who runs it, and
`T/AGENTS.md` does not mention blessing at all. The authority rule is in the
skill: "The user blesses frames; the agent never does. Render, show the
frame, adjust, repeat — a frame becomes a contract only when the user says it
matches" and "Selection alone never authorizes blessing, golden freeze,
capture, or mutation" (`S/skills/tailrocks-tui-design/SKILL.md:6,15-17,89-96,113-128`).
ROADMAP M9-03 restates it ("blessed by the human"). So the human does not
need to leave their seat or run anything on the host: the agent renders
frames (`frame`/SVG/PNG export), posts them where the human sees them (the
attached session, or the issue via the M4 capsule prompt path), waits for an
explicit approval recorded on the issue (D-013 activity or comment), then
runs `mise run bless-previews` itself and commits the goldens with the
approval reference in the commit body. *(opinion)* Model it as a `blocked`
task status (`concept/task-format.md` "Status") with an elicitation, which
is exactly the M4 capsule capability; do not give the role a mechanism to
bless without that record, and do not have the human run `bless-previews`
on the host — that would produce a commit outside the task's branch history.

Other constraints on both tasks: `analysis/termrock.md` §9 — API
instability is policy (a SHA pin in jackin follows), Linux/macOS only,
hot-path budgets are the CI floor, no Tokio in base modules
(`T/ENGINEERING.md`). Both tasks run in Claude lanes L1/L2 (ROADMAP §5).

## 4. Ecosystem document tasks (M1-01, M1-08, M1-12 authoring part)

This repository contains only Markdown plus `tasks/<id>/verify.sh`
(`AGENTS.md` rule 1, D-038). Minimal tool set:

| Tool | Needed for | Source |
| --- | --- | --- |
| `git` with `commit -s` and push | rule 9 of `AGENTS.md`; every task ends with a push | construct base |
| `gh` | pushing over HTTPS with jackin's forwarded token, opening the PR if the ecosystem repo moves to PRs (today rule 9 says push `origin` directly) | construct base ships `gh` (ROADMAP §4) |
| `bash`, `grep`, `sed`, `awk` | `verify.sh` scripts (M1-01 "every M1..M4 id … has a folder with the four files"; M1-08 "the section exists and every D-012/D-014 field appears") | construct base |
| Markdown lint | none; no linter config exists in this repository (no `mise.toml`, no `.markdownlint*`) | — |
| Mermaid | `ROADMAP.md:148-190` holds a Mermaid graph; GitHub renders it, nothing verifies it locally | not needed |
| `shellcheck` | *(opinion)* cheap insurance for `verify.sh`; the architect toolchain already has 0.11.0 (`A/jackin-toolchain/mise.toml`) | optional |
| `curl` + Linear GraphQL, browser | only M1-12's Linear half (issue creation, `inverseRelations` check) — that is operator work, not authoring | operator role |

The authoring half of M1-12 (writing issue bodies from folders, linking URLs
back into `tasks/README.md`) is the same git-and-Markdown work as M1-01.

## 5. Recommendation

**termrock work belongs in the same role as jackin Rust work.** Tooling
overlap is near total: the architect's `jackin-toolchain/mise.toml` already
carries cargo-nextest 0.9.140, cargo-deny 0.20.2, cargo-hack 0.6.45,
cargo-shear 1.13.0, bun, python, uv, `pipx:reuse` 6.2.0, actionlint
(`A/jackin-toolchain/mise.toml:2-35`); termrock adds only
cargo-semver-checks, wasm-pack, git-cliff, gitleaks, cargo-public-api, a
nightly toolchain, the `wasm32` target, and Rust 1.97.1, all of which
`mise install` in the checkout resolves from `T/mise.toml` + `T/mise.lock`
without any role change. The skill is already in the plugin
(`tailrocks-tui-design` ships with `tailrocks-skills`). ROADMAP §4 reached the
same conclusion. Least privilege is not served by a second image: the only
privilege difference between jackin and termrock work is the GitHub
credential scope (`jackin-project` vs `tailrocks` org, branch vs `main`),
and jackin scopes credentials per launch through the `op://` allowlist and
`jackin-exec` (`analysis/jackin.md:139-140`), not per image. A separate
role would duplicate a 6.7 KB Dockerfile to remove nothing.

**Document tasks need no role of their own.** They need git, gh, and bash,
which every construct-based role has. Least privilege says they should run
in the role that carries the fewest credentials for the lane in use; in
practice that is the Rust role with only the ecosystem repository's push
credential bound (the operator role carries browser profile and 1Password
access, which authoring never needs). M1-12's Linear half stays with the
operator role as ROADMAP already assigns.

*(opinion)* One purpose-built Rust role for this effort, replacing
`the-architect` per D-045, covers jackin, termrock, and ecosystem authoring.

## 6. Proposed role spec (single Rust role; termrock delta marked)

- Name: `donbeave/jackin-the-builder`, role `the-builder` (D-045). Base:
  `projectjackin/construct:0.36-trixie@sha256:…` digest-pinned (hard rule 1,
  `A/AGENTS.md`).
- Install list (copy the architect's structure, `A/Dockerfile`): mise +
  `jackin-toolchain/` from jackin upstream; **add** `rust@1.97.1` alongside
  1.98.0, `rustup target add wasm32-unknown-unknown`, `rustup toolchain
  install nightly --profile minimal`, and `mise install` run once against a
  vendored copy of `T/mise.toml`+`T/mise.lock` so cargo-semver-checks
  0.48.0, wasm-pack 0.15.0, git-cliff 2.13.1, gitleaks 8.30.1, cargo-public-api
  0.52.0 are cached in the image; keep `build-essential`, `cmake`,
  `pkg-config`; keep `skills` CLI for Codex/Amp skill installs; **drop**
  OpenTofu, `ctx7`, headroom. Add `agent-browser` only if the D-032
  verification tasks share this role (separate analysis).
- `jackin.role.toml` sketch:

  ```toml
  version = "v1alpha5"
  dockerfile = "Dockerfile"
  published_image = "ghcr.io/donbeave/jackin-the-builder:latest"
  agents = ["claude", "codex"]
  [identity]
  name = "The Builder"
  [claude]
  model = "claude-sonnet-4-6"          # lane overrides (ROADMAP §5)
  plugins = ["rust-analyzer-lsp@claude-plugins-official",
             "github@claude-plugins-official",
             "commit-commands@claude-plugins-official",
             "jackin-dev@jackin-marketplace",
             "tailrocks-skills@tailrocks-skills",
             "caveman@caveman"]
  [[claude.marketplaces]]
  source = "jackin-project/jackin-marketplace"
  [[claude.marketplaces]]
  source = "https://github.com/tailrocks/tailrocks-skills.git#v0.28.0"
  [[claude.marketplaces]]
  source = "JuliusBrussee/caveman"
  [codex]
  [hooks]
  preflight = "hooks/preflight.sh"     # codex plugin add tailrocks-skills; rtk init
  [env.CLAUDE_CODE_MAX_OUTPUT_TOKENS]
  default = "64000"
  [env.CAVEMAN_DEFAULT_MODE]
  default = "ultra"
  [env.TERMROCK_BLESS_PREVIEWS]
  default = ""                          # never set by the image; set only in the bless step after recorded approval
  ```

- Env: no credential env in the image (hard rule 3); `GH_TOKEN` arrives via
  jackin's `op://` resolution per launch, scoped to the one repository the
  issue names. Mounts: the workspace checkout only; a named cargo cache
  volume is worthwhile for termrock's 256 KLOC builds (*opinion*).
- Hooks: `preflight.sh` runs `codex plugin marketplace add tailrocks/tailrocks-skills@v0.28.0 && codex plugin add tailrocks-skills`
  when the Codex home lacks it, `rtk init -g`, and `mise trust /workspace`.
- Threat model bullets: plugin breadth (same anchors as `A/AGENTS.md` §Threat
  model: tagged caveman, versioned tailrocks-skills, first-party jackin-dev);
  `mise install` at task time pulls binaries from GitHub/crates.io/aqua —
  pre-cache in the image so tasks run with the lockfile only; the termrock
  push credential targets `tailrocks/termrock` `main` if `T/CONTRIBUTING.md`
  stands — a compromised session can rewrite the trunk of a shared design
  system, so bind that token only for M9-02/M9-03 launches and prefer the
  branch policy change; golden bless is unguarded technically — the only
  guard is the recorded human approval, so the task prompt must forbid
  `TERMROCK_BLESS_*` before that record exists; no Docker socket, no `op`,
  no browser profile in this role.
