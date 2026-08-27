---
name: superset-upload
description: Upload a CSV, Excel, or Parquet file into Apache Superset as a queryable dataset (creates the underlying table via Superset's REST API). Use when the user asks to push, load, import, or add data into Superset, or to create a Superset dataset/dashboard from a local file.
---

# Superset data upload

Pushes a local data file into Apache Superset by calling its REST API upload
endpoint (`POST /api/v1/database/{id}/upload/`). Superset creates/replaces/appends
the table in the target database and registers it as a dataset — no manual
"New dataset" step in the UI needed.

Runs entirely via Docker — **no Python/pip needed on the host**. The tool is a
small `python:3.12-slim` image (`superset-uploader`, built from this
directory's `Dockerfile`) with `requests` baked in. Each upload runs it as a
one-off `docker run --rm` on the same docker network as the Superset stack.

## Prerequisites

- The Superset stack is up (`/home/user/superset-docker`, see this repo's
  `CLAUDE.md`): `docker compose -f docker-compose-image-tag.yml up -d`.
- The uploader image is built — **and rebuilt after any edit to `scripts/`**,
  since they're `COPY`'d into the image at build time, not live-mounted:
  ```
  docker build -t superset-uploader:latest .claude/skills/superset-upload/
  ```
  If pip can't reach the network during the build on this machine, add
  `--build-arg HTTP_PROXY=... --build-arg HTTPS_PROXY=...` (see
  `CLAUDE.md` for why).
- Credentials in the repo's `.env`: `SUPERSET_URL` (the *internal* docker
  network hostname, `http://superset_app:8088` — not `localhost`, since the
  uploader runs in its own container), `SUPERSET_PUBLIC_URL`
  (`http://localhost:8088`, used only for the human-facing link printed at
  the end), `SUPERSET_USERNAME`, `SUPERSET_PASSWORD`.
- An upload-enabled Superset "Database" connection. `SUPERSET_UPLOAD_DATABASE`
  (default `uploads`) names it; if it doesn't exist yet, set
  `SUPERSET_UPLOAD_SQLALCHEMY_URI` in `.env` and the script creates it with
  `allow_file_upload=true` automatically on first use.

## Usage

```
.claude/skills/superset-upload/upload.sh \
  --file <path/to/data.csv> \
  --table-name <destination_table_name> \
  [--if-exists fail|replace|append]   # default: fail
  [--schema public]                   # default: public
  [--delimiter ";"]                   # CSV only
  [--sheet-name "Sheet1"]             # Excel only
  [--header-row 0]
```

`upload.sh` is a thin wrapper: it resolves `--file` to an absolute path,
bind-mounts *only that file's parent directory* into the container read-only
for the duration of this one call (`docker run --rm`), and mounts the repo's
`.env` for credentials. Nothing else on the host is exposed to the
container, and the mount doesn't outlive the single upload.

On success it prints the Superset Explore URL (using `SUPERSET_PUBLIC_URL`)
for the new/updated dataset.

Supported file types are inferred from the extension: `.csv`/`.tsv` → CSV,
`.xls`/`.xlsx` → Excel, `.parquet`/`.zip` → columnar.

## Why not a host venv, and why not `docker exec` into `superset_app`?

Two alternatives were tried and rejected:

- **Host Python venv** — works, but adds a Python dependency on the host
  when the rest of the project deliberately runs everything in Docker.
- **`docker exec` into the long-running `superset_app` container** (which
  already has `requests`) — would need bind-mounting host paths (script,
  `.env`, target data file) into that *always-on* service container. Doing
  that broadly (e.g. the whole home directory, so any file could be
  uploaded) was correctly blocked by this environment's safety guardrails
  as too large a blast radius for a persistent mount.

The current design — a dedicated, disposable image, mounting only the one
directory needed, only for the duration of one `docker run --rm` — gets the
"no host Python" property without that trade-off.

## When comparing/merging multiple sources before upload

This skill only handles the "push to Superset" leg. If the user's data needs
cleaning, deduplication, or merging across sources first, do that separately
and write the result to a single CSV/Parquet, then call `upload.sh` once per
destination table. Don't try to make Superset's upload endpoint do the
transformation — it only loads what you give it.

## Troubleshooting

- `Database schema is not allowed for csv uploads` — the target database's
  `extra.schemas_allowed_for_file_upload` doesn't include the schema you
  passed via `--schema`. `superset_client.ensure_database()` sets this to
  `["public"]` by default when creating a new connection.
- `CSRF session token is missing` — only relevant if calling the API directly
  with curl/requests outside this script: the CSRF token must be fetched
  with the *same* cookie-jar/session used for login, and sent back on the
  upload POST via `X-CSRFToken`. `superset_client.py` already handles this.
- `docker: Error response from daemon: network superset-docker_default not
  found` — the Superset stack isn't up, or its compose project isn't named
  `superset-docker` (compose derives the network name from the directory
  name). Check `docker network ls` and adjust `NETWORK` in `upload.sh` if
  the Superset install was moved.
- Auth/connection errors — verify the Superset containers are up:
  `docker ps --filter name=superset` and `curl http://localhost:8088/health`.

## Files

- `Dockerfile` — the `superset-uploader` image (python:3.12-slim + requests).
- `upload.sh` — the entry point described above; run this, not the script
  directly, unless you have your own Python environment with `requests`.
- `scripts/superset_client.py` — reusable `SupersetClient` (login, CSRF,
  database lookup/creation, file upload, dataset lookup).
- `scripts/upload_to_superset.py` — the CLI the Docker image runs.
