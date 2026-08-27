---
id: ADR-0006
titre: Workers Celery arrêtés plutôt que réparés
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

Les conteneurs `superset-worker` et `superset-worker-beat` échouaient en boucle de
redémarrage, pour deux causes successives :

1. `ModuleNotFoundError: psycopg2` — le bootstrap Docker de Superset saute
   volontairement l'installation des requirements Postgres pour les workers
   (« Skip postgres requirements installation for workers to avoid conflicts »).
   **Contourné** en ajoutant `docker/requirements-local.txt` contenant
   `psycopg2-binary`, mécanisme d'extension officiel appliqué à tous les conteneurs.
2. `ModuleNotFoundError: No module named 'superset.tasks.deletion_retention'` —
   incohérence de l'image `apache/superset:latest` elle-même. **Bug amont**, sans
   rapport avec la configuration locale.

## Options envisagées

- **Réparer** — épingler une version d'image antérieure, ou builder depuis les sources.
  *Pour :* débloque les fonctionnalités asynchrones. *Contre :* revient sur ADR-0003
  pour un besoin actuellement inexistant.
- **Arrêter les conteneurs** — *Pour :* supprime la boucle de redémarrage, sans effet
  sur l'objectif du projet. *Contre :* dette assumée, invisible tant qu'on n'en a pas
  besoin.

## Décision

Les deux conteneurs sont **arrêtés** (`docker stop`). Celery n'est pas nécessaire pour
l'upload CSV synchrone via l'API REST, seul usage actuel.

## Conséquences

- **Indisponible :** rapports planifiés, alertes, cache asynchrone lourd.
- À reprendre si des fonctionnalités asynchrones deviennent nécessaires — probablement
  en épinglant une version d'image, ce qui rouvrirait ADR-0003.
- Le correctif `docker/requirements-local.txt` reste en place et reste utile.
