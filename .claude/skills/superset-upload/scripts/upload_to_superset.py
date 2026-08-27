#!/usr/bin/env python3
"""CLI to push a CSV/Excel/Parquet file into Apache Superset as a dataset.

Config resolution order for each setting: CLI flag > environment variable >
`.env` file (SUPERSET_URL, SUPERSET_USERNAME, SUPERSET_PASSWORD,
SUPERSET_UPLOAD_DATABASE, SUPERSET_UPLOAD_SQLALCHEMY_URI). The `.env` is
looked up next to this script first, then walking up its parent directories.

Examples:
    python upload_to_superset.py --file sales.csv --table-name sales
    python upload_to_superset.py --file q3.xlsx --table-name q3 --sheet-name "Q3 Data" --if-exists replace
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from superset_client import SupersetAPIError, SupersetClient  # noqa: E402

SCRIPT_DIR = Path(__file__).resolve().parent


def _find_dotenv() -> Path | None:
    candidates = [SCRIPT_DIR] + list(SCRIPT_DIR.parents)
    return next((p / ".env" for p in candidates if (p / ".env").exists()), None)


def load_dotenv(path: Path | None) -> None:
    if path is None or not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip())


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--file", required=True, help="Path to the CSV/Excel/Parquet file to upload")
    parser.add_argument("--table-name", required=True, help="Destination table/dataset name in Superset")
    parser.add_argument("--schema", default="public", help="Target DB schema (default: public)")
    parser.add_argument(
        "--if-exists",
        default="fail",
        choices=("fail", "replace", "append"),
        help="Behavior if the table already exists (default: fail)",
    )
    parser.add_argument("--delimiter", default=None, help="CSV delimiter (default: comma)")
    parser.add_argument("--sheet-name", default=None, help="Excel sheet name (default: first sheet)")
    parser.add_argument("--header-row", type=int, default=None, help="0-indexed row containing headers")
    parser.add_argument("--database", default=None, help="Superset database connection name (default: env SUPERSET_UPLOAD_DATABASE or 'uploads')")
    parser.add_argument("--url", default=None, help="Superset base URL (default: env SUPERSET_URL)")
    parser.add_argument("--username", default=None, help="Superset username (default: env SUPERSET_USERNAME)")
    parser.add_argument("--password", default=None, help="Superset password (default: env SUPERSET_PASSWORD)")
    parser.add_argument("--insecure", action="store_true", help="Skip TLS certificate verification")
    return parser


def main() -> int:
    load_dotenv(_find_dotenv())
    args = build_arg_parser().parse_args()

    base_url = args.url or os.environ.get("SUPERSET_URL", "http://localhost:8088")
    # SUPERSET_URL may be an in-container hostname (e.g. http://superset_app:8088)
    # that only resolves on the docker network; SUPERSET_PUBLIC_URL, if set, is
    # what to print for a human to open in their own browser.
    public_url = os.environ.get("SUPERSET_PUBLIC_URL", base_url)
    username = args.username or os.environ.get("SUPERSET_USERNAME", "admin")
    password = args.password or os.environ.get("SUPERSET_PASSWORD")
    database_name = args.database or os.environ.get("SUPERSET_UPLOAD_DATABASE", "uploads")
    database_uri = os.environ.get("SUPERSET_UPLOAD_SQLALCHEMY_URI")

    if not password:
        print("error: no Superset password found (--password or SUPERSET_PASSWORD in .env)", file=sys.stderr)
        return 2

    client = SupersetClient(base_url, username, password, verify=not args.insecure)
    try:
        client.login()

        database_id = client.find_database_id(database_name)
        if database_id is None:
            if not database_uri:
                print(
                    f"error: database '{database_name}' does not exist in Superset and "
                    "SUPERSET_UPLOAD_SQLALCHEMY_URI is not set to create it",
                    file=sys.stderr,
                )
                return 2
            database_id = client.ensure_database(database_name, database_uri)
            print(f"Created Superset database connection '{database_name}' (id={database_id})")

        result = client.upload_file(
            database_id=database_id,
            file_path=args.file,
            table_name=args.table_name,
            schema=args.schema,
            already_exists=args.if_exists,
            delimiter=args.delimiter,
            sheet_name=args.sheet_name,
            header_row=args.header_row,
        )
        print(f"Uploaded '{args.file}' -> table '{args.table_name}': {result.get('message', result)}")

        dataset = client.find_dataset(args.table_name)
        if dataset:
            print(f"Dataset available: {public_url}/explore/?datasource_type=table&datasource_id={dataset['id']}")
        return 0
    except SupersetAPIError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except FileNotFoundError as exc:
        print(f"error: file not found: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
