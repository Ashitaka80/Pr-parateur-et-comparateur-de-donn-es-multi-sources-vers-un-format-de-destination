#!/usr/bin/env bash
# Pilote la stack Superset vendorisée dans ce dépôt.
#
#   superset.sh secrets   Génère docker/.env-local (mots de passe aléatoires) — une fois.
#   superset.sh up        Démarre la stack.
#   superset.sh down      Arrête la stack (les données Postgres survivent).
#   superset.sh reset     Arrête ET supprime les volumes — perte de données.
#   superset.sh status    État des conteneurs.
#   superset.sh logs [svc] Suit les logs.
#
# Le nom de projet compose est figé à « superset » : le réseau docker s'appelle donc
# toujours superset_default, valeur attendue par .claude/skills/superset-upload/upload.sh.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export COMPOSE_PROJECT_NAME=superset
export TAG="${TAG:-latest}"          # image de prod ; latest-dev embarque l'outillage de dev
COMPOSE=(docker compose -f docker-compose-image-tag.yml)
ENV_LOCAL="docker/.env-local"

gen() { tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-32}"; }

secrets() {
  if [[ -f "$ENV_LOCAL" ]]; then
    echo "$ENV_LOCAL existe déjà — non écrasé (il contient les mots de passe en service)." >&2
    return 1
  fi
  local pg admin secret
  pg="$(gen 32)"; admin="$(gen 24)"; secret="$(gen 48)"
  cat > "$ENV_LOCAL" <<EOF
# Secrets de la stack Superset — généré par superset.sh secrets, NON VERSIONNÉ.
# Modèle documenté : docker/.env-local.example (upstream) et le README de ce dossier.

SUPERSET_SECRET_KEY=$secret

# Ces deux variables doivent rester IDENTIQUES : POSTGRES_PASSWORD est le mot de passe
# que le conteneur db attribue à l'utilisateur superset, DATABASE_PASSWORD celui que
# l'application utilise pour s'y connecter. Un écart fait échouer superset-init sur
# « password authentication failed ».
POSTGRES_PASSWORD=$pg
DATABASE_PASSWORD=$pg

ADMIN_PASSWORD=$admin

# Le proxy doit être injecté dans les conteneurs, pas seulement dans le daemon docker :
# superset-init installe des dépendances pip au démarrage et doit atteindre pypi.org.
HTTP_PROXY=${HTTP_PROXY:-}
HTTPS_PROXY=${HTTPS_PROXY:-}
NO_PROXY=${NO_PROXY:-localhost,127.0.0.1,superset_app,superset_db,superset_cache}
EOF
  chmod 600 "$ENV_LOCAL"
  echo "Généré : infra/superset/$ENV_LOCAL (permissions 600, non versionné)"
  echo
  echo "À reporter dans le .env à la racine du dépôt :"
  echo "  SUPERSET_PASSWORD=$admin"
  echo "  SUPERSET_UPLOAD_SQLALCHEMY_URI=postgresql+psycopg2://superset:$pg@superset_db:5432/uploads"
  echo
  echo "Puis : ./infra/superset/superset.sh up"
}

require_secrets() {
  [[ -f "$ENV_LOCAL" ]] || { echo "manque $ENV_LOCAL — lancer d'abord: superset.sh secrets" >&2; exit 2; }
}

case "${1:-}" in
  secrets) secrets ;;
  up)      require_secrets; "${COMPOSE[@]}" up -d
           echo; echo "Superset démarre sur http://localhost:8088 (première initialisation : plusieurs minutes)."
           echo "Suivre : ./infra/superset/superset.sh logs superset-init" ;;
  down)    "${COMPOSE[@]}" down ;;
  reset)   read -rp "Supprimer les volumes (metadata Superset ET base uploads) ? [oui/non] " r
           [[ "$r" == "oui" ]] && "${COMPOSE[@]}" down -v || echo "annulé" ;;
  status)  "${COMPOSE[@]}" ps ;;
  logs)    shift; "${COMPOSE[@]}" logs -f "$@" ;;
  *)       sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
