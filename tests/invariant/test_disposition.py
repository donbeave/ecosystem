#!/usr/bin/env python3
"""Regression tests for the finding-disposition quote anchor.

The anchor is the quote, not the recorded line: inserting text above a
finding must not fail the check, an absent or ambiguous quote must.
"""

import importlib.util
import os
import pathlib
import tempfile
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPEC = importlib.util.spec_from_file_location(
    "check_disposition", os.path.join(REPO, "tools", "check_disposition.py"))
check = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(check)

DOC = """
[archive]
path = "test"
count = 1

[[finding]]
id = "T-01"
title = \"\"\"t\"\"\"
disposition = "fixed"
evidence = \"\"\"e\"\"\"
file = "doc.md"
line = {line}
quote = \"\"\"{quote}\"\"\"
"""


class QuoteAnchorTest(unittest.TestCase):
    def run_on(self, body, line, quote):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "doc.md").write_text(body, encoding="utf-8")
            (root / "findings").mkdir()
            (root / "findings" / "disposition.toml").write_text(
                DOC.format(line=line, quote=quote), encoding="utf-8")
            original_root, original_doc = check.ROOT, check.DOC
            check.ROOT = root
            check.DOC = root / "findings" / "disposition.toml"
            try:
                return check.main()
            finally:
                check.ROOT, check.DOC = original_root, original_doc

    def test_shifted_line_still_passes(self):
        body = "filler\nfiller\nthe anchor text\n"
        self.assertEqual(self.run_on(body, 1, "the anchor text"), 0)

    def test_absent_quote_fails(self):
        self.assertEqual(self.run_on("nothing here\n", 1, "the anchor text"), 1)

    def test_ambiguous_quote_fails(self):
        body = "the anchor text\nthe anchor text\n"
        self.assertEqual(self.run_on(body, 1, "the anchor text"), 1)

    def test_repeat_on_one_line_is_one_anchor(self):
        body = "pad\nanchor and anchor\n"
        self.assertEqual(self.run_on(body, 2, "anchor"), 0)

    def test_multiline_quote_anchors_start_line(self):
        body = "first line\nsecond line\nfirst line second line\n"
        self.assertEqual(self.run_on(body, 1, "first line\nsecond line"), 0)

    def test_locate_reports_every_start_line(self):
        self.assertEqual(check.locate("a\nq\nb\nq\n", "q"), [2, 4])
        self.assertEqual(check.locate("x\na\nb\n", "a\nb"), [2])

    def test_line_zero_fails(self):
        self.assertEqual(self.run_on("the anchor text\n", 0, "the anchor text"), 1)


if __name__ == "__main__":
    unittest.main()
