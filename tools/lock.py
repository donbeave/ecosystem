#!/usr/bin/env python3
"""Build and verify run/LOCK.toml, the immutable pin set of one run epoch.

A run must never track a moving reference. Every input the run depends on --
the reviewed plan snapshot, the external repositories, the 81 task bundles,
the models, the CLI tools, the container images, the permission profile --
is pinned here by an exact value. The words "main", "HEAD" and "latest" are
forbidden as values; a branch name may only appear inside a key.

Usage:
    python3 tools/lock.py write   [--out run/LOCK.toml] [--epoch N]
    python3 tools/lock.py check   [--file run/LOCK.toml]

`write` resolves everything from the working tree and the network (read-only
`git ls-remote`) and writes the file. `check` re-computes what can be
re-computed offline (bundle hashes, permission profile digest, lock hash) and
validates every recorded value, exiting non-zero on any drift.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LOCK_PATH = REPO / "run" / "LOCK.toml"

# The plan snapshot reviewed by the external round; row 0.2 (tagging it) is a
# human-only step, so `tag` stays empty until the human creates the tag.
PLAN_COMMIT_REF = "130cb4b7"

EXTERNAL_REPOS = [
    ("jackin", "https://github.com/jackin-project/jackin"),
    ("jackin_the_architect", "https://github.com/jackin-project/jackin-the-architect"),
    ("termrock", "https://github.com/tailrocks/termrock"),
]

ROLE_REPOS = [
    ("crew_builder", "https://github.com/donbeave/jackin-crew-builder"),
    ("crew_operator", "https://github.com/donbeave/jackin-crew-operator"),
    ("crew_reviewer", "https://github.com/donbeave/jackin-crew-reviewer"),
]

MODELS = {
    "host": "claude-fable-5",
    "host_effort": "high",
    "subagent": "claude-opus-5",
    "permission_mode": "bypassPermissions",
}

# name -> command producing one version line
CLI_TOOLS = [
    ("claude", ["claude", "--version"]),
    ("codex", ["codex", "--version"]),
    ("gh", ["gh", "--version"]),
    ("docker", ["docker", "--version"]),
    ("herdr", ["herdr", "--version"]),
    ("gitleaks", ["gitleaks", "version"]),
    ("shellcheck", ["shellcheck", "--version"]),
    ("op", ["op", "--version"]),
    ("jackin", ["jackin", "--version"]),
]

SHA_RE = re.compile(r"^[0-9a-f]{40}$")
FORBIDDEN_VALUES = {"main", "head", "latest"}
UNRESOLVED = "unresolved"


# --------------------------------------------------------------------------
# helpers


def run(cmd, cwd=None):
    """Run a command, returning stripped stdout or None when it fails."""
    try:
        out = subprocess.run(
            cmd, cwd=cwd, capture_output=True, text=True, timeout=60, check=False
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    return out.stdout.strip()


def toml_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def kv(key: str, value) -> str:
    if isinstance(value, int) and not isinstance(value, bool):
        return f"{key} = {value}"
    return f'{key} = "{toml_escape(str(value))}"'


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def lock_hash_of(text: str) -> str:
    """sha256 over the file content with the lock_hash line removed."""
    kept = [ln for ln in text.splitlines(keepends=True)
            if not ln.lstrip().startswith("lock_hash")]
    return sha256_bytes("".join(kept).encode())


# --------------------------------------------------------------------------
# resolvers


def plan_commit() -> str:
    sha = run(["git", "rev-parse", PLAN_COMMIT_REF], cwd=REPO)
    if not sha or not SHA_RE.match(sha):
        raise SystemExit(f"cannot resolve plan commit {PLAN_COMMIT_REF}")
    return sha


def plan_tag(commit: str) -> str:
    out = run(["git", "tag", "--points-at", commit], cwd=REPO)
    if not out:
        return ""
    return out.splitlines()[0].strip()


def ls_remote(url: str) -> dict:
    """Return {ref: sha} for the default branch and the feature branch."""
    out = run([
        "git", "ls-remote", url,
        "refs/heads/main", "refs/heads/master",
        "refs/heads/feat/managed-execution",
    ])
    refs = {}
    if not out:
        return refs
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 2 and SHA_RE.match(parts[0]):
            refs[parts[1]] = parts[0]
    return refs


def bundle_hashes() -> list:
    out = run([sys.executable, str(REPO / "tools" / "bundle.py"), "hash", "--all"])
    if not out:
        raise SystemExit("tools/bundle.py hash --all produced no output")
    entries = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) != 2:
            raise SystemExit(f"unexpected bundle hash line: {line}")
        entries.append((parts[0], parts[1]))
    return entries


def cli_versions() -> list:
    versions = []
    for name, cmd in CLI_TOOLS:
        if shutil.which(cmd[0]) is None:
            continue
        out = run(cmd)
        if not out:
            continue
        line = out.splitlines()[0].strip()
        if name == "shellcheck":
            for candidate in out.splitlines():
                if candidate.startswith("version:"):
                    line = candidate.strip()
                    break
        versions.append((name, line))
    return versions


def roadmap_images() -> list:
    """Container images the roadmap names, resolved to digests when possible."""
    roadmap = REPO / "ROADMAP.md"
    if not roadmap.exists():
        return []
    text = roadmap.read_text(encoding="utf-8")
    names = sorted(set(re.findall(r"ghcr\.io/[^\s`)\'\"|]+", text)))
    images = []
    for ref in names:
        digest = UNRESOLVED
        out = run(["docker", "manifest", "inspect", "-v", ref]) if shutil.which("docker") else None
        if out:
            try:
                data = json.loads(out)
                if isinstance(data, list):
                    data = data[0]
                digest = data.get("Descriptor", {}).get("digest") or UNRESOLVED
            except (ValueError, AttributeError, IndexError, KeyError):
                digest = UNRESOLVED
        images.append((ref, digest))
    return images


def permission_profile_sha() -> str:
    path = REPO / ".claude" / "settings.json"
    if not path.exists():
        raise SystemExit("missing .claude/settings.json")
    return sha256_bytes(path.read_bytes())


def key_for_image(ref: str) -> str:
    return re.sub(r"[^0-9a-zA-Z]+", "_", ref).strip("_")


# --------------------------------------------------------------------------
# write


def render(epoch: int) -> str:
    commit = plan_commit()
    tag = plan_tag(commit)

    lines = []
    lines.append("# run/LOCK.toml -- immutable pin set for one run epoch.")
    lines.append("# Generated by tools/lock.py write; verified by tools/lock.py check.")
    lines.append("# No value may be a moving reference: the words main, HEAD and latest")
    lines.append("# are forbidden as values, and every commit is a full 40-hex sha.")
    lines.append("")
    lines.append("[plan]")
    lines.append(kv("commit", commit))
    if tag:
        lines.append(kv("tag", tag))
    else:
        lines.append(kv("tag", ""))
        lines.append("# tag is empty: creating the review tag is a human-only step")
        lines.append("# (readiness plan row 0.2). Fill it in and re-run write.")
    lines.append("")

    lines.append("[external]")
    pending_external = []
    for name, url in EXTERNAL_REPOS:
        refs = ls_remote(url)
        default = refs.get("refs/heads/main") or refs.get("refs/heads/master")
        if default:
            lines.append(kv(f"{name}_default", default))
        else:
            pending_external.append(name)
        feature = refs.get("refs/heads/feat/managed-execution")
        if feature:
            lines.append(kv(f"{name}_managed_execution", feature))
    if pending_external:
        lines.append(
            "pending = ["
            + ", ".join(f'"{toml_escape(n)}"' for n in pending_external)
            + "]"
        )
    else:
        lines.append("pending = []")
    lines.append("")

    lines.append("[roles]")
    lines.append("# Role repositories are created by milestone M3; those that do not")
    lines.append("# exist yet are listed in pending and pinned on their first run.")
    pending_roles = []
    for name, url in ROLE_REPOS:
        refs = ls_remote(url)
        default = refs.get("refs/heads/main") or refs.get("refs/heads/master")
        if default:
            lines.append(kv(f"{name}_default", default))
        else:
            pending_roles.append(name)
    lines.append(
        "pending = ["
        + ", ".join(f'"{toml_escape(n)}"' for n in pending_roles)
        + "]"
    )
    lines.append("")

    lines.append("[bundles]")
    for task_id, digest in bundle_hashes():
        lines.append(f'"{toml_escape(task_id)}" = "{toml_escape(digest)}"')
    lines.append("")

    lines.append("[models]")
    for key in ("host", "host_effort", "subagent", "permission_mode"):
        lines.append(kv(key, MODELS[key]))
    lines.append("")

    lines.append("[cli]")
    for name, version in cli_versions():
        lines.append(kv(name, version))
    lines.append("")

    lines.append("[images]")
    images = roadmap_images()
    if not images:
        lines.append("# The roadmap names no ghcr.io image; nothing to pin.")
    for ref, digest in images:
        lines.append(kv(key_for_image(ref), f"{ref}@{digest}" if digest != UNRESOLVED else UNRESOLVED))
    lines.append("")

    lines.append("[permissions]")
    lines.append(kv("profile_sha256", permission_profile_sha()))
    lines.append("")

    lines.append("[run]")
    lines.append(kv("epoch", epoch))
    body = "\n".join(lines) + "\n"
    digest = lock_hash_of(body)
    return body + kv("lock_hash", digest) + "\n"


def cmd_write(args) -> int:
    out_path = Path(args.out) if args.out else LOCK_PATH
    out_path.parent.mkdir(parents=True, exist_ok=True)
    text = render(args.epoch)
    out_path.write_text(text, encoding="utf-8")
    print(f"wrote {out_path.relative_to(REPO) if out_path.is_relative_to(REPO) else out_path}")
    return 0


# --------------------------------------------------------------------------
# check


def iter_values(data, path=""):
    if isinstance(data, dict):
        for key, value in data.items():
            yield from iter_values(value, f"{path}.{key}" if path else key)
    elif isinstance(data, list):
        for index, value in enumerate(data):
            yield from iter_values(value, f"{path}[{index}]")
    else:
        yield path, data


def cmd_check(args) -> int:
    path = Path(args.file) if args.file else LOCK_PATH
    problems = []
    if not path.exists():
        print(f"FAIL missing {path}")
        return 1
    text = path.read_text(encoding="utf-8")
    data = tomllib.loads(text)

    # 1. no moving reference anywhere in the values
    for key, value in iter_values(data):
        if isinstance(value, str) and value.strip().lower() in FORBIDDEN_VALUES:
            problems.append(f"moving reference at {key}: {value!r}")

    # 2. every commit-shaped field is a full 40-hex sha
    for section in ("plan", "external", "roles"):
        for key, value in (data.get(section) or {}).items():
            if key in ("tag", "pending"):
                continue
            if not (isinstance(value, str) and SHA_RE.match(value)):
                problems.append(f"{section}.{key} is not a 40-hex sha: {value!r}")

    # 3. bundle hashes match the working tree, and all 81 are present
    bundles = data.get("bundles") or {}
    try:
        current = dict(bundle_hashes())
    except SystemExit as exc:
        problems.append(str(exc))
        current = {}
    if current:
        if len(bundles) != len(current):
            problems.append(
                f"bundle count drift: lock has {len(bundles)}, tree has {len(current)}"
            )
        for task_id, digest in current.items():
            recorded = bundles.get(task_id)
            if recorded is None:
                problems.append(f"bundle {task_id} missing from the lock")
            elif recorded != digest:
                problems.append(f"bundle {task_id} drifted")
        for task_id in bundles:
            if task_id not in current:
                problems.append(f"bundle {task_id} in the lock is gone from the tree")
    for task_id, digest in bundles.items():
        if not re.match(r"^[0-9a-f]{64}$", str(digest)):
            problems.append(f"bundle {task_id} hash is not sha256 hex")

    # 4. models are exactly the pinned set
    models = data.get("models") or {}
    for key, value in MODELS.items():
        if models.get(key) != value:
            problems.append(f"models.{key} is {models.get(key)!r}, expected {value!r}")

    # 5. Herdr is the host process/session owner. The lock must pin the exact
    # binary that will keep the interactive coordinator alive; accepting an
    # absent or stale entry would make restart behavior depend on host drift.
    herdr = run(["herdr", "--version"]) if shutil.which("herdr") else None
    recorded_herdr = (data.get("cli") or {}).get("herdr")
    if not herdr:
        problems.append("required CLI herdr is not installed")
    elif recorded_herdr != herdr.splitlines()[0].strip():
        problems.append(
            f"cli.herdr is {recorded_herdr!r}, expected {herdr.splitlines()[0].strip()!r}"
        )

    # 6. permission profile digest matches the file on disk
    try:
        expected = permission_profile_sha()
    except SystemExit as exc:
        problems.append(str(exc))
        expected = None
    recorded = (data.get("permissions") or {}).get("profile_sha256")
    if expected and recorded != expected:
        problems.append("permissions.profile_sha256 drifted from .claude/settings.json")

    # 7. plan commit still resolves to the same object
    try:
        if (data.get("plan") or {}).get("commit") != plan_commit():
            problems.append("plan.commit drifted from the reviewed snapshot")
    except SystemExit as exc:
        problems.append(str(exc))

    # 8. run epoch and the self hash
    epoch = (data.get("run") or {}).get("epoch")
    if not isinstance(epoch, int) or epoch < 1:
        problems.append(f"run.epoch is not a positive integer: {epoch!r}")
    recorded_hash = (data.get("run") or {}).get("lock_hash")
    actual_hash = lock_hash_of(text)
    if recorded_hash != actual_hash:
        problems.append("run.lock_hash does not match the file content")

    if problems:
        for problem in problems:
            print(f"FAIL {problem}")
        return 1
    print(f"OK {path.name}: {len(bundles)} bundles, epoch {epoch}, no drift")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    writer = sub.add_parser("write", help="generate run/LOCK.toml")
    writer.add_argument("--out", default=None)
    writer.add_argument("--epoch", type=int, default=1)
    writer.set_defaults(func=cmd_write)
    checker = sub.add_parser("check", help="verify run/LOCK.toml against the tree")
    checker.add_argument("--file", default=None)
    checker.set_defaults(func=cmd_check)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
