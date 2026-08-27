# The workflow, end to end

This is the complete workflow as it is meant to work for the person using
it, written to be confirmed or corrected. It is also the workflow used to
build the product itself (D-033). Numbered decisions are cited; unnumbered
sentences are the current understanding and are open to correction.

## 0. One-time setup

1. Install the latest jackin locally, built from the working branch
   (D-034). Verify with the existing interactive commands; they are
   unchanged (D-009).
2. Create the jackin Linear agent app (`app:assignable`,
   `app:mentionable`) and install it in the workspace. Store its
   credentials in 1Password; the daemon reads them from there.
3. Prepare the roles that will do the work (for example `the-architect`),
   built locally, with `agent-browser` included (D-032).
4. Create the persistent `agent-browser` profile logged in to Linear and
   GitHub (D-032).
5. Start the jackin daemon on the local machine (D-017). It begins
   monitoring containers and listening to Linear (D-008, D-011).

## 1. Define the work

1. In the repository that is the source of truth, make sure the references
   the work must satisfy exist: database structures, API contracts, TUI
   designs, and the verification script (D-003).
2. Create a Linear issue. Fill in: repository, branch (and base branch if
   not `main`), jackin role, agent runtime, prompt, and the checklist of
   tasks as a Markdown task list (D-012, D-013, D-014). Convention for the
   fields: *open (Q-013)*.
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
5. The agent works item by item with research and verification subagents
   (D-007). When an item is finished it ticks it in the local file; the
   daemon pushes that tick to the Linear issue (D-013). The person sees
   progress in Linear without asking.
6. When the checklist is complete, verification runs (*open (Q-014)*).
   Failure handling is *open (Q-008)*.
7. The daemon opens or updates the pull request from the branch on GitHub
   (D-014). Merge strategy is *open (Q-007)*.

## 4. Watch, attach, decide

- Watch from Linear: checklist ticks, session activity, and comments.
- Watch from the jackin TUI on termrock: every running container, its
  issue, its state (D-006, D-016).
- Attach to any container to see the exact prompt and the live session
  (D-016). This is the primary way to understand what an agent is doing.
- When the agent needs a decision, it is asked through the issue
  (*open (Q-009)* for the exact channel). Answer there; the run continues.

## 5. Finish

The result is a pull request on GitHub. Review it, merge it (who merges is
*open (Q-007)*), and the issue reaches its final state. Issues blocked by
it become runnable.

## 6. Building the product with this workflow (D-033, D-034)

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
- Changes to jackin, termrock, and this repository each go on one working
  branch where possible; pull requests to `main` and jackin releases happen
  when a milestone needs them (D-034).

## Today, for contrast

Pick the project by hand; build the plan in a jackin session with skills;
commit it to a branch; start a new agent by hand; paste a `/goal` prompt
pointing at the whole plan; watch; verify by hand; repeat. A large plan
handed to one agent is implemented partly wrong because the agent loses
context — which is why the target workflow is one small issue per agent.
