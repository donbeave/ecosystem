# jackin — analysis for the multi-agent orchestration planning effort

Date: 2026-08-27. Sources: local checkouts under `/Users/donbeave/Projects/tailrocks/jackin-project/` and `/Users/donbeave/Projects/tailrocks/vision/README.md`. Read-only analysis; nothing in the source was modified.

Path shorthand used throughout:

- `J/…` = `/Users/donbeave/Projects/tailrocks/jackin-project/jackin/…` (main Rust repo, HEAD `493149b2`, 2026-08-26)
- `P/…` = `/Users/donbeave/Projects/tailrocks/jackin-project/…` (sibling repos)
- `V` = `/Users/donbeave/Projects/tailrocks/vision/README.md`

Status vocabulary: **implemented** (code exists and is wired), **partial** (code exists with documented gaps), **documented only** (roadmap/research/prose, no code), **absent** (nothing in code or docs beyond a mention).

---

## 1. Identity

jackin❯ is a host CLI plus an in-container control plane that runs a single AI coding agent (Claude Code, Codex, Amp, Kimi, OpenCode or Grok) inside an isolated Docker (or Apple Container) container, with the agent's own permission bypass mode switched on unconditionally, and with the safety boundary moved from the agent's permission prompts to the container: scoped bind mounts, a Docker security profile with capability drops and an egress allowlist firewall, credentials forwarded through host-owned sockets, and a per-instance durable agent home (`J/README.md:10-12`, `J/docker/runtime/entrypoint.sh:77-136`). It is explicitly "the ecosystem layer around AI coding agents — not another agent itself" (`J/README.md:12`). The vision document positions it as the "orchestration & isolation" layer of the Tailrocks stack and promises multi-agent teams, roles, "runs anywhere", and a single control plane across TUI, macOS and phone (`V:103-131`). Of those promises, isolation, roles, the TUI and the macOS usage app exist; team collaboration, remote hosts, a fleet control plane and phone access do not (see §6, §10).

Maturity: pre-release proof-of-concept. `J/PRERELEASE.md:3` states there is no released version; `J/README.md:5-8` carries a "not production-ready … major breaking changes before a stable release" warning. `J/DEPRECATED.md:22` lists no active deprecations because pre-release changes are made as breaking changes rather than deprecations (`J/DEPRECATED.md:7`). `J/CHANGELOG.md` has only an `[Unreleased]` section and stays empty by policy until the first tag (`J/PRERELEASE.md:29`).

Release channel: rolling Homebrew preview only. `brew tap jackin-project/tap && brew install jackin@preview` (`J/README.md:19-22`); the preview formula is `P/homebrew-tap/Formula/jackin-preview.rb` (currently `0.6.4-preview.1149+ab8c1d8`), published by `J/.github/workflows/preview.yml` on every push to `main`. The stable formula `P/homebrew-tap/Formula/jackin.rb:10` is `disable!`d ("jackin has not reached a stable release yet"). Stable releases are tag-triggered (`v[0-9]*`) via `J/.github/workflows/release.yml:6-18` and would ship signed CLI archives, a separate `jackin-capsule` binary, and the notarized macOS desktop app.

Versioning: workspace version `0.6.4`, edition 2024, MSRV 1.97 (`J/Cargo.toml:37-39`), toolchain pinned to `1.97.1` (`J/rust-toolchain.toml:10-12`). Three on-disk schemas are versioned independently with migration registries: config `v1alpha9` (`J/crates/jackin-config/src/versions.rs:11`), workspace `v1alpha8` (`versions.rs:13`), role manifest `v1alpha6` (`J/crates/jackin-core/src/constants.rs:23`). The instance manifest has its own `INSTANCE_MANIFEST_VERSION = 2` outside that policy (`J/crates/jackin-instance/src/manifest.rs:24`). Release automation is `cargo-release` with `publish = false` (no crates.io) and tag `v{{version}}` (`J/release.toml:4-9`). All crates are `publish = false`.

License Apache-2.0; author's independent personal project (`J/README.md:96-100`).

---

## 2. Architecture

### 2.1 Workspace layout

One Cargo workspace with 32 members plus one excluded dylint crate (`J/Cargo.toml:6-34`). Each crate declares an "Architecture Invariant" tier T0…T6 in its doc header; lower tiers may not depend on higher ones. Grouped by tier:

| Tier | Crate | Purpose (from Cargo/lib header) |
|---|---|---|
| T0 | `jackin-core` | Universal vocabulary: `Agent`, `MountIsolation`, `AuthForwardMode`, selectors, constants, container paths, `RoleManifest` serde type (`J/crates/jackin-core/Cargo.toml:10`) |
| T0 | `jackin-brand` | Renderer-neutral identity + color tokens |
| T0 | `jackin-process` | Subprocess transport: capture, timeout, retry (`J/crates/jackin-process/Cargo.toml:10`) |
| T0 | `jackin-telemetry` | Governed OTel facade over a closed registry (`J/crates/jackin-telemetry/Cargo.toml:8`) |
| T0 | `jackin-term` | Owned terminal model (`DamageGrid`) for the capsule PTY multiplexer (`J/crates/jackin-term/Cargo.toml:10`) |
| T0 | `jackin-dev` | Binary: local PR-verification helper (`J/crates/jackin-dev/Cargo.toml:11`) — unrelated to the `jackin-dev` skills plugin repo |
| T1 | `jackin-config` | `AppConfig`, `WorkspaceConfig`, migrations, resolution (`J/crates/jackin-config/Cargo.toml:10`) |
| T1 | `jackin-protocol` | Wire types host CLI ↔ in-container capsule (`J/crates/jackin-protocol/Cargo.toml:10`) |
| T1 | `jackin-tui` | Cross-surface presentation over termrock (`J/crates/jackin-tui/src/lib.rs:1-8`) |
| T1 | `jackin-build-meta`, `jackin-pr-trailers`, `jackin-xtask` | Build helpers, git-trailer CLI, workspace automation |
| T2 | `jackin-agent-status` | Pure agent runtime status detection + arbitration (`J/crates/jackin-agent-status/Cargo.toml:7`) |
| T2 | `jackin-diagnostics` | Host observability substrate, tracing init, OTLP export (`J/crates/jackin-diagnostics/Cargo.toml:10`) |
| T2 | `jackin-manifest` | Role manifest load/validate/migrate (`J/crates/jackin-manifest/Cargo.toml:10`) |
| T3 | `jackin-docker` | bollard `DockerApi` impl (`J/crates/jackin-docker/Cargo.toml:10`) |
| T3 | `jackin-env` | `op://` + `$VAR` resolution, 1Password CLI (`J/crates/jackin-env/Cargo.toml:10`) |
| T3 | `jackin-instance` | Instance identity, `instances.json` index, auth provisioning, container naming (`J/crates/jackin-instance/Cargo.toml:10`) |
| T3 | `jackin-launch` | Launch-progress TUI (presentation only) |
| T3 | `jackin-oppicker` | Pure 1Password picker planning |
| T3 | `jackin-usage` | Usage/pricing/quota subsystem, host broker (`J/crates/jackin-usage/Cargo.toml:10`) |
| T3 | `jackin-otlp-testbed`, `jackin-test-support` | Test-only OTLP receiver; fakes |
| T4 | `jackin-capsule` | In-container PID 1 control plane: PTY multiplexer, daemon, TUI, MCP server, firewall (`J/crates/jackin-capsule/Cargo.toml:10`) |
| T4 | `jackin-console` | Operator console state machine + screens |
| T4 | `jackin-host` | Host OS integration: clipboard, caffeinate, desktop notifications (`J/crates/jackin-host/Cargo.toml:10`) |
| T4 | `jackin-image` | Derived-image generation, agent binary prefetch (`J/crates/jackin-image/Cargo.toml:10`) |
| T4 | `jackin-isolation` | Mount isolation: shared/worktree/clone materialization (`J/crates/jackin-isolation/Cargo.toml:10`) |
| T4 | `jackin-usage-ffi` | boltffi facade for the macOS menu-bar app (`J/crates/jackin-usage-ffi/Cargo.toml:10`) |
| T5 | `jackin-runtime` | Container bootstrap pipeline, DinD sidecar, host daemon, usage broker bin (`J/crates/jackin-runtime/Cargo.toml:10`) |
| T6 | `jackin` | Host CLI binary; also `jackin-role` and `build-jackin-capsule` bins (`J/crates/jackin/Cargo.toml:18-28`) |
| — | `jackin-lints` | Excluded dylint crate (render-thread purity lint) (`J/crates/jackin-lints/README.md:3-10`) |

Other top-level artifacts: `J/docker/construct/` (base image Dockerfile), `J/docker/runtime/` (`entrypoint.sh`, agent-status hooks), `J/native/` (Swift macOS app), `J/docs/` (Fumadocs site), `J/roadmap/`, `J/plans/`, `J/research/`, `J/prompts/`, and a dense set of governance files (`ENGINEERING.md`, `HOST_AND_CONTAINER.md`, `PRERELEASE.md`, `ratchet.toml`, `code-health-baseline.toml`, `container-path-allowlist.toml`).

### 2.2 Key abstractions

**Role.** A git repository containing `Dockerfile` + `jackin.role.toml` (`J/crates/jackin-core/src/constants.rs:11-14`). Selected as `name` or `namespace/name` (`J/crates/jackin-core/src/selector.rs:16-97`); built-in roles are only `agent-smith` and `the-architect` (`J/crates/jackin-config/src/app_config/roles.rs:186-195`); namespaced roles resolve to `https://github.com/{ns}/jackin-{name}.git` (`roles.rs:197-238`). Roles are cloned into `~/.jackin/roles[/ns]/name/{default,branches/<b>}` (`J/crates/jackin-runtime/src/runtime/repo_cache.rs:74-79,321-329`). Role source is git, not an OCI registry; `published_image` on Docker Hub is a warm base, not the source of truth (`J/crates/jackin-core/src/manifest.rs:28-33`).

**Construct base image.** `projectjackin/construct`, stable tag `trixie`, pinned form `0.N-trixie` (`J/crates/jackin-manifest/src/repo_contract.rs:28-41`). Debian 13, zsh/fish/starship, git, gh, Docker CLI + buildx + compose, mise, tirith, shellfirm, iptables/ipset, `libnss-extrausers`; no baked sudoers (`J/docker/construct/Dockerfile:1-186`). Built and published by `J/docker-bake.hcl:10-107` and `J/.github/workflows/construct.yml`. Current pins: construct `0.36-trixie` (`J/docker/construct/VERSION`).

**Derived image.** jackin generates a Dockerfile in Rust per role+agent set: per-agent install blocks, Claude plugin bake, `/jackin/default-home` snapshot, hook copies, `entrypoint.sh`, agent-status assets, capsule binary, `USER agent`, `ENTRYPOINT ["/jackin/runtime/jackin-capsule"]` (`J/crates/jackin-image/src/derived_image.rs:347-482`). Image tags prefixed `jk_` with labels driving reuse decisions (`J/crates/jackin-image/src/naming.rs:15-68`, `J/crates/jackin-image/src/image_decision.rs:129-172`).

**Agent runtime adapters.** Closed enum `Agent { Claude, Codex, Amp, Kimi, Opencode, Grok }` (`J/crates/jackin-core/src/agent.rs:23-48`) dispatching to a sealed `AgentRuntime` trait (`J/crates/jackin-core/src/agent/runtime.rs:70-85`) with one adapter file per agent under `J/crates/jackin-core/src/agent/adapters/`. Sealing means external crates cannot add agents.

**Instance.** One container launch with a durable home and identity. `InstanceManifest { instance_id, container_base, workspace_name, workdir, role_key, agent_runtime, image_tag, status, backend, sessions, … }` (`J/crates/jackin-instance/src/manifest.rs:89-115`); host index `~/.jackin/data/instances.json` under a flock (`manifest.rs:25-27,421-455`). Container names `jk-<id8>[-<workspace>]-<role>` (`J/crates/jackin-instance/src/naming.rs:16-63`).

**Session.** One agent tab/pane inside a live instance, multiplexed by the capsule daemon (`J/CONTEXT.md:11-13`); `SessionId(u64)` (`J/crates/jackin-core/src/session_id.rs:17-30`); persisted `SessionRecord` inside the instance manifest (`J/crates/jackin-instance/src/manifest.rs:113-114`); live state in `J/crates/jackin-capsule/src/session.rs`.

**Workspace + mounts.** `WorkspaceConfig { workdir, mounts, allowed_roles, default_role, default_agent, env, roles, keep_awake, git_pull_on_entry, runtime, dirty_exit_policy, docker }` (`J/crates/jackin-config/src/schema.rs:264-328`); `MountConfig { src, dst, readonly, isolation }` (`schema.rs:75-88`); `MountIsolation { Shared, Worktree, Clone }` (`J/crates/jackin-core/src/isolation.rs:30-72`) materialized by `jackin-isolation` (`J/crates/jackin-isolation/src/materialize.rs:556,622,785`). Worktree/clone give each container its own checkout and scratch branch.

**Credentials.** `AuthForwardMode { Sync, ApiKey, OAuthToken, Ignore }` per agent (`J/crates/jackin-core/src/auth.rs:15-36`), `GithubAuthMode { Sync, Token, Ignore }` (`J/crates/jackin-config/src/auth.rs:44-56`), layered workspace-role → workspace → global (`J/crates/jackin-config/src/auth.rs:20-38`). `EnvValue` = literal | `$VAR` | `op://` ref | on-demand (`J/crates/jackin-core/src/env_value.rs:29-36`). On-demand values are resolved by the host over `host.sock` on request (`jackin-exec`, §3.5).

**Tool profile / Docker security profile.** The docs use "tool profile" as prose for a role (`J/docs/content/(public)/getting-started/concepts.mdx:31`); there is no `tool_profile` type. The enforced concept is `DockerSecurityProfile { Locked < Hardened < Standard < Compat }` plus `DockerGrants { network, allowed_hosts, dind, user, sudo, system_writes, memory, cpus, pids, nofile, capabilities_add }` (`J/crates/jackin-core/src/docker_security.rs:15-183`); roles may declare a floor via `[docker]` in the manifest (`J/crates/jackin-core/src/manifest.rs:67-88`). Default profile recently changed from `compat` to `standard` (breaking; `J/CHANGELOG.md:15-17`).

**Capsule.** The in-container PID 1: zombie reaping and signal forwarding (`J/crates/jackin-capsule/src/pid1.rs:1-60`), PTY multiplexer built on `jackin-term`, attach socket, control socket, runtime setup, git hook, firewall/sudo provisioning, usage relay, MCP stdio server (`J/crates/jackin-capsule/README.md:3-14`). tmux is fully removed (`J/docs/content/roadmap/(reactive-daemon-program)/jackin-capsule.mdx:7`).

**Protocol.** `jackin-protocol` carries the attach frames (binary tag-framed, `J/crates/jackin-protocol/src/attach.rs:5-30`), the control channel (length-prefixed JSON one-shot request/response, `J/crates/jackin-protocol/src/control.rs:4-10`), `ExecBinding`/`CredRequest`/`CredReply` (`src/lib.rs:34-90`), usage-broker records, agent-status records and W3C trace context. Control requests today: `TelemetryHealth, Status, Snapshot, Agents, ReportRuntimeEvent, StatusCapture, UsageFocused, UsageRefreshFocused, UsageAccountList, ExecCommand, TokenUsage` (`control.rs:28-87`). There is no `session.create`, `session.send`, `session.wait` or event-subscription method.

### 2.3 Data model and on-disk state

**Config files (all TOML, all host-side):**

- `~/.config/jackin/config.toml` → `AppConfig` (`J/crates/jackin-config/src/app_config.rs:31-90`): per-agent auth, `github`, global `env`, `[roles.<name>]`, `[docker]` (mounts/profile/grants), `[runtime] default_backend`, `[telemetry]`, `[git]` (coauthor trailer, DCO), `dirty_exit_policy`, `role_repo_refresh_ttl_seconds`.
- `~/.config/jackin/workspaces/<name>.toml` → `WorkspaceConfig` (above). There is no project-local `jackin.toml`; grep finds none.
- `<role-repo>/jackin.role.toml` → `RoleManifest` with `deny_unknown_fields` (`J/crates/jackin-core/src/manifest.rs:20-70`): `version`, `dockerfile`, `published_image`, `[identity].name`, `agents`, `[claude] {model, marketplaces, plugins, providers}`, `[codex] {model, providers}`, `[amp]`, `[kimi] {model}`, `[opencode] {model, providers}`, `[grok] {model}`, `[hooks] {setup_once, source, preflight}`, `[env.<NAME>] {default, interactive, skippable, prompt, options, depends_on}`, `[docker] {min_profile, dind, allowed_hosts, capabilities_add}`.
- JSON Schema export: **absent** (no `schemars`, no `*.schema.json`).

**Host state (`JackinPaths`, `J/crates/jackin-core/src/paths.rs:36-96`):** `~/.jackin/{roles,data,cache}` modeled; `~/.jackin/sockets/<container>/` and `~/.jackin/run/` constructed ad hoc in `jackin-runtime` (`launch_runtime.rs:878`, `host_daemon.rs:367`). Overrides `JACKIN_HOME_DIR`, `JACKIN_CONFIG_DIR`. Per instance: `~/.jackin/data/<container>/{home,state,.config/gh}` (`J/crates/jackin-instance/src/lib.rs:525-560`), `state/isolation.json` (`J/crates/jackin-isolation/src/state.rs:26-38`). Usage broker state under `~/.jackin/data/usage-broker/` and `daemon/accounts.db`. Locks: `config.lock` (`J/crates/jackin-config/src/persist.rs:39-123`), `instances.json.lock`, keep-awake lock.

**Container layout (`J/crates/jackin-core/src/container_paths.rs:9-132`, enforced by `cargo xtask lint container-paths` and `J/container-path-allowlist.toml`):** everything jackin owns is under `/jackin/`: `/jackin/runtime/{jackin-capsule,entrypoint.sh,agent-status/…}`, `/jackin/run/{jackin.sock,host.sock,usage.sock,agent.toml,clipboard}`, `/jackin/state/{git-hooks,exit-action.json,usage/snapshots.db,agent-status/captures,container-init.done}`, `/jackin/default-home`, and per-agent credential handoff dirs `/jackin/{claude,codex,amp,opencode,grok,kimi-code}`.

---

## 3. Runtime

### 3.1 Launch path (implemented)

`jackin load <role>` → `handle_load` (`J/crates/jackin/src/app/load_cmd.rs:43-146`) → `runtime::load_role` (`J/crates/jackin-runtime/src/runtime/launch/launch_pipeline.rs:220`) → `run_launch_phases` (`launch_pipeline/launch_core/orchestrate.rs:75-1693`) which runs a `#[must_use]` typed phase chain: grant validation → image classification (`Reuse | RefreshInBackground | BuildFromPublished | BuildFromWorkspace`) → workspace materialization → instance preparation → `docker run -d` → post-run root steps → attach (`launch_phases.rs:8-140`). The DinD sidecar / role network future is started before image materialization so they overlap (`orchestrate.rs:1776-1830`).

Image builds shell out to `docker --context default buildx build` (`J/crates/jackin-runtime/src/runtime/image.rs:84-98`). Agent binaries are prefetched on the host from vendor release URLs and cached under `~/.jackin/cache/agent-binaries/<agent>/`, then `COPY`ed into the derived image, with a curl-installer fallback (`J/crates/jackin-image/src/agent_binary.rs:24-28,376-563`). Post-`docker run`, `docker exec --user root … jackin-capsule firewall-apply` and `… sudo-provision` run fail-closed (`launch_runtime.rs:1090-1140`). The host then attaches to the capsule multiplexer either via the bind-mounted attach socket or `docker exec … jackin-capsule attach-proxy` (`J/crates/jackin-runtime/src/runtime/host_attach.rs:4-9,114-140`).

### 3.2 Container lifecycle (implemented)

- No `--rm`; containers persist after exit for diagnosis and `hardline` restart; clean exits are reclaimed by the naming loop or `cleanup` (`launch_runtime.rs:420-439`; `launch_slot.rs:19-90`).
- Labels `jackin.managed=true`, `jackin.kind=role|dind|prewarm-dind`, `jackin.role`, `jackin.image`, `jackin.keep.awake` (`J/crates/jackin-runtime/src/runtime/naming.rs:24-46`).
- Runs as the host UID with `--group-add 0`, `HOME=/home/agent`, passwd/group lines bind-mounted read-only into `/var/lib/extrausers` (`launch_runtime.rs:551-568,874-905`).
- Hard rule, test-guarded: the host Docker socket is never mounted (`launch_runtime.rs:540-543`).
- GC verbs: `eject`, `exile`, `purge`, `prune {roles,cache,images,instances,system}` in `J/crates/jackin-runtime/src/runtime/cleanup.rs:62-848`; `prune_instances` reconciles vanished containers into `Crashed` restore candidates (`cleanup.rs:685-700`).
- Multiple live instances per workspace+role+agent are allowed and expected; no one-live-instance cap (ADR-008, `J/docs/content/reference/adrs/adr-008-launch-never-reconnects-live-instance.mdx:21`).

### 3.3 Docker/OCI

Both bollard (typed `DockerApi`: inspect/list/create/volumes/networks/images/exec, `J/crates/jackin-docker/src/docker_client.rs:379-780`) and the `docker` CLI (`run`, `exec`, `buildx build`) are used. Backends: `docker` (default) and `apple-container` (macOS 26 ARM, `container` CLI ≥ 0.11, `JACKIN_CAPSULE_FORCE_DAEMON=1`, no single-file binds so worktree isolation fails closed there) (`J/crates/jackin-runtime/src/apple_container_client.rs:1-56`, `launch/mounts.rs:202-243`). Podman, OrbStack, Colima, smolvm: research pages only.

DinD: sidecar container on a per-role network with TLS; `privileged` or `rootless` grant; role container gets `DOCKER_HOST`/`DOCKER_TLS_VERIFY`/`DOCKER_CERT_PATH` (`launch_dind.rs:157-262`; `launch_runtime.rs:584-596`). Disabled by default under the new `standard` profile.

### 3.4 Networking (implemented, partial parity)

`NetworkGrant { None, Allowlist, Open }`; `locked/hardened` default to allowlist, `standard/compat` to open (`J/crates/jackin-core/src/docker_security.rs:19-34,79-91`). `--network none` when tier is none and DinD is off; otherwise a per-role Docker network, `internal` under `locked` (`launch_runtime.rs:458-460`). Allowlist = union of operator/role `allowed_hosts`, per-agent API hosts, GitHub hosts, OTLP host, injected as `JACKIN_ALLOWED_HOSTS` (`docker_profile.rs:753-816`). Enforced by `jackin-capsule firewall-apply` via iptables + ipset `jackin-allowed`, DROP-first ordering, IPv6 dropped wholesale, empty list = no egress (`J/crates/jackin-capsule/src/firewall.rs:1-121,245-247`). Remaining gaps per roadmap: inner-DinD parity, rule editing, decision logs, non-Docker backends (`J/docs/content/roadmap/(agent-orchestration)/(containment-egress-recovery)/network-egress-policy.mdx:5-7`).

### 3.5 Secrets and 1Password

- `jackin-env` shells out to `op` with timeouts/retries (`J/crates/jackin-env/src/op_cli.rs:13-59`); `op://` references are a first-class `EnvValue` form.
- Launch-time transport: every non-`JACKIN_*` env value goes into a `0600` host-only temp env file passed as `--env-file` and deleted after `docker run` returns; values that cannot be represented fail closed (`J/crates/jackin-runtime/src/runtime/launch/capsule_setup.rs:138-303`). Container-visible `agent.toml` shows literals as the marker `"literal"` (`capsule_setup.rs:11,43-58`).
- On-demand: `jackin-exec` (argv0 alias of `jackin-capsule`) asks the host resolver on `/jackin/run/host.sock`; the host validates each `(name, kind, source)` against the launch allowlist, requires `op://` prefixes, uses `--` before `op read`, and on Linux checks `SO_PEERCRED` == container init PID (`J/crates/jackin-runtime/src/exec_host.rs:1-76,232-256,433`). Exposed to the agent as MCP tool `jackin_exec` (`J/crates/jackin-capsule/src/mcp_server.rs:79-132`). Roadmap status: partially implemented, one materialization gap, no live smoke pass (`J/docs/content/roadmap/(isolation-security)/jackin-exec.mdx:5-7`).
- Agent credential handoff files under `/jackin/<agent>/…` gated on `forward_auth` and existence (`launch/mounts.rs:47-128`). GitHub: `GH_TOKEN` + `GITHUB_TOKEN` exported, `gh auth git-credential` helper and ssh→https `insteadOf` rewrites configured in-container (`J/crates/jackin-capsule/src/runtime_setup.rs:158-193`). SSH-agent forwarding: absent.
- Host writes are prohibited: `~/.gitconfig`, repo `.git/config`, `~/.config/gh/hosts.yml` are read-only from jackin's perspective (`J/HOST_AND_CONTAINER.md:5-21`).

### 3.6 Host boundary

Container→host reaches only the `0700` socket dir `~/.jackin/sockets/<container>` mounted at `/jackin/run` (attach socket, credential resolver, usage relay, read-only `agent.toml`) (`container_paths.rs:49-56`; `launch_runtime.rs:869-886`). Host→container: `docker exec` and the attach socket. Three daemons exist: the in-container capsule (implemented), the host `jackin daemon` (partial: "empty daemon shell" with `Hello/Status/TelemetryHealth/AttentionSnapshot/Shutdown`, protocol v2, launchd/systemd unit writers, `J/crates/jackin-runtime/src/host_daemon.rs:1-89`), and the host `jackin-usage-broker` (implemented; single owner of provider quota refresh, per-container capability-scoped relay, `J/HOST_AND_CONTAINER.md:35-57`).

### 3.7 "Full speed" mode

There is no `--full-speed`/`--yolo` flag in jackin. Permission bypass is unconditional and hardcoded per agent in `J/docker/runtime/entrypoint.sh:77-136`:

| Agent | argv |
|---|---|
| claude | `claude --settings '{"skipDangerousModePermissionPrompt":true}' --dangerously-skip-permissions --verbose` (+ `--system-prompt` when `JACKIN_EXEC_BINDINGS` set) (`:79-82`) |
| codex | `codex --enable goals --dangerously-bypass-approvals-and-sandbox` (+ `--profile`, `-c model_catalog_json` when `JACKIN_CODEX_PROFILE`) (`:88-98`) |
| amp | `amp --dangerously-allow-all` — note: no `"$@"` append, so model args are dropped (`:103-107`) |
| kimi | `kimi --yolo` (`:109`) |
| opencode | `OPENCODE_CONFIG_CONTENT='{"permission":"allow"}' opencode` (`:114-119`) |
| grok | `grok --always-approve` (`:127`) |

The operator's knob is therefore the container security profile and grants, not the agent's permission model.

### 3.8 Agent runtime adapters

| Agent | Adapter | Binary path | Auth handoff | Auth modes | Model flag | Status reporter | Usage parser |
|---|---|---|---|---|---|---|---|
| Claude | `adapters/claude.rs:20-105` | `~/.local/bin/claude` | `/jackin/claude/{credentials,account}.json`, home `.claude/` | Sync/ApiKey/OAuthToken/Ignore | `--model` | hook `hooks/claude/report-hook.sh` | `usage/claude.rs` |
| Codex | `adapters/codex.rs` | `~/.local/bin/codex` | `/jackin/codex/auth.json`, home `.codex/` | Sync/ApiKey/Ignore | `-m` | hook | `usage/codex.rs` |
| Amp | `adapters/amp.rs` | `~/.amp/bin/amp` | `/jackin/amp/secrets.json` (copied, no write-back) | Sync/ApiKey/Ignore | none | none | `usage/amp.rs` |
| Kimi | `adapters/kimi.rs` | `~/.kimi-code/bin/kimi` | `/jackin/kimi-code/` dir | Sync/ApiKey/Ignore | `--model` | none | `usage/kimi.rs` |
| OpenCode | `adapters/opencode.rs` | `~/.opencode/bin/opencode` | `/jackin/opencode/auth.json` | Sync/ApiKey/Ignore | `-m` | plugin.js + hook | `usage/opencode.rs` |
| Grok | `adapters/grok.rs` | `~/.grok/bin/{grok,agent}` | `/jackin/grok/auth.json` | Sync/ApiKey (mirrored to `GROK_DEPLOYMENT_KEY`)/Ignore | `-m` | none | `usage/grok.rs` |

(Adapter paths under `J/crates/jackin-core/src/agent/adapters/`; mounts in `J/crates/jackin-runtime/src/runtime/launch/mounts.rs:47-128`; model flags at `J/crates/jackin-capsule/src/session.rs:1652-1655`.) Gemini and Cursor: absent. Status hooks exist for 3 of 6 agents; the arbitration authority grades only `opencode` and the flagged `codex-app-server` prototype as `Complete` (`session.rs:1602-1611`). No agent-level `--resume`/`--continue` is passed; persistence is by bind-mounting the durable home (`mounts.rs:23-46`). Alternative LLM providers (Z.AI, MiniMax, Kimi) are wired through per-agent `[<agent>.providers.<id>]` overrides and a sealed `ProviderAdapter` for usage (`J/crates/jackin-protocol/src/provider_adapter.rs:1-60`).

### 3.9 Telemetry

OTLP only, via a closed attribute/metric/span registry (`J/crates/jackin-telemetry/registry/attributes.yaml`; `J/crates/jackin-telemetry/src/lib.rs:1-44`). Emits launch stages, Docker HTTP operations, subprocess boundaries, error/degradation records, capsule daemon telemetry. Endpoint from `OTEL_EXPORTER_OTLP_*` (`J/crates/jackin-diagnostics/src/observability.rs:311-346`); container export is opt-in and gated on network classification (`launch_runtime.rs:715-742,822-849`); traceparent crosses the boundary in control frames. With no endpoint, telemetry is disabled with no local fallback file (`J/TESTING.md:225-231`). There is no run log store, no dashboard, and local telemetry artifacts were deliberately removed (`J/docs/content/roadmap/(operator-surface)/jackin-join-and-debug-bundle.mdx:7`).

---

## 4. Surfaces

### 4.1 CLI (`J/crates/jackin/src/cli.rs:114-166`, all implemented unless noted)

| Command | Purpose |
|---|---|
| `jackin` (bare) | Opens the console on a TTY ≥ 40x15, else root help (`cli/dispatch.rs:17-95`) |
| `load <role> [--mount… --rebuild --force --agent --role-branch --docker-profile --dry-run --format]` | Launch a role into a new isolated instance |
| `hardline [--inspect --new --agent --shell]` | Reattach to a running instance, or start another foreground agent/shell session in it |
| `eject [--all --purge]` | Stop a role instance and clean up its container |
| `exile` | Stop every running role at once |
| `purge [--all]` | Delete persisted state for a role class |
| `prewarm [--agent… --role --workspace --image --daemon --roles --sidecar …]` | Warm caches (images, agent binaries, sidecar) before launch |
| `prune roles|cache|images|instances|system` | Delete cached or stale data (`prune orphaned` / `prune isolation` are referenced in docs and error hints but do not exist — `cli/prune.rs:15-49` vs `preflight.rs:474,501`) |
| `console` | Operator TUI |
| `role validate|migrate|create|construct-version|published-image|published-image-repository|publish-labels` | Role-author tooling (also exposed as standalone `jackin-role` binary) |
| `workspace create|list|show|edit|prune|remove|env {set,unset,list}|claude-token {setup,rotate,revoke,doctor}` | Saved workspace management |
| `config mount|trust|auth|env|git` | Operator configuration |
| `daemon serve|install|uninstall|start|stop|restart|status` | Host daemon (unix only) |
| `doctor` | Pre-flight checks |
| `diagnostics validate` | Verify OTLP delivery |
| `status` / `ps [workspace] [instance] [--detail --state --filter --format]` | Local three-level overview: workspaces → instances → agents (the word "fleet" here means local instances only) |
| `usage [instance|cache|host] accounts|verify|snapshot` | Provider quota/usage views |
| `help [cmd]` | Renders clap_mangen roff through `man` |

Absent: shell completions (no `clap_complete`), installed man pages, any `init` wizard command.

In-container binary `jackin-capsule` has its own hand-rolled CLI: `new [agent]`, `agents`, `status [explain|capture]`, `snapshot`, `attach-proxy`, `usage …`, `exec`, `mcp-server`, `runtime-setup`, `sudo-provision`, `firewall-apply`, `prepare-commit-msg` (`J/crates/jackin-capsule/src/main.rs:36-120`).

### 4.2 TUI

Three layers, all implemented: `jackin-tui` (T1 presentation over termrock), `jackin-console` (operator console, 35 modules, screens workspaces/editor/settings/usage), `jackin-capsule/src/tui` (in-container multiplexer chrome, tab strip, panes, dialogs, command palette). termrock is a real git-pinned dependency: `termrock = { version = "=0.11.0", git = "https://github.com/tailrocks/termrock.git", rev = "1ac0d079…" }` plus `termrock-raster` (`J/Cargo.toml:118-124`; `J/Cargo.lock:6853-6877`), consumed by `jackin`, `jackin-capsule`, `jackin-console`, `jackin-launch`, `jackin-oppicker`, `jackin-tui`. `ratatui = "0.30"` (`J/Cargo.toml:106-110`). The console shows workspaces, expandable instance rows with role/agent/status, a live tab/pane tree from the capsule daemon with agent states `working|blocked|done|idle|unknown`, keys `Enter` reattach / `N` new session / `X` shell / `T` stop / `P` eject+purge, a workspace editor, settings, and a host-wide Usage route (`J/docs/content/(public)/commands/console.mdx:29-45`; `J/docs/content/reference/tui/navigation.mdx:7-17`). The launch cockpit (`jackin-launch`) has shipped (`J/docs/content/roadmap/(agent-orchestration)/(live-operations)/launch-progress-tui.mdx:7`).

### 4.3 macOS app and phone

`J/native/` is a Swift 6 / SwiftUI, macOS 26+, arm64-only menu-bar app `JackinDesktop.app` (`com.jackin-project.desktop`) that displays provider usage/quota only, over `jackin-usage-ffi` (boltffi static lib) (`J/native/README.md:1-8`, `J/native/AGENTS.md:9-45`). Built by `cargo xtask desktop {bindings,xcframework,build,verify,run,test,sign-notarize,…}` (`J/crates/jackin-xtask/src/desktop.rs:53-76`) and by `release.yml` on `macos-26` with signing/notarization (`J/.github/workflows/release.yml:424-427,578-643`). It is not an agent control surface: no instance list, no attach, no approvals; scope is "limits-only". Roadmap: `native-macos-usage-menu-bar` partially implemented; a "Desktop Agent Hub" bridge is Phase 4 of the capsule plan, open (`jackin-capsule.mdx:7`). Phone/iOS: absent (no references in `native/`).

### 4.4 Control plane / server / remote hosts

There is no network server. Both daemons speak over local Unix sockets with JSON/binary framing; `tonic`/`hyper-util` exist only for OTLP export (`J/crates/jackin-diagnostics/Cargo.toml:28,40-76`), no axum, no GraphQL, no tonic service definitions for jackin's own protocols. Remote hosts, SSH transport, host inventory, multi-machine scheduling: absent. `jackin-remote` (`--remote <name>`, SSH+rsync, handler relay) is a Phase 5 design proposal with nothing built (`J/docs/content/roadmap/(agent-orchestration)/(distributed-work)/jackin-remote.mdx:5-7`; research at `J/docs/content/research/agents/orchestration/remote-execution/index.mdx:14`).

---

## 5. Roles

### 5.1 Contract

A role = `Dockerfile` + `jackin.role.toml` in a repo named `jackin-<role>` (`J/docs/content/(public)/(role-authoring)/guides/role-repos.mdx:19-56`). The Dockerfile must `FROM projectjackin/construct:<tag>` (`J/crates/jackin-manifest/src/repo_contract.rs:28-41`, `validate_agent_dockerfile` at `:98`). Manifest loading = toml_edit parse → version check → deserialize → feature-version + agent-consistency validation (`J/crates/jackin-manifest/src/manifest.rs:56-72`); migrations are additive no-ops so far (`J/crates/jackin-manifest/src/migrations.rs:19-53`). Claude marketplaces are cross-checked against the marketplace's `marketplace.json` on GitHub (`J/crates/jackin/src/role_claude_plugins.rs:83-135`). Hooks run in a fixed order `setup-once.sh` → `source.sh` → `preflight.sh` (`J/crates/jackin-core/src/manifest.rs:283-315`). Roles are not sandboxed from each other in any way beyond the container; the manifest can only raise the Docker profile floor, not lower it.

### 5.2 Build, validate, publish (`jackin-role-action`)

`P/jackin-role-action/action.yml:10-75` is a composite action: download the `jackin-role` validator binary (`scripts/download-jackin-role.sh`, which prefers `preview-GitHub-jackin-<target>` CI artifacts), hadolint, `jackin-role validate`, `linux/amd64` buildx build with `push: false`. The reusable `publish.yml:8-291` verifies the validator's provenance with `gh attestation verify --signer-workflow jackin-project/jackin/.github/workflows/preview.yml`, builds amd64 + arm64 by digest on `velnor-target-mvp` runners (or GitHub-hosted), merges the manifest, tags `latest` + short SHA, applies `jackin.construct.version` / `jackin.role.git.sha` labels from `jackin-role publish-labels`, and `cosign sign`s. Images land on Docker Hub as `docker.io/projectjackin/jackin-<role>`. No action outputs are declared.

### 5.3 The three roles

| Role | Manifest version | Base | Agents | Notable content |
|---|---|---|---|---|
| `the-architect` (`P/jackin-the-architect/jackin.role.toml:1-82`) | v1alpha5 | `construct:0.36-trixie` | all six | 12 Claude plugins from 3 marketplaces (`claude-plugins-official`, `jackin-marketplace`, `tailrocks-skills`, `caveman`), provider overrides (zai/minimax/kimi), full Rust toolchain mirrored from upstream via `jackin-toolchain/` (33 mise tools), caveman + headroom + rtk + ctx7 token stack, `hooks/preflight.sh` (184 lines wiring MCPs per agent), `AGENTS.md.d/` fragments assembled into `/home/agent/AGENTS.md` and symlinked into each agent's config dir (`Dockerfile:117-135`) |
| `agent-smith` (`P/jackin-agent-smith/jackin.role.toml:1-23`) | v1alpha4 | `construct:0.35-trixie` | claude only | 2 official plugins, Node 24 only, no hooks; the minimal reference role |
| `sentinel` (`P/jackin-sentinel/jackin.role.toml:1-89`) | v1alpha4 | `construct:0.35-trixie` | all six | Empty Dockerfile body; exists to exercise every manifest form (all env-declaration variants, all three hooks, hook-ordering oracle in `hooks/setup-once.sh:11-58`). Not built-in; loaded as `jackin-project/sentinel` |

### 5.4 Plugin/skill delivery into roles

Two paths, both implemented: (1) Claude Code — manifest `plugins`/`marketplaces` are baked into the derived image as `claude plugin marketplace add …` + `claude plugin install …` `RUN` lines (`J/crates/jackin-image/src/derived_image.rs:297-343`); (2) other agents — the role Dockerfile installs skills itself, e.g. `skills add jackin-project/jackin-dev -a codex|amp --global` (`P/jackin-the-architect/Dockerfile:98-102`). `P/jackin-dev/` ships 11 manual-only skills (`jackin-propose`, `jackin-research`, `jackin-create-pr`, `jackin-release`, …) with per-agent plugin manifests (`.claude-plugin`, `.codex-plugin`, `.kimi-plugin`, Antigravity `plugin.json`), all at version 0.4.0. `P/jackin-marketplace/.claude-plugin/marketplace.json` publishes only `jackin-dev` and pins version `0.3.0` — a skew against the plugin's 0.4.0. A generic cross-runtime "workspace skills mount" is roadmap-open, blocked on a native APM decision (`J/docs/content/roadmap/(agent-orchestration)/(distributed-work)/workspace-skills-mount.mdx:5-7`).

---

## 6. Multi-agent today

What exists is "many isolated single agents", not cooperation.

**Implemented**

- N concurrent instances per workspace with no cap, each its own container, DinD sidecar, home and credentials (ADR-008 `adr-008-…mdx:21`; index under flock `J/crates/jackin-instance/src/manifest.rs:26-27,421-455`). Per-container git isolation via `worktree`/`clone` mounts (`J/crates/jackin-isolation/src/materialize.rs:556-785`; `J/docs/content/(public)/guides/workspaces.mdx:112`).
- N sessions inside one instance: `jackin hardline --new --agent <x>` spawns another foreground agent in the same container sharing files, branch, tools, credentials, DinD (`J/crates/jackin/src/cli/role.rs:114-129`; `J/crates/jackin-capsule/src/daemon/session_lifecycle.rs:362-375`; cap `MAX_TABS = 32`, `daemon.rs:511`). Secondary sessions are foreground only; named reconnectable secondary sessions are roadmap (`parallel-agents.mdx:100-103`).
- Agent identity: every tab gets a never-reused codename injected as `JACKIN_AGENT_CODENAME` (`J/crates/jackin-capsule/src/session.rs:1642,1672`; retirement in `wordlist.rs:166-189`, `daemon.rs:186-194`). Read-only registry `jackin-capsule agents [--format json]` (`J/crates/jackin-capsule/src/client.rs:325-392`; protocol `ClientMsg::Agents` → `ServerMsg::AgentRegistry`, `control.rs:36,157-159,818-836`). Host view `jackin status <ws> <instance>` lists per-agent rows.
- Agent state model `Working | Blocked | Done | Idle | Unknown` derived per session by the capsule's evidence-arbitration authority (`control.rs:887-897`; `agent-runtime-status.mdx:7`), surfaced in console and status.
- Attention notifications: host daemon accepts one-way `AttentionSnapshot`s and can dispatch macOS/Linux notifications for `blocked`/unseen `done` transitions when `JACKIN_ATTENTION=1` (`host_daemon.rs:424`; `agent-attention-prompts.mdx:7`).
- Per-request credential approval: `jackin_exec` MCP tool → host resolver with allowlist + peer credential check (§3.5).

**Documented only (no code)**

- Coordination between sessions is a documented *convention*: a `COORDINATION.md` in the workdir, claimed under `flock`, with a suggested bootstrap prompt. The guide states "jackin❯ does not prescribe a coordination format or communication pattern" (`J/docs/content/(public)/guides/parallel-agent-coordination.mdx:59-101`). No writer, parser or schema for it exists in `crates/`.
- Planner/worker delegation ("Conductor view"): a research page designs one orchestrator tab plus N worker tabs inside one capsule, an in-container `jackin-orchestrate` MCP server with `jackin.delegate/await/collect`, new control-protocol methods `session.create`, `session.send`, `events`, `session.read`, and a Conductor TUI layout. Research state "Incomplete"; it acknowledges "those agents are isolated islands. There is no supported way for one agent to hand work to another" (`J/docs/content/research/agents/orchestration/multi-agent-collaboration/index.mdx:5,11,53-58`). `ClientMsg` today has none of `session.create/send/read/wait` or `events` (`control.rs:28-87`).
- Durable workflow runs: `WorkflowRun`, `WorkflowDefinition` (typed steps `agent|context|review|verify|github|gate|artifact|parallel`), `RunSession`, `RunReporter`, `MemoryBrief`, a run state machine `planned → provisioning → implementing → awaiting_operator → verifying → reviewing → fixing → ready_for_operator | failed | cancelled`, with "agent prose is evidence, never the transition authority" (`J/docs/content/research/agents/orchestration/workflow-systems/agent-workflow-orchestration/02-design-constraints.mdx:18-95`). Headline: jackin should own the substrate; no external workbench qualifies as a dependency; a workflow language, background queue, dashboard and autonomous review loops "should not define the initial contract" (`…/index.mdx:14-21`).
- Autonomous task queue, task-source abstraction, idle-runtime cleanup: "no code exists yet" (`autonomous-task-queue.mdx:5-7`, `task-source-abstraction.mdx:5-7`, `idle-runtime-cleanup.mdx:5-7`).
- Persistent storage / workspace memory: per-instance SQLite, daemon-global quota cache, scoped memory briefs with provenance (`J/docs/content/research/agents/orchestration/memory/index.mdx`), research only.
- Terminal observation/automation (`session.read/wait/send`, structured frames, waits, input injection) — decided to implement natively in the capsule, not shipped (`J/docs/content/research/agents/orchestration/terminal-observation/terminal-observation-automation.mdx`).
- Agent tag protocol (`<jackin:*>` markers), custom operator tools `[[tool]]`, GitHub link tracking, console resource panel, session snapshot/rollback: all "Open", design only.
- Host bridge (secrets + approved host actions with per-request approval and audit) and live auth sync: "Deferred", blocked on the daemon foundation (`host-bridge.mdx:5-7`, `live-auth-sync.mdx:5-7`).
- `jackin-remote`: Open, nothing built (§4.4).

**Absent entirely**

Mailbox/message bus, broadcast, task graph, scheduler, container-to-container comms or shared network namespace, remote/SSH execution, durable human decision inbox, run log aggregation, dashboards. Keyword tallies confirm this: `mailbox` 0 code files, `task graph` 0, `broadcast` 1 unrelated; `coordinator` hits are the usage-refresh coordinator, `supervisor` hits are the PTY session supervisor, `orchestrat` hits are a token orchestrator (all from grep over `J/crates/**/*.rs`).

---

## 7. Integrations: code vs vision

| Product | Vision claim (`V`) | Reality in jackin |
|---|---|---|
| termrock | "powers the TUIs of jackin" (`V:96`) | **Implemented.** Git-rev-pinned dependency consumed by six crates (`J/Cargo.toml:118-124`); documented in `J/docs/content/reference/tui/architecture.mdx` and ADR-003. |
| parallax | "every jackin agent can connect to your Parallax out of the box" (`V:156-159`); "agents read logs, traces, metrics" (`V:90`) | **Partial / naming only.** No Cargo dependency. `parallax` appears as a reserved telemetry namespace that must not leak (`J/crates/jackin-telemetry/src/schema/tests.rs:18`), one enum variant `ConnectionPeerType::Parallax` (`J/crates/jackin-telemetry/src/schema/enums.rs:31`), a run-telemetry guide (`J/docs/content/(public)/guides/run-telemetry.mdx`) and a 5-part research dossier. jackin can *export* OTLP to a Parallax endpoint like any collector; there is no evidence-bundle consumer, no agent-side Parallax tooling. |
| velnor | "runs CI for jackin" (`V:88`) | **Implemented as infrastructure, not as code.** Roughly 20 workflows route lanes to `["self-hosted","velnor-target-mvp"]`; xtask carries Velnor-host workarounds (`J/crates/jackin-xtask/src/ci.rs:350`, `release_archive.rs:111`). `P/velnor-actions/` is the Rust generator of the fleet-wide CI workflows (`fleet/repositories.toml` lists 24 repos incl. all jackin repos and tailrocks siblings). |
| holla | "entry point to everything → jackin" (`V:98`) | **Absent.** Only a fake repo name in capsule tests (`J/crates/jackin-capsule/src/exit_assess/tests.rs:38-67`) and the watchlist (`J/docs/content/research/watchlist.mdx:64`). |
| tailrocks-skills | not named in `V` | **Partial.** Referenced as a Claude marketplace in the-architect (`P/jackin-the-architect/jackin.role.toml:25,41-42`); jackin has only generic marketplace validation with a test fixture. |
| caveman | not named in `V` | Role-side only (the-architect Dockerfile `:87-95`, preflight hook, `caveman-config.json`); jackin core has no caveman-specific path. |
| GitHub | — | **Implemented** by shelling out to `gh` (~20 modules: preflight, status, auth provisioning, release verify) and raw.githubusercontent fetches for marketplace validation (`J/crates/jackin/src/role_claude_plugins.rs:64-76`). Durable GitHub link tracking / check-run reporting: Open (`github-link-tracking.mdx:5-7`). `jackin-pr-trailers` is a small standalone CLI used by CI/skills. |
| ruxel, tablerock, schemalane | provisioning / DB tooling | No references in jackin code. |

Sibling checkouts worth knowing: `P/jackin-velnor-estate/` is an older detached-HEAD working copy of `jackin` itself (same remote, byte-identical CHANGELOG, 515 tree differences all consistent with lag) containing one unique file, `APPLE_CONTAINER_RESEARCH.md` (2026-06-10 dossier on PR #527); `P/jackin-github-terraform/` manages org branch protection; `P/homebrew-tap/` holds the three formulae.

---

## 8. Testing, CI, release, docs

**Testing.** Contract in `J/TESTING.md` (25.8K). Unit via `cargo nextest` per crate with a `verification_map` from `cargo xtask health`; Docker E2E behind `--features e2e --profile docker-e2e` plus a scheduled full-DinD lane (`J/TESTING.md:160-192,363`); E2E suites in `J/crates/jackin/tests/{dind_e2e,per_mount_isolation_e2e,usage_broker_e2e,manager_flow,profile_matrix,migration_fixtures,frame_time}.rs`. Snapshots: `insta =1.48.0`, 18 `.snap` files confined to capsule dialogs and console views (`J/TESTING.md:177-183`). PTY render-conformance harness replays byte streams and asserts emitted frames (`J/crates/jackin-capsule/src/daemon/tests.rs`, 301 KB; fixtures promoted via `cargo xtask pty-fixture`). Criterion benches in `jackin-term`, `jackin-capsule`, `jackin-runtime`, `jackin-usage`, `jackin-config`, `jackin-manifest`, `jackin-telemetry`. Fuzz targets for manifest validate/migrate. Governance ledgers: `J/ratchet.toml` (shrink-only budgets for file size, suppressions, public surface, suite time, build time, function complexity), `J/code-health-baseline.toml` (369 `allow`, 215 `expect`, 1 bare allow), `J/flaky-tests.toml` (zero entries; unquarantined flakes fail CI), `J/DEFECT_LEDGER.md` (6 rows; the two newest from 2026-08-21 have no adopted gate yet). dylint `render_thread_purity` runs advisory (`hygiene.yml:960`). Lint posture: `unsafe_code = forbid`, `unwrap/expect/panic/todo/print_*` denied workspace-wide (`J/Cargo.toml` lints block); only `jackin-usage-ffi` allows unsafe.

**CI.** `J/.github/workflows/`: `ci.yml` (umbrella, generated by velnor-actions-generator, dispatches `jackin-project`/`tailrocks` lanes), `rust-nextest.yml` (reusable per-crate matrix, 29 packages), `hygiene.yml` (nightly: bench, dhat, cold-start, coverage, miri, mutants, beta-clippy, hakari, dylint, dind-chaos, health-trend), `construct.yml` (+ `-public-unmerged`), `docs.yml` (+ `-public-unmerged`), `release.yml`, `preview.yml`, `jackin-dev.yml` (+ `-public-unmerged`), `desktop-cadence.yml`, `renovate*.yml`, `reuse-compliance*.yml`, `cache-cleanup.yml`. Nearly every workflow takes a `lanes` input `velnor|github|both`.

**Release.** `cargo-release` (`J/release.toml`), tag-triggered `release.yml` producing per-target CLI archives, a separate capsule binary, the macOS app, cosign/attestation/SBOM sidecars, verified by `cargo xtask release-verify` (`J/CHANGELOG.md:12-13`). Homebrew preview on every `main` push (`preview.yml`). Construct image published per platform by digest then manifest (`construct.yml:287-301`; mise tasks `construct-*`, `J/mise.toml:66-80`).

**Docs site.** Fumadocs 16 on TanStack Start + Vite 8, Bun, Tailwind 4, Orama search, React 19, TS 7 (`J/docs/package.json`); deployed to GitHub Pages at `https://jackin.tailrocks.com` by `docs.yml:634-654`; lychee link checks; `cargo xtask roadmap audit` / `research check` / `docs repo-links` enforce roadmap/research page structure and status vocabulary (`J/TODO.md:78-97`). Content tree: `(public)/{getting-started,guides,commands,(role-authoring)}`, `reference/{adrs,capsule,crates,runtime,tui,errors,developer-reference}`, `roadmap/` (68 items in 9 groups), `research/` (context, platform, agents, product, engineering).

---

## 9. Roadmap, plans, TODOs, issues

**In-repo `J/roadmap/` and `J/plans/`.** One program: `unified-agent-usage` — one usage experience across desktop, console, CLI and capsule, fed by a Rust canonical projection. Plans 001–007 DONE, 008 (parity proof + signed distribution) REJECTED pending external release authorization; tracked in PR #898 (`J/plans/unified-agent-usage/README.md:11-23`; `J/roadmap/unified-agent-usage/README.md:3`). `J/research/agent-usage-platform/` holds nine supporting dossiers. `J/prompts/research/` holds three research briefs (context techniques, context tools, session capture).

**Docs roadmap (68 items).** Grouped as `(agent-orchestration)` [containment-boundary-contract, containment-egress-recovery, distributed-work, fleet-automation, foundation, live-operations], `(agent-runtimes-authentication)`, `(configuration-ergonomics)`, `(documentation-tooling)`, `(infrastructure)`, `(isolation-security)`, `(operator-surface)`, `(product-direction)`, `(reactive-daemon-program)`. Status counts from `in-progress.mdx`, `planned.mdx`, `ideas.mdx`: ~31 partially implemented, ~26 open, 4 deferred, 1 exploring. The items most relevant here and their verbatim state:

| Item | Status | Current state |
|---|---|---|
| agent-runtime-status | Partial | evidence arbitration live; fixtures/packs and signed remote pack channel outstanding |
| console-agent-session-control | Partial | instance tree, `hardline --new/--shell`, console keys shipped; live session reconciliation open |
| session-keep-and-resume | Partial | exit dialog, restore picker, recipe pins shipped |
| jackin-capsule | Partial | Phases 1–3 shipped; Phase 4 host-daemon / Desktop Agent Hub bridge open |
| jackin-daemon | Partial | lifecycle + attention adapter shipped; reactive features pending |
| agent-attention-prompts | Partial | one-way snapshots + OS notifications; no per-container subscription, click-to-focus, console tab |
| network-egress-policy, declarative-resource-limits, operator-handler-system, credential-source-pattern, jackin-exec, apple-container-backend | Partial | see §3 |
| autonomous-task-queue, task-source-abstraction, idle-runtime-cleanup | Open | no code |
| jackin-remote | Open | no code |
| agent-tag-protocol, custom-operator-tools, github-link-tracking, console-resource-panel, session-snapshot-rollback, session-contract-explain-mode, stack-integration-contracts, workspace-skills-mount, ephemeral-mount-modes, source-branch-policy | Open | design only |
| host-bridge, live-auth-sync | Deferred | blocked on daemon security posture |

**Research pages** relevant to this effort, all "Incomplete" or "Needs refresh": program-research (orchestration program synthesizing multicode, Hazmat, Docker Sandboxes, Herdr, cellshot, Orca), multi-agent-collaboration, workflow-systems (agent-workflow-orchestration, task-source-abstraction-design), fleet-operations, remote-execution, memory, recovery, terminal-observation, resource-limits, conversation-capture.

**Code TODOs.** 3 real markers: `TODO(keyboard-help-mouse)`, `TODO(WP0-tier2)` (profile matrix), `TODO(apple-container)` (`container ps` schema pin). `J/TODO.md` tracks four follow-ups, including `launch-worktree-leak-on-sidecar-fail` (a host `git worktree` can be left staged when the sidecar fails; `LoadCleanup` does not unstage it) and `shellfirm-aarch64-linux-binary`.

**GitHub issue/PR refs** in docs: 75 distinct numbers; load-bearing ones are #898 (usage program), #576 (motivated ADR-008), #527 (Apple Container backend), #632 (shellfirm prebuild).

---

## 10. Gap analysis for multi-agent big-task orchestration

The goal is: given a big task, plan it, decompose it, execute parts across several agents (possibly different runtimes/models) in several containers and possibly several hosts, verify, integrate, and let a human decide when needed. Below, each missing capability is classified as "jackin" (belongs in jackin because it is a property of the isolation/session substrate) or "new project" (belongs in the orchestrator), with reasoning. The guiding split is the one jackin's own research already draws: jackin owns "visible PTYs, sessions, attach/hijack, input/output, lifecycle"; a workflow runner owns "allowed transitions, policies, gates, evidence requirements, and reporters" (`02-design-constraints.mdx:51-61`).

| # | Missing capability | State in jackin | Belongs to | Reasoning |
|---|---|---|---|---|
| 1 | **Typed session control API**: create a session with a given agent/provider/model, inject a prompt or brief into its PTY, read its screen/output, wait on a condition, kill, subscribe to state events | Absent in `ClientMsg` (`control.rs:28-87`); designed in terminal-observation research and named as the "genuinely new" pieces by the collaboration research (`session.create`, `session.send`, `events`) | **jackin** | Only the capsule owns PTYs, DamageGrid screen state, codenames and the status authority. Nesting another PTY daemon was explicitly rejected (`terminal-observation-automation.mdx`, "Decision"). The new project must consume this, not build it. This is the single largest dependency. |
| 2 | **Non-interactive / headless launch**: start an instance and hand it a task without a foreground terminal attach; detach/reattach semantics for long-running work | Partial: containers persist and `hardline` reattaches; `hardline --new` sessions are foreground only; launch pipeline assumes an operator terminal (launch TUI, exit dialog) | **jackin** | Launch/attach is jackin's pipeline. The new project needs `load --detach`-style and `hardline --new --detach` semantics with a programmatic result, i.e. the "reconnectable named secondary sessions" item already on jackin's roadmap. |
| 3 | **Programmatic host API** (JSON over the host daemon socket or a library crate) for: list instances, launch, session control, status stream, usage | Partial: `jackin status --format json`, `--dry-run --format`, `jackin-capsule agents --format json`; host daemon has only Hello/Status/TelemetryHealth/AttentionSnapshot/Shutdown (`host_daemon.rs:39-60`); library crates are `publish = false` and tiered internally | **jackin** | Whether the new project links jackin crates or talks to a socket, jackin must expose a stable machine interface. Today the only stable-ish surface is CLI text/JSON. Recommend the new project standardize on the host daemon socket (or a `jackin-client` crate) and jackin grow it. |
| 4 | **Durable run ledger**: `WorkflowRun`, events, transitions with actor/reason/evidence, artifacts, links | Absent; designed (`02-design-constraints.mdx:20-49`); memory research proposes per-instance SQLite and a daemon-global store | **new project** | This is the orchestrator's core object model. jackin's research says jackin "should own the execution substrate and durable run model" (`index.mdx:16`), but that conflates two things; the substrate (sessions, instances) is jackin's, the run graph is not tied to Docker or PTYs and should not make jackin heavier. Keep the ledger in the new project; have jackin emit the session/instance events it needs. |
| 5 | **Task graph / plan model**: decomposition into typed steps (`agent`, `verify`, `review`, `gate`, `parallel`, `github`), dependencies, retries, budgets | Absent; step vocabulary sketched (`02-design-constraints.mdx:81-85`) | **new project** | Pure orchestration logic. |
| 6 | **Scheduler / dispatcher**: concurrency limits, slot claiming, dispatch of a task to a fresh isolated instance, idle cleanup, budget caps, re-delegation limits | Absent; autonomous-task-queue "no code" (`autonomous-task-queue.mdx:7`); queue config sketched under `[workspaces.*.queue]` (`fleet-operations/index.mdx:38-50`) | **new project** (dispatch policy) + **jackin** (idle-cleanup signal, per-instance resource limits already partial) | The dispatcher decides *what* runs; jackin decides *how* it is isolated. jackin's roadmap places the queue inside jackin, but a queue inside a CLI with no daemon scheduler is a poor fit; the new project should own it and treat jackin as the executor. |
| 7 | **Inter-agent communication**: orchestrator→worker briefs, worker→orchestrator results, peer messages, addressed by codename | Absent; only the `COORDINATION.md` + flock convention (docs) and the `jackin.delegate/await/collect` MCP design | **new project** (message semantics, MCP tool surface exposed to agents) built on **jackin** (#1 for delivery into a PTY, plus the existing MCP auto-registration pattern in `runtime_setup.rs`) | Message routing across *containers and hosts* cannot live in the capsule (which is per-container) and the host daemon is a shell. The new project's control plane should own the bus; jackin provides the last hop into each session. |
| 8 | **Shared artifacts across instances/hosts**: plan documents, patches, review findings, test outputs, handoff bundles | Absent; per-instance state only (`~/.jackin/data/<container>/`); git worktree/clone is the only cross-instance sharing mechanism | **new project** | Artifact store is orchestration state. Git branches remain the natural code-handoff channel (already supported by `worktree`/`clone` mounts); the new project should define a branch-per-task convention and an artifact store beside the ledger. |
| 9 | **Remote host control**: launch/attach/status on other machines, host inventory, placement | Absent (`jackin-remote.mdx:7`); SSH+rsync design only | Split: **new project** owns inventory, placement, and fleet-level scheduling; **jackin** owns running on a remote host via a remote daemon and preserving the attach/console UX | jackin's research favors `jackin-remote` over SSH for a laptop-to-one-server case. A multi-host orchestrator needs a per-host agent (the jackin host daemon, grown) plus a coordinator. Do not build a second per-host runtime; grow `jackin daemon` into the per-host executor and put the coordinator in the new project. |
| 10 | **Observability of runs**: run timeline, per-session logs, screen captures, token/cost per task, resource usage, aggregated across hosts | Partial: OTLP export of stages/spans; agent state model; usage broker per host; no run log store, no dashboard (explicit scope decision, `research/context/engine/02-architecture.mdx:86`), console resource panel open | **new project** (run-level aggregation, dashboard/TUI) consuming **jackin** signals (status events, OTLP, usage snapshots, PTY captures via #1) | jackin refuses to host a dashboard and a cross-container daemon by design; the natural sink for its OTLP is parallax. The new project should render run views and can source telemetry from parallax. |
| 11 | **Human decision inbox**: durable queue of `awaiting_operator` items (blocked agent, secret request, gate approval, review sign-off) with resolution, audit, and multi-surface delivery (TUI, macOS, phone) | Partial: synchronous approvals (credential picker, exit dialog, purge modal); one-way attention notifications; host bridge deferred | **new project** (inbox, gate semantics, durability, phone/desktop delivery) + **jackin** (host bridge approvals for secrets/host actions must stay in jackin because they touch host trust) | Gate decisions are run-ledger transitions. Secret/host-action approvals are jackin's trust boundary; the new project should request them through jackin rather than reimplement. |
| 12 | **Verification as first-class evidence**: run deterministic commands (`cargo test`, lints, CI status) inside an instance and capture exit code/output as transition evidence | Absent as an API; `jackin-capsule exec`/`ExecCommand` exist for credential-bearing commands (`control.rs:73`) but are not a general "run this and return the result" surface | **jackin** (exec-with-result in a session/instance) + **new project** (what counts as evidence) | Executing inside the isolation boundary is jackin's job; deciding that evidence advances a run is the orchestrator's. |
| 13 | **Workspace memory / cross-agent briefs** | Absent; designed in memory research | **new project** | Orchestration context, not isolation. Keep out of jackin per its own headline "agents never open host storage directly". |
| 14 | **GitHub reporting** (tracking issue, draft PR, check runs, compact phase summaries) | Absent beyond `gh` auth forwarding; github-link-tracking open | **new project** | Reporter is a run-ledger projection. |
| 15 | **Agent-agnostic prompt/brief injection and result extraction** independent of agent CLI quirks (Amp drops args, model flags differ, Claude adds `--system-prompt`) | Partial: entrypoint hardcodes per-agent argv; no structured result channel; the workflow research names ACP as the interop candidate | **jackin** (adapter surface: "start this agent with this brief and these flags", plus result markers) | Adapters are sealed in `jackin-core`; only jackin can extend them. The `agent-tag-protocol` roadmap item (`<jackin:*>` markers) is the intended result channel. |
| 16 | **Resource/placement limits per task** | Partial: `[docker.grants]` memory/cpus/pids/nofile, OOM detection; no per-launch overrides, no non-Docker translation | **jackin** (per-launch override flags are already on its roadmap) | Enforcement is container-level. |
| 17 | **Session snapshot/rollback** of a worker's filesystem | Absent (`session-snapshot-rollback.mdx:5-7`) | **jackin** | Isolation substrate feature; the orchestrator's re-delegate path would use it. |

Net: the new project should be the *coordinator* — run ledger, plan/task graph, scheduler, message bus, artifact store, inbox, GitHub reporter, multi-host placement, run observability UI — and jackin should be the *per-host executor* it drives, which requires jackin to add (1) a typed session control API, (2) detached launches and named secondary sessions, (3) a programmatic host interface via the daemon, (12) exec-with-result, (15) brief injection/result markers, and eventually (9) remote-daemon mode. Items 4–8, 10, 11, 13, 14 should not be pushed into jackin even though several are on its roadmap, because they are independent of the isolation boundary and jackin's own research warns against a background queue, dashboard and cross-container daemon inside jackin.

---

## 11. Risks and constraints for a project building on jackin

1. **Pre-release, deliberately breaking.** No compatibility shims, no deprecations, one schema bump per PR; the CLI, protocol enums and crate boundaries can change under a consumer at any time (`J/PRERELEASE.md:5-9`). The default Docker profile just changed from `compat` to `standard`, disabling DinD and sudo unless granted (`J/CHANGELOG.md:15-17`). Pin a jackin commit and treat upgrades as work.
2. **No library API.** All crates are `publish = false`, tiered by architecture invariants (T0–T6) enforced by `cargo xtask lint arch`, with heavy lint policy (`unwrap`/`expect`/`panic` denied, `unsafe` forbidden). Depending on internal crates by git path means inheriting that policy and churn; depending on the CLI means parsing text/JSON with only partial `--format json` coverage. The host daemon socket protocol is v2 and explicitly a "shell".
3. **Protocol is host↔one-container.** `jackin-protocol` control and attach channels are per-container Unix sockets under `~/.jackin/sockets/<container>`; there is no addressing across containers or hosts. Multi-host requires a new transport layer either in jackin's daemon or in the new project.
4. **Sealed agent set.** `Agent` enum and `AgentRuntime` trait are sealed in `jackin-core`; adding Gemini/Cursor/ACP-based runtimes means changing jackin. Per-agent launch argv lives in a shell script (`entrypoint.sh`), with known quirks (Amp ignores extra args; status hooks for only 3 of 6 agents; codex/opencode only fully graded for status authority).
5. **Foreground-centric session model.** Launch and `hardline --new` assume an operator terminal; exit assessment shows a dialog; secondary sessions are not reconnectable by name. Headless orchestration needs jackin changes first (§10 #2).
6. **Host-write prohibitions.** jackin will not write host git config, gh hosts, or repo config, and only opts into `git_pull_on_entry` and `worktree add` (`J/HOST_AND_CONTAINER.md:7-17`). An orchestrator that wants to create branches, push, or open PRs must do so *inside* an instance (via gh forwarding) or on its own host account, not via jackin.
7. **Apple Container backend limits.** No worktree isolation (single-file binds rejected), DinD gated, CLI-shelled with a pending `container ps` schema pin. Multi-instance-per-workspace on macOS therefore needs Docker or `clone` mounts.
8. **Known leak.** `launch-worktree-leak-on-sidecar-fail` in `J/TODO.md`: a failed sidecar can leave a host worktree staged until eject/purge. Bulk parallel launches will hit this more often.
9. **Termrock coupling by git rev.** TUI crates pin termrock `=0.11.0` at a specific rev; a new project sharing the console look must pin the same rev or accept divergence.
10. **Governance overhead.** Ratchets on file size, suppressions, public surface, suite time and build time; roadmap/research page structure enforced by xtask; DCO and trailer rules. Contributions to jackin from the new project must budget for that.
11. **Docs/code drift to watch.** `prune orphaned`/`prune isolation` referenced but absent; `container_binary_paths` doc claims run-time bind mounts that are not implemented; `PRERELEASE.md` cites pre-workspace paths; marketplace pins `jackin-dev` 0.3.0 vs plugin 0.4.0; `TODO.md` still calls the docs site "Starlight" while it is Fumadocs. Do not trust prose over code when integrating.
12. **Single-maintainer, dogfood-driven.** Independent personal project (`J/README.md:96-100`), roadmap prioritized by the author's own workflow; the unified-usage program is currently blocked on external release authorization. Expect priorities to move.

---

## Appendix A — What "control plane" means in jackin today

Three separate things share the phrase in the docs, and none is a fleet control plane: (a) the **capsule** is the in-container control plane for one container's PTYs; (b) the **host daemon** is a per-user lifecycle shell with attention snapshots; (c) the **usage broker** is a per-host quota authority. The vision's "one control plane … how many servers, which agents, where they run" (`V:125-131`) has no implementation and no host-spanning component in the repo; jackin's own architecture note says fleet coordination "stays in the host orchestrator" and there is "no cross-container daemon … no cloud component whatsoever" (`J/docs/content/research/context/engine/02-architecture.mdx:86`).

## Appendix B — Jackin's own proposed shapes worth reusing verbatim

- Run state machine and evidence rule (`02-design-constraints.mdx:34-49`).
- Control-plane ownership table (`02-design-constraints.mdx:51-61`).
- Typed step vocabulary `agent|context|review|verify|github|gate|artifact|parallel` (`02-design-constraints.mdx:83`).
- Conductor topology and MCP tool names `jackin.delegate/await/collect` (`multi-agent-collaboration/index.mdx:53-58`).
- Queue config sketch `[workspaces.*.queue] max_parallel`, `task_sources`, `manual_gates` (`fleet-operations/index.mdx:38-50`).
- Remote config sketch `[remote.<name>] ssh, remote_jackin_path, sync_up, sync_bidi, install` (`remote-execution/index.mdx`).
- Agent state model `Working | Blocked | Done | Idle | Unknown` and codename registry (`control.rs:818-897`).

## Appendix C — Integration points a new project would touch first

| Need | Where in jackin |
|---|---|
| Launch an instance programmatically | `J/crates/jackin-runtime/src/runtime/launch/launch_pipeline.rs:220` (`load_role`), `J/crates/jackin/src/app/load_cmd.rs:43-146`; `--dry-run --format json` for a resolved launch plan |
| Enumerate instances | `~/.jackin/data/instances.json` via `J/crates/jackin-instance/src/manifest.rs:139-455`; `jackin status --format json` (`J/crates/jackin/src/cli/status.rs:45-71`) |
| Talk to a running container | control socket `/jackin/run/jackin.sock` ↔ host `~/.jackin/sockets/<container>/jackin.sock`; `ClientMsg`/`ServerMsg` in `J/crates/jackin-protocol/src/control.rs`; attach frames in `attach.rs` |
| Spawn a second agent session | `SpawnRequest::{Shell, Agent, AgentWithProvider}` in the attach `Hello` frame (`J/crates/jackin-protocol/src/attach.rs:158-172`); daemon side `J/crates/jackin-capsule/src/daemon/session_lifecycle.rs:362` |
| Read agent state / codenames | `ClientMsg::Agents` → `AgentRegistryEntry` (`control.rs:36,818-836`); `AgentState` (`control.rs:887-897`); arbitration in `J/crates/jackin-agent-status/` |
| Expose tools to the agent | MCP stdio server `J/crates/jackin-capsule/src/mcp_server.rs`; auto-registration in `J/crates/jackin-capsule/src/runtime_setup.rs` |
| Per-agent launch argv | `J/docker/runtime/entrypoint.sh:77-136`; model flags `J/crates/jackin-capsule/src/session.rs:1652-1655` |
| Host daemon extension point | `J/crates/jackin-runtime/src/host_daemon.rs:39-89` (`DaemonRequest`/`DaemonResponse`), CLI `J/crates/jackin/src/app/daemon_cmd.rs:14-80` |
| Host-side notifications | `J/crates/jackin-host/src/host_desktop.rs`; attention adapter in `host_daemon.rs:424` |
| Telemetry sink | `OTEL_EXPORTER_OTLP_*` in `J/crates/jackin-diagnostics/src/observability.rs:311-346`; registry `J/crates/jackin-telemetry/registry/attributes.yaml` |
| Git isolation per worker | `MountIsolation::{Worktree, Clone}` (`J/crates/jackin-core/src/isolation.rs:30-72`), `J/crates/jackin-isolation/src/materialize.rs:556-785` |
| Credentials on demand | `ExecBinding`/`CredRequest` (`J/crates/jackin-protocol/src/lib.rs:34-90`), host resolver `J/crates/jackin-runtime/src/exec_host.rs` |
