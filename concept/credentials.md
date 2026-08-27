# Credentials inventory — jackin managed execution

Status: **inventory, 2026-08-27**. Records what already exists in 1Password
that this project can reuse, what is already wired through `op://`, and
what still has to be created. Follows D-035 (every credential lives in
1Password and is referenced as `op://`). This document contains item
metadata only: vault names, item titles, categories, field *names*, URLs,
dates. No secret value appears here and none may be added.

## 1. Method and what was accessible

- `op` 2.39.0 at `/opt/homebrew/bin/op`, signed in to one account:
  `zhokhov.1password.com` (user `alexey@zhokhov.com`). No sign-in was
  attempted; the existing session was used.
- 16 vaults visible: A Personal Checked, A TODO, AZ & DZ, AZ & Veronica,
  Boris, ChainArgos, CS, Febos, Joyce, Kanargi, Private, Polusharie,
  ruxel-test, Shared, tailrocks, Vestor. 2,173 items in total.
- Only three vaults hold anything relevant: **tailrocks** (7 items),
  **Private**, **ChainArgos**. `Shared` is empty. There is **no `jackin`
  vault**.
- Commands used: `op vault list`, `op item list --format json`, and
  `op item get <id> --format json` piped through `jq` selecting
  `.fields[] | {label, type, purpose}` only. `.value` was never read.
- Code and config were grepped for `op://` in `jackin-project`, `termrock`,
  `tailrocks-skills`, `~/.config/jackin`, `~/.jackin`.
- Fact supplied by the coordinator, not visible in 1Password as a separate
  item: the Linear workspace account exists and signs in with **Google SSO**
  as `alexey@chainargos.com`; there is no separate Linear password.

## 2. Existing credentials

Field names are listed as they appear in 1Password. `sign in with` is the
1Password SSO marker (the item has no usable password of its own).
"Referenced from" is where an `op://` to this item already exists.

### 2.1 Directly reusable for this project

| Vault | Item | Category | Fields (names only) | URL | Updated | Likely purpose | Referenced from |
| --- | --- | --- | --- | --- | --- | --- | --- |
| tailrocks | GitHub App — jackin-package-updater | API_CREDENTIAL | App ID, Slug, Client ID, PEM private key, Installation ID, Owner org, Selected repositories, Exact permissions, Created at, Settings URL, Install URL | (none) | 2026-08-12 | GitHub App for automated PRs in `jackin-project` org; installation-token model, no long-lived PAT | nothing |
| tailrocks | GitHub App — tailrocks-package-updater | API_CREDENTIAL | same shape as above | (none) | 2026-08-12 | Same for `tailrocks` org | nothing |
| tailrocks | GitHub | LOGIN | username, password, velnor-apt, holla-homebrew-tap-publisher, tailrocks-renovate, holla-apt, tailrocks-public-read-only, parallax-homebrew-tap-publisher | github.com | 2026-06-15 | tailrocks org GitHub account plus per-purpose PATs kept as extra concealed fields | nothing |
| Private | GitHub (created 2026-04-07) | LOGIN | username, password, jackin-homebrew-tap-publisher, jackin-renovate, jackin-public-read-only | github.com | 2026-05-19 | jackin-project org account; PATs for Homebrew tap publish, Renovate, read-only clone | nothing |
| Private | GitHub (created 2011-05-10) | LOGIN | login, password, commit, Mega token, Renovate token, GitHub Runner token, GARM, read-only, recovery codes, Key (OTP) | github.com | 2026-06-24 | Personal `donbeave` account with several PATs and TOTP | nothing |
| Private | Linear | LOGIN | username, password, sign in with | linear.app | 2026-08-26 | Linear workspace login; **EXISTS, login = Google SSO** (`alexey@chainargos.com`), the `sign in with` field marks it | nothing |
| Private | Claude (created 2026-03-20) | LOGIN | username, password, Zed, chainargos, sign in with | anthropic.com, claude.com | 2026-04-23 | Anthropic account with two API-key fields (Zed editor, chainargos) | nothing |
| Private | Claude (created 2026-04-27) | LOGIN | username, password, auth token, sign in with | claude.com | 2026-05-13 | Claude account with an OAuth/auth token field (matches jackin's `Claude/auth token` handoff pattern) | nothing |
| Private | Claude (×3 more: 2025-11-02, 2026-05-17, 2026-08-11) | LOGIN | username, password (+phone on one) | claude.ai / claude.com | 2026-02 .. 2026-08 | Additional Claude web logins; no API fields | nothing |
| Private | Anthropic | LOGIN | username, password, zed | anthropic.com | 2025-12-05 | Console login + one API key field | nothing |
| Private | Scentbird Claude API Key | PASSWORD | password | (none) | 2026-02-09 | Client-specific Anthropic key; not for this project | nothing |
| Private | OpenAI (×4) | LOGIN | email/username, password, sign in with | openai.com, chatgpt.com | 2026-08-05 .. 08-17 | ChatGPT/Codex subscription logins; no API-key field on any of them | nothing |
| Private | Amp Code | LOGIN | username, password, sign in with | ampcode.com | 2026-05-20 | Amp (Sourcegraph) login; SSO, no API key field | nothing |
| Private | Kimi | LOGIN | username, password, sign in with | kimi.com | 2026-06-03 | Kimi login (personal) | nothing |
| Private | Moonshot | LOGIN | username, password, sign in with | moonshot.ai | 2026-05-12 | Moonshot platform login (Kimi API vendor) | nothing |
| Private | OpenCode | LOGIN | username, password, sign in with, API key | opencode.ai | 2026-08-23 | OpenCode login with an API key field | nothing |
| Private | xAI | LOGIN | username, password, sign in with | x.ai | 2026-08-17 | Grok login; no API key field | nothing |
| Private | Context7 | LOGIN | (section `API Keys`, field `Claude`) | context7.com | 2026-03-29 | Context7 MCP key used by the-architect role | `~/.config/jackin/config.toml` `CONTEXT7_API_KEY` |
| Private | Docker (×3) | LOGIN | username, password, email, GitHub (on the 2026 one) | docker.com, hub.docker.com | 2022 .. 2026-04-07 | Docker Hub logins; the `GitHub` field is a Hub access token for CI | nothing |
| Private | donbeave SSH | SSH_KEY | public key, fingerprint, private key, key type | (none) | 2022-10-26 | Personal git SSH key | nothing |

### 2.2 Relevant but organisation-scoped (ChainArgos vault)

| Vault | Item | Category | Fields (names only) | URL | Updated | Likely purpose | Referenced from |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ChainArgos | Kimi | LOGIN | username, password, sign in with, section `API Keys` → `Test` | kimi.com | 2026-06-03 | Kimi Code API key | `config.toml` `KIMI_CODE_API_KEY` |
| ChainArgos | MiniMax | LOGIN | section `subscription` → `key` | minimax.io | 2026-06-03 | MiniMax provider key (the-architect provider override) | `config.toml` `MINIMAX_API_KEY` |
| ChainArgos | Z.ai | LOGIN | section `API keys` → `Test` | z.ai | 2026-06-03 | Z.ai provider key (the-architect provider override) | `config.toml` `ZAI_API_KEY` |
| ChainArgos | xAI | LOGIN | username, password, sign in with | x.ai | 2026-06-08 | Grok login, org account | nothing |
| ChainArgos | GitHub | LOGIN | username, password, public-read-only | github.com | 2026-05-19 | chainargos org account + read-only PAT | nothing |
| ChainArgos | Docker | LOGIN | username, password, email, GitHub Actions | docker.com | 2026-02-07 | Docker Hub org login + CI token | nothing |
| ChainArgos | Cloudflare | LOGIN | username, password, chainargos | cloudflare.com | 2026-06-10 | Cloudflare account + API token field | nothing |
| ChainArgos | Hetzner | LOGIN | username, password, login, key, one-time password | hetzner.com | 2024-05-18 | Hetzner console with TOTP | nothing |
| ChainArgos | ruxel Hetzner Cloud | API_CREDENTIAL | credential, token, hostname, expires… | (none) | 2026-06-11 | Hetzner Cloud API token for `ruxel` | nothing |
| ChainArgos | ruxel CI service account / Service Account Auth Token: ruxel-ci / ChainArgos op Service Account (lightdash-migration-agent) | API_CREDENTIAL | credential, hostname, expires… | (none) | 2026-06 .. 07 | **1Password service-account tokens** already used for headless `op` in CI/agents; pattern to copy for the daemon | nothing |
| ChainArgos | ChainArgos GARM | LOGIN | username, password, PAT, secret, email, passphrase, name, current local URL | garm.chainargos.com | 2026-05-10 | Self-hosted GitHub runners manager | nothing |

### 2.3 Present but not for this project

- tailrocks: `holla-apt GPG Signing Key`, `velnor-apt GPG Signing Key`
  (apt repo signing, not container/role signing), `Google`, `КриптоПро`.
- Private: three `Cloudflare` logins (personal), `Hetzner` (personal),
  `Z.ai` (personal), `Linode Singapore` SSH key.
- Nothing titled `jackin`, `termrock`, `linear-agent`, `cosign`, `sigstore`,
  `ghcr`, `agent-browser` exists anywhere.

## 3. Existing `op://` references in code and config

Real references exist in exactly one file. Everything in the repositories
is test fixtures, fuzz corpora, or documentation placeholders
(`op://vault/item/field`, `op://Personal/api/token`,
`op://Work/Anthropic/api-key`, …) and is listed only for completeness.

| Reference (path form as stored) | File | What uses it |
| --- | --- | --- |
| `Private/Context7/API Keys/Claude` (stored as UUID form `op://xlm7…/lppg…/API Keys/sfzq…`) | `~/.config/jackin/config.toml` `[env]` | `CONTEXT7_API_KEY` exported into every role container |
| `ChainArgos/Kimi/API Keys/Test` (UUID form) | same | `KIMI_CODE_API_KEY` for the Kimi runtime |
| `ChainArgos/MiniMax/subscription/key` (UUID form) | same | `MINIMAX_API_KEY` for the-architect provider override |
| `ChainArgos/Z/API keys/Test` (UUID form) | same | `ZAI_API_KEY` for the-architect provider override |
| `op://Personal/api/token`, `op://Work/Anthropic/api-key` | `jackin-project/jackin/crates/jackin-config/src/fixtures/config.round_trip.toml` | round-trip fixture, placeholder |
| `op://v/i/f`, `op://rv/ri/rf` | `jackin-project/jackin/crates/jackin/tests/fixtures/migrations/workspace/from-v1alpha4/*.toml`, `jackin-config/fuzz/corpus/workspace_migrate/*.toml` | migration fixtures, placeholder |
| ~60 other placeholder forms | `jackin-env`, `jackin-core`, `jackin-console`, `jackin-runtime`, `jackin-diagnostics` test modules | parser, picker, scrubber, and launch tests |

Observations:

- Every real reference is stored in **UUID form** with a human `path` label
  and a pinned `account` id (`K45NXUZGQBCFPHAFWW5WCJ6ABY`). That is what
  jackin's picker writes; it survives item renames. `op account list` only
  prints the user id, so the account id was not cross-checked.
- All agent runtimes in `config.toml` (`claude`, `codex`, `amp`, `github`,
  `kimi`, `opencode`, `grok`) use `auth_forward = "sync"`: the container
  gets the **host's logged-in state** (Claude OAuth, `gh auth`, Codex
  login, …), not a 1Password secret. This works for interactive use on the
  laptop and is the reason there are no `op://` items for those runtimes
  yet. A daemon on a server host has no host login to forward; those
  become real credentials (section 4).
- `~/.jackin/` holds no `op://` references (workspaces, roles cache, sockets
  only). `termrock` and `tailrocks-skills` hold none.
- jackin already writes to 1Password for Claude tokens (roadmap
  `onepassword-integration`), so refresh-token write-back for Linear has a
  precedent.

## 4. Needed credentials for this project

Derived from `SPEC.md` §5, §6, §9a, §10; D-032, D-035; `concept/workflow.md`
§0; `analysis/linear-agents.md` A7/A8. Proposed names use a new vault
`jackin` (section 5). "Runtime" means the daemon reads it on every launch;
"setup" means it is used once by a human or the browser profile.

| # | Purpose | Type | Proposed item (vault `jackin`) | Proposed `op://` | When | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Linear OAuth agent app identity (`actor=app`, `app:assignable`, `app:mentionable`) | client id + client secret | `linear-agent-app` fields `client id`, `client secret`, `app url`, `redirect uri` | `op://jackin/linear-agent-app/client id`, `…/client secret` | runtime (refresh, client-credentials) | **CREATE** — no OAuth app item exists |
| 2 | Linear webhook verification (`Linear-Signature` HMAC) | signing secret | `linear-agent-app` field `webhook signing secret` | `op://jackin/linear-agent-app/webhook signing secret` | runtime (relay or daemon) | **DEFER** — polling adopted (Q-015, D-053); create only if a relay is added later |
| 3 | Linear per-workspace installation token | access token + refresh token + expires_at + app_user_id + organization_id | `linear-workspace-<org-slug>` fields `access token`, `refresh token`, `expires at`, `app user id`, `organization id` | `op://jackin/linear-workspace-<org>/access token`, `…/refresh token` | runtime; daemon must **write back** the rotated refresh token | **CREATE** — produced by the authorize flow after #1 |
| 4 | Linear workspace human login (browser profile, D-032) | Google SSO | existing `Private/Linear` (SSO marker) + Google account | none (interactive SSO; profile persists the session) | setup | **EXISTS** (`Private/Linear`, login = Google SSO `alexey@chainargos.com`) |
| 5 | GitHub: push branches, open/update PRs, read repos | GitHub App installation (preferred) or fine-grained PAT with `contents:write`, `pull_requests:write`, `metadata:read` | `github-app-jackin-daemon` (same field shape as `GitHub App — jackin-package-updater`) | `op://jackin/github-app-jackin-daemon/PEM private key`, `…/App ID`, `…/Installation ID` | runtime | **PARTIAL** — `tailrocks/GitHub App — jackin-package-updater` and `…tailrocks-package-updater` exist but are scoped to package-update repos and permissions; a daemon app (or widened installation) is needed. Repo-scope PATs on `Private/GitHub` are tap-publisher/renovate/read-only, not PR-management |
| 6 | GitHub human login for browser profile (D-032) | LOGIN with TOTP | existing `Private/GitHub` (2011 item, has `Key` OTP + recovery codes) | `op://Private/GitHub/Key` for OTP during first login only | setup | **EXISTS** (`Private/GitHub`) |
| 7 | `gh` CLI in the daemon host / container (`GH_TOKEN`) | derived from #5 (installation token) or PAT | none extra if #5 is an App; otherwise `github-daemon-pat` | `op://jackin/github-daemon-pat/token` | runtime | **PARTIAL** — covered by #5 once decided |
| 8 | Claude runtime in daemon-run containers | OAuth token (subscription) or `ANTHROPIC_API_KEY` | `claude-daemon` field `auth token` (or `api key`) | `op://jackin/claude-daemon/auth token` | runtime | **PARTIAL** — `Private/Claude (2026-04-27)` has `auth token`; `Private/Anthropic` and `Private/Claude (2026-03-20)` have API-key fields; nothing dedicated, nothing referenced. Today `auth_forward = "sync"` from the laptop |
| 9 | Codex runtime | ChatGPT OAuth login or `OPENAI_API_KEY` | `codex-daemon` | `op://jackin/codex-daemon/api key` | runtime | **PARTIAL** — 4 `Private/OpenAI` logins, no API-key field, no token item |
| 10 | Amp runtime | Amp API key / settings token | `amp-daemon` | `op://jackin/amp-daemon/api key` | runtime | **PARTIAL** — `Private/Amp Code` login only (SSO) |
| 11 | Kimi runtime | `KIMI_CODE_API_KEY` | reuse `ChainArgos/Kimi/API Keys/Test` or move to `jackin/kimi-daemon` | already `op://…/API Keys/Test` in `config.toml` | runtime | **EXISTS** (`ChainArgos/Kimi`, field `Test`); rename field from `Test` recommended |
| 12 | OpenCode runtime | API key | reuse `Private/OpenCode` field `API key` | `op://Private/OpenCode/API key` | runtime | **EXISTS** (`Private/OpenCode`), not yet referenced |
| 13 | Grok runtime | `XAI_API_KEY` | `grok-daemon` | `op://jackin/grok-daemon/api key` | runtime | **PARTIAL** — `Private/xAI` and `ChainArgos/xAI` logins, no API-key field |
| 14 | Provider overrides used by the-architect (Z.ai, MiniMax, Context7) | API keys | keep existing | existing refs in `config.toml` | runtime | **EXISTS** (`ChainArgos/Z.ai`, `ChainArgos/MiniMax`, `Private/Context7`) |
| 15 | Pull role images / push locally built role images (Docker Hub `projectjackin/*`, GHCR) | registry token | `registry-dockerhub` (or reuse `Private/Docker` field `GitHub`) ; GHCR via #5 | `op://jackin/registry-dockerhub/token` | runtime (pull) / setup (push) | **PARTIAL** — Docker Hub logins exist with a CI token field; public role images need no credential to pull; nothing named for jackin |
| 16 | Role/image signing | cosign key or keyless (Sigstore OIDC) | none if keyless in CI; `cosign-role-signing` if key-based | `op://jackin/cosign-role-signing/private key` | setup (CI) | **CREATE only if key-based** — no cosign item exists; jackin release uses cosign/attestation sidecars in CI, likely keyless; open |
| 17 | Headless `op` for the daemon itself (server host, no desktop app) | 1Password service account token scoped to vault `jackin` | `op-service-account-jackin-daemon` (store in `tailrocks`, **not** in the vault it unlocks) | `OP_SERVICE_ACCOUNT_TOKEN` from `op://tailrocks/op-service-account-jackin-daemon/credential` at daemon start | runtime | **CREATE** — pattern exists (`ChainArgos/ruxel CI service account`, `…lightdash-migration-agent`) |
| 18 | Webhook relay (Hookdeck / Cloudflare Worker / smee) for daemon behind NAT (Q-015) | relay API key or Worker deploy token | `webhook-relay` | `op://jackin/webhook-relay/token` | runtime | **DEFER** — polling adopted (Q-015, D-053); no relay in the prototype |
| 19 | Homebrew tap publish for jackin releases (D-034 releases) | PAT | existing | `op://Private/GitHub/jackin-homebrew-tap-publisher` | setup (release) | **EXISTS** (`Private/GitHub`, field `jackin-homebrew-tap-publisher`) |
| 20 | Git author identity for the daemon's commits/PRs (DCO sign-off) | not secret; name + email | config, not 1Password | — | runtime | n/a |

Counts: **EXISTS 6** (#4, #6, #11, #12, #14, #19; #14 counts three
provider keys as one row), **PARTIAL 7** (#5, #7, #8, #9, #10, #13, #15),
**CREATE 5** (#1, #2, #3, #17, #18); #16 is conditional (CREATE only if
key-based signing is chosen).

## 5. Gaps and recommendations

### 5.1 Vault and naming

- Create a dedicated vault **`jackin`**. Everything the daemon needs at
  runtime lives there, nothing else does. This gives the 1Password service
  account (#17) a single-vault scope and makes the audit trivial.
- Item names: lowercase, hyphenated, `<system>-<role-of-credential>`:
  `linear-agent-app`, `linear-workspace-<org>`, `github-app-jackin-daemon`,
  `claude-daemon`, `codex-daemon`, `amp-daemon`, `grok-daemon`,
  `registry-dockerhub`, `webhook-relay`. Field names: lowercase words with
  spaces, matching what the vendor calls them (`client id`, `client secret`,
  `refresh token`, `PEM private key`). The two existing `GitHub App — …`
  items in `tailrocks` are the template for the App shape.
- Do not add more concealed fields to the personal `GitHub` and `Claude`
  login items. That pattern (`jackin-renovate`, `Mega token`, `Zed`,
  `chainargos`) already makes it impossible to tell which token is used
  where or to rotate one without opening the whole account item. Move the
  daemon's tokens into their own items.
- Rename `ChainArgos/Kimi` field `Test` and `Z.ai` field `Test` to something
  that states the purpose (`jackin`), or copy to `jackin/kimi-daemon`. UUID
  references in `config.toml` survive the rename.

### 5.2 One item per credential

- One item per **rotation unit**. The Linear OAuth app is one item (client
  id, client secret, webhook signing secret rotate together, invalidating
  each other). Each workspace installation is a separate item because its
  refresh token rotates independently and the daemon writes it back.
- GitHub App private key is its own item; installation ids are metadata on
  it, as the existing `…-package-updater` items do.
- Runtime provider keys are one item each. The daemon resolves per role
  launch via `jackin config env set KEY "op://…" --role <role>` which is
  already supported; grouped items would force wide `op read` scopes.

### 5.3 Runtime vs setup

| Needed by the daemon at runtime | Setup-only |
| --- | --- |
| #1 client id/secret, #2 webhook secret, #3 workspace tokens, #5/#7 GitHub App key, #8–#14 provider keys, #15 registry pull if private, #17 service account, #18 relay | #4 Linear SSO, #6 GitHub login + OTP for the browser profile, #16 signing (CI), #19 tap publish |

- Runtime references are resolved with `op read` at launch and never
  persisted (jackin-env behaviour). The daemon must resolve **per launch**,
  not cache in memory across restarts, so rotation takes effect without a
  restart.
- The browser profile (D-032) is a directory, not a credential; its
  location goes in the environment setup, its logins are #4 and #6. After
  first login the profile holds session cookies for Linear and GitHub, so
  the profile directory itself must be treated as a secret (not committed,
  not mounted into role containers other than the implementing role).

### 5.4 Rotation

- Linear access tokens last 24 h and refresh tokens rotate on every
  refresh; the daemon writes the new refresh token back to
  `linear-workspace-<org>` immediately (`op item edit`), keyed by
  `organization id`. A missed write-back loses the installation; the
  recovery is re-authorising through the browser profile.
- Rotating the Linear client secret invalidates all client-credentials
  tokens; rotate #1 and re-run the authorise flow for #3 in one step.
- GitHub App private keys can have two active keys; rotate by adding the
  new key to the item as a new field, switching, then removing the old.
- Provider API keys: 90-day rotation, one item each, so a leak of one
  runtime's key does not require touching the others.
- The 1Password service-account token (#17) is itself a credential; store
  it in `tailrocks` (a vault the service account cannot read) and rotate
  when the daemon host changes.

### 5.5 Open items feeding `OPEN-QUESTIONS.md`

- #15/#16: whether role images pushed from a developer machine (D-034) are
  signed at all; if yes, key-based or keyless. Affects whether a cosign key
  item exists.
- #18: relay choice (Q-015) determines which token is created.
- #5: one GitHub App for `jackin-project`, `tailrocks`, `chainargos`
  installations versus one per org. The two existing package-updater apps
  are per org, which suggests per org.
- `auth_forward = "sync"` remains the right mode for the laptop prototype;
  the switch to `op://`-backed provider keys is required at the "one server
  host" step of SPEC §9. Record that as the trigger, so the prototype is
  not blocked on #8–#13.
