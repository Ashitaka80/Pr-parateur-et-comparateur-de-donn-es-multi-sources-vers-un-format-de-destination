#!/usr/bin/env bash
# Wrapper that runs compare_sources.py inside the compare-sources Docker image
# (no host Python needed). Mounts only the parent directories of --source-a
# and --source-b (read-only) plus --output-dir (read-write), for the duration
# of this one call. See SKILL.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="compare-sources:latest"

source_a="" source_b="" output_dir=""
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-a)   source_a="$2";  args+=("--source-a" "__A__");   shift 2 ;;
    --source-b)   source_b="$2";  args+=("--source-b" "__B__");   shift 2 ;;
    --output-dir) output_dir="$2"; args+=("--output-dir" "__OUT__"); shift 2 ;;
    *)            args+=("$1"); shift ;;
  esac
done

[[ -n "$source_a" ]]   || { echo "error: --source-a <path> is required" >&2; exit 2; }
[[ -n "$source_b" ]]   || { echo "error: --source-b <path> is required" >&2; exit 2; }
[[ -n "$output_dir" ]] || { echo "error: --output-dir <path> is required" >&2; exit 2; }
[[ -f "$source_a" ]] || { echo "error: file not found: $source_a" >&2; exit 2; }
[[ -f "$source_b" ]] || { echo "error: file not found: $source_b" >&2; exit 2; }
mkdir -p "$output_dir"

a_dir="$(cd "$(dirname "$source_a")" && pwd)"; a_name="$(basename "$source_a")"
b_dir="$(cd "$(dirname "$source_b")" && pwd)"; b_name="$(basename "$source_b")"
out_dir="$(cd "$output_dir" && pwd)"

final_args=()
for a in "${args[@]}"; do
  case "$a" in
    __A__)   final_args+=("/data/a/$a_name") ;;
    __B__)   final_args+=("/data/b/$b_name") ;;
    __OUT__) final_args+=("/out") ;;
    *)       final_args+=("$a") ;;
  esac
done

exec docker run --rm \
  -v "$a_dir:/data/a:ro" \
  -v "$b_dir:/data/b:ro" \
  -v "$out_dir:/out" \
  "$IMAGE" \
  "${final_args[@]}"
