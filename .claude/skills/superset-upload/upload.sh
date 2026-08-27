#!/usr/bin/env bash
# Wrapper that runs upload_to_superset.py inside the superset-uploader Docker
# image (no host Python needed). Mounts only the parent directory of --file,
# for the duration of this one call, on the Superset stack's docker network.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
NETWORK="${SUPERSET_NETWORK:-superset_default}"
IMAGE="superset-uploader:latest"

file=""
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      file="$2"
      args+=("--file" "__FILE__")
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$file" ]]; then
  echo "error: --file <path> is required" >&2
  exit 2
fi
if [[ ! -f "$file" ]]; then
  echo "error: file not found: $file" >&2
  exit 2
fi

file_dir="$(cd "$(dirname "$file")" && pwd)"
file_name="$(basename "$file")"

final_args=()
for a in "${args[@]}"; do
  if [[ "$a" == "__FILE__" ]]; then
    final_args+=("/data/$file_name")
  else
    final_args+=("$a")
  fi
done

exec docker run --rm \
  --network "$NETWORK" \
  -v "$file_dir:/data:ro" \
  -v "$REPO_ROOT/.env:/app/.env:ro" \
  "$IMAGE" \
  "${final_args[@]}"
