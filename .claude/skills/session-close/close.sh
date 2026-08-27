#!/usr/bin/env bash
# Vérifie qu'une session peut être clôturée sans laisser un collègue dans le noir.
# Lecture seule : ne commite rien, ne pousse rien, ne modifie aucun fichier.
#
#   close.sh          Audit complet. Sortie != 0 s'il reste quelque chose à faire.
#
# Contrepartie de la délégation D-0003 : « en fin de session, un collègue doit être en
# mesure de prendre la suite ».
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$ROOT"

fails=0; warns=0
ok()   { printf '  OK    %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; warns=$((warns + 1)); }
fail() { printf '  FAIL  %s\n' "$*"; fails=$((fails + 1)); }
head_(){ printf '\n%s\n' "$*"; }

run_check() { # $1 = libellé, $2 = commande
  if [[ ! -x "$2" ]]; then warn "$1 : outil absent ($2)"; return; fi
  if "$2" check >/dev/null 2>&1; then ok "$1 : au vert"
  else fail "$1 : en échec — lancer $2 check"; fi
}

head_ "1. Contrôles outillés"
run_check "configuration (project-init)" ".claude/skills/project-init/init.sh"
run_check "traçabilité (decision-log)"   ".claude/skills/decision-log/trace.sh"

head_ "2. Document de passation"
P="docs/PASSATION.md"
if [[ ! -f "$P" ]]; then
  fail "$P absent — c'est le document que lit le collègue qui reprend"
else
  today="$(date +%F)"
  stamped="$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$P" | head -1)"
  if [[ "$stamped" == "$today" ]]; then
    ok "$P daté d'aujourd'hui ($today)"
  else
    fail "$P porte la date $stamped, pas $today — le relire et le remettre à jour"
  fi
  # Un travail commité aujourd'hui sans passation touchée = état non transmis.
  if [[ -n "$(git log --since=midnight --oneline 2>/dev/null)" ]] \
     && [[ -z "$(git log --since=midnight --oneline -- "$P" 2>/dev/null)" ]]; then
    warn "des commits ont été faits aujourd'hui sans toucher à $P"
  fi
fi

head_ "3. État git"
branch="$(git branch --show-current)"
if [[ "$branch" == "main" || "$branch" == "master" ]]; then
  fail "travail sur « $branch » — ADR-0009 impose une branche thématique"
else
  ok "branche thématique : $branch"
fi
n="$(git status --porcelain | wc -l)"
if [[ "$n" -eq 0 ]]; then ok "arbre de travail propre"
else fail "$n fichier(s) non committé(s) — un collègue ne les verrait pas"; fi
if git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  ahead="$(git rev-list --count '@{upstream}'..HEAD)"
  [[ "$ahead" -eq 0 ]] && ok "tout est poussé sur origin" \
                       || fail "$ahead commit(s) non poussé(s) — invisibles pour l'équipe"
else
  fail "branche sans upstream — jamais poussée (git push -u origin $branch)"
fi

head_ "4. Secrets"
if git log --all --oneline -- .env 2>/dev/null | grep -q .; then
  fail ".env apparaît dans l'historique git — secrets à révoquer"
else
  ok ".env absent de l'historique git"
fi

head_ "5. En attente d'une décision humaine"
T=".claude/skills/decision-log/trace.sh"
if [[ -x "$T" ]]; then
  pending="$("$T" list 2>/dev/null | sed -n '/En attente de ratification/,$p' | tail -n +2 | sed '/^$/d')"
  if [[ -n "$pending" ]]; then
    warn "points à soumettre avant de partir :"; printf '%s\n' "$pending" | sed 's/^/     /'
  else
    ok "rien en attente de ratification"
  fi
fi

printf '\nRésultat\n'
if [[ $fails -gt 0 ]]; then
  printf '  Session NON clôturable : %d point(s) bloquant(s), %d avertissement(s).\n' "$fails" "$warns"
  exit 1
fi
printf '  Session clôturable (%d avertissement(s)).\n' "$warns"
