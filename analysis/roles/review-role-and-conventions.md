# Review role and role conventions for the `donbeave` role family

Two analyses. Part A specifies the reviewer role that runs the review tasks in
`ROADMAP.md` (M2-08, M3-08, M4-07, and the review halves of M5-03 .. M11-03).
Part B fixes the conventions every new `donbeave/*` role follows (D-045).
Sources are cited by absolute path; nothing here was inferred without reading
the code, manifest, or doc named.

## Part A — the review role

### A.1 What the roadmap asks of it

| Task | Reviews | Extra emphasis | Verification (`ROADMAP.md`) |
| --- | --- | --- | --- |
| M2-08 | jackin M2 branch diff, "with the code-review plugin" | findings become follow-up checklist items on the same issue | review posted; `verify.sh` checks "the PR has a review from the app account and no `blocking` findings remain open" |
| M3-08 | jackin M3 diff | launch pipeline must not alter the CLI path (D-009); trust handling for role-branch loads | review posted; no blocking findings open |
| M4-07 | jackin M4 diff | security: prompt content is untrusted input, no credential leakage into argv; D-016 preserved | same |
| M5-03 .. M11-03 | proof-run PRs across `jackin`, `termrock`, `ecosystem` | — | evidence folder plus review |

Lane rule (`ROADMAP.md` §5, `SPEC.md` D-039): "a review runs on the
runtime the implementer did not use". Implementation lanes are Claude (L1..L3)
for most jackin/termrock work, so most reviews land on Codex (L4..L6); the
role must therefore be fully functional under `codex` and `claude`, with the
same posture on both. ROADMAP §4 already lists the required delta for
`agent-smith`: construct 0.36, `pr-review-toolkit`, `agents = ["claude",
"codex"]` with a `[codex]` table. D-045 moves that delta into a new role under
`donbeave` instead of editing `agent-smith`.

### A.2 What `agent-smith` is today

`/Users/donbeave/Projects/tailrocks/jackin-project/jackin-agent-smith`:

- `Dockerfile`: `FROM projectjackin/construct:0.35-trixie@sha256:d6917f…`, `USER agent`, one mise layer installing `node@24.19.0`. Nothing else.
- `jackin.role.toml`: `version = "v1alpha4"`, `published_image = "docker.io/projectjackin/jackin-agent-smith:latest"`, `agents = ["claude"]`, `[claude] model = "claude-sonnet-4-6"`, plugins `code-review@claude-plugins-official`, `feature-dev@claude-plugins-official`, two `CLAUDE_CODE_*` env defaults.
- `AGENTS.md`: threat model (base supply chain, build-time pulls, runtime credential mounts, layer secrets, plugin trust), six hard rules (digest-pinned construct final stage, document every plugin's trust anchor, no credential `ENV`/`ARG`, `--mount=type=secret` only, no `latest`, marketplace allow-list in sync).
- `scripts/marketplace-audit.sh`: pre-commit hook; allow-list is `@(claude-plugins-official|jackin-marketplace)`.
- `.github/workflows/publish-image.yml`: calls `jackin-project/jackin-role-action/.github/workflows/publish.yml` on push to `main`; `ci.yml` is the velnor-generated fleet template.

It has no Codex support, no Rust toolchain, and `feature-dev` is an
implementation plugin that a reviewer does not need.

### A.3 What the review plugins actually do

| Plugin | Runtime | Builds/tests? | Posts how | Source |
| --- | --- | --- | --- | --- |
| `code-review@claude-plugins-official` | Claude | No — "Do not check build signal or attempt to build or typecheck the app. These will run separately"; `allowed-tools` is limited to `gh pr view/diff/comment/list`, `gh issue`, `gh search` | `gh pr comment` (an issue comment, not a PR review) | `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/code-review/commands/code-review.md` |
| `pr-review-toolkit@claude-plugins-official` | Claude | No; six agents (code-reviewer, pr-test-analyzer, silent-failure-hunter, type-design-analyzer, comment-analyzer, code-simplifier) read the diff | reports locally; `/review-pr` reads `git diff` and `gh pr view` | `…/plugins/pr-review-toolkit/commands/review-pr.md` |
| `review-crucible` (tailrocks) | Claude, Codex, Amp | No; preflight gate, 15 reviewer roles, validator, `>=80/100` confidence gate | GitHub Reviews API via `gh api` with `comments[]` (`path`, `line`, `side`, `body`); "If no confirmed findings remain, post at most one short top-level summary" | `/Users/donbeave/Projects/tailrocks/review-crucible/README.md`, `skills/review-crucible/references/github-commenting.md`, `commands/code-review.md` |
| `tailrocks-review-pr`, `tailrocks-rust-review` (tailrocks-skills) | Claude, Codex, others | No; "unconditionally read-only: it never edits files, posts comments, merges, or approves" | never posts; posting is "a separate, freshly authorized transaction" | `/Users/donbeave/Projects/tailrocks/tailrocks-skills/skills/tailrocks-review-pr/SKILL.md`, `skills/tailrocks-rust-review/SKILL.md` |

Facts that constrain the choice:

- `review-crucible` is public (`gh repo view tailrocks/review-crucible` → PUBLIC) but its README's Claude install path (`tailrocks/tailrocks-marketplace`) does not exist on GitHub, and the repo "does not ship its own marketplace manifest". `jackin role validate` resolves every `[claude].plugins` entry against a `.claude-plugin/marketplace.json` fetched from `raw.githubusercontent.com/<slug>/HEAD/…` (`jackin/crates/jackin/src/role_claude_plugins.rs`), so `review-crucible@…` cannot appear in `[claude].plugins` until some marketplace lists it. It ships `.codex-plugin/plugin.json` with `"skills": "./skills/"` and `.codex/agents/*.toml`, so on Codex it installs as a plugin or as a plain skill directory (`.codex/INSTALL.md` options 1–4).
- jackin bakes plugins for Claude only: `render_claude_plugin_section` in `jackin/crates/jackin-image/src/derived_image.rs:305-344` emits `claude plugin marketplace add …` and `claude plugin install …` RUN lines; `[codex]` has only `model` and `providers` (`jackin/crates/jackin-core/src/manifest.rs:185`); no runtime has a skills field. Codex skill installation is therefore the role Dockerfile's job (B.5).
- `review-crucible` routes Rust judgment to a skill named `rust-best-practices`; the tailrocks equivalent is `tailrocks-rust-review` / `tailrocks-rust-best-practices` (`tailrocks-skills/skills/`). The crucible skill says it will report "Rust-specific review was limited" when its expected name is missing; the role's `AGENTS.md` maps the name.

### A.4 Does the reviewer need a Rust toolchain? No.

Reasoning, in order of weight:

1. **Read-only posture is a security property, not a preference.** Compiling a PR runs its `build.rs`, proc-macros, and `cargo` plugins — arbitrary code chosen by the PR author, which from M2 on is another agent. A reviewer that compiles is executing the thing it is judging, inside a container that also holds `gh` credentials. `rust-analyzer-lsp` has the same problem (it runs build scripts). The implementer role and CI already execute that code in their own sandboxes.
2. **CI is the build oracle.** `jackin/.github/workflows/ci.yml` runs on `pull_request`; `termrock/mise.toml` defines `test`/`lint`/`gate`. The reviewer reads `gh pr checks` and `gh run view --log-failed` instead of re-running them; the official `code-review` plugin states the same policy verbatim.
3. **Every candidate review workflow is read-only by design** (table A.3). None of them run `cargo`; findings must cite `file:line` evidence from the tree. Verification of a suspected bug that truly needs execution is expressed as a finding "needs reproduction: <test sketch>" which becomes a checklist item for the implementer (that is exactly the M2-08 flow: "findings become follow-up checklist items on the same issue").
4. **Consistency with M6/D-030:** "verify command lives on the base branch; reviewer role signs off when an agent authored it" (`ROADMAP.md` §7, M6 row). Sign-off is a reading act.

Consequence: the role has no `cargo`, no `rustup`, no OpenTofu. It has `gh`
(construct base), `git`, `jq`, Node (Claude plugins need it), Python (crucible
`scripts/validate.py` is optional; omit unless needed).

### A.5 How a verdict is posted

- **Primary: a GitHub PR review through the Reviews API**, not `gh pr comment`. `verify.sh` for M2-08 checks "the PR has a review from the app account"; an issue comment does not satisfy that. Shape (from `review-crucible/skills/review-crucible/references/github-commenting.md`): `gh api repos/{owner}/{repo}/pulls/{n}/reviews -f commit_id=<head sha> -f event=<EVENT> -f body=<summary> --input comments.json` with one inline comment per confirmed finding. The role's `AGENTS.md` overrides the official `code-review` plugin's "comment back with gh" step with this flow.
- **Event mapping (amended by D-079):** `COMMENT` always while the reviewer runs on the forwarded `gh` identity (the PR author until M8-01; GitHub returns 422 for `REQUEST_CHANGES` and `APPROVE` on one's own PR). The verdict is carried in the review body's first line `verdict: REQUEST_CHANGES|COMMENT` plus `blocking:`/`major:`/`minor:` prefixes on inline comments; the real `REQUEST_CHANGES` event only once the reviewer identity is the M8-01 App token, which is not the PR author. **Never `APPROVE`**: (a) the reviewer's `gh` identity is the forwarded login until M8-01 and the App token after, and GitHub rejects approving one's own PR; (b) merge authority belongs to the Linear "merging" state and M8-01, not to the reviewer. Each inline body starts with a severity tag `blocking:` / `major:` / `minor:` so `verify.sh` can grep for open `blocking` threads.
- **Findings back to Linear (M2-08 onward):** the reviewer does not hold a Linear token (D-035); it emits the finding list in its final message in the task-format checklist syntax (`concept/task-format.md`), and the daemon (M5-02 checklist write-back) or the operator appends them as checklist items. Once the jackin-exec Linear binding exists (D-023/Q-018 pattern), the role calls it directly; the manifest needs no change for that.
- **Preflight** (crucible preflight gate; official plugin step 1): skip closed/draft/already-reviewed PRs — necessary because the daemon re-dispatches on retry (M6-02).

### A.6 Proposed role spec

| Item | Value |
| --- | --- |
| Selector | `donbeave/crew-reviewer` (family name per B.7; final name recorded in `concept/roles.md`) |
| Repo | `github.com/donbeave/jackin-crew-reviewer` (B.1) |
| Identity | `Crew Reviewer` |
| Base | `projectjackin/construct:0.36-trixie@sha256:41815a3550254e5ef2edf5fc1215d9b1d1f0fd694bf6df108b57ba5a35812c1f` (the pin `the-architect` uses; `0.36-trixie` is the newest tag on Docker Hub as of 2026-08-27) |
| Installs | `node@24.19.0` via mise (as agent-smith); `git clone --depth 1 --branch <tag>` of `tailrocks/review-crucible` into `/home/agent/.agents/skills/review-crucible` (Codex/Amp skill surface) plus `.codex/agents/*.toml` staged under `/opt/jackin-role/codex-agents/` for the `source` hook to copy into `$CODEX_HOME/agents/`; `~/.config/amp/checks/` from `.agents/checks/` if `amp` is ever added |
| Not installed | Rust toolchain, `rust-analyzer-lsp`, OpenTofu, `op`, `agent-browser` |
| Runtimes | `agents = ["claude", "codex"]`; model per lane profile (ROADMAP §4 note: manifest models are overridden by the lane) |
| Posture | read-only on `/workspace` (mount `:ro` in the daemon's workspace profile; the role's `AGENTS.md` forbids edits, pushes, `gh pr merge`, `APPROVE`) |
| Verdict | PR review via Reviews API (A.5) |

`jackin.role.toml` sketch:

```toml
version = "v1alpha5"            # v1alpha6 only if [docker] is used; both validate on jackin 0.6.4-preview.1100
dockerfile = "Dockerfile"
# published_image omitted for the laptop prototype (B.3); add
# "docker.io/donbeave/jackin-crew-reviewer:latest" at M10.
agents = ["claude", "codex"]

[identity]
name = "Crew Reviewer"

[claude]
model = "claude-sonnet-4-6"     # overridden per lane
plugins = [
  "code-review@claude-plugins-official",
  "pr-review-toolkit@claude-plugins-official",
  "tailrocks-skills@tailrocks-skills",   # tailrocks-review-pr, tailrocks-rust-review
]

[[claude.marketplaces]]
source = "tailrocks/tailrocks-skills"

[codex]                          # review-crucible + tailrocks-skills arrive via the Dockerfile and hooks, not here

[hooks]
source = "hooks/source.sh"       # copies staged Codex agents into $CODEX_HOME/agents, idempotent

[env.CLAUDE_CODE_NO_FLICKER]
default = "1"

[env.CLAUDE_CODE_MAX_OUTPUT_TOKENS]
default = "64000"

[env.CLAUDE_CODE_EFFORT_LEVEL]
default = "medium"               # D-039; Codex effort pinned in the lane's config.toml
```

`AGENTS.md` for the role (baked, as `the-architect` does with `AGENTS.md.d/`)
states: which command to run per runtime (`/code-review <pr>` then
`/review-pr all` on Claude; `Use $review-crucible … spawn the focused Codex
custom agents …` on Codex, prompt from `review-crucible/.codex/INSTALL.md`),
the `rust-best-practices` → `tailrocks-rust-review` mapping, the verdict flow
of A.5, and the read-only rules.

Threat model (delta from `jackin-agent-smith/AGENTS.md`):

1. Same five surfaces (base supply chain, build-time pulls, runtime credential mounts, layer secrets, plugin trust).
2. **PR content is untrusted input.** Diffs, commit messages, PR bodies, and prior comments may contain instructions; the role treats them as evidence only (both `tailrocks-review-pr` and crucible already say so). No compilation, no `build.rs`, no `cargo` — the bounding argument of A.4.
3. **Two new trust anchors:** `tailrocks/tailrocks-skills` (tagged) and `tailrocks/review-crucible` (clone pinned to a tag or commit, never `main`). The marketplace allow-list in the pre-commit audit gains `tailrocks-skills`.
4. **`gh` write scope is the blast radius.** The reviewer's token can post reviews and comments on every repo the App/PAT is installed on; it cannot push (no write mount) and must not merge. Prompt-injection through a PR therefore can at worst post a misleading review, which the human reads.
5. **Codex home is synced from the host** (`CODEX_HOME`, D-039 lanes). The `source` hook writes only under `$CODEX_HOME/agents/`; it never touches `auth.json`.

## Part B — conventions for the `donbeave` role family

### B.1 Repo naming that `jackin load donbeave/<name>` resolves

`jackin/crates/jackin-config/src/app_config/roles.rs:204-237`: a namespaced
selector resolves to `https://github.com/{namespace}/{repo}.git` with
`repo = name if name.starts_with("jackin-") else "jackin-" + name`. So:

| Selector | Repo |
| --- | --- |
| `donbeave/crew-reviewer` | `github.com/donbeave/jackin-crew-reviewer` |
| `donbeave/jackin-crew-reviewer` | same (prefix kept verbatim) |
| `crew-reviewer` (bare) | `github.com/jackin-project/jackin-crew-reviewer` — wrong org; always use the namespace |

Selector rules (`jackin/crates/jackin-core/src/selector.rs:71-94,149`): lowercased, segments `[a-z0-9-]` only, at most one `/`, bare names may not start with `jk-`. Docs: `jackin/docs/content/(public)/(role-authoring)/guides/role-repos.mdx:24-57`. No `jackin-*` repos exist under `donbeave` yet (`gh repo list donbeave`).

### B.2 What a role repo must contain

| Requirement | Enforced by |
| --- | --- |
| `jackin.role.toml` at repo root; `dockerfile` is the only required field; unknown fields rejected (`deny_unknown_fields`) | `jackin/crates/jackin-core/src/manifest.rs:21-70`; `jackin-manifest/src/repo.rs:155-229` |
| Final `FROM` is `projectjackin/construct:<version>-trixie`; digest suffix allowed and looked through; floating `trixie` rejected; earlier stages any base; no `--platform` on the final FROM | `jackin/crates/jackin-manifest/src/repo_contract.rs:100-160` |
| `Dockerfile`, hook paths relative, inside repo, not symlinks | `repo.rs` (`PathIsSymlink`, `PathEscapesBoundary`) |
| `[<agent>]` table for every entry in `agents`; `agents = []` rejected | `jackin-manifest/src/validate.rs:51-107` |
| `[env.X]`: non-interactive needs `default`; `options` needs `interactive`; interpolation refs listed in `depends_on` | `validate.rs:118-253` |
| `Dockerfile`, `jackin.role.toml`, `.dockerignore`, `.gitignore` present; hadolint clean; `linux/amd64` build succeeds | `jackin-role-action/action.yml` + `README.md` "CI checks performed" |
| Manifest `version`: current code constant `v1alpha6` (`jackin-core/src/constants.rs:23`); `[docker]` needs ≥v1alpha6, `[*.providers]` ≥v1alpha5; the installed `jackin 0.6.4-preview.1100` validates both v1alpha5 and v1alpha6 (checked with `jackin role validate`) | `jackin-manifest/src/manifest.rs:87-135`, `migrations.rs` |
| Construct base: `0.36-trixie@sha256:41815a35…` — from `jackin-the-architect/Dockerfile`; newest tag on Docker Hub. Note the validator does not require the digest; the family's hard rule (inherited from agent-smith) does | `jackin-agent-smith/AGENTS.md` hard rule 1 |

Convention files carried over from the existing roles: `AGENTS.md` (threat
model + hard rules + conventions), `CLAUDE.md` → symlink to `AGENTS.md`,
`README.md`, `LICENSE`/`NOTICE`/`REUSE.toml`/`LICENSES/`, `.hadolint.yaml`,
`.pre-commit-config.yaml` with gitleaks + `scripts/marketplace-audit.sh`,
`mise.toml` (actionlint, gitleaks, prek, reuse), `renovate.json`,
`.github/workflows/{ci,publish-image,precommit,gitleaks-history,reuse-compliance}.yml`.
Docs the validator does not read but jackin does at runtime: `hooks/*.sh`
(`setup_once`, `source`, `preflight`; ADR-009 in `jackin/docs/content/reference/adrs/`).

### B.3 Publishing, and why the prototype is local-only

- The publish workflow reads the image name from `published_image` (`jackin-role published-image-repository`), logs into `registry` (default `https://index.docker.io/v1/`) with `registry-username`/`registry-password`, builds amd64+arm64, merges the manifest, tags `latest` and the short sha, signs keyless with cosign (`jackin-role-action/.github/workflows/publish.yml:134-291`). Nothing restricts the namespace: jackin only checks the reference's alphabet (`jackin-image/src/derived_image.rs:508-518`); docs show ghcr/ECR. The `donbeave` Docker Hub user exists (`hub.docker.com/v2/users/donbeave` → 200), so `docker.io/donbeave/jackin-<name>` publishes from a personal account with a Hub access token stored as repo secrets.
- jackin does **not** verify cosign signatures on role images; freshness is the `jackin.role.git.sha` label vs the cached checkout HEAD (`jackin-runtime/src/runtime/image/published.rs:25-93`). A pull failure is logged and the image is rebuilt from the workspace Dockerfile.
- `--role-branch` ignores `published_image` **and** always raises the branch-trust dialog, even for trusted roles (`launch_pipeline.rs:614-640`); that dialog needs the rich renderer, which the daemon lacks (`jackin-launch/src/progress.rs:212-222`). So `--role-branch` is unusable for daemon launches. There is no local-path role loading; the only path is a cached git checkout of the default branch.

Recommendation: **until M10, omit `published_image`** and work on `main` of
each role repo. Loads then always take `BuildFromWorkspace` from the
`~/.jackin/roles/donbeave/<name>/default` checkout; `jackin load --rebuild`
refreshes after a role commit; no registry secrets are needed on the laptop.
At M10 (server host must not rebuild) add `published_image =
"docker.io/donbeave/jackin-<name>:latest"`, the `publish-image.yml` caller,
and the two Hub secrets; the ROADMAP Q-022 answer changes from "role-branch"
to "default branch + pre-granted trust".

### B.4 Trust for `donbeave/*` (Q-022)

Trust is per selector key, stored as `roles.<key>.trusted` in operator config
(`jackin-config/src/schema.rs:447-456`); no namespace wildcard exists (`*`
fails segment validation; wildcards exist only for mount scopes). Granting is
non-interactive: `jackin config trust grant donbeave/crew-reviewer` synthesizes
the GitHub URL, upserts the source, sets `trusted = true`
(`jackin/crates/jackin/src/app/config_cmd.rs:215-233`). An untrusted role in a
non-interactive launch fails with `rich_launch_dialog_required_message("role
trust prompt")`. So M1-05 runs one `trust grant` per family role on every
daemon host, and the daemon reports a missing grant as a validation failure
(ROADMAP §7 Q-022 already says this; only the "role-branch" half is wrong per
B.3).

### B.5 Baking plugins and skills per runtime

| Runtime | Mechanism | Where it lives in the role repo |
| --- | --- | --- |
| Claude Code | jackin emits `claude plugin marketplace add <source>` + `claude plugin install <id>` RUN lines at derived-image build, before the default-home snapshot (`derived_image.rs:305-344`); `jackin role validate` checks each id against the marketplace's `marketplace.json` on GitHub | `[claude].plugins`, `[[claude.marketplaces]]`; allow-list in `scripts/marketplace-audit.sh` |
| Codex | nothing in jackin. Skills are files: `~/.agents/skills/<name>/SKILL.md` is read natively (`tailrocks-skills/INSTALL.md:106-111`; `~/.codex/skills` is deprecated). Custom agents are `.codex/agents/*.toml` per project or under `$CODEX_HOME/agents/`. The `codex` binary is installed by jackin's derived stage, so `codex plugin add` cannot run in the role Dockerfile; `CODEX_HOME` is synced from the host per lane, so anything placed there at build time is shadowed | Dockerfile `git clone --branch <tag>` into `/home/agent/.agents/skills/…`; agent TOMLs staged in the image and copied by `hooks/source.sh` into `$CODEX_HOME/agents/` |
| Amp | `~/.config/amp/checks/*.md` + `AGENTS.md` snippet (`review-crucible/amp/INSTALL.md`) | Dockerfile COPY if `amp` is ever in `agents` |
| All | `AGENTS.md.d/*.md` concatenated into `/home/agent/AGENTS.md` at build (`jackin-the-architect/Dockerfile` lines ~87-88) — the runtime-neutral instruction surface | `AGENTS.md.d/` |

Two consequences: `tailrocks-skills` should be installed once per runtime the
way its `INSTALL.md` prescribes for that runtime (Claude: marketplace plugin;
Codex: plugin via `codex plugin marketplace add` cannot run at build, so use
the skills-dir copy pinned to a tag and keep the Claude plugin as the only
Claude channel), and Codex custom agents that a role wants must ride a hook,
not the image.

### B.6 Shared base layer: template repo, not a base image

Image inheritance is out: the validator requires the **final** stage to be
`FROM projectjackin/construct:…` (`repo_contract.rs:100-160`), so a
`donbeave/jackin-role-base` image could only be an earlier stage whose files
are `COPY --from`'d — fragile for mise-managed tools and pointless for a
five-line layer. What the family shares is text, not layers.

Recommendation: `donbeave/jackin-role-template` (a GitHub template repo, not a
loadable role — it has no `jackin.role.toml` on purpose) holding: the
Dockerfile preamble (digest-pinned construct FROM, `SHELL`, `USER agent`,
`MISE_TRUSTED_CONFIG_PATHS`, mise cache mount block), per-tool RUN fragments
(`node`, `tailrocks-skills` skills-dir clone, review-crucible clone),
`AGENTS.md.d/00-common.md` (read-only rules, credential rules, task-format
output contract), `hooks/source.sh`, the pre-commit/marketplace-audit scripts
with the family allow-list (`claude-plugins-official`, `jackin-marketplace`,
`tailrocks-skills`), `renovate.json` (construct digest + tool ARGs), and the
three workflows. Roles are created with `jackin role create` then overlaid
from the template; Renovate keeps the construct digest and tool pins aligned
across the family, which is the property a shared image would otherwise give.
Revisit only if a second family needs a >1 GB common layer.

### B.7 Naming scheme and per-role checklist

Scheme: selector `donbeave/<family>-<purpose>` → repo
`donbeave/jackin-<family>-<purpose>`; identity name `<Family> <Purpose>`.
Family = the working style the roles implement (build a product through
Linear + jackin); `crew` is used above as the placeholder, to be fixed in
`concept/roles.md`. Purposes from ROADMAP §4: `builder` (replaces
`the-architect` for this project, with `agent-browser`), `operator`
(`the-operator`), `reviewer` (this document). The `jackin-` prefix is
mandatory (B.1); `crew-` keeps the family listable with one glob on GitHub and
in `~/.jackin/roles/donbeave/`.

Checklist to create one role:

1. `gh repo create donbeave/jackin-<family>-<purpose> --public` from `donbeave/jackin-role-template`; `jackin role create` if the scaffold is preferred, then overlay.
2. `jackin.role.toml`: `version = "v1alpha5"` (v1alpha6 if `[docker]` is needed), `dockerfile`, `agents`, one table per agent, `[identity].name`, `[claude].plugins` with only official/`tailrocks-skills` entries, no `published_image` before M10.
3. Dockerfile: construct `0.36-trixie@sha256:41815a35…`; one ARG + one RUN per tool; `--mount=type=secret,id=github_token`; no `latest`.
4. `AGENTS.md`: threat model naming every new trust anchor; hard rules; conventions. `CLAUDE.md -> AGENTS.md`.
5. `AGENTS.md.d/` runtime-neutral instructions; `hooks/source.sh` if Codex agents are shipped.
6. `jackin role validate .` locally; push; CI (`jackin-role-action`) green.
7. On each daemon host: `jackin config trust grant donbeave/<family>-<purpose>`; `jackin load donbeave/<family>-<purpose> --dry-run --format json` to confirm the resolved repo and `BuildFromWorkspace`.
8. Record the role in `concept/roles.md` and the lane table in `ROADMAP.md` §5.
9. M10: add `published_image`, `publish-image.yml`, Hub secrets; first publish is a cold build.

### B.8 Discrepancies noticed on the way (not blocking)

- `jackin/docs/content/(public)/(role-authoring)/developing/role-manifest.mdx:80` says the current manifest version is `v1alpha4`; code says `v1alpha6`. Docs pin construct `0.4-trixie`; validator fixtures still use `0.1-trixie`.
- `review-crucible/README.md` points Claude users at `tailrocks/tailrocks-marketplace`, which does not exist; adding `review-crucible` to `tailrocks-skills/.claude-plugin/marketplace.json` (or creating that marketplace) would let it appear in `[claude].plugins` and lift the Claude side of the role to the same plugin on both runtimes.
- `ROADMAP.md` §7 Q-022 assumes `--role-branch` for daemon loads; B.3 shows that path cannot be non-interactive.
