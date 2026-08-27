#!/usr/bin/env bash
# Pilote la stack Superset vendorisée dans ce dépôt.
#
#   superset.sh bootstrap  Configure tout depuis zéro : .env, secrets, stack, image
#                          uploader. Idempotent, ne réécrit rien d'existant.
#   superset.sh smoke-test Uploade un fichier de test, vérifie, puis nettoie. À lancer
#                          après bootstrap pour confirmer que la chaîne fonctionne.
#   superset.sh secrets   Génère docker/.env-local (mots de passe aléatoires) — une fois.
#   superset.sh up        Démarre la stack.
#   superset.sh down      Arrête la stack (les données Postgres survivent).
#   superset.sh reset     Arrête ET supprime les volumes — perte de données.
#   superset.sh status    État des conteneurs.
#   superset.sh db-uploads Crée la base Postgres des uploads si elle manque (idempotent).
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
REPO_ROOT="$(cd ../.. && pwd)"

# head -c fermerait le tube en amont : sous « set -o pipefail », le SIGPIPE reçu par tr
# ferait échouer la fonction. On lit donc une quantité fixe d'octets, puis on tronque.
gen() {
  local n="${1:-32}" raw
  raw="$(head -c "$((n * 3))" /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"
  printf '%s' "${raw:0:n}"
}

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

# Instance propre : pas de jeux de données d'exemple. Le docker/.env d'upstream les
# active par défaut, ce qui charge des centaines de milliers de lignes sans rapport
# avec le projet et allonge fortement la première initialisation.
SUPERSET_LOAD_EXAMPLES=no

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

# La base des données uploadées est distincte de la metadata DB (ADR-0004) et n'est
# créée ni par le compose, ni par le tool d'upload : celui-ci enregistre la connexion
# côté Superset, mais échoue sur « Unable to connect to database » si la base Postgres
# n'existe pas. Ce pas est idempotent et rejoué à chaque « up ».
ensure_uploads_db() {
  local root_env="../../.env" name=uploads
  if [[ -f "$root_env" ]]; then
    local uri
    uri="$(sed -nE 's|^SUPERSET_UPLOAD_SQLALCHEMY_URI=.*/([A-Za-z0-9_]+)[[:space:]]*$|\1|p' "$root_env" | head -1)"
    [[ -n "$uri" ]] && name="$uri"
  fi
  docker exec superset_db pg_isready -U superset -q 2>/dev/null || {
    echo "superset_db n'est pas prêt — base « $name » non créée." >&2; return 1; }
  if docker exec superset_db psql -U superset -d superset -tAc \
       "SELECT 1 FROM pg_database WHERE datname='$name'" 2>/dev/null | grep -q 1; then
    echo "base « $name » déjà présente"
  else
    docker exec superset_db createdb -U superset "$name" && echo "base « $name » créée"
  fi
}

up_cmd() {
  require_secrets
  # Les workers Celery bouclent en redémarrage sur cette image (bug amont,
  # ADR-0006) et ne servent pas à l'upload synchrone. On ne les démarre donc
  # pas du tout, plutôt que de les arrêter à la main après coup.
  # WITH_WORKERS=1 pour les lancer quand même (fonctionnalités asynchrones).
  if [[ "${WITH_WORKERS:-0}" == "1" ]]; then
    "${COMPOSE[@]}" up -d
  else
    "${COMPOSE[@]}" up -d --scale superset-worker=0 --scale superset-worker-beat=0
  fi
  ensure_uploads_db || true
}

# Attend que superset_app soit healthy, pas seulement démarré : la première init
# (migrations, création admin) prend plusieurs minutes après que le conteneur tourne.
wait_healthy() {
  local timeout="${BOOTSTRAP_TIMEOUT:-300}" waited=0 status
  echo "Attente de superset_app (healthy) — jusqu'à ${timeout}s…"
  while true; do
    status="$(docker inspect --format='{{.State.Health.Status}}' superset_app 2>/dev/null || echo absent)"
    [[ "$status" == "healthy" ]] && { echo "superset_app est prêt."; return 0; }
    if (( waited >= timeout )); then
      echo "délai dépassé (${timeout}s) en attendant superset_app (état: $status)" >&2
      return 1
    fi
    sleep 5; waited=$((waited + 5))
  done
}

# Reporte ADMIN_PASSWORD/POSTGRES_PASSWORD de $ENV_LOCAL dans le .env racine —
# uniquement les valeurs encore vides ou à CHANGEME, jamais une valeur déjà
# renseignée à la main (une resynchronisation ne doit pas écraser un choix humain).
populate_root_env() {
  local root_env="$REPO_ROOT/.env" admin_pw pg_pw
  [[ -f "$root_env" ]] || { echo "manque $root_env — lancer d'abord: superset.sh bootstrap" >&2; return 1; }
  admin_pw="$(sed -nE 's/^ADMIN_PASSWORD=(.*)$/\1/p' "$ENV_LOCAL" | head -1)"
  pg_pw="$(sed -nE 's/^POSTGRES_PASSWORD=(.*)$/\1/p' "$ENV_LOCAL" | head -1)"

  if grep -qE '^SUPERSET_PASSWORD=$' "$root_env"; then
    sed -i "s/^SUPERSET_PASSWORD=.*/SUPERSET_PASSWORD=$admin_pw/" "$root_env"
    echo "SUPERSET_PASSWORD reporté dans .env"
  fi
  if grep -qE '^SUPERSET_UPLOAD_SQLALCHEMY_URI=.*CHANGEME' "$root_env"; then
    sed -i "s/CHANGEME/$pg_pw/" "$root_env"
    echo "SUPERSET_UPLOAD_SQLALCHEMY_URI reporté dans .env"
  fi
}

# Configure tout depuis une machine neuve, sans écraser ce qui existe déjà
# (ADR-0011). Idempotent : rejouable sans effet si une étape est déjà faite.
bootstrap() {
  local root_env="$REPO_ROOT/.env"
  local project_init="$REPO_ROOT/.claude/skills/project-init/init.sh"
  local uploader_dir="$REPO_ROOT/.claude/skills/superset-upload"

  if [[ -f "$root_env" ]]; then
    echo "== .env racine déjà présent — inchangé =="
  else
    echo "== amorçage du .env racine depuis .env.example =="
    "$project_init" init
  fi

  if [[ -f "$ENV_LOCAL" ]]; then
    echo "== secrets déjà générés ($ENV_LOCAL) — inchangés =="
  else
    echo "== génération des secrets Superset =="
    secrets
  fi

  echo "== démarrage de la stack =="
  up_cmd
  wait_healthy

  echo "== report des secrets dans le .env racine =="
  populate_root_env

  echo "== build de l'image superset-uploader =="
  docker build -t superset-uploader:latest \
    --build-arg HTTP_PROXY="${HTTP_PROXY:-}" --build-arg HTTPS_PROXY="${HTTPS_PROXY:-}" \
    "$uploader_dir"

  echo "== vérification de la configuration =="
  "$project_init" check

  echo
  echo "Bootstrap terminé. Superset : http://localhost:8088"
  echo "Vérifier la chaîne complète : ./infra/superset/superset.sh smoke-test"
}

# Uploade un petit fichier de test, vérifie qu'il est bien en base, puis nettoie
# dataset et table — que le test réussisse ou échoue (ADR-0011).
smoke_test() {
  local root_env="$REPO_ROOT/.env"
  local uploader_dir="$REPO_ROOT/.claude/skills/superset-upload"
  [[ -f "$root_env" ]] || { echo "manque .env racine — lancer d'abord: superset.sh bootstrap" >&2; return 2; }
  docker image inspect superset-uploader:latest >/dev/null 2>&1 || {
    echo "image superset-uploader absente — lancer d'abord: superset.sh bootstrap" >&2; return 2; }

  local tmp table rows=10 ok=1 counted
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  table="smoke_test_$(date +%s)"

  {
    echo "id,label,value"
    for i in $(seq 1 "$rows"); do echo "$i,item_$i,$((i * 7))"; done
  } > "$tmp/smoke_test.csv"

  echo "== upload de $rows lignes vers la table « $table » =="
  if ! "$uploader_dir/upload.sh" --file "$tmp/smoke_test.csv" --table-name "$table" --if-exists replace; then
    echo "échec de l'upload" >&2
    ok=0
  fi

  if [[ "$ok" == 1 ]]; then
    counted="$(docker exec superset_db psql -U superset -d uploads -tAc "SELECT COUNT(*) FROM $table" 2>/dev/null || echo -1)"
    if [[ "$counted" == "$rows" ]]; then
      echo "== vérifié en base : $counted lignes =="
    else
      echo "échec de la vérification : $counted lignes en base, $rows attendues" >&2
      ok=0
    fi
  fi

  echo "== nettoyage =="
  "$uploader_dir/delete_dataset.sh" --table-name "$table" \
    || echo "avertissement : dataset non supprimé (peut-être déjà absent)" >&2
  docker exec superset_db psql -U superset -d uploads -c "DROP TABLE IF EXISTS $table;" >/dev/null \
    || echo "avertissement : suppression de la table échouée" >&2

  if [[ "$ok" == 1 ]]; then
    echo; echo "smoke-test OK : la chaîne préparation → upload → dataset Superset fonctionne."
    return 0
  else
    echo; echo "smoke-test EN ÉCHEC — voir les messages ci-dessus." >&2
    return 1
  fi
}

case "${1:-}" in
  bootstrap) bootstrap ;;
  smoke-test) smoke_test ;;
  secrets) secrets ;;
  up)      up_cmd
           echo; echo "Superset démarre sur http://localhost:8088 (première initialisation : plusieurs minutes)."
           echo "Suivre : ./infra/superset/superset.sh logs superset-init" ;;
  db-uploads) ensure_uploads_db ;;
  down)    "${COMPOSE[@]}" down ;;
  reset)   read -rp "Supprimer les volumes (metadata Superset ET base uploads) ? [oui/non] " r
           [[ "$r" == "oui" ]] && "${COMPOSE[@]}" down -v || echo "annulé" ;;
  status)  "${COMPOSE[@]}" ps ;;
  logs)    shift; "${COMPOSE[@]}" logs -f "$@" ;;
  *)       sed -n '2,14p' "$(basename "${BASH_SOURCE[0]}")" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
