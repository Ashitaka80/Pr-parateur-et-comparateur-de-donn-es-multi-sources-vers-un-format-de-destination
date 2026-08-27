#!/usr/bin/env bash
# Pousse une branche vers origin en s'authentifiant avec le PAT du .env, sans
# jamais l'exposer en argv, dans .git/config, ni dans l'historique shell —
# via git-credential-helper.sh et `git -c credential.helper=...`, scopé à
# cette seule invocation. Voir ADR-0012.
#
# Usage : scripts/git-push.sh [branche]   (défaut : branche courante)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$REPO_ROOT/scripts/git-credential-helper.sh"
branch="${1:-$(git -C "$REPO_ROOT" branch --show-current)}"

[[ -n "$branch" ]] || { echo "error: aucune branche courante (HEAD détaché ?) — préciser le nom" >&2; exit 2; }
if [[ "$branch" == "main" ]]; then
  echo "error: push direct sur main refusé (ADR-0009, D-0004) — passer par une branche" >&2
  exit 2
fi

git -C "$REPO_ROOT" -c credential.helper="$HELPER" push -u origin "$branch"
