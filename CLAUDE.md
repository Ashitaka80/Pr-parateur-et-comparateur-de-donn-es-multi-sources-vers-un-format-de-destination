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

L'état d'avancement réel, les points bloquants et la marche à suivre pour reprendre le
travail vivent dans **[`docs/PASSATION.md`](docs/PASSATION.md)** — c'est le document à
lire en premier, et à mettre à jour en fin de session (D-0003).

## Authentification GitHub

Le token d'authentification git (`GITHUB_TOKEN`) est dans `.env` à la racine de ce repo
(voir `.env.example` pour la liste complète des variables).

**Utiliser un token classique (`ghp_…`, scope `repo`).** Les tokens *fine-grained*
(`github_pat_…`) essayés sur ce dépôt échouent tous au push avec
`403 Resource not accessible by personal access token`, alors même que l'API confirme
le rôle *push* du compte sur le dépôt. Devant un 403 au push, vérifier d'abord le type
de token avant de chercher ailleurs.

**Pousser une branche : `scripts/git-push.sh [branche]`** (ADR-0012). Authentifie via
un credential helper git scopé à cette seule invocation (`scripts/git-credential-helper.sh`,
qui lit `.env`) — le token ne touche jamais `.git/config` ni les arguments d'un process.
Refuse tout push direct sur `main`.

**Point d'exploitation qui ne se déduit pas du code** : le classificateur de sécurité du
mode automatique **bloque l'action `git push` elle-même quand Claude l'exécute, quelle
que soit la méthode d'authentification** — y compris `scripts/git-push.sh`, pourtant
sans secret en clair dans la commande. En pratique, malgré la délégation D-0004, **le
développeur doit lancer ce script lui-même** (`! scripts/git-push.sh` en CLI Claude
Code) à chaque push, sauf s'il ajoute une règle de permission ciblée
(`Bash(.../scripts/git-push.sh:*)`) — que Claude ne peut pas s'accorder lui-même (tenté,
également refusé par le classificateur).

## Infrastructure Apache Superset (environnement de dev local)

Superset reste un **service tiers**, mais ses fichiers de déploiement sont désormais
**vendorisés dans le dépôt** — l'ancien clone externe `/home/user/superset-docker` a
disparu de la machine en emportant toute la configuration, rendant le projet non
reproductible (ADR-0010).

- **Emplacement** : `infra/superset/` — `docker-compose-image-tag.yml` et `docker/`
  repris tels quels d'`apache/superset` (commit noté dans `infra/superset/UPSTREAM`,
  en-têtes de licence Apache-2.0 conservés).
- **Lancement sur une machine neuve** : `./infra/superset/superset.sh bootstrap`
  (ADR-0011) — enchaîne `.env`, `secrets`, `up`, attente du healthcheck, report des
  secrets dans le `.env` racine, build de l'image `superset-uploader`, puis
  `project-init check`. Idempotent. Suivi de `./infra/superset/superset.sh smoke-test`
  pour vérifier la chaîne complète avec un fichier de test (uploadé puis nettoyé).
  Étape par étape : `./infra/superset/superset.sh secrets` (une fois par machine) puis
  `./infra/superset/superset.sh up`. Le wrapper **fige le nom de projet compose à
  `superset`**, donc le réseau docker est toujours `superset_default` — valeur attendue
  par `upload.sh`, qui s'y attache.
- **URL** : http://localhost:8088
- **Identifiants** : générés par `superset.sh secrets` dans
  `infra/superset/docker/.env-local` (permissions 600, non versionné ;
  `SUPERSET_SECRET_KEY`, `POSTGRES_PASSWORD`, `DATABASE_PASSWORD`, `ADMIN_PASSWORD`,
  variables de proxy). La commande affiche les deux valeurs à reporter dans le `.env`
  racine. **`docker/.env` (valeurs par défaut d'upstream, sans secret) est lui
  versionné**, via une exception explicite du `.gitignore`.
- **Backend metadata DB** : PostgreSQL 17 (conteneur `superset_db`), utilisateur `superset`.
- **`SUPERSET_LOAD_EXAMPLES=no`** : pas de jeux de données d'exemple chargés, instance propre.

### Pièges d'exploitation

Les **décisions** (pourquoi Docker, pourquoi cette image, pourquoi cette base, pourquoi
les workers sont désactivés) sont dans [`docs/decisions/`](docs/decisions/) et ne sont
pas rejouées ici. Cette section ne garde que ce qui fait perdre du temps en pratique.

1. **Pas de `sudo` interactif depuis Claude Code** (pas de TTY pour le mot de passe) :
   les installations système — Docker et son plugin compose ici — doivent être faites
   par un humain.
2. **Le proxy HTTP se configure à trois endroits distincts**, et en oublier un donne des
   symptômes très différents :
   - **Daemon docker** — sinon les images ne se téléchargent pas (timeout vers
     `registry-1.docker.io`). systemd n'hérite pas du proxy de l'environnement
     utilisateur : drop-in `/etc/systemd/system/docker.service.d/http-proxy.conf`, puis
     `systemctl daemon-reload && systemctl restart docker`. Déjà en place sur cette machine.
   - **Conteneurs** — sinon `superset-init` échoue en installant ses dépendances pip.
     Repris automatiquement de l'environnement par `superset.sh secrets`.
   - **Builds d'image** — `docker build` n'hérite pas du proxy du daemon :
     `--build-arg HTTP_PROXY=… --build-arg HTTPS_PROXY=…`.
3. **`POSTGRES_PASSWORD` et `DATABASE_PASSWORD` doivent être identiques.** La première est
   le mot de passe que le conteneur `db` attribue à l'utilisateur `superset`, la seconde
   celui que l'application utilise pour joindre sa metadata DB. Un écart fait échouer
   `superset-init` sur `password authentication failed`. `superset.sh secrets` les aligne.
4. **La base Postgres `uploads` n'est créée par personne automatiquement.** Le tool
   d'upload enregistre la *connexion* côté Superset mais pas la base : sans elle, l'upload
   échoue sur `Unable to connect to database "uploads"`. `superset.sh up` la crée si elle
   manque ; `superset.sh db-uploads` fait ce pas seul.
5. **Les jeux de données d'exemple sont activés par défaut** dans le `docker/.env`
   d'upstream. `superset.sh secrets` pose `SUPERSET_LOAD_EXAMPLES=no` : sans cela, la
   première initialisation charge des centaines de milliers de lignes sans rapport avec
   le projet et dure beaucoup plus longtemps.
6. **Les workers Celery bouclent en redémarrage** sur cette image
   (`ModuleNotFoundError: superset.tasks.deletion_retention`, bug amont). `superset.sh up`
   ne les démarre donc pas du tout — plutôt que de les arrêter à la main après coup, ce
   qui ne survivait pas au `up` suivant. `WITH_WORKERS=1 ./infra/superset/superset.sh up`
   pour les lancer quand même. Sans effet sur l'upload synchrone (ADR-0006). Le correctif
   `docker/requirements-local.txt` (`psycopg2-binary`) reste nécessaire et en place : sans
   lui l'échec survient plus tôt, sur `ModuleNotFoundError: psycopg2`.
7. **Ne jamais éditer un script shell pendant qu'il s'exécute** : bash lit le fichier au
   fur et à mesure, et l'édition provoque une erreur de syntaxe trompeuse
   (« fin de fichier prématurée ») sur du code pourtant valide.

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
- **Base de données cible** : base Postgres `uploads` dans le conteneur `superset_db`,
  distincte de la metadata DB `superset` (ADR-0004). Créée par `superset.sh up` si elle
  manque ; le tool y enregistre la connexion Superset avec `allow_file_upload=true` et
  `schemas_allowed_for_file_upload: ["public"]`.
- **Identifiants et config** dans `.env` à la racine (non versionné, voir `.gitignore`) :
  `SUPERSET_URL` (hostname **interne** au réseau docker, `http://superset_app:8088` —
  nécessaire car le conteneur `superset-uploader` tourne sur ce même réseau
  `superset_default`), `SUPERSET_PUBLIC_URL` (`http://localhost:8088`, uniquement
  pour le lien affiché en fin d'upload, cliquable depuis le navigateur de l'hôte),
  `SUPERSET_USERNAME`, `SUPERSET_PASSWORD`, `SUPERSET_UPLOAD_DATABASE`,
  `SUPERSET_UPLOAD_SQLALCHEMY_URI`.
- **Testé de bout en bout le 2026-08-27**, sur la stack vendorisée : CSV de démo de
  200 lignes → table `uploads.ventes_demo` (200 lignes vérifiées en base) → dataset
  Superset enregistré et interrogeable.
- Point d'API clé découvert par lecture du code source Superset (pas de doc publique claire
  dessus) : `POST /api/v1/database/{id}/upload/`, payload `multipart/form-data` avec
  `type` (csv/excel/columnar), `table_name`, `file`, `already_exists` (fail/replace/append),
  `schema`, et des options spécifiques CSV/Excel (`delimiter`, `sheet_name`, `header_row`, ...).
  Nécessite une session cookie + `X-CSRFToken` en plus du bearer JWT (sinon
  `400 CSRF session token is missing`), et le `schema` doit correspondre à
  `schemas_allowed_for_file_upload` sur la connexion sinon
  `Database schema is not allowed for csv uploads`.
- **Pourquoi une image dédiée** plutôt qu'un venv hôte ou un `docker exec` dans
  `superset_app` : voir **ADR-0005**, qui garde la trace des deux options écartées.

## Skills du dépôt

| Skill | Rôle |
|---|---|
| [`superset-upload`](.claude/skills/superset-upload/SKILL.md) | Pousser un fichier CSV/Excel/Parquet dans Superset comme dataset |
| [`project-init`](.claude/skills/project-init/SKILL.md) | Créer et auditer la configuration locale (`.env` / `.env.example`) |
| [`decision-log`](.claude/skills/decision-log/SKILL.md) | Tracer décisions, délégations et spécifications sous `docs/` |

## Prochaines étapes

Voir [`docs/PASSATION.md`](docs/PASSATION.md) — état réel, points ouverts et prochaine
action recommandée y sont tenus à jour en fin de session, plutôt que dupliqués ici.

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
