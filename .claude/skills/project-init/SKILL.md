---
name: project-init
description: Initialize or audit this project's local configuration — create .env from the versioned .env.example template, keep real credentials out of git while keeping the list of required variables documented, and diagnose a misconfigured .env. Use when setting up the project on a new machine, when a tool fails for a missing/empty environment variable, when adding a new configuration variable, or when checking that no secret is about to be committed.
---

# Initialisation propre d'un projet (.env sans fuite de secrets)

Le principe : **les valeurs restent locales, la liste des variables est versionnée.**

| Fichier | Versionné ? | Contient |
|---|---|---|
| `.env` | **non** (`.gitignore`) | les vraies valeurs, permissions `600` |
| `.env.example` | **oui** | les noms de variables, leur rôle, des placeholders |

Quiconque clone le dépôt sait donc exactement quoi configurer, sans qu'aucun
secret n'ait jamais transité par git.

## Commandes

Toutes via `.claude/skills/project-init/init.sh` (bash pur, rien à installer) :

```bash
.claude/skills/project-init/init.sh init     # 1re installation : crée .env depuis le modèle
.claude/skills/project-init/init.sh check    # audit (défaut) — sortie != 0 si problème
.claude/skills/project-init/init.sh doctor   # audit + corrige ce qui est corrigeable
.claude/skills/project-init/init.sh sync     # ajoute à .env les clés nouvelles du modèle
```

`init` n'écrase **jamais** un `.env` existant. `doctor` ne touche qu'à ce qui est
sans risque : permissions, ligne `.env` dans `.gitignore`, ajout de clés
manquantes avec une valeur vide. Il ne devine aucune valeur.

## Ce que `check` vérifie

1. **Fichiers** — `.env` et `.env.example` présents.
2. **Secrets hors de git** — `.env` couvert par `.gitignore`, non suivi par git,
   **absent de l'historique** (`git log --all -- .env`), en permissions `600`.
3. **Modèle propre** — aucun motif de secret réel dans `.env.example`
   (`ghp_…`, `github_pat_…`, `xox…`, `AKIA…`, clé privée PEM), et aucune valeur
   d'une clé sensible (`*PASSWORD*`, `*TOKEN*`, `*SECRET*`, `*KEY*`) identique
   entre `.env` et `.env.example` — signe qu'un vrai secret a été recopié dans
   le modèle.
4. **Cohérence** — clés du modèle absentes de `.env` (bloquant) ; clés de `.env`
   absentes du modèle (avertissement : à documenter, sinon le prochain
   utilisateur ne saura pas qu'elles existent).
5. **Valeurs** — variables marquées REQUIS mais vides, placeholders `CHANGEME`
   restants, et valeurs `SUPERSET_*` entre guillemets.

## Conventions à respecter dans `.env.example`

- **`REQUIS` dans le commentaire qui précède une clé** la rend bloquante :
  `check` échoue si elle est vide dans `.env`. Le script lit le bloc de
  commentaires immédiatement au-dessus de la ligne `CLE=`.
- **Pas de guillemets autour des valeurs.** Le parseur `.env` de
  `superset-upload` (`scripts/upload_to_superset.py`) fait un simple split sur
  `=` sans les retirer : `SUPERSET_PASSWORD="x"` tenterait de s'authentifier
  avec la valeur `"x"`, guillemets compris.
- **Toute nouvelle variable s'ajoute d'abord ici**, avec son rôle, son défaut
  s'il existe, et où trouver sa valeur — puis `init.sh sync` la propage dans
  les `.env` locaux.

## Ajouter une variable au projet

1. Ajouter la clé + son commentaire explicatif dans `.env.example` (valeur vide
   ou placeholder, jamais la vraie).
2. `init.sh sync` — la clé apparaît dans `.env` avec une valeur vide.
3. Renseigner la valeur dans `.env`.
4. `init.sh check` — doit repasser au vert.
5. Committer **`.env.example` uniquement**.

## En cas d'échec

- `FAIL .env est SUIVI par git` → `git rm --cached .env`, puis committer.
- `FAIL .env apparaît dans l'historique git` → les secrets sont exposés dans les
  objets git même après suppression : **les révoquer et les régénérer** (token
  GitHub, mot de passe Superset), puis réécrire l'historique si le dépôt a été
  poussé.
- `FAIL <CLE> est marquée REQUIS … mais vide` → voir le commentaire de la clé
  dans `.env.example`, il indique où trouver la valeur.
