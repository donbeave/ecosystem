#!/usr/bin/env python3
"""Focused regression tests for off-roadmap canonical bundle hashing."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
BUNDLE = REPO / "tools" / "bundle.py"
FILES = (
    "TASK.md",
    "expected-evidence.toml",
    "refs/sources.txt",
    "task.toml",
    "verify.sh",
)


class HashBundleDirectoryTest(unittest.TestCase):
    def run_bundle(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(BUNDLE), *args],
            cwd=REPO,
            check=False,
            capture_output=True,
            text=True,
        )

    def fixture(self, omit: str = "") -> Path:
        temporary = tempfile.TemporaryDirectory(prefix="bundle-dir-test-")
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        bundle = root / "CANARY-01"
        for name in FILES:
            if name == omit:
                continue
            target = bundle / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO / "tasks" / "M1-01" / name, target)
        return bundle

    def test_off_roadmap_directory_uses_canonical_hash(self) -> None:
        bundle = self.fixture()
        (bundle / "evidence.json").write_text("ignored\n", encoding="utf-8")
        expected = self.run_bundle("hash", "M1-01")
        actual = self.run_bundle("hash", "--bundle-dir", str(bundle))
        self.assertEqual(expected.returncode, 0, expected.stderr)
        self.assertEqual(actual.returncode, 0, actual.stderr)
        self.assertEqual(
            actual.stdout.split(),
            ["CANARY-01", expected.stdout.split()[1]],
        )

    def test_missing_canonical_file_is_rejected(self) -> None:
        bundle = self.fixture("refs/sources.txt")
        result = self.run_bundle("hash", "--bundle-dir", str(bundle))
        self.assertEqual(result.returncode, 1)
        self.assertIn("missing canonical bundle file(s): refs/sources.txt", result.stderr)

    def test_roadmap_hash_rejects_the_same_missing_file(self) -> None:
        bundle = self.fixture("refs/sources.txt")
        root = bundle.parent
        roadmap_bundle = root / "tasks" / "M1-01"
        roadmap_bundle.parent.mkdir(parents=True)
        bundle.rename(roadmap_bundle)
        result = self.run_bundle(
            "hash",
            "M1-01",
            "--root",
            str(root),
            "--roadmap",
            str(REPO / "ROADMAP.md"),
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("missing canonical bundle file(s): refs/sources.txt", result.stderr)

    def test_directory_and_task_identity_cannot_be_mixed(self) -> None:
        bundle = self.fixture()
        result = self.run_bundle("hash", "M1-01", "--bundle-dir", str(bundle))
        self.assertEqual(result.returncode, 1)
        self.assertIn("cannot be combined", result.stderr)


if __name__ == "__main__":
    unittest.main()
