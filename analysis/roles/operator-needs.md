# What `the-operator` role needs

Date: 2026-08-27. Scope: the jackin role that performs the operator tasks
of the managed-execution effort — Linear workspace configuration (M1-09,
M1-11, M1-12), Linear OAuth agent app creation and authorization (M1-07,
M1-10), GitHub App creation (M7-01), 1Password vault and item work (M1-03,
M1-07, M1-10, M7-01, M10-01), the persistent `agent-browser` profile
(M1-06), and every proof run (M2-07, M3-07, M4-06, M5-03, M6-04, M7-03,
M8-02, M9-05, M10-03, M11-03) [`ROADMAP.md:54-133`, `ROADMAP.md:261`].
Claims are tagged **[code]** (verified in a local repository or binary),
**[doc]** (vendor or jackin documentation), **[host]** (observed on this
laptop), or **[proposal]** (recommendation). Repository paths are under
`/Users/donbeave/Projects/tailrocks/`.

## 1. What the tasks actually do

| Task | Surface touched | Mechanism | Credential involved |
| --- | --- | --- | --- |
| M1-03 vault + item shell | 1Password | `op vault create`, `op item create` (no secret values) | `op` session or service account with write on vault `jackin` |
| M1-06 browser profile | Linear, GitHub UI | `agent-browser --profile <dir>` first login, Google SSO + GitHub TOTP | `Private/Linear` (SSO marker), `Private/GitHub` incl. OTP `Key` (`concept/credentials.md` §4 rows 4, 6) |
| M1-07 Linear OAuth app | Linear settings UI (no API for app creation, `analysis/linear-agents.md` A1 step 1) | browser profile; then `op item edit linear-agent-app` with three secrets | browser session; `op` write on `jackin` |
| M1-09 labels, states, template | Linear UI + GraphQL | browser; `curl` to `api.linear.app/graphql` for verification | workspace token (`op://jackin/linear-workspace-<org>/access token`) |
| M1-10 authorize `actor=app` | Linear OAuth (browser consent) + token endpoint | browser to `/oauth/authorize?actor=app&scope=…`; `curl` to `/oauth/token`; `op item create linear-workspace-<org>` | client id/secret read; `op` write |
| M1-11, M1-12 issues | Linear UI + GraphQL | browser screenshots; `curl` mutations | workspace token read |
| M7-01 GitHub App | GitHub settings UI (App manifest flow or form) | browser profile; `op item create github-app-jackin-daemon` (PEM, App ID, Installation ID); `gh api` to verify | GitHub session; `op` write |
| M10-01 runtime items + service account | 1Password UI or `op` | `op item create <runtime>-daemon`, service-account creation is UI-only (`op service-account create` exists but token display is one-shot) | `op` write on `jackin`; `tailrocks` write for #17 |
| Proof runs | Linear UI, local `jackin` | `agent-browser screenshot`, `jackin daemon status --format json`, `docker ps` on the host | browser session; read-only tokens |

Two facts shape everything below. First, three of the tasks (M1-07, M7-01,
M10-01 service account) are **browser-only** at the vendor: Linear has no
API to create an OAuth application [doc: `analysis/linear-agents.md:21-24`],
and GitHub Apps are created through the settings form or the App Manifest
flow, both of which start in a browser (the manifest flow ends with
`POST /app-manifests/{code}/conversions`, which returns `id`, `client_id`,
`client_secret`, `webhook_secret`, and `pem`, but the `code` is only issued
after a browser POST to `https://github.com/settings/apps/new?state=…` and
must be exchanged within an hour) [doc:
https://docs.github.com/en/apps/sharing-github-apps/registering-a-github-app-from-a-manifest,
https://docs.github.com/en/rest/apps/apps]. The manifest flow is preferable
for M7-01 because the five secrets arrive in one JSON response that can be
piped straight into `op item create` without ever being shown on a page. Second, every task that *creates* a credential
must write it to 1Password in the same step [D-035, `DECISIONS.md:401-423`],
so the role needs a write path into vault `jackin` from inside the container.

## 2. Tool list

| Tool | Version to pin | Why | Where it comes from |
| --- | --- | --- | --- |
| `agent-browser` | 0.35.1 (host version and latest release, 2026-08-26 [host; doc: https://github.com/vercel-labs/agent-browser/releases/latest]) | D-032 visual verification; only browser driver the effort standardises on | npm package `agent-browser` (100 % Rust CLI + Rust daemon speaking CDP since 0.20; `bin/agent-browser.js` is a Node launcher that execs the platform binary) [code: `/opt/homebrew/Cellar/agent-browser/0.35.1/libexec/lib/node_modules/agent-browser/bin`; doc: CHANGELOG] |
| Chrome for Testing | whatever `agent-browser install` resolves (host has 152.0.7977.64 [host: `agent-browser doctor`]) | the daemon speaks CDP to a real Chrome; "No Playwright or Node.js required for the daemon" [doc: package `README.md:79`] | `agent-browser install --with-deps` at image build, run as `agent` so the cache lands in `/home/agent/.agent-browser/browsers` |
| Node | 24.x via mise, same pin as agent-smith (`24.19.0`) [code: `jackin-agent-smith/Dockerfile:12`] | the npm launcher needs `node` on `PATH`; package `engines.node >= 24` [code: `package.json`] | mise, as in agent-smith |
| `op` | 2.39.0 (host version and current release, 2026-08-14 [host; doc: https://app-updates.agilebits.com/product_history/CLI2]) | M1-03, M1-07, M1-10, M7-01, M10-01 item writes; `op read` for verification | 1Password apt repository (`downloads.1password.com/linux/debian/<arch> stable main`, keyring `1password.asc`, debsig policy) [doc: https://www.1password.dev/cli/get-started/] |
| `gh` | construct base (host has 2.98.0) | M7-01 verification (`gh api /installation/repositories`), PR checks in proof runs | already in `projectjackin/construct` [code: `jackin/docker/construct/Dockerfile:137-143`] |
| `jq`, `curl` | construct base | every `verify.sh` in ROADMAP pipes `op … --format json` through `jq`; GraphQL through `curl` [`ROADMAP.md:54,58,61`] | construct apt list [code: `construct/Dockerfile:35,42`] |
| `openssl` | Debian package | mint the GitHub App JWT (RS256) for the M7-01 verification; `gh` has no built-in App JWT support and GitHub's reference example is bash + openssl [doc: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app] | apt (already a dependency of `ca-certificates`) |
| Python | not needed | no task in the operator's list runs Python; keeping the toolchain out keeps the image small and the blast radius narrow [proposal] | — |
| Xvfb | optional Debian package | only if `--headed` is ever needed inside the container (agent-browser starts a private virtual display when `DISPLAY` is unset and Xvfb exists) [doc: `README.md:1234`]; first login happens on the host (§8), so leave it out unless WebGPU screenshots become necessary | apt |

Not shipped: Rust toolchain, OpenTofu, Docker-in-Docker (`[docker] dind =
"none"`), provider override plugins. The role's blast radius is Linear,
GitHub settings, and one vault [`ROADMAP.md:261`].

## 3. The persistent browser profile (Q-017)

**How agent-browser persists login.** `--profile <path>` (or
`AGENT_BROWSER_PROFILE`) points Chrome at a user-data directory; "this
persists everything (cookies, IndexedDB, service workers, cache) across
browser restarts without explicit save/load" [doc: `skill-data/core/references/authentication.md:75-99`].
The alternative, `--session <name> --restore`, stores only cookies and
localStorage as an encrypted JSON under `~/.agent-browser` [doc:
`README.md:755`]; it is lighter but not what D-032 asks for ("one static
profile"). Screenshots are `agent-browser screenshot [path]` with `--full`
and `--annotate` variants; headless output hides scrollbars [doc:
`SKILL.md:278-287`].

**Headless and containers.** The default is headless [doc: `SKILL.md:440`];
a profile *directory* works headless (a profile *name* instead copies the
real Chrome profile to a temporary snapshot, which is not what we want)
[doc: README "Persistent Profiles" / "Chrome Profile Reuse"]. Since 0.16.1
agent-browser detects Docker/Podman/Kubernetes and adds `--no-sandbox`
itself [doc: CHANGELOG; https://github.com/vercel-labs/agent-browser/issues/70],
so the container never needs a display or extra Chrome flags for the
steady state; `--with-deps` also installs CJK and emoji fonts, which
matters for screenshots of issue titles [doc: CHANGELOG #1002].

**Google SSO inside a headless profile.** The Linear login is Google SSO
(`Private/Linear`, `alexey@chainargos.com`) [`concept/credentials.md` §4 row
4]. Google is known to refuse sign-in from automation-controlled or headless
Chrome ("This browser or app may not be secure") — a Google behaviour, not
something the agent-browser documentation discusses; that documentation
steers 2FA and SSO logins to `--headed` plus a human, or to importing
cookies from a Chrome the human is already logged into (`--auto-connect
state save`) [doc: `authentication.md:22-60,280-296`]. Once the Google
session cookie and the Linear session cookie exist in the profile, Linear
itself does not re-contact Google until its session expires, so the profile
survives headless use; what does not survive is a **fresh** Google login
from headless. Conclusion: the first login is a human-on-host step (§8),
the profile is then reused read-mostly by containers.

**Recommendation (Q-017).**

| Item | Recommendation |
| --- | --- |
| Host path | `~/.jackin/agent-browser-profile` (ROADMAP §6 candidate) [`ROADMAP.md:352`]; `0700`, owner = operator |
| Mount | scoped global mount: `jackin config mount add agent-browser-profile --src ~/.jackin/agent-browser-profile --dst /home/agent/.agent-browser-profile --scope "donbeave/the-operator"` and a second entry for the browser-capable implementation role [doc: `jackin/docs/content/(public)/guides/mounts.mdx:97-110`]. Not read-only: Chrome writes cookies, and a read-only profile breaks token refresh. |
| Env | role manifest `[env.AGENT_BROWSER_PROFILE] default = "/home/agent/.agent-browser-profile"` so no per-command flag is needed |
| Chrome lock | a Chrome user-data directory holds a `SingletonLock`; two Chrome processes on one profile (host and container, or two containers) collide. Run at most one operator instance at a time, and never keep a host `agent-browser --profile` daemon alive while a container uses it. agent-browser's daemon idles out after one hour and can be closed with `agent-browser close --all` [doc: `README.md:1582`]. |
| Secrecy | the directory is a credential: full Linear and GitHub session for the human account. Listed as a secret in `AGENTS.md`; `.gitignore` in every repository that could see it (`ROADMAP.md:57`); never copied into an image layer, never put under `/workspace` |
| Backup | none. Loss = redo M1-06 by hand. Do not put it in 1Password as a document (it is tens of MB and rotates on its own) |
| UID | construct runs as the host UID/GID (libnss-extrausers) [code: `construct/Dockerfile:63-67`], so the host-owned directory is writable in-container without chown |

Two agent-browser constraints matter for the role: `--allowed-domains`
refuses to work with Chrome profiles [doc: `SKILL.md:122`], so network
containment must come from the jackin Docker profile, not from
agent-browser; and the default unnamed session is shared across every agent
on the machine, so the role should always pass `--session operator` [doc:
`SKILL.md:32`].

## 4. Writing to 1Password from the container (Q-018)

**What does not work.** The 1Password desktop-app integration ("Integrate
with 1Password CLI", biometric unlock) hands `op` a session through a Unix
socket opened by the desktop app, which also verifies the calling binary
[doc: https://www.1password.dev/cli/biometric-security/]. On this laptop
those sockets are `0600` files under
`~/Library/Group Containers/2BUA8C4S2C.com.1password/t/` [host]. A Docker
Desktop container runs in a Linux VM and cannot present a code-signed macOS
client on that socket; 1Password publishes no container support for the
integration, and a 1Password employee's answer to the dev-container question
is "use a service account" [doc:
https://www.1password.community/discussions/developers/1password-cli-biometric-authentication-in-dev-container/26375].
So an `op` inside the container has exactly two ways to authenticate: a
**service account token** in `OP_SERVICE_ACCOUNT_TOKEN`, or a 1Password
Connect server (self-hosted REST API, not deployed here) [doc:
https://www.1password.dev/secrets-automation/]. Service accounts fit the
design: permissions are per vault (`read_items`, `write_items`), fixed at
creation, cannot reach `Private` vaults at all, `op item create` and
`op item edit` are supported, and the token is shown once [doc:
https://www.1password.dev/service-accounts/get-started/,
https://www.1password.dev/service-accounts/use-with-1password-cli/].
Write rate limits (100/h on Individual/Families and Teams plans, 1,000/h on
Business) are far above what the operator tasks need [doc:
https://www.1password.dev/service-accounts/rate-limits/].

**What jackin offers today.** jackin's host-side `op` use is `op read` only:
launch-time `op://` env values are resolved on the host and injected as an
env file [code: `analysis/jackin.md:137-138`], and `jackin-exec` resolves
`on_demand = true` env values on the host through `host.sock` **and then
runs the command inside the container with those values in its environment,
redacting output** [doc: `jackin/docs/content/roadmap/(isolation-security)/jackin-exec.mdx:9-15`;
code: `jackin/crates/jackin-runtime/src/exec_host.rs:1-35`]. It does not run
host-side commands; the "approved host actions" host bridge is design-only
and deferred behind the daemon [doc: `jackin/docs/content/roadmap/(reactive-daemon-program)/(host-integration)/host-bridge.mdx:5-7`].
The ROADMAP §6 wording "jackin-exec binding for `op item create/edit`
executed host-side" [`ROADMAP.md:353`] therefore does not describe a
mechanism that exists; what exists is: a binding that injects a token into
one in-container `op` invocation after the operator confirms a picker.

`on_demand` is set in **operator env config** (global / role / workspace ×
role layers), not in the role manifest [code:
`jackin/crates/jackin-env/src/resolve.rs:576-612`; doc:
`jackin-exec-design.mdx:41-62`]. Launch injects only the binding *names* as
`JACKIN_EXEC_BINDINGS`, which also registers the `jackin_exec` MCP tool and
a system-prompt block [doc: `jackin-exec.mdx:9`].

**Recommendation.**

| Host | Mechanism | Token scope | Notes |
| --- | --- | --- | --- |
| Laptop (M1..M9) | `jackin-exec` binding: workspace × role env `OP_SERVICE_ACCOUNT_TOKEN = { op = "op://tailrocks/op-service-account-jackin-operator/credential", on_demand = true }`; the agent runs `jackin-exec op item create …`; the operator confirms in the picker | service account with **read + write on vault `jackin` only**; no access to `Private`, `tailrocks`, `ChainArgos` | Token never sits in `printenv`; each write is a visible, operator-approved event. Residuals: picker needs the operator at the TUI (fine for `jackin load` by hand, D-033), macOS/Docker Desktop lacks the `SO_PEERCRED` peer check, and the flow has had no live smoke pass [doc: `jackin-exec.mdx:5,22-24`]. If the picker path fails in M1-03, fall back to the same token as a plain launch-time `op://` value for that one session and record it in the task folder. |
| Server (M10+) | `OP_SERVICE_ACCOUNT_TOKEN` resolved at launch from the daemon's own service account (`credentials.md` #17) | daemon service account: **read** on `jackin`; the operator role's *write* token stays separate | Two service accounts, two rotation units: the daemon's read token is on every launch; the operator's write token is only on operator launches. `M10-01` creates both. |
| Either | vault `jackin` only | the token for `tailrocks/op-service-account-…` items lives in `tailrocks`, which neither service account can read [`concept/credentials.md` §5.4] | Storing #17 outside the vault it unlocks is what makes rotation possible. |

Why a service account rather than the human `op` session: it is the only
headless auth `op` supports, it can be scoped to a single vault, and
1Password logs its actions separately from the human's. Why on-demand rather
than launch-time on the laptop: a write-capable token that sits in the
container environment for the whole session is exactly the exposure
jackin-exec was built to remove, and the operator role runs long browser
sessions in which a hijacked page could reach the shell.

## 5. Runtimes

`agents = ["claude", "codex"]` [`ROADMAP.md:56,261`]. The lane table
schedules operator tasks on L3 (Claude, Sonnet 5), L5 and L6 (Codex)
[`ROADMAP.md:288-291`], so both runtimes must be installable; nothing in the
task list needs Amp, Kimi, OpenCode, or Grok, and each extra runtime is
another credential handoff directory under `/jackin/<agent>` [code:
`analysis/jackin.md:139`]. The `[codex]` table is required when `codex` is
listed [doc: `role-manifest.mdx:149-151`]. `jackin_exec` is an MCP tool
registered by the capsule for whichever runtime is launched [doc:
`jackin-exec.mdx:9`]; the Claude entrypoint additionally receives a
`--system-prompt` block naming the bindings [code: `analysis/jackin.md:152`],
so Claude is the safer runtime for the 1Password-writing tasks until the
Codex path is proven in M1-03 (which the lanes already assign to L6/Codex —
that task doubles as the proof).

## 6. Threat model

- **The profile directory is the human account.** Whoever reads
  `~/.jackin/agent-browser-profile` is `alexey@chainargos.com` on Linear
  (workspace admin, can create OAuth apps) and on GitHub (owner of
  `donbeave`, member of `tailrocks`/`chainargos`, can create Apps and
  tokens). This exceeds any token the daemon holds. Mount it only into
  roles that need a browser; never into `agent-smith` or the daemon's
  worker roles.
- **Prompt injection through the page.** The role reads untrusted web
  content (issue bodies, PR comments, third-party pages during OAuth
  redirects) with a shell behind it. Mitigations: `--session operator`,
  no `compat` profile, `dind = "none"`, and the write token gated by the
  picker. The jackin `hardened` profile (allowlist: model API + GitHub)
  cannot be used because Linear and Google endpoints are required; run
  `standard` with a workspace-level `network = "allowlist"` grant listing
  `linear.app`, `api.linear.app`, `accounts.google.com`, `*.google.com`,
  `github.com`, `api.github.com`, `*.1password.com`, `*.1password.eu` (whichever region), and the
  Chrome for Testing host only if `install` runs at launch instead of at
  build [doc: `docker-profiles.mdx:101-116,205-214`].
- **Credential creation is one-way.** The role creates secrets it must
  never see again in plain text: it writes `op item create` output to
  nothing (`> /dev/null`), verifies with `--format json | jq 'has("value")'`
  [`ROADMAP.md:58`], and never prints `op read` results. The Codex and
  Claude entrypoints run with permission prompts disabled [code:
  `analysis/jackin.md:147-160`], so the rule lives in `AGENTS.md` and in
  the task prompts, not in the runtime.
- **Must never do:** widen the service account beyond vault `jackin`;
  create personal access tokens on the human GitHub account (M7-01 creates
  an *App*); change Linear workspace security or SSO settings; log in to a
  second Google account in the profile; copy the profile anywhere; commit
  or screenshot pages showing secrets (Linear shows the client secret once
  on creation — capture after it is hidden, or crop); run with `compat`.
- **Screenshots are evidence, not secrets.** They land in `tasks/<id>/`
  and are pushed; the role must screenshot after secrets are masked and
  must not screenshot 1Password pages at all.
- **Out of scope**, as in agent-smith's list: a compromised construct base
  or plugin marketplace, and secrets an operator mounts by hand [code:
  `jackin-agent-smith/AGENTS.md` "What this does NOT protect against"].

## 7. Proposed role spec

Name `donbeave/jackin-the-operator` (repository `jackin-the-operator` under
the `donbeave` GitHub account, selector `donbeave/the-operator`) [D-045,
`DECISIONS.md:646-660`]. Trust is granted once with `jackin config trust
grant donbeave/the-operator` (Q-022) [doc: `security-model.mdx:86-95`].

Base: `projectjackin/construct:0.36-trixie` digest-pinned, to match
`the-architect`; construct already carries `gh`, `jq`, `curl`, `git`,
`ripgrep`, `mise`, and runs as `agent` [code: `construct/Dockerfile:30-50,137-143,169`].

Dockerfile install list, in order: apt `unzip openssl` plus the 1Password
apt repository and `1password-cli`; mise `node@24.19.0` pinned as in
agent-smith [code: `jackin-agent-smith/Dockerfile:12-20`]; `npm i -g
agent-browser@0.35.1`; `agent-browser install --with-deps` (needs root for
the library step, so split: `USER root` for `--with-deps` libraries via apt,
then `USER agent` for `agent-browser install`, which downloads Chrome for
Testing into `/home/agent/.agent-browser/browsers`). Record the trust anchor
for the npm package (vercel-labs, Apache-2.0) and for the Chrome for Testing
download host in `AGENTS.md`, following agent-smith rule 2.

```toml
version = "v1alpha6"
dockerfile = "Dockerfile"
published_image = "docker.io/donbeave/jackin-the-operator:latest"
agents = ["claude", "codex"]

[identity]
name = "The Operator"

[claude]
model = "claude-sonnet-4-6"
plugins = ["github@claude-plugins-official"]

[codex]

[docker]
min_profile = "standard"
dind = "none"
allowed_hosts = ["linear.app", "api.linear.app", "accounts.google.com",
  "github.com", "api.github.com", "my.1password.com"]

[hooks]
preflight = "hooks/preflight.sh"   # agent-browser doctor --json; fail if Chrome missing or profile unwritable

[env.AGENT_BROWSER_PROFILE]
default = "/home/agent/.agent-browser-profile"

[env.AGENT_BROWSER_SESSION]
default = "operator"

[env.AGENT_BROWSER_SCREENSHOT_DIR]
default = "/workspace/evidence"

[env.OP_SERVICE_ACCOUNT_TOKEN]
interactive = true
skippable = true      # skipped on the laptop: value arrives via the on-demand binding
secret = true

[env.CLAUDE_CODE_NO_FLICKER]
default = "1"
```

Host-side configuration that accompanies the role (not in the repository):
the scoped global mount from §3; the workspace × role env entry
`OP_SERVICE_ACCOUNT_TOKEN = { op = "op://tailrocks/op-service-account-jackin-operator/credential", on_demand = true }`;
and a workspace network grant if the allowlist is used. The manifest cannot
declare mounts [doc: `mounts.mdx:85-110`], which is why the profile mount
is operator configuration.

Tasks served: M1-03, M1-05 (its own creation is done by the-architect),
M1-06, M1-07, M1-09, M1-10, M1-11, M1-12, M2-07, M3-07, M4-06, M5-03,
M6-04, M7-01, M7-03, M8-02, M9-05, M10-01, M10-03, M11-03
[`ROADMAP.md:54-133,261`].

## 8. What needs a human on the host

| Step | Why the container cannot do it | Who and how |
| --- | --- | --- |
| First Google SSO login into the profile (M1-06) | Google blocks headless/automation sign-in; the password lives in the human's Google account, not in `jackin`; may trigger a phone prompt | Human on the laptop: `agent-browser --headed --profile ~/.jackin/agent-browser-profile --session operator open https://linear.app/login`, complete SSO, then `agent-browser close --all` |
| First GitHub login with TOTP (M1-06) | OTP secret is in `Private/GitHub`, a vault the role's service account must not read | Same headed session; the human reads the OTP from 1Password |
| Re-login after session expiry | same as above | Human repeats the headed step; the role detects it (`agent-browser get url` lands on a login page) and stops with an `error` instead of attempting credentials |
| Creating the two service accounts (M10-01, and the operator write account before M1-03) | Service accounts are created in the 1Password web UI by an owner/admin and the token is shown once | Human creates them and stores the tokens in `tailrocks` |
| Linear workspace admin consent (M1-10) | `actor=app` authorization requires a workspace admin [doc: `analysis/linear-agents.md:25`]; the profile *is* the admin, so the role can click through, but the human should be the one deciding dedicated-vs-existing workspace (§6 of credentials) | Human decides; role executes in the profile |
| GitHub App installation on orgs (M7-01) | Installing on `tailrocks`/`chainargos` needs org owner approval; the profile has it, but the scope decision is a human one | Human approves the installation page the role opens |
| Picker confirmation for every 1Password write | jackin-exec is fail-closed and requires the operator at the TUI | The host session confirms via `tmux send-keys Space Enter` after checking the displayed command (D-082); never a human step during the run |

Everything else — creating the OAuth app form, filling scopes, running the
token exchange with `curl`, `op item create/edit`, label and template
creation, issue creation, screenshots — runs from the container with the
mounted profile and the on-demand token.

## 9. Open points this analysis raises

- `jackin-exec` has never had a live smoke pass and lacks the peer check on
  Docker Desktop [doc: `jackin-exec.mdx:5,22`]; M1-03 is the first real
  use and should record the outcome. If it fails, the fallback (launch-time
  token for one session) must be logged as a deviation.
- Whether `agent-browser install --with-deps` succeeds non-interactively on
  Debian 13 inside the construct image (it "exits nonzero if the package
  manager cannot install every required browser library" [doc:
  `README.md:63`]) is a build-time fact to verify in M1-05.
- The `SingletonLock` collision between a host daemon and a container on
  the same profile is a documented Chrome behaviour, not an agent-browser
  feature; the preflight hook should refuse to start if the lock file
  exists and its PID is alive.
- `--allowed-domains` cannot be used with a profile, so network containment
  is the jackin allowlist grant or nothing; the allowlist quality under DinD
  is irrelevant here because `dind = "none"`.
