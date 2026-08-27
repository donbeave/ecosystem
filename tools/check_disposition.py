#!/usr/bin/env python3
"""Check findings/disposition.toml against the repository.

Asserts: the row count equals the archive count declared in the header
table (76); no row has an empty disposition or empty evidence; every
`fixed` row names a file and line whose text still contains its quote.
Exits non-zero and prints one line per failure otherwise.
"""
import pathlib
import sys
import tomllib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOC = ROOT / "findings" / "disposition.toml"
ALLOWED = {"fixed", "open", "disproved", "duplicate", "host-probe-required"}


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
        lines = target.read_text(encoding="utf-8").splitlines()
        if line < 1 or line > len(lines):
            errors.append(f"{fid}: {path}:{line} is out of range")
        elif quote not in lines[line - 1]:
            errors.append(f"{fid}: {path}:{line} no longer contains its quote")

    for e in errors:
        print(f"FAIL {e}")
    if errors:
        return 1
    counts = {}
    for f in findings:
        counts[f["disposition"]] = counts.get(f["disposition"], 0) + 1
    print(f"rows: {len(findings)} (archive.count {expected})")
    for k in sorted(counts):
        print(f"{k}: {counts[k]}")
    print("status: DONE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
