#!/usr/bin/env python3
"""Verify M1-12's captured Linear mirror against the locked task graph.

The input is a two-pass GraphQL snapshot.  Requiring both observations makes
idempotence, immutable source URLs, and early-start backfill machine-checkable
without placing a Linear credential in this verifier.
"""
import argparse
import hashlib
import json
import re
import subprocess
import tomllib
from pathlib import Path

import roadmap_compile as rc

EARLY_START = {"M3-01", "M3-03", "M4-02", "M4-03"}
STATE_TYPE = {
    "planned": "unstarted",
    "ready": "unstarted",
    "blocked": "unstarted",
    "in-progress": "started",
    "waiting": "started",
    "done": "completed",
}
SHA40 = re.compile(r"^[0-9a-f]{40}$")
BUNDLE_FILES = ["TASK.md", "expected-evidence.toml", "refs/sources.txt",
                "task.toml", "verify.sh"]


def fail(message):
    print("FAIL " + message)
    raise SystemExit(1)


def load_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        fail(f"cannot read {path}: {exc}")


def task_statuses(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    header = next((rc.split_row(line) for line in lines
                   if line.startswith("|") and "Task" in line and
                   "Status" in line), None)
    if header is None:
        fail("tasks/README.md has no Task/Status header")
    task_i, status_i = header.index("Task"), header.index("Status")
    rows = {}
    for line in lines:
        if not re.match(r"^\|\s*M\d+-\d+[a-z]*\s*\|", line):
            continue
        cells = rc.split_row(line)
        rows[cells[task_i]] = cells[status_i]
    return rows


def git_output(root, args, binary=False):
    proc = subprocess.run(["git", "-C", str(root), *args], capture_output=True,
                          text=not binary, check=False)
    if proc.returncode:
        detail = proc.stderr.decode(errors="replace") if binary else proc.stderr
        fail(f"git {' '.join(args)} failed: {detail.strip()}")
    return proc.stdout


def locked_blob(root, source, path):
    return git_output(root, ["show", f"{source}:{path}"], binary=True)


def locked_paths(root, source, prefix):
    output = git_output(root, ["ls-tree", "-r", "--name-only", source, "--", prefix])
    return sorted(line for line in output.splitlines() if line)


def locked_bundle_hash(root, source, task_id):
    digest = hashlib.sha256()
    for name in BUNDLE_FILES:
        body = locked_blob(root, source, f"tasks/{task_id}/{name}")
        digest.update(name.encode())
        digest.update(b"\0")
        digest.update(str(len(body)).encode())
        digest.update(b"\0")
        digest.update(body)
    return digest.hexdigest()


def task_config(root, source, task_id):
    path = f"tasks/{task_id}/task.toml"
    try:
        return tomllib.loads(locked_blob(root, source, path).decode())
    except (UnicodeDecodeError, ValueError) as exc:
        fail(f"cannot read {path}: {exc}")


def expected_issue(root, task_id, status, source, lanes, mirrored, lock_bundles):
    actual_hash = locked_bundle_hash(root, source, task_id)
    if lock_bundles.get(task_id) != actual_hash:
        fail(f"{task_id}: plan.commit bundle bytes do not match run/LOCK.toml")
    cfg = task_config(root, source, task_id)
    lane = lanes.get(cfg["lane"])
    if not isinstance(lane, dict):
        fail(f"{task_id}: lane {cfg['lane']} absent from M1-13/lanes.json")
    try:
        task_text = locked_blob(root, source, f"tasks/{task_id}/TASK.md").decode()
    except UnicodeDecodeError as exc:
        fail(f"{task_id}: locked TASK.md is not UTF-8: {exc}")
    first = ("task_source: https://github.com/tailrocks/ecosystem/tree/"
             f"{source}/tasks/{task_id}")
    description = first + "\n" + task_text
    attachment_paths = ["task.toml", "verify.sh", "expected-evidence.toml"]
    prefix = f"tasks/{task_id}/"
    attachment_paths += [path.removeprefix(prefix) for path in
                         locked_paths(root, source, prefix + "refs/")]
    attachments = {
        path: ("https://raw.githubusercontent.com/tailrocks/ecosystem/"
               f"{source}/tasks/{task_id}/{path}")
        for path in attachment_paths
    }
    labels = {
        f"role:{cfg['role']}", f"agent:{cfg['runtime']}",
        f"lane:{cfg['lane']}", lane["label"],
        f"effort:{lane['effort']}", f"delivery:{cfg['delivery']}",
        f"repo:{cfg['repo']}", "auto-dispatch",
    }
    blockers = sorted(dep for dep in cfg.get("depends_on", []) if dep in mirrored)
    return {
        "title": f"{task_id} {cfg['title']}",
        "milestone": task_id.split("-", 1)[0],
        "source_commit": source,
        "task_source": first,
        "description": description,
        "description_sha256": hashlib.sha256(description.encode()).hexdigest(),
        "labels": labels,
        "state_type": STATE_TYPE.get(status),
        "blockers": blockers,
        "attachments": attachments,
    }


def require_string(item, key, task_id):
    value = item.get(key)
    if not isinstance(value, str) or not value:
        fail(f"{task_id}: {key} must be a non-empty string")
    return value


def issue_map(pass_data, expected, pass_number):
    issues = pass_data.get("issues") if isinstance(pass_data, dict) else None
    if not isinstance(issues, list):
        fail(f"pass {pass_number}: issues must be a list")
    by_task = {}
    identities = {"id": set(), "identifier": set(), "url": set()}
    for item in issues:
        if not isinstance(item, dict):
            fail(f"pass {pass_number}: issue entry is not an object")
        task_id = require_string(item, "task_id", f"pass {pass_number}")
        if task_id in by_task:
            fail(f"pass {pass_number}: duplicate task {task_id}")
        by_task[task_id] = item
        for key in identities:
            value = require_string(item, key, task_id)
            if value in identities[key]:
                fail(f"pass {pass_number}: duplicate {key} {value}")
            identities[key].add(value)
    if set(by_task) != set(expected):
        missing = sorted(set(expected) - set(by_task))
        extra = sorted(set(by_task) - set(expected))
        fail(f"pass {pass_number}: task set mismatch; missing={missing}, extra={extra}")
    return by_task


def check_issue(task_id, item, want, pass_number, team_id, project_id,
                milestone_ids, workflow):
    for key in ("title", "milestone", "source_commit", "task_source",
                "state_type"):
        if item.get(key) != want[key]:
            fail(f"pass {pass_number} {task_id}: {key} mismatch")
    description = require_string(item, "description", task_id)
    if hashlib.sha256(description.encode()).hexdigest() != want["description_sha256"]:
        fail(f"pass {pass_number} {task_id}: captured description hash mismatch")
    if description != want["description"]:
        fail(f"pass {pass_number} {task_id}: captured description bytes mismatch")
    if "delegate_id" not in item or item["delegate_id"] is not None:
        fail(f"pass {pass_number} {task_id}: delegate_id must be explicit null")
    if item.get("team_id") != team_id or item.get("project_id") != project_id:
        fail(f"pass {pass_number} {task_id}: team/project membership mismatch")
    if item.get("milestone_id") != milestone_ids[want["milestone"]]:
        fail(f"pass {pass_number} {task_id}: milestone membership mismatch")
    state_key = {"unstarted": "unstarted", "started": "first_started",
                 "completed": "completed"}[want["state_type"]]
    if item.get("state_id") != workflow[state_key]["id"]:
        fail(f"pass {pass_number} {task_id}: workflow state id mismatch")
    if set(item.get("labels", [])) != want["labels"]:
        fail(f"pass {pass_number} {task_id}: canonical labels mismatch")
    if sorted(item.get("blockers", [])) != want["blockers"]:
        fail(f"pass {pass_number} {task_id}: blockers mismatch")
    attachments = item.get("attachments")
    if not isinstance(attachments, list):
        fail(f"pass {pass_number} {task_id}: attachments must be a list")
    actual = {}
    for entry in attachments:
        if not isinstance(entry, dict):
            fail(f"pass {pass_number} {task_id}: attachment is not an object")
        title = require_string(entry, "title", task_id)
        if title in actual:
            fail(f"pass {pass_number} {task_id}: duplicate attachment {title}")
        actual[title] = require_string(entry, "url", task_id)
    if actual != want["attachments"]:
        fail(f"pass {pass_number} {task_id}: immutable attachments mismatch")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot")
    parser.add_argument("--root", type=Path,
                        default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    root = args.root.resolve()
    snapshot = load_json(Path(args.snapshot))
    try:
        lock = tomllib.loads((root / "run/LOCK.toml").read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        fail(f"cannot read run/LOCK.toml: {exc}")
    source = (lock.get("plan") or {}).get("commit")
    if not isinstance(source, str) or not SHA40.match(source):
        fail("run/LOCK.toml plan.commit is not 40 lowercase hex")
    statuses = task_statuses(root / "tasks/README.md")
    mirrored = {task_id for task_id, status in statuses.items()
                if not task_id.startswith("M1-") and status != "planned"}
    mirrored |= EARLY_START
    lanes = load_json(root / "tasks/M1-13/lanes.json")
    lock_bundles = lock.get("bundles") or {}
    expected = {}
    for task_id in sorted(mirrored):
        status = statuses.get(task_id)
        if status not in STATE_TYPE:
            fail(f"{task_id}: status {status!r} has no Linear projection")
        expected[task_id] = expected_issue(
            root, task_id, status, source, lanes, mirrored, lock_bundles)

    team = snapshot.get("team") if isinstance(snapshot, dict) else None
    project = snapshot.get("project") if isinstance(snapshot, dict) else None
    if not isinstance(team, dict) or team.get("key") != "JACKIN" or not team.get("id"):
        fail("team must contain non-empty id and key JACKIN")
    if not isinstance(project, dict) or not project.get("id"):
        fail("project must contain a non-empty id")
    milestone_rows = project.get("milestones")
    if not isinstance(milestone_rows, list):
        fail("project milestones must be a list")
    milestone_ids = {}
    for item in milestone_rows:
        if not isinstance(item, dict) or not item.get("id") or not item.get("name"):
            fail("every milestone must contain non-empty id and name")
        if item["name"] in milestone_ids:
            fail(f"duplicate milestone {item['name']}")
        milestone_ids[item["name"]] = item["id"]
    if set(milestone_ids) != {f"M{i}" for i in range(1, 13)}:
        fail("project milestones must be exactly M1..M12")
    workflow = snapshot.get("workflow_states")
    if not isinstance(workflow, dict) or set(workflow) != {
            "unstarted", "first_started", "completed"}:
        fail("workflow_states must name unstarted, first_started, completed")
    for key, state_type in (("unstarted", "unstarted"),
                            ("first_started", "started"),
                            ("completed", "completed")):
        state = workflow[key]
        if not isinstance(state, dict) or not state.get("id") or state.get("type") != state_type:
            fail(f"workflow state {key} has wrong id/type")
    if workflow["first_started"].get("name") in ("Review", "Merging"):
        fail("first started state cannot be Review or Merging")
    passes = snapshot.get("passes")
    if not isinstance(passes, list) or len(passes) != 2:
        fail("snapshot must contain exactly two reconciliation passes")
    observed = []
    for number, pass_data in enumerate(passes, 1):
        by_task = issue_map(pass_data, expected, number)
        for task_id, want in expected.items():
            check_issue(task_id, by_task[task_id], want, number,
                        team["id"], project["id"], milestone_ids, workflow)
        attempts = pass_data.get("early_start_attempts")
        if not isinstance(attempts, dict) or set(attempts) != EARLY_START or not all(
                isinstance(value, int) and value >= 0 for value in attempts.values()):
            fail(f"pass {number}: early_start_attempts must cover the four early tasks")
        observed.append((by_task, attempts))
    first, second = observed
    for task_id in expected:
        identity = ("id", "identifier", "url", "source_commit")
        if any(first[0][task_id].get(key) != second[0][task_id].get(key)
               for key in identity):
            fail(f"{task_id}: reconciliation changed issue identity or source")
    if first[1] != second[1]:
        fail("reconciliation changed an early-start attempt count")
    print(f"OK issue mirror: {len(expected)} tasks, two idempotent passes, source {source}")


if __name__ == "__main__":
    main()
