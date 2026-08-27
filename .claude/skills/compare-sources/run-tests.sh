#!/usr/bin/env bash
# Lance la suite de tests (stdlib unittest) dans l'image compare-sources.
set -euo pipefail

exec docker run --rm --entrypoint python compare-sources:latest -m unittest discover -s tests -v
