#!/usr/bin/env bash
# Initialise et vérifie la configuration locale du projet (.env) en gardant les
# secrets hors de git, tout en versionnant leur description (.env.example).
#
#   init.sh check    Vérifie .env vs .env.example (défaut). Sortie != 0 si problème.
#   init.sh init     Crée .env à partir de .env.example (n'écrase jamais), puis check.
#   init.sh sync     Ajoute à .env les clés présentes dans .env.example et absentes.
#   init.sh doctor   Comme check, mais tente de corriger ce qui est corrigeable
#                    (permissions, .gitignore, clés manquantes).
#
# Aucune dépendance : bash + coreutils + git. Rien n'est installé sur l'hôte.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ENV_FILE="$ROOT/.env"
EXAMPLE_FILE="$ROOT/.env.example"
GITIGNORE="$ROOT/.gitignore"

fails=0
warns=0
ok()   { printf '  OK    %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; warns=$((warns + 1)); }
fail() { printf '  FAIL  %s\n' "$*"; fails=$((fails + 1)); }
head_() { printf '\n%s\n' "$*"; }

# Clés déclarées dans un fichier .env-like (ignore commentaires et lignes vides).
keys_of() { grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null | tr -d '=' | sort -u; }

# Valeur brute d'une clé (première occurrence), guillemets compris.
value_of() { sed -nE "s/^$2=(.*)$/\1/p" "$1" 2>/dev/null | head -1; }

# Clés marquées REQUIS dans le bloc de commentaires qui les précède.
required_keys() {
  awk '
    /^[[:space:]]*#/ { block = block " " $0; next }
    /^[A-Za-z_][A-Za-z0-9_]*=/ {
      key = substr($0, 1, index($0, "=") - 1)
      if (block ~ /REQUIS/) print key
      block = ""; next
    }
    { block = "" }
  ' "$1" 2>/dev/null
}

# ---------------------------------------------------------------- actions ---

ensure_gitignore() {
  local fix="$1"
  if [[ -f "$GITIGNORE" ]] && grep -qxE '\.env|/\.env|\*\*/\.env' "$GITIGNORE"; then
    ok ".gitignore couvre .env"
  elif [[ "$fix" == "fix" ]]; then
    printf '\n# Secrets locaux (jamais versionnés) — le modèle versionné est .env.example\n.env\n.env.local\n' >> "$GITIGNORE"
    ok ".gitignore complété avec .env"
  else
    fail ".env n'est pas listé dans .gitignore — risque de commit de secrets"
  fi
}

create_env() {
  if [[ -f "$ENV_FILE" ]]; then
    ok ".env existe déjà (non écrasé)"
    return 0
  fi
  if [[ ! -f "$EXAMPLE_FILE" ]]; then
    fail "ni .env ni .env.example — rien pour amorcer la configuration"
    return 1
  fi
  cp "$EXAMPLE_FILE" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  sed -i '1i # Secrets locaux — NE JAMAIS COMMITER. Généré depuis .env.example.' "$ENV_FILE"
  ok ".env créé depuis .env.example (valeurs à renseigner)"
}

sync_env() {
  [[ -f "$ENV_FILE" && -f "$EXAMPLE_FILE" ]] || { fail "il faut .env ET .env.example pour synchroniser"; return 1; }
  local added=0 k
  while read -r k; do
    [[ -n "$k" ]] || continue
    if ! grep -qE "^$k=" "$ENV_FILE"; then
      [[ $added -eq 0 ]] && printf '\n# --- Ajouté par project-init (à renseigner) ---\n' >> "$ENV_FILE"
      printf '%s=\n' "$k" >> "$ENV_FILE"
      ok "clé ajoutée à .env : $k"
      added=$((added + 1))
    fi
  done < <(comm -23 <(keys_of "$EXAMPLE_FILE") <(keys_of "$ENV_FILE"))
  [[ $added -eq 0 ]] && ok ".env contient déjà toutes les clés de .env.example"
  return 0
}

check_all() {
  local fix="${1:-nofix}"

  head_ "1. Fichiers"
  [[ -f "$EXAMPLE_FILE" ]] && ok ".env.example présent (versionné, sans secret)" \
                           || fail ".env.example manquant — personne ne peut savoir quoi configurer"
  if [[ -f "$ENV_FILE" ]]; then
    ok ".env présent"
  else
    fail ".env manquant — lancer: $0 init"
    return
  fi

  head_ "2. Secrets hors de git"
  ensure_gitignore "$fix"
  if git -C "$ROOT" ls-files --error-unmatch .env >/dev/null 2>&1; then
    fail ".env est SUIVI par git — le retirer: git rm --cached .env"
  else
    ok ".env n'est pas suivi par git"
  fi
  if [[ -n "$(git -C "$ROOT" log --all --oneline -- .env 2>/dev/null)" ]]; then
    fail ".env apparaît dans l'historique git — les secrets exposés sont à révoquer"
  else
    ok ".env absent de l'historique git"
  fi
  local perms; perms="$(stat -c '%a' "$ENV_FILE")"
  if [[ "$perms" == "600" ]]; then
    ok ".env en permissions 600"
  elif [[ "$fix" == "fix" ]]; then
    chmod 600 "$ENV_FILE"; ok ".env repassé en permissions 600 (était $perms)"
  else
    warn ".env en permissions $perms (attendu 600)"
  fi

  head_ "3. Aucun secret réel dans le modèle versionné"
  if [[ -f "$EXAMPLE_FILE" ]]; then
    if grep -qE 'gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY' "$EXAMPLE_FILE"; then
      fail ".env.example contient ce qui ressemble à un vrai secret"
    else
      ok "aucun motif de secret connu dans .env.example"
    fi
    local k ev xv leaked=0
    while read -r k; do
      [[ -n "$k" ]] || continue
      case "$k" in *PASSWORD*|*TOKEN*|*SECRET*|*KEY*) ;; *) continue ;; esac
      ev="$(value_of "$ENV_FILE" "$k")"; xv="$(value_of "$EXAMPLE_FILE" "$k")"
      if [[ -n "$ev" && "$ev" == "$xv" ]]; then
        fail "$k a la même valeur dans .env et .env.example — secret probablement recopié dans le modèle"
        leaked=1
      fi
    done < <(comm -12 <(keys_of "$ENV_FILE") <(keys_of "$EXAMPLE_FILE"))
    [[ $leaked -eq 0 ]] && ok "aucune valeur sensible partagée entre .env et .env.example"
  fi

  head_ "4. .env vs .env.example"
  if [[ -f "$EXAMPLE_FILE" ]]; then
    local missing extra
    missing="$(comm -23 <(keys_of "$EXAMPLE_FILE") <(keys_of "$ENV_FILE"))"
    extra="$(comm -13 <(keys_of "$EXAMPLE_FILE") <(keys_of "$ENV_FILE"))"
    if [[ -n "$missing" ]]; then
      if [[ "$fix" == "fix" ]]; then sync_env
      else fail "clés du modèle absentes de .env : $(echo "$missing" | tr '\n' ' ')— lancer: $0 sync"; fi
    else
      ok "toutes les clés du modèle sont dans .env"
    fi
    if [[ -n "$extra" ]]; then
      warn "clés dans .env mais pas documentées dans .env.example : $(echo "$extra" | tr '\n' ' ')— les ajouter au modèle (nom + rôle, valeur vide)"
    else
      ok "aucune clé non documentée dans .env"
    fi
  fi

  head_ "5. Valeurs"
  local k v need_fill=0
  while read -r k; do
    [[ -n "$k" ]] || continue
    v="$(value_of "$ENV_FILE" "$k")"
    if [[ -z "$v" ]]; then
      fail "$k est marquée REQUIS dans .env.example mais vide dans .env"
      need_fill=1
    fi
  done < <(required_keys "$EXAMPLE_FILE")
  [[ $need_fill -eq 0 ]] && ok "toutes les variables REQUIS sont renseignées"

  if grep -qE '^[A-Za-z_][A-Za-z0-9_]*=.*CHANGEME' "$ENV_FILE"; then
    warn "valeurs placeholder CHANGEME encore présentes dans .env : $(awk -F= '/CHANGEME/ && /^[A-Za-z_]/ {printf "%s ", $1}' "$ENV_FILE")"
  else
    ok "aucun placeholder CHANGEME restant"
  fi

  # Le parseur .env de superset-upload fait un simple split sur "=" sans retirer
  # les guillemets : SUPERSET_PASSWORD="x" authentifierait avec la valeur «"x"».
  local quoted
  quoted="$(grep -E '^SUPERSET_[A-Z_]+=("|'\'').*("|'\'')$' "$ENV_FILE" | cut -d= -f1 | tr '\n' ' ')"
  if [[ -n "$quoted" ]]; then
    warn "valeurs entre guillemets : $quoted— le parseur de upload_to_superset.py ne les retire pas, les guillemets feraient partie de la valeur"
  else
    ok "aucune variable SUPERSET_* entre guillemets"
  fi
}

summary() {
  head_ "Résultat"
  if [[ $fails -gt 0 ]]; then
    printf '  %d problème(s), %d avertissement(s).\n' "$fails" "$warns"; return 1
  fi
  printf '  Configuration saine (%d avertissement(s)).\n' "$warns"; return 0
}

case "${1:-check}" in
  check)  check_all nofix ;;
  doctor) check_all fix ;;
  init)   head_ "Initialisation"; ensure_gitignore fix; create_env; check_all nofix ;;
  sync)   head_ "Synchronisation"; sync_env ;;
  *)      sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
summary
