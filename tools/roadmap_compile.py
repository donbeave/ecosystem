#!/usr/bin/env python3
"""Compile ROADMAP.md task tables into a DAG and validate it.

Stdlib only. See --help.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys

ID_RE = re.compile(r"^M(\d+)-(\d+)([a-z]*)$")
ROW_RE = re.compile(r"^\|\s*(M\d+-\d+[a-z]*)\s*\|")
IDREF_RE = re.compile(r"\bM\d+-\d+[a-z]*\b")
ART_RE = re.compile(r"tasks/(M\d+-\d+[a-z]*)/([A-Za-z0-9._/-]+)")
GATE_RE = re.compile(
    r"(may start once|starts with M\d+, after|after M\d+-\d+[a-z]* )", re.I
)
# A cell needs a live managed run when it asserts something about a managed
# container, or launches/attaches an agent on a scratch issue or repository.
LIVE_RE = re.compile(
    r"(while a managed container runs|live managed run|scratch repositor"
    r"|(launch|attach|hardline)[a-z]*[^|]{0,80}scratch issue"
    r"|scratch issue[^|]{0,80}(launch|attach|hardline))", re.I)
# A path is authored, not consumed, when one of these verbs (or an explicit
# "produces:"/"authors:" marker) stands shortly before it in the same cell.
AUTHOR_RE = re.compile(
    r"\b(writes|creates|authors|produces:|authors:)[^|]{0,60}$", re.I)
# A task that can itself provide a live managed run: the dispatch step, or the
# task that creates the scratch repository every later live proof reads.
DISPATCH_RE = re.compile(r"^Dispatch\b", re.I)

COLS = ["id", "title", "scope", "repos", "depends_on", "role", "lane",
        "delivery", "size", "verify", "proof"]


def split_row(line):
    # split on unescaped pipes
    parts, cur, i = [], [], 0
    while i < len(line):
        c = line[i]
        if c == "\\" and i + 1 < len(line):
            cur.append(line[i + 1])
            i += 2
            continue
        if c == "|":
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(c)
        i += 1
    parts.append("".join(cur))
    return [p.strip() for p in parts[1:-1]]  # drop before-first / after-last


def parse(path):
    tasks = {}
    dupes = []
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            if not ROW_RE.match(line):
                continue
            cells = split_row(line.rstrip("\n"))
            if len(cells) < len(COLS):
                cells += [""] * (len(COLS) - len(cells))
            row = dict(zip(COLS, cells[:len(COLS)]))
            row["line"] = n
            row["extra"] = " ".join(cells[len(COLS):])
            tid = row["id"]
            deps = [] if row["depends_on"].strip() in ("", "—", "-", "None") \
                else IDREF_RE.findall(row["depends_on"])
            row["deps"] = deps
            if tid in tasks:
                dupes.append((tid, n))
            else:
                tasks[tid] = row
    return tasks, dupes


def cells_text(row, keys=("verify", "proof", "scope", "title")):
    return " || ".join(row[k] for k in keys)


def toposort(tasks, extra_edges=()):
    edges = {t: set(r["deps"]) & set(tasks) for t, r in tasks.items()}
    for a, b in extra_edges:  # a depends on b
        edges.setdefault(a, set()).add(b)
    wave, done, remaining = {}, set(), dict(edges)
    level = 0
    while remaining:
        ready = [t for t, d in remaining.items() if d <= done]
        if not ready:
            return wave, sorted(remaining)  # cycle members
        for t in ready:
            wave[t] = level
            del remaining[t]
        done |= set(ready)
        level += 1
    return wave, []


def ancestors(tasks, tid):
    seen, stack = set(), list(tasks[tid]["deps"])
    while stack:
        x = stack.pop()
        if x in seen or x not in tasks:
            continue
        seen.add(x)
        stack.extend(tasks[x]["deps"])
    return seen


def check(tasks, dupes, inject):
    errs = {"dangling": [], "cycle": [], "artifact": [], "gate": [],
            "dupe": [f"{t} (line {n})" for t, n in dupes]}
    for tid, row in tasks.items():
        for d in row["deps"]:
            if d not in tasks:
                errs["dangling"].append(
                    f"{tid} (line {row['line']}): depends_on unknown {d}")
    wave, cyc = toposort(tasks, inject)
    if cyc:
        errs["cycle"].append("cycle among: " + ", ".join(cyc))
    # Tasks that can themselves provide a live managed run: the dispatch step
    # and the task that creates the scratch repository later proofs read.
    providers = {t for t, r in tasks.items()
                 if DISPATCH_RE.match(r["title"])
                 or re.search(r"tasks/" + re.escape(t) + r"/scratch-repo",
                              cells_text(r))}
    for tid, row in sorted(tasks.items()):
        anc = ancestors(tasks, tid)
        text = cells_text(row)
        seen = set()
        for m in ART_RE.finditer(text):
            prod, fname = m.group(1), m.group(2)
            if (prod, fname) in seen:
                continue
            if prod == tid or prod not in tasks:
                continue
            if AUTHOR_RE.search(text[:m.start()]):
                continue  # this row authors that file, it does not consume it
            seen.add((prod, fname))
            if prod not in anc:
                errs["artifact"].append(
                    f"{tid} (line {row['line']}): unproduced artifact "
                    f"tasks/{prod}/{fname} — {prod} is not an ancestor")
        # live-proof: a verify needing a live managed run must be a provider
        # itself or descend from one.
        if LIVE_RE.search(text) and providers and not (anc & providers) \
                and tid not in providers:
            errs["gate"].append(
                f"{tid} (line {row['line']}): live-proof gate — verify needs a "
                f"live managed run but neither it nor an ancestor provides one "
                f"({sorted(providers)})")
        for m in GATE_RE.finditer(text):
            frag = text[m.start():m.start() + 90].replace("\n", " ")
            # "X may start once <this row's work> ..." — X is the consumer
            head = text[max(0, m.start() - 40):m.start()]
            hids = IDREF_RE.findall(head)
            if hids and hids[-1] in tasks and hids[-1] != tid:
                cons = hids[-1]
                if tid not in ancestors(tasks, cons):
                    errs["gate"].append(
                        f"{tid} (line {row['line']}): prose gate "
                        f"\"{hids[-1]} {frag.strip()[:60]}\" — {cons} has no "
                        f"depends_on edge to {tid}")
                continue
            refs = set(IDREF_RE.findall(frag)) - {tid}
            miss = [r for r in sorted(refs) if r in tasks and r not in anc]
            gm = re.search(r"starts with M(\d+), after", frag)
            if gm:
                pre = {t for t in tasks if t.startswith(f"M{gm.group(1)}-")}
                if not (anc & pre) and not miss:
                    miss = [f"M{gm.group(1)}-*"]
            if miss:
                errs["gate"].append(
                    f"{tid} (line {row['line']}): prose gate \"{frag.strip()}\""
                    f" has no depends_on edge to {', '.join(miss)}")
    return errs, wave


def bundles(tasks, root):
    ok, bad = 0, []
    have_sc = shutil.which("shellcheck")
    try:
        import tomllib
    except ImportError:
        tomllib = None
    for tid, row in sorted(tasks.items()):
        d = os.path.join(root, "tasks", tid)
        probs = []
        for f in ("TASK.md", "task.toml", "verify.sh"):
            if not os.path.isfile(os.path.join(d, f)):
                probs.append(f"missing {f}")
        if not probs:
            if tomllib:
                try:
                    with open(os.path.join(d, "task.toml"), "rb") as fh:
                        tomllib.load(fh)
                except Exception as e:
                    probs.append(f"task.toml: {e}")
            vs = os.path.join(d, "verify.sh")
            if have_sc:
                p = subprocess.run(["shellcheck", "-s", "sh", vs],
                                   capture_output=True, text=True)
                if p.returncode:
                    first = (p.stdout.strip().splitlines() or [""])[0]
                    probs.append(f"shellcheck: {first}")
            else:
                probs.append("shellcheck not installed")
            with open(vs, encoding="utf-8") as fh:
                body = fh.read()
            for tok in sorted(set(re.findall(
                    r"^\s*([a-z][a-z0-9_.-]{1,20})\s", body, re.M))):
                if tok in ("if", "then", "else", "elif", "fi", "for", "do",
                           "done", "case", "esac", "while", "return", "exit",
                           "local", "set", "echo", "cd", "in"):
                    continue
                if not shutil.which(tok) and \
                        f"{tok}()" not in body and f"{tok} ()" not in body:
                    probs.append(f"verify.sh command not found: {tok}")
        for tok in sorted(set(re.findall(r"`([a-z][a-z0-9_-]{1,20})[ `]",
                                         row["verify"]))):
            if tok in ("test", "grep", "true", "false") or shutil.which(tok):
                continue
            probs.append(f"verify cell command not found: {tok}")
        if probs:
            bad.append(f"{tid}: " + "; ".join(sorted(set(probs))[:4]))
        else:
            ok += 1
    return ok, bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("roadmap", nargs="?", default="ROADMAP.md")
    ap.add_argument("--json", action="store_true", help="dump DAG as JSON")
    ap.add_argument("--bundles", action="store_true")
    ap.add_argument("--root", default=".", help="repo root for --bundles")
    ap.add_argument("--expect", type=int, default=81)
    ap.add_argument("--inject-cycle", nargs=2, metavar=("A", "B"),
                    help="add synthetic edge A depends_on B")
    a = ap.parse_args()

    tasks, dupes = parse(a.roadmap)
    inject = [tuple(a.inject_cycle)] if a.inject_cycle else []
    errs, wave = check(tasks, dupes, inject)

    # With --json, stdout carries only the JSON document; the human-readable
    # findings and summary go to stderr so the output stays parseable.
    out = sys.stderr if a.json else sys.stdout
    if a.json:
        print(json.dumps({
            "ids": sorted(tasks),
            "edges": sorted((t, d) for t in tasks for d in tasks[t]["deps"]),
            "waves": {t: wave.get(t, -1) for t in sorted(tasks)},
        }, indent=2))

    rc = 0
    if len(tasks) != a.expect:
        print(f"task count: {len(tasks)} found, {a.expect} expected", file=out)
        rc = 1
    for k in ("dupe", "dangling", "cycle", "artifact", "gate"):
        for e in errs[k]:
            print(f"{k}: {e}", file=out)
        if errs[k]:
            rc = 1
    if a.bundles:
        ok, bad = bundles(tasks, a.root)
        for b in bad:
            print(f"bundle: {b}", file=out)
        print(f"{ok}/{len(tasks)} bundles valid", file=out)
        if ok != len(tasks):
            rc = 1
    if rc == 0:
        print(f"{len(tasks)} tasks, 0 cycles, 0 unproduced artifacts, "
              f"0 prose gates", file=out)
    else:
        print(f"{len(tasks)} tasks, {len(errs['cycle'])} cycles, "
              f"{len(errs['artifact'])} unproduced artifacts, "
              f"{len(errs['gate'])} prose gates", file=out)
    return rc


if __name__ == "__main__":
    sys.exit(main())
