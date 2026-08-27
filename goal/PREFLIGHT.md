# Operator preflight for the `/goal` run

Everything the human provides, once, before running `/goal Follow GOAL.md`
(D-050). Consolidated from the per-milestone "Operator preflight" lists in
`ROADMAP.md` §2. The host session runs every host *command* itself (trust
grants, `op vault create`, `jackin config`, Homebrew); the human does only
what needs a browser login, an OTP, a consent screen, a UI-created
credential, a physical host, or billing. Each item names the command that
proves it is in place; the session re-runs the §1 checks at every start.

Section §2 is mandatory before the first run. Sections §3..§5 can be done
in the same sitting (D-062 merges preflights) or later; an item not yet
done when its milestone starts becomes a row in `PREFLIGHT-DEFECTS.md`
and the run stops when nothing else is runnable.

## 1. Standing items (checked at every session start)

- [ ] OrbStack running, Docker context `orbstack`, no Docker Desktop
      (D-056). Proof: `docker context show` prints `orbstack`;
      `docker info --format '{{.NCPU}} {{.MemTotal}}'` shows the 18 CPU /
      ~122 GiB figures.
- [ ] Host stays awake for the whole run. Proof: the session starts
      `caffeinate -dims`; the human sets no sleep timer that overrides it
      and keeps the lid open or the machine on power.
- [ ] `gh auth status` shows `donbeave` with `repo` and `workflow` scopes;
      the account can create public repositories and mark a template.
- [ ] Provider logins current in all four account homes: `~/.claude`,
      `~/.codex`, `~/.codex-chainargos`, `~/.codex-chainargos2`. Proof:
      `claude --version` and a `claude -p 'ok'` under
      `CLAUDE_CONFIG_DIR=~/.claude`; `codex login status` under each
      `CODEX_HOME`. A login that expires mid-run is a preflight defect.
- [ ] 1Password desktop app unlocked with CLI integration on. Proof:
      `op whoami` succeeds and `op read op://Private/GitHub/username`
      resolves without a prompt.
- [ ] `tmux` installed (`brew install tmux`; container path of
      `goal/EXECUTION.md` §4). Proof: `tmux -V`.
- [ ] `agent-browser` installed on the host. Proof:
      `agent-browser --version` (0.35.1 or later).
- [ ] `~/.jackin/managed` on a disk with room for one checkout per issue
      (M3). Proof: `df -h ~/.jackin` shows tens of GiB free.

## 2. Before the first run (M1)

- [ ] The human's Linear account is a workspace admin (OAuth app creation
      in M1-07 and the `actor=app` consent in M1-10). Proof: Linear
      Settings → Administration is visible.
- [ ] The human's GitHub account owns the `jackin-project` and `tailrocks`
      organizations (M8-01 later needs owner consent screens). Proof:
      `gh api user/memberships/orgs --jq '.[]|[.organization.login,.role]'`
      lists both as `admin`.
- [ ] Vault `jackin` created in 1Password, and the **operator service
      account** created in the 1Password UI with read + write on vault
      `jackin` only; its token stored at
      `op://tailrocks/op-service-account-jackin-operator` (M1-05d,
      D-035; a service account cannot be created by the CLI). Proof:
      `op vault get jackin` succeeds;
      `op read op://tailrocks/op-service-account-jackin-operator | wc -c`
      prints a non-zero count (value never shown).
- [ ] Persistent browser profile logged in, headed, once (M1-06):
      `agent-browser --headed --profile ~/.jackin/agent-browser-profile --session operator`
      then sign in to Linear (Google SSO, `op://Private/Linear`) and GitHub
      (`op://Private/GitHub`, OTP from 1Password); close the browser so no
      `SingletonLock` remains. Proof:
      `agent-browser --profile ~/.jackin/agent-browser-profile open https://linear.app`
      shows the workspace without a login prompt, and no process holds
      the profile when the session starts.
- [ ] `jackin-preview` may still be installed; the session removes it in
      M1-02a (D-042). Nothing to do.
- [ ] `feat/managed-execution` may be created by the session in every
      involved repository (D-047); the human has push rights there. Proof:
      `gh repo view jackin-project/jackin --json viewerPermission` prints
      `ADMIN` or `WRITE`; same for `tailrocks/termrock`.

## 3. Before M4 (runtime matrix, M4-05)

- [ ] For each of Amp, Kimi, OpenCode, and Grok: either a host login in
      that runtime's config directory or an API key stored as
      `op://jackin/<runtime>-daemon` (`concept/credentials.md` §4). A
      runtime without a credential is recorded as skipped by M4-05, never
      as passed; leaving one out is allowed and is not a defect. Proof:
      `op item get <runtime>-daemon --vault jackin` per provided key.

## 4. Before M8 (GitHub App)

- [ ] Organization-owner consent screens for one GitHub App per
      organization are reachable through the browser profile (§2 owner
      item). If the App creation in M8-01 asks for a confirmation only the
      human can give, it is filed as a preflight defect and the run
      continues with everything else.

## 5. Before M10..M12 (blessing, server hosts)

- [ ] M10: blessing termrock golden frames (`TERMROCK_BLESS_PREVIEWS`) is
      a human approval after M10-03 and M10-04; the session files the
      frames and records the defect if the approval is not yet given.
      If termrock 0.14 publishes to crates.io, the publish token is stored
      under the `concept/credentials.md` §5.1 naming before M10-02.
- [ ] M11: one Docker server host (Docker installed, SSH reachable);
      address and SSH key in 1Password, referenced from `tasks/M11-03/`.
      Provider API keys for every runtime in use at
      `op://jackin/<runtime>-daemon` (credentials #8..#13, billing consent
      is a human action). The **daemon service account**, read-only on
      vault `jackin`, created in the 1Password UI with its token at
      `op://tailrocks/op-service-account-jackin-daemon` (#17). Docker Hub
      access token for `donbeave` stored as the two Hub secrets M11-02
      reads. Proof: `op item get` for each item; `ssh <host> docker info`.
- [ ] M12: a second server host provisioned exactly as in M11 and a
      network path from this Mac to both daemons. Proof: `ssh` to both.

## 6. What the human never has to do during the run

Assign issues, review or merge pull requests, answer design questions,
bless anything but golden frames, or re-run anything. If the session stops,
`PREFLIGHT-DEFECTS.md` lists exactly what is needed; clear it, mark the
rows resolved, and run `/goal Follow GOAL.md` again.
