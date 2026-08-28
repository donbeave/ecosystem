#!/usr/bin/env python3
"""Check findings/disposition.toml against the repository.

Asserts: the row count equals the archive count declared in the header
table (76); no row has an empty disposition or empty evidence; every
`fixed` row names a file, a positive line and a quote, and that quote
still occurs exactly once in that file.

The quote, not the line number, is the anchor: an unrelated edit above a
finding shifts every line below it, and a line-exact check would then
fail on rows that are still true. The line stays in the schema as a
diagnostic -- when it disagrees with the located line the check prints a
`drift` line naming both, and stays green. A quote that no longer occurs
is a failure, and so is one that occurs more than once, because an
ambiguous quote cannot anchor anything.

Exits non-zero and prints one line per failure otherwise.
"""
import pathlib
import sys
import tomllib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOC = ROOT / "findings" / "disposition.toml"
ALLOWED = {"fixed", "open", "disproved", "duplicate", "host-probe-required"}


def locate(text: str, quote: str) -> list[int]:
    """Return the 1-based start line of every occurrence of quote in text.

    A single-line quote is anchored per line, so a quote that occurs twice
    on one line still anchors that one line. A quote that spans lines --
    the escape hatch for a line whose whole text also occurs inside a
    longer line elsewhere -- is matched against the raw text.
    """
    if "\n" in quote:
        starts = []
        at = text.find(quote)
        while at != -1:
            starts.append(text.count("\n", 0, at) + 1)
            at = text.find(quote, at + 1)
        return starts
    return [n for n, line in enumerate(text.splitlines(), 1) if quote in line]


def main() -> int:
    data = tomllib.loads(DOC.read_text(encoding="utf-8"))
    findings = data.get("finding", [])
    expected = data.get("archive", {}).get("count")
    errors = []

    if expected is None:
        errors.append("archive.count is missing")
    elif len(findings) != expected:
        errors.append(f"row count {len(findings)} != archive.count {expected}")

    seen = set()
    drifted = []
    for f in findings:
        fid = f.get("id", "<no id>")
        if fid in seen:
            errors.append(f"{fid}: duplicate id")
        seen.add(fid)
        disposition = (f.get("disposition") or "").strip()
        if not disposition:
            errors.append(f"{fid}: empty disposition")
        elif disposition not in ALLOWED:
            errors.append(f"{fid}: unknown disposition {disposition!r}")
        if not (f.get("evidence") or "").strip():
            errors.append(f"{fid}: empty evidence")
        if disposition != "fixed":
            continue
        path, line, quote = f.get("file"), f.get("line"), f.get("quote")
        if not path or not line or not (quote or "").strip():
            errors.append(f"{fid}: fixed row lacks file, line or quote")
            continue
        target = ROOT / path
        if not target.is_file():
            errors.append(f"{fid}: {path} does not exist")
            continue
        if not isinstance(line, int) or line < 1:
            errors.append(f"{fid}: line {line!r} is not a positive line number")
            continue
        matches = locate(target.read_text(encoding="utf-8"), quote)
        if not matches:
            errors.append(f"{fid}: {path} no longer contains its quote")
        elif len(matches) > 1:
            shown = ", ".join(str(n) for n in matches[:5])
            errors.append(
                f"{fid}: {path} quote is ambiguous, it matches lines {shown}")
        elif matches[0] != line:
            drifted.append(f"{fid}: {path}:{line} -> {matches[0]}")

    for e in errors:
        print(f"FAIL {e}")
    if errors:
        return 1
    counts = {}
    for f in findings:
        counts[f["disposition"]] = counts.get(f["disposition"], 0) + 1
    for d in drifted:
        print(f"drift {d}")
    print(f"rows: {len(findings)} (archive.count {expected})")
    for k in sorted(counts):
        print(f"{k}: {counts[k]}")
    print("status: DONE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
