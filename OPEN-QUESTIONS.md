# Open questions

**Nothing here blocks execution (D-050, D-053, D-054).**

Undecided points that affect the design. Each entry names the question, why
it matters, and known options. Closing a question means recording a decision
in `DECISIONS.md` and removing the entry here. Every question that had a
recommended answer was adopted as the working decision by D-053; the
adopted answers are stated in `SPEC.md` and the concept documents and may
be overridden by a later decision. Only items with no recommended answer
remain below.

## Q-002 — What is the project's name?

Placeholder in all documents: "the manager". Stays until M10 names the
console route.

## Q-005 — How is a planner's output approved?

Narrowed by D-013 (the issue author writes the checklist) and D-028
(adopted, D-053: a planner role may propose follow-up issues; the daemon
creates them unassigned in a backlog state, and they become work only when
a human assigns them). Remaining: whether a planner may also produce a
checklist for an existing issue, and what the human's approval of a batch
of proposed issues looks like beyond assigning each one.

## Q-009 — How are escalations delivered beyond Linear?

Narrowed by D-029 (adopted, D-053: a blocker brief posted as a Linear
elicitation; the reply is sent into the session's PTY) and D-051 (a
harness-level block is a Linear-visible state). Remaining: desktop and
phone delivery beyond Linear's own apps, and how the termrock inbox mirrors
the ledger.
