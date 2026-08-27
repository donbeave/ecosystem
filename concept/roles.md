> **Amended by D-048 (2026-08-27):** jackin development always uses the
> existing `jackin-the-architect` role. In this document, `crew-builder`'s
> scope is therefore termrock, ecosystem authoring, and the role
> repositories — not jackin. Read "builder serves jackin tasks" below as
> "the-architect serves jackin tasks". The role-set proposal number is
> D-049 (D-046..D-048 were taken while this was drafted).

# Roles that build this product (Q-016, D-045)

Status: **PROPOSAL, 2026-08-27**. Consolidates the four analyses under
`analysis/roles/` into one role set, one naming scheme, one spec per role,
and the decision text for D-046. Nothing here is decided until D-046 is
recorded in `DECISIONS.md`. Sources are cited as `dev §n`
(`analysis/roles/jackin-dev-needs.md`), `tr §n`
(`analysis/roles/termrock-and-docs-needs.md`), `op §n`
(`analysis/roles/operator-needs.md`), and `rev A.n` / `conv B.n`
(`analysis/roles/review-role-and-conventions.md`). Q-017..Q-024 are the
proposed questions in `ROADMAP.md` §7; `OPEN-QUESTIONS.md` stops at Q-016.

## 1. The set: three roles

| Role | Purpose | Toolchain | Credentials it can touch | Blast radius |
| --- | --- | --- | --- | --- |
| **builder** | implements jackin, termrock, and ecosystem documents | Rust (mise-managed), bun/node, python for REUSE, DinD when granted | `gh` session (push, open PR), provider login | a bad commit on a branch that still needs review and CI |
| **operator** | Linear, GitHub settings, 1Password items, browser proofs | `agent-browser` + Chrome for Testing, `op`, node; no Rust | browser profile (= the human on Linear and GitHub), on-demand service-account token for vault `jackin` | the human's Linear workspace, GitHub App/OAuth settings, one vault |
| **reviewer** | reviews PRs, posts verdicts | none; node for Claude plugins | `gh` session with review/comment scope | a misleading review the human reads |

Why three and not one or two:

- **One axis of privilege per role.** The builder holds the ability to push
  code; the operator holds the human's browser session and a vault write
  path; the reviewer holds a comment-only `gh` scope. Any merge of two axes
  creates a path that none of the tasks need: builder + browser turns a
  prompt injection through issue text (M4-07 calls it untrusted) into
  "push a malicious PR, then approve and merge it in the browser" (dev §5);
  reviewer + compiler executes the PR author's `build.rs` and proc-macros
  inside a container that also holds `gh` credentials (rev A.4).
- **Tooling overlap decides the merges that do happen.** termrock and jackin
  Rust work share the whole mise toolchain and the `tailrocks-skills` plugin;
  termrock adds only what `mise install` resolves from its own lockfile
  (tr §5). Ecosystem authoring needs git, gh, bash — a strict subset (tr §4).
  So one Rust role serves all three repositories. The operator and reviewer
  share nothing with it beyond the construct base.
- **Why the builder has no `agent-browser`.** The six builder tasks whose
  verification names a browser (M2-04, M5-02, M6-03, M7-02, M8-01, M10-02)
  only *observe* Linear or GitHub state the daemon wrote; they do not change
  the code under test, and the milestone proof runs are already operator
  tasks (dev §5). The profile directory is a credential with write access to
  the human's Linear and GitHub accounts (op §6), so it stays out of the role
  that can also push code. **Amendment to D-032 required:** the consequence
  "roles used to implement this project must ship `agent-browser`" becomes
  "the role that performs the browser proof ships `agent-browser`; the proof
  is a checklist item executed by the operator role on the same issue (a
  subagent-spawned proof, D-036), screenshot filed in `tasks/<id>/`".
- **Why the reviewer has no compiler.** CI is the build oracle (`gh pr
  checks`, `gh run view --log-failed`); every candidate review workflow is
  read-only by design; a finding that needs execution becomes "needs
  reproduction: <test sketch>" and a checklist item for the builder — which
  is exactly the M2-08 flow (rev A.4). `rust-analyzer-lsp` is excluded for
  the same reason: it runs build scripts.

## 2. Naming

Scheme (conv B.1, B.7): selector `donbeave/<family>-<purpose>` → repository
`github.com/donbeave/jackin-<family>-<purpose>` (jackin prepends `jackin-`
when absent, `roles.rs:204-237`); identity name `<Family> <Purpose>`. Always
use the namespace: a bare `<family>-<purpose>` resolves to `jackin-project`.
Selector alphabet is `[a-z0-9-]`, one `/` at most.

Family name. The analyses used the placeholder `crew`. Candidates:

| Family | Reads as | Reasoning |
| --- | --- | --- |
| `crew` | `crew-builder`, `crew-operator`, `crew-reviewer` | a crew works one job under one foreman (the daemon); each purpose is a trade; reads naturally in all three |
| `guild` | `guild-builder`, … | same trade metaphor, but a guild is the standards body, not the working team; misleads about what the roles are |
| `forge` | `forge-builder`, … | evokes building, but "forge" already means a code-hosting platform (Forgejo, SourceForge) and fits `operator`/`reviewer` poorly |
| `loop` | `loop-builder`, … | names the product's core (issue → agent → PR → issue) but reads as an adjective and collides with common CLI verbs |

**Recommendation: `crew`.** Repositories `donbeave/jackin-crew-builder`,
`donbeave/jackin-crew-operator`, `donbeave/jackin-crew-reviewer`; one glob
`jackin-crew-*` lists the family on GitHub and under `~/.jackin/roles/donbeave/`.

Shared base: **template repository `donbeave/jackin-role-template`, not a
base image.** The validator requires the *final* stage to be `FROM
projectjackin/construct:<version>-trixie` (`repo_contract.rs:100-160`), so a
family base image could only be an earlier `COPY --from` stage — fragile for
mise-managed tools. What the family shares is text: Dockerfile preamble,
per-tool RUN fragments, `AGENTS.md.d/00-common.md`, `hooks/source.sh`,
pre-commit and marketplace-audit scripts, `renovate.json`, workflows. The
template has no `jackin.role.toml` on purpose so it can never be loaded
(conv B.6).

## 3. Per-role specification

Common to all three (conv B.2): base
`projectjackin/construct:0.36-trixie@sha256:41815a3550254e5ef2edf5fc1215d9b1d1f0fd694bf6df108b57ba5a35812c1f`
(the pin `the-architect` uses; the validator accepts a digest suffix and the
family's hard rule requires it); `agents = ["claude", "codex"]` because every
task lane is L1..L6 (dev §2, op §5, rev A.1); manifest models are overridden
by the lane's workspace profile (ROADMAP §4); no `published_image` before M10
(§4 below); `AGENTS.md` with threat model and hard rules, `CLAUDE.md ->
AGENTS.md`, `AGENTS.md.d/` concatenated at build; `--mount=type=secret` for
build-time tokens; no credential `ENV`. Manifest version: `v1alpha5` is the
family baseline, but `[docker]` requires `v1alpha6` (`manifest.rs:87-135`;
both validate on the installed `jackin 0.6.4-preview.1100`), so builder and
operator declare `v1alpha6` and the reviewer `v1alpha5`; `v1alpha7` follows
M3-02 (`default_agent`).

### 3.1 Summary table

| Item | `donbeave/crew-builder` | `donbeave/crew-operator` | `donbeave/crew-reviewer` |
| --- | --- | --- | --- |
| Repo | `donbeave/jackin-crew-builder` | `donbeave/jackin-crew-operator` | `donbeave/jackin-crew-reviewer` |
| Identity | Crew Builder | Crew Operator | Crew Reviewer |
| apt | `build-essential libssl-dev openssl pkg-config cmake xxd` (dev §7) | `unzip openssl` + 1Password apt repo → `1password-cli` 2.39.0 (op §2); Chrome libraries via `agent-browser install --with-deps` as root | none beyond construct |
| mise | pre-warm regenerated from `jackin@feat/managed-execution` `mise.toml` (dev §1 rows: nextest, deny, audit, shear, hack, dylint, actionlint, shellcheck, sccache, weaver, codebook, bun, node, python, uv, reuse, zig, cosign, syft, boltffi) **plus** termrock's delta (tr §6): rust `1.97.1` beside `1.98.0`, nightly minimal, `wasm32-unknown-unknown`, cargo-semver-checks 0.48.0, wasm-pack 0.15.0, git-cliff 2.13.1, gitleaks 8.30.1, cargo-public-api 0.52.0; `rustup component add rust-analyzer`; `MISE_TRUSTED_CONFIG_PATHS=/workspace:/tmp/jackin-mise` | `node@24.19.0` only (op §2) | `node@24.19.0` only (rev A.6) |
| npm / binstall | `skills` CLI (Codex/Amp skill installs); `cargo binstall lychee`; drop `cargo-watch` | `npm i -g agent-browser@0.35.1`; `agent-browser install` as `agent` so Chrome lands in `/home/agent/.agent-browser/browsers` | none |
| Removed vs the-architect | OpenTofu, Context7/`ctx7`, headroom, amp/opencode/kimi/grok, `feature-dev`, `security-guidance`, `claude-md-management`, `code-simplifier`, `pr-review-toolkit` | everything Rust, OpenTofu, provider overrides | Rust, `rust-analyzer-lsp`, OpenTofu, `op`, `agent-browser`, `feature-dev` |
| Claude plugins (jackin bakes `claude plugin marketplace add` + `claude plugin install` RUN lines, `derived_image.rs:305-344`) | `code-review`, `commit-commands`, `github`, `rust-analyzer-lsp` (all `@claude-plugins-official`); `jackin-dev@jackin-marketplace`; `tailrocks-skills@tailrocks-skills`; `caveman@caveman` (optional house style, tagged) | `github@claude-plugins-official` | `code-review`, `pr-review-toolkit` (`@claude-plugins-official`); `tailrocks-skills@tailrocks-skills` |
| Marketplaces | `jackin-project/jackin-marketplace`; `https://github.com/tailrocks/tailrocks-skills.git#v0.28.0`; `JuliusBrussee/caveman` | none | `https://github.com/tailrocks/tailrocks-skills.git#v0.28.0` |
| Codex skills (jackin bakes nothing for Codex; `[codex]` has only `model`/`providers`, conv B.5) | Dockerfile: `skills add` of `jackin-dev` and `improve` into `/home/agent/.agents/skills/`; `tailrocks-skills` skills-dir clone pinned `v0.28.0` | Dockerfile: copy agent-browser's bundled `skill-data/` to `/home/agent/.agents/skills/agent-browser/` (verify layout in M1-05b) | Dockerfile: `git clone --depth 1 --branch <tag>` of `tailrocks/review-crucible` into `/home/agent/.agents/skills/review-crucible`; tailrocks-skills clone `v0.28.0`; `.codex/agents/*.toml` staged in `/opt/jackin-role/codex-agents/`, copied by `hooks/source.sh` into `$CODEX_HOME/agents/` |
| `[docker]` | `min_profile = "standard"` (cargo needs crates.io + github.com); `dind` omitted, granted per lane by `[docker.grants] dind = "rootless"` in the M1-13 profiles (dev §3) | `min_profile = "standard"`, `dind = "none"`; network allowlist grant at workspace level (Linear, Google, GitHub, 1Password hosts) because `hardened` lacks Linear/Google and `--allowed-domains` refuses profiles (op §6) | none; `hardened` profile fits (model API + GitHub) |
| Hooks | `preflight.sh`: `mise trust /workspace`, `rtk init -g`, Codex skill presence check; no Context7 | `preflight.sh`: `agent-browser doctor --json`, refuse if Chrome missing, profile unwritable, or `SingletonLock` PID alive (op §9) | `source.sh`: copy staged Codex agents, idempotent, never touches `auth.json` |
| Env defaults | `CLAUDE_CODE_EFFORT_LEVEL=medium`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000`, `CLAUDE_CODE_NO_FLICKER=1`, `CAVEMAN_DEFAULT_MODE=ultra`, `RTK_TELEMETRY_DISABLED=1`; `TERMROCK_BLESS_PREVIEWS` never set by the image (tr §6) | `AGENT_BROWSER_PROFILE=/home/agent/.agent-browser-profile`, `AGENT_BROWSER_SESSION=operator`, `AGENT_BROWSER_SCREENSHOT_DIR=/workspace/evidence`, `CLAUDE_CODE_EFFORT_LEVEL=medium`, `CLAUDE_CODE_NO_FLICKER=1`; `OP_SERVICE_ACCOUNT_TOKEN` declared `interactive`, `skippable`, `secret` (value arrives via binding) | `CLAUDE_CODE_EFFORT_LEVEL=medium`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000`, `CLAUDE_CODE_NO_FLICKER=1` |
| Codex effort | not a manifest knob: `model_reasoning_effort = "medium"` in each lane's `CODEX_HOME/config.toml` (M1-13, Q-024) | same | same |
| Secrets it may hold | `gh` via `[github] auth_forward = "sync"`; provider login via per-agent `auth_forward = "sync"` (D-039) | browser profile (mounted, rw); `OP_SERVICE_ACCOUNT_TOKEN` per `jackin-exec` invocation, vault `jackin` read+write; `gh` forward; Linear workspace token only as `jackin-exec op read … | curl` for verification | `gh` forward only (review + comment) |
| Must never hold | Linear client secret or workspace tokens (D-035; the daemon reads them host-side), `OP_SERVICE_ACCOUNT_TOKEN`, browser profile, registry credentials, `CONTEXT7_API_KEY`, org-admin `GITHUB_TOKEN` (dev §4) | tokens for `Private`, `tailrocks`, `ChainArgos` vaults; personal access tokens on the human's GitHub; a second Google account in the profile; a `compat` Docker profile; plaintext of anything it `op item create`d (op §6) | write mount on `/workspace`; Linear token; `op`; browser profile; `APPROVE` (rev A.5) |
| Mounts (all from operator/workspace config; manifests cannot declare mounts, `mounts.mdx:85-110`) | workspace checkout (`~/.jackin/managed/<key>` from M3-03; `~/Projects/...` for hand-run M1/M2); named volumes for `~/.cargo/registry`, `~/.cargo/git`, `target/` per lane; persistent DinD data volume | `jackin config mount add agent-browser-profile --src ~/.jackin/agent-browser-profile --dst /home/agent/.agent-browser-profile --scope donbeave/crew-operator`, rw (Chrome writes cookies) — **operator config, not manifest** (op §3, §7); workspace = evidence dir | workspace `:ro` |
| Threat model | pushes to `jackin-project/jackin`, never merges without the per-PR "merge it"; issue text untrusted; DinD is a throwaway second daemon; supply chain = mise/cargo `--locked`, three marketplaces, tagged clones; termrock push credential bound only for M9-02/M9-03 launches; golden bless guarded only by the recorded human approval (dev §7, tr §6) | profile = the human account on Linear (admin) and GitHub (org owner); page content is untrusted with a shell behind it; credential creation is one-way (`> /dev/null`, verify with `jq 'has("value")'`); screenshots after secrets are masked, never of 1Password pages; one instance at a time (op §6) | PR content is untrusted; no compilation; two new trust anchors (`tailrocks-skills` tag, `review-crucible` tag); `gh` write scope is the whole blast radius; `source.sh` writes only `$CODEX_HOME/agents/` (rev A.6) |
| ROADMAP tasks served | M1-01, M1-02, M1-08, M1-13, M2-01..M2-06, M3-01..M3-06, M4-01..M4-05, M5-01, M5-02, M6-01..M6-03, M7-02, M8-01, M9-01..M9-04, M10-02, M11-01, M11-02 (dev §6, tr §3, §4) | M1-02a, M1-03, M1-06, M1-07, M1-09..M1-12, M2-07, M3-07, M4-06, M5-03, M6-04, M7-01, M7-03, M8-02, M9-05, M10-01, M10-03, M11-03 proof halves, plus the browser-proof items moved out of the six builder tasks (op §7) | M2-08, M3-08, M4-07, review halves of M5-03..M11-03 (rev A.1) |

### 3.2 Manifest sketches

```toml
# donbeave/jackin-crew-builder/jackin.role.toml
version = "v1alpha6"                     # [docker] needs it; v1alpha7 after M3-02
dockerfile = "Dockerfile"
agents = ["claude", "codex"]
[identity]
name = "Crew Builder"
[claude]
model = "claude-sonnet-4-6"              # lane overrides
plugins = ["code-review@claude-plugins-official", "commit-commands@claude-plugins-official",
  "github@claude-plugins-official", "rust-analyzer-lsp@claude-plugins-official",
  "jackin-dev@jackin-marketplace", "tailrocks-skills@tailrocks-skills", "caveman@caveman"]
[[claude.marketplaces]]
source = "jackin-project/jackin-marketplace"
[[claude.marketplaces]]
source = "https://github.com/tailrocks/tailrocks-skills.git#v0.28.0"
[[claude.marketplaces]]
source = "JuliusBrussee/caveman"
[codex]
[docker]
min_profile = "standard"                 # dind via [docker.grants] per lane
[hooks]
preflight = "hooks/preflight.sh"
[env.CLAUDE_CODE_EFFORT_LEVEL]
default = "medium"
[env.CLAUDE_CODE_MAX_OUTPUT_TOKENS]
default = "64000"
[env.CLAUDE_CODE_NO_FLICKER]
default = "1"
[env.CAVEMAN_DEFAULT_MODE]
default = "ultra"
[env.RTK_TELEMETRY_DISABLED]
default = "1"
```

```toml
# donbeave/jackin-crew-operator/jackin.role.toml
version = "v1alpha6"
dockerfile = "Dockerfile"
agents = ["claude", "codex"]
[identity]
name = "Crew Operator"
[claude]
model = "claude-sonnet-4-6"
plugins = ["github@claude-plugins-official"]
[codex]
[docker]
min_profile = "standard"
dind = "none"
[hooks]
preflight = "hooks/preflight.sh"         # agent-browser doctor; SingletonLock check
[env.AGENT_BROWSER_PROFILE]
default = "/home/agent/.agent-browser-profile"
[env.AGENT_BROWSER_SESSION]
default = "operator"
[env.AGENT_BROWSER_SCREENSHOT_DIR]
default = "/workspace/evidence"
[env.OP_SERVICE_ACCOUNT_TOKEN]
interactive = true
skippable = true                         # laptop: value comes through the jackin-exec binding
secret = true
[env.CLAUDE_CODE_EFFORT_LEVEL]
default = "medium"
[env.CLAUDE_CODE_NO_FLICKER]
default = "1"
```

```toml
# donbeave/jackin-crew-reviewer/jackin.role.toml
version = "v1alpha5"                     # no [docker]
dockerfile = "Dockerfile"
agents = ["claude", "codex"]
[identity]
name = "Crew Reviewer"
[claude]
model = "claude-sonnet-4-6"
plugins = ["code-review@claude-plugins-official", "pr-review-toolkit@claude-plugins-official",
  "tailrocks-skills@tailrocks-skills"]
[[claude.marketplaces]]
source = "https://github.com/tailrocks/tailrocks-skills.git#v0.28.0"
[codex]                                  # review-crucible + tailrocks-skills via Dockerfile and hook
[hooks]
source = "hooks/source.sh"
[env.CLAUDE_CODE_EFFORT_LEVEL]
default = "medium"
[env.CLAUDE_CODE_MAX_OUTPUT_TOKENS]
default = "64000"
[env.CLAUDE_CODE_NO_FLICKER]
default = "1"
```

Reviewer verdict flow (rev A.5): a PR *review* through the Reviews API
(`gh api repos/{o}/{r}/pulls/{n}/reviews -f commit_id=… -f event=… --input
comments.json`), never `gh pr comment`; `REQUEST_CHANGES` when a `blocking:`
finding remains, `COMMENT` otherwise, never `APPROVE`; findings for Linear
emitted in task-format checklist syntax in the final message; preflight
skips closed, draft, or already-reviewed PRs. `review-crucible` cannot be a
Claude plugin until some marketplace lists it (its README points at a
non-existent `tailrocks/tailrocks-marketplace`; `jackin role validate`
resolves every plugin id against a `marketplace.json`, rev A.3), so on
Claude the reviewer runs the official plugins plus `tailrocks-review-pr`.

## 4. Publishing and trust

- **Local-only builds until M10** (conv B.3). Omit `published_image`; every
  load is `BuildFromWorkspace` from `~/.jackin/roles/donbeave/<name>/default`;
  `jackin load donbeave/crew-<p> --rebuild` after each role commit. No
  registry secrets on the laptop.
- **Default branch, not `--role-branch`.** `--role-branch` ignores
  `published_image` and always raises the branch-trust dialog, which needs
  the rich renderer the daemon lacks (`launch_pipeline.rs:614-640`,
  `progress.rs:212-222`). There is no local-path role loading. So the roles
  work on `main`, and Q-020's "roles use `feat/agent-browser`" is dropped.
  This changes Q-022's answer (§6).
- **Trust** is per selector, no wildcard (conv B.4): `jackin config trust
  grant donbeave/crew-builder`, `…-operator`, `…-reviewer`, once per host.
  An untrusted role in a non-interactive launch fails with "role trust
  prompt"; the daemon reports a missing grant as a validation failure.
- **M10:** add `published_image = "docker.io/donbeave/jackin-crew-<p>:latest"`
  (the `donbeave` Docker Hub user exists), the `publish-image.yml` caller of
  `jackin-role-action`, and two Hub secrets; the workflow builds amd64+arm64
  and signs keyless with cosign. jackin does not verify cosign on pull;
  freshness is the `jackin.role.git.sha` label versus the cached checkout.

## 5. Credentials wiring

| Role | Mechanism | Scope |
| --- | --- | --- |
| builder | `[github] auth_forward = "sync"` (host `~/.config/gh/` copied in, `gh auth setup-git`, host never written); per-agent provider `auth_forward = "sync"` from the lane's `CLAUDE_CONFIG_DIR` / `CODEX_HOME` (M1-13) | the human's `gh` identity until the GitHub App (M7-01) supplies a per-repo token |
| operator | workspace × role env entry in **operator config** (not manifest): `OP_SERVICE_ACCOUNT_TOKEN = { op = "op://tailrocks/op-service-account-jackin-operator/credential", on_demand = true }`; the agent runs `jackin-exec op item create …`; the human confirms in the picker | 1Password service account with `read_items` + `write_items` on vault **`jackin` only**; cannot reach `Private`; token stored in `tailrocks` (op §4) |
| reviewer | `gh` forward only | review + comment |

**Correction to ROADMAP** (§4 role table "host-side `op`" and §7 Q-018 row
"executed host-side"; the brief refers to this as §6): `jackin-exec` does not
run commands on the host. It resolves `on_demand` `op://` values on the host
through `host.sock` and **injects them into the one in-container command**,
redacting its output (`exec_host.rs:1-35`, `jackin-exec.mdx:9-15`). The
host-side "approved host actions" bridge is design-only. So on the laptop
the operator's `op` runs inside the container with a token that exists only
for that invocation; the desktop-app socket integration cannot work from a
container at all (op §4). Two service accounts, two rotation units: the
operator's write token (before M1-03) and the daemon's read token (M10-01).
`jackin-exec` has had no live smoke pass and lacks the `SO_PEERCRED` check on
Docker Desktop; M1-03 is the proof, and a fallback to a launch-time token
for one session must be logged as a deviation (op §9).

## 6. Conflicts to resolve

| # | Conflict | Recommended answer |
| --- | --- | --- |
| 1 | termrock `CONTRIBUTING.md` is trunk-only (never a branch, never a PR) vs Q-020 `feat/managed-execution` and D-034 PRs; D-030 also wants a reviewer sign-off on agent-authored code (tr §1) | Amend `CONTRIBUTING.md` with an "agent-authored changes" clause: branch, PR to `main`, `crew-reviewer` review, human merges. Trunk push from an agent bypasses the only review gate and hands the builder a `main` push credential on a shared design system. Human decision; Q-020 stands. |
| 2 | D-032 consequence "roles used to implement … must ship `agent-browser`" vs D-045 and least privilege (dev §5) | Amend as in §1: the operator role performs the browser proof as a checklist item; the six builder tasks' browser lines move to the corresponding proof runs (M2-07, M5-03, M6-04, M7-03, M8-02, M10-03). |
| 3 | Q-022 assumes `--role-branch` loads for the daemon (conv B.3, B.8) | Rewrite: roles load from their default branch with trust pre-granted per host by `jackin config trust grant`; `--role-branch` is unusable non-interactively; the daemon reports a missing grant as a validation failure. |
| 4 | Q-018 says "host-side `op`" (op §4) | Rewrite: 1Password service account scoped to vault `jackin`, delivered per invocation by a `jackin-exec` on-demand binding into the in-container `op`; daemon read-only account from M10. |
| 5 | ROADMAP M1-04 (add `agent-browser` to `the-architect`) contradicts D-045 | Drop M1-04. |
| 6 | ROADMAP M1-05 creates one role in `jackin-project` | Becomes a template task plus three role-creation tasks (§7); `M1-06` depends on the operator task; every `the-architect` / `the-operator` / `agent-smith` role column becomes `crew-builder` / `crew-operator` / `crew-reviewer`. |
| 7 | jackin bakes plugins for Claude only; `codex plugin add` cannot run in the role Dockerfile (the `codex` binary arrives in jackin's derived stage) and `CODEX_HOME` is synced from the host, shadowing anything baked there (conv B.5) | Skills as files in `/home/agent/.agents/skills/` pinned to tags; Codex custom agents ride `hooks/source.sh`. Record a jackin feature request for `[codex].skills` outside this effort's task list. |
| 8 | Chrome `SingletonLock`: two processes on one profile collide (op §3, §9) | One operator instance at a time: preflight refuses when the lock's PID is alive; M3-05's per-host cap gains a per-role cap of 1 for `crew-operator`; the human never keeps a host `agent-browser --profile` daemon alive while a container runs. |
| 9 | Reviewer identity: M2-08 `verify.sh` expects "a review from the app account", but the GitHub App is M7-01 | Until M7-01 the review is posted by the forwarded `gh` identity; `verify.sh` for M2-08..M4-07 checks for a review by the configured reviewer login. |

## 7. Per-role creation checklist and ROADMAP task deltas

Checklist per role (conv B.7):

1. `gh repo create donbeave/jackin-crew-<purpose> --public --template donbeave/jackin-role-template`; `jackin role create` if the scaffold is preferred, then overlay.
2. `jackin.role.toml` per §3.2: no `published_image`; only official, `jackin-marketplace`, `tailrocks-skills`, and (builder) `caveman` plugin entries; allow-list in `scripts/marketplace-audit.sh` updated to match.
3. Dockerfile: construct `0.36-trixie@sha256:41815a35…`; one ARG + one RUN per tool; `--mount=type=secret,id=github_token`; no `latest`; skills cloned by tag.
4. `AGENTS.md`: threat model naming every new trust anchor, hard rules, conventions; `CLAUDE.md -> AGENTS.md`; `AGENTS.md.d/` runtime-neutral instructions.
5. `hooks/preflight.sh` or `hooks/source.sh` as in §3.1.
6. `jackin role validate .`; push; `jackin-role-action` CI green (hadolint, amd64 build).
7. On each host: `jackin config trust grant donbeave/crew-<purpose>`; `jackin load donbeave/crew-<purpose> --dry-run --format json` shows the resolved repo and `BuildFromWorkspace`.
8. Record the role here and in the lane table (`ROADMAP.md` §5).
9. M10: `published_image`, `publish-image.yml`, Hub secrets; first publish is a cold build.

Task deltas (replace M1-04 and M1-05; role column for these bootstrap tasks
is `the-architect`, unmodified, since the builder does not exist yet):

| id | title | depends_on | role | lane | size | verification |
| --- | --- | --- | --- | --- | --- | --- |
| M1-04 | *dropped* | — | — | — | — | — |
| M1-04a | Create `donbeave/jackin-role-template` | M1-02 | the-architect | L4 (codex, GPT-5.6 Sol, `~/.codex`) | S | `verify.sh`: repo is a GitHub template, has no `jackin.role.toml`, ships the preamble, `AGENTS.md.d/00-common.md`, `hooks/source.sh`, audit script, `renovate.json`, three workflows; hadolint clean |
| M1-05a | Create `donbeave/crew-builder` | M1-04a | the-architect | L4 (codex, GPT-5.6 Sol, `~/.codex`) | M | `verify.sh`: `jackin role validate` passes; `jackin load donbeave/crew-builder --agent claude` starts; inside: `mise install` in a jackin checkout is a no-op, `cargo nextest --version`, `cargo public-api --version`, `rustup run 1.97.1 cargo --version` exit 0; no `agent-browser`, no `op` on PATH |
| M1-05b | Create `donbeave/crew-operator` | M1-04a | the-architect | L5 (codex, GPT-5.6 Terra, `~/.codex-chainargos`) | M | `verify.sh`: validate passes; `jackin load donbeave/crew-operator --agent claude` starts; inside: `op --version`, `gh --version`, `agent-browser --version`, `agent-browser doctor --json` exit 0; profile path writable; no `cargo` on PATH; `agent-browser install --with-deps` succeeded non-interactively at build |
| M1-05c | Create `donbeave/crew-reviewer` | M1-04a | the-architect | L6 (codex, GPT-5.6 Luna, `~/.codex-chainargos2`) | S | `verify.sh`: validate passes; loads on both runtimes; `/home/agent/.agents/skills/review-crucible/SKILL.md` exists at the pinned tag; `$CODEX_HOME/agents/` populated after `source.sh`; no `cargo`, no `op`, no `agent-browser` |
| M1-05d | Grant trust and configure host bindings | M1-05a, M1-05b, M1-05c | the-operator | L3 (claude, Sonnet 5, `~/.claude`) | S | `verify.sh`: `jackin config` shows `trusted = true` for the three selectors; the profile mount scoped to `donbeave/crew-operator` exists; the on-demand `OP_SERVICE_ACCOUNT_TOKEN` entry exists at workspace × role; three `--dry-run` loads report `BuildFromWorkspace` |

Other row edits: M1-06 `depends_on` = M1-05b, M1-05d; M1-13 adds
`[docker.grants] dind = "rootless"` to the builder lanes and the operator
network allowlist grant; M2-04, M5-02, M6-03, M7-02, M8-01, M10-02 lose their
browser line, which is added to M2-07, M5-03, M6-04, M7-03, M8-02, M10-03
respectively; M3-05 gains the per-role cap (§6 item 8); all role columns
renamed per §6 item 6; §8 delivery lists gain M1-04a, M1-05a..c as `goal`
and M1-05d as `prompt`.

## 8. Proposed decision text

```markdown
## D-046 — 2026-08-27 — PROPOSED — Three `crew` roles under `donbeave` build this product

**Decision.** The product is built by exactly three jackin roles in the
`donbeave` GitHub account, family name `crew`: `donbeave/crew-builder`
(repository `donbeave/jackin-crew-builder`; jackin, termrock, and ecosystem
implementation; Rust toolchain; no browser), `donbeave/crew-operator`
(`donbeave/jackin-crew-operator`; Linear, GitHub settings, 1Password items,
and every browser proof; `agent-browser`, `op`; no Rust), and
`donbeave/crew-reviewer` (`donbeave/jackin-crew-reviewer`; read-only pull
request review posted through the GitHub Reviews API; no compiler). All
three run Claude Code and Codex, are built from the digest-pinned
`projectjackin/construct:0.36-trixie` base, share a text-only template
repository `donbeave/jackin-role-template` (not a base image), load from
their default branch with trust pre-granted per host, and stay unpublished
until M10. Specifications live in `concept/roles.md`.

**Rationale.** Each role holds one axis of privilege: code push, the human's
UI sessions plus one vault, or comment-only review. Combining any two
creates an attack path no task needs (`analysis/roles/`). Tooling overlap
makes one Rust role sufficient for three repositories.

**Consequences.**

- D-032's consequence "roles used to implement this project must ship
  `agent-browser`" is amended to "the role that performs the browser proof
  ships it"; browser proofs are operator checklist items on the same issue.
- ROADMAP M1-04 is dropped; M1-05 becomes M1-04a and M1-05a..d; role
  columns are renamed; Q-018, Q-020 (role branches), and Q-022 are
  rewritten as in `concept/roles.md` §6.
- The operator writes to 1Password through a service account scoped to
  vault `jackin`, delivered per invocation by a `jackin-exec` binding.
- termrock's `CONTRIBUTING.md` needs an agent-authored-changes clause
  before M9-02 starts; the human decides.
- Q-016 is closed.
```
