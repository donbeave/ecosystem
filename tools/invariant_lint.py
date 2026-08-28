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

# Documents inspected for cross-document consistency. Only SPEC.md defines
# product requirements; ROADMAP.md supplies graph/order and the others are
# procedure or non-normative context. `analysis/` records dated repository facts.
CHECKED_DOCS = [
    "AGENTS.md",
    "GOAL.md",
    "README.md",
    "SPEC.md",
    "ROADMAP.md",
    "VISION.md",
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
    return [p for p in CHECKED_DOCS if os.path.exists(os.path.join(REPO, p))] \
        + globbed("goal") + globbed("concept")


def all_markdown():
    """Every Markdown file except non-authoritative analysis sources."""
    out = []
    for root, dirs, names in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in (".git", "analysis")]
        for name in names:
            if not name.endswith(".md"):
                continue
            path = os.path.join(root, name)
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
                 "the run carries one manifest schema bump only (ROADMAP.md M3-02)")

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
# 3b. No `op://` reference carries an unexpanded `<org>` placeholder
# --------------------------------------------------------------------------

# A credential reference is only runnable when the item name is a literal, so
# `op://jackin/github-app-jackin-daemon-<org>/...` is a defect wherever it
# appears: the human cannot create an item called `<org>` and `op read` cannot
# resolve one. The check is deliberately wider than the `<org>` retired-string
# check above, which covers two files only; this one covers every Markdown
# file of the repository except non-authoritative analysis sources.
OP_REFERENCE = re.compile(r"op://[^\s`|)\]]+")


def check_op_org_placeholder():
    for path in all_markdown():
        text = read(path)
        for match in OP_REFERENCE.finditer(text):
            if "<org>" not in match.group(0):
                continue
            line = text.count("\n", 0, match.start()) + 1
            fail("op-org-placeholder", "%s:%d" % (path, line),
                 "the `op://` reference %r keeps an unexpanded `<org>`; "
                 "name the literal items instead (D-108)" % match.group(0))


# --------------------------------------------------------------------------
# 4. SPEC IDs, compatibility aliases, selectors, and pointers resolve
# --------------------------------------------------------------------------

NORMATIVE_DEF = re.compile(
    r"^- \*\*([A-Z][A-Z0-9]*-\d{3})\*\*", re.M)
ACC_ROW_DEF = re.compile(r"^\| \*\*(ACC-\d{3})\*\* \|", re.M)
ALIAS_DEF = re.compile(r"^## (D-\d{3})\s*$", re.M)
QUESTION_DEF = re.compile(r"^## (Q-\d{3})\b", re.M)
NORMATIVE_PREFIXES = frozenset((
    "PRD", "AUTH", "ARCH", "ISSUE", "SCHED", "STATE", "EXEC", "REC",
    "SEC", "ROLE", "OBS", "DEP", "CTRL", "ACC",
))
REFERENCE_PREFIXES = NORMATIVE_PREFIXES | {"D", "Q"}
STABLE_ID = re.compile(r"\b[A-Z][A-Z0-9]*-\d{3}\b")
NUMBERED_ALIAS = re.compile(r"\bD-\d{3}\s*\(\d+\)")
SELECTOR = re.compile(
    r"(?<![A-Z0-9-])([A-Z][A-Z0-9]*-(?:\*|\d{3}(?:\.\.[A-Z][A-Z0-9]*-\d{3})?))")
SPEC_POINTER = re.compile(
    r"`?SPEC(?:\.md)?`?\s*§\s*(\d+(?:\.\d+)*)", re.I)
SPEC_SECTION = re.compile(r"^#{2,3}\s+(\d+(?:\.\d+)*)(?:\.\s|\s)", re.M)
HISTORY_FRAMING = re.compile(
    r"\b(?:decision registry|proposal alias|working decision|"
    r"adopted as written|historical proposal)\b", re.I)


def _definitions(pattern, text):
    """Return id -> definition line, reporting duplicate definitions."""
    out = {}
    for match in pattern.finditer(text):
        ident = match.group(1)
        line = text.count("\n", 0, match.start()) + 1
        if ident in out:
            fail("spec-id", "SPEC.md:%d" % line,
                 "%s is defined more than once (first at line %d)"
                 % (ident, out[ident]))
        else:
            out[ident] = line
    return out


def _expand_selector(selector, normative):
    if selector.endswith("-*"):
        prefix = selector[:-1]
        return {ident for ident in normative if ident.startswith(prefix)}
    if ".." not in selector:
        return {selector} if selector in normative else set()
    first, last = selector.split("..", 1)
    first_prefix, first_num = first.rsplit("-", 1)
    last_prefix, last_num = last.rsplit("-", 1)
    if first_prefix != last_prefix or first not in normative or last not in normative:
        return set()
    low, high = int(first_num), int(last_num)
    if low > high:
        return set()
    return {ident for ident in normative
            if ident.startswith(first_prefix + "-")
            and low <= int(ident.rsplit("-", 1)[1]) <= high}


def _near_reference_prefix(prefix):
    """True for a canonical prefix or a one-edit typo of one."""
    for expected in REFERENCE_PREFIXES:
        if prefix == expected:
            return True
        if abs(len(prefix) - len(expected)) > 1:
            continue
        shorter, longer = sorted((prefix, expected), key=len)
        if len(shorter) == len(longer):
            if sum(a != b for a, b in zip(shorter, longer)) == 1:
                return True
        elif any(shorter == longer[:i] + longer[i + 1:]
                 for i in range(len(longer))):
            return True
    return False


def check_spec_contract():
    spec = read("SPEC.md")
    normative = _definitions(NORMATIVE_DEF, spec)
    for ident, line in _definitions(ACC_ROW_DEF, spec).items():
        if ident in normative:
            fail("spec-id", "SPEC.md:%d" % line,
                 "%s is defined more than once (first at line %d)"
                 % (ident, normative[ident]))
        else:
            normative[ident] = line
    for ident, line in normative.items():
        prefix = ident.rsplit("-", 1)[0]
        if prefix not in NORMATIVE_PREFIXES:
            fail("spec-id", "SPEC.md:%d" % line,
                 "%s uses unknown normative prefix %s" % (ident, prefix))
    aliases = _definitions(ALIAS_DEF, spec)
    questions = _definitions(QUESTION_DEF, read("QUESTIONS.md"))

    for match in HISTORY_FRAMING.finditer(spec):
        line = spec.count("\n", 0, match.start()) + 1
        fail("spec-history", "SPEC.md:%d" % line,
             "historical decision framing %r is forbidden" % match.group(0))

    alias_heads = list(ALIAS_DEF.finditer(spec))
    for index, head in enumerate(alias_heads):
        end = alias_heads[index + 1].start() if index + 1 < len(alias_heads) else len(spec)
        body = spec[head.end():end].strip()
        selectors = [match.group(1) for match in SELECTOR.finditer(body)]
        if not selectors:
            fail("alias-selector", "SPEC.md:%d" % aliases[head.group(1)],
                 "%s maps to no normative selector" % head.group(1))
        for selector in selectors:
            if not _expand_selector(selector, normative):
                fail("alias-selector", "SPEC.md:%d" % aliases[head.group(1)],
                     "%s has unknown or empty selector %s"
                     % (head.group(1), selector))
        residue = SELECTOR.sub("", body)
        if residue.strip(";., \t\r\n"):
            fail("alias-selector", "SPEC.md:%d" % aliases[head.group(1)],
                 "%s contains non-selector mapping text %r"
                 % (head.group(1), residue.strip()))

    known = set(normative) | set(aliases) | set(questions)
    pointer_paths = CITING + globbed("goal") + globbed("concept") \
        + ["findings/disposition.toml"]
    sections = set(SPEC_SECTION.findall(spec))
    for path in pointer_paths:
        text = read(path)
        for match in NUMBERED_ALIAS.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            fail("semantic-pointer", "%s:%d" % (path, line),
                 "%s cites a removed numbered alias subclause"
                 % match.group(0))
        for match in STABLE_ID.finditer(text):
            cited = match.group(0)
            if cited in known:
                continue
            if not _near_reference_prefix(cited.rsplit("-", 1)[0]):
                continue
            line = text.count("\n", 0, match.start()) + 1
            fail("semantic-pointer", "%s:%d" % (path, line),
                 "%s has no normative definition, compatibility alias, or question"
                 % cited)
        for match in SPEC_POINTER.finditer(text):
            section = match.group(1)
            if section in sections:
                continue
            line = text.count("\n", 0, match.start()) + 1
            fail("semantic-pointer", "%s:%d" % (path, line),
                 "SPEC section %s does not exist" % section)


# --------------------------------------------------------------------------
# 5. No open question is left anywhere
# --------------------------------------------------------------------------

def check_no_open_questions():
    spec = read("SPEC.md")
    head = re.search(r"^## 11\. Open questions\s*$", spec, re.M)
    if head is None:
        fail("open-questions", "SPEC.md:0", "section 11 is missing")
    else:
        tail = spec[head.end():]
        next_head = re.search(r"^## ", tail, re.M)
        body = tail[:next_head.start()] if next_head else tail
        marker = body.split("\n- **", 1)[0].strip()
        if marker != "None.":
            fail("open-questions", "SPEC.md:%d" %
                 (spec.count("\n", 0, head.end()) + 1),
                 "section 11 must begin with the exact closed marker `None.`")
    open_questions = read("OPEN-QUESTIONS.md")
    body = re.sub(r"\A# Open questions\s*\n", "", open_questions).lstrip()
    marker = body.split("\n\n", 1)[0].strip()
    if marker != "None.":
        fail("open-questions", "OPEN-QUESTIONS.md:0",
             "the first body paragraph must be the exact closed marker `None.` (D-053)")


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
                     "the projections are generated, never hand-edited (D-111)")
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


# --------------------------------------------------------------------------
# 11. Every task file claimed to exist NOW resolves (D-116)
# --------------------------------------------------------------------------

EXISTS_CLAIM = re.compile(
    r"\b(?:currently|already)\s+(?:exists|is present|is committed)\b|"
    r"\b(?:exists|is present|is committed)\s+now\b|\bchecked[- ]in\b", re.I)


def check_existence_claims():
    for path in ["AGENTS.md", "README.md", "SPEC.md"] + globbed("goal"):
        if not os.path.exists(os.path.join(REPO, path)):
            continue
        text = read(path)
        for match in re.finditer(r"`(tasks/[A-Za-z0-9][^`\s]*)`", text):
            cited = match.group(1)
            if "<" in cited or ">" in cited or "*" in cited:
                continue  # a template, not a claim about one file
            start = text.rfind("\n", 0, match.start()) + 1
            end = text.find("\n", match.end())
            end = len(text) if end < 0 else end
            sentence = text[start:end]
            if not EXISTS_CLAIM.search(sentence):
                continue
            if os.path.exists(os.path.join(REPO, cited)):
                continue
            line = text.count("\n", 0, match.start()) + 1
            fail("existence-claims", "%s:%d" % (path, line),
                 "claims `%s` exists now, but that path does not resolve"
                 % cited)


CHECKS = (
    ("d119-predicate", check_runnable_predicate),
    ("claude-cap", check_claude_cap),
    ("retired-strings", check_retired_strings),
    ("op-org-placeholder", check_op_org_placeholder),
    ("spec-contract", check_spec_contract),
    ("open-questions", check_no_open_questions),
    ("goal-size", check_goal_size),
    ("projections", check_projections),
    ("existence-claims", check_existence_claims),
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
        print("check %-22s %s" % (name, status))
    print("")
    for line in findings:
        print(line)
    print("")
    print("invariant_lint: %d finding(s)" % len(findings))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
