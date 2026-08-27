#!/usr/bin/env python3
"""Compare and reconcile two prepared data sources (SPEC-0001).

Pure standard library — no pandas/rapidfuzz — to keep the Docker image as
minimal as the rest of this project's tooling (see .claude/skills/compare-sources/SKILL.md).

Pipeline:
    1. Deduplicate each source internally on the matching columns.
    2. Fuzzy-match records between the two deduplicated sources.
    3. Classify every record/pair: concordant, value mismatch, present in
       only one source, or cross-source duplicate.
    4. Write a report + two internal-duplicates files to --output-dir.

Nothing here corrects or merges data — see SPEC-0001 "Hors périmètre".
"""

from __future__ import annotations

import argparse
import csv
import sys
import unicodedata
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

Row = dict[str, Any]


# -- normalization / similarity ---------------------------------------------

def normalize(value: str | None) -> str:
    """Lowercase, strip, drop accents, collapse whitespace — for tolerant matching."""
    if value is None:
        return ""
    text = unicodedata.normalize("NFKD", value.strip().lower())
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return " ".join(text.split())


def similarity(a: str | None, b: str | None) -> float:
    return SequenceMatcher(None, normalize(a), normalize(b)).ratio()


def row_score(row_a: Row, row_b: Row, columns: list[str]) -> float:
    if not columns:
        return 0.0
    return sum(similarity(row_a.get(c), row_b.get(c)) for c in columns) / len(columns)


# -- I/O ----------------------------------------------------------------------

def read_rows(path: Path, delimiter: str) -> tuple[list[str], list[Row]]:
    with open(path, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh, delimiter=delimiter)
        fieldnames = reader.fieldnames or []
        rows = []
        for i, row in enumerate(reader):
            row["_row_id"] = i
            rows.append(row)
    return fieldnames, rows


def require_columns(label: str, fieldnames: list[str], columns: list[str]) -> None:
    missing = [c for c in columns if c not in fieldnames]
    if missing:
        raise ValueError(f"colonnes absentes de {label}: {', '.join(missing)}")


# -- internal deduplication ---------------------------------------------------

def dedupe(rows: list[Row], columns: list[str], threshold: float) -> tuple[list[Row], list[dict]]:
    """Keep first occurrence; later rows scoring >= threshold against a kept row
    are reported as internal duplicates, not silently dropped."""
    kept: list[Row] = []
    duplicates: list[dict] = []
    for row in rows:
        match = None
        best_score = 0.0
        for k in kept:
            score = row_score(row, k, columns)
            if score >= threshold and score > best_score:
                match, best_score = k, score
        if match is not None:
            duplicates.append(
                {"removed_row": row["_row_id"], "kept_row": match["_row_id"], "score": round(best_score, 4)}
            )
        else:
            kept.append(row)
    return kept, duplicates


# -- cross-source matching -----------------------------------------------------

def build_score_matrix(kept_a: list[Row], kept_b: list[Row], columns: list[str]) -> dict[int, dict[int, float]]:
    matrix: dict[int, dict[int, float]] = {}
    for a in kept_a:
        matrix[a["_row_id"]] = {}
        for b in kept_b:
            matrix[a["_row_id"]][b["_row_id"]] = row_score(a, b, columns)
    return matrix


def candidates_above(scores: dict[int, float], threshold: float) -> list[tuple[int, float]]:
    return sorted(((k, v) for k, v in scores.items() if v >= threshold), key=lambda kv: -kv[1])


def diff_columns(row_a: Row, row_b: Row, columns: list[str]) -> list[tuple[str, str, str]]:
    diffs = []
    for c in columns:
        va, vb = (row_a.get(c) or "").strip(), (row_b.get(c) or "").strip()
        if va != vb:
            diffs.append((c, va, vb))
    return diffs


def match_sources(
    kept_a: list[Row],
    kept_b: list[Row],
    match_columns: list[str],
    compare_columns: list[str],
    threshold: float,
) -> list[dict]:
    by_id_a = {r["_row_id"]: r for r in kept_a}
    by_id_b = {r["_row_id"]: r for r in kept_b}
    matrix = build_score_matrix(kept_a, kept_b, match_columns)
    # candidates_by_b[b_id] = [(a_id, score), ...] — for symmetric multiplicity checks.
    candidates_by_b: dict[int, list[tuple[int, float]]] = {b["_row_id"]: [] for b in kept_b}
    for a_id, row in matrix.items():
        for b_id, score in candidates_above(row, threshold):
            candidates_by_b[b_id].append((a_id, score))

    results: list[dict] = []
    b_consumed: set[int] = set()

    for a in kept_a:
        a_id = a["_row_id"]
        cands = candidates_above(matrix[a_id], threshold)
        if not cands:
            results.append({"status": "seulement_a", "a_row": a_id, "b_row": "", "score": "", "details": ""})
            continue
        if len(cands) > 1:
            details = "; ".join(f"b={b_id} (score={score:.3f})" for b_id, score in cands)
            results.append(
                {"status": "doublon_croise", "a_row": a_id, "b_row": "", "score": f"{cands[0][1]:.3f}", "details": details}
            )
            continue
        b_id, score = cands[0]
        if len(candidates_by_b[b_id]) > 1:
            others = "; ".join(f"a={aid} (score={s:.3f})" for aid, s in candidates_by_b[b_id])
            results.append(
                {"status": "doublon_croise", "a_row": a_id, "b_row": b_id, "score": f"{score:.3f}", "details": others}
            )
            continue
        # Mutual best match: a genuine pair.
        b_consumed.add(b_id)
        diffs = diff_columns(a, by_id_b[b_id], compare_columns)
        if diffs:
            details = "; ".join(f"{c}: '{va}' vs '{vb}'" for c, va, vb in diffs)
            results.append(
                {"status": "ecart_valeur", "a_row": a_id, "b_row": b_id, "score": f"{score:.3f}", "details": details}
            )
        else:
            results.append(
                {"status": "concordant", "a_row": a_id, "b_row": b_id, "score": f"{score:.3f}", "details": ""}
            )

    for b in kept_b:
        b_id = b["_row_id"]
        if b_id in b_consumed:
            continue
        cands = candidates_by_b[b_id]
        if not cands:
            results.append({"status": "seulement_b", "a_row": "", "b_row": b_id, "score": "", "details": ""})
        else:
            details = "; ".join(f"a={a_id} (score={score:.3f})" for a_id, score in cands)
            results.append(
                {"status": "doublon_croise", "a_row": "", "b_row": b_id, "score": f"{cands[0][1]:.3f}", "details": details}
            )

    return results


# -- CLI ------------------------------------------------------------------------

def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source-a", required=True, help="Path to source A (CSV)")
    parser.add_argument("--source-b", required=True, help="Path to source B (CSV)")
    parser.add_argument("--match-on", required=True, help="Comma-separated columns used for approximate matching")
    parser.add_argument(
        "--compare-on",
        default=None,
        help="Comma-separated columns to check for value mismatches (default: all columns common to A and B, minus --match-on)",
    )
    parser.add_argument("--threshold", type=float, default=0.85, help="Similarity threshold in [0,1] (default: 0.85)")
    parser.add_argument("--delimiter", default=",", help="CSV delimiter (default: comma)")
    parser.add_argument("--output-dir", required=True, help="Directory to write report.csv and duplicate lists into")
    return parser


def main() -> int:
    args = build_arg_parser().parse_args()
    match_columns = [c.strip() for c in args.match_on.split(",") if c.strip()]

    try:
        fields_a, rows_a = read_rows(Path(args.source_a), args.delimiter)
        fields_b, rows_b = read_rows(Path(args.source_b), args.delimiter)
        require_columns("source A", fields_a, match_columns)
        require_columns("source B", fields_b, match_columns)

        if args.compare_on is not None:
            compare_columns = [c.strip() for c in args.compare_on.split(",") if c.strip()]
        else:
            common = [c for c in fields_a if c in fields_b]
            compare_columns = [c for c in common if c not in match_columns]
        require_columns("source A", fields_a, compare_columns)
        require_columns("source B", fields_b, compare_columns)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if not 0.0 <= args.threshold <= 1.0:
        print("error: --threshold must be in [0, 1]", file=sys.stderr)
        return 2

    kept_a, dupes_a = dedupe(rows_a, match_columns, args.threshold)
    kept_b, dupes_b = dedupe(rows_b, match_columns, args.threshold)
    report = match_sources(kept_a, kept_b, match_columns, compare_columns, args.threshold)

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    with open(out_dir / "report.csv", "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=["status", "a_row", "b_row", "score", "details"])
        writer.writeheader()
        writer.writerows(report)

    for name, dupes in (("doublons_internes_source_a.csv", dupes_a), ("doublons_internes_source_b.csv", dupes_b)):
        with open(out_dir / name, "w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=["removed_row", "kept_row", "score"])
            writer.writeheader()
            writer.writerows(dupes)

    counts: dict[str, int] = {}
    for r in report:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    summary = ", ".join(f"{k}={v}" for k, v in sorted(counts.items())) or "aucun enregistrement"
    print(f"Rapport : {summary}")
    print(f"Doublons internes : source A={len(dupes_a)}, source B={len(dupes_b)}")
    print(f"Écrit dans {out_dir}/ (report.csv, doublons_internes_source_a.csv, doublons_internes_source_b.csv)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
