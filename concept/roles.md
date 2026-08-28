> **Amended by D-048 (2026-08-27):** jackin development always uses the
> existing `jackin-the-architect` role. In this document, `crew-builder`'s
> scope is therefore termrock, ecosystem authoring, and the role
> repositories — not jackin. Read "builder serves jackin tasks" below as
> "the-architect serves jackin tasks".
>
> **Adopted by D-053 (2026-08-27):** the role set proposed here (family
> `crew`: `crew-builder`, `crew-operator`, `crew-reviewer`; template
> repository; local-only builds until the server milestone; role `host` for
> human steps) and the D-032 amendment (browser proof by the operator role)
> are the working contract. The role set is adopted under D-053; §8 points at
> its normative specification instead of restating it (D-103).

# Roles that build this product (Q-016, D-045)

Status: **ADOPTED (D-053), 2026-08-27**. Consolidates the four analyses
under `analysis/roles/` into one role set, one naming scheme, one spec per
role, and the contract that D-053 adopted. Any item may be overridden by a
later revision to `SPEC.md`. Sources are cited as `dev §n`
(`analysis/roles/jackin-dev-needs.md`), `tr §n`
(`analysis/roles/termrock-and-docs-needs.md`), `op §n`
(`analysis/roles/operator-needs.md`), and `rev A.n` / `conv B.n`
(`analysis/roles/review-role-and-conventions.md`). Q-017..Q-024 were the
questions in `ROADMAP.md` §7; their recommended answers, including those in
§6 below, are adopted (D-053).

## 1. The set: three roles

| Role | Purpose | Toolchain | Credentials it can touch | Blast radius |
| --- | --- | --- | --- | --- |
| **builder** | implements jackin, termrock, and ecosystem documents | Rust (mise-managed), bun/node, python for REUSE, DinD when granted | `gh` session (push, open PR), provider login | a bad commit on a branch that still needs review and CI |
| **operator** | Linear, GitHub settings, 1Password items, browser proofs | `agent-browser` + Debian Chromium (no Chrome for Testing on arm64, D-077), `op`, node; no Rust | browser profile (= the human on Linear and GitHub), on-demand service-account token for vault `jackin` | the human's Linear workspace, GitHub App/OAuth settings, one vault |
| **reviewer** | reviews PRs, posts verdicts | none; node for Claude plugins | `gh` session with review/comment scope | a misleading review the human reads |

Why three and not one or two:

- **One axis of privilege per role.** The builder holds the ability to push
  code; the operator holds the human's browser session and a vault write
  path; the reviewer holds the same repo-scope `gh` token as the builder, limited to reviews by policy and a read-only mount (D-079). Any merge of two axes
  creates a path that none of the tasks need: builder + browser turns a
  prompt injection through issue text (M4-07 calls it untrusted) into
  "push a malicious PR, then approve and merge it in the browser" (dev §5);
  reviewer + compiler executes the PR author's `build.rs` and proc-macros
  inside a container that also holds `gh` credentials (rev A.4).
- **Tooling overlap decides the merges that do happen.** termrock and jackin
  Rust work share the whole mise toolchain and the `tailrocks-skills` plugin;
  termrock adds only what `mise install` resolves from its own lockfile
  (tr §5). Ecosystem authoring needs git, gh, bash — a strict subset (tr §4).
  So one Rust role serves termrock and ecosystem authoring; jackin itself is
  served by `the-architect` (D-048), so the builder pre-warms termrock's
  toolchain, not jackin's. The operator and reviewer
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
task lane is L1..L6 (dev §2, op §5, rev A.1); manifests carry no `[claude].model`;
the lane sets model and effort by workspace env and the Codex hook
(ROADMAP §4, D-078); no `published_image` before M10
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
| apt | `build-essential libssl-dev openssl pkg-config cmake xxd` (dev §7) | `unzip openssl chromium fonts-noto-cjk fonts-noto-color-emoji`; `op` 2.39.0 by direct download, not the apt repository (it serves only the current version, so a pinned `1password-cli=2.39.0` fails on the next release, D-090): `ARG OP_CLI_VERSION=2.39.0`, `ARG OP_CLI_SHA256_ARM64=829baeff1c07e055cfa132031b1d9f2282ccdf5076258e482caf2fda70aea5d0`, `ARG OP_CLI_SHA256_AMD64=6fba7f376b6c6dec49f41b06408930a43ad064cce103c6a2ce5b3d0413a86434`, `RUN arch=$(dpkg --print-architecture) && curl -fsSLo /tmp/op.zip "https://cache.agilebits.com/dist/1P/op2/pkg/v${OP_CLI_VERSION}/op_linux_${arch}_v${OP_CLI_VERSION}.zip" && echo "<sha for arch>  /tmp/op.zip" \| sha256sum -c && unzip -o /tmp/op.zip -d /usr/local/bin op && chmod 755 /usr/local/bin/op` (`cache.agilebits.com` is a trust anchor named in `AGENTS.md`; op §2); Debian Chromium on both architectures, never `agent-browser install` (Chrome for Testing has no Linux arm64 build, D-077) | none beyond construct |
| mise | pre-warm exactly termrock's own `mise.toml` `[tools]` (tr §6: cargo-nextest 0.9.140, cargo-semver-checks 0.48.0, wasm-pack 0.15.0, git-cliff 2.13.1, gitleaks 8.30.1, bun, node, python, uv, reuse) plus `rustup toolchain install 1.97.1` (termrock's `rust-toolchain.toml`) beside the image default, nightly minimal, `wasm32-unknown-unknown`, `rustup component add rust-analyzer clippy rustfmt`, and `cargo binstall cargo-public-api@0.52.0 lychee`; `MISE_TRUSTED_CONFIG_PATHS=/workspace:/tmp/jackin-mise`. jackin's own toolchain is not pre-warmed here: jackin work is served by `the-architect` (D-048). | `node@24.19.0` only (op §2) | `node@24.19.0` only (rev A.6) |
| npm / binstall | `skills` CLI (Codex/Amp skill installs); `cargo binstall lychee`; drop `cargo-watch` | `npm i -g agent-browser@0.35.1` only; the browser is `/usr/bin/chromium` via `AGENT_BROWSER_EXECUTABLE_PATH` (D-077) | none |
| Removed vs the-architect | OpenTofu, Context7/`ctx7`, headroom, amp/opencode/kimi/grok, `feature-dev`, `security-guidance`, `claude-md-management`, `code-simplifier`, `pr-review-toolkit` | everything Rust, OpenTofu, provider overrides | Rust, `rust-analyzer-lsp`, OpenTofu, `op`, `agent-browser`, `feature-dev` |
| Claude plugins (jackin bakes `claude plugin marketplace add` + `claude plugin install` RUN lines, `derived_image.rs:305-344`) | `code-review`, `commit-commands`, `github`, `rust-analyzer-lsp` (all `@claude-plugins-official`); `jackin-dev@jackin-marketplace`; `tailrocks-skills@tailrocks-skills`; `caveman@caveman` (optional house style, tagged) | `github@claude-plugins-official` | `code-review`, `pr-review-toolkit` (`@claude-plugins-official`); `tailrocks-skills@tailrocks-skills` |
| Marketplaces | `jackin-project/jackin-marketplace`; `tailrocks/tailrocks-skills` (slug form, as the-architect uses; jackin's `github_slug` has no `#ref` syntax and validates HEAD, D-078); `JuliusBrussee/caveman` | none | `tailrocks/tailrocks-skills` |
| Codex skills (jackin bakes nothing for Codex; `[codex]` has only `model`/`providers`, conv B.5) | Dockerfile: `skills add` of `jackin-dev` and `improve` into `/home/agent/.agents/skills/`; `tailrocks-skills` skills-dir clone pinned to commit `ARG TAILROCKS_SKILLS_SHA` (no `v0.28.0` tag exists; newest tag is `v0.25.0`; the SHA of HEAD is captured by M1-05a and recorded in its folder) | Dockerfile: copy agent-browser's bundled `skill-data/` to `/home/agent/.agents/skills/agent-browser/` (verify layout in M1-05b) | Dockerfile: `tailrocks/review-crucible` pinned by commit `ARG REVIEW_CRUCIBLE_SHA=5936f0e069946db0ee4408e72122b134800336e4` (the repository has no tags; default branch `port/cross-agent-dry`): under `USER root` `install -d -o agent -g agent /opt/review-crucible`, then under `USER agent` `git init /opt/review-crucible && git -C /opt/review-crucible fetch --depth 1 <url> "$REVIEW_CRUCIBLE_SHA" && git -C /opt/review-crucible checkout --detach FETCH_HEAD && git -C /opt/review-crucible rev-parse HEAD > /opt/review-crucible/.jackin-pin` (the checkout is owned by `agent`, so git never refuses it as 'dubious ownership' and no `safe.directory` entry is needed; if the directory must stay root-owned, `git config --system --add safe.directory /opt/review-crucible` is the alternative), then `ln -s /opt/review-crucible/skills/review-crucible /home/agent/.agents/skills/review-crucible`; tailrocks-skills clone pinned to `TAILROCKS_SKILLS_SHA`; `.codex/agents/*.toml` staged in `/opt/jackin-role/codex-agents/`, copied by `hooks/source.sh` into `$CODEX_HOME/agents/` |
| `[docker]` | `min_profile = "standard"` (cargo needs crates.io + github.com); `dind` omitted, granted per role by `[docker.grants] dind = "privileged"` in the `the-architect` and `donbeave/crew-builder` files of `tasks/M1-13/grants/<role>.toml` (rootless is unproven under OrbStack and jackin's sidecar spec has no seccomp or capability knob; M1-13's `dind.out` is the tier of record, D-078). Grants are per role, never per lane: a lane is runtime plus model plus account home and every lane serves builder, operator, and reviewer tasks, so the host session merges the lane template `tasks/M1-13/lanes/L<n>.toml` and then the task's `tasks/M1-13/grants/<role>.toml` into each per-task workspace. | `min_profile = "standard"`, `dind = "none"`; the network allowlist grant (Linear, Google, GitHub, 1Password hosts) lives in the `donbeave/crew-operator` file of `tasks/M1-13/grants/<role>.toml` and is merged into the workspace, because `hardened` lacks Linear/Google and `--allowed-domains` refuses profiles (op §6) | none; `hardened` profile fits (model API + GitHub); the `donbeave/crew-reviewer` file of `tasks/M1-13/grants/<role>.toml` grants nothing |
| Hooks | `preflight.sh`: `mise trust /workspace`, `rtk init -g`, Codex skill presence check; no Context7; `source.sh`: idempotent write of `model`/`model_reasoning_effort = "medium"` into `$CODEX_HOME/config.toml` from `JACKIN_LANE_CODEX_MODEL` (D-078). Every role's `source.sh` opens with `CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"` (jackin's own entrypoint uses that default, so the variable is not guaranteed in the hook's environment and an unset one would write to `/agents`), never sets `set -e` and never calls `exit` — it is sourced by the entrypoint before `exec`, so either would kill the launch — and is a no-op when `JACKIN_LANE_CODEX_MODEL` is unset | `preflight.sh`: `agent-browser doctor --json` (honours the executable env var), refuse if profile unwritable; remove `$AGENT_BROWSER_PROFILE/SingletonLock`, `SingletonSocket` and `SingletonCookie` unconditionally before launching Chromium (the `crew-operator` cap of 1 guarantees no live holder, and a PID check is meaningless across PID namespaces: Chromium writes the lock as `<hostname>-<pid>`, the hostname is the container id, so a stale lock makes the next container refuse to start with "profile in use on another computer"); `agent-browser open https://linear.app` + `get url`, on a login page `agent-browser state load /home/agent/.agent-browser-profile/state.json` and re-check; if it is still a login page, or the profile directory or `state.json` is absent, print `[operator-preflight] WARNING: no browser session — run the M1-06 re-login` and exit 0, never non-zero (D-077). The hook refuses the launch only when the profile is unwritable; a missing or logged-out session is never a launch gate, because jackin's entrypoint exits the container on a non-zero preflight and the profile mount itself is added only by M1-05d, which depends on M1-05b. Proving the session is logged in belongs to M1-06's verify and to each operator task's own checklist; `source.sh` as builder for Codex lanes, including the same `CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"` default and the no-`set -e`, no-`exit` rule | `source.sh`: copy staged Codex agents and write the lane's `config.toml` keys, idempotent, never touches `auth.json`; same `CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"` default, no `set -e`, no `exit`, no-op without `JACKIN_LANE_CODEX_MODEL`, as in the builder column |
| Env defaults | `CLAUDE_CODE_EFFORT_LEVEL=medium`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000`, `CLAUDE_CODE_NO_FLICKER=1`, `CAVEMAN_DEFAULT_MODE=ultra`, `RTK_TELEMETRY_DISABLED=1`; `TERMROCK_BLESS_PREVIEWS` never set by the image (tr §6) | `AGENT_BROWSER_PROFILE=/home/agent/.agent-browser-profile`, `AGENT_BROWSER_SESSION=operator`, `AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium`, `AGENT_BROWSER_SCREENSHOT_DIR=/workspace/evidence`, `CLAUDE_CODE_EFFORT_LEVEL=medium`, `CLAUDE_CODE_NO_FLICKER=1`; `OP_SERVICE_ACCOUNT_TOKEN` is **not** declared in the manifest (the value arrives at exec time via the on-demand binding; a launch-time prompt would only stall the non-interactive load, D-078) | `CLAUDE_CODE_EFFORT_LEVEL=medium`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000`, `CLAUDE_CODE_NO_FLICKER=1` |
| Codex effort | not a manifest knob: written in-container by `hooks/source.sh` into `$CODEX_HOME/config.toml` from workspace env (M1-13, Q-024, D-078); the host `config.toml` is not synced, only `auth.json` | same | same |
| Secrets it may hold | `gh` via `[github] auth_forward = "sync"`; provider login via per-agent `auth_forward = "sync"` (D-039) | browser profile (mounted, rw); `OP_SERVICE_ACCOUNT_TOKEN` per `jackin-exec` invocation, vault `jackin` read+write; `gh` forward; Linear workspace token only as `jackin-exec op read … | curl` for verification | `gh` forward only (review + comment) |
| Must never hold | Linear client secret or workspace tokens (D-035; the daemon reads them host-side), `OP_SERVICE_ACCOUNT_TOKEN`, browser profile, registry credentials, `CONTEXT7_API_KEY`, org-admin `GITHUB_TOKEN` (dev §4) | tokens for `Private`, `tailrocks`, `ChainArgos` vaults; personal access tokens on the human's GitHub; a second Google account in the profile; a `compat` Docker profile; plaintext of anything it `op item create`d (op §6) | write mount on `/workspace`; Linear token; `op`; browser profile; `APPROVE` (rev A.5) |
| Mounts (all from operator/workspace config; manifests cannot declare mounts, `mounts.mdx:85-110`) | workspace checkout (`~/.jackin/managed/<key>` from M3-03; `~/Projects/...` for hand-run M1/M2); per-lane host bind directories declared as `[[mounts]]` in the lane template and applied one by one with `jackin workspace edit task-<id> --mount <src>:<dst>` (jackin mounts are bind-only; a named volume cannot be declared): `~/.jackin/cache/L<n>/cargo-registry:/home/agent/.cargo/registry`, `~/.jackin/cache/L<n>/cargo-git:/home/agent/.cargo/git`, `~/.jackin/cache/L<n>/target:/home/agent/cargo-target`, with `[env] CARGO_TARGET_DIR=/home/agent/cargo-target` in the same template so the build writes into the mounted directory. One directory per lane, so the per-Codex-home cap of 1 and the distinct `~/.claude` lanes L1..L3 keep a single writer each, and a teardown no longer discards the fetch and the build; persistent DinD data volume | `jackin config mount add agent-browser-profile --src ~/.jackin/agent-browser-profile --dst /home/agent/.agent-browser-profile --scope donbeave/crew-operator`, rw (Chrome writes cookies) — **operator config, not manifest** (op §3, §7); workspace = evidence dir | workspace `:ro` |
| Threat model | pushes to `jackin-project/jackin`, merges its own PR through the forwarded `gh` only when the task text says so (the task prompt is the per-PR "merge it", D-055, D-079); issue text untrusted; DinD is a throwaway second daemon; supply chain = mise/cargo `--locked`, three marketplaces, tagged clones; termrock push credential bound only for M9-02/M9-03 launches; golden bless performed only by the host session under the pre-approval of D-075, never by the image (dev §7, tr §6) | profile = the human account on Linear (admin) and GitHub (org owner); page content is untrusted with a shell behind it; credential creation is one-way (`> /dev/null`, verify with `jq -e '(.value // "") | length > 0'` (D-081)); screenshots after secrets are masked, never of 1Password pages; one instance at a time (op §6) | PR content is untrusted; no compilation; two new trust anchors (`tailrocks-skills` commit, `review-crucible` commit); `gh` write scope is the whole blast radius; `source.sh` writes only `$CODEX_HOME/agents/` and the `config.toml` model keys (rev A.6, D-078) |
| ROADMAP tasks served | M1-01, M1-02, M1-08, M1-13, M2-01..M2-06, M3-01..M3-06, M4-01..M4-05, M5-01, M5-02, M6-01..M6-03, M7-02, M8-01, M9-01..M9-04, M10-02, M11-02 (dev §6, tr §3, §4) | M1-02a, M1-03, M1-06, M1-07, M1-09..M1-12, M2-07, M3-07, M4-06, M5-03, M6-04, M7-01, M7-03, M8-02, M9-05, M10-01, M10-03, M11-01 (verify-and-record, D-090), M11-03 proof halves, plus the browser-proof items moved out of the six builder tasks (op §7) | M2-08, M3-08, M4-07, review halves of M5-03..M11-03 (rev A.1) |

### 3.2 Manifest sketches

```toml
# donbeave/jackin-crew-builder/jackin.role.toml
version = "v1alpha6"                     # [docker] needs it; v1alpha7 after M3-02
dockerfile = "Dockerfile"
agents = ["claude", "codex"]
[identity]
name = "Crew Builder"
[claude]                                 # no model: the lane sets it (D-078)
plugins = ["code-review@claude-plugins-official", "commit-commands@claude-plugins-official",
  "github@claude-plugins-official", "rust-analyzer-lsp@claude-plugins-official",
  "jackin-dev@jackin-marketplace", "tailrocks-skills@tailrocks-skills", "caveman@caveman"]
[[claude.marketplaces]]
source = "jackin-project/jackin-marketplace"
[[claude.marketplaces]]
source = "tailrocks/tailrocks-skills"
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
[claude]                                 # no model: the lane sets it (D-078)
plugins = ["github@claude-plugins-official"]
[codex]
[docker]
min_profile = "standard"
dind = "none"
[hooks]
preflight = "hooks/preflight.sh"         # agent-browser doctor; Singleton* removal
[env.AGENT_BROWSER_PROFILE]
default = "/home/agent/.agent-browser-profile"
[env.AGENT_BROWSER_SESSION]
default = "operator"
[env.AGENT_BROWSER_SCREENSHOT_DIR]
default = "/workspace/evidence"
[env.AGENT_BROWSER_EXECUTABLE_PATH]
default = "/usr/bin/chromium"            # Debian Chromium, D-077
# OP_SERVICE_ACCOUNT_TOKEN is never declared here: on-demand binding in
# ~/.config/jackin/config.toml (D-078); EnvVarDecl has no `secret` key and an
# interactive declaration would raise a launch prompt (D-090).
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
[claude]                                 # no model: the lane sets it (D-078)
plugins = ["code-review@claude-plugins-official", "pr-review-toolkit@claude-plugins-official",
  "tailrocks-skills@tailrocks-skills"]
[[claude.marketplaces]]
source = "tailrocks/tailrocks-skills"
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
with one JSON payload — `jq -n --arg c "$review_sha" --arg b "$(cat
review.md)" --slurpfile cm comments.json '{commit_id:$c,event:"COMMENT",body:$b,comments:$cm[0]}'
| gh api -X POST repos/{o}/{r}/pulls/{n}/reviews --input -` (`-f` cannot be
mixed with `--input`) — never `gh pr comment`; `commit_id` is always the
SHA given in the task (line 2 of the staged `.jackin/task/pr.txt`), never
`gh pr view` head, because concurrent pushes move the head while the
review is written, and the diff reviewed is `git diff <line 3>..<line 2>`
(D-091); the event is always `COMMENT` while
the reviewer's `gh` login equals the PR author (every review before M8-01;
GitHub returns 422 for `REQUEST_CHANGES` and `APPROVE` on one's own PR and
a 422 is never retried with the same event); the verdict is the first body
line `verdict: REQUEST_CHANGES|COMMENT` plus `blocking:`/`major:`/`minor:`
prefixes; the real `REQUEST_CHANGES` event only when `gh api user` login
differs from the PR author; never `APPROVE` (D-079); findings for Linear
emitted in task-format checklist syntax in the final message and appended
to the issue by the host session; preflight skips closed PRs and PRs
already reviewed by this login at the task's `review_sha` (one rolling PR
per repository is reviewed once per milestone, D-074), drafts are accepted. `review-crucible` cannot be a
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
  work on `main`: `donbeave/jackin-crew-*` commit directly to `main`,
  `jackin-the-architect` merges its PR in the same task, and every role
  change ends with `jackin load <role> --rebuild` (D-074); the earlier
  "roles use `feat/agent-browser`" wording is dropped.
  This changes Q-022's answer (§6).
- **Trust** is per selector, no wildcard (conv B.4): `jackin config trust
  grant donbeave/crew-builder`, `…-operator`, `…-reviewer`, once per host.
  An untrusted role in a non-interactive launch fails with "role trust
  prompt"; the daemon reports a missing grant as a validation failure.
- **M11 (M11-02):** add `published_image = "docker.io/donbeave/jackin-crew-<p>:latest"`
  (the `donbeave` Docker Hub user exists), the `publish-image.yml` caller of
  `jackin-role-action` with explicit GitHub-hosted `runner-*` inputs
  (`publish.yml` defaults them to `velnor-target-mvp`, D-064, D-089), and
  two Hub secrets; the workflow builds amd64+arm64 and signs keyless with
  cosign. The publish workflow's validator comes from jackin's `preview`
  release built from `main`; a `v1alpha7` manifest therefore needs the
  jackin merge M11-01a before the first publish, and the role `ci.yml`
  (validator `latest-build`) is expected red from M3-02a until then
  (D-089). jackin does not verify cosign on pull; freshness is the
  `jackin.role.git.sha` label versus the cached checkout.

## 5. Credentials wiring

| Role | Mechanism | Scope |
| --- | --- | --- |
| builder | `[github] auth_forward = "sync"` (host `~/.config/gh/` copied in, `gh auth setup-git`, host never written); per-agent provider forwarding from the lane's `CLAUDE_CONFIG_DIR` / `CODEX_HOME` (M1-13; OAuth-token mode for Claude lanes where M1-13 adopts it, D-082) | the human's `gh` identity until the GitHub App (M8-01) supplies a per-repo token |
| operator | role env entry in **operator config** `~/.config/jackin/config.toml` (not manifest, and never `~/.jackin/config.toml`, which jackin does not read, D-090): `OP_SERVICE_ACCOUNT_TOKEN = { op = "op://tailrocks/op-service-account-jackin-operator/credential", on_demand = true }`; the agent runs `jackin-exec op item create …`; after checking the displayed command, the host session confirms in the task's recorded Herdr pane with `herdr pane send-keys "$(cat tasks/<id>/herdr-pane.txt)" space enter` (D-082 as superseded by D-124); the entry is hand-written with the mandatory `path` field, D-078 | 1Password service account with `read_items` + `write_items` on vault **`jackin` only**; cannot reach `Private`; token stored in `tailrocks` (op §4) |
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
macOS Docker hosts (OrbStack here, D-056); M1-03 is the proof, and a fallback to a launch-time token
for one session must be logged as a deviation (op §9).

## 6. Conflicts to resolve

| # | Conflict | Recommended answer |
| --- | --- | --- |
| 1 | termrock `CONTRIBUTING.md` is trunk-only (never a branch, never a PR) vs D-047 `feat/managed-execution` and D-034 PRs; D-030 also wants a reviewer sign-off on agent-authored code (tr §1) | Amend `CONTRIBUTING.md` with an "agent-authored changes" clause: branch, PR to `main`, `crew-reviewer` review requested, agent merges when the task says so (D-055, D-079). Trunk push from an agent bypasses the only review gate and hands the builder a `main` push credential on a shared design system. Adopted (D-053); D-047 stands. |
| 2 | D-032 consequence "roles used to implement … must ship `agent-browser`" vs D-045 and least privilege (dev §5) | Amend as in §1: the operator role performs the browser proof as a checklist item; the six builder tasks' browser lines move to the corresponding proof runs (M2-07, M5-03, M6-04, M7-03, M8-02, M10-03). |
| 3 | Q-022 assumes `--role-branch` loads for the daemon (conv B.3, B.8) | Rewrite: roles load from their default branch with trust pre-granted per host by `jackin config trust grant`; `--role-branch` is unusable non-interactively; the daemon reports a missing grant as a validation failure. |
| 4 | Q-018 says "host-side `op`" (op §4) | Rewrite: 1Password service account scoped to vault `jackin`, delivered per invocation by a `jackin-exec` on-demand binding into the in-container `op`; daemon read-only account from M10. |
| 5 | ROADMAP M1-04 (add `agent-browser` to `the-architect`) contradicts D-045 | Drop M1-04. |
| 6 | ROADMAP M1-05 creates one role in `jackin-project` | Becomes a template task plus three role-creation tasks (§7); `M1-06` depends on the operator task; every `the-architect` / `the-operator` / `agent-smith` role column becomes `crew-builder` / `crew-operator` / `crew-reviewer`. |
| 7 | jackin bakes plugins for Claude only; `codex plugin add` cannot run in the role Dockerfile (the `codex` binary arrives in jackin's derived stage) and `CODEX_HOME` is synced from the host, shadowing anything baked there (conv B.5) | Skills as files in `/home/agent/.agents/skills/` pinned to tags; Codex custom agents ride `hooks/source.sh`. Record a jackin feature request for `[codex].skills` outside this effort's task list. |
| 8 | Chrome `SingletonLock`: two processes on one profile collide (op §3, §9) | One operator instance at a time: M3-05's per-host cap gains a per-role cap of 1 for `crew-operator`, and the human never keeps a host `agent-browser --profile` daemon alive while a container runs. Because that cap guarantees no live holder, `preflight.sh` removes `SingletonLock`, `SingletonSocket` and `SingletonCookie` from the profile unconditionally instead of testing the lock's PID, which is unreadable across PID namespaces and, when reused, would refuse forever. Teardown is symmetric: every teardown of a `crew-operator` container (retry, quota hop, re-sync, stuck, resume, end) runs `docker exec -u agent <container> agent-browser close --all` before `jackin eject`, so Chromium releases the shared profile, and once `docker ps --filter label=jackin.role=donbeave/crew-operator` prints nothing the host session runs `rm -f ~/.jackin/agent-browser-profile/Singleton{Lock,Socket,Cookie}` before the next operator launch (goal/EXECUTION.md §4). |
| 9 | Reviewer identity: M2-08 `verify.sh` expects "a review from the app account", but the GitHub App is M8-01 | Until M8-01 the review is posted by the forwarded `gh` identity as a `COMMENT` event with a `verdict:` line (the author cannot request changes on its own PR); `verify.sh` for every review task checks for a review by the configured reviewer login at the head SHA in `tasks/<id>/pr.txt` (D-079). |

## 7. Per-role creation checklist and ROADMAP task deltas

Checklist per role (conv B.7):

1. `gh repo create donbeave/jackin-crew-<purpose> --public --template donbeave/jackin-role-template`; `jackin role create` if the scaffold is preferred, then overlay.
2. `jackin.role.toml` per §3.2: no `published_image`; only official, `jackin-marketplace`, `tailrocks-skills`, and (builder) `caveman` plugin entries; allow-list in `scripts/marketplace-audit.sh` updated to match.
3. Dockerfile: construct `0.36-trixie@sha256:41815a35…`; one ARG + one RUN per tool; `--mount=type=secret,id=github_token`; no `latest`; skills cloned by tag or commit (`ARG <NAME>_SHA`).
4. `AGENTS.md`: threat model naming every new trust anchor, hard rules, conventions; `CLAUDE.md -> AGENTS.md`; `AGENTS.md.d/` runtime-neutral instructions.
5. `hooks/preflight.sh` or `hooks/source.sh` as in §3.1.
6. `jackin role validate .`; push; `jackin-role-action` CI green (hadolint, amd64 build), the workflow pinned to `jackin-version: latest-build` — the only value `scripts/download-jackin-role.sh` can resolve, because jackin publishes no versioned release and the `preview` assets carry no version segment, so any pinned tag 404s at the download step; pinning is a `jackin-role-action` gap noted in the task folder and never worked around here — expected red from M3-02a (`v1alpha7`) until the jackin merge M11-01a republishes the validator (D-089); never a defect to chase before then.
7. On each host: `jackin config trust grant donbeave/crew-<purpose>`; `jackin load donbeave/crew-<purpose> --dry-run --format json | jq -r .data.role` prints the selector (dry-run prints workspace, role, agent, and mounts only — no image decision, D-078). Because the check needs a rich terminal, create a labelled Herdr probe tab as D-124 specifies, run it with `herdr pane run <probe-pane-id> "jackin load donbeave/crew-<purpose> --dry-run --format json | jq -r .data.role"`, inspect it with `herdr pane read <probe-pane-id> --source recent-unwrapped --lines 200`, then close only that probe tab with `herdr tab close <probe-tab-id>`.
8. Record the role here and in the lane table (`ROADMAP.md` §5).
9. M11-02: `published_image`, `publish-image.yml` with explicit GitHub-hosted `runner-*` inputs, Hub secrets; first publish is a cold build, after M11-01a.

Task deltas: the ROADMAP rows these deltas produced are live in
`ROADMAP.md` §2 (M1-04a, M1-05a..d and the renamed role columns); read them
there rather than here, so the applied instructions cannot drift from the
rows they produced.

## 8. Normative contract (adopted under D-053)

D-053 ("Recommended answers are adopted as defaults") adopted the role set,
the template repository, the local-only builds until the server milestone,
the role `host` for human steps, and the D-032 amendment (the role that
performs the browser proof ships `agent-browser`). `SPEC.md` owns the
normative role contract; §1..§6 above elaborate it (D-103).
