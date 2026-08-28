#!/usr/bin/env python3
"""Regression proof for the exhaustive M2+ Linear issue mirror."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import verify_issue_mirror as mirror  # noqa: E402


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
    print("status: DONE")


if __name__ == "__main__":
    main()
