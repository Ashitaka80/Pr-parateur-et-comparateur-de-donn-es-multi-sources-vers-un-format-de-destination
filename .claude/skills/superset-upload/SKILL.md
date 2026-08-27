---
name: superset-upload
description: Upload a CSV, Excel, or Parquet file into Apache Superset as a queryable dataset (creates the underlying table via Superset's REST API). Use when the user asks to push, load, import, or add data into Superset, or to create a Superset dataset/dashboard from a local file.
---

# Superset data upload

Pushes a local data file into Apache Superset by calling its REST API upload
endpoint (`POST /api/v1/database/{id}/upload/`). Superset creates/replaces/appends
the table in the target database and registers it as a dataset — no manual
"New dataset" step in the UI needed.

## Prerequisites

- A running Superset instance reachable at `SUPERSET_URL` (local dev default:
  `http://localhost:8088`, see `/home/user/superset-docker` and this repo's
  `CLAUDE.md` for how it's deployed).
- Credentials in the repo's `.env` (or passed via flags):
  `SUPERSET_URL`, `SUPERSET_USERNAME`, `SUPERSET_PASSWORD`.
- An upload-enabled Superset "Database" connection. `SUPERSET_UPLOAD_DATABASE`
  (default `uploads`) names it; if it doesn't exist yet, set
  `SUPERSET_UPLOAD_SQLALCHEMY_URI` in `.env` and the script will create it
  with `allow_file_upload=true` automatically on first use.

## Why a venv, given Superset already runs in Docker?

Superset's own container (`superset_app`) already has `requests` installed, so
in principle `docker exec superset_app python <script>` could run this tool
without any host venv. In practice that requires bind-mounting host paths
(the script, `.env`, and whatever data file you want to upload) into the
container — broader filesystem exposure than a single read-only project
mount, and correctly gated as a risky action in this environment. A small
dedicated venv (`.venv/`, one dependency: `requests`) avoids that trade-off
entirely and lets `--file` point at any path on the host. Keep using it.

## Usage

Run via the project venv:

```
/home/user/Documents/TP_Claude/.venv/bin/python \
  .claude/skills/superset-upload/scripts/upload_to_superset.py \
  --file <path/to/data.csv> \
  --table-name <destination_table_name> \
  [--if-exists fail|replace|append]   # default: fail
  [--schema public]                   # default: public
  [--delimiter ";"]                   # CSV only
  [--sheet-name "Sheet1"]             # Excel only
  [--header-row 0]
```

On success it prints the Superset Explore URL for the new/updated dataset.

Supported file types are inferred from the extension: `.csv`/`.tsv` → CSV,
`.xls`/`.xlsx` → Excel, `.parquet`/`.zip` → columnar.

## When comparing/merging multiple sources before upload

This skill only handles the "push to Superset" leg. If the user's data needs
cleaning, deduplication, or merging across sources first, do that with
pandas/Python and write the result to a single CSV/Parquet, then call this
script once per destination table. Don't try to make Superset's upload
endpoint do the transformation — it only loads what you give it.

## Troubleshooting

- `Database schema is not allowed for csv uploads` — the target database's
  `extra.schemas_allowed_for_file_upload` doesn't include the schema you
  passed via `--schema`. `superset_client.ensure_database()` sets this to
  `["public"]` by default when creating a new connection.
- `CSRF session token is missing` — only relevant if calling the API directly
  with curl/requests outside this script: the CSRF token must be fetched
  with the *same* cookie-jar/session used for login, and sent back on the
  upload POST via `X-CSRFToken`. `superset_client.py` already handles this.
- Auth/connection errors — verify the Superset containers are up:
  `docker ps --filter name=superset` and `curl http://localhost:8088/health`.

## Files

- `scripts/superset_client.py` — reusable `SupersetClient` (login, CSRF,
  database lookup/creation, file upload, dataset lookup).
- `scripts/upload_to_superset.py` — CLI entry point described above.
