# termrock — analysis for the Tailrocks TUI component layer

Analysis date: 2026-08-27. Source: local checkout `/Users/donbeave/Projects/tailrocks/termrock` at commit `5a56bd77` (2026-08-24). All paths below are relative to that repo unless stated otherwise. This document is the input for the planning effort that must make termrock the single component layer for every Tailrocks TUI, including the new multi-agent orchestration product.

## 1. Identity

**What it is.** TermRock describes itself as a "hybrid terminal design system" on Ratatui: an interaction kernel (session lifecycle, focus, overlays, semantic intents, design tokens), product-neutral widgets, and composition patterns, inspired by shadcn/ui's owned-source model (`README.md:12-22`, `docs/design/architecture-foundation.md:27-40`). Stack law: Ratatui is the mandatory paint engine, crossterm is the preferred (optional) session/backend adapter, and TermRock owns "the product-grade contracts on top of paint" (`AGENTS.md:16-31`). The vision doc names it "the shared base layer for every Tailrocks terminal interface — jackin's console, tablerock's TUI, parallax's CLI — so all of them feel like one product" (`/Users/donbeave/Projects/tailrocks/vision/README.md:190-197`) and "the shared component layer for all of them" in the "TUI first" section (`vision/README.md:228-233`).

**Origin / provenance.** Extracted from jackin's `crates/jackin-tui` and `crates/jackin-tui-lookbook` via `git-filter-repo` from donor revision `33896a50…`, history boundary `d8006e70…` (`provenance.toml:2-15`). Three donor items were reimplemented rather than imported (`TailScroll`, bottom-chrome helpers, OSC pointer/clipboard encoders — `provenance.toml:17-34`). First commit in the retained history is 2026-04-01; 264 commits total; development is on `main` only, no feature branches or PRs by rule (`AGENTS.md:252-254`), although recent commits carry PR numbers (`#34`, `#43`, `#44`) from the Velnor CI flow.

**Maturity.** Pre-stable by declaration: "The public API is always allowed to change. TermRock is deliberately not stable yet and provides no backward-compatibility guarantees of any kind" (`AGENTS.md:166-170`). Repository is "in its bootstrap extraction period" (`README.md:33-34`). The volume of work is large: 256 KLOC in `crates/termrock/src` (widgets + patterns + kernel), 137 contract-tracked components (`docs/api/component-contracts.json`), 35 patterns (`docs/api/pattern-catalog.json`), 1,076 lookbook stories (`crates/termrock-lookbook/src/stories.rs`), 3,130 `#[test]` functions in the core crate, 331 numbered migration guides (`migrations/`), and a 92,248-line public API inventory (`docs/api/public-api.txt`).

**Version.** Workspace version is `0.11.0` (`Cargo.toml:11`; `cargo metadata` confirms all six crates report 0.11.0). This is inconsistent with the migration ledger, which documents boundaries up to `v0.14.0` (`MIGRATING.md` rows 0029–0331; `migrations/0331-v0.14.0-jackin-parity-handoff.md`). The last Cargo version bump found in history is 0.9.0 → 0.10.0 (`git log -S'version = "0.1' -- Cargo.toml`); the big August landings (`40e3f0e0 feat!: add shadcn-style TUI experience layer`, `2856f718 feat(design)!: complete premium TUI overhaul`, `e1d61f4d feat: achieve Jackin-TermRock parity`) did not bump `Cargo.toml`. Registry catalog entries already declare `version: "0.13.0"` with `min_version: "0.11.0"` (`crates/termrock/src/registry/catalog.rs:36,68`). `RELEASING.md:7-25` requires the first breaking change of a minor to bump the workspace version atomically; that rule has not been followed since v0.10. **Planning consequence:** "v0.12/v0.13/v0.14" in migration docs are documentation labels, not Cargo versions or tags.

**Release / publish status.** Not on crates.io: "The crate is not published to crates.io; a release creates an immutable Git tag and GitHub release" (`RELEASING.md:3-5`); "crates.io publication is not part of the initial migration" (`README.md:33-34`). Consumers pin a full git SHA: `termrock = { git = "https://github.com/tailrocks/termrock.git", rev = "FULL_COMMIT_SHA" }` (`README.md:43-45`). Tags present: `v0.6.0`, `v0.7.0`, `v0.8.0`, `v0.9.0` only (`git tag`); v0.7–v0.9 are "historical backfills" (`RELEASING.md:56`). `CHANGELOG.md` is git-cliff generated and its `[Unreleased]` section still reflects the July state (`CHANGELOG.md:6-84`); it does not mention the August experience-layer or premium-overhaul work. `registry/` is not a package registry either (see §5). The `termrock-lookbook-web` crate is `publish = false` (`crates/termrock-lookbook-web/Cargo.toml:13`).

**Toolchain / MSRV.** `rust-version = "1.97.1"` with the comment "Track latest stable (forward-only; no lagging MSRV policy)" (`Cargo.toml:9-10`); `rust-toolchain.toml` pins it; `compatibility.toml:6-7` records `rust_version_floor = "1.95"`, `tested_toolchain = "1.97.1"`. Edition 2024, resolver 3 (`Cargo.toml:8-9`).

**Ratatui.** Uses the split Ratatui crates, not the umbrella: `ratatui-core 0.1.2` (feature `underline-color`), `ratatui-widgets 0.3.2`, optional `ratatui-crossterm 0.1.2`, `crossterm 0.29.0` (`Cargo.toml:22-27`, `README.md:55-56`). The lookbook additionally pulls `ratatui 0.30.2` with `default-features = false` (`Cargo.toml:22`, `crates/termrock-lookbook/Cargo.toml:26`). Other core deps: `anstyle-parse`, `base64`, `tui-scrollbar 0.2.7`, `unicode-segmentation`, `unicode-width`, `web-time`, optional `serde` (`crates/termrock/Cargo.toml:21-36`). No Tokio anywhere in `Cargo.lock` (0 matches), enforced by ENGINEERING law (`ENGINEERING.md:4-5`).

**Platform claims.** Linux and macOS only; canonical render platform Linux (`compatibility.toml:11-12`). Windows, reduced-color, `NO_COLOR`, RTL/BiDi are "not claimed by this revision line" per README (`README.md:60`), although `architecture-foundation.md:46-61` says the README's no-`NO_COLOR` claim is superseded by migration 0031 — the README was not updated. Windows support is explicitly deferred to "a separately reviewed platform decision" (`TODO.md:6`).

**License.** Apache-2.0, REUSE-compliant, DCO sign-off required (`Cargo.toml:12`, `REUSE.toml`, `AGENTS.md:258-260`).

## 2. Architecture

### 2.1 Crate layout

| Crate | Purpose | Evidence |
|---|---|---|
| `termrock` | The library. Kernel + widgets + patterns. Features: `default = []`, `crossterm`, `serde`. | `crates/termrock/Cargo.toml:16-19` |
| `termrock-lookbook` | Studio/story gallery, deterministic frame/SVG/PNG export, golden + PNG baseline tests. 1,076 stories. | `crates/termrock-lookbook/src/{stories,frame,svg,png,app}.rs`, `tests/{goldens,png_baselines}.rs` |
| `termrock-lookbook-web` | WASM host for the shared demo runtime powering live previews on the docs site. | `crates/termrock-lookbook-web/Cargo.toml:12` |
| `termrock-cli` | `termrock doctor`, `contract list/check`, `plan/add/diff/check <entry-dir>` — offline source-registry CLI spike. | `crates/termrock-cli/src/main.rs:14-32` |
| `termrock-showcase` | Flagship demo app ("the flagship workbench") built from public APIs only, scripted agent, headless scene tests. | `crates/termrock-showcase/src/lib.rs:4-20` |
| `termrock-raster` | Deterministic `Buffer` → PNG rasterizer (swash + tiny-skia, vendored JetBrains Mono) for pixel baselines. | `crates/termrock-raster/src/lib.rs:4-7` |
| `docs/` | Fumadocs + Vite + React site at `termrock.tailrocks.com` with live WASM previews, Playwright tests, catalog checks. | `docs/package.json`, `docs/public/CNAME` |

Public modules of `termrock` (`crates/termrock/src/lib.rs:16-34`): `ansi_text`, `capability`, `context`, `input`, `interaction`, `keymap`, `layout`, `osc`, `patterns`, `perf`, `registry`, `runtime`, `scroll`, `style`, `text`, `widgets`, and `crossterm` (feature-gated). The crate root deliberately re-exports nothing; a test enforces "crate root must not re-export types" (`lib.rs:36-54`, migration 0060).

### 2.2 Layering and "sole authorities"

The crate doc states the architecture in one line: "one paint authority (`style::DesignSystem`), one focus/hit authority (`interaction::InteractionScene`), one modal authority (`interaction::OverlayStack`), per-frame coordination (`context::UiContext`), plus `runtime::run` for the host loop" (`lib.rs:8-11`). Policy tests in `lib.rs:56-215` lock these: `FocusRing` and `ModalStack` must not be public, `Theme`/`DesignTokens`/`PanelEmphasis` must not exist, no widget may paint box-drawing glyphs directly or erase recipe backgrounds.

Layer map from `architecture-foundation.md:33-38`:

| Layer | Distribution | Owns |
|---|---|---|
| Kernel | Rust crate | Session lifecycle, focus, hit geometry, scroll, Unicode safety, overlay stack, semantic intents, per-frame scene registration, design tokens |
| Components | Crate today; source-copy registry later | Styled widgets with stable IDs and borrowed data |
| Blocks / patterns | Crate recipes today; installable sources later | Agent shell, ops dashboard, resource browser layouts |
| Studio | `termrock-lookbook` | Stories, contracts, SVG previews |

Ownership split (`ENGINEERING.md`, `AGENTS.md:73-78`): TermRock owns rendering, layout, styles, semantic roles, focus/navigation, hit geometry, narrow-terminal behavior, Unicode safety, non-color cues, domain-neutral widget state. Consumers own domain state and wording, effects, process policy, secrets, executor choice, and projections from product models into widgets. "Public components borrow render data, use stable caller IDs, separate state from rendering, and expose logical outcomes rather than effects. Base modules must not depend on Tokio" (`ENGINEERING.md:3-5`).

### 2.3 Interaction kernel (`interaction/`, `context.rs`, `keymap.rs`, `input/`)

- **`InteractionScene<Id, LayerId, Action>`** (`interaction/scene.rs:257`) — immediate-mode per-frame registration of `InteractionElement`s in `InteractionLayer`s; resolves focus, hover, hits, and returns `InteractionOutcome`. Sole input-layer authority.
- **`SemanticScene<Id, Action>`** (`scene.rs:1120`) — parented semantic tree rebuilt per frame (`SemanticRole`, label, description, `SemanticState`, actions, rect) for hit discovery, help, jump mode, Studio snapshots, and "AI-readable UI" (`architecture-foundation.md:68`). `SemanticSnapshot` (`scene.rs:929`) is serializable output.
- **`FocusGraph<Id>`** (`interaction/focus_graph.rs:203`) — sole focus-graph authority: tab order, spatial navigation, zones, traps, history, roving; `FocusLens` for focus-lens mode (`focus_graph.rs:743-771`). `RovingFocusGroup` (`roving.rs:89`) for toolbars/tab strips.
- **`OverlayStack<FocusId>`** (`interaction/overlay_stack.rs:755`) — z-ordered overlays with `OverlaySpec` (`OverlayKind`, `OverlaySize`, anchor, `OverlayPolicy`, `NarrowFallback`, `BackdropPolicy`), placement flip/clamp, focus trap + opener restore, pointer routing, modal queue, fullscreen promotion; "Escape closes exactly one conceptual layer" (`docs/design/overlay-stack.md:23-30`). `DismissableLayer`/`DismissPolicy` (`dismissable.rs`) model outside-click/Esc dismissal.
- **`UiIntent`** (`interaction/intent.rs:74-116`) — the semantic intent vocabulary: `Move(NavigationMove)`, `Page`, `Activate`, `Toggle`, `Open`, `Close`, `Cancel`, `Submit`, `Expand`, `Collapse`, `FocusNext/Previous`, `JumpStart/JumpLabel`, `Edit`, `Delete`, `Backspace`, `Search`, `Help`, `Fullscreen`, `OpenCommandPalette`, `AppCommand(AppCommandId)`. Widgets consume intents "where practical"; raw keys map through `default_*_intents` and app keymaps (`architecture-foundation.md:66`).
- **`EventResult<M, FocusId>`** (`event_result.rs:142`) — standard envelope: domain message `M` + `Propagation` + `Redraw` + `FocusRequest` + `OverlayRequest`. Explicitly not an Elm/Bubble-Tea runtime: "Global Elm/Bubble Tea runtime — out of scope — no forced app architecture" (`docs/design/event-result.md:17`).
- **`CollectionState<Id>`**, **`SelectionModel<Id>`**, **`CellSelectionModel`** (`collection.rs`, `selection_model.rs`) — shared cursor/selection state for lists, trees, tables, grids ("one selection language", migration 0296).
- **`Keymap<A>`** (`keymap.rs:233`) — single source of truth for key dispatch and hint advertisement; runtime-configurable (migration 0025), conflict detection (`Conflict`), `raw_bytes_to_chord`.
- **`input::Event`/`KeyEvent`/`MouseEvent`** (`input/event.rs:9-217`) — backend-neutral event vocabulary; crossterm events convert via `Event::from` (`runtime/runner.rs:78`).
- **`UiContext` / `UiHost`** (`context.rs:80,294`) — per-frame bundle of design system, capabilities, intents/keymap, focus, overlays, semantics, clock, diagnostics. "Not a widget tree or React-style context provider. Not a replacement for `Frame`/`Buffer`" (`context.rs:1-25`). `UiHost::test` + `FrameTick::manual` give headless tests.

### 2.4 Runtime and event loop (`runtime/`, `crossterm/`)

- **`runtime::run(model, RunOptions, render, update, next_deadline)`** (`runtime/runner.rs:58-64`): closure-based host loop. Enters a crossterm `Session`, wraps a `QuietBackend<CrosstermBackend>`, drives `FrameClock`/`Presenter`, polls with `poll_timeout` (default 120 ms), uses synchronized output (`BeginSynchronizedUpdate`/`End…`) by default, and restores the terminal on exit (`runner.rs:22-90`). `update` returns `ControlFlow<()>`; `next_deadline` lets animations/timers wake the loop. This is TEA-shaped (model/update/render) but is a plain synchronous blocking loop — there is no async integration, no message channel abstraction, and no subscription system beyond `ReadySubscription` (`runtime/subscription.rs`), which is a fused immediately-ready poll adapter added for jackin parity (migration 0331).
- **`crossterm::Session`** (`crossterm/session.rs:62-156`): scoped raw-mode/alt-screen/mouse/paste/keyboard-enhancement setup with exact reverse restoration, partial-init rollback, and earliest-error preservation (proved in `compatibility.toml:86-90`). `SessionOptions` are independent (migration 0015).
- **Time/motion**: `FrameTick`, `FrameClock`, `Instant` (portable via `web-time`, migration 0280), `Presenter` with `FrameRate`/`TickLadder`/`ScrollClock`, `Animator`/`Animation` spring helpers, `Presence` enter/exit phases, `AnimationDemand` (`runtime/{time,presenter,animate,motion}.rs`). Law: "No `Instant::now()` inside widgets" (`docs/design/streaming-performance.md:135-137`).

### 2.5 Rendering model and paint authority (`style/`, `layout/`, `scroll/`)

- Immediate mode; widgets implement Ratatui `Widget`/`StatefulWidget` and paint into `Buffer` (`AGENTS.md:18-21`, `context.rs`). No retained DOM.
- **`DesignSystem`** (`style/tokens.rs:681`) is the sole paint authority; it carries `RolePalette` (104 semantic `Role`s, `style/mod.rs:120`), `SpacingScale`, `GlyphSet` (Unicode/ASCII), `SurfaceFamily`, `Elevation` ladder (five rungs, migration 0326), `Density`, motion policy, and the frame tick (migration 0299). Row recipes are painted through `DesignSystem::paint_row` (`tokens.rs:1027`) — patterns are forbidden from raw paint (`AGENTS.md:146-150`, enforced by `tests/design_gate.rs::patterns_only_compose`).
- **Presets**: `RolePalette::tailrocks_phosphor()` (default, "the design language Tailrocks projects ship with", `AGENTS.md:172-175`), `terminal_native`, `slate`, `paper`, `ansi`, `high_contrast`, `phosphor`, `obsidian`; `DesignSystem::adaptive()` picks by detected appearance (`style/mod.rs:362-791`, `style/tokens.rs:727-773`).
- **Capability ladder**: `ColorCapability` (truecolor/256/16/monochrome) with `RolePalette::quantized` (`style/quantize.rs:13,334`), `Appearance` detection, `Motion` reduction, `GlyphSet::Ascii`, contrast floor (`style/contrast_floor.rs`, migration 0283). `capability::{TerminalCapabilities, CapabilitySet, CapabilityKind (20 kinds incl. Multiplexer, Ssh, WindowsConPty), CapabilityProfile, CapabilityBoundary, doctor}` (`capability/`, `docs/design/terminal-capability-architecture.md:40-57`). Widgets read `CapabilitySet`; they never probe env at paint time.
- **Layout**: `layout::{Stack, Inline, Grid, Center, panel_stack + ShrinkPolicy, render_dialog_shell, WorkSurface/RegionSpec, Workspace/WorkspaceNode (binary split tree with collapse priorities, `layout/workspace.rs:49-135`), responsive::{ContentPriority, ContractionStage (8 stages), SizeBudget, AdaptiveAnatomy, ViewportClass, ResponsiveRecipe, Breakpoint}}` (`layout/mod.rs:17-43`, `docs/design/responsive-layout.md`).
- **Scroll**: `scroll::{ScrollArea…, TailScroll}` over `tui-scrollbar` metrics; "one scrollbar language" (migration 0291).
- **OSC**: typed `osc::Request` for hyperlinks (OSC 8), pointer shape (OSC 22), clipboard write (OSC 52); consumers own emission (`osc/{request,encode}.rs`).
- **Text**: `ansi_text` (ANSI-to-spans parser), `text` helpers, grapheme-safe `edit_core`.

### 2.6 Accessibility

No screen-reader/AT integration exists (terminal constraint). What exists is "accessible-enough terminal UX" (`AGENTS.md:57-58`): non-color cues as a mandatory quality axis (`no_color`, `ascii_fallback`, `color_ladder` in `docs/design/component-quality-standard.md:37-42`), contrast floor, `Motion::Off`, focus-visible rule ("Border weight never communicates focus: the semantic theme does", `AGENTS.md:177-188`), `SemanticScene` labels/descriptions/roles (the nearest thing to an accessibility tree, also intended for "AI-readable UI"), `KeyboardHelp` generated from `Keymap`, and `JumpOverlay` for direct navigation. The component prompt library lists "Support screen-reader/semantic descriptions" as an aspiration only (`docs/design/component-prompt-library.md:3306`).

### 2.7 Testing tools

- **Contract matrix**: `docs/api/component-contracts.json` — 137 components × six axes (focus, keyboard, mouse, narrowTerminal, nonColor, unicode) with values `covered | partial | caller-owned | not-applicable`; v2 schema with 22 axes and machine-linkable evidence is defined (`component-contract.schema.json`, `component-quality-standard.md:35-42`) and "optional until Q2".
- **Design gate**: `crates/termrock/tests/design_gate.rs` (73 KB) — ~60 source-scanning and render-scanning laws: no bare ellipsis, one chord notation, one overflow note, no interaction underline, accent budget, bold budget per row, no widget paints selection fill by default, patterns only compose, widgets never import patterns, text never touches borders, modal geometry never escapes terminal, flagship widgets survive tiny/random geometry, state matrix distinct, no wide emoji in chrome, real empty states (`design_gate.rs:136-2063`).
- **Hot-path budgets**: `tests/{tree,table,log_pane,detail_table,picker,text_area,viewport}_hot_path.rs` with `perf::budgets()` (e.g. Tree 10k nodes: 100 paints/250 ms and zero steady-state allocations, `docs/design/streaming-performance.md:167-183`).
- **Golden frames**: `crates/termrock-lookbook/tests/goldens.rs` diffs 15 flagship previews against committed cell dumps (`crates/termrock-lookbook/goldens/`, `mise run preview-goldens`, bless with `mise run bless-previews`, `TESTING.md:6-12`).
- **PNG baselines**: `tests/png_baselines.rs` + `termrock-raster`, decoded-pixel zero-tolerance compare, `mise run png-baselines`/`bless-pngs` (migration 0331, `research/tui-png-baselines/README.md`).
- **Lookbook**: 1,076 stories with knobs/interactors, SVG export, frame JSON export, `export-frames` determinism gate (render-twice diff).
- **Showcase scene tests**: `crates/termrock-showcase/tests/scenes.rs` replays scripted scenarios headlessly.
- **Policy tests in `lib.rs`** and `root_reexports_are_forbidden`.
- **API freshness**: `cargo public-api` diff against `docs/api/public-api.txt` and `cargo semver-checks` against the latest tag (`mise.toml:60-61`, `RELEASING.md:58-65`).
- **Docs site**: Playwright preview/pattern/visual tests, catalog and snippet checks (`docs/package.json:21-27`).

### 2.8 Studio, docs site, and catalog surfaces

- **Lookbook (`termrock-lookbook`)**: `stories()` returns 1,076 `Story { id, title, component, description, width, height, … }` entries across 47 top-level story families (`crates/termrock-lookbook/src/stories.rs:169-181,744`); interactive gallery app (`app.rs`), knobs and interactors (`interactors.rs`, 143 KB), deterministic frame JSON export (`frame.rs`), SVG export (`svg.rs`), PNG export via `termrock-raster` (`png.rs`), 256-color palette preview (`palette256.rs`). Native feature `native = ["termrock/crossterm", "ratatui/crossterm", "dep:termrock-raster"]` (`crates/termrock-lookbook/Cargo.toml:21`).
- **Golden set (15 flagship previews)**: `command-palette__basic`, `dialog__destructive`, `form__validation`, `list__selection`, `metrics-dashboard__basic`, `prompt-composer__basic`, `quick-open__basic`, `setup-wizard__capability`, `sidebar__settings`, `status-bar__basic`, `table__basic`, `tabs__status`, `toast__stack`, `tool-call-card__permission`, `transcript__basic` (`crates/termrock-lookbook/goldens/`).
- **Docs site**: 168 component pages and 36 pattern pages under `docs/content/docs/{components,patterns}`, plus `interaction.mdx`, `runtime.mdx`, `quality-migrations.mdx`; live previews run the shared demo runtime compiled to WASM (`termrock-lookbook-web`, `docs/package.json:9`); generated inputs `docs/api/{component-contracts,component-routes,pattern-catalog,handbook-route-migration}.json`; `bun run build` runs component/pattern/snippet/catalog/preview-metric checks before Vite build (`docs/package.json:28`).
- **Machine-readable catalogs**: `docs/api/public-api.txt` (cargo-public-api dump, 92k lines), `component-contracts.json` (137 components), `pattern-catalog.json` (35 patterns with `classification`, `buildingBlocks`, `actions`, `defaultDimensions`), `passive-interaction-exceptions.json`, `termrock::registry::official_kernel_contracts()` (schema v3).

### 2.9 Kernel type cheat-sheet (for planning API adoption)

| Concern | Type(s) | File |
|---|---|---|
| Paint / tokens | `DesignSystem`, `RolePalette`, `Role`, `SpacingScale`, `GlyphSet`, `Elevation`, `Density`, `SurfaceFamily` | `style/{tokens,mod,density,glyph}.rs` |
| Capability | `TerminalCapabilities`, `CapabilitySet`, `CapabilityKind`, `CapabilityProfile`, `CapabilityBoundary`, `ColorCapability`, `Appearance` | `capability/*.rs`, `style/{quantize,appearance}.rs` |
| Input | `Event`, `KeyEvent`, `KeyCode`, `KeyModifiers`, `MouseEvent`, `Keymap<A>`, `KeyChord`, `KeyBinding`, `Visibility` | `input/event.rs`, `keymap.rs` |
| Intents / results | `UiIntent`, `NavigationMove`, `PageMove`, `AppCommandId`, `EventResult<M, FocusId>`, `Propagation`, `Redraw`, `FocusRequest`, `OverlayRequest`, `Outcome<T>` | `interaction/{intent,event_result}.rs` |
| Focus / hit | `InteractionScene`, `InteractionLayer`, `InteractionElement`, `HitRegion`, `FocusGraph`, `FocusNode`, `FocusLens`, `RovingFocusGroup` | `interaction/{scene,focus_graph,roving}.rs` |
| Semantics | `SemanticScene`, `SemanticNode`, `SemanticRole`, `SemanticState`, `SemanticSnapshot` | `interaction/scene.rs` |
| Overlays | `OverlayStack`, `OverlaySpec`, `OverlayKind`, `OverlaySize`, `OverlayPolicy`, `OverlayOutcome`, `DismissableLayer`, `DismissPolicy`, `render_backdrop` | `interaction/{overlay_stack,dismissable,modal}.rs` |
| Collections | `CollectionState`, `SelectionModel`, `SelectionKind`, `CellSelectionModel`, `Virtualizer`, `VirtualWindow` | `interaction/{collection,selection_model}.rs`, `widgets/{virtualizer,data_view}.rs` |
| Per-frame | `UiHost`, `UiContext`, `UiDiagnostics` | `context.rs` |
| Runtime | `run`, `RunOptions`, `FrameTick`, `FrameClock`, `Presenter`, `FrameRate`, `Animator`, `Presence`, `AnimationDemand`, `ReadySubscription` | `runtime/*.rs` |
| Session | `Session`, `SessionOptions`, `CrosstermBackend` | `crossterm/session.rs` |
| Layout | `Stack`, `Inline`, `Grid`, `Center`, `Workspace`, `WorkspaceNode`, `PaneId`, `WorkSurface`, `RegionSpec`, `ResponsiveRecipe`, `ContentPriority`, `ContractionStage`, `panel_stack` | `layout/*.rs` |
| Perf | `ComponentBudget`, `budgets()`, `check_zero_alloc_steady`, `check_max_rows_touched`, `FollowMode`, `ScrollAnchor`, `NewContentIndicator`, `StreamCoalescer`, `StreamBatch`, `BackpressureSignal`, `DirtyFlags`, `UpdatePriority` | `perf/{budget,follow,stream}.rs` |
| OSC | `Request`, `PointerShape`, `HyperlinkRegion`, `ClipboardWrite`, `encode*` | `osc/{request,encode}.rs` |

## 3. Component inventory

Status vocabulary used here: **stable-contract** = in `component-contracts.json` with all applicable axes `covered`; **partial** = contract has `partial`/`caller-owned` axes or the docs describe open gaps; **pattern** = `patterns/` example composite (copy-adapt, not a first-class widget). No component in termrock is API-stable in the semver sense (see §9). One-line purposes are taken from each module's `//!` header.

### 3.1 Foundation and chrome (`widgets/`)

| Widget | Purpose | Status |
|---|---|---|
| `Surface` | Lowest-level fill/padding/border/clip/hit geometry | stable-contract |
| `Panel` (+`PanelChrome`, variants, body modes) | Composable panel chrome with anatomy | stable-contract |
| `Card` | Raised container = Panel + Surface | stable-contract |
| `Section`, `Separator` | Editorial grouping, labeled rules | stable-contract |
| `Text`, `Heading`, `Paragraph`, `Label`, `Description`, `HighlightedText` | Typographic primitives | stable-contract |
| `Icon`, `Kbd`/`ShortcutHint`, `Badge`, `Tag`/`Chip`, `Link`/`ActionLink`, `AvatarGlyph`/`Identity` | Inline semantics | Badge partial (focus/keyboard/mouse `partial`) |
| `AccentRail`, `ComposedRow`, `TieredRow`, `RowChrome`, `ChromeRow`, `BlockChrome`, `TableChrome` | Row/block anatomy helpers | stable-contract / helpers |
| `StatusBar`, `StatusStrip`, `StatusIndicator`, `SemanticStatus`, `HintBar`, `Toolbar`, `ActionBar`, `MenuBar` | Chrome rows | ActionBar keyboard `caller-owned` |
| `CodeBlock`, `MarkdownView`, `StreamingMarkdown`, `AnsiText` | Content rendering | stable-contract |
| `ImageSurface` | Optional terminal image protocol surface | contract present; protocol emission is consumer-owned |
| `ThemePicker`, `DesignInspector` | Studio/debug tooling | DesignInspector "not a production shell" |

### 3.2 Inputs and forms

`Button`, `IconButton`, `ButtonGroup`, `Toggle`/`ToggleGroup`, `Checkbox`, `RadioGroup`, `Switch`, `SegmentedControl`, `Slider`/`RangeSlider`, `TextInput` (validation, external cursor), `PasswordInput`, `NumberInput`, `SearchInput`, `PathInput`, `TokenField`, `TextArea` (multi-line grapheme-safe, two-axis viewport), `Select`, `MultiSelect`, `Combobox`/`Autocomplete`, `DateTimePicker`, `FilePicker`, `KeybindingRecorder`, `InputOtp`, `InputGroup`, `Form`/`Field`/`Fieldset`/`FieldRow`/`FieldMessage`, `FormWizard`, `Stepper`, `ProgressSteps`. All are contract-tracked; the family shares one field chrome (`design_gate.rs::inputs_share_field_chrome`).

### 3.3 Navigation and overlays

`Tabs`, `Sidebar`/`NavigationList`, `TreeNavigation`, `Breadcrumbs`, `Pagination`, `Menu`, `DropdownMenu`/`ContextMenu`, `CommandPalette` (flagship: fuzzy filter, groups, recents, nested pages, async host results with generation gates, fullscreen promotion), `QuickOpen`, `Picker`, `HistoryPicker`, `JumpOverlay` (jump mode over `SemanticScene`), `KeyboardHelp` (generated from keymap), `Tooltip`, `Popover`, `Dialog`, `ChoiceDialog`, `MessageDialog`, `AlertDialog`, `ConfirmPrompt`, `Drawer`/`Sheet`, `FullscreenViewer`/`SemanticZoom`, `PreviewCard`, `Carousel`, `Collapsible`, `Accordion`, `CompletionMenu`, `SlashCommandMenu`. All route through `OverlayStack` open helpers (`overlay-stack.md:13-18`).

### 3.4 Feedback and state

`Toast` (priority, actions, lifecycle, entrance motion), `NotificationCenter` (persistent history, grouping, dedup keys, drawer/full-page recipes; persistence host-owned), `Callout`/`Alert`, `Spinner`/`ActivityIndicator`, `ProgressBar`, `Skeleton`, `EmptyState`, `ErrorState`/`Recovery`, `LoadingOverlay`/`BusyBoundary`, `OfflineBanner`/`ReconnectingState`, `LoadingView`/`Banner`.

### 3.5 Data presentation and large data

| Widget | Purpose | Status |
|---|---|---|
| `List` (+`ListRow`, multiselect contract) | Composable collection view | stable-contract |
| `VirtualList` | O(viewport) list over `Virtualizer`; million-row, async pages, follow-tail | stable-contract; budget `virtual_grid_million_window` |
| `Virtualizer` | Canonical 1D/2D virtualizer (stable indices, overscan, variable extents, sticky headers, anchors) | kernel primitive |
| `VirtualGrid` | Two-axis virtualized grid over caller-projected cells | stable-contract |
| `Table` | Static/moderate columnar display | stable-contract |
| `DataTable` | Interactive/virtualized grid: sort, filter, column ops, cell/range selection, inline edit, million-row projection | stable-contract; hot-path budget |
| `TreeTable`, `DetailTable`, `KeyValueTable`, `KeyValueList`, `ObjectInspector` | Hierarchical/detail grids | stable-contract |
| `Tree` | Hierarchical collection, lazy children, stable IDs, virtualized | stable-contract; zero-alloc budget |
| `FileTree` | Filesystem-specialized Tree | stable-contract |
| `ScrollArea`, `Viewport` | Shared scrolling primitives | kernel |
| `Sparkline`, `Chart` (line/area), `Gauge`, `Histogram`, `SegmentedMeter`, `MetricRadar`, `BarSeries`, `MetricTile` | Visualization family | stable-contract; shadcn chart coverage docs |
| `DependencyGraph` | Constrained layered graph viewer with list/tree fallback; "does not promise arbitrary graph-layout quality" | contract present; explicitly limited |
| `Timeline`, `CheckpointTimeline` | Chronological events; rewindable session history | stable-contract |
| `LogPane` | Append-owned bounded scrollback with follow | stable-contract; hot-path budget |
| `LogStream` | Projected-window professional log viewer: follow/pause/unseen, severity, search, filters, bookmarks, dropped-line signals | stable-contract |
| `EventStream` | Typed structured-event viewer | stable-contract |
| `TerminalOutput`, `TerminalCellGrid`/`TerminalCellSource` | Command output presentation; borrowed emulator-cell projection | stable-contract; cell grid added for jackin parity (0331) |
| `DiffView`, `DiffReview` | Read-only unified/side-by-side diff; interactive review with file/hunk/line decisions and comments | stable-contract |
| `Diagnostic`/`CodeFrame`, `HexViewer`, `SearchResults`, `TraceWaterfall` | Developer data surfaces | stable-contract |
| `SplitPane`, `ResizablePanelGroup` | Two-pane and N-pane resizable layouts with handles, collapse, presets, keyboard resize, drawer recipe; content-agnostic | stable-contract; latest commits `#43` add seamless mode + host-seeded sizes |

### 3.6 Agent-era widgets

`PromptComposer` (flagship input: queue, chips, blur-draft, completions), `PermissionPrompt` (default-deny trust surface with provenance chain, generations, FIFO queue; `y` unbound), `Transcript` (variable-height streaming transcript; "sole agent conversation surface"), `MessageThread`, `ToolCard`/`ToolCallCard`, `ThinkingBlock`, `TokenMeter`, `ContextMeter`, `ModeRibbon`/`WorkbenchMode`, `ModelSelector`/`AgentModeSelector`, `QuestionFlow`, `PlanReview`, `AttachmentChip`/`PasteChip`, `FileMention`/`EntityMention`, `SourceCitation`, `PromptQueueItem` model types. The agent collection is designed in `docs/design/termrock-agent.md` (22 components + `AgentWorkbench`), status "Draft (design SoT)".

### 3.7 Patterns (`patterns/`, 35, copy-adapt examples)

Classification from `docs/api/pattern-catalog.json`: 17 composite, 16 application, 2 layout-helper.

- Layout helpers: `AgentShell` (stream + prompt + status + side rail geometry), `StudioShell`.
- Application shells: `AppShell` (slots, focus order, overlay bounds), `AppDashboard`, `OpsDashboard` (metrics strip + main + log + status), `ResourceBrowser` (rail + detail + preview), `MetricsDashboard`, `ObservabilityDashboard` (LogStream + EventStream + inspector), `AgentWorkbench` (north-star: TaskRail + Transcript/MessageThread + ActivityShelf + PromptComposer + status + PermissionPrompt/QuestionFlow/PlanReview/DiffReview/SessionPicker overlays), `DatabaseWorkbench`, `GitWorkbench`, `FileManager`, `ProjectLauncher`, `HelpCenter`, `SettingsScreen`, `SetupWizard`, `AuthEntry`, `ConnectionManager`.
- Composites: `ActivityShelf`, `AgentStatusHeader`, `ApprovalQueue` (multi-type human-decision inbox: permissions, questions, plans, diffs; high-risk only `Open`, never bulk grant), `BackgroundTaskPanel` (detached jobs, live output, restart/stop requests), `TaskRail` (unified task/agent inventory with groups, deps, search, `ActivityModel`), `SubagentCard` (delegated agent run: role, provenance, status, steer/message/cancel/retry/detach/promote outcomes), `WorkingStateCard`, `TerminalRunCard`, `PlanReview`, `PromptQueue`, `SessionPicker`, `IntegrationStatus` (MCP servers/plugins), `ErrorRecovery`/`CrashReport`, `ProcessTable`, `QueryEditor`, `ResultGrid`, `SchemaBrowser`.

Every pattern file must carry `//! Teaches:` and `//! Composes:` headers and "Copy-adapt: keep the widget composition and the focus routing; replace the domain types, the wording, and the effects with your own" (enforced by `design_gate.rs::patterns_have_charter_docs`).

## 4. Consumer usage

Survey of the five named repositories (grep of `Cargo.toml`, `Cargo.lock`, `termrock::` imports, local widget definitions, and docs). Commit ages are relative to termrock history: `5a56bd77` = HEAD (2026-08-24), `1ac0d079` = 2026-08-21, `29a16b5b` = 2026-08-19.

| Repo | Uses termrock | Pin | Locked commit | Ratatui | Files using termrock | Local duplicate widgets |
|---|---|---|---|---|---|---|
| jackin | yes (+ `termrock-raster`) | git rev, `version = "=0.11.0"`, features `crossterm, serde` | `1ac0d079` | `ratatui 0.30` + `ratatui-core =0.1.2` | 157 | yes (see below) |
| tablerock | yes | git rev, `=0.11.0`, features `crossterm, serde` | `29a16b5b` | `ratatui-core 0.1.2` + `ratatui-crossterm 0.1.2` only | 9 | none (architecture tests forbid) |
| holla | yes | `branch = "main"`, no version, feature `crossterm` only | `5a56bd77` | `ratatui =0.30.2` direct + `crossterm =0.29.0` direct | 7 | none |
| velnor-tui | no | — | — | none | 0 | not a TUI |
| parallax | no | — | — | none | 0 | not a TUI |

### 4.1 jackin (`/Users/donbeave/Projects/tailrocks/jackin-project/jackin`) — donor and heaviest consumer

- Pin: `Cargo.toml:120` `termrock = { version = "=0.11.0", git = "https://github.com/tailrocks/termrock.git", rev = "1ac0d0793b8cfd9edc61ced241e2b2ecb89162b4", features = ["crossterm", "serde"] }`; `Cargo.toml:121` pins `termrock-raster` at the same rev (for PNG baseline tests). `Cargo.lock:6853-6873` confirms. `ratatui = "0.30"` and `ratatui-core = "=0.1.2"` with the comment "Must stay lockstep-compatible with ratatui 0.30" (`Cargo.toml:113-116`).
- Dependent crates (7): `jackin-console` (89 files), `jackin-capsule` (34), `jackin-launch` (23), `jackin-tui` (3), `jackin-oppicker` (3), `jackin-xtask` (2), `jackin` (2), `jackin-diagnostics` (1). `jackin-term` uses `ratatui-core` only.
- What it uses (qualified-path hit counts): `style` 587 (`DesignSystem::default` 306; `Role::{TextMuted, Accent, Text, TextStrong, Danger, Tab*, StatusBar, ScrollTrack}`), `widgets` 231 (`HintSpan`, `PanelChrome`, `ScrollAreaState`, `TextInputState`, `render_hint_bar`, `Panel`, `ListState`, `Tabs`/`TabsState`/`lay_out_tabs`, `Toast`, `Viewport`, `VirtualListState`, `KeyboardHelpState`), `scroll` 204 (`ScrollAxes`, `DialogScroll`), `text` 47 (`display_cols`), `osc` 41 (pointer, clipboard, hyperlink encoders), `interaction` 34 (`HitRegion`), `input` 30, `layout` 28 (`render_dialog_shell`), `keymap` 16, `runtime` 14 (`Instant`, `FrameTick`), `patterns` 2, `ansi_text` 1; plus `termrock_raster::{compare_png_pixels, render_png}`.
- **Adoption depth is shallow relative to the surface.** jackin consumes tokens, scroll math, hints, dialog shells, and a handful of widgets, but not `InteractionScene`, `OverlayStack`, `FocusGraph`, `UiContext`, `runtime::run`, `Transcript`, `PromptComposer`, `PermissionPrompt`, `AgentWorkbench`, or any pattern beyond two references. It still hand-rolls product dialogs and inputs.
- **Duplicates/divergence.** `crates/jackin-tui/src/lib.rs:3-10` states the crate "never owns neutral widgets or surface event loops … Neutral widgets and interaction mechanics belong to TermRock", and `crates/jackin-tui/` is now tiny (`lib.rs`, `operator_info.rs`, `runtime.rs`, `tokens.rs`). But `crates/jackin-console/src/tui/components/` holds ~30 modules (`dialogs.rs` 15.9 KB, `save_preview.rs` 46.8 KB, `auth_panel.rs` 22.1 KB, `editor_rows.rs` 21.6 KB, `modal_overlay.rs`, `keyboard_help.rs`, `spinner.rs`, `footer_hints.rs`, several `*_picker.rs`). Concrete duplicates of termrock widgets: `jackin-console/src/tui/components/dialogs.rs:80` local `TextInputState` + `:158 render_text_input` (used by `op_picker/render.rs:37-38`, which names it `donor`), a second local `TextInputState` in `jackin-oppicker/src/adapters.rs:16`, local `Dialog` enum in `jackin-capsule/src/tui/components/dialog.rs:147`, local `StatusBar` in `jackin-capsule/src/tui/components/status_bar.rs:70`, and dialog implementations in `jackin-launch/src/tui/components/{dialog,failure_dialog,container_info_dialog,build_log_dialog}.rs`, `jackin-console/src/tui/dialog_layout.rs`, `jackin-core/src/standalone_dialog.rs`.
- Migration state: `TODO.md:44-47` records an open item (`keyboard-help-mouse`: console overlay is keyboard-only while `termrock::widgets::KeyboardHelpState::handle_mouse` exists) "Last verified: 2026-08-21 … at `roadmap/termrock-migration`" — an in-flight migration branch. `AGENTS.md:93,97` designate TermRock as "Shared components" and its docs as the "Lookbook"; `crates/AGENTS.md:158` makes "use TermRock for product-neutral TUI components" a standing invariant. termrock's own migration 0331 ("Jackin parity handoff") and `compatibility.toml` show the parity work was done from termrock's side; jackin has not yet cut over to the experience-layer APIs.
- No vendored termrock source.

### 4.2 tablerock (`/Users/donbeave/Projects/tailrocks/tablerock-project/tablerock`) — cleanest adopter

- Pin: `Cargo.toml:26` `termrock = { version = "=0.11.0", git = "…/termrock.git", rev = "29a16b5bff84ea8609854711b774e87acbc456cc", features = ["crossterm", "serde"] }`. Uses only `ratatui-core 0.1.2` and `ratatui-crossterm 0.1.2` (`Cargo.toml:19-20`); no umbrella `ratatui` in `Cargo.lock`. This is the same backend-neutral posture as termrock itself.
- Dependent crates: `tablerock-tui` (`Cargo.toml:13`), `tablerock-cli` (`Cargo.toml:25`).
- Widest widget surface of any consumer: `crates/tablerock-tui/src/view.rs:8-17` imports `interaction::HitRegion`, `style::PanelChrome`, and 28 widget items — `ActionBar`, `CompletionMenu`, `Form`/`Field`/`Fieldset`, `VirtualGrid`, `Panel`, `StatusBar`, `Tabs`, `TextArea`, `Tree`, `render_hint_bar`. `model/mod.rs:25-30` uses `FocusGraph`/`FocusNode`, `Keymap`, `DesignSystem`; `keymap.rs:3-6` uses `KeyBinding`/`KeyChord`/`Visibility`; `tablerock-cli/src/run.rs:19` uses `termrock::crossterm::{Session, SessionOptions}`; `input.rs:4-5` uses `input::Event` etc. Still does not use `InteractionScene`, `OverlayStack`, `UiContext`, or `runtime::run`.
- Enforcement: `crates/tablerock-tui/tests/architecture.rs:32` `connection_screens_use_termrock_form_and_tree()`, `:69-70` asserts the TUI crate depends on termrock; `crates/tablerock-core/tests/architecture.rs:35` bans termrock from the core layer; `AGENTS.md:37` says neutral widgets live in termrock. No local `Panel`/`List`/`Dialog`/`Tree`/`VirtualGrid` definitions.
- Migration ledger: `docs/evidence/termrock/` with entries for the 0.8, 0.9 (styled tab glyphs, input+OSC, key vocabulary, constructible theme, semantic palette, slate preset, neutral event, canonical module) and 0.10 series (metadata+selection, widget construction, visible scroll, closure runner spike, runtime keymap spike), plus "577 TermRock main compatibility refresh" (`docs/evidence/README.md:637-658`); `docs/architecture/termrock-integration.md`; `ROADMAP.md:55` "phase-1 — termrock substrate and TUI shell"; upstream feature plans `008-termrock-virtualgrid.md` and `010-termrock-textarea-completionmenu.md` (`docs/prompt.md:46,50`). tablerock is the consumer that has been pushing generic capabilities upstream.

### 4.3 holla (`/Users/donbeave/Projects/tailrocks/holla-project/holla`) — adopter, unpinned

- Pin: `Cargo.toml:23` `termrock = { git = "https://github.com/tailrocks/termrock.git", branch = "main", features = ["crossterm"] }` — no version, no rev, tracks `main`; `Cargo.lock:2675-2677` resolves to `5a56bd77` (termrock HEAD). Direct `ratatui = "=0.30.2"` and `crossterm = { version = "=0.29.0", features = ["event-stream"] }` (`Cargo.toml:21-22`). No `serde` feature.
- Usage: all seven files in `src/tui/` (`app`, `analyzer`, `menu`, `insights`, `finder`, `cleanup_flow`, `trust`). Items: `crossterm::Session`/`SessionOptions` (8 each), `widgets::{Backdrop, ChoiceDialog, Dialog, MessageDialog, List/ListRow/ListState/RowRole, Panel, TextInput/Validation, Tree/TreeNode/TreeNodeStatus, Progress, StatusBar/StatusSlot/StatusRegion, HintBar/Hint, DetailTable…}`, `style::{DesignSystem as Theme, Density, PanelChrome, Role}`, `layout::centered_rect`, `keymap::*`, `osc::encode_clipboard`, `interaction::Outcome`, `ansi_text::styled_spans` (`src/tui/finder.rs:13-25`, `analyzer.rs:29-38`, `cleanup_flow.rs:5-14`).
- No local duplicates. Mixed layering: composes termrock widgets into raw `ratatui` frames and owns its own crossterm `event-stream` loop rather than `runtime::run`. `PRODUCT.md:16` claims the dependency is "pinned" — it is not.

### 4.4 velnor-tui (`/Users/donbeave/Projects/tailrocks/velnor-project/velnor-tui`) — not a TUI

No termrock, no ratatui, no crossterm in any `Cargo.toml`/`Cargo.lock`. Workspace crates: `velnor-client`, `velnor-control`, `velnor-model`, `velnor-render`, `velnor-runner`, `velnor-tools`, `velnorctl`. `crates/velnor-render/src/lib.rs:1-9` describes "Output renderers for Velnor operator surfaces" — `table | wide | json | yaml | jsonl | name` stdout formatters. termrock mentions are CI-fleet references only (`VELNOR_PROJECTS_SETUP.md:28`, `AGENTS.md:477`). The repo name is misleading; there is nothing to migrate.

### 4.5 parallax (`/Users/donbeave/Projects/tailrocks/parallax-project/parallax`) — not a TUI

No termrock, ratatui, or crossterm anywhere; `parallax-cli` is a plain clap CLI; no `.md` mentions termrock. The vision's "parallax's CLI" line (`vision/README.md:196`) is aspirational.

### 4.6 Cross-consumer findings

1. **Three adopters, three different termrock commits** (`1ac0d079`, `29a16b5b`, `5a56bd77`), all reporting `0.11.0`. There is no shared pin and no way to express the difference via version because the Cargo version has not moved (§1).
2. **holla tracks `main` unpinned**, violating termrock's own consumer rule (`README.md:29-31`, `AGENTS.md:168-169`).
3. **Ratatui layering is inconsistent**: jackin and holla depend on umbrella `ratatui 0.30.2`; tablerock and termrock use `ratatui-core` + `ratatui-crossterm` only.
4. **Nobody uses the interaction kernel as designed.** No consumer uses `InteractionScene`, `OverlayStack`, `UiContext`, `SemanticScene`, or `runtime::run`; tablerock uses `FocusGraph`. Consumers use termrock as a widget + token crate, which is exactly the "strong Ratatui crate with aspirational APIs" diagnosis in `docs/design/shadcn-quality-roadmap.md:30-36`.
5. **jackin, the donor, retains the most duplicate chrome** and has an open migration branch; termrock's parity work (0331, `termrock-raster`, `TerminalCellGrid`, `ReadySubscription`) was done to enable that cutover.
6. **No consumer uses `patterns/`** (jackin: 2 hits). The copy-adapt model has no evidence of use in products yet.
7. **No forks or vendored copies** of termrock source exist in any consumer.

## 5. Extension model

**Two mechanisms coexist, and only one is real today.**

1. **Library dependency (real).** "The current distribution unit is the Rust crate" (`AGENTS.md:246-249`). Consumers `git`-pin `termrock`, import from modules, and build product widgets by composing public widgets, `DesignSystem` recipes, `InteractionScene`, `OverlayStack`, and `layout` primitives. The `AgentWorkbench` and every pattern show the intended shape: host owns domain model and projects it per frame into borrowed widget inputs; widgets return typed outcomes; host performs effects. `docs/design/showcase-api-gaps.md` documents the protocol when a product needs a private workaround: log the gap, fix TermRock, never paper over with private chrome (`showcase-api-gaps.md:3-5, 225-231`); every listed gap is closed.

2. **Source-owned "shadcn" registry (spike only).** `docs/design/source-owned-registry.md` describes the target: kernel crate stays a binary dependency; components/blocks/themes/keymaps are copied into the app via `termrock add`, tracked in `termrock.toml`/`termrock.lock`, updated with 3-way merge (`source-owned-registry.md:58-89`). Implemented today: `termrock-cli` with `plan/add/diff/check <entry-dir>` against local `registry/fixtures/*/entry.json` (schema 1: name, version, `kernel` = "0.11.0", files with sha256 and `dest`) and `contract list/check` over `termrock::registry::official_kernel_contracts()` (`crates/termrock-cli/src/main.rs:14-32`, `registry/fixtures/ops-dashboard/entry.json`, `registry/official/README.md`). Six fixtures exist (`demo-block`, `form-wizard`, `ops-dashboard`, `resource-browser`, `settings-shell`, `tiny-component`). There is no hosted registry, no `termrock update`, no `termrock/agent/*` items ("Registry: demo blocks; no `termrock/agent/*` items yet", `termrock-agent.md:135`). `architecture-foundation.md:76-78` lists "Full registry CLI (`termrock add`), multi-crate split, complete agent product pack, Workbench app, Windows/ConPTY, RTL/BiDi" as non-goals of the current slice.

**Building block vs example composite law** (`AGENTS.md:90-154`, `docs/design/building-block-vs-example-composite.md`): anything with a product noun in its public model goes to `patterns/`; `widgets` never depends on `patterns` (test `widgets_never_import_patterns`); no product-branded widgets under `widgets`; "When a generic capability is missing, extend `widgets` (or the interaction kernel)." For a Tailrocks product this means: generic capability gaps must land in termrock, product assemblies live in the product (or as a `patterns/` example). Migration 0331 makes the same point for jackin: "BrandHeader, digital rain, launch animation, and other brand/domain compositions must not move into `termrock::widgets`" (`migrations/0331-…:29-33`).

**Practical extension recipe today:** (a) depend on `termrock` with `features = ["crossterm"]`; (b) build a `DesignSystem` (`tailrocks_phosphor` or `adaptive`) and `UiHost`; (c) per frame `begin_frame` → `UiContext`; (d) compute geometry with `AppShell`/`Workspace`/`ResizablePanelGroup`; (e) register interactive regions in `InteractionScene`, paint widgets with borrowed data; (f) route `input::Event` through `OverlayStack` first, then scene, then widget `handle_intent`/`handle_key`; (g) apply typed outcomes to the domain model. `termrock-showcase` is the reference implementation (`crates/termrock-showcase/src/{app,demo_runtime,model}.rs`).

## 6. Engineering standards

- **`ENGINEERING.md`** (5 lines): borrowed render data, stable caller IDs, state separated from rendering, logical outcomes not effects, no Tokio in base modules, crossterm optional.
- **`AGENTS.md`** (260 lines, symlinked as `CLAUDE.md`): north star, stack law, shadcn-class quality bar, "Breaking changes are free; excellence is not", building-block-vs-composite law with checklist, patterns-contain-zero-raw-paint, focus-visible panel hierarchy, forward-only design, cross-surface consistency ("Inconsistency is a defect"), mandatory sequential migration files, "Every public widget must be represented by the catalog's generated API inventory, contract matrix, documentation, story, and deterministic preview", main-only development, Conventional Commits + DCO.
- **`TESTING.md`**: `mise run check` (fmt, clippy `-D warnings`, all-feature nextest, doctests) before every commit; `mise run gate` (adds no-default-features, examples, rustdoc `-D warnings`, cargo-hack feature powerset, cargo-deny, cargo-shear, packaging, preview goldens) before every push. Lints: `missing_docs = deny`, `unsafe_code = forbid`, clippy correctness/suspicious/perf deny; style/complexity/pedantic allowed "until the large surface is cleaned incrementally" (`Cargo.toml:37-56`).
- **`performance-baseline.md`**: historical v0.6 donor comparison (clean build 1.4 s, catalog render 0.098 s, first frame 0.515 s) plus pointer to `termrock::perf::budgets()`; policy "no more than 20% regression … without an evidence-backed explanation; no interaction or rendering contract may regress in exchange for speed" (`performance-baseline.md:26`). Live budgets in `docs/design/streaming-performance.md:167-185` with CI-fail on regression and "raising a budget requires intentional PR + measurement note".
- **`compatibility.toml`**: schema-1 record of the first-consumer compatibility contract at `v0.6.0` — termrock revision `f4368a3e`, jackin revision `27c450e9`, verification commands and results on Linux and macOS (`compatibility.toml:1-96`). It has not been updated since 2026-07-16 and predates the entire August redesign; the jackin evidence there refers to a pre-experience-layer API.
- **`provenance.toml`**: donor repository, frozen revision, history boundary, reimplemented items (see §1).
- **`deny.toml`**: yanked advisories denied, license allowlist (Apache-2.0, MIT, Unicode-3.0, Zlib, BSD-2/3), wildcard deps denied, unknown registries/git denied.
- **CI**: `.github/workflows/{ci,docs,hygiene,release}.yml`; PR lane runs on self-hosted Velnor runners (`velnor-target-mvp`), push/dispatch on `ubuntu-26.04` (`ci.yml:168`); "fleet contract" enforcement job; docs deploy to `termrock.tailrocks.com`. Rust verification is nextest-only.
- **Docs governance**: `docs/design/component-documentation-standard.md`, `component-quality-standard.md` (completeness law: "Compile + render alone never suffice", `:15-25`), `docs/api/public-api.txt` freshness gate.

## 7. Roadmap, TODO, research, open problems

- **`roadmap/README.md`** is an empty table (header only). **`research/README.md`** lists one topic: `tui-png-baselines` (2026-08-16), which concluded libghostty cannot render PNGs and led to `termrock-raster`. The `plans/` tree was deleted twice (`8adddd9c chore(docs): remove plans/ directory`, `2e191af5 chore: remove implementation plans tree`); plan numbers referenced across docs (plans 001–051) no longer resolve to files.
- **`TODO.md`** (4 items): portable benchmarks/fuzz/mutation testing "after the first stable consumer migration"; shared testing helpers only after two independent consumers need the same API; measure 20 CI runs before compiler cache; Windows only via separate platform decision.
- **Design SoT documents that define the forward plan** (all under `docs/design/`):
  - `shadcn-tui-strategic-brief.md` (62 KB) — category direction: kernel + registry + Studio + `@termrock/agent` pack; "TermRock Workbench" north-star app (§11); multi-surface/plugin architecture (§12); capability profiles (§13).
  - `pre-1.0-api-redesign.md` — "Accepted execution SoT — M1–M3 landed (0060–0062); next M4 OverlayStack-only / Form interim remainder" (`:284`). Diagnosis: the surface "grew by accretion … dual (sometimes triple) authorities for paint, focus, modals, prompts, permissions, streams, and grids" (`:297`). Later migrations 0063–0088 executed most of the remaining milestones (agent dual cutover, transcript sole stream, overlay stack sole, data-table cursor…).
  - `source-owned-registry.md` — full registry architecture; only the offline spike is live.
  - `termrock-studio.md` — Studio as harness + inspector + recorder; lookbook is the seed; recording format was closed as "scripted tests" instead (`showcase-api-gaps.md` GAP-REC-1).
  - `termrock-agent.md` — 22-component agent pack, Draft.
  - `streaming-performance.md` implementation plan: P0–P1 done; **P2 transcript coalescer + last-block cache, P3 LogStream follow chrome, P4 workbench composite frame budget — "Next"; P5 scene telemetry, P6 release benches — "Later"** (`:247-258`). Budgets `transcript_10k_blocks`, `overlay_open_close`, `workbench_composite_frame` are listed as "(wire next)" — not yet enforced (`:176-181`).
  - `termrock-component-audit-2026-08.md` — 48-component designer audit whose foundations F1–F10 drove migrations 0281–0330.
  - `component-quality-standard.md` — contracts v2 "optional until Q2".
- **Migration volume by declared version** (files in `migrations/`): v0.7.0 1, v0.8.0 1, v0.9.0 8, v0.10.0 5, v0.11.0 13, v0.12.0 31, v0.13.0 221, v0.14.0 51. The v0.13.0 block (0060–0280) is the pre-1.0 redesign plus one migration per component; v0.14.0 (0281–0331) is the August "premium overhaul" plus jackin parity. Only v0.7–v0.9 have tags.
- **Open problems evident from the tree:**
  1. Version/tag/changelog drift (§1): no tag since v0.9.0, Cargo still 0.11.0, migrations claim v0.14.0, CHANGELOG stale.
  2. `compatibility.toml` and README compatibility table are stale relative to the August redesign.
  3. Registry distribution is a spike; the "you own the code" promise is documentation, not product.
  4. Async integration: no channel/subscription model beyond `ReadySubscription`; the cross-thread model is prose in `streaming-performance.md:201-216` ("workers → mpsc deltas → UI StreamCoalescer") with `perf::StreamCoalescer` as the only kit.
  5. Multi-agent budgets (`workbench_composite_frame`, `transcript_10k_blocks`) not wired.
  6. Windows/ConPTY unsupported; SSH/tmux only as capability hints.
  7. Lookbook goldens cover 15 flagship previews; PNG baselines cover the jackin-used subset only.

## 8. Gap analysis for a multi-agent orchestration TUI

Scope: fleet of agents on big tasks — dashboards, task graphs, logs, approvals/decision inbox, multi-pane sessions. Verdict column: **exists / partial / absent**; Home column: where the missing work belongs under the building-block law (`AGENTS.md:90-154`).

| Need | termrock today | Verdict | Home / what must change |
|---|---|---|---|
| Multi-pane layouts, split views | `layout::Workspace` (binary split tree, collapse priorities, `layout()` solver, `layout/workspace.rs:49-135`), `AppShell` slots, `WorkSurface` regions, `SplitPane`, `ResizablePanelGroup` (N panels, handles, presets, keyboard resize, drawer collapse), `panel_stack` + `ShrinkPolicy::Equal` (commit `adc2afd3`) | **exists** (geometry) / **partial** (pane management) | Missing generic: pane *tabs/stacks* inside a split leaf, pane focus-cycling helper tied to `FocusGraph` zones, persisted layout presets serialization (needs `serde` feature coverage of `WorkspaceNode`), zoom-a-pane (`FullscreenViewer` exists per widget, not per pane). These are generic → **termrock `layout`/`widgets`**. Product owns which pane shows which agent. |
| Multi-session / attach to remote agent sessions | `SessionPicker` pattern (create/resume/search), `TerminalCellGrid`/`TerminalCellSource` (paint a borrowed emulator snapshot, 0331), `BackgroundTaskPanel`, `CapabilityKind::{Ssh,Multiplexer}` hints. No PTY, no terminal emulator, no transport. | **partial** | Emulator/transport is product-owned by law (ENGINEERING: no Tokio, no process policy). Generic gap: a **`TerminalPane`** widget with scrollback/follow/selection over `TerminalCellSource` plus input forwarding outcomes (today only paint). → **termrock widget**; VT parsing/PTY/SSH → **product** (or a separate Tailrocks crate). |
| Live log streams (many agents, high frequency) | `LogPane` (owning, bounded, follow, budgeted), `LogStream` (projected window, follow/pause/unseen, severity, search, filters, bookmarks, dropped-line signals, reconnect banners), `EventStream`, `TerminalOutput`, `Transcript`, `perf::{StreamCoalescer, FollowMode, NewContentIndicator, BackpressureSignal, DirtyFlags}` | **exists** | Wire P2/P3 of `streaming-performance.md` (transcript last-block cache, LogStream follow chrome budgets). Multi-stream: "one coalescer per stream (agent id) or one global with tagged batches" is prose (`streaming-performance.md:229-233`); a **`MultiStreamCoalescer`/per-source tagging kit** is a generic gap → **termrock `perf`**. Product owns channels/threads. |
| Task graph / task tree | `Tree` (lazy children, stable IDs, virtualized, zero-alloc), `TreeTable`, `TaskRail` pattern (groups, deps, search, `ActivityModel`), `DependencyGraph` (layered layout, ASCII connectors, list/tree fallback; explicitly "does not promise arbitrary graph-layout quality"), `ProgressSteps`, `Stepper` | **partial** | DAG view for hundreds of tasks with status propagation, critical path, collapse-by-group, and live status updates is beyond `DependencyGraph`'s stated mission. Generic: extend `DependencyGraph` (status overlays, grouped/collapsed clusters, live update by id, edge kinds) or add a **`TaskGraph`** building block → **termrock**. Product owns the orchestration model → projection. |
| Timeline / history | `Timeline` (rail/detailed/grouped-day, live streaming with anchored reading position), `CheckpointTimeline` (rewind), `TraceWaterfall` (spans/latency) | **exists** | Fleet-wide Gantt-style "agents × time" swimlane is absent; `TraceWaterfall` is the nearest primitive. If needed → **termrock** (generic viz). |
| Approval / decision inbox | `ApprovalQueue` pattern (multi-type inbox; high-risk items only `Open`), `PermissionPrompt` (default-deny, provenance chain, FIFO queue, generations), `QuestionFlow`, `PlanReview`, `DiffReview`, `NotificationCenter`, `Toast` priorities; law "never starve permission overlays behind tokens" (`streaming-performance.md:233`) | **exists** as example + primitives | `ApprovalQueue` is a `patterns/` composite → product must **copy-adapt** it. Cross-agent aggregation (per-agent provenance, SLA/age sorting, batch-safe non-risky approvals) is product logic on top. No change needed in termrock unless a generic "decision item" model is wanted for reuse across jackin and the new product — then promote a neutral model type to `widgets` (allowed by checklist item 4). |
| Notifications | `Toast`, `NotificationCenter`, `ActivityShelf`, `StatusBar` `TransientStatus`, `BackgroundTaskPanel` notifications | **exists** | Persistence host-owned by design. |
| Keyboard command palette | `CommandPalette` (flagship), `Keymap` runtime remaps, `KeyboardHelp`, `JumpOverlay`, `QuickOpen`, `SlashCommandMenu` | **exists** | None. |
| Dashboards | `MetricTile`, `Sparkline`, `Chart`, `Gauge`, `Histogram`, `SegmentedMeter`, `MetricRadar`, `MetricsDashboard`/`ObservabilityDashboard`/`OpsDashboard`/`AppDashboard` patterns, `StatusStrip`, `AgentStatusHeader` | **exists** | Dashboards are patterns → copy-adapt. A fleet "agent grid" (N agent cards in a responsive grid with live status) composes `layout::Grid` + `SubagentCard`/`WorkingStateCard`; no generic gap unless a card-grid virtualizer is needed for hundreds of agents → `VirtualGrid` covers cells, not cards; a **virtualized card grid** may be a generic gap → **termrock**. |
| Agent representation | `SubagentCard`, `WorkingStateCard`, `TaskRail`, `ToolCallCard`, `TerminalRunCard`, `ContextMeter`, `TokenMeter`, `ModeRibbon`, `AgentModeSelector`, `IntegrationStatus`, `AgentWorkbench` | **exists** (single-agent-centric) | These were designed for one workbench with subagents (Grok Build/Amp class). Fleet-of-fleets (roles, hosts, containers, budgets per jackin's vision) is product projection. Generic gap candidate: **actor/provenance rail across N top-level agents** (today provenance is a chain inside one permission request). |
| High-frequency update performance | Viewport-only paint laws, zero-alloc budgets for Tree/Table, `StreamCoalescer` (8 ms min flush, priorities, backpressure), `Motion::Off ⇒ no idle redraw`, synchronized output in `run` | **exists** (kits) / **partial** (enforcement) | Wire `workbench_composite_frame` (30 frames/300 ms), `transcript_10k_blocks`, `overlay_open_close` budgets (`streaming-performance.md:176-181` "wire next"). Product must implement the "workers → mpsc → UI apply" loop itself; `runtime::run` gives `next_deadline` but no `try_recv` hook — a **channel-drain hook or `Subscription` trait in `runtime::run`** is a generic gap → **termrock `runtime`**. |
| Large-list virtualization | `Virtualizer`, `VirtualList`, `VirtualGrid`, `DataTable` (million-row projection, ≤48 rows touched budget), `Tree` window, `LogStream` windows | **exists** | None. |
| Diff viewer | `DiffView` (unified/side-by-side), `DiffReview` (file tree, hunk/line selection, comments, approve/reject outcomes; `scroll_mut` host injection, commit `29a16b5b`) | **exists** | None; streaming patch append is listed as a strategy (`streaming-performance.md:22`), verify coverage when needed. |
| Form / wizard | `Form`/`Field`/`Fieldset`, `FormWizard`, `Stepper`, `SetupWizard` + `SettingsScreen` patterns, full input family | **exists** | None. |
| Remote/collaborative presence, multi-user | None | **absent** | Product. |
| Async runtime integration | None (by law) | **absent by design** | Product owns Tokio; termrock stays sync. Acceptable, but the host-loop hook above should exist so every product does not re-implement `drive_loop`. |

**Summary of what must change in termrock for the orchestration product:** (1) pane-management layer above `Workspace` (tabbed leaves, zoom, focus zones, serializable presets); (2) `TerminalPane` widget over `TerminalCellSource` with input-forwarding outcomes; (3) multi-source stream coalescing kit; (4) `TaskGraph`/extended `DependencyGraph` for live DAGs; (5) host-loop subscription/drain hook in `runtime::run`; (6) wire the three unwired perf budgets; (7) optionally promote neutral decision-item and fleet-actor models to `widgets`. Everything else exists as widget or copy-adapt pattern.

## 9. Risks and constraints

1. **API instability is policy, not accident.** "Backward compatibility is never a design input" (`AGENTS.md:51-58`, `166-170`). 331 migration guides in ~5 months; migrations 0060–0062 alone removed root re-exports, `Theme`, `FocusRing`, `ModalStack`. Any product must budget continuous migration work and pin a SHA. Mitigation offered by termrock: sequential migration files "must let another agent migrate a pinned consumer without reconstructing intent" (`AGENTS.md:229-243`).
2. **Version/tag/changelog drift** (§1) means semver-checks compare HEAD against `v0.9.0`, and consumers cannot express "v0.14" in Cargo. Fix requires bumping `Cargo.toml` and dispatching the release workflow.
3. **Single-maintainer velocity and scale.** 256 KLOC, 1,076 stories, 92k-line API surface; clippy style/complexity lints are allowed "until the large surface is cleaned incrementally" (`Cargo.toml:47-49`). Compile-time and review load are real; `performance-baseline.md` build numbers predate the 30k-line August landing and were not re-measured.
4. **Kernel coupling.** Products must adopt `DesignSystem`, `InteractionScene`, `OverlayStack`, `FocusGraph`, `UiContext`, and `input::Event` together; the policy tests forbid parallel authorities inside termrock, and the "showcase gap protocol" expects products to do the same rather than hand-roll chrome. Partial adoption (only widgets, own focus) is possible but fights the design.
5. **Sync-only runtime, no Tokio.** Correct for a library, but each product re-implements the worker→UI bridge; the orchestration product will be the most demanding consumer of this seam.
6. **Distribution.** Git-pin only, no crates.io, registry spike offline. Cross-repo builds need network access to GitHub and `cargo-deny` `unknown-git = deny` in consumers must allow the tailrocks source.
7. **Platform.** Linux/macOS only; Windows deferred; canonical previews Linux-only; PNG determinism relies on vendored fonts + pure-Rust raster (validated cross-arch per research).
8. **Performance limits.** Debug-profile budgets are the CI floor; release benches optional (`streaming-performance.md:197`). Scene soft cap 256 elements per workbench frame; overlays rebuild placement on open/resize; transcript incremental measurement (P2) not yet done — token floods across many agents will hit the transcript/measure path first.
9. **Pattern copy-adapt drift.** Patterns are examples; once a product copies `ApprovalQueue` or `TaskRail`, it stops receiving upstream fixes unless the registry `update` path materializes.
10. **Brand default.** Phosphor is the default and "must never prevent the library from being product-neutral" (`AGENTS.md:172-175`); products that want a different look must construct their own `RolePalette` (fully constructible since migration 0007) — supported, but the 104-role palette is a large surface to theme.

## 10. Decisions the planning effort must make

Factual inputs above imply these decisions; they are listed, not resolved.

1. **Release discipline.** Bump `Cargo.toml` to match the migration ledger (0.14.0 or 1.0-pre), dispatch the release workflow so tags exist, regenerate `CHANGELOG.md`, and refresh `compatibility.toml`/README compatibility table. Without this, "which termrock" cannot be stated by any consumer.
2. **One shared pin across Tailrocks.** jackin, tablerock, holla, and the new orchestration product should resolve the same termrock commit (or tag); holla must move from `branch = "main"` to a rev. Decide whether a workspace-level `[patch]`/shared `Cargo.toml` fragment or a fleet-wide Renovate rule enforces this.
3. **Ratatui dependency posture.** Standardize consumers on `ratatui-core` + `ratatui-crossterm` (tablerock/termrock posture) or accept umbrella `ratatui 0.30` (jackin/holla) — the split matters for `Widget` trait identity and build size.
4. **Kernel adoption depth.** Decide whether products must adopt `InteractionScene` + `OverlayStack` + `UiContext` + `runtime::run` (the designed path, used by no product today) or whether the widget-only usage is an accepted tier. The orchestration product is greenfield and can be the first full-kernel consumer; jackin's `roadmap/termrock-migration` branch should target the same depth.
5. **Async seam.** Specify the host-loop contract for worker→UI delivery (drain hook / subscription trait in `runtime::run`, or a documented external loop) before the orchestration product builds its own; ENGINEERING's no-Tokio law stays.
6. **Generic gaps to land in termrock before product work** (§8): pane management above `Workspace`, `TerminalPane` over `TerminalCellSource`, multi-source stream coalescing, live `TaskGraph`/`DependencyGraph` extension, unwired perf budgets.
7. **Pattern ownership.** Decide whether `ApprovalQueue`, `TaskRail`, `SubagentCard`, `BackgroundTaskPanel`, `AgentWorkbench` are copied into the product (shadcn model, no upstream fixes) or consumed as crate types (fast fixes, product-noun coupling). termrock's law prefers copy-adapt; today no product does it.
8. **jackin dedupe.** Retire the local `TextInputState`×2, `Dialog`, `StatusBar`, and dialog families in jackin in favor of termrock widgets; this is the largest remaining divergence in the ecosystem.
9. **Windows.** Confirm the orchestration product's platform list; if Windows is required, termrock's deferred platform decision (`TODO.md:6`) becomes a prerequisite.
10. **Governance.** termrock's "breaking changes are free" policy is compatible with a fleet of AI-migrated consumers only if every consumer runs a migration cadence; decide the cadence (per termrock release, weekly) and who owns consumer migrations.
