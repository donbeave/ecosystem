# What a jackin development role needs

Analysis for the role that implements the `jackin` tasks of `ROADMAP.md` for
the managed-execution effort. Facts are cited by path; recommendations are
labeled as such. Paths are relative to `~/Projects/tailrocks/` unless absolute.

## 1. Toolchain to build, test, lint, and release jackin locally

The single source of truth for versions is the jackin repository itself, and
the repository re-resolves them at run time: `mise.toml` has `lockfile = true`
and `idiomatic_version_file_enable_tools = ["rust"]`
(`jackin-project/jackin/mise.toml`), and `the-architect` marks `/workspace`
trusted (`MISE_TRUSTED_CONFIG_PATHS=/workspace:/tmp/jackin-mise`,
`jackin-project/jackin-the-architect/Dockerfile`). A role image therefore only
pre-warms the tools; the exact versions come from the checked-out branch's
`mise.toml` and `mise.lock` when `mise install` runs in the workspace. The
table lists what a green local run of the gates needs and which file mandates
it.

| Tool | Version pinned today | Mandated by | Used by which gate |
| --- | --- | --- | --- |
| Rust `1.97.1`, components `clippy`, `rustfmt`, targets `aarch64/x86_64-unknown-linux-gnu` | `rust-toolchain.toml` | `jackin/rust-toolchain.toml`; `rust-version = "1.97"` in `jackin/Cargo.toml` | everything |
| `rust-analyzer` component | added by `rustup component add` in the-architect Dockerfile | `rust-analyzer-lsp@claude-plugins-official` plugin in `jackin-the-architect/jackin.role.toml` | editor/LSP only |
| `cargo-nextest` 0.9.140 | `mise.toml` (`aqua:nextest-rs/nextest/cargo-nextest`) | `crates/jackin-xtask/src/ci.rs` (`nextest run --workspace --all-features --locked`); `.config/nextest.toml` profiles `default`, `ci`, `docker-e2e` | tests, snapshots, e2e |
| `cargo-deny` 0.20.2, `cargo-audit` 0.22.2, `cargo-shear` 1.13.4 | `mise.toml` | `ci.rs` policy partition: `deny check advisories bans licenses sources`, `audit`, `shear --deny-warnings`; `deny.toml` | policy |
| `cargo-hack` 0.6.45 | `mise.toml` | `ci.rs` powerset partition (`hack check --workspace --feature-powerset --all-targets --locked`), default when not `--fast` | powerset |
| `cargo-dylint` 6.0.4, `dylint-link` 6.0.4 | `mise.toml`; `[workspace.metadata.dylint]` in `Cargo.toml` | `cargo xtask lint --strict` (custom lints in `crates/jackin-lints`) | lint |
| `actionlint` 1.7.12, `shellcheck` 0.11.0 | `mise.toml` | `ci.rs` lint partition runs `actionlint` first | lint |
| `sccache` 0.16.0 | `mise.toml`; `.github/AGENTS.md` ("Rust compilation uses mold, sccache") | build speed; mold is optional per `.cargo/config.toml` | build |
| `cargo-llvm-cov` 0.8.7, `cargo-mutants` 27.1.0, `cargo-fuzz` 0.13.2, `cargo-hakari` 0.9.38, `hyperfine` 1.20.0 | `mise.toml` | hygiene workflow only (`.github/workflows/hygiene.yml`: fuzz, bench, cold-start); not on the PR gate | optional |
| `weaver` 0.24.2 | `mise.toml` | `crates/jackin-xtask/src/telemetry_registry.rs` (telemetry registry check, part of `xtask lint`) | lint |
| `codebook-lsp` 0.3.42 | `mise.toml`; `.codebook.toml` | spelling gate in `xtask lint` | lint |
| `bun` 1.3.14, `node` 24.18.0 | `mise.toml` | docs site: `bun ci`, `bun run build`, `bun run scripts/gen-crate-pages.ts` in `.github/workflows/docs.yml`; `crates/jackin-xtask/src/docs/contract.rs` requires `bun` or `node` | docs partition (`xtask docs repo-links`, roadmap audit) |
| `python` 3.14.7, `uv` 0.11.29, `pipx:reuse` 6.2.0 | `mise.toml`; `REUSE.toml` | `reuse-compliance.yml` (SPDX headers on every file) | policy |
| `zig` 0.16.0, `cargo-zigbuild` 0.23.0 | `mise.toml` | release archives only (`release_archive.rs`; `release.yml`) | release |
| `cosign` 3.1.3, `syft` 1.46.0 | `mise.toml` | `release.yml` signs keyless with `id-token: write` (`cosign sign-blob --bundle --yes`) and `syft scan`; `release_verify.rs` verifies bundles | release verification only |
| `boltffi_cli` 0.30.1 | `mise.toml` | `jackin-usage-ffi` bindings drift check (`mise run` task "Fail when committed boltffi bindings drift") | policy (FFI crate) |
| `git`, `gh`, `docker` CLI + buildx + compose, `jq`, `yq`, `ripgrep`, `fd`, `fzf` | construct base `0.36-trixie` (`jackin/docker/construct/Dockerfile`, `VERSION`) | PR flow (`.github/AGENTS.md`), role rebuilds, e2e | all |
| `build-essential`, `libssl-dev`, `pkg-config`, `cmake`, `openssl`, `xxd` | `jackin-the-architect/Dockerfile` apt layer | native deps of the workspace (openssl-sys, ring, tiny-skia via termrock-raster) | build |
| `cargo-watch`, `lychee` | `jackin-the-architect/Dockerfile` via `cargo binstall` | lychee: link checks in `docs.yml`; cargo-watch: convenience | docs |
| `termrock` `=0.11.0` git rev `1ac0d07` | `jackin/Cargo.toml:120` | vendored through Cargo; no extra tool, but network to github.com at first build | build |

The commands a task must be able to run, from `crates/jackin-xtask/src/ci.rs`
and `mise.toml` tasks:

- `mise run fmt` → `cargo fmt --check`.
- `mise run lint` → `cargo xtask ci --only lint --fast` = `actionlint`,
  `cargo fmt --check`, `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`, `cargo xtask lint --strict`.
- `mise run test` → `cargo xtask ci --only tests --fast` = `cargo check --workspace --all-targets --locked`, `cargo nextest run --workspace --all-features --locked`, `cargo test --doc --workspace --locked`.
- `mise run ci` → `git fetch origin main` then `cargo xtask ci --only policy --only docs --only snapshots` (policy needs `--base` for `schema-check`, so `origin/main` must be fetchable).
- `cargo xtask ci` (no flags) adds the feature powerset; `cargo xtask ci --e2e` adds the Docker lane (§3).
- Docs site: `bun ci && bun run build` under `docs/`.
- Release: not run locally (D-034: releases happen through CI when a milestone needs one; `release.yml` is the only cosign user, keyless). The role needs no cosign key.

Drift to fix in the role: `jackin-the-architect/jackin-toolchain/mise.toml`
already differs from `jackin/mise.toml` (bun 1.4.0 vs 1.3.14, node 24.19.0 vs
24.18.0, sccache 0.17.0 vs 0.16.0, uv 0.12.5 vs 0.11.29, syft 1.51.0 vs
1.46.0, weaver 0.25.1 vs 0.24.2, `uniffi` instead of `boltffi_cli`). This is
harmless because the workspace `mise.lock` wins, but the pre-warm should be
regenerated from the `feat/managed-execution` branch (Q-020) with the existing
`scripts/update-jackin-toolchain.rs` so the first `mise install` in a task is
a no-op rather than a download.

## 2. Skills and plugins the jackin tasks need

| Skill or plugin | Runtime | Why the tasks need it | Source |
| --- | --- | --- | --- |
| `jackin-dev@jackin-marketplace` (`jackin-propose`, `jackin-create-pr`, `jackin-refresh-pr`, `jackin-checkout-pr`, `jackin-merge-pr`, `jackin-goal-prompt`, `jackin-brainstorm`, `jackin-research`, release skills) | Claude (plugin), Codex (`codex plugin marketplace add jackin-project/jackin-dev`), Amp reuses the Claude cache; OpenCode unsupported | PR body template with the mandatory `jackin-dev pr sync <PR>` block (`jackin/PULL_REQUESTS.md` "Include local checkout instructions"), squash flow with `jackin-pr-trailers` (`jackin/.github/AGENTS.md`), `/goal` delivery (D-044) | `jackin-project/jackin-dev/README.md`, `INSTALL.md` |
| `tailrocks-skills@tailrocks-skills`: `tailrocks-rust-best-practices`, `tailrocks-rust-review`, `tailrocks-rust-refactor`, `tailrocks-tui-design`, `tailrocks-tui-design-audit`, `tailrocks-record-decision`, `tailrocks-create-pr`, `tailrocks-review-pr` | Claude plugin; `.codex-plugin` and `.kimi-plugin` manifests exist in `tailrocks-skills/` | Rust correctness contracts for every jackin crate; TUI design for M9-04 (`jackin-console`, termrock widgets); ROADMAP §4 states no separate termrock role because this plugin carries the TUI skill | `tailrocks-skills/` skill directories |
| `tailrocks-axum-*`, `tailrocks-grpc-*`, `tailrocks-graphql-*` | same | Not needed: jackin has no Axum, tonic, or Juniper surface; the Linear adapter (M2-01..M2-04) is a GraphQL *client* over HTTP, which `tailrocks-graphql-best-practices` explicitly scopes out ("public GraphQL API policy") | plugin descriptions |
| `code-review@claude-plugins-official`, `pr-review-toolkit@claude-plugins-official` | Claude | Review tasks M2-08, M3-08, M4-07 are assigned to the review role on Codex lanes (L6), so the dev role needs these only for self-review before opening a PR; keep `code-review` for the pre-PR pass, drop `pr-review-toolkit` (review role owns it, ROADMAP §4) | `ROADMAP.md` §4, lanes §5 |
| `improve` (`shadcn/improve` via `skills add`) | Claude, Codex, Amp, OpenCode, Kimi | Read-only audit and plan generation; ROADMAP §4 lists it among the-architect's contents; useful for M2-08-style follow-ups but not required by any task's `verify.sh` | `jackin-the-architect/Dockerfile` |
| `rust-analyzer-lsp@claude-plugins-official` | Claude | Symbol navigation across 34 crates (`jackin/crates/`) | `jackin-the-architect/jackin.role.toml` |
| `github@claude-plugins-official`, `commit-commands@claude-plugins-official` | Claude | `gh` PR flow and Conventional Commits with `-s` (`jackin/COMMITS.md`) | manifest |
| `caveman@caveman` + RTK + headroom | Claude hooks; Codex/Amp skills; OpenCode plugin | Token stack; not required by any gate, inherited from the-architect if kept | `jackin-the-architect/hooks/preflight.sh` |
| `security-guidance`, `claude-md-management`, `code-simplifier`, `feature-dev` | Claude | Not required by tasks; `feature-dev` overlaps `jackin-propose`; recommendation: drop to shrink the trust surface (threat model item 1 in `jackin-the-architect/AGENTS.md`) | manifest |

Runtimes: every jackin task in `ROADMAP.md` is on lanes L1..L6, which are
Claude Code (L1..L3) or Codex (L4..L6). No jackin task is assigned to amp,
opencode, kimi, or grok. The six-runtime matrix (M4-05) exercises the *target*
roles launched inside DinD, not the developer's own container.

## 3. Docker for integration tests

Two classes of test need a Docker daemon: the `dind_e2e` and
`usage_broker_e2e` binaries selected by `[profile.docker-e2e]` in
`jackin/.config/nextest.toml` (`cargo nextest run -p jackin --features e2e --profile docker-e2e`, `jackin/TESTING.md`), and every M3/M4 `verify.sh` in
`ROADMAP.md` that runs `docker ps`, `jackin load`, `jackin hardline`, or
`jackin daemon exec` against a real container. The tests honour `DOCKER_HOST`
(`jackin/crates/jackin/tests/dind_e2e/common.rs:90`,
`pty_runner.rs:64`).

jackin never mounts the host Docker socket into a role container. The only
path is the DinD sidecar: the launch sets `DOCKER_HOST=tcp://<dind>:2376`
(`jackin/crates/jackin-runtime/src/runtime/launch/launch_runtime.rs:388`),
tiered as `none < rootless < privileged` (`jackin-core/src/docker_security.rs`).
Under the default `standard` profile DinD is off unless granted; a manifest
`[docker] dind = "rootless"` makes the role require it, `dind` omitted leaves
it to the operator's `[docker.grants]` (`jackin/docs/content/(public)/(role-authoring)/developing/role-manifest.mdx` §`[docker]`).

Recommendation: the manifest sets `min_profile = "standard"` (cargo needs
open network to crates.io and github.com for the termrock git dependency) and
omits `dind`; the six jackin workspace profiles of M1-13 set
`[docker.grants] dind = "privileged"` so every lane can run the e2e lane, and
the daemon's `LoadOptions` (M3-01) passes the same grant. Rootless would be
preferable because the tests only need a daemon, not host-level
capabilities, but jackin's sidecar `ContainerSpec` exposes only `privileged`
(no `security_opt`/`cap_add`), the upstream image documents `--privileged`
as required, and jackin's own matrix cell is `TODO(WP0-tier2)`; M1-13 proves
the tier on this host and its `dind.out` is the tier of record (D-078). A
`security_opt`/`cap_add` knob for the sidecar is a non-gating jackin
follow-up so rootless can be retried later. Note the cost: the e2e `jackin load` inside DinD pulls
`projectjackin/construct:0.36-trixie` and builds a fixture role image on every
fresh sidecar, so the DinD data volume should persist across the lane's
instances. The macOS OrbStack usage-broker lane (`TESTING.md` "Mandatory macOS
OrbStack usage-broker lane") cannot run in any container and stays a host-side
operator step; no M-task touches the usage broker.

## 4. Secrets and environment

What the role needs at run time:

| Need | Mechanism | Source |
| --- | --- | --- |
| Push branches and open PRs on `jackin-project/jackin` | `[github] auth_forward = "sync"` (default) copies the host's `~/.config/gh/`; the container runs `gh auth setup-git`, the host is never written | `jackin/docs/content/reference/runtime/configuration.mdx` "GitHub CLI auth-forward settings"; `jackin/HOST_AND_CONTAINER.md` |
| Provider login for the lane | per-agent `auth_forward = "sync"` from `CLAUDE_CONFIG_DIR` / `CODEX_HOME` per lane (`~/.claude`, `~/.codex*`) | D-039, M1-13, credentials §5.5 (`op://` keys only from M10) |
| `origin/main` reachable for `schema-check --base` | public repo, no token needed | `crates/jackin-xtask/src/ci.rs` policy partition |
| Docker daemon | DinD sidecar (§3), no socket | `launch_runtime.rs:388` |

What must not be in it: the Linear client secret and workspace tokens (D-023
proposal, D-035; the daemon under development reads them through jackin's
`op://` env resolution on the *host* daemon config, M2-01, and a test uses a
fake `op`), `OP_SERVICE_ACCOUNT_TOKEN` (server host only, M10-01, credentials
§5.4), the `agent-browser` profile directory (session cookies for Linear and
GitHub; credentials §5.3 says "not mounted into role containers other than the
implementing role"; see §5 below), DockerHub or registry credentials
(`publish-image.yml` uses repository secrets in CI), `CONTEXT7_API_KEY`
(optional third-party MCP, threat model item 5; drop the env declaration
unless a task asks for it), and any OpenTofu/org-admin `GITHUB_TOKEN`
(the-architect threat model item 2; this role never runs
`jackin-github-terraform`). No `ENV` credential in the Dockerfile and
`--mount=type=secret` for build-time tokens, as the-architect's hard rules 3
and 5 require.

## 5. Browser verification inside the role

D-032 says implementation is verified visually "by the implementing agent"
and that roles used to implement "must ship `agent-browser`". D-045, decided
later the same day, says the-architect must not accumulate project tooling
such as `agent-browser` and that the new roles are designed per purpose.
Least privilege decides between them.

Which jackin tasks name a browser proof: M2-04 (thought within 10 s, state
change), M5-02 (ticks visible), M6-03 (elicitation), M7-02 (PR linked), M8-01
(PR merged, issue Done), M10-02 (issue runs on the server). Every other jackin
task's `verify.sh` is local: nextest, `jackin daemon status --format json`,
`docker ps`, attach captures. The browser proofs are all observations of
Linear or GitHub state that the daemon wrote; they do not change the code
under test, and the ROADMAP already routes the milestone proof runs (M2-07,
M3-07, M4-06, M5-03) to `the-operator`.

Recommendation: no `agent-browser` and no profile mount in the development
role. The browser proof for the six tasks above becomes a checklist item
executed by the operator role on the same issue (a subagent-spawned proof,
D-036), with the screenshot filed in `tasks/<task>/`. Reasons: the profile
directory is a credential with write access to the human's Linear workspace
and GitHub account (credentials §5.3), while the development role already
holds the ability to push code; combining both in one container turns a
prompt-injection through issue text (M4-07 calls prompt content untrusted)
into a path from "malicious PR" to "approve and merge it in the browser".
Splitting keeps each role's blast radius to one axis: code for the developer,
UI and vault for the operator. This needs D-032's consequence "roles used to
implement this project must ship `agent-browser`" amended to "the role that
performs the browser proof" — record it as a decision before tasks are cut.

## 6. ROADMAP tasks this role serves

All rows with `jackin` in the repository column and role `the-architect`,
which D-045 replaces with this role: M1-02 (branch build, `jackin doctor`),
M1-13 (workspace lanes), M2-01..M2-06, M3-01..M3-06, M4-01..M4-05, M5-01,
M5-02, M6-01..M6-03, M7-02, M8-01, M9-01, M9-04, M10-02 (with local), M11-01,
M11-02. Also M3-02's manifest updates of the new roles, since it touches
`RoleManifest` and the role repositories together. Not served: review tasks
(M2-08, M3-08, M4-07 → review role), proof runs and Linear/1Password/GitHub
setup (→ operator role), termrock tasks M9-02/M9-03 (termrock repository; the
same image can run them because `tailrocks-tui-design` is present, but they
are not jackin tasks).

## 7. Proposed role specification

**Name.** `donbeave/jackin-role-wright` (selector `wright`; a wright is the
one who builds the thing — the role builds jackin itself). Alternative if a
plainer name is preferred: `donbeave/jackin-role-jackin-builder`.

**Base image.** `projectjackin/construct:0.36-trixie` pinned by digest, the
same digest as `jackin-the-architect/Dockerfile` (D-042: roles built locally
target the branch's construct base; `jackin/docker/construct/VERSION` is
`0.36-trixie`).

**Install list (Dockerfile).**

| Layer | Content | Inherited from the-architect or added |
| --- | --- | --- |
| apt | `build-essential libssl-dev openssl pkg-config cmake xxd` | inherited |
| mise pre-warm | `jackin-toolchain/mise.toml` regenerated from `jackin@feat/managed-execution` `mise.toml` (all §1 rows), rust from `rust-toolchain.toml`, `rustup component add rust-analyzer`, `MISE_TRUSTED_CONFIG_PATHS=/workspace:/tmp/jackin-mise` | inherited, versions refreshed |
| cargo-binstall extras | `lychee` (docs link gate); drop `cargo-watch` | inherited minus one |
| skills | `jackin-dev` for codex and amp via `skills add`; `improve` for claude and codex | inherited, reduced to two runtimes |
| token stack | caveman, RTK, headroom and the `AGENTS.md.d` concatenation | inherited (optional; keep if the human keeps caveman as house style) |
| removed | OpenTofu, `ctx7`/Context7, `skills` for opencode/kimi, `uniffi` | added by omission: no org-admin credential adjacency (threat model item 2), no third-party MCP |
| added | nothing binary; `AGENTS.md.d/jackin.md` telling the agent to run `mise install` in `/workspace` first, then the §1 command list; pointer to `jackin/AGENTS.md` hard rules (branch, `-s`, push, `/jackin/` paths, brand) | added |

**`jackin.role.toml` sketch.**

```toml
version = "v1alpha6"                       # v1alpha7 once M3-02 adds default_agent
dockerfile = "Dockerfile"
published_image = "ghcr.io/donbeave/jackin-role-wright:latest"   # or docker.io/donbeave/...
agents = ["claude", "codex"]               # lanes L1..L6 only; six runtimes not needed (§2)
# default_agent = "claude"                 # after M3-02

[identity]
name = "The Wright"

[claude]
model = "claude-sonnet-4-6"                # overridden per lane by the workspace profile (ROADMAP §4)
plugins = [
  "code-review@claude-plugins-official",
  "commit-commands@claude-plugins-official",
  "github@claude-plugins-official",
  "rust-analyzer-lsp@claude-plugins-official",
  "jackin-dev@jackin-marketplace",
  "tailrocks-skills@tailrocks-skills",
  "caveman@caveman",
]
[[claude.marketplaces]]
source = "jackin-project/jackin-marketplace"
[[claude.marketplaces]]
source = "tailrocks/tailrocks-skills"
[[claude.marketplaces]]
source = "JuliusBrussee/caveman"

[codex]

[hooks]
preflight = "hooks/preflight.sh"           # the-architect's script minus Context7; keeps RTK hook, caveman flag, headroom MCP

[docker]
min_profile = "standard"                   # cargo needs open egress; DinD left to [docker.grants] (§3)

[env.CLAUDE_CODE_NO_FLICKER]
default = "1"
[env.CLAUDE_CODE_MAX_OUTPUT_TOKENS]
default = "64000"
[env.CLAUDE_CODE_EFFORT_LEVEL]
default = "medium"                         # D-039; Codex model_reasoning_effort set by the lane profile (Q-024)
[env.CAVEMAN_DEFAULT_MODE]
default = "ultra"
[env.RTK_TELEMETRY_DISABLED]
default = "1"
```

**Env, mounts, hooks.** No secret env declarations. Mounts come from the
workspace profile, not the manifest: the jackin checkout at
`~/.jackin/managed/<key>` (M3-03) or `~/Projects/jackin-project/jackin` for
hand-run M1/M2 tasks, `isolation = "worktree"` where the task branch demands
it (`configuration.mdx` `[[mounts]]`). A persistent named volume for
`~/.cargo/registry`, `~/.cargo/git`, and `target/` per lane is recommended so
a 34-crate workspace does not rebuild from zero per instance; and a persistent
DinD volume (§3). Hooks: `preflight.sh` only; no `setup_once` writes outside
`/jackin/state/` (`HOST_AND_CONTAINER.md`).

**Threat model bullets (for the role's `AGENTS.md`).**

- Holds a GitHub session able to push to `jackin-project/jackin` and open
  PRs; merges only when the task text names the merge — under D-055/D-079
  the task prompt is the operator's per-PR "merge it" that
  `jackin/.github/AGENTS.md` requires (opinion superseded by D-055).
- Issue text delivered by the daemon is untrusted input (M4-07); the role has
  no browser profile, no vault access, no Linear token, so the worst case is a
  bad commit on a branch that still needs review and CI.
- DinD sidecar (when granted) is a second Docker daemon inside the sandbox,
  not the host's; images built there are throwaway.
- Supply chain as in the-architect: mise, cargo (`--locked` everywhere),
  npm for `skills`, plugin marketplaces limited to the three listed; the
  marketplace audit pre-commit hook and gitleaks carry over unchanged.
- Base image trust anchored on `projectjackin/construct` digest, as today.

**Inherits versus adds relative to the-architect.** Inherits the construct
base, apt build deps, the mise pre-warm mechanism and its refresh script, the
`jackin-dev`/`improve`/caveman/RTK/headroom layers, the preflight hook
structure, the pre-commit checks, and the AGENTS.md concatenation. Removes
OpenTofu, Context7, four of six runtimes, five Claude plugins, `cargo-watch`.
Adds `[docker] min_profile`, the effort env, a jackin-specific instruction
file, and (after M3-02) `default_agent`. Nothing browser-related; that lives in
the operator role.
