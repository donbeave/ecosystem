#!/usr/bin/env python3
"""Regression proof for the exhaustive M2+ Linear issue mirror."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import verify_issue_mirror as mirror  # noqa: E402


def test_concurrent_transition_snapshots():
    events = [
        {
            "seq": 0,
            "type": "init",
            "run_id": "mirror-test",
            "tasks": [
                {"id": "M1-01", "milestone": "M1", "depends_on": [],
                 "status": "done"},
                {"id": "M2-01", "milestone": "M2", "depends_on": ["M1-01"],
                 "status": "planned"},
            ],
        },
        {"seq": 1, "type": "transition", "task": "M2-01", "status": "ready",
         "lane": "", "idempotency": "ready"},
        {"seq": 2, "type": "lease", "task": "M2-01", "owner": "fixture",
         "token": 1, "epoch": 1, "expires_at": 9999999999},
    ]
    mirrored = {"M2-01"}
    first, first_seq = mirror.captured_task_statuses(
        {"event_seq": 1, "task_statuses": {"M2-01": "ready"}},
        events, mirrored, 1)
    second, second_seq = mirror.captured_task_statuses(
        {"event_seq": 2, "task_statuses": {"M2-01": "leased"}},
        events, mirrored, 2)
    assert first_seq < second_seq
    assert mirror.STATE_TYPE[first["M2-01"]] == "unstarted"
    assert mirror.STATE_TYPE[second["M2-01"]] == "started"

    expected = {"M2-01": object()}
    issue = {"task_id": "M2-01", "id": "id-1", "identifier": "JACKIN-1",
             "url": "https://linear.app/jackin/issue/JACKIN-1"}
    first_issues = mirror.issue_map({"issues": [dict(issue)]}, expected, 1)
    second_issues = mirror.issue_map({"issues": [dict(issue)]}, expected, 2)
    assert first_issues["M2-01"]["url"] == second_issues["M2-01"]["url"]


def main():
    expected = {
        "planned": "unstarted",
        "ready": "unstarted",
        "resource-waiting": "unstarted",
        "blocked": "unstarted",
        "failed-system": "unstarted",
        "leased": "started",
        "in-progress": "started",
        "waiting": "started",
        "done": "completed",
    }
    assert mirror.STATE_TYPE == expected
    statuses = {f"M2-{index:02d}": status
                for index, status in enumerate(expected, 1)}
    statuses["M1-01"] = "done"
    assert mirror.mirrored_task_ids(statuses) == set(statuses) - {"M1-01"}
    actual = mirror.task_statuses(ROOT / "tasks" / "README.md")
    assert mirror.mirrored_task_ids(actual) == {
        task_id for task_id in actual if not task_id.startswith("M1-")
    }
    test_concurrent_transition_snapshots()
    print("status: DONE")


if __name__ == "__main__":
    main()
