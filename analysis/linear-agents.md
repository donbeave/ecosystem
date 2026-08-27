# Linear Agents platform and jackin roles: factual analysis

Date: 2026-08-27. Sources are cited inline. Each claim is tagged:

- **[doc]** — stated in Linear documentation or a jackin docs page.
- **[schema]** — verified in the Linear GraphQL SDL published in `linear/linear` (`packages/sdk/src/schema.graphql`, fetched 2026-08-27 from https://raw.githubusercontent.com/linear/linear/master/packages/sdk/src/schema.graphql; 51,004 lines).
- **[code]** — verified in jackin source at `/Users/donbeave/Projects/tailrocks/jackin-project/jackin` or the role repo at `/Users/donbeave/Projects/tailrocks/jackin-project/jackin-the-architect`.
- **[proposal]** — our recommendation, not a fact.

Where documentation and schema disagree or one is silent, that is called out.

---

## Part A — Linear Agents platform

### A1. What a Linear agent app is and how it is created

An agent is an OAuth application installed into a workspace as an **app user** ("Agents behave similar to other users in a workspace. They can be @mentioned, delegated issues through assignment, create and reply to comments, collaborate on projects and documents") [doc: https://linear.app/developers/agents].

Creation steps [doc: https://linear.app/developers/agents, https://linear.app/developers/oauth-2-0-authentication]:

1. Create an OAuth2 application at https://linear.app/settings/api/applications/new. Linear recommends a dedicated workspace to own the app because every admin of the owning workspace can manage it.
2. In the app settings enable webhooks and tick the "Agent session events" category.
3. Authorize with `actor=app` in the authorization URL. `actor=app` means "Resources are created as the application. This option should be used for agents and service accounts." The default `actor=user` creates resources as the authorizing human and does not make an agent.
4. Request scopes. Agent-specific scopes: `app:assignable` ("Allow the app to be assigned as a delegate on issues and made a member of projects") and `app:mentionable` ("Allow the app to be mentioned in issues, documents, and other editor surfaces"). General scopes still apply: `read`, `write`, `issues:create`, `comments:create`, `admin`, plus `customer:*`, `initiative:*`. The schema confirms the assignable gate: `User.canBeAssigned` says "app users are assignable only if they have the app:assignable scope" [schema: schema.graphql line ~47631].
5. Installation is per workspace: the authorizing user must be a workspace admin, and the app receives "a unique ID for each workspace it is installed within", discoverable via `query Me { viewer { id } }` executed with that workspace's token [doc: https://linear.app/developers/agents]. Admins pick which teams get access during install [doc: https://linear.app/docs/agents-in-linear].

Design rationale from Linear's own post: "Issues can only be assigned to humans, and only delegated to agents", so a human assignee always remains accountable; the human assignee and the delegated agent appear side by side [doc: https://linear.app/now/our-approach-to-building-the-agent-interaction-sdk]. In the API this is the separate `Issue.delegate: User` field alongside `Issue.assignee: User`, and `IssueUpdateInput.delegateId` ("The identifier of the agent user to delegate the issue to") [schema].

Reference sample: https://github.com/linear/weather-bot (Cloudflare Worker; `GET /oauth/authorize`, `GET /oauth/callback` storing the `actor=app` token in KV; `POST /webhook` handling `created` and `prompted`) [doc].

### A2. Trigger model and payloads

**Triggers.** A session is created automatically when (a) a user delegates an issue to the agent (assignment UI), (b) a user @mentions the agent in an issue/document/comment, or (c) the agent itself calls `agentSessionCreateOnIssue` / `agentSessionCreateOnComment` [doc: https://linear.app/developers/agent-interaction; schema: mutations at lines 22793/22802]. Templates and automation rules can also pre-set the "delegated agent" property, so a rule can delegate as part of triage [doc: https://linear.app/docs/issue-templates, https://linear.app/docs/assigning-issues].

**Webhook event.** The agent receives `AgentSessionEvent` webhooks with `action` ∈ {`created`, `prompted`} [doc: agent-interaction]. Verified payload type `AgentSessionEventWebhookPayload` [schema lines 974–1020]:

| Field | Type | Notes |
|---|---|---|
| `action` | String! | `created` or `prompted` |
| `type` | String! | `AgentSessionEvent` |
| `agentSession` | `AgentSessionWebhookPayload!` | see below |
| `agentActivity` | `AgentActivityWebhookPayload` | the user's prompt for `prompted` |
| `previousComments` | `[CommentChildWebhookPayload!]` | only for `created` from a mention inside a comment thread |
| `guidance` | `[GuidanceRuleWebhookPayload!]` | workspace/team agent guidance; "nearest team-specific guidance should take highest precedence" |
| `promptContext` | String | "A formatted prompt string containing the relevant context for the agent session, including issue details, comments, and guidance. Present only for `created` events." Docs describe it as structured XML. |
| `appUserId`, `oauthClientId`, `organizationId`, `webhookId`, `webhookTimestamp`, `createdAt` | | routing/identity |

`AgentSessionWebhookPayload` fields [schema]: `id`, `status` (String), `type`, `appUserId`, `creatorId`/`creator` (null when created by automation), `issueId`/`issue` (**`IssueWithDescriptionChildWebhookPayload`**: only `id`, `identifier`, `title`, `description`, `url`, `team`, `teamId`), `commentId`/`comment`, `sourceCommentId`, `sourceMetadata`, `startedAt`, `endedAt`, `summary`, `organizationId`, `url`.

`AgentActivityWebhookPayload` fields [schema]: `id`, `agentSessionId`, `content: JSONObject!` (the `{type, body, ...}` object), `signal` (String; `stop` when the user pressed Stop), `signalMetadata`, `sourceCommentId`, `userId`/`user`.

**What the session webhook does NOT carry** [schema]: labels, project, state, assignee, attachments, relations, sub-issues, comments other than `previousComments`. The daemon must fetch those over GraphQL using `agentSession.issueId`. `promptContext` is a convenience blob for LLM prompting, not a structured source.

**Ordinary data-change webhooks.** Separately, if the app's webhook subscribes to Issue/Comment categories, `Issue` `update` events fire with a full `IssueWebhookPayload` including `delegateId`, `delegate`, `assigneeId`, `labelIds`, `labels[]`, `stateId`/`state`, `project`, `parentId`, `description`, `descriptionData`, `lastAppliedTemplateId`, `url`, plus `updatedFrom` on updates [schema: IssueWebhookPayload; doc: https://linear.app/developers/webhooks]. So "issue assigned to agent" is visible twice: once as `AgentSessionEvent created` (authoritative for sessions) and once as `Issue update` with `updatedFrom.delegateId` (useful for state sync but not required).

### A3. Agent session lifecycle

**States** [schema enum `AgentSessionStatus`]: `pending`, `active`, `awaitingInput`, `error`, `complete`, `stale`. Docs: "You don't need to manage agent session state manually. Linear tracks session lifecycle automatically based on the last emitted activity" [doc: agent-interaction]. Mapping from activities (documented): `thought`/`action` → `active`; `elicitation` → `awaitingInput`; `response` → `complete`; `error` → `error`; no activity for 30 minutes → `stale` ("Activities can be sent for up to 30 minutes before the session becomes stale (recoverable by sending new activities)") [doc: https://linear.app/developers/agent-best-practices]. `stale` is not a terminal state.

**Timing constraints** [doc: agent-interaction, agent-best-practices]:

- Webhook receiver must return HTTP 200 within **5 seconds**.
- After `created`, the agent must emit an activity **or** update `externalUrls` within **10 seconds** or the session is marked unresponsive. Recommended: a `thought` acknowledging the session.
- 30-minute inactivity → `stale`.

**Activity content types** [schema enum `AgentActivityType` and content union]:

| type | Agent may create | Fields | Purpose |
|---|---|---|---|
| `thought` | yes | `body` (Markdown) | reasoning / acknowledgement; supports `ephemeral` |
| `action` | yes | `action`, `parameter`, `result` (Markdown, optional) | tool call; supports `ephemeral` |
| `elicitation` | yes | `body` | ask the human; moves session to `awaitingInput`; may carry `signal: select` with `signalMetadata.options[{label,value}]` or `signal: auth` with `{url, userId?, providerName?}` |
| `response` | yes | `body` | final answer; completes session |
| `error` | yes | `body`, `reasonCode` (schema-only; docs do not describe values) | failure; sets `error` |
| `prompt` | **no** (user only) | `body`, `title` | human message; arrives via `prompted` webhook; may carry `signal: stop` |

`AgentActivitySignal` enum is `auth`, `continue`, `select`, `stop` [schema line 596]. Docs describe `auth`, `select`, `stop`; `continue` is present in the schema but undocumented on https://linear.app/developers/agent-signals [doc vs schema gap].

**Creating activities** [doc: agent-interaction; schema `AgentActivityCreateInput`]:

```graphql
mutation AgentActivityCreate($input: AgentActivityCreateInput!) {
  agentActivityCreate(input: $input) { success agentActivity { id } }
}
```

`AgentActivityCreateInput` = `{ agentSessionId: String!, content: JSONObject!, contextualMetadata: JSONObject, ephemeral: Boolean, id: String, signal: AgentActivitySignal, signalMetadata: JSONObject }`. `content` shape is validated server-side; `ephemeral` is accepted only for `thought`/`action`. The optional client-supplied `id` allows idempotent retries [schema].

**Elicitation round-trip.** Agent emits `elicitation` (optionally `signal: select`). The human replies in the session UI; Linear fires `AgentSessionEvent` with `action: "prompted"` and the reply in `agentActivity.content.body` (for `select`, the chosen value arrives as a regular `prompt` activity; free-text reply dismisses the select) [doc: agent-interaction, agent-signals]. Docs recommend reconstructing history from `agentSession.activities` rather than comments because "Comments may not be reliable to read from, as they are editable" [doc: agent-best-practices].

**Stop.** A user Stop produces a `prompt` activity with `signal: stop` delivered as a `prompted` event; the agent must "halt work immediately" and emit a final `response` or `error` [doc: agent-signals]. Dismissal: `AgentSession.dismissedAt` — "When dismissed, the agent is removed as delegate from the associated issue" [schema].

**Session-level plan** ("Agent Plans") [doc: agent-interaction; schema `AgentSessionUpdateInput.plan: JSONObject`, `AgentSession.plan: JSON`]: an ordered list `[{content, status}]` with `status` ∈ `pending | inProgress | completed | canceled`; updated via `agentSessionUpdate(id, input: {plan})`; "agents must replace the existing plan in its entirety". This is the native checklist for agent progress and renders in the session UI.

**External URLs** [doc; schema]: `agentSessionUpdate` accepts `externalUrls: [{label, url}]` (replace), `addedExternalUrls`, `removedExternalUrls`; `externalLink` is deprecated. GitHub PR URLs get special treatment. Setting a URL within 10 s also satisfies the acknowledgement deadline.

**Repository suggestions** [schema `Query.issueRepositorySuggestions`, doc]: ranked repo candidates for an issue, meant for coding agents that need a target repo.

**Multiple sessions.** `Issue.agentSessions` and `Comment.agentSessions`/`spawnedAgentSessions` are connections [schema]; nothing prevents several sessions per issue (one per mention/delegation). Docs are silent on concurrency limits per issue.

### A4. Reading the issue

Fields verified on `type Issue` [schema]: `id`, `identifier`, `title`, `description: String` (Markdown, derived), `descriptionState: String` (Yjs base64 — canonical), `documentContent`, `assignee`, `delegate`, `state: WorkflowState!` (`name`, `type`, `position`), `team`, `project`, `projectMilestone`, `labels` (connection; `IssueLabel` has `name`, `parent`, `isGroup`, `team`), `labelIds`, `parent`, `children`, `relations`, `inverseRelations`, `attachments(filter)`, `documents`, `comments`, `agentSessions`, `lastAppliedTemplate: Template`, `branchName`, `url`, `priority`, `estimate`, `dueDate`, `cycle`, `history`.

- **Description**: `Issue.description` is Markdown. There is no `Issue.descriptionData` on the object type (it exists only on `IssueUpdateInput` and the webhook payload) [schema].
- **Checklists**: no `checklist` field or type exists anywhere in the schema (grep for `checklist` returns nothing) [schema]. Task lists typed as `- [ ]` become native editor checkbox nodes and are serialised back into `description` Markdown as `- [ ]` / `- [x]` [doc: https://linear.app/docs/creating-issues; behaviour of Markdown round-trip is documented, exact serialisation format is not — treat as needs a smoke test]. Linear can convert a checklist to sub-issues (Cmd/Ctrl+Shift+O) but the result is issues, not a structured checklist [doc]. Conclusion: **checklists are Markdown only**; structured progress lives in `AgentSession.plan` or sub-issues.
- **Sub-issues**: `Issue.children` (connection), `Issue.parent`, `IssueUpdateInput.parentId` [schema]. Templates can predefine sub-issues [doc: issue-templates].
- **Blocking**: `IssueRelation { issue, relatedIssue, type }` with `IssueRelationType` = `blocks | duplicate | related | similar`. "Blocked by X" is read from `inverseRelations` where `type == "blocks"` (X blocks me) [schema]. There is no `blockedBy` field.
- **Attachments**: `Attachment { url, title, subtitle, metadata: JSONObject!, source, sourceType, bodyData }` — these are external links (PRs, Slack, etc.). Images/files pasted into the description are Markdown links to `https://uploads.linear.app/...` inside `description`; fetching them requires the same bearer token [doc: https://linear.app/developers/how-to-upload-a-file-to-linear — upload flow documented; download auth behaviour not explicitly documented, verify]. `Issue.documents` lists linked Documents whose `content` is Markdown [schema `DocumentContent.content`].
- **Templates**: `Template { name, type, templateData: JSON!, hasFormFields, team }`; `Issue.lastAppliedTemplate` links back [schema]. `templateData` is an undocumented JSON blob.
- **Custom fields / properties**: none. No `CustomField`, `IssueProperty`, or `CustomProperty` type exists [schema grep]. 2026 changelog added "initiative properties" (statuses/priority/labels on initiatives) [doc: https://linear.app/changelog/2026-07-02-initiative-properties], not free-form fields on issues.
- **Template form fields** [doc: https://linear.app/docs/issue-templates]: generic fields (text, long text, dropdown, checkboxes, date, instructional text) are written into the **description**; property fields (customer, label group, priority, title, due date) map to real issue properties. There is no API to read a form answer structurally except via the property it mapped to.
- **Agent guidance**: Markdown rules at Settings › Agents › Additional guidance (workspace) and team settings › Agents (team); team wins [doc: agents-in-linear]. Delivered in `guidance[]` and inside `promptContext` [schema].

**Rate limits** [doc: https://linear.app/developers/rate-limiting]: OAuth app tokens 5,000 requests/hour per app user, complexity budget 2,000,000 points/hour, single query cap 10,000 points; API keys 2,500 req/h and 3,000,000 points. Headers: `X-RateLimit-Requests-Remaining`, `X-RateLimit-Requests-Reset`, `X-Complexity`, `X-RateLimit-Complexity-Remaining`, `X-RateLimit-Complexity-Reset`. Payload/request-size limits are not documented.

### A5. Writing back

Mutations verified [schema]: `issueUpdate(id, input: IssueUpdateInput)` with `description`, `descriptionData`, `stateId`, `delegateId`, `assigneeId`, `labelIds`/`addedLabelIds`/`removedLabelIds`, `parentId`, `projectId`, `priority`, `estimate`, `title`; `commentCreate`; `attachmentCreate`; `issueRelationCreate`; `agentSessionUpdate` (plan, externalUrls); `agentActivityCreate`.

Linear's recommendations [doc: agent-best-practices]:

- On delegation, if the issue is not already in a `started`/`completed`/`canceled` state, move it to the **first `started` state** ("query workflow states with `type: { eq: "started" }` and select the lowest position"). `WorkflowState.type` values are strings such as `triage`, `backlog`, `unstarted`, `started`, `completed`, `canceled` [schema; doc].
- If the issue has no `delegate` and the agent is implementing, set itself as delegate. If an automation delegated it while in triage, leave triage and human assignment alone.
- Progress goes into activities (`action` with `result`), not comments. Completion = `response`; blockers = `elicitation` or `error`.
- Nothing in the docs forbids editing the description or changing state; the app needs `write` scope. Marking done = `issueUpdate(stateId: <completed state>)` — the docs do not say Linear does it automatically on `response` (it does not; `response` only completes the **session**).
- Agent identity is always shown as an agent; comments created with an `actor=app` token appear as the app user [doc: our-approach post].

What an agent cannot do: sign in, use admin functions, manage users [doc: agents-in-linear]; create `prompt` activities [doc]; update `plan`/`externalUrls` of a session owned by another OAuth app ("Only updatable by the OAuth application that owns the session") [schema].

### A6. Issue templates as a carrier for role / runtime / prompt

Options, ranked by what Linear can express structurally:

1. **Labels** — structured, filterable (`IssueFilter.labels.some.name`), visible on the card, settable by templates and rules. Label groups (`IssueLabel.isGroup`, `parent`) give mutually exclusive values (one child per group per issue) [schema; doc: https://linear.app/docs/labels]. Best fit for `role` and `agent`.
2. **Template property fields** — map to labels/priority/customer only; no free text property [doc].
3. **Description conventions** — fenced block or front-matter; Linear preserves fenced code blocks in Markdown [doc: creating-issues]. Free-form, not filterable, editable by anyone.
4. **Sub-issues** — structured task list with their own state; heavier and creates one session per delegation.
5. **`templateData` / `lastAppliedTemplate`** — readable but undocumented JSON; brittle.
6. **Agent guidance** — Markdown per team/workspace; good for standing instructions (coding conventions), not per-issue.

There is no custom-field mechanism, so "role", "runtime", "prompt" cannot be first-class properties. Recommendation is in Part C.

### A7. Webhook delivery vs polling

Webhooks [doc: https://linear.app/developers/webhooks]:

- Endpoint must be a "Publicly accessible HTTPS, non-localhost URL", respond 200 within 5 s.
- Headers: `Linear-Delivery` (UUID), `Linear-Event`, `Linear-Signature` (HMAC-SHA256 hex of the raw body with the signing secret), `Linear-Timestamp` (ms). Verify with constant-time compare and reject timestamps older than ~1 minute.
- Retries: 3 attempts with 1 min, 1 h, 6 h backoff; repeated failures auto-disable the webhook.
- Source IPs are published (35.231.147.226 … 34.60.255.158).
- For OAuth apps the webhook is configured once on the app; a webhook is created automatically for every workspace that installs it. `OAuthApp revoked` event carries `oauthClientId`, `organizationId`.

Polling: the docs say nothing about polling and there is no long-poll or WebSocket API [doc]. But it is possible over GraphQL [schema]:

- `Query.agentSessions(first, after, orderBy: createdAt|updatedAt, includeArchived)` — **no filter argument**; you page through all sessions of the app user and diff on `status == "pending"` / `updatedAt`. Executed with the app's token, results are scoped to that app user in that workspace (documented behaviour of viewer scoping; not explicitly documented for this query).
- `Query.issues(filter: { delegate: { id: { eq: <appUserId> } }, state: { type: { nin: [...] } }, updatedAt: { gt: ... } })` — `IssueFilter.delegate: NullableUserFilter` exists [schema].
- `AgentSession.activities(filter: AgentActivityFilter)` for new `prompt` activities on active sessions.

Consequences for a daemon behind NAT: the 10-second acknowledgement is measured from the webhook, so pure polling at, say, 5-second intervals is acceptable in principle but will occasionally miss the 10-second window; each poll is one request against the 5,000/h budget (a 5 s poll ≈ 720 req/h per workspace). A relay (Hookdeck/Cloudflare Worker/`smee`-style) that receives the webhook publicly and queues it for the daemon is the documented-compatible path; Hookdeck publishes a specific Linear-agents guide [doc: https://hookdeck.com/webhooks/platforms/how-to-build-linear-agents-with-hookdeck-cli].

### A8. Auth model for a self-hosted daemon

[doc: https://linear.app/developers/oauth-2-0-authentication]

- Standard OAuth2 authorization-code flow with `actor=app`, optional PKCE (`code_challenge_method=S256`).
- Access tokens: 24 hours (86,399 s). Refresh tokens issued; "OAuth2 applications were migrated to the new refresh token system on April 1, 2026"; refresh grant with basic auth or body params; 30-minute grace for refresh-token replay.
- Client-credentials tokens (app acting without a user) last 30 days; up to 1,000 parallel tokens; rotating the client secret invalidates them. Team access for the app user is configured on the app details page.
- Revocation endpoint exists.
- One token per workspace installation; the daemon must key its token store by `organizationId` (present in every webhook payload) and refresh before expiry.
- Secrets to hold: `client_id`, `client_secret`, webhook signing secret, and per-workspace `{access_token, refresh_token, expires_at, app_user_id}`. jackin already resolves `op://VAULT/ITEM/FIELD` references through `op read` at launch with a 120 s timeout and never persists resolved values [doc: jackin `docs/content/(public)/guides/environment-variables.mdx` lines 45–173]. The refresh token rotates, so it must be written back to 1Password (jackin already does 1Password writes for Claude tokens [doc: `docs/content/roadmap/(agent-runtimes-authentication)/onepassword-integration.mdx`]).

### A9. Limits summary

| Limit | Value | Source |
|---|---|---|
| Webhook response | 200 within 5 s | doc webhooks / agent-interaction |
| First activity after `created` | 10 s | doc agents / agent-interaction |
| Inactivity → `stale` | 30 min, recoverable | doc agent-best-practices |
| Webhook retries | 3 (1 m, 1 h, 6 h) | doc webhooks |
| Requests | 5,000/h per app user (OAuth) | doc rate-limiting |
| Complexity | 2,000,000 pts/h; 10,000 per query | doc rate-limiting |
| Access token TTL | 24 h; client-credentials 30 d | doc oauth |
| Payload size | not documented | — |
| Concurrent sessions | not documented; schema allows many per issue | schema |
| Linear MCP | `https://mcp.linear.app/mcp` (OAuth 2.1, dynamic client registration); tools for issues/projects/comments; no documented agent-session tools | doc https://linear.app/docs/mcp |

Changelog context: Linear Agent (Linear's own coding agent) launched 2026-03-24, MCP 2026-04, and "coding sessions" via Claude Code / Codex on 2026-06-11 for Basic/Business/Enterprise; this is Linear's hosted competitor to what the daemon does, and uses the same session/activity primitives [doc: https://linear.app/changelog/2026-06-11-coding-sessions, https://linear.app/changelog/2026-03-24-introducing-linear-agent].

---

## Part B — jackin agent roles

### B1. Role anatomy

A role is a GitHub repository `jackin-<name>` (or `<org>/jackin-<name>`) containing a Dockerfile and `jackin.role.toml` [doc: `docs/content/(public)/(role-authoring)/guides/role-repos.mdx`].

**Dockerfile contract** [code: `crates/jackin-manifest/src/repo_contract.rs` `validate_agent_dockerfile`]: the final `FROM` must be `projectjackin/construct:<ver>-trixie` (digest pin allowed, floating `:trixie` rejected, `--platform` rejected). Published images carry OCI labels `jackin.construct.version` and `jackin.role.git.sha`. The-architect's Dockerfile pins `projectjackin/construct:0.36-trixie@sha256:…`, installs the Rust/mise toolchain, caveman, skills, headroom, rtk, and generates `/home/agent/AGENTS.md` + `CLAUDE.md` symlinked into each runtime's config dir [code: `jackin-the-architect/Dockerfile`].

**`jackin.role.toml` fields** [code: `crates/jackin-core/src/manifest.rs` `RoleManifest`, `#[serde(deny_unknown_fields)]`; doc: `docs/content/(public)/(role-authoring)/developing/role-manifest.mdx`]:

| Field | Meaning |
|---|---|
| `version` | schema version (`v1alpha5` in the-architect; `v1alpha6` adds `[docker]`); feature gates enforced in `validate_feature_versions` [code: `crates/jackin-manifest/src/manifest.rs`] |
| `dockerfile` | repo-relative Dockerfile path |
| `published_image` | pre-built image; console pulls it and layers only the agent install on top |
| `agents` | list of supported runtimes: `claude`, `codex`, `amp`, `kimi`, `opencode`, `grok`; omitted ⇒ Claude-only; empty ⇒ error; each listed agent needs a `[<agent>]` table (orphan tables warn) [code: `crates/jackin-manifest/src/validate.rs`] |
| `[identity].name` | display name |
| `[claude]` | `model` (→ `claude --model`), `plugins[]` (`plugin@marketplace`), `[[claude.marketplaces]]` (`source`, `sparse[]`), `[claude.providers.<id>].model` |
| `[codex]` | `model` (→ `codex -m`), `providers` |
| `[amp]` | empty table |
| `[kimi]` | `model` (→ `kimi --model`) |
| `[opencode]` | `model` (`provider/model` → `opencode -m`), `providers` |
| `[grok]` | `model` (→ `grok -m`) |
| `[hooks]` | `setup_once`, `source`, `preflight` — repo-relative scripts run by the entrypoint in that order [code: `HooksConfig::entries`] |
| `[env.<NAME>]` | `default`, `interactive`, `skippable`, `prompt`, `options[]`, `depends_on[]`; non-interactive vars must have a default; `${env.X}` interpolation |
| `[docker]` | `min_profile`, `dind` (`none|rootless|privileged`), `allowed_hosts[]`, `capabilities_add[]` |

There is **no** `secrets`, `mounts`, `prompt`, `goal`, `launch_args`, or `skills` field in the manifest [code: `RoleManifest` struct; confirmed by roadmap `docs/content/roadmap/(agent-runtimes-authentication)/agent-launch-flags-api.mdx`: "No launch-argument override exists anywhere in the manifest"]. Skills are installed by the Dockerfile (`skills add …`) and plugins by jackin from `[claude].plugins`. Mounts are operator/workspace config (`--mount`, workspace `mounts`, global named mounts scoped `namespace/*` or role key) [code: `crates/jackin-config/src/resolve.rs` `resolve_load_workspace`; `crates/jackin-config/src/schema.rs`]. Secrets are operator env (`jackin config env set KEY "op://…" --role <role>`), resolved at launch [doc: environment-variables.mdx].

The-architect manifest specifics [code: `jackin-the-architect/jackin.role.toml`]: `agents = ["claude","codex","amp","opencode","kimi","grok"]`, `[claude].model = "claude-sonnet-4-6"`, 12 plugins, three marketplaces, provider overrides for `zai`/`minimax`/`kimi`, `hooks.preflight = "hooks/preflight.sh"`, env defaults for `CLAUDE_CODE_NO_FLICKER`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, `CONTEXT7_API_KEY`, `CAVEMAN_DEFAULT_MODE`.

### B2. How a role is loaded and how the runtime is selected

`jackin load [SELECTOR] [TARGET] [--agent A] [--mount …] [--rebuild] [--role-branch B] [--docker-profile P] [--dry-run --format json] [--force]` [code: `crates/jackin/src/cli/role.rs` `LoadArgs`].

Runtime selection [code: `crates/jackin-runtime/src/runtime/launch/launch_pipeline.rs` `select_launch_agent`]: precedence is `--agent` → workspace `default_agent` → restored instance's agent → if the manifest lists exactly one agent, that one → otherwise an interactive "Choose launch agent" dialog; with no rich progress surface it fails with "role … supports multiple agents … load requires the rich launch dialog for agent selection, or pass --agent / set workspace `default_agent`". A role **restricts** runtimes via `agents` (validate rejects tables for unlisted agents and `--agent` outside the list fails at launch [code: `validate.rs`; `crates/jackin/tests/agent_validation.rs`]) but cannot rank or prefer one.

Hard constraint for a daemon: `jackin load` refuses to run without a rich terminal — "jackin load requires a rich terminal: stdin/stdout/stderr must be TTYs, TERM must not be dumb, CI must be unset, and the terminal must be at least 80x24" [code: `crates/jackin-launch/src/tui/terminal.rs` line 20; doc: load.mdx]. `--dry-run` also goes through this surface. There is no headless launch API today; the roadmap says the launch pipeline would be "reused programmatically" by a future queue [doc: `docs/content/roadmap/(agent-orchestration)/(fleet-automation)/autonomous-task-queue.mdx`].

Role-branch loads always require an interactive trust dialog [doc: load.mdx].

### B3. How an initial prompt / goal is delivered today

**It is not.** Verified chain:

1. Host side builds the container command with `build_agent_command(agent, model, auth_mode, env, cwd, codename)`; the only argv it appends are model flags from `agent_model_args` (`--model` for claude/kimi, `-m` for codex/opencode/grok) plus env `JACKIN_AGENT`, `JACKIN_AGENT_CODENAME`, auth mode [code: `crates/jackin-capsule/src/session.rs` lines 1621–1658].
2. In-container `docker/runtime/entrypoint.sh` builds `LAUNCH=(claude --settings '{"skipDangerousModePermissionPrompt":true}' --dangerously-skip-permissions --verbose)`, optionally `--system-prompt "$JACKIN_EXEC_SYSTEM_PROMPT"` (only when `JACKIN_EXEC_BINDINGS` is set, and only for the jackin-exec credential instructions), then appends `"$@"` (the model args), runs hooks, and `exec "${LAUNCH[@]}"` [code: `docker/runtime/entrypoint.sh` lines 59–102, 187]. Codex: `codex --enable goals --dangerously-bypass-approvals-and-sandbox [--profile …] "$@"`. Amp: `amp --dangerously-allow-all` (no `$@`). Kimi: `kimi --yolo "$@"`. OpenCode: `opencode "$@"`. Grok: `grok --always-approve "$@"`.
3. The agent then runs interactively on a PTY owned by the Capsule; input arrives only from an attached terminal [code: `crates/jackin-capsule/src/session.rs` line ~1258 comment "goes back to the agent's own PTY stdin"].
4. No CLI flag, env var, file, or stdin mechanism carries a goal. Grep for `goal`, `initial_prompt`, `--prompt`, `headless`, `--print` across `crates/` finds nothing launch-related [code grep]. `crates/jackin/src/prompt.rs` is operator y/n prompting, unrelated. `codex --enable goals` enables Codex's own goals feature but no goal text is passed.
5. Roadmap confirms: `AgentRuntime` trait "has no launch-argv method yet"; "First-prompt templating through task-source handlers" is item 4 of the autonomous task queue; "Webhook-driven dispatch" and "Background daemon mode independent of console/runtime supervision" are explicitly out of scope of that item [doc: agent-launch-flags-api.mdx; autonomous-task-queue.mdx].

The only writable channel that reaches the agent unmodified is the environment (`[env.*]` + operator env) and the mounted workspace (a file). Hooks (`preflight.sh`) run before exec and can read env and write files but cannot alter argv except through `source.sh` mutating the entrypoint shell (which could, in principle, `set -- …` but nothing does today).

### B4. Role identifiers

`RoleSelector { namespace: Option<String>, name }` parsed from `name` or `namespace/name`, lowercased, GitHub-style case-insensitive; key is `name` or `namespace/name`; runtime slug is `namespace_name` [code: `crates/jackin-core/src/selector.rs`]. Resolution: `the-architect` → repo `jackin-the-architect` in the default org; `chainargos/the-architect` → `github.com/chainargos/jackin-the-architect` [doc: role-repos.mdx]. `jackin-project/sentinel` would resolve to `github.com/jackin-project/jackin-sentinel`. Repos are cached and their `origin` must still match the configured source or load errors; namespaced roles need trust (`jackin config trust grant org/name`) before first build [doc: load.mdx].

Workspaces can restrict roles with `allowed_roles` [code: `resolve.rs` `resolve_load_workspace`]. The image is either `published_image` from the manifest or a derived build; `jackin role published-image .` prints it [code: `cli/role.rs` `RoleCommand::PublishedImage`].

For a daemon, mapping "role string from Linear" → image is therefore: parse with `RoleSelector::parse`, check `allowed_roles` and trust config, run the existing launch pipeline (which resolves repo → manifest → image). No separate registry is required; the selector **is** the identifier.

### B5. Gap list for unattended "issue assigned → spawn role R with runtime A and prompt P"

1. **Headless launch.** `jackin load` demands a TTY ≥80×24 and interactive dialogs for agent choice, trust, env prompts, dirty-tree acknowledgement [code: `jackin-launch/src/tui/terminal.rs`; `select_launch_agent`]. Need a programmatic `LoadOptions` entry point with all decisions pre-supplied (agent, trust already granted, env values, `--force`).
2. **Prompt delivery.** No manifest field or launch mechanism for an initial prompt [code: `entrypoint.sh`, `build_agent_command`]. Minimal options: (a) env `JACKIN_INITIAL_PROMPT` consumed by the entrypoint as `claude "$PROMPT"` / `codex "$PROMPT"` positional argument; (b) a file mounted at a known path plus a system-prompt line pointing to it; (c) a `[prompt]` manifest table. Any of these is a schema bump (v1alpha7) per the launch-flags roadmap.
3. **Non-interactive agent mode.** Even with a prompt, Claude/Codex run their interactive TUI on the PTY. The daemon must decide between interactive-on-PTY (operator can `hardline` in) and print/exec modes (`claude -p`, `codex exec`). The Capsule status machine already tracks `blocked`/`done` transitions and the host daemon consumes attention snapshots [doc: daemon.mdx], which is the natural source for `awaitingInput` and `complete`.
4. **Runtime restriction/preference.** `agents` restricts; nothing expresses a default per role. Either use workspace `default_agent` or add `default_agent` to the manifest.
5. **Completion and output channel.** No structured outcome marker exists; roadmap item 5 ("completion classification … `completed`, `failed`, `needs_review`") is open [doc: autonomous-task-queue.mdx]. The daemon needs a way for the agent to report checklist progress — simplest is the agent calling Linear itself via the Linear MCP (`https://mcp.linear.app/mcp`) or a `linear` CLI bound through `jackin-exec`, with the daemon owning session/activity lifecycle.
6. **Credentials in-container.** Linear token must reach the agent (if it writes back) without leaking: `jackin-exec` bindings exist for exactly this [code: `entrypoint.sh` `JACKIN_EXEC_BINDINGS`; doc: `docs/content/research/platform/security/credential-exposure/jackin-exec-design.mdx`].
7. **Task source.** No `TaskSource` trait, queue, or storage [doc: task-source-abstraction.mdx]. A Linear source would be the third implementation after `github_issues` and `file_glob`.
8. **Workspace mapping.** Linear issue → jackin workspace (repo) is not derivable from the role; needs config (`team`/`project` → workspace) or Linear's `issueRepositorySuggestions` [schema].

---

## Part C — Proposed mapping [proposal]

### C1. Where role, runtime, prompt come from

| Input | Source in Linear | Fallback | Rationale |
|---|---|---|---|
| Role | label in label group **`role`** (children: `role:the-architect`, `role:jackin-project/sentinel` — display name is the selector; group enforces one value) | team-level default in daemon config | filterable, template-settable, rule-settable, visible on card; parsed by `RoleSelector::parse` |
| Runtime | label group **`agent`** (`agent:claude`, `agent:codex`, …) | workspace `default_agent`, else role's single agent, else daemon default `claude` | must be in manifest `agents`; if not, emit `error` activity with `reasonCode: "unsupported_agent"` |
| Model/provider | optional label group **`model`** | manifest `[agent].model` | keeps manifest authoritative |
| Workspace | daemon config map `team.key`/`project.id` → jackin workspace name; override via `issueRepositorySuggestions` when confidence is high | `error` activity asking for mapping | Linear has no repo field |
| Prompt | issue `description` Markdown, verbatim, preceded by a daemon-generated header (`identifier`, `title`, `url`, labels, blockers, parent) and followed by `guidance[]` | `promptContext` from the `created` payload as a whole | `promptContext` is already LLM-shaped but undocumented in structure; description is stable |
| Task list | the first `- [ ]` task list in the description | none (single-step run) | Markdown only; mirrored into `agentSession.plan` |
| Standing instructions | Linear agent guidance (team > workspace) | none | delivered in every `created` payload |

Explicitly rejected: front-matter or a fenced `jackin` block in the description as the primary carrier. It is invisible on the board, not filterable, and users editing descriptions break it. A fenced ```` ```jackin ```` block may be an optional **override** for advanced fields (`mounts`, `env`), parsed only if present.

### C2. Session and activity flow

```
Linear                          daemon                               jackin
------                          ------                               ------
delegate issue → AgentSession   webhook/relay or poll (≤5 s)
  status: pending           →   verify HMAC + timestamp
                            →   agentActivityCreate thought
                                "Acknowledged; resolving role…"      (≤10 s)
                            →   fetch issue: labels, description,
                                inverseRelations(blocks), children,
                                state, project, team
                            →   if blocked-by open issue:
                                elicitation "Blocked by X; proceed?"  → awaitingInput
                            →   move issue to first `started` state
                            →   agentSessionUpdate plan=[pending…]
                            →   agentSessionUpdate externalUrls
                                [{label:"jackin instance", url:…}]
                            →   spawn role R / runtime A / prompt P   → container
  status: active            ←   action "launch" result=instance id
per checklist item:         ←   Capsule status + agent progress file
                            →   action "task" parameter=item text
                                result=summary; plan[i]=completed
                            →   issueUpdate description: tick `- [x]`
agent needs decision        ←   Capsule `blocked` transition
                            →   elicitation (signal select if enum)   → awaitingInput
user replies (prompted)     →   forward body to agent PTY/stdin       → active
user Stop (signal stop)     →   stop container; error/response        → complete/error
agent exits 0               →   response "Done: …" + link to PR
                            →   issueUpdate stateId=completed?  (policy: only if all
                                checklist items ticked and `auto-complete` label set)
agent exits ≠0 / stale      →   error body + reasonCode
```

Timing guard: the acknowledgement `thought` is emitted before any GraphQL read. Heartbeat: an ephemeral `thought` every ≤20 minutes while the container runs, to stay under the 30-minute stale threshold.

### C3. Write-back cadence

- **Per completed checklist item**: `agentSessionUpdate` with the full plan (Linear requires full replacement) and `issueUpdate(description)` with the `- [ ]` → `- [x]` edit applied to the original Markdown (read-modify-write on `description`; abort if `updatedAt` changed since read to avoid clobbering human edits — Linear has no optimistic-concurrency field on `issueUpdate`, so compare `updatedAt` manually).
- **Per action of note** (branch created, PR opened, tests run): `action` activity; PR URL also added via `addedExternalUrls`.
- **On finish**: one `response` activity with summary; one comment only if the team asks for it (activities are the canonical record per Linear's guidance).
- **State**: `started` on launch; `completed` only under an explicit policy label; otherwise leave for the human assignee (Linear's model: human is accountable).

### C4. What Linear cannot express

- No custom fields: role/runtime must be labels or text.
- No structured checklist: progress is Markdown edits + `plan` JSON; no per-item identity across edits.
- No `blockedBy` field: derive from `inverseRelations.type == "blocks"`.
- No filter on `agentSessions`: polling must page and diff.
- No polling/long-poll contract: 10-second acknowledgement implies a public HTTPS receiver or a relay.
- No documented payload-size or concurrency limits: keep activities small (Markdown) and cap concurrent sessions per workspace in the daemon.
- Session `plan` is per session, not per issue; a second delegation starts a new session with an empty plan.
- `prompt` activities cannot be created by the agent: the daemon cannot inject a synthetic user message.
- `continue` signal exists in schema but is undocumented; do not rely on it.

### C5. Reference queries the daemon needs [schema-verified field names]

Read everything the session webhook omits (one request, well under the 10,000-point cap):

```graphql
query IssueForSession($id: String!) {
  issue(id: $id) {
    id identifier title description url branchName priority estimate
    state { id name type position }
    team { id key name }
    project { id name }
    assignee { id name } delegate { id name }
    parent { id identifier }
    labels(first: 50) { nodes { id name parent { name } } }
    children(first: 50) { nodes { id identifier title state { type } } }
    inverseRelations(first: 50) { nodes { type issue { id identifier state { type } } } }
    attachments(first: 50) { nodes { url title sourceType } }
    documents(first: 10) { nodes { id title } }
    lastAppliedTemplate { id name }
  }
}
```

First `started` state for the team (per Linear best practice):

```graphql
query StartedStates($teamId: ID!) {
  workflowStates(filter: { team: { id: { eq: $teamId } }, type: { eq: "started" } }) {
    nodes { id name position }
  }
}
```

Polling fallback for a NAT-bound daemon (no filter argument exists on `agentSessions`):

```graphql
query PendingSessions($after: String) {
  agentSessions(first: 50, after: $after, orderBy: updatedAt) {
    nodes { id status updatedAt issue { id identifier } creator { id } }
    pageInfo { hasNextPage endCursor }
  }
}
```

Acknowledge, plan, complete:

```graphql
mutation Ack($sid: String!) {
  agentActivityCreate(input: { agentSessionId: $sid, content: { type: "thought", body: "Acknowledged. Resolving role and workspace." } }) { success }
}
mutation Plan($sid: ID!, $plan: JSONObject!) {
  agentSessionUpdate(id: $sid, input: { plan: $plan }) { success }
}
mutation Done($sid: String!, $body: String!) {
  agentActivityCreate(input: { agentSessionId: $sid, content: { type: "response", body: $body } }) { success }
}
```

Note: `agentActivityCreate.input.agentSessionId` is `String!` while the documented `agentSessionUpdate` example declares `$agentSessionId: String!` for the `id` argument [doc]. The `plan` input is typed `JSONObject` in the SDL, but the documented example passes a bare array: `"plan": [ { "content": "…", "status": "inProgress" }, { "content": "…", "status": "pending" } ]` with no wrapper key [doc: https://linear.app/developers/agent-interaction]. Follow the documented shape; the scalar type name is loose.

### C6. Minimal jackin changes implied

1. Programmatic launch (`LoadOptions` with pre-resolved agent, trust, env, mounts; no TUI) — reuse `launch_pipeline`.
2. Manifest v1alpha7: `default_agent`, `[prompt] { env = "JACKIN_INITIAL_PROMPT" | file = "/jackin/task.md" }`; entrypoint appends the prompt as a positional argument per runtime.
3. `jackin-exec` binding for a Linear token so the agent can post its own `action` activities if desired; otherwise the daemon proxies.
4. Linear `TaskSource` implementation once the trait lands; until then a standalone daemon that shells into the programmatic launch is the pragmatic path.
