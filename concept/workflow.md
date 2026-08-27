# Workflow: today versus target

## Today (manual)

| Step | Who | How |
| --- | --- | --- |
| Choose the project that is the source of truth | Human | By hand |
| Build the plan and its references | Human + agent | jackin session, planning skills |
| Store the plan | Human | Commit to a branch |
| Start an implementation agent | Human | New jackin session |
| Give it the work | Human | Paste `/goal` prompt pointing at the plan |
| Wait, watch, correct | Human | Terminal |
| Verify | Human or `./verify.sh` | By hand |
| Repeat for the next piece | Human | All of the above |

Failure mode: a large plan handed to one agent is implemented partly wrong
because the agent loses context.

## Target (managed)

| Step | Who | How |
| --- | --- | --- |
| Author or approve a plan decomposed into tasks | Human (+ planner agent, Q-005) | `concept/task-format.md` |
| Mark it ready | Human | Status change the daemon watches (D-005) |
| Determine runnable tasks | Manager | Dependency graph (D-004) |
| Start one isolated agent per runnable task | Manager via jackin | Role, runtime, mounts, prompt generated from the task |
| Execute with research and verification subagents | Agent | D-007 |
| Verify | Manager | Task `verify.sh`; failure policy (Q-008) |
| Merge and unblock dependents | Manager | Merge strategy (Q-007) |
| Decide when asked | Human | Decision inbox (Q-009) on the termrock TUI |

The human touches the system at three points: authoring, "ready", and
decisions.

## What changes in the ecosystem

- **jackin** gains a programmatic session API, detached launches, a daemon
  the manager can drive, verification execution, and remote-host mode
  (`analysis/jackin.md`, section 10).
- **termrock** gains pane management, a terminal pane, a live task graph,
  multi-source stream coalescing, and a host-loop drain hook so a live fleet
  UI is possible on its synchronous runtime (`analysis/termrock.md`, section
  8); jackin's duplicated widgets are removed (D-006).
- **tailrocks-skills** gain (or formalize) planning skills that emit the
  task format, and execution skills that assume one task per agent.
