# The workflow, end to end

This is a non-normative walkthrough for the person using the system and for
the run that builds it. `SPEC.md` alone defines final workflow behavior and
acceptance; examples here explain that contract but cannot extend it.

## 0. One-time setup

1. Install the latest jackin locally, built from the working branch
   (D-034). Verify with the existing interactive commands; they are
   unchanged (D-009).
2. Create the jackin Linear agent app (`app:assignable`,
   `app:mentionable`) and install it in the workspace. Its client id,
   secret, and tokens are stored in 1Password at creation and referenced
   as `op://` (D-035); the daemon reads them from there.
3. Prepare the roles that will do the work (for example `the-architect`),
   built locally. Only the role that performs the browser proof ships
   `agent-browser` (D-032 as amended by D-053).
4. Create the persistent `agent-browser` profile logged in to Linear and
   GitHub (D-032); its logins are stored in 1Password (D-035).
5. Start the jackin daemon on the local machine (D-017). It begins
   monitoring containers and listening to Linear (D-008, D-011).

## 1. Define the work

1. In the repository that is the source of truth, make sure the references
   the work must satisfy exist: database structures, API contracts, TUI
   designs, and the verification script (D-003).
2. Create a Linear issue. Fill in: repository, branch (and base branch if
   not `main`), jackin role, agent runtime, prompt, and the checklist of
   tasks as a Markdown task list (D-012, D-013, D-014). Convention for the
   fields: labels `role:`/`agent:`/`model:`/`effort:`/`repo:`/`delivery:`,
   `branch:`/`base:` lines, prompt = description, checklist = first task
   list (Q-013 adopted, D-053).
3. If the issue depends on other issues, add Linear blocking relations
   (D-004).
4. Keep issues small. One issue is one agent's whole context; if the
   checklist is long, split it into several issues with blocking relations
   (D-003, D-004).

## 2. Hand it over

Assign the issue to jackin (D-011). Nothing else is required. Several
issues can be assigned at once; independent ones run in parallel (D-004).

## 3. The daemon runs it

1. The daemon sees the assignment, validates the issue contract, and if a
   field is missing comments on the issue and stops (D-012, D-014).
2. It prepares the workspace: pulls and reuses the branch if it exists on
   the remote, otherwise creates it from the base branch (D-014).
3. It reads the issue once and writes the checklist into the workspace
   (D-013).
4. It spawns the role with the chosen runtime through the same container
   mechanism as `jackin load`, under the capsule, with the prompt delivered
   as `/goal ... <local checklist>` (D-009, D-012, D-016).
5. The agent works item by item, delegating each item's research,
   implementation, and verification to subagents (D-007, D-036). When an item is finished it ticks it in the local file; the
   daemon pushes that tick to the Linear issue (D-013). The person sees
   progress in Linear without asking.
6. When the checklist is complete, the daemon runs the repository's verify
   command and accepts only `status: DONE` (D-030). Failures retry with
   backoff, stall is killed and retried, exhaustion escalates (D-021,
   D-027, D-029).
7. The daemon opens or updates the pull request from the branch on GitHub
   (D-014). Merge: the agent merges it itself, using the forwarded `gh`
   identity, whenever its task text names the merge; the daemon then moves
   the issue to the merging state and confirms (D-031, D-055, D-079).

## 4. Watch, attach, decide

- Watch from Linear: checklist ticks, session activity, and comments.
- Watch from the jackin TUI on termrock: every running container, its
  issue, its state (D-006, D-016).
- Attach to any container to see the exact prompt and the live session
  (D-016). This is the primary way to understand what an agent is doing.
- When the agent needs a decision, it is asked through the issue
  as a Linear elicitation with a blocker brief (D-029). Answer there; the
  run continues. Blocked, stuck, and container identity are visible on the
  issue (D-049, D-051, D-052).

## 5. Finish

The result is a pull request on GitHub. The agent merges it itself once its
required checks pass (who merges is D-031, D-055, D-079); the daemon then
moves the issue to the merging state and on to its final state. Issues
blocked by it become runnable.

## 6. Building the product with this workflow (D-033, D-034)

- All work, including the planning in this repository, is delegated to
  subagents; the session's top-level agent coordinates and records
  decisions (D-036). Any credential created along the way goes to 1Password
  in the same step (D-035).
- Milestone 1 is the setup in section 0 plus enough of the daemon to run
  section 3 steps 1–4 for one issue on the local machine.
- Until that exists, the same issue contract is executed by hand: create
  the issue, prepare the branch, run `jackin load <role> --agent <runtime>`
  in the workspace, paste the same prompt. The manual path and the daemon
  path must produce the same run, so the manual path is the daemon's
  acceptance test.
- Every step is verified locally first; jackin is built and installed
  from the working branch; roles are rebuilt locally; CI confirms later
  (D-034). Every milestone is also verified visually in Linear and GitHub
  with `agent-browser` (D-032).
- Changes to an involved project are made per task in that task's own git
  worktree on its own branch `managed/<run-id>/<task-id>`, created from the
  base SHA locked in `run/LOCK.toml`. A worker pushes only that branch and
  never pushes an integration branch. The holder of the repository's single
  integrator lease (`python3 tools/state.py lease --owner
  integrator:<repo>`) fast-forwards or merges the task branch into the
  integration target — `feat/managed-execution`, or `main` in a role
  repository — one task at a time; verification then runs against the
  resulting integrated SHA, recorded in `tasks/<id>/evidence.json` as
  `integrated_sha` (D-112). Pull requests to a protected `main` and jackin
  releases happen when a milestone needs them (D-034); such a `main` is
  reached only by a pull request the agent merges once its required checks
  pass, never by a push and never by a bypass (`goal/EXECUTION.md` §4).

## Today, for contrast

Pick the project by hand; build the plan in a jackin session with skills;
commit it to a branch; start a new agent by hand; paste a `/goal` prompt
pointing at the whole plan; watch; verify by hand; repeat. A large plan
handed to one agent is implemented partly wrong because the agent loses
context — which is why the target workflow is one small issue per agent.
