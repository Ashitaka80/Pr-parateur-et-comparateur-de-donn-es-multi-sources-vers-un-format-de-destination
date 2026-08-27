#!/usr/bin/env bash
# Git credential helper : fournit GITHUB_USERNAME/GITHUB_TOKEN depuis le .env
# racine pour une seule invocation git, via `git -c credential.helper=...`.
# N'écrit jamais dans .git/config, n'apparaît jamais dans les arguments d'un
# process (visibles par `ps`), n'est jamais imprimé. Voir ADR-0012.
#
# Protocole standard des credential helpers git : appelé avec `get` (ou
# `store`/`erase`, ignorés ici), reçoit la requête sur stdin, répond en
# key=value sur stdout.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

operation="${1:-get}"
cat >/dev/null || true   # draine la requête de git sans la réafficher

[[ "$operation" == "get" ]] || exit 0
[[ -f "$ENV_FILE" ]] || { echo "error: $ENV_FILE introuvable" >&2; exit 1; }

username="$(sed -nE 's/^GITHUB_USERNAME=(.*)$/\1/p' "$ENV_FILE" | head -1)"
token="$(sed -nE 's/^GITHUB_TOKEN=(.*)$/\1/p' "$ENV_FILE" | head -1)"

if [[ -z "$token" ]]; then
  echo "error: GITHUB_TOKEN vide dans .env — voir .env.example" >&2
  exit 1
fi
# GitHub accepte n'importe quel login non vide accompagné d'un PAT.
[[ -n "$username" ]] || username="x-access-token"

cat <<EOF
protocol=https
host=github.com
username=$username
password=$token
EOF
