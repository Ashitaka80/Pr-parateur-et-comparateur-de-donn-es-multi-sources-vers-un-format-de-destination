#!/usr/bin/env python3
"""CLI to remove a Superset dataset registration by table name.

Does not touch the underlying table in the source database — only the
Superset dataset entry pointing to it. Config resolution and .env lookup
follow the same rules as upload_to_superset.py.

Example:
    python delete_dataset.py --table-name smoke_test_1234567890
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
    parser.add_argument("--table-name", required=True, help="Table name of the dataset to remove")
    parser.add_argument("--url", default=None, help="Superset base URL (default: env SUPERSET_URL)")
    parser.add_argument("--username", default=None, help="Superset username (default: env SUPERSET_USERNAME)")
    parser.add_argument("--password", default=None, help="Superset password (default: env SUPERSET_PASSWORD)")
    parser.add_argument("--insecure", action="store_true", help="Skip TLS certificate verification")
    return parser


def main() -> int:
    load_dotenv(_find_dotenv())
    args = build_arg_parser().parse_args()

    base_url = args.url or os.environ.get("SUPERSET_URL", "http://localhost:8088")
    username = args.username or os.environ.get("SUPERSET_USERNAME", "admin")
    password = args.password or os.environ.get("SUPERSET_PASSWORD")

    if not password:
        print("error: no Superset password found (--password or SUPERSET_PASSWORD in .env)", file=sys.stderr)
        return 2

    client = SupersetClient(base_url, username, password, verify=not args.insecure)
    try:
        client.login()
        dataset = client.find_dataset(args.table_name)
        if dataset is None:
            print(f"no dataset registered for table '{args.table_name}' — nothing to do")
            return 0
        client.delete_dataset(dataset["id"])
        print(f"deleted dataset id={dataset['id']} for table '{args.table_name}'")
        return 0
    except SupersetAPIError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
