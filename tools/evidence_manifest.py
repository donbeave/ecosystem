#!/usr/bin/env python3
"""Per-task evidence manifest: write and validate `tasks/<id>/evidence.json`.

The manifest is the machine record of what a run actually produced for one
task: which commands ran, with which exit codes, what their output hashed
to, which tool versions were present, which external objects were created,
and which commit the verification ran against. It exists so that a task
reaches `done` because of recorded evidence rather than because the
implementing agent said so (K-30).

Python 3 standard library only.

Usage:

    evidence_manifest.py run --task <id> --bundle-hash <h> \
        --integrated-sha <sha> [--repository <repo> <branch> <sha> <checkout>] \
        [options] -- <cmd> [-- <cmd> ...]
    evidence_manifest.py validate <path> | --all [--root <dir>]

`run` executes each command, hashes stdout and stderr, records the exit
code and the start/finish timestamps, and writes the manifest atomically
(temporary file in the same directory, then `os.replace`). Repeated `run`
invocations against the same manifest append to `commands` and refresh the
scalar fields.

`validate` enforces the acceptance semantics of
`jq -e '.integrated_sha and .commands and .bundle_hash'` plus the
40-hex-SHA shape and the `result_class` enum, and exits non-zero on the
first failure.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

RESULT_CLASSES = ("DONE", "BLOCKED HUMAN", "FAILED SYSTEM", "PENDING")
HEX40 = re.compile(r"\A[0-9a-f]{40}\Z")
HEX64 = re.compile(r"\A[0-9a-f]{64}\Z")

MANIFEST_NAME = "evidence.json"

# Tools whose version is recorded when they are on PATH.
DEFAULT_TOOL_VERSIONS = (
    ("git", ("git", "--version")),
    ("jq", ("jq", "--version")),
    ("python3", ("python3", "--version")),
    ("gitleaks", ("gitleaks", "version")),
    ("gh", ("gh", "--version")),
    ("docker", ("docker", "--version")),
)


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def tool_versions() -> dict:
    versions = {}
    for name, cmd in DEFAULT_TOOL_VERSIONS:
        if shutil.which(cmd[0]) is None:
            continue
        try:
            out = subprocess.run(
                cmd, capture_output=True, text=True, timeout=30, check=False
            )
        except (OSError, subprocess.SubprocessError):
            continue
        line = (out.stdout or out.stderr or "").strip().splitlines()
        if line:
            versions[name] = line[0].strip()
    return versions


def split_commands(argv: list) -> list:
    """Split the trailing argument list into one or more commands on `--`."""
    commands, current = [], []
    for arg in argv:
        if arg == "--":
            if current:
                commands.append(current)
                current = []
            continue
        current.append(arg)
    if current:
        commands.append(current)
    return commands


def load(path: str) -> dict:
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as handle:
        try:
            return json.load(handle)
        except json.JSONDecodeError as exc:
            raise SystemExit("%s: not valid JSON: %s" % (path, exc))


def write_atomic(path: str, manifest: dict) -> None:
    directory = os.path.dirname(os.path.abspath(path)) or "."
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".evidence-", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(manifest, handle, indent=2, sort_keys=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def parse_pairs(values: list) -> dict:
    """Parse `key=value` arguments into a dictionary."""
    out = {}
    for item in values or []:
        if "=" not in item:
            raise SystemExit("expected key=value, got %r" % item)
        key, value = item.split("=", 1)
        key = key.strip()
        if not key:
            raise SystemExit("empty key in %r" % item)
        out.setdefault(key, [])
        out[key].append(value)
    return {k: (v[0] if len(v) == 1 else v) for k, v in out.items()}


def cmd_run(args: argparse.Namespace) -> int:
    commands = split_commands(args.command)
    if not commands:
        raise SystemExit("no command given; pass it after `--`")

    path = args.manifest or os.path.join(args.dir or ".", MANIFEST_NAME)
    manifest = load(path)

    manifest["task"] = args.task
    manifest["bundle_hash"] = args.bundle_hash
    manifest["integrated_sha"] = args.integrated_sha
    if args.repository:
        manifest["repositories"] = [
            {
                "repo": repo,
                "branch": branch,
                "integrated_sha": integrated_sha,
                "checkout": checkout,
            }
            for repo, branch, integrated_sha, checkout in args.repository
        ]
    else:
        manifest.pop("repositories", None)
    manifest["attempt"] = args.attempt
    manifest["epoch"] = args.epoch
    manifest["fencing_token"] = args.fencing_token
    manifest.setdefault("created", now())
    manifest.setdefault("commands", [])
    external = manifest.setdefault("external_object_ids", {})
    external.update(parse_pairs(args.external))
    manifest["tool_versions"] = tool_versions()

    worst = 0
    for cmd in commands:
        started = now()
        try:
            proc = subprocess.run(cmd, capture_output=True, check=False)
            exit_code, stdout, stderr = proc.returncode, proc.stdout, proc.stderr
        except OSError as exc:
            exit_code = 127
            stdout = b""
            stderr = str(exc).encode()
        finished = now()
        worst = max(worst, 1 if exit_code else 0)
        manifest["commands"].append(
            {
                "cmd": cmd,
                "exit_code": exit_code,
                "stdout_sha256": sha256_bytes(stdout),
                "stderr_sha256": sha256_bytes(stderr),
                "started": started,
                "finished": finished,
            }
        )
        sys.stdout.write(stdout.decode("utf-8", "replace"))
        sys.stderr.write(stderr.decode("utf-8", "replace"))

    if args.result_class:
        manifest["result_class"] = args.result_class
    elif worst:
        manifest["result_class"] = "FAILED SYSTEM"
    else:
        manifest.setdefault("result_class", "PENDING")

    manifest["updated"] = now()
    write_atomic(path, manifest)
    print("manifest: %s" % path)
    return worst


def problems(manifest: dict, path: str) -> list:
    found = []

    def fail(msg):
        found.append("%s: %s" % (path, msg))

    # `jq -e '.integrated_sha and .commands and .bundle_hash'` semantics:
    # each field must be present and truthy (not null, not false, and for
    # this manifest not an empty string or an empty array either).
    for field in ("integrated_sha", "commands", "bundle_hash"):
        if field not in manifest:
            fail("missing %s" % field)
        elif manifest[field] in (None, False, "", [], {}):
            fail("empty %s" % field)

    task = manifest.get("task")
    if not isinstance(task, str) or not task.strip():
        fail("task must be a non-empty string")

    sha = manifest.get("integrated_sha")
    if isinstance(sha, str) and not HEX40.match(sha):
        fail("integrated_sha must be 40 lowercase hex characters")

    repositories = manifest.get("repositories")
    if repositories is not None:
        if not isinstance(repositories, list) or not repositories:
            fail("repositories must be a non-empty array when present")
            repositories = []
        seen_repositories = set()
        for index, entry in enumerate(repositories or []):
            where = "repositories[%d]" % index
            if not isinstance(entry, dict):
                fail("%s must be an object" % where)
                continue
            for field in ("repo", "branch", "checkout"):
                value = entry.get(field)
                if not isinstance(value, str) or not value.strip():
                    fail("%s.%s must be a non-empty string" % (where, field))
                elif any(separator in value for separator in ("\t", "\r", "\n")):
                    fail("%s.%s must not contain tabs or newlines" % (where, field))
            repo = entry.get("repo")
            if isinstance(repo, str):
                if repo in seen_repositories:
                    fail("repositories contains duplicate repo %s" % repo)
                seen_repositories.add(repo)
            repo_sha = entry.get("integrated_sha")
            if not isinstance(repo_sha, str) or not HEX40.match(repo_sha):
                fail("%s.integrated_sha must be 40 lowercase hex characters" % where)
        if repositories and isinstance(repositories[0], dict):
            first_sha = repositories[0].get("integrated_sha")
            if isinstance(sha, str) and sha != first_sha:
                fail("integrated_sha must equal repositories[0].integrated_sha")

    bundle = manifest.get("bundle_hash")
    if isinstance(bundle, str) and not (HEX40.match(bundle) or HEX64.match(bundle)):
        fail("bundle_hash must be 40 or 64 lowercase hex characters")

    result_class = manifest.get("result_class")
    if result_class not in RESULT_CLASSES:
        fail("result_class must be one of %s" % ", ".join(RESULT_CLASSES))

    commands = manifest.get("commands")
    if commands is not None and not isinstance(commands, list):
        fail("commands must be an array")
        commands = []
    for index, entry in enumerate(commands or []):
        where = "commands[%d]" % index
        if not isinstance(entry, dict):
            fail("%s must be an object" % where)
            continue
        cmd = entry.get("cmd")
        if not (isinstance(cmd, list) and cmd and all(isinstance(a, str) for a in cmd)):
            fail("%s.cmd must be a non-empty array of strings" % where)
        if not isinstance(entry.get("exit_code"), int):
            fail("%s.exit_code must be an integer" % where)
        for field in ("stdout_sha256", "stderr_sha256"):
            value = entry.get(field)
            if not (isinstance(value, str) and HEX64.match(value)):
                fail("%s.%s must be 64 lowercase hex characters" % (where, field))
        for field in ("started", "finished"):
            if not isinstance(entry.get(field), str) or not entry.get(field):
                fail("%s.%s must be a timestamp string" % (where, field))

    if not isinstance(manifest.get("tool_versions", {}), dict):
        fail("tool_versions must be an object")
    if not isinstance(manifest.get("external_object_ids", {}), dict):
        fail("external_object_ids must be an object")
    for field in ("attempt", "epoch", "fencing_token"):
        value = manifest.get(field)
        if value is not None and not isinstance(value, int):
            fail("%s must be an integer" % field)

    return found


def cmd_validate(args: argparse.Namespace) -> int:
    paths = []
    if args.all:
        root = args.root or "tasks"
        for entry in sorted(os.listdir(root)) if os.path.isdir(root) else []:
            candidate = os.path.join(root, entry, MANIFEST_NAME)
            if os.path.isfile(candidate):
                paths.append(candidate)
    if args.path:
        paths.append(args.path)
    if not paths:
        if args.all:
            print("no manifests found")
            return 0
        raise SystemExit("give a manifest path or --all")

    failures = 0
    for path in paths:
        if not os.path.isfile(path):
            print("%s: missing" % path)
            failures += 1
            continue
        found = problems(load(path), path)
        if found:
            failures += 1
            for line in found:
                print(line)
        else:
            print("%s: ok" % path)
    return 1 if failures else 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="subcommand", required=True)

    run = sub.add_parser("run", help="run commands and record the manifest")
    run.add_argument("--task", required=True, help="task id")
    run.add_argument("--bundle-hash", required=True, help="task bundle hash")
    run.add_argument(
        "--integrated-sha",
        required=True,
        help=(
            "exact 40-hex integration head the verification and task "
            "transition run against; a later final gate verifies ancestry"
        ),
    )
    run.add_argument(
        "--repository", action="append", nargs=4,
        metavar=("REPO", "BRANCH", "SHA", "CHECKOUT"),
        help=(
            "exact per-repository integration evidence at task transition; "
            "repeat for every involved repo"
        ),
    )
    run.add_argument("--dir", help="task folder (default: working directory)")
    run.add_argument("--manifest", help="manifest path (default: <dir>/evidence.json)")
    run.add_argument("--attempt", type=int, default=1)
    run.add_argument("--epoch", type=int, default=1)
    run.add_argument("--fencing-token", type=int, default=0)
    run.add_argument("--result-class", choices=list(RESULT_CLASSES))
    run.add_argument("--external", action="append", metavar="KEY=VALUE",
                     help="external object id, e.g. pr_url=... , repeatable")
    run.add_argument("command", nargs=argparse.REMAINDER,
                     help="-- <cmd...> ; repeat `--` to record several commands")
    run.set_defaults(func=cmd_run)

    validate = sub.add_parser("validate", help="validate one manifest or all of them")
    validate.add_argument("path", nargs="?", help="manifest path")
    validate.add_argument("--all", action="store_true",
                          help="validate every tasks/<id>/evidence.json")
    validate.add_argument("--root", help="task root for --all (default: tasks)")
    validate.set_defaults(func=cmd_validate)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
