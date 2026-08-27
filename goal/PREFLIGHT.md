# Operator preflight for the `/goal` run

Everything the human provides, once, before running `/goal Follow GOAL.md`
(D-050). Consolidated from the per-milestone "Operator preflight" lists in
`ROADMAP.md` §2. The host session runs every host *command* itself (trust
grants, `jackin config`, Homebrew); the human does only what needs a
browser login, an OTP, a consent screen, a UI-created credential, a
physical host, or billing. Each item names the command that proves it is
in place; the session re-runs the §1 checks at every start.

For a single uninterrupted run, complete all of §2..§5 before the first
run: each undone §3..§5 item is one guaranteed BLOCKED stop and re-run
cycle (`PREFLIGHT-DEFECTS.md`, D-070). §2 is mandatory before the first
run in any case.

## 1. Standing items (checked at every session start)

- [ ] OrbStack running, Docker context `orbstack`, no Docker Desktop
      (D-056). Proof: `docker context show` prints `orbstack`;
      `docker info --format '{{.NCPU}} {{.MemTotal}}'` shows the 18 CPU /
      ~122 GiB figures. Images build for the host's native platform
      (`docker version --format '{{.Server.Arch}}'` = `arm64`); no
      `--platform linux/amd64` emulation; any tool that ships only
      linux/amd64 binaries is replaced in the role (D-077).
- [ ] Host stays awake for the whole run. Proof: the session starts
      `caffeinate -dims`; the human sets no sleep timer that overrides it
      and keeps the lid open or the machine on power.
- [ ] macOS screen lock disabled for the run: System Settings → Lock
      Screen: start screen saver Never, "Require password after screen
      saver begins or display is turned off" Never; Energy: prevent
      automatic sleeping on power adapter. Proof: `defaults -currentHost
      read com.apple.screensaver idleTime` prints `0` (the session may set
      it: `defaults -currentHost write com.apple.screensaver idleTime 0`).
- [ ] 1Password desktop app unlocked, CLI integration on, and Security
      settings human-only: Auto-lock "Never" (or the maximum offered);
      "Lock on sleep, screensaver, or switching users" unchecked. Proof:
      `op whoami` succeeds and, after at least 15 minutes without
      keyboard or mouse input, `op read "op://Private/Context7/API Keys/Claude"
      </dev/null >/dev/null && echo ok` prints `ok` without any prompt
      (D-076). If the account policy forbids "Never", the daemon service
      account (#17) is created now instead of in M11 and the laptop
      daemon runs with `OP_SERVICE_ACCOUNT_TOKEN`; record it in the M2
      preflight note of `ROADMAP.md`.
- [ ] `gh auth status` shows `donbeave` with `repo` and `workflow` scopes;
      the account can create public repositories and mark a template.
- [ ] Provider logins current in all four account homes: `~/.claude`,
      `~/.codex`, `~/.codex-chainargos`, `~/.codex-chainargos2`. Proof:
      `claude --version` and `claude -p 'ok'` under
      `CLAUDE_CONFIG_DIR=~/.claude`; under each `CODEX_HOME`: `codex login
      status` and a real non-interactive call `codex exec -C /tmp 'print
      ok'` (login status alone does not prove `exec` works), and `codex
      exec --help` accepts `-c model_reasoning_effort=medium`. A login
      that expires mid-run is a preflight defect only when this host-side
      probe fails (D-082).
- [ ] `tmux` installed (`brew install tmux`; container path of
      `goal/EXECUTION.md` §4). Proof: `tmux -V` (not yet installed on this
      host at the time of writing).
- [ ] `agent-browser` installed on the host. Proof:
      `agent-browser --version` (0.35.1 or later) and `agent-browser
      --help` lists `state save` / `state load` (D-077).
- [ ] `gitleaks` installed on the host (`brew install gitleaks`; evidence
      scan, D-081). Proof: `gitleaks version`.
- [ ] `~/.jackin/managed` on a disk with room for one checkout per issue
      (M3). Proof: `df -h ~/.jackin` shows tens of GiB free.
- [ ] Every ref the roles pin resolves (D-078): `gh api
      repos/tailrocks/review-crucible/commits/<REVIEW_CRUCIBLE_SHA>` and
      `gh api repos/tailrocks/tailrocks-skills/commits/<TAILROCKS_SKILLS_SHA>`
      return 200, with the SHAs of `concept/roles.md` §3.1.

## 2. Before the first run (M1)

- [ ] The human's Linear account is a workspace admin (OAuth app creation
      in M1-07 and the `actor=app` consent in M1-10). Proof: Linear
      Settings → Administration is visible.
- [ ] The human's GitHub account owns the `jackin-project` and `tailrocks`
      organizations. Proof:
      `gh api user/memberships/orgs --jq '.[]|[.organization.login,.role]'`
      lists both as `admin`.
- [ ] `delete_branch_on_merge` is off in `jackin-project/jackin` and
      `tailrocks/termrock` so `feat/managed-execution` survives any squash
      merge (D-074). Proof: `gh api repos/<org>/<repo> --jq
      .delete_branch_on_merge` prints `false` for both (the human runs
      `gh api -X PATCH repos/<org>/<repo> -f delete_branch_on_merge=false`).
- [ ] Vault `jackin` created in 1Password (exactly one vault of that name),
      and the **operator service account** created in the 1Password UI
      with read + write on vault `jackin` only; its token stored as the
      `credential` field of the API Credential item
      `op://tailrocks/op-service-account-jackin-operator` (M1-05d,
      D-035, D-076; a service account cannot be created by the CLI, and
      the session never runs `op vault create`). Proof:
      `op vault list --format json | jq '[.[]|select(.name=="jackin")]|length'`
      prints `1`;
      `op read op://tailrocks/op-service-account-jackin-operator/credential | wc -c`
      prints a non-zero count (value never shown).
- [ ] Browser session for the operator role (M1-06, D-077). Headed, once,
      into a host-only profile:
      `agent-browser --headed --profile ~/.jackin/agent-browser-host-profile --session operator`
      then sign in to Linear (Google SSO, `op://Private/Linear`) and GitHub
      (item `GitHub` created 2011-05-10 in `Private`, OTP from 1Password);
      then save the OS-independent session state into the directory the
      container mounts:
      `mkdir -p ~/.jackin/agent-browser-profile && agent-browser --profile ~/.jackin/agent-browser-host-profile --session operator state save ~/.jackin/agent-browser-profile/state.json && chmod 600 ~/.jackin/agent-browser-profile/state.json`
      and `agent-browser --profile ~/.jackin/agent-browser-host-profile close --all`
      so no `SingletonLock` remains. `~/.jackin/agent-browser-profile`
      otherwise starts empty (Linux Chromium creates it; a macOS Chrome
      profile's cookies are unreadable there). Proof (Linux-side, after
      M1-05b has built the image; before that only `test -s
      ~/.jackin/agent-browser-profile/state.json`): `jackin load
      donbeave/crew-operator --agent claude` and inside `agent-browser open
      https://linear.app && agent-browser get url` prints the workspace
      URL, same for `https://github.com`; no host process holds a profile
      when the session starts. Session expiry mid-run = repeat this item
      and re-save `state.json` (the only planned re-login).
- [ ] GitHub App `jackin-daemon` created and installed by the human in
      each of `jackin-project` and `tailrocks` (sudo mode and owner
      consent are human-only, D-076), permissions `contents:write`,
      `pull_requests:write`, `metadata:read`; private key generated and
      stored as `op://jackin/github-app-jackin-daemon-<org>` with fields
      `app id`, `client id`, `installation id`, `PEM private key`
      (`concept/credentials.md` §5.1, §5.5). Proof: `op item get
      github-app-jackin-daemon-<org> --vault jackin --format json | jq
      '.fields[].label'` lists the four fields for both orgs; `gh api
      /orgs/<org>/installations --jq '.installations[].app_slug'` lists
      the App. Done now rather than before M8 because it is one sitting
      (D-062).
- [ ] `jackin-preview` may still be installed; the session removes it in
      M1-02a (D-042). Nothing to do.
- [ ] `feat/managed-execution` may be created by the session in every
      involved repository (D-047); the human has push rights there. Proof:
      `gh repo view jackin-project/jackin --json viewerPermission` prints
      `ADMIN` or `WRITE`; same for `tailrocks/termrock` and
      `jackin-project/jackin-the-architect`.
- [ ] Golden-frame blessing for M10-03 and M10-04 pre-approved (D-075):
      ticking this box is the recorded approval; the host session runs
      `mise run bless-previews` itself. Nothing to do at run time.

## 3. Before M4 (runtime matrix, M4-05)

- [ ] For each of Amp, Kimi, OpenCode, and Grok: either a host login in
      that runtime's config directory or an API key stored as
      `op://jackin/<runtime>-daemon/api key` (`concept/credentials.md`
      §4). A runtime without a credential is recorded as skipped by M4-05,
      never as passed; leaving one out is allowed and is not a defect.
      Proof: `op item get <runtime>-daemon --vault jackin --format json |
      jq '.fields[].label'` per provided key lists `api key`.

## 4. Before M8 (GitHub App)

- [ ] Covered by the §2 GitHub App item. M8-01 only verifies the
      installation and mints an installation token; no sudo-mode prompt is
      ever answered by the operator role.

## 5. Before M10..M12 (crates.io, server hosts)

- [ ] M10: blessing is pre-approved in §2 (D-075) and is never a task gate
      or a defect. If termrock 0.14 publishes to crates.io, the publish
      token is stored under the `concept/credentials.md` §5.1 naming
      before M10-02. Proof: `op item get <name> --vault jackin`.
- [ ] M11 (every item in vault `jackin` unless stated; field names are the
      contract M11-01 verifies, D-076):
      `op://jackin/claude-daemon/api key`, `op://jackin/codex-daemon/api key`,
      plus `amp-daemon`, `kimi-daemon`, `opencode-daemon`, `grok-daemon`
      (`/api key`) for every runtime in use (credentials #8..#13; billing
      consent is a human action);
      `op://jackin/registry-dockerhub/username` and `…/token` (Docker Hub
      access token for `donbeave`; M11-02 copies them into the GitHub
      Actions secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`);
      `op://jackin/server-host-1/address`, `…/ssh user`, `…/private key`
      (SSH Key item; one Docker server host with Docker installed and SSH
      reachable); the **daemon service account**, read-only on vault
      `jackin`, created in the 1Password UI with its token at
      `op://tailrocks/op-service-account-jackin-daemon/credential` (#17).
      Proof per item: `op item get <name> --vault jackin --format json |
      jq '.fields[].label'` lists the named fields; `op read
      op://tailrocks/op-service-account-jackin-daemon/credential | wc -c`
      non-zero; `ssh <ssh user>@<address> docker info` works from this
      Mac. M11-01's `op://tailrocks/...` check runs in the host session
      (the operator container can neither read nor write `tailrocks`).
- [ ] M12: `op://jackin/server-host-2/address`, `…/ssh user`,
      `…/private key` for a second server host provisioned exactly as in
      M11, and a network path from this Mac to both daemons. Proof: `ssh`
      to both.

## 6. What the human never has to do during the run

Assign issues, review or merge pull requests, answer design questions,
answer GitHub sudo-mode or capsule dialogs, bless anything (golden frames
are blessed by the session under D-075), or re-run anything. If the
session ends BLOCKED, `PREFLIGHT-DEFECTS.md` lists exactly what is needed
(a missing input or an `exhausted: <id>` row, D-070); clear it — leaving
the `Resolved` cell empty is fine, the session re-runs each proof command
at the next start — and run `/goal Follow GOAL.md` again.
