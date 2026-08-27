# Préparateur et comparateur de données multi-sources

Outillage pour préparer, comparer et pousser des données issues de plusieurs sources
vers un format/outil de destination. La destination actuellement implémentée est
**Apache Superset** (visualisation / BI).

## Objectifs

- Ingérer des données provenant de sources hétérogènes (fichiers plats, formats à
  largeur fixe, CSV, Excel, etc.).
- Les préparer/normaliser (structuration en colonnes, typage, nettoyage) avant
  diffusion.
- Les comparer entre sources (à venir — voir [Périmètre](#périmètre)).
- Les pousser vers un outil de destination pour exploitation (dashboards,
  exploration), sans étape manuelle dans l'UI de l'outil cible.

## Cahier des charges

| Besoin | Statut |
|---|---|
| Connecter un outil de destination (Apache Superset) en local | ✅ Fait |
| Uploader un fichier (CSV/Excel/Parquet) vers Superset via API, sans passer par l'UI | ✅ Fait |
| Créer automatiquement la connexion base de données cible si absente | ✅ Fait |
| Gérer les cas table déjà existante (échouer / remplacer / ajouter) | ✅ Fait |
| Fonctionner sans dépendance Python installée sur la machine hôte | ✅ Fait (tout tourne en conteneurs Docker) |
| Préparer une source à un format non standard (ex : largeur fixe) avant upload | ✅ Fait à la main pour un cas réel (voir `exemples/`), pas encore généralisé en outil |
| Comparer plusieurs sources entre elles (diff, réconciliation, dédoublonnage) | ⏳ Pas commencé |
| Automatiser la préparation multi-sources (détection de format, mapping de colonnes) | ⏳ Pas commencé |
| Support d'autres destinations que Superset | ⏳ Pas commencé (architecture pensée pour être extensible) |

## Périmètre

**Dans le périmètre actuel :**
- Un outil (skill Claude Code + script) qui pousse un fichier de données local
  vers Superset comme dataset interrogeable.
- L'infrastructure locale nécessaire pour exécuter et tester cet outil (Superset
  en Docker).

**Hors périmètre pour l'instant :**
- La logique de comparaison entre sources multiples (le nom du projet l'annonce,
  mais ce n'est pas encore implémenté — seul le pipeline de préparation ponctuelle
  → upload a été validé, à la main, sur un cas réel).
- Les destinations autres que Superset.
- Un pipeline automatisé/planifié (aujourd'hui, tout est déclenché manuellement).
- La gestion multi-utilisateurs / multi-environnements de Superset (l'instance
  actuelle est une instance de dev locale à usage individuel).

## Architecture

Deux briques Docker indépendantes, orchestrées séparément, **toutes deux dans ce
dépôt** :

```
┌──────────────────────────────┐        ┌──────────────────────────────┐
│  Stack Apache Superset       │        │  Image superset-uploader      │
│  (infra/superset/)           │        │  (.claude/skills/…)           │
│                              │        │                               │
│  superset_app  (UI + API)    │◄───────┤  docker run --rm, une fois    │
│  superset_db   (Postgres)    │  API   │  par upload                   │
│  superset_cache (Redis)      │  REST  │  → login, CSRF, POST multipart│
└──────────────────────────────┘        └──────────────────────────────┘
        ▲          réseau docker « superset_default »
        │ navigateur (http://localhost:8088)
      Humain
```

- **Superset** : UI + API REST, backend PostgreSQL dédié (base `uploads`,
  distincte de la metadata DB de Superset). Les fichiers de déploiement sont
  vendorisés depuis `apache/superset` dans [`infra/superset/`](infra/superset/) —
  le dépôt est autonome, voir ADR-0010.
- **`superset-uploader`** : image Python minimale (`python:3.12-slim` +
  `requests`), jetable — un conteneur par appel. Ne monte que le dossier du
  fichier à uploader (lecture seule, le temps de l'appel) et le fichier
  `.env` de config/identifiants. Aucun Python n'est requis sur la machine hôte.

Détails techniques et API Superset utilisée : voir `.claude/skills/superset-upload/SKILL.md`.

## Contraintes rencontrées

L'environnement de développement a imposé plusieurs contraintes non fonctionnelles,
documentées en détail (avec les correctifs appliqués) dans `CLAUDE.md` :

- Réseau derrière un **proxy HTTP obligatoire**, à configurer séparément pour le
  daemon Docker, les conteneurs, et les builds d'image (`--build-arg`).
- Pas d'accès `sudo` interactif depuis les outils automatisés → les installations
  système (Docker, `python3-venv`, etc.) ont dû être faites manuellement par
  l'utilisateur.
- Bugs/incohérences rencontrés dans l'image `apache/superset:latest` (workers
  Celery non fonctionnels — non bloquant pour le besoin actuel).
- Contrainte de sécurité de l'environnement d'exécution : impossible de monter
  des répertoires hôte larges (ex. `/home`) dans un conteneur de service
  persistant → a orienté la conception vers une image jetable à montage minimal
  plutôt qu'un `docker exec` dans le conteneur Superset déjà démarré.

## Prérequis

- Docker + Docker Compose (v2, plugin `docker compose`). **Rien d'autre** : aucun
  Python, aucun outil à installer sur la machine hôte.
- Un accès réseau sortant (direct ou via proxy) pour télécharger les images et
  paquets pip au premier lancement.

## Démarrage

Sur une machine neuve, deux commandes (ADR-0011) suffisent :

```bash
# 1. Configure tout : .env, secrets, stack Superset, image de l'outil d'upload
./infra/superset/superset.sh bootstrap

# 2. Vérifie que la chaîne fonctionne réellement (upload d'un fichier de test,
#    vérification en base, nettoyage)
./infra/superset/superset.sh smoke-test
```

`bootstrap` est idempotent : rejouable sans effet si une étape est déjà faite, et ne
réécrit jamais une valeur déjà renseignée à la main dans `.env`.

Puis, pour un vrai fichier :

```bash
.claude/skills/superset-upload/upload.sh \
  --file mes_donnees.csv \
  --table-name ma_table \
  --if-exists replace
```

Superset est ensuite accessible sur http://localhost:8088 (utilisateur `admin`,
mot de passe généré par `superset.sh secrets` et stocké dans
`infra/superset/docker/.env-local`, non versionné).

Détail étape par étape (ce que fait `bootstrap`), utile en cas de problème sur une
étape précise : `.claude/skills/project-init/init.sh init` (config), `./infra/superset/superset.sh secrets`
puis `up` (stack), `docker build -t superset-uploader:latest .claude/skills/superset-upload/`
(image de l'outil d'upload).

## Configuration

Toute la config sensible/environnement vit dans `.env` à la racine, **non versionné**.
Sa contrepartie versionnée est **`.env.example`** : mêmes clés, aucun secret, avec
le rôle de chaque variable et où trouver sa valeur. Le skill `project-init` gère
les deux (`init` pour amorcer, `check` pour auditer, `sync` après ajout d'une
variable) — voir `.claude/skills/project-init/SKILL.md`.

| Variable | Rôle |
|---|---|
| `SUPERSET_URL` | URL de Superset **vue depuis le conteneur d'upload** (hostname interne docker, ex. `http://superset_app:8088`) |
| `SUPERSET_PUBLIC_URL` | URL de Superset **vue depuis le navigateur de l'hôte** (`http://localhost:8088`), utilisée seulement pour le lien affiché en fin d'upload |
| `SUPERSET_USERNAME` / `SUPERSET_PASSWORD` | Identifiants Superset |
| `SUPERSET_UPLOAD_DATABASE` | Nom de la connexion Superset cible des uploads (défaut `uploads`) |
| `SUPERSET_UPLOAD_SQLALCHEMY_URI` | URI utilisée pour créer cette connexion si elle n'existe pas encore |
| `GITHUB_TOKEN` | Authentification git vers ce dépôt |

## Exemple réel testé

`~/Téléchargements/deces-2026-m07.txt` — fichier INSEE des personnes décédées
(format largeur fixe, 198 caractères/ligne, 56 493 lignes) : parsé en CSV
structuré (nom, prénoms, sexe, dates, lieux) puis uploadé avec succès comme
dataset Superset via ce pipeline. Preuve que l'outil tient sur un fichier
réel, volumineux, et dans un format non trivial.

## Limitations connues

- Pas de logique de comparaison/réconciliation multi-sources : chaque source
  est préparée et uploadée indépendamment, à la main.
- La préparation d'un format non standard (ex. largeur fixe) est encore
  ad hoc (script écrit au cas par cas), pas un outil générique paramétrable.
- Instance Superset de dev, mono-utilisateur, sans HTTPS ni durcissement
  pour un déploiement en production.
- Workers asynchrones Superset (Celery) désactivés — pas de rapports
  planifiés ni d'alertes.

## Prochaines étapes

- Généraliser la préparation de sources à formats variés (détection de format,
  mapping de colonnes configurable) plutôt que des scripts ad hoc.
- Implémenter la comparaison entre sources (le cœur du nom du projet).
- Étendre le tool d'upload aux formats déjà supportés par l'API Superset non
  encore testés (`columnar`/Parquet).
- Réparer les workers Celery si des fonctionnalités asynchrones deviennent
  nécessaires.

## Pour aller plus loin

Historique détaillé des décisions techniques, bugs rencontrés et correctifs :
voir [`CLAUDE.md`](./CLAUDE.md). Documentation de l'outil d'upload Superset
(usage, dépannage) : voir [`.claude/skills/superset-upload/SKILL.md`](./.claude/skills/superset-upload/SKILL.md).

## Traçabilité des décisions

Plusieurs développeurs travaillent sur ce dépôt. Les choix d'architecture, les
spécifications et les autorisations accordées à Claude Code sont tracés dans
[`docs/`](docs/README.md), avec attribution nominative :

| Dossier | Contenu |
|---|---|
| [`docs/decisions/`](docs/decisions/) | ADR — une décision par fichier, immuable, avec son décideur |
| [`docs/delegations/`](docs/delegations/REGISTRE.md) | Ce que Claude peut décider seul, et ce qui est tranché définitivement |
| [`docs/specs/`](docs/specs/) | Spécifications fonctionnelles et techniques |

Outillage : `.claude/skills/decision-log/trace.sh` (`adr`, `spec`, `index`, `check`, `list`).
