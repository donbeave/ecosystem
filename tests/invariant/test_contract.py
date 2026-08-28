#!/usr/bin/env python3
"""Adversarial regression tests for cross-document contract parsing."""

import importlib.util
import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPEC = importlib.util.spec_from_file_location(
    "invariant_lint", os.path.join(REPO, "tools", "invariant_lint.py"))
lint = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lint)


class ContractParserTest(unittest.TestCase):
    def setUp(self):
        self.original_read = lint.read
        lint.findings[:] = []

    def tearDown(self):
        lint.read = self.original_read
        lint.findings[:] = []

    def test_near_miss_reference_prefix_fails(self):
        def mutated(path):
            text = self.original_read(path)
            return text + "\nSECC-999\n" if path == "ROADMAP.md" else text

        lint.read = mutated
        lint.check_spec_contract()
        self.assertTrue(any("SECC-999" in finding for finding in lint.findings))

    def test_unknown_normative_prefix_fails(self):
        def mutated(path):
            text = self.original_read(path)
            if path == "SPEC.md":
                return text.replace("**SEC-001**", "**SECC-001**", 1)
            return text

        lint.read = mutated
        lint.check_spec_contract()
        self.assertTrue(any("unknown normative prefix SECC" in finding
                            for finding in lint.findings))

    def test_acceptance_ids_come_from_spec(self):
        def mutated(path):
            text = self.original_read(path)
            if path == "SPEC.md":
                return text + "\n- **ACC-999** Future declared criterion.\n"
            return text

        lint.read = mutated
        lint.check_spec_contract()
        self.assertFalse(any("ACC-999" in finding for finding in lint.findings))

    def test_open_word_after_none_fails(self):
        def mutated(path):
            text = self.original_read(path)
            if path == "OPEN-QUESTIONS.md":
                return text.replace("None.\n\n", "None ... OPEN\n\n", 1)
            return text

        lint.read = mutated
        lint.check_no_open_questions()
        self.assertTrue(any("OPEN-QUESTIONS.md" in finding
                            for finding in lint.findings))

    def test_future_evidence_description_is_not_existence_claim(self):
        def mutated(path):
            text = self.original_read(path)
            if path == "SPEC.md":
                return text + "\nEvidence exists at `tasks/FUTURE/evidence.json` after execution.\n"
            return text

        lint.read = mutated
        lint.check_existence_claims()
        self.assertFalse(lint.findings)

    def test_current_checked_in_path_must_resolve(self):
        def mutated(path):
            text = self.original_read(path)
            if path == "SPEC.md":
                return text + "\nChecked-in path `tasks/FUTURE/evidence.json` exists now.\n"
            return text

        lint.read = mutated
        lint.check_existence_claims()
        self.assertTrue(any("tasks/FUTURE/evidence.json" in finding
                            for finding in lint.findings))


if __name__ == "__main__":
    unittest.main()
