# TP_Claude — Préparateur et comparateur de données multi-sources

Projet : préparer et comparer des données issues de plusieurs sources, puis les pousser
vers un format/outil de destination. La destination actuellement ciblée est **Apache Superset**
(visualisation / BI), via des **skills et tools Claude Code** dédiés à l'ajout de données.

## Règle de travail — décisions et délégations (à lire en premier)

Plusieurs développeurs travaillent sur ce dépôt. La traçabilité vit dans
[`docs/`](docs/README.md) et **prime sur ce fichier pour le « pourquoi » et le « qui »** :

- [`docs/decisions/`](docs/decisions/) — un ADR par décision structurante, attribué à
  une personne nommée. `CLAUDE.md` ne rejoue pas l'argumentaire, il cite l'ADR.
- [`docs/delegations/REGISTRE.md`](docs/delegations/REGISTRE.md) — **à consulter avant
  de poser une question à un développeur.** Il liste ce que Claude peut décider seul
  (`D-XXXX`) et ce qui a été tranché une fois pour toutes (`DP-XXXX`). Son but explicite
  est qu'une même question ne soit pas reposée d'une session à l'autre.
- [`docs/specs/`](docs/specs/) — spécifications fonctionnelles et techniques.

Deux obligations, outillées par le skill `.claude/skills/decision-log/` :

1. **Toute décision structurante donne lieu à un ADR**, avant ou juste après sa mise en
   œuvre — jamais « plus tard ».
2. **Toute autorisation accordée par un développeur est inscrite au registre dans la
   session où elle est donnée.** Claude n'est jamais `décideur` d'un ADR ; une décision
   prise sans validation humaine porte `validation: à confirmer` et reste en dette.

`.claude/skills/decision-log/trace.sh check` vérifie le respect de ces règles ;
`trace.sh list` affiche les points en attente de ratification.

## État du dépôt

Le dépôt GitHub distant (`Ashitaka80/Pr-parateur-et-comparateur-de-donn-es-multi-sources...`)
était vide au clonage. Ce fichier et l'infrastructure Superset décrite ci-dessous sont les
premiers éléments mis en place.

## Authentification GitHub

Le token d'authentification git (`GITHUB_TOKEN`) est dans `.env` à la racine de ce repo.
Voir aussi la mémoire persistante `github_token_reference` (auto-memory Claude).

## Infrastructure Apache Superset (environnement de dev local)

Superset **ne fait pas partie du dépôt applicatif** : c'est un service tiers installé
séparément sur la machine, utilisé comme cible pour les futurs tools d'upload.

- **Emplacement** : `/home/user/superset-docker` (clone officiel de `apache/superset`,
  utilisé uniquement pour ses fichiers `docker-compose-image-tag.yml` / `docker/`).
- **Lancement** : `docker compose -f docker-compose-image-tag.yml up -d` depuis ce dossier.
- **URL** : http://localhost:8088
- **Identifiants** : générés aléatoirement, stockés dans
  `/home/user/superset-docker/CREDENTIALS.txt` (permissions 600, non versionné) et dans
  `docker/.env-local` (secrets : `SUPERSET_SECRET_KEY`, `POSTGRES_PASSWORD`, `ADMIN_PASSWORD`).
- **Backend metadata DB** : PostgreSQL 17 (conteneur `superset_db`), utilisateur `superset`.
- **`SUPERSET_LOAD_EXAMPLES=no`** : pas de jeux de données d'exemple chargés, instance propre.

### Décisions / historique

1. **Tentative pip (venv) abandonnée.** Une installation via `pip install apache-superset`
   dans un venv (`/home/user/superset/venv`) a été faite en premier et fonctionnait
   (après contournement d'un bug de compatibilité `flask-caching` 2.5.0 en downgradant
   vers `flask-caching==2.1.0` — `SupersetMetastoreCache` ne supporte pas le kwarg
   `ignore_delete_many_errors` introduit par les versions récentes). Cette approche a été
   abandonnée sur demande explicite au profit de Docker, jugé plus proche d'un déploiement
   réaliste et plus simple à maintenir/réinitialiser. Le venv a été arrêté (process gunicorn tué)
   mais pas supprimé.
2. **Docker nécessitait un accès root** (`docker.io`, `docker-compose-plugin`) installés
   manuellement par l'utilisateur via `sudo apt install` (pas d'accès sudo interactif possible
   depuis les commandes lancées par Claude Code — pas de TTY pour le mot de passe).
3. **Le daemon Docker ne récupérait pas les images** (timeout vers `registry-1.docker.io` /
   `apachesuperset.docker.scarf.sh`) car le réseau de la machine impose un proxy HTTP
   (`http://proxy.pipo.land:3128/`, visible dans l'environnement shell via `HTTPS_PROXY`)
   que **systemd/dockerd n'hérite pas automatiquement** de l'environnement utilisateur.
   Corrigé en ajoutant un drop-in systemd :
   `/etc/systemd/system/docker.service.d/http-proxy.conf` (variables `HTTP_PROXY`/`HTTPS_PROXY`/
   `NO_PROXY`), suivi de `systemctl daemon-reload && systemctl restart docker`.
4. Image Superset utilisée : `TAG=latest` (image de prod, pas `latest-dev`) via
   `docker-compose-image-tag.yml`, qui pull des images pré-construites plutôt que de builder
   depuis les sources (plus rapide, pas besoin du frontend dev server).
5. **Deux variables distinctes contrôlent le mot de passe Postgres** dans ce docker-compose :
   `POSTGRES_PASSWORD` (mot de passe réellement défini par le conteneur `db` pour l'utilisateur
   `superset`) et `DATABASE_PASSWORD` (mot de passe utilisé par l'app Superset pour se connecter
   à sa metadata DB). Les deux doivent être identiques — sinon `superset-init` échoue avec
   `password authentication failed`. Les deux sont alignées dans `docker/.env-local`.
6. **Le proxy HTTP doit aussi être injecté dans les conteneurs**, pas seulement dans le
   daemon Docker : `superset-init` installe des dépendances pip au démarrage
   (`pip install -e .[postgres]`) et a besoin d'atteindre `pypi.org`. Ajouté
   `HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY` dans `docker/.env-local` (repris comme variables
   d'environnement des conteneurs via `env_file`).
7. **`superset-worker` / `superset-worker-beat` en échec** (connu, non résolu) :
   - D'abord `ModuleNotFoundError: psycopg2` — le bootstrap Docker skip volontairement
     l'installation des requirements Postgres pour les workers ("Skip postgres requirements
     installation for workers to avoid conflicts"). Contourné en ajoutant
     `docker/requirements-local.txt` (contenant `psycopg2-binary`), un mécanisme d'extension
     officiel du bootstrap Superset installé pour tous les types de conteneurs.
   - Ensuite `ModuleNotFoundError: No module named 'superset.tasks.deletion_retention'` —
     semble être une incohérence dans l'image `apache/superset:latest` elle-même (bug amont,
     pas lié à notre config). Les deux conteneurs ont été **arrêtés** (`docker stop`) pour
     éviter une boucle de redémarrage infinie ; Celery n'est pas nécessaire pour l'upload CSV
     synchrone via l'API REST, donc non bloquant pour l'objectif du projet. À creuser plus tard
     si des fonctionnalités async (rapports planifiés, cache lourd, alertes) sont nécessaires.

## Skill / tool d'upload vers Superset (fait)

- **Skill Claude Code** : `.claude/skills/superset-upload/SKILL.md`.
- **100% Docker, aucun Python côté hôte.** Le tool tourne dans une image dédiée
  `superset-uploader` (`Dockerfile` du skill : `python:3.12-slim` + `requests`), lancée en
  `docker run --rm` par appel via `.claude/skills/superset-upload/upload.sh`. Ce wrapper ne
  monte que le dossier parent du fichier `--file` (lecture seule, le temps de l'appel) plus
  `.env` — rien d'autre du disque hôte n'est exposé, et le montage ne survit pas à l'appel.
  **Les scripts sont `COPY`'d dans l'image au build** (pas montés en live) : après toute
  modification de `scripts/`, il faut reconstruire
  (`docker build -t superset-uploader:latest .claude/skills/superset-upload/`).
- **Base de données cible** : une base Postgres `uploads` a été créée dans le conteneur
  `superset_db` (distincte de la metadata DB `superset`), enregistrée dans Superset comme
  connexion `uploads` avec `allow_file_upload=true` et
  `schemas_allowed_for_file_upload: ["public"]`.
- **Identifiants et config** dans `.env` à la racine (non versionné, voir `.gitignore`) :
  `SUPERSET_URL` (hostname **interne** au réseau docker, `http://superset_app:8088` —
  nécessaire car le conteneur `superset-uploader` tourne sur ce même réseau
  `superset-docker_default`), `SUPERSET_PUBLIC_URL` (`http://localhost:8088`, uniquement
  pour le lien affiché en fin d'upload, cliquable depuis le navigateur de l'hôte),
  `SUPERSET_USERNAME`, `SUPERSET_PASSWORD`, `SUPERSET_UPLOAD_DATABASE`,
  `SUPERSET_UPLOAD_SQLALCHEMY_URI`.
- **Testé de bout en bout** : upload d'un CSV de démo (`demo_ventes`) via `upload.sh` → table
  Postgres créée → dataset Superset enregistré et interrogeable.
- Point d'API clé découvert par lecture du code source Superset (pas de doc publique claire
  dessus) : `POST /api/v1/database/{id}/upload/`, payload `multipart/form-data` avec
  `type` (csv/excel/columnar), `table_name`, `file`, `already_exists` (fail/replace/append),
  `schema`, et des options spécifiques CSV/Excel (`delimiter`, `sheet_name`, `header_row`, ...).
  Nécessite une session cookie + `X-CSRFToken` en plus du bearer JWT (sinon
  `400 CSRF session token is missing`), et le `schema` doit correspondre à
  `schemas_allowed_for_file_upload` sur la connexion sinon
  `Database schema is not allowed for csv uploads`.
- **Historique de conception (venv → docker exec → image dédiée)** : un venv hôte a d'abord
  été utilisé (une dépendance, `requests`), fonctionnel mais jugé incohérent avec un projet
  "tout Docker" (retour utilisateur explicite). Piste suivante, `docker exec` dans le
  conteneur `superset_app` déjà vivant (qui a `requests`) : rejetée, car elle aurait nécessité
  de monter des chemins hôte (script, `.env`, fichier à uploader) dans un conteneur de service
  **persistant** — les garde-fous de sécurité de l'environnement ont bloqué l'élargissement de
  ce montage au-delà d'un seul dossier de scripts. Solution retenue : une image **dédiée et
  jetable** (`superset-uploader`), avec un montage **minimal et éphémère** (un seul dossier,
  le temps d'un `docker run --rm`) — élimine le Python hôte sans le compromis de sécurité du
  montage large sur un conteneur permanent. Note technique annexe : `docker build`
  n'hérite pas du proxy configuré au niveau du daemon (voir point 6) — passer
  `--build-arg HTTP_PROXY=...`/`HTTPS_PROXY=...` pour les étapes `RUN pip install`.

## Prochaines étapes possibles

- Étendre le tool à d'autres formats déjà supportés par l'API (`columnar`/Parquet).
- Ajouter la logique de préparation/comparaison multi-sources (cœur du projet) en amont de
  l'upload, en pandas, avant d'appeler `upload_to_superset.py`.
- Réparer `superset-worker` / `superset-worker-beat` si des fonctionnalités async deviennent
  nécessaires (voir point 7 ci-dessus).

## Configuration locale et secrets (skill `project-init`)

Deux fichiers à la racine, avec un partage des rôles strict :

- **`.env`** — valeurs réelles, permissions `600`, **jamais versionné** (`.gitignore`).
- **`.env.example`** — **versionné**, mêmes clés, aucun secret : uniquement le rôle de
  chaque variable, sa valeur par défaut si elle en a une, et où trouver la vraie valeur.
  C'est le contrat de configuration du projet : on peut cloner le dépôt et savoir quoi
  renseigner sans qu'aucun secret n'ait transité par git.

Le skill `.claude/skills/project-init/` outille ce cycle en bash pur (rien sur l'hôte) :
`init.sh init` (amorce `.env` depuis le modèle, sans jamais écraser), `check` (audit,
sortie != 0 si problème), `doctor` (audit + corrige permissions / `.gitignore` / clés
manquantes), `sync` (propage dans `.env` les clés nouvellement ajoutées au modèle).

Points vérifiés par `check` qui valent d'être connus :

- `.env` non suivi par git **et absent de l'historique** (`git log --all -- .env`) : un
  fichier retiré de l'index reste dans les objets git, les secrets sont alors à révoquer.
- Aucune valeur d'une clé sensible (`*PASSWORD*`, `*TOKEN*`, `*SECRET*`, `*KEY*`)
  identique entre `.env` et `.env.example` — détecte un vrai secret recopié dans le modèle.
- Le mot-clé **`REQUIS`** dans le bloc de commentaires précédant une clé de `.env.example`
  la rend bloquante si elle est vide côté `.env`. C'est le mécanisme utilisé pour
  `SUPERSET_PASSWORD`, seule variable sans défaut dans `upload_to_superset.py`.
- **Valeurs sans guillemets.** Le parseur `.env` de `upload_to_superset.py` fait un simple
  `partition("=")` puis `os.environ.setdefault(...)` sans retirer les guillemets :
  `SUPERSET_PASSWORD="x"` s'authentifierait avec la valeur `"x"`. Les variables `GITHUB_*`
  préexistantes sont quotées (elles ne passent pas par ce parseur) ; les `SUPERSET_*` ne
  doivent pas l'être.
