#!/usr/bin/env python3
"""Cross-document invariant lint (D-116).

Fails when two authoritative documents of this repository disagree with each
other. Every check is a fact that must hold across files, not inside one file:
a single-file rule belongs in that file's own gate. Python 3 standard library
only, no network, read-only except for a temporary copy of the run store.

Exit status is 0 when every check passes and 1 when any check fails. Each
finding is printed as `FAIL <check>: <file>:<line> <what disagrees>` so the
line can be opened directly.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The documents that bind the run. `analysis/` records facts about other
# repositories and `KICKOFF-READINESS-PLAN.md` quotes defects verbatim, so
# neither is authoritative and both are excluded from the text checks.
AUTHORITATIVE = [
    "AGENTS.md",
    "GOAL.md",
    "README.md",
    "SPEC.md",
    "ROADMAP.md",
    "VISION.md",
    "DECISIONS.md",
    "QUESTIONS.md",
    "OPEN-QUESTIONS.md",
    "PREFLIGHT-DEFECTS.md",
]

CITING = [
    "AGENTS.md",
    "GOAL.md",
    "README.md",
    "SPEC.md",
    "ROADMAP.md",
]

findings = []


def fail(check, where, message):
    findings.append("FAIL %s: %s %s" % (check, where, message))


def rel(path):
    return os.path.relpath(path, REPO)


def read(path):
    with open(os.path.join(REPO, path), encoding="utf-8") as handle:
        return handle.read()


def globbed(pattern_dir, suffix=".md"):
    directory = os.path.join(REPO, pattern_dir)
    if not os.path.isdir(directory):
        return []
    return sorted(
        os.path.join(pattern_dir, name)
        for name in os.listdir(directory)
        if name.endswith(suffix)
    )


def doc_set():
    return [p for p in AUTHORITATIVE if os.path.exists(os.path.join(REPO, p))] \
        + globbed("goal") + globbed("concept")


def all_markdown():
    """Every Markdown file except the two non-authoritative sources."""
    out = []
    for root, dirs, names in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in (".git", "analysis")]
        for name in names:
            if not name.endswith(".md"):
                continue
            path = os.path.join(root, name)
            if rel(path) == "KICKOFF-READINESS-PLAN.md":
                continue
            if os.path.islink(path):
                continue
            out.append(rel(path))
    return sorted(out)


def paragraph(text, marker):
    """The blank-line-delimited paragraph that contains `marker`."""
    index = text.find(marker)
    if index < 0:
        return None, None
    start = text.rfind("\n\n", 0, index)
    start = 0 if start < 0 else start + 2
    end = text.find("\n\n", index)
    end = len(text) if end < 0 else end
    line = text.count("\n", 0, index) + 1
    return text[start:end], line


def normalise(paragraph_text):
    return " ".join(paragraph_text.split())


# --------------------------------------------------------------------------
# 1. The D-119 runnable predicate says the same thing in both contracts
# --------------------------------------------------------------------------

def check_runnable_predicate():
    goal, goal_line = paragraph(read("GOAL.md"), "Runnable (D-119)")
    execu, exec_line = paragraph(read("goal/EXECUTION.md"), "Runnable predicate (D-119)")
    if goal is None:
        fail("d119-predicate", "GOAL.md:0", "no paragraph mentions D-119")
        return
    if execu is None:
        fail("d119-predicate", "goal/EXECUTION.md:0", "no paragraph mentions D-119")
        return
    if normalise(goal) != normalise(execu):
        fail("d119-predicate",
             "GOAL.md:%d vs goal/EXECUTION.md:%d" % (goal_line, exec_line),
             "the D-119 runnable predicate paragraph differs between the two "
             "contracts; they must carry the same text")


# --------------------------------------------------------------------------
# 2. The `~/.claude` concurrency cap is 2 everywhere
# --------------------------------------------------------------------------

# A cap of three counts as drift only when the number belongs to the
# `~/.claude` mention itself: "at most three ... ~/.claude", "~/.claude cap of
# three", "three for ~/.claude". A neighbouring "at most three in flight" is a
# different cap (D-071 caps total agents at three) and must not be flagged.
CAP_THREE = (
    re.compile(r"(?:at most|≤\s*)\s*(?:3|three)\b[^.;|]{0,50}?`?~/\.claude", re.I),
    re.compile(r"`?~/\.claude`?[^.;|]{0,50}?cap(?:ped)?\s*(?:of|at|is|=|to)?\s*(?:3|three)\b", re.I),
    re.compile(r"(?:3|three)\s+(?:for|on)\s+`?~/\.claude", re.I),
)


def check_claude_cap():
    for path in doc_set():
        text = read(path)
        flat = " ".join(text.split())
        for pattern in CAP_THREE:
            for match in pattern.finditer(flat):
                context = flat[match.start():match.end() + 60]
                if "lowered to 2" in context or "is 2" in context:
                    continue
                fail("claude-cap", "%s:0" % path,
                     "states a `~/.claude` cap other than 2 (D-071): %r"
                     % context[:90])


# --------------------------------------------------------------------------
# 3. Retired strings: `v1alpha8`, `<org>`, `workspace delete`
# --------------------------------------------------------------------------

def check_retired_strings():
    for path in ("ROADMAP.md", "SPEC.md"):
        text = read(path)
        for match in re.finditer(r"v1alpha8", text):
            line = text.count("\n", 0, match.start()) + 1
            fail("v1alpha8", "%s:%d" % (path, line),
                 "the run carries one manifest schema bump only (D-096 row 2.4)")

    for path in ("goal/EXECUTION.md", "ROADMAP.md"):
        text = read(path)
        for match in re.finditer(r"<org>", text):
            line = text.count("\n", 0, match.start()) + 1
            fail("org-placeholder", "%s:%d" % (path, line),
                 "an unexpanded `<org>` placeholder is not a runnable instruction")

    for path in all_markdown():
        text = read(path)
        for match in re.finditer(r"workspace delete", text):
            line = text.count("\n", 0, match.start()) + 1
            fail("workspace-delete", "%s:%d" % (path, line),
                 "the jackin subcommand is `workspace remove` (D-085)")


# --------------------------------------------------------------------------
# 4. Every cited decision and question resolves
# --------------------------------------------------------------------------

def check_citations():
    decisions = set(re.findall(r"^## (D-\d{3})", read("DECISIONS.md"), re.M))
    questions = set(re.findall(r"^## (Q-\d{3})", read("QUESTIONS.md"), re.M))

    for path in CITING + globbed("goal") + globbed("concept"):
        text = read(path)
        if path == "DECISIONS.md":
            continue
        for match in re.finditer(r"\bD-[01]\d{2}\b", text):
            cited = match.group(0)
            if cited in decisions:
                continue
            line = text.count("\n", 0, match.start()) + 1
            fail("decision-citation", "%s:%d" % (path, line),
                 "cites %s, which has no `## %s` heading in DECISIONS.md"
                 % (cited, cited))
        for match in re.finditer(r"\bQ-0\d{2}\b", text):
            cited = match.group(0)
            if cited in questions:
                continue
            line = text.count("\n", 0, match.start()) + 1
            fail("question-citation", "%s:%d" % (path, line),
                 "cites %s, which has no `## %s` heading in QUESTIONS.md"
                 % (cited, cited))


# --------------------------------------------------------------------------
# 5. No open question is left anywhere
# --------------------------------------------------------------------------

def check_no_open_questions():
    spec = read("SPEC.md")
    index = spec.find("\n## 11. Open questions")
    if index < 0:
        fail("open-questions", "SPEC.md:0", "section 11 is missing")
    else:
        body, _ = paragraph(spec[index + 1:], "\n")
        tail = spec[index:index + 400]
        if "None" not in tail:
            fail("open-questions", "SPEC.md:%d" % (spec.count("\n", 0, index) + 2),
                 "section 11 does not state that there are no open questions")
    open_questions = read("OPEN-QUESTIONS.md")
    if not re.search(r"^None\b", open_questions, re.M):
        fail("open-questions", "OPEN-QUESTIONS.md:0",
             "the file does not state that there are no open questions (D-053)")


# --------------------------------------------------------------------------
# 6. GOAL.md stays within the prompt budget
# --------------------------------------------------------------------------

GOAL_CAP = 4000


def check_goal_size():
    size = len(read("GOAL.md").encode("utf-8"))
    if size > GOAL_CAP:
        fail("goal-size", "GOAL.md:0",
             "%d bytes, over the %d-byte prompt cap" % (size, GOAL_CAP))


# --------------------------------------------------------------------------
# 7. The two projections equal what the run store renders
# --------------------------------------------------------------------------

def check_projections():
    log = os.path.join(REPO, "run", "events.jsonl")
    if not os.path.exists(log):
        fail("projections", "run/events.jsonl:0", "the run store is missing")
        return
    temp = tempfile.mkdtemp(prefix="invariant-lint-")
    try:
        # ECOSYSTEM_STORE makes state.py render into the copy, so the real
        # projections are compared, never rewritten.
        shutil.copy2(log, os.path.join(temp, "events.jsonl"))
        env = dict(os.environ, ECOSYSTEM_STORE=temp)
        result = subprocess.run(
            [sys.executable, os.path.join(REPO, "tools", "state.py"), "render"],
            env=env, capture_output=True, text=True)
        if result.returncode != 0:
            fail("projections", "tools/state.py:0",
                 "render failed: %s" % result.stderr.strip().splitlines()[-1:])
            return
        for rendered, actual in ((os.path.join(temp, "tasks-README.md"), "tasks/README.md"),
                                 (os.path.join(temp, "PROGRESS.md"), "PROGRESS.md")):
            with open(rendered, encoding="utf-8") as handle:
                want = handle.read()
            have = read(actual)
            if want != have:
                fail("projections", "%s:0" % actual,
                     "differs from `python3 tools/state.py render` output; "
                     "the projections are generated, never hand-edited (D-098)")
    finally:
        shutil.rmtree(temp, ignore_errors=True)


# --------------------------------------------------------------------------
# 8. The tree is clean
# --------------------------------------------------------------------------

def check_clean_tree():
    result = subprocess.run(["git", "-C", REPO, "status", "--porcelain"],
                            capture_output=True, text=True)
    if result.returncode != 0:
        fail("clean-tree", "git:0", "git status failed")
        return
    dirty = [line for line in result.stdout.splitlines() if line.strip()]
    if dirty:
        fail("clean-tree", "git:0",
             "%d uncommitted path(s), first: %s" % (len(dirty), dirty[0][3:]))


CHECKS = (
    ("d119-predicate", check_runnable_predicate),
    ("claude-cap", check_claude_cap),
    ("retired-strings", check_retired_strings),
    ("citations", check_citations),
    ("open-questions", check_no_open_questions),
    ("goal-size", check_goal_size),
    ("projections", check_projections),
    ("clean-tree", check_clean_tree),
)


def main():
    only = sys.argv[1:]
    for name, function in CHECKS:
        if only and name not in only:
            continue
        before = len(findings)
        function()
        status = "ok" if len(findings) == before else "FAILED"
        print("check %-16s %s" % (name, status))
    print("")
    for line in findings:
        print(line)
    print("")
    print("invariant_lint: %d finding(s)" % len(findings))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
