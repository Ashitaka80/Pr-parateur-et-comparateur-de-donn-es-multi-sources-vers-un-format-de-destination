#!/usr/bin/env bash
# Outillage de traçabilité : ADR, spécifications, registre des délégations.
#
#   trace.sh adr "<titre>"    Crée le prochain ADR pré-rempli (décideur = identité git).
#   trace.sh spec "<titre>"   Crée la prochaine spécification.
#   trace.sh index            Régénère les index de docs/decisions et docs/specs.
#   trace.sh check            Vérifie frontmatter, statuts, références croisées, index.
#   trace.sh list             Vue d'ensemble : décisions, délégations, points en attente.
#
# Aucune dépendance : bash + coreutils + git.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DEC="$ROOT/docs/decisions"
SPEC="$ROOT/docs/specs"
REG="$ROOT/docs/delegations/REGISTRE.md"

fails=0; warns=0
ok()   { printf '  OK    %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; warns=$((warns + 1)); }
fail() { printf '  FAIL  %s\n' "$*"; fails=$((fails + 1)); }
head_(){ printf '\n%s\n' "$*"; }

STATUTS_ADR="proposée acceptée rejetée remplacée obsolète"
STATUTS_SPEC="brouillon validée implémentée abandonnée"
CHAMPS_ADR="id titre statut date décideur proposé par validation délégation"

# Valeur d'un champ de frontmatter YAML (première occurrence, avant le second ---).
field() { awk -v k="$2" '
  NR == 1 && $0 == "---" { inb = 1; next }
  inb && $0 == "---" { exit }
  inb {
    key = $0; sub(/:.*/, "", key)
    if (key == k) {
      v = $0; sub(/^[^:]*:[[:space:]]*/, "", v)
      sub(/[[:space:]][[:space:]]+#.*$/, "", v)   # commentaire du modele
      sub(/^#.*$/, "", v)                        # valeur vide suivie du commentaire
      sub(/[[:space:]]+$/, "", v)
      print v; exit
    }
  }' "$1"; }

slug() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 'y/àâäéèêëîïôöùûüç/aaaeeeeiioouuuc/; s/[^a-z0-9]+/-/g; s/^-+|-+$//g' \
    | cut -c1-60
}

next_id() { # $1 = dossier, $2 = préfixe
  local n
  n=$(find "$1" -maxdepth 1 -name "$2-[0-9][0-9][0-9][0-9]-*.md" -printf '%f\n' 2>/dev/null \
      | sed -E "s/^$2-([0-9]{4}).*/\1/" | sort -n | tail -1)
  printf '%04d' $(( 10#${n:-0} + 1 ))
}

git_identity() {
  local n e
  n="$(git -C "$ROOT" config user.name)"; e="$(git -C "$ROOT" config user.email)"
  [[ -n "$n" && -n "$e" ]] && printf '%s <%s>' "$n" "$e" || printf ''
}

today() { date +%F; }

# ------------------------------------------------------------------ créer ---

new_doc() { # $1 = adr|spec
  local kind="$1" titre="$2" dir prefix id file who
  [[ -n "$titre" ]] || { echo "usage: trace.sh $kind \"<titre>\"" >&2; return 2; }
  if [[ "$kind" == "adr" ]]; then dir="$DEC"; prefix="ADR"; else dir="$SPEC"; prefix="SPEC"; fi
  [[ -f "$dir/TEMPLATE.md" ]] || { echo "modèle absent : $dir/TEMPLATE.md" >&2; return 1; }

  id="$(next_id "$dir" "$prefix")"
  file="$dir/$prefix-$id-$(slug "$titre").md"
  who="$(git_identity)"
  [[ -n "$who" ]] || { who=""; warn "identité git absente — renseigner 'décideur' à la main (git config user.name/user.email)"; }

  cp "$dir/TEMPLATE.md" "$file"
  sed -i "s|^id: .*|id: $prefix-$id|; s|^titre: .*|titre: $titre|; s|^date: .*|date: $(today)|" "$file"
  if [[ "$kind" == "adr" ]]; then
    sed -i "s|^décideur:.*|décideur: $who|; s|^proposé par:.*|proposé par: |" "$file"
  else
    sed -i "s|^auteur:.*|auteur: $who|" "$file"
  fi
  echo "créé : ${file#$ROOT/}"
  echo
  echo "Rappels :"
  echo "  - 'décideur' doit être la personne qui tranche, pas Claude (docs/CONTRIBUTEURS.md)."
  echo "  - Si Claude a tranché seul : validation: à confirmer, et 'délégation:' renseignée."
  echo "  - Documenter les options écartées : leur trace évite de les réexplorer."
  echo "  - Puis : trace.sh index"
}

# ------------------------------------------------------------------ index ---

build_index() { # $1 = adr|spec  → table markdown sur stdout
  local dir prefix f id titre statut who
  if [[ "$1" == "adr" ]]; then dir="$DEC"; prefix="ADR"; else dir="$SPEC"; prefix="SPEC"; fi
  local files; files=$(find "$dir" -maxdepth 1 -name "$prefix-[0-9][0-9][0-9][0-9]-*.md" | sort)
  [[ -n "$files" ]] || { echo "_Aucun document pour l'instant._"; return; }
  if [[ "$1" == "adr" ]]; then
    echo "| ID | Décision | Statut | Décideur | Validation |"
    echo "|---|---|---|---|---|"
  else
    echo "| ID | Spécification | Statut | Auteur |"
    echo "|---|---|---|---|"
  fi
  while read -r f; do
    [[ -n "$f" ]] || continue
    id="$(field "$f" id)"; titre="$(field "$f" titre)"; statut="$(field "$f" statut)"
    if [[ "$1" == "adr" ]]; then
      who="$(field "$f" décideur)"
      printf '| [%s](%s) | %s | %s | %s | %s |\n' "$id" "$(basename "$f")" "$titre" "$statut" \
        "${who:-—}" "$(field "$f" validation)"
    else
      who="$(field "$f" auteur)"
      printf '| [%s](%s) | %s | %s | %s |\n' "$id" "$(basename "$f")" "$titre" "$statut" "${who:-—}"
    fi
  done <<< "$files"
}

write_index() { # $1 = adr|spec, $2 = fichier index
  local content; content="$(build_index "$1")"
  if [[ ! -f "$2" ]] || ! grep -q 'INDEX:début' "$2"; then
    { echo "# Index"; echo; echo "<!-- INDEX:début - régénéré par trace.sh index, ne pas éditer à la main -->";
      echo "$content"; echo "<!-- INDEX:fin -->"; } > "$2"
  else
    local tmp="$2.tmp"
    awk -v c="$content" '
      /INDEX:début/ { print; print c; skip = 1; next }
      /INDEX:fin/   { skip = 0 }
      !skip { print }
    ' "$2" > "$tmp" && mv "$tmp" "$2"
  fi
  ok "index régénéré : ${2#$ROOT/}"
}

# ------------------------------------------------------------------ check ---

check_all() {
  head_ "1. Arborescence"
  local d
  for d in "$DEC" "$SPEC" "$(dirname "$REG")"; do
    [[ -d "$d" ]] && ok "${d#$ROOT/} présent" || fail "${d#$ROOT/} manquant"
  done
  [[ -f "$REG" ]] && ok "registre des délégations présent" || fail "registre manquant : ${REG#$ROOT/}"

  head_ "2. Frontmatter des ADR"
  local f id statut val deleg dec champ
  while read -r f; do
    [[ -n "$f" ]] || continue
    local base; base="$(basename "$f")"
    id="$(field "$f" id)"
    [[ "$base" == "$id"-* ]] || fail "$base : le champ id ($id) ne correspond pas au nom de fichier"
    while IFS= read -r champ; do
      [[ -n "$(field "$f" "$champ")" ]] || fail "$base : champ '$champ' vide ou absent"
    done < <(printf 'id\ntitre\nstatut\ndate\ndécideur\nvalidation\n')
    statut="$(field "$f" statut)"
    grep -qw -- "$statut" <<< "$STATUTS_ADR" || fail "$base : statut inconnu « $statut » (attendu : $STATUTS_ADR)"
    val="$(field "$f" validation)"
    [[ "$val" == "confirmée" || "$val" == "à confirmer" ]] \
      || fail "$base : validation « $val » (attendu : confirmée | à confirmer)"
    dec="$(field "$f" décideur)"
    [[ "$dec" == *Claude* ]] && fail "$base : Claude ne peut pas être décideur — nommer la personne qui valide"
    if [[ -n "$dec" && "$dec" != *Claude* ]] && ! grep -qF "$dec" "$ROOT/docs/CONTRIBUTEURS.md" 2>/dev/null; then
      warn "$base : décideur « $dec » absent de docs/CONTRIBUTEURS.md — l'attribution n'est rattachable à personne"
    fi
    deleg="$(field "$f" délégation)"
    if [[ -n "$deleg" && "$deleg" != "—" ]]; then
      grep -q "### $deleg " "$REG" 2>/dev/null || fail "$base : délégation $deleg introuvable dans le registre"
    fi
    if [[ "$(field "$f" 'remplacé par')" =~ ADR-[0-9]{4} ]]; then
      [[ "$statut" == "remplacée" ]] || warn "$base : porte 'remplacé par' mais son statut est « $statut »"
    fi
  done < <(find "$DEC" -maxdepth 1 -name 'ADR-[0-9][0-9][0-9][0-9]-*.md' | sort)
  [[ $fails -eq 0 ]] && ok "tous les ADR ont un frontmatter valide"

  head_ "3. Index à jour"
  local tmpdir; tmpdir="$(mktemp -d)"
  local k file
  for k in adr spec; do
    [[ "$k" == "adr" ]] && file="$DEC/README.md" || file="$SPEC/README.md"
    if [[ -f "$file" ]] && grep -q 'INDEX:début' "$file"; then
      local current expected
      current="$(awk '/INDEX:début/{f=1;next} /INDEX:fin/{f=0} f' "$file")"
      expected="$(build_index "$k")"
      [[ "$current" == "$expected" ]] && ok "index $k à jour" \
        || fail "index $k périmé — lancer: trace.sh index"
    else
      fail "index $k absent ou sans marqueurs INDEX:début/fin"
    fi
  done
  rm -rf "$tmpdir"

  head_ "4. Points en attente"
  local n
  n=$(grep -lE '^validation: à confirmer' "$DEC"/ADR-*.md 2>/dev/null | wc -l)
  [[ "$n" -gt 0 ]] && warn "$n décision(s) appliquée(s) mais non ratifiée(s) par un humain (validation: à confirmer)" \
                   || ok "toutes les décisions sont ratifiées"
  n=$(grep -cE '^\- \*\*Statut\*\* : \*\*à confirmer\*\*' "$REG" 2>/dev/null)
  [[ "$n" -gt 0 ]] && warn "$n entrée(s) du registre à confirmer" || ok "registre entièrement confirmé"
}

# ------------------------------------------------------------------- list ---

list_all() {
  head_ "Décisions"
  build_index adr
  head_ "Délégations et directives permanentes"
  grep -E '^### (D|DP)-[0-9]{4}' "$REG" 2>/dev/null | sed 's/^### /  /' || echo "  (registre absent)"
  head_ "En attente de ratification"
  local f
  while read -r f; do
    [[ -n "$f" ]] || continue
    printf '  %s — %s\n' "$(field "$f" id)" "$(field "$f" titre)"
  done < <(grep -lE '^validation: à confirmer' "$DEC"/ADR-*.md 2>/dev/null | sort)
  grep -B3 -E '^\- \*\*Statut\*\* : \*\*à confirmer\*\*' "$REG" 2>/dev/null \
    | grep -E '^### ' | sed 's/^### /  /'
}

summary() {
  head_ "Résultat"
  if [[ $fails -gt 0 ]]; then printf '  %d problème(s), %d avertissement(s).\n' "$fails" "$warns"; return 1; fi
  printf '  Traçabilité conforme (%d avertissement(s)).\n' "$warns"; return 0
}

case "${1:-check}" in
  adr)   new_doc adr "${2:-}" ;;
  spec)  new_doc spec "${2:-}" ;;
  index) head_ "Index"; write_index adr "$DEC/README.md"; write_index spec "$SPEC/README.md"; summary ;;
  check) check_all; summary ;;
  list)  list_all ;;
  *)     sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
