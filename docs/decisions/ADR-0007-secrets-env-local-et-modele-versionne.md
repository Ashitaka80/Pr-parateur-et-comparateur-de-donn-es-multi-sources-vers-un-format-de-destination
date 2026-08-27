---
id: ADR-0007
titre: Secrets en `.env` local, contrat de configuration versionné en `.env.example`
statut: acceptée
date: 2026-08-27
décideur: user808 <user808@mail.com>
proposé par: user808
validation: confirmée
délégation: —
remplace: —
remplacé par: —
---

## Contexte

Le projet manipule des credentials (token GitHub, mot de passe Superset, URI Postgres).
Deux exigences apparemment opposées ont été posées explicitement : les credentials ne
doivent **pas** être dans git, et on doit **malgré tout** savoir ce qu'il faut
configurer. Sans le second point, un nouveau développeur découvre les variables
manquantes une par une, au fil des erreurs d'exécution.

## Options envisagées

- **`.env` seul, ignoré par git** — *Pour :* simple. *Contre :* la liste des variables
  n'existe nulle part ; elle se reconstitue en lisant le code.
- **Gestionnaire de secrets (Vault, SOPS, âge)** — *Pour :* secrets partageables et
  chiffrés dans le dépôt. *Contre :* infrastructure et gestion de clés hors de
  proportion pour un environnement de développement individuel.
- **`.env` local + `.env.example` versionné** — *Pour :* séparation nette valeurs /
  contrat, convention universellement comprise, coût nul. *Contre :* les deux fichiers
  peuvent diverger silencieusement — d'où l'outillage de vérification.

## Décision

Deux fichiers aux rôles strictement séparés : **`.env`** (valeurs réelles,
permissions `600`, jamais versionné) et **`.env.example`** (versionné, mêmes clés,
aucun secret, rôle de chaque variable et où trouver sa valeur).

Un skill `.claude/skills/project-init/` outille le cycle : `init`, `check`, `doctor`,
`sync`. Le contrôle ne se limite pas au `.gitignore` — il vérifie aussi que `.env`
est absent de **l'historique** git, et qu'aucune valeur de clé sensible n'est identique
entre `.env` et `.env.example`, ce qui détecterait un secret recopié dans le modèle.

## Conséquences

- Généralisée en directive permanente **DP-0003**.
- Toute nouvelle variable s'ajoute **d'abord** à `.env.example`, puis se propage par
  `init.sh sync`. Une variable non documentée est signalée.
- Le mot-clé `REQUIS` dans le commentaire précédant une clé la rend bloquante.
- **Contrainte héritée :** les valeurs `SUPERSET_*` ne doivent pas être entourées de
  guillemets — le parseur de `upload_to_superset.py` fait un `partition("=")` sans les
  retirer, et authentifierait avec les guillemets. Contrôlé par `init.sh check`.
