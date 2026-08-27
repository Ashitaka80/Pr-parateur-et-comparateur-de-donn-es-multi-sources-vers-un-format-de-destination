# Stack Apache Superset (vendorisée)

Superset était jusqu'ici déployé depuis un clone d'`apache/superset` situé **hors du
dépôt** (`/home/user/superset-docker`). Ce clone a disparu de la machine, emportant
avec lui la configuration : le projet n'était pas reproductible. Les fichiers
nécessaires vivent désormais ici. Voir **ADR-0010**.

## Provenance

Fichiers repris tels quels depuis [apache/superset](https://github.com/apache/superset)
(licence Apache-2.0, en-têtes de licence conservés), commit :

    5879994e683e7ec01ed4809eaf35552f7f69b0b4  (2026-08-27)

Également enregistré dans le fichier `UPSTREAM`. Pour comparer avec une version plus
récente d'upstream, cloner `apache/superset` dans un dossier temporaire et differ
`docker-compose-image-tag.yml` et `docker/`.

**Ajout local, absent d'upstream :** `docker/requirements-local.txt`
(`psycopg2-binary`), sans lequel les workers Celery échouent — voir ADR-0006.

## Démarrage

Sur une machine neuve, une seule commande (ADR-0011) :

```bash
./infra/superset/superset.sh bootstrap
```

Elle enchaîne : amorce le `.env` racine si absent, génère les secrets si absents,
démarre la stack, **attend qu'elle soit healthy**, reporte automatiquement
`SUPERSET_PASSWORD` et `SUPERSET_UPLOAD_SQLALCHEMY_URI` dans le `.env` racine (sans
écraser une valeur déjà renseignée), construit l'image `superset-uploader`, puis
vérifie la configuration. Rejouable sans effet si une étape est déjà faite.

Vérifier ensuite que la chaîne fonctionne réellement, avec un fichier de test uploadé
puis nettoyé :

```bash
./infra/superset/superset.sh smoke-test
```

Étape par étape, ou pour piloter la stack une fois debout :

```bash
./infra/superset/superset.sh secrets   # une seule fois : génère docker/.env-local
./infra/superset/superset.sh up        # démarre (première init : plusieurs minutes)
./infra/superset/superset.sh logs superset-init
```

`secrets` affiche les deux valeurs à reporter dans le `.env` à la racine du dépôt
(`SUPERSET_PASSWORD` et `SUPERSET_UPLOAD_SQLALCHEMY_URI`) si `bootstrap` n'a pas été
utilisé. Vérifier ensuite avec `.claude/skills/project-init/init.sh check`.

Superset écoute alors sur http://localhost:8088 (utilisateur `admin`).

## Points à connaître

- **Le nom de projet compose est figé à `superset`** par `superset.sh`, donc le réseau
  docker s'appelle toujours `superset_default` — valeur attendue par
  `.claude/skills/superset-upload/upload.sh`. Sans ce verrouillage, compose déduirait le
  nom du dossier et le tool d'upload ne trouverait plus le réseau.
- **`docker/.env` est versionné** (valeurs par défaut d'upstream, sans secret) ;
  **`docker/.env-local` ne l'est pas** (mots de passe générés). Le `.gitignore` racine
  contient une exception explicite pour le premier.
- **`POSTGRES_PASSWORD` et `DATABASE_PASSWORD` doivent rester identiques** : la première
  est le mot de passe que le conteneur `db` attribue, la seconde celle que l'application
  utilise. Un écart fait échouer `superset-init` sur `password authentication failed`.
  `superset.sh secrets` les génère alignées.
- **Le proxy HTTP doit être injecté à trois endroits distincts** : le daemon docker
  (drop-in systemd), les conteneurs (`docker/.env-local`, repris par `superset.sh secrets`
  depuis l'environnement), et les builds d'image (`--build-arg`). Voir `CLAUDE.md`.
- **`TAG=latest`** (image de prod). Ce tag est mouvant : un `pull` peut changer la
  version sous les pieds de l'équipe. Surchargeable par `TAG=... ./superset.sh up`.
- **Les workers Celery** (`superset-worker`, `superset-worker-beat`) sont connus pour
  échouer sur cette image ; ils sont sans effet sur l'upload synchrone (ADR-0006).
- **`SUPERSET_LOAD_EXAMPLES=no`** est posé par `superset.sh secrets` : le `docker/.env`
  d'upstream active les jeux d'exemple, qui chargent des centaines de milliers de lignes
  sans rapport avec le projet et allongent fortement la première initialisation.

## Base de données des uploads

La base `uploads` est distincte de la metadata DB `superset` (ADR-0004). Le tool
d'upload crée la **connexion** côté Superset, mais **pas la base Postgres elle-même** :
sans elle il échoue sur `Unable to connect to database "uploads"`. `superset.sh up`
la crée donc si elle manque (pas idempotent rejoué à chaque démarrage), et
`superset.sh db-uploads` permet de le faire seul. Le nom est déduit de
`SUPERSET_UPLOAD_SQLALCHEMY_URI` dans le `.env` racine.
