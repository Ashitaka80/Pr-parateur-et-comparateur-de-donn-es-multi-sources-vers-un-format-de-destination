#!/usr/bin/env python3
"""Unit tests for compare_sources.py — stdlib unittest, no extra dependency.

Run inside the compare-sources image (see run-tests.sh):
    python -m unittest discover -s tests -v
"""

from __future__ import annotations

import csv
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import compare_sources as cs  # noqa: E402


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


class NormalizeAndSimilarity(unittest.TestCase):
    def test_normalize_strips_accents_case_and_spaces(self):
        self.assertEqual(cs.normalize("  Émile   Dûpont "), "emile dupont")

    def test_similarity_identical_strings_is_one(self):
        self.assertEqual(cs.similarity("Emile Dupont", "Emile Dupont"), 1.0)

    def test_similarity_tolerant_to_accents_and_case(self):
        self.assertEqual(cs.similarity("Émile Dupont", "emile dupont"), 1.0)

    def test_similarity_typo_is_high_but_not_one(self):
        score = cs.similarity("Emile Dupont", "Emil Dupont")
        self.assertGreater(score, 0.9)
        self.assertLess(score, 1.0)


class Dedupe(unittest.TestCase):
    def test_internal_duplicate_removed_and_tracked(self):
        rows = [
            {"_row_id": 0, "nom": "Emile Dupont"},
            {"_row_id": 1, "nom": "emile dupont"},  # same after normalization
            {"_row_id": 2, "nom": "Sarah Martin"},
        ]
        kept, duplicates = cs.dedupe(rows, ["nom"], threshold=0.85)
        self.assertEqual([r["_row_id"] for r in kept], [0, 2])
        self.assertEqual(len(duplicates), 1)
        self.assertEqual(duplicates[0]["removed_row"], 1)
        self.assertEqual(duplicates[0]["kept_row"], 0)

    def test_no_duplicates_below_threshold(self):
        rows = [
            {"_row_id": 0, "nom": "Emile Dupont"},
            {"_row_id": 1, "nom": "Sarah Martin"},
        ]
        kept, duplicates = cs.dedupe(rows, ["nom"], threshold=0.85)
        self.assertEqual(len(kept), 2)
        self.assertEqual(duplicates, [])


class MatchSources(unittest.TestCase):
    def _kept(self, rows):
        return [dict(r, _row_id=i) for i, r in enumerate(rows)]

    def test_identical_sources_all_concordant(self):
        rows = [{"nom": "Emile Dupont", "ville": "Paris"}, {"nom": "Sarah Martin", "ville": "Lyon"}]
        a, b = self._kept(rows), self._kept(rows)
        results = cs.match_sources(a, b, ["nom"], ["ville"], threshold=0.85)
        self.assertEqual(len(results), 2)
        self.assertTrue(all(r["status"] == "concordant" for r in results))

    def test_present_only_in_a_and_b(self):
        a = self._kept([{"nom": "Emile Dupont"}])
        b = self._kept([{"nom": "Completely Different Person"}])
        results = cs.match_sources(a, b, ["nom"], [], threshold=0.85)
        statuses = {r["status"] for r in results}
        self.assertEqual(statuses, {"seulement_a", "seulement_b"})

    def test_value_mismatch_on_compared_column(self):
        a = self._kept([{"nom": "Emile Dupont", "ville": "Paris"}])
        b = self._kept([{"nom": "Emile Dupont", "ville": "Lyon"}])
        results = cs.match_sources(a, b, ["nom"], ["ville"], threshold=0.85)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["status"], "ecart_valeur")
        self.assertIn("ville", results[0]["details"])

    def test_cross_duplicate_flagged_both_sides(self):
        a = self._kept([{"nom": "Emile Dupont"}, {"nom": "emile dupont"}])
        b = self._kept([{"nom": "Emile Dupont"}])
        results = cs.match_sources(a, b, ["nom"], [], threshold=0.85)
        statuses = [r["status"] for r in results]
        # Both A-side rows point at the single B row above threshold: doublon_croise
        # on the A side; the B row itself is also reported once, doublon_croise.
        self.assertEqual(statuses.count("doublon_croise"), 3)
        self.assertNotIn("concordant", statuses)


class MainCLI(unittest.TestCase):
    def test_missing_match_column_fails_before_any_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            a_path, b_path, out_dir = tmp_path / "a.csv", tmp_path / "b.csv", tmp_path / "out"
            write_csv(a_path, ["nom"], [{"nom": "Emile Dupont"}])
            write_csv(b_path, ["nom"], [{"nom": "Emile Dupont"}])

            argv = [
                "compare_sources.py",
                "--source-a", str(a_path),
                "--source-b", str(b_path),
                "--match-on", "colonne_absente",
                "--output-dir", str(out_dir),
            ]
            old_argv = sys.argv
            sys.argv = argv
            try:
                exit_code = cs.main()
            finally:
                sys.argv = old_argv

            self.assertEqual(exit_code, 2)
            self.assertFalse(out_dir.exists())

    def test_end_to_end_writes_report_and_dedup_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            a_path, b_path, out_dir = tmp_path / "a.csv", tmp_path / "b.csv", tmp_path / "out"
            write_csv(
                a_path,
                ["nom", "ville"],
                [{"nom": "Emile Dupont", "ville": "Paris"}, {"nom": "Sarah Martin", "ville": "Lyon"}],
            )
            write_csv(
                b_path,
                ["nom", "ville"],
                [{"nom": "Emile Dupont", "ville": "Marseille"}],
            )

            argv = [
                "compare_sources.py",
                "--source-a", str(a_path),
                "--source-b", str(b_path),
                "--match-on", "nom",
                "--compare-on", "ville",
                "--output-dir", str(out_dir),
            ]
            old_argv = sys.argv
            sys.argv = argv
            try:
                exit_code = cs.main()
            finally:
                sys.argv = old_argv

            self.assertEqual(exit_code, 0)
            self.assertTrue((out_dir / "report.csv").exists())
            self.assertTrue((out_dir / "doublons_internes_source_a.csv").exists())
            self.assertTrue((out_dir / "doublons_internes_source_b.csv").exists())

            with open(out_dir / "report.csv", newline="", encoding="utf-8") as fh:
                rows = list(csv.DictReader(fh))
            statuses = {r["status"] for r in rows}
            self.assertIn("ecart_valeur", statuses)   # Emile Dupont: Paris vs Marseille
            self.assertIn("seulement_a", statuses)     # Sarah Martin has no match in B


if __name__ == "__main__":
    unittest.main()
