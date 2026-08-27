---
id: ADR-0011
titre: Bootstrap et smoke-test intégrés à superset.sh
statut: acceptée
date: 2026-08-27
décideur: user808 <user808@mail.com>
proposé par: Claude
validation: confirmée
ratification: demande explicite du 2026-08-27
délégation: —
remplace: —
remplacé par: —
---

## Contexte

Remonter l'environnement sur une machine neuve demande d'enchaîner à la main plusieurs
commandes réparties sur deux outils (`project-init`, `superset.sh`) puis de recopier
deux valeurs générées par `superset.sh secrets` (`ADMIN_PASSWORD`, `POSTGRES_PASSWORD`)
dans le `.env` racine avant de pouvoir démarrer — un pas manuel, source d'erreur, déjà
documenté comme tel dans `docs/PASSATION.md`. Aucune commande ne vérifie ensuite que la
chaîne complète (upload → dataset interrogeable) fonctionne réellement : la seule preuve
disponible était un test fait à la main en session, jamais rejouable telle quelle.

## Options envisagées

- **Nouveau skill dédié** (`bootstrap` ou équivalent) orchestrant les trois briques
  existantes. *Pour :* isolé, ne touche à rien d'existant. *Contre :* ajoute une couche
  supplémentaire à maintenir en plus des trois outils déjà en place, avec un risque de
  désynchronisation si l'un d'eux change sans que le wrapper suive.
- **Étendre le skill `project-init`** avec ces étapes. *Pour :* un seul point d'entrée
  pour la configuration. *Contre :* `project-init` a une portée volontairement étroite
  (audit du contrat `.env`/`.env.example`, sans rien connaître de Docker ni de
  Superset) — un projet tiers pourrait le reprendre tel quel. Y coupler le démarrage
  d'une stack Docker et un test d'upload spécifique à Superset romprait cette
  séparation et le coincerait à une seule destination, alors que le README annonce
  vouloir en supporter d'autres.
- **Ajouter les commandes à `infra/superset/superset.sh`**, qui possède déjà `secrets`
  et `up`. *Pour :* reste dans l'outil qui connaît déjà Superset et sait piloter sa
  stack (réseau docker, base `uploads`, healthcheck) ; `bootstrap` peut réutiliser
  `secrets`/`up`/`ensure_uploads_db` tels quels ; `smoke-test` réutilise le skill
  `superset-upload` existant plutôt que de réimplémenter l'appel API. *Contre :*
  alourdit un script déjà multi-commandes.

Retenue : la troisième option, qui garde une seule responsabilité par outil
(`project-init` = config, `superset.sh` = cycle de vie de la stack Superset,
`superset-upload` = un upload) sans en créer un quatrième.

## Décision

Deux commandes ajoutées à `infra/superset/superset.sh` :

- **`bootstrap`** — enchaîne `project-init init` (si `.env` racine absent), `secrets`
  (si non déjà fait), `up`, attend que `superset_app` soit `healthy`, **reporte
  automatiquement** `SUPERSET_PASSWORD` et `SUPERSET_UPLOAD_SQLALCHEMY_URI` dans le
  `.env` racine (uniquement les valeurs encore vides ou à `CHANGEME` — ne clobber pas
  une valeur déjà renseignée à la main), construit l'image `superset-uploader`, puis
  lance `project-init check`.
- **`smoke-test`** — génère un petit CSV temporaire, l'uploade via
  `.claude/skills/superset-upload/upload.sh` sous un nom de table horodaté, vérifie le
  nombre de lignes en base Postgres, puis **nettoie** systématiquement (dataset
  Superset + table) que le test réussisse ou échoue, via un nouveau script
  `delete_dataset.py` ajouté au skill `superset-upload` (même client API que
  l'upload).

Les deux restent des commandes séparées, dans le même esprit que `secrets`/`up`/`down`
déjà distincts : `bootstrap` ne lance pas `smoke-test` automatiquement, pour ne pas
mélanger « configurer » et « vérifier » dans une même invocation.

## Conséquences

- Remonter l'environnement sur une machine neuve tient en deux commandes :
  `./infra/superset/superset.sh bootstrap` puis `./infra/superset/superset.sh smoke-test`.
- Le report manuel des deux secrets dans `.env`, source d'erreur documentée dans
  `docs/PASSATION.md`, disparaît pour le cas standard (il reste possible de les
  renseigner à la main, `bootstrap` ne les écrase pas si déjà présents).
- Le skill `superset-upload` gagne une capacité de suppression de dataset
  (`delete_dataset.py`), réutilisable au-delà du smoke-test.
- `superset.sh` reste couplé à Superset uniquement — cohérent avec son rôle actuel,
  pas un changement de périmètre.
