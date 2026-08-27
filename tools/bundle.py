#!/usr/bin/env python3
"""Generate the 81 task bundles from ROADMAP.md (D-114).

Every task bundle -- ``TASK.md``, ``task.toml``, ``verify.sh``,
``expected-evidence.toml`` and ``refs/`` -- is derived from the task's row in
``ROADMAP.md`` and from nothing else, so the plan the run executes is the plan
the gate checked. Bundles are content addressed: ``bundle.py hash <id>`` is a
SHA-256 over the sorted generated files and ``run/LOCK.toml`` records the
hashes. ``bundle.py verify --all`` regenerates into a temporary directory and
fails when a bundle on disk has drifted from ``ROADMAP.md``.

Standard library only.

Usage:
    tools/bundle.py generate [--all | <id>...] [--root .]
    tools/bundle.py hash [--all | <id>...] [--root .]
    tools/bundle.py verify [--all | <id>...] [--root .]
"""
import argparse
import filecmp
import hashlib
import os
import re
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roadmap_compile as rc  # noqa: E402

# Files a bundle is made of; the hash covers exactly these, in this order.
BUNDLE_FILES = ["TASK.md", "expected-evidence.toml", "refs/sources.txt",
                "task.toml", "verify.sh"]

HOST_MARK = re.compile(r"host \(D-061[^)]*\):")
CONTAINER_MARK = re.compile(r"container:")

# The first word of a backticked span makes it a command rather than a literal.
COMMANDS = {
    "!", "agent-browser", "brew", "cargo", "cat", "command", "comm", "curl",
    "dash", "docker", "gh", "git", "gitleaks", "grep", "head", "jackin",
    "jackin-exec", "jackin-role", "jq", "mise", "npm", "op", "openssl",
    "printf", "python3", "script", "sed", "sh", "shellcheck", "sort", "ssh",
    "tail", "test", "tmux", "wc",
}

ROLE_SELECTOR = {
    "the-architect": "the-architect",
    "crew-builder": "donbeave/crew-builder",
    "crew-operator": "donbeave/crew-operator",
    "crew-reviewer": "donbeave/crew-reviewer",
    "host": "host",
}

REPO_OF = {
    "jackin": "jackin-project/jackin",
    "termrock": "tailrocks/termrock",
    "ecosystem": "tailrocks/ecosystem",
    "jackin-crew-builder": "donbeave/jackin-crew-builder",
    "jackin-crew-operator": "donbeave/jackin-crew-operator",
    "jackin-crew-reviewer": "donbeave/jackin-crew-reviewer",
}
# Repositories that carry the feature branch (D-047); everything else is main.
FEATURE_BRANCH_REPOS = {"jackin-project/jackin", "tailrocks/termrock"}


# --------------------------------------------------------------- roadmap read

def lane_table(path):
    """Lane -> (runtime, model, account home, fallback) from ROADMAP.md 5."""
    lanes = {}
    for line in open(path, encoding="utf-8"):
        if not re.match(r"^\|\s*L\d\s*\|", line):
            continue
        c = rc.split_row(line.rstrip("\n"))
        if len(c) < 6:
            continue
        lanes[c[0]] = {
            "runtime": "claude" if c[1].strip().lower().startswith("claude")
                       else "codex",
            "model_family": c[2],
            "account_home": c[3].strip("`"),
            "fallback_lane": c[5],
        }
    return lanes


def milestone_of(tid):
    return tid.split("-", 1)[0]


def strip_md(text):
    """Backticks and bold markers out; the prose is kept verbatim otherwise."""
    return text.replace("**", "")


def split_parts(verify):
    """Return (container text, host text) of a verify cell."""
    m = HOST_MARK.search(verify)
    if m:
        head, host = verify[:m.start()], verify[m.end():]
    else:
        head, host = verify, ""
    mc = CONTAINER_MARK.search(head)
    cont = head[mc.end():] if mc else head
    return cont.strip(" .;"), host.strip(" .;")


def commands_in(text):
    """Backticked spans whose first word is a command, in source order."""
    out = []
    for m in re.finditer(r"`([^`]+)`", text):
        span = m.group(1).strip()
        words = span.split()
        # A negated assertion is written `! grep ...` or `!grep ...`; the
        # command that decides whether it is a command is the one after the
        # negation, and the span keeps the `!` so the shell negates it.
        if words and words[0] == "!":
            words = words[1:]
        first = words[0].lstrip("!").strip() if words else ""
        if first in COMMANDS and span not in out:
            out.append(span)
    return out


def is_none_part(text):
    return text.strip().lower().startswith("none")


def self_evidence(row, tid):
    """Files this row says it files under its own task folder."""
    names = []
    text = " ".join(row[k] for k in ("scope", "verify", "proof"))
    for m in re.finditer(r"tasks/" + re.escape(tid) + r"/([A-Za-z0-9._/-]+)",
                         text):
        name = m.group(1).rstrip(".,;")
        if name.endswith("/") or not name or "." not in name:
            continue
        if name in BUNDLE_FILES or name.startswith("refs/"):
            continue  # part of the bundle itself, not evidence
        if name not in names:
            names.append(name)
    return names


def decisions_in(row):
    text = " ".join(str(v) for v in row.values())
    return sorted(set(re.findall(r"\bD-\d{3}\b", text)))


# ------------------------------------------------------------------ TOML bits

def tstr(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def tlist(items, indent="  "):
    if not items:
        return "[]"
    return "[\n" + "".join(f"{indent}{tstr(i)},\n" for i in items) + "]"


# ------------------------------------------------------------------ generator

def plan(tasks, lanes, tid):
    """Everything the four files are rendered from, derived once."""
    row = tasks[tid]
    lane = row["lane"].strip()
    lane = lane if lane in lanes else ""
    cont_text, host_text = split_parts(row["verify"])
    cont_cmds = [] if is_none_part(cont_text) else commands_in(cont_text)
    host_cmds = [] if is_none_part(host_text) else commands_in(host_text)
    has_container = bool(cont_text) and not is_none_part(cont_text)
    repos = [r.strip() for r in row["repos"].split(",") if r.strip()]
    repo = ""
    for r in repos:
        key = r.strip("`")
        if key in REPO_OF:
            repo = REPO_OF[key]
            break
    if not repo and any("crew-" in r for r in repos):
        repo = REPO_OF["jackin-crew-builder"]
    branch = "feat/managed-execution" if repo in FEATURE_BRANCH_REPOS \
        else "main"
    role = row["role"].strip().strip("`")
    evidence = []
    if has_container:
        evidence.append(("verify.container.out", "container", "status: DONE"))
    for name in self_evidence(row, tid):
        part = "host" if not has_container else "container"
        evidence.append((name, part, ""))
    return {
        "row": row,
        "id": tid,
        "milestone": milestone_of(tid),
        "title": strip_md(row["title"]),
        "scope": strip_md(row["scope"]),
        "proof": strip_md(row["proof"]),
        "verify": strip_md(row["verify"]),
        "container_text": cont_text,
        "host_text": host_text,
        "container_cmds": cont_cmds,
        "host_cmds": host_cmds,
        "has_container": has_container,
        "deps": row["deps"],
        "role": role,
        "role_selector": ROLE_SELECTOR.get(role, role),
        "lane": lane,
        "runtime": lanes[lane]["runtime"] if lane else "host",
        "fallback_lane": lanes[lane]["fallback_lane"] if lane else "",
        "account_home": lanes[lane]["account_home"] if lane else "",
        "delivery": row["delivery"].strip() or "goal",
        "size": row["size"].strip(),
        "repos": repos,
        "repo": repo,
        "branch": branch,
        "evidence": evidence,
        "decisions": decisions_in(row),
    }


def render_task_md(p):
    tid = p["id"]
    deps = ", ".join(p["deps"]) if p["deps"] else "none"
    lines = []
    a = lines.append
    a(f"# {tid} {p['title']}")
    a("")
    a("Generated from the `ROADMAP.md` row for this task by `tools/bundle.py`")
    a("(D-114). Do not edit by hand: an edit here is lost on the next")
    a("generation and makes `tools/bundle.py verify --all` fail. Change the")
    a("roadmap row instead.")
    a("")
    a("| Field | Value |")
    a("| --- | --- |")
    a(f"| milestone | {p['milestone']} |")
    a(f"| depends on | {deps} |")
    a(f"| role | `{p['role_selector']}` |")
    a(f"| lane | {p['lane'] or 'host (no lane)'} |")
    a(f"| runtime | {p['runtime']} |")
    a(f"| fallback lane | {p['fallback_lane'] or 'none'} |")
    a(f"| delivery | {p['delivery']} |")
    a(f"| size | {p['size']} |")
    a(f"| repositories | {', '.join(p['repos']) or 'none'} |")
    a(f"| branch | `{p['branch']}` |")
    a("")
    a("## Objective")
    a("")
    a(f"{p['title']}.")
    a("")
    a("## Scope")
    a("")
    a(p["scope"] if p["scope"] else "See the roadmap row.")
    a("")
    a("## References")
    a("")
    a("The container never sees this repository, so every reference below is")
    a("container-relative (D-086).")
    a("")
    a("- `.jackin/task/refs/sources.txt` — the roadmap row and the decisions")
    a("  this task is bound by.")
    a("- `.jackin/task/TASK.md` — this file.")
    a("- `.jackin/task/verify.sh` — the verification this task must pass.")
    a("- `.jackin/task/expected-evidence.toml` — the evidence it must file.")
    a("")
    a("## Steps")
    a("")
    a("1. Read the scope above and the references it names.")
    a("2. Do the work in the repositories listed, on the branch named above.")
    a("3. File the expected evidence in the task folder.")
    a("4. Run `sh verify.sh container` (and, host-side, `sh verify.sh host`)")
    a("   until the last line is `status: DONE`.")
    a("")
    a("## Checklist")
    a("")
    a("- [ ] The scope above is implemented in the listed repositories.")
    if p["container_cmds"]:
        for c in p["container_cmds"]:
            a(f"- [ ] container check passes: `{c}`")
    elif p["has_container"]:
        a("- [ ] The container part of the verify contract below holds.")
    if p["host_cmds"]:
        for c in p["host_cmds"]:
            a(f"- [ ] host check passes: `{c}`")
    for name, _part, _c in p["evidence"]:
        a(f"- [ ] `{name}` is filed in the task folder.")
    a("- [ ] Every touched repository is committed and pushed.")
    a("- [ ] `sh verify.sh` prints `status: DONE` for each part.")
    a("")
    a("## Verify contract")
    a("")
    a("Container part (run inside the task container):")
    a("")
    a(f"> {p['container_text'] or 'none'}")
    a("")
    a("Host part (run by the host Claude Code session, D-061):")
    a("")
    a(f"> {p['host_text'] or 'none'}")
    a("")
    if p["has_container"]:
        a("When a container part exists the host part first asserts that")
        a(f"`tasks/{tid}/verify.container.out` ends with `status: DONE`, so a")
        a("passing host part can never mask a failed container part (D-086).")
        a("")
    a("## Evidence expected (D-118)")
    a("")
    if p["evidence"]:
        for name, part, contains in p["evidence"]:
            extra = f", containing `{contains}`" if contains else ""
            a(f"- `tasks/{tid}/{name}` ({part} part{extra})")
    else:
        a("- The verify output of each part, filed in the task folder.")
    a("")
    a("## Proof (browser/attach)")
    a("")
    a(p["proof"] if p["proof"] and p["proof"] != "—" else "None for this task.")
    a("")
    a("## Definition of done")
    a("")
    a("The scope is implemented, the evidence above is filed, every touched")
    a("repository is committed and pushed, and `verify.sh` prints")
    a("`status: DONE` as its last line for every part this task has.")
    a("")
    a("## Constraints")
    a("")
    a("Always `git commit -s` (DCO is a required check, D-089). Work only on")
    a("this task; do not touch another task's area. Fix an involved project")
    a("rather than working around it (D-046). No secret value in any file,")
    a("log, message, or image: every credential is an `op://` reference")
    a("(D-035, D-081).")
    a("")
    a("## Preflight (D-050)")
    a("")
    a("preflight: none beyond the milestone's \"Operator preflight\" list in")
    a("`ROADMAP.md`. An input only a human can provide that is discovered")
    a("missing mid-task is a preflight defect: finish what does not depend on")
    a("it and mark the task blocked with the exact item.")
    a("")
    a("## Authorization (D-055, D-079)")
    a("")
    a("This task text is the operator's per-PR authorization: when a step")
    a("names a merge, merge the pull request yourself with `gh pr merge` once")
    a("every required check is green; do not wait for a further \"merge it\";")
    a("never bypass a failed check. Role repositories commit to `main`")
    a("(D-074).")
    a("")
    a("## When stuck (D-063)")
    a("")
    a("If this task stalls or takes longer than expected, do not escalate")
    a("first. Spawn subagents to analyze why (wrong assumption, missing input,")
    a("failing check, environment) and to propose a solution; apply it; only")
    a("then, if it is a genuine operator input, mark the task blocked with the")
    a("exact item.")
    return "\n".join(lines) + "\n"


def render_task_toml(p):
    tid = p["id"]
    out = []
    a = out.append
    a("# Generated from the ROADMAP.md row for this task by tools/bundle.py")
    a("# (D-114). Do not edit by hand; edit the roadmap row and regenerate.")
    a(f"id = {tstr(tid)}")
    a(f"milestone = {tstr(p['milestone'])}")
    a(f"title = {tstr(p['title'])}")
    a(f"repo = {tstr(p['repo'])}")
    a(f"repos = {tlist(p['repos'])}")
    a(f"branch = {tstr(p['branch'])}")
    a('base = "main"')
    a(f"role = {tstr(p['role_selector'])}")
    a(f"runtime = {tstr(p['runtime'])}")
    a(f"lane = {tstr(p['lane'])}")
    a(f"fallback_lane = {tstr(p['fallback_lane'])}")
    a(f"account_home = {tstr(p['account_home'])}")
    a(f"delivery = {tstr(p['delivery'])}")
    a(f"size = {tstr(p['size'])}")
    a(f"depends_on = {tlist(p['deps'])}")
    a(f"decisions = {tlist(p['decisions'])}")
    a("")
    a("[limits]")
    a("attempts = 3")
    a("")
    a("[verify]")
    a("script = \"verify.sh\"")
    a(f"has_container_part = {'true' if p['has_container'] else 'false'}")
    a(f"container = {tlist(p['container_cmds'])}")
    a(f"host = {tlist(p['host_cmds'])}")
    a("")
    for name, part, contains in p["evidence"]:
        a("[[evidence]]")
        a(f"path = {tstr(name)}")
        a(f"part = {tstr(part)}")
        a(f"contains = {tstr(contains)}")
        a("")
    return "\n".join(out).rstrip("\n") + "\n"


def render_expected_evidence(p):
    out = []
    a = out.append
    a("# Evidence this task must produce, declared before it runs (D-118).")
    a("# Generated by tools/bundle.py from the ROADMAP.md row; verify.sh fails")
    a("# when a declared artefact is missing or does not contain its marker.")
    a(f"task = {tstr(p['id'])}")
    a("")
    if not p["evidence"]:
        a("# This row declares no named artefact of its own; the filed verify")
        a("# output of each part is the evidence.")
    for name, part, contains in p["evidence"]:
        a("[[evidence]]")
        a(f"path = {tstr(name)}")
        a(f"part = {tstr(part)}")
        a(f"contains = {tstr(contains)}")
        a("")
    return "\n".join(out).rstrip("\n") + "\n"


def render_sources(p, roadmap):
    tid = p["id"]
    out = []
    a = out.append
    a(f"# Sources for {tid}. Generated by tools/bundle.py (D-114).")
    a(f"roadmap: {roadmap} line {p['row']['line']} (row {tid})")
    a(f"format: concept/task-format.md")
    a(f"decisions: {' '.join(p['decisions']) if p['decisions'] else 'none'}")
    a(f"repositories: {', '.join(p['repos']) if p['repos'] else 'none'}")
    a(f"role: {p['role_selector']}")
    a(f"lane: {p['lane'] or 'host (no lane)'}")
    return "\n".join(out) + "\n"


PF = "printf '%s" + chr(92) + "n'"


def sh_quote(s):
    """Single-quote a string for POSIX sh."""
    return "'" + s.replace("'", "'\\''") + "'"


def render_verify_sh(p):
    tid = p["id"]
    out = []
    a = out.append
    a("#!/bin/sh")
    # SC2016: the checks are stored as literal command strings on
    # purpose, so nothing expands before run_cmd runs them. SC2329: the
    # helpers are called from the other case branch.
    a("# shellcheck disable=SC2016,SC2329")
    a(f"# {tid} verification. Generated by tools/bundle.py from the")
    a(f"# ROADMAP.md row at line {p['row']['line']} (D-114). Do not edit by")
    a("# hand: edit the roadmap row and regenerate.")
    a("#")
    a("# Takes one argument, container or host, and runs only that part")
    a("# (D-086). Prints status: DONE as its last line on success and")
    a("# status: PENDING otherwise.")
    a("set -eu")
    a("")
    a('task_dir=$(dirname "$0")')
    a("fail=0")
    a("")
    a("# A command carrying a <placeholder> needs an operator substitution, so")
    a("# it is not run here; its filed evidence is what proves it instead.")
    a("run_cmd() {")
    a('  case $1 in')
    a("    *'<'*'>'*)")
    a(f'      {PF} "skip (needs substitution): $1"')
    a("      return 0")
    a("      ;;")
    a("  esac")
    a(f'  {PF} "run: $1"')
    a('  if sh -c "$1"; then')
    a(f'    {PF} "ok: $1"')
    a("  else")
    a(f'    {PF} "FAILED: $1"')
    a("    fail=1")
    a("  fi")
    a("}")
    a("")
    a("need_evidence() {")
    a('  if [ ! -s "$task_dir/$1" ]; then')
    a(f'    {PF} "missing evidence: $1"')
    a("    fail=1")
    a("    return 0")
    a("  fi")
    a('  if [ -n "$2" ] && ! grep -q -- "$2" "$task_dir/$1"; then')
    a(f'    {PF} "evidence $1 does not contain: $2"')
    a("    fail=1")
    a("  fi")
    a("}")
    a("")
    a("finish() {")
    a('  if [ "$fail" -eq 0 ]; then')
    a(f'    {PF} "status: DONE"')
    a("    exit 0")
    a("  fi")
    a(f'  {PF} "status: PENDING"')
    a("  exit 1")
    a("}")
    a("")
    a("part=${1:-}")
    a('case "$part" in')
    a("  container)")
    if not p["has_container"]:
        a(f'    {PF} "no container part for this task"'
          " # host row (D-061)")
    for c in p["container_cmds"]:
        a(f"    run_cmd {sh_quote(c)}")
    for name, part, contains in p["evidence"]:
        if part == "container" and name != "verify.container.out":
            a(f"    need_evidence {sh_quote(name)} {sh_quote(contains)}")
    a("    finish")
    a("    ;;")
    a("  host)")
    if p["has_container"]:
        a("    need_evidence 'verify.container.out' 'status: DONE'")
        a('    if [ "$fail" -ne 0 ]; then')
        a(f'      {PF} "container part has not passed"')
        a(f'      {PF} "status: PENDING"')
        a("      exit 1")
        a("    fi")
    for c in p["host_cmds"]:
        a(f"    run_cmd {sh_quote(c)}")
    for name, part, contains in p["evidence"]:
        if part == "host":
            a(f"    need_evidence {sh_quote(name)} {sh_quote(contains)}")
    a("    finish")
    a("    ;;")
    a("  *)")
    a(f'    {PF} "usage: $0 container|host"')
    a(f'    {PF} "status: PENDING"')
    a("    exit 2")
    a("    ;;")
    a("esac")
    return "\n".join(out) + "\n"


def generate(root, roadmap, tasks, lanes, tid, dest_root=None):
    p = plan(tasks, lanes, tid)
    d = os.path.join(dest_root or os.path.join(root, "tasks"), tid)
    os.makedirs(os.path.join(d, "refs"), exist_ok=True)
    files = {
        "TASK.md": render_task_md(p),
        "task.toml": render_task_toml(p),
        "expected-evidence.toml": render_expected_evidence(p),
        "refs/sources.txt": render_sources(p, roadmap),
        "verify.sh": render_verify_sh(p),
    }
    for name, body in files.items():
        path = os.path.join(d, name)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(body)
        if name == "verify.sh":
            os.chmod(path, 0o755)
    return d


def bundle_hash(d, names=None):
    h = hashlib.sha256()
    for name in (names if names is not None else BUNDLE_FILES):
        path = os.path.join(d, name)
        h.update(name.encode())
        h.update(b"\0")
        with open(path, "rb") as fh:
            body = fh.read()
        h.update(str(len(body)).encode())
        h.update(b"\0")
        h.update(body)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("action", choices=["generate", "hash", "verify"])
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--root", default=".")
    ap.add_argument("--roadmap", default=None)
    ap.add_argument("--extra", action="append", default=[], metavar="ID",
                    help="hash a bundle whose id is not in ROADMAP.md, such as "
                         "the canary; only `hash` accepts it, and the id is "
                         "never added to the compiled graph")
    a = ap.parse_args()

    roadmap = a.roadmap or os.path.join(a.root, "ROADMAP.md")
    tasks, dupes = rc.parse(roadmap)
    if dupes:
        print("duplicate rows: " + ", ".join(t for t, _ in dupes),
              file=sys.stderr)
        return 1
    lanes = lane_table(roadmap)
    ids = sorted(tasks) if (a.all or not a.ids) else list(a.ids)
    if a.extra:
        if a.action != "hash":
            print("--extra is only meaningful for `hash`", file=sys.stderr)
            return 1
        if a.all or a.ids:
            print("--extra cannot be combined with --all or a listed id",
                  file=sys.stderr)
            return 1
        # An extra id is hashed straight from disk: it has no ROADMAP.md row,
        # so it can be neither generated nor verified against one, and a
        # hand-written bundle has no `refs/sources.txt`, which only the
        # generator produces. The hash therefore covers the bundle files that
        # are present, in the same fixed order; the three files every bundle
        # must have are still required. Evidence a task produces later --
        # `evidence.json`, `verify.out` and the artefacts themselves -- is
        # outside that list, so the hash of a bundle does not move once it is
        # written.
        for tid in a.extra:
            d = os.path.join(a.root, "tasks", tid)
            if not os.path.isdir(d):
                print(f"{tid} missing", file=sys.stderr)
                return 1
            present = [n for n in BUNDLE_FILES
                       if os.path.isfile(os.path.join(d, n))]
            missing = [n for n in ("TASK.md", "task.toml", "verify.sh")
                       if n not in present]
            if missing:
                print(f"{tid} missing " + ", ".join(missing), file=sys.stderr)
                return 1
            print(f"{tid} {bundle_hash(d, present)}")
        return 0
    unknown = [i for i in ids if i not in tasks]
    if unknown:
        print("unknown task id: " + ", ".join(unknown), file=sys.stderr)
        return 1

    if a.action == "generate":
        for tid in ids:
            generate(a.root, roadmap, tasks, lanes, tid)
        print(f"{len(ids)} bundles generated")
        return 0

    if a.action == "hash":
        for tid in ids:
            d = os.path.join(a.root, "tasks", tid)
            if not os.path.isdir(d):
                print(f"{tid} missing", file=sys.stderr)
                return 1
            print(f"{tid} {bundle_hash(d)}")
        return 0

    # verify: regenerate into a temporary tree and compare byte for byte
    drift = []
    tmp = tempfile.mkdtemp(prefix="bundle-verify-")
    try:
        for tid in ids:
            have = os.path.join(a.root, "tasks", tid)
            want = generate(a.root, roadmap, tasks, lanes, tid, dest_root=tmp)
            if not os.path.isdir(have):
                drift.append(f"{tid}: bundle missing")
                continue
            for name in BUNDLE_FILES:
                hp, wp = os.path.join(have, name), os.path.join(want, name)
                if not os.path.isfile(hp):
                    drift.append(f"{tid}: missing {name}")
                elif not filecmp.cmp(hp, wp, shallow=False):
                    drift.append(f"{tid}: {name} differs from ROADMAP.md")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for d in drift:
        print(f"drift: {d}", file=sys.stderr)
    if drift:
        print(f"{len(ids) - len({d.split(':')[0] for d in drift})}/{len(ids)} "
              f"bundles match ROADMAP.md", file=sys.stderr)
        return 1
    print(f"{len(ids)}/{len(ids)} bundles match ROADMAP.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
