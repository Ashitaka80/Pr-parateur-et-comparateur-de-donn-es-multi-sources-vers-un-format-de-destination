#!/usr/bin/env bash
# Wrapper that runs delete_dataset.py inside the superset-uploader Docker image
# (no host Python needed). Removes a Superset dataset registration by table
# name — does not touch the underlying table in the source database.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
NETWORK="${SUPERSET_NETWORK:-superset_default}"
IMAGE="superset-uploader:latest"

exec docker run --rm \
  --network "$NETWORK" \
  -v "$REPO_ROOT/.env:/app/.env:ro" \
  --entrypoint python \
  "$IMAGE" \
  /app/delete_dataset.py "$@"
