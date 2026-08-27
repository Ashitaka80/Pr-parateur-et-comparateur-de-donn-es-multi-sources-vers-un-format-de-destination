---
name: compare-sources
description: Compare two prepared data sources (CSV) and produce a discrepancy report — approximate matching on configurable key columns, internal and cross-source duplicate detection, value-mismatch detection. Use when the user asks to compare, reconcile, or diff two data sources, or to find duplicates/discrepancies between two files.
---

# Comparaison et réconciliation de deux sources

Implémente [`SPEC-0001`](../../../docs/specs/SPEC-0001-comparaison-et-reconciliation-de-deux-sources-de-donnees.md).
Compare deux fichiers CSV déjà préparés (sortie du pipeline de préparation existant),
apparie leurs enregistrements par similarité approchée sur des colonnes configurables,
et produit un **rapport d'écarts** — rien n'est corrigé ou fusionné automatiquement.

Tourne entièrement via Docker — **aucune dépendance Python côté hôte**, et aucune
dépendance externe non plus : normalisation et similarité de chaînes en pur stdlib
(`unicodedata`, `difflib`), pas de pandas/rapidfuzz, pour rester aussi minimal que le
reste de l'outillage du projet.

## Prérequis

Construire l'image (une fois, ou après modification de `scripts/`/`tests/`, `COPY`'d
au build, pas montés en live) :

```bash
docker build -t compare-sources:latest .claude/skills/compare-sources/
```

## Usage

```bash
.claude/skills/compare-sources/compare.sh \
  --source-a chemin/vers/source_a.csv \
  --source-b chemin/vers/source_b.csv \
  --match-on nom,prenom,date_naissance \
  [--compare-on ville,statut]           # défaut : toutes les colonnes communes hors --match-on
  [--threshold 0.85]                    # défaut : 0.85, échelle 0-1
  [--delimiter ";"]                     # défaut : virgule
  --output-dir chemin/vers/rapport/
```

`compare.sh` ne monte que les dossiers parents de `--source-a`/`--source-b` (lecture
seule) et `--output-dir` (écriture), le temps de l'appel — rien d'autre du disque hôte
n'est exposé.

## Ce que ça fait (résumé de SPEC-0001)

1. **Déduplication interne** de chaque source sur les colonnes `--match-on` : les
   doublons sont retirés du jeu comparé et tracés (jamais supprimés sans trace).
2. **Appariement approché** entre les deux sources dédoublonnées, tolérant aux
   variations mineures (casse, accents, fautes de frappe) grâce à
   `difflib.SequenceMatcher` sur les valeurs normalisées.
3. **Classification** de chaque enregistrement : `concordant`, `ecart_valeur` (avec le
   détail des colonnes qui divergent), `seulement_a` / `seulement_b`, ou
   `doublon_croise` (un enregistrement apparié à plusieurs de l'autre côté — jamais
   résolu automatiquement).

## Sorties

Dans `--output-dir` :
- `report.csv` — une ligne par enregistrement/paire, colonnes `status, a_row, b_row,
  score, details`.
- `doublons_internes_source_a.csv` / `doublons_internes_source_b.csv` — colonnes
  `removed_row, kept_row, score`.

`report.csv` est un CSV standard : pour le pousser vers Superset, réutiliser tel quel
`.claude/skills/superset-upload/upload.sh --file <output-dir>/report.csv ...`
(question ouverte de SPEC-0001 tranchée ainsi : pas d'intégration automatique en V1).

## Tests

```bash
.claude/skills/compare-sources/run-tests.sh
```

Suite `unittest` (stdlib, pas de pytest) couvrant les critères d'acceptation de
SPEC-0001 : sources identiques, enregistrement présent dans une seule source, écart de
valeur, doublon interne, doublon croisé, colonne d'appariement absente (échec avant
tout traitement).

## Limitations connues

- Comparaison en O(|A|×|B|) : pas d'indexation/blocage, adapté aux volumes visés par
  ce projet, pas à de gros jeux de données (voir SPEC-0001, hors périmètre : pas
  d'optimisation de performance en V1).
- Exactement deux sources (SPEC-0001 exclut explicitement N sources en V1).
- Score de similarité = moyenne simple des similarités par colonne d'appariement,
  sans pondération par colonne.
