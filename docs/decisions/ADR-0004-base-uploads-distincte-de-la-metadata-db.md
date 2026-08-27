---
id: ADR-0004
titre: Base Postgres `uploads` distincte de la metadata DB de Superset
statut: acceptée
date: 2026-08-27
décideur: user808 <user808@mail.com>
proposé par: Claude
validation: confirmée
ratification: 2026-08-27 par user808 <user808@mail.com>
délégation: —
remplace: —
remplacé par: —
---

## Contexte

Les données uploadées doivent atterrir dans une base que Superset sait interroger.
Le conteneur `superset_db` (PostgreSQL 17) héberge déjà la metadata DB `superset`
— celle où Superset stocke ses dashboards, utilisateurs et connexions.

## Options envisagées

- **Écrire dans la metadata DB `superset`** — *Pour :* rien à créer. *Contre :* mélange
  les données métier avec l'état interne de l'outil ; une table métier mal nommée peut
  entrer en collision avec le schéma interne ; toute restauration de Superset emporte
  les données.
- **Base dédiée `uploads` dans le même serveur Postgres** — *Pour :* isolation logique
  franche, sauvegarde et purge indépendantes, aucun conteneur supplémentaire.
  *Contre :* même serveur, donc pas d'isolation de charge ni de panne.
- **Serveur Postgres séparé** — *Pour :* isolation complète. *Contre :* surcoût
  d'infrastructure injustifié pour un environnement de développement individuel.

## Décision

Une base **`uploads`** est créée dans le conteneur `superset_db`, enregistrée dans
Superset comme connexion `uploads` avec `allow_file_upload=true` et
`schemas_allowed_for_file_upload: ["public"]`.

## Conséquences

- L'état de Superset peut être réinitialisé sans perdre les données uploadées.
- Le `schema` passé à l'API doit correspondre à `schemas_allowed_for_file_upload`,
  sinon Superset répond `Database schema is not allowed for csv uploads`.
- Pas d'isolation de charge : une requête lourde sur `uploads` peut ralentir l'UI.
