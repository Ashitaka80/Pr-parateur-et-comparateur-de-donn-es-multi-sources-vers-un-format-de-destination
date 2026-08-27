---
id: SPEC-0001
titre: Comparaison et réconciliation de deux sources de données
statut: implémentée      # brouillon | validée | implémentée | abandonnée
date: 2026-08-27
auteur: Claude
validée par: user808 <user808@mail.com>
adr liés:                 # ADR-XXXX, … ou —
---

## Besoin

Aujourd'hui, chaque source (fichier CSV, Excel, largeur fixe…) est préparée puis
uploadée vers Superset **indépendamment des autres** — rien dans le projet ne les
confronte entre elles. Deux extractions du même domaine, issues de systèmes
différents, peuvent donc diverger silencieusement (enregistrements manquants d'un
côté, valeurs différentes, doublons) sans qu'aucun outil ne le signale.

Sert au développeur/analyste qui reçoit deux extractions déjà préparées (sortie du
pipeline de préparation existant) et veut savoir, avant de les pousser dans Superset,
où elles se recoupent, où elles divergent, et si l'une ou l'autre contient des
doublons — sans que rien ne soit corrigé automatiquement à sa place.

Arbitrages actés avec le développeur le 2026-08-27 :
- Portée V1 : **exactement deux sources**, pas N.
- Appariement **approché** entre les deux sources (aucune clé commune fiable
  supposée) : combinaison de colonnes-clés configurables, tolérantes aux variations
  mineures (casse, accents, fautes de frappe).
- Objectif double : **réconciliation croisée** entre les deux sources **et**
  **nettoyage** (déduplication), à la fois à l'intérieur de chaque source et entre
  les deux une fois appariées.
- Sortie : **un rapport des écarts, rien d'automatique** — jamais de correction ou de
  fusion silencieuse des données.
- Reste **générique et paramétrable** : aucun domaine métier figé dans cette spec, les
  colonnes d'appariement et de comparaison sont fournies par l'utilisateur.

## Périmètre

**Dans le périmètre :**
- Exactement deux sources en entrée par exécution.
- Chaque source déjà structurée en colonnes (sortie du pipeline de préparation
  existant — un CSV normalisé, par exemple) : cette spec ne reparse pas de format
  brut.
- Une configuration explicite fournie par l'utilisateur : colonnes d'appariement
  (avec leur tolérance), seuil de similarité pour valider un appariement, colonnes à
  comparer pour détecter les écarts de valeur (peuvent différer des colonnes
  d'appariement).
- Déduplication **interne** à chaque source, sur les mêmes colonnes-clés que
  l'appariement, avant toute comparaison croisée.
- Appariement **approché** (fuzzy) entre les deux sources dédoublonnées.
- Déduplication **croisée** : un enregistrement d'une source qui correspond, au-dessus
  du seuil, à plusieurs enregistrements de l'autre source.
- Un rapport structuré listant, pour chaque enregistrement ou paire concernée, son
  statut et le détail de l'écart.

**Hors périmètre :**
- Toute résolution automatique des écarts (fusion, choix d'une source de vérité,
  correction des données sources) — seulement signalé, jamais corrigé.
- Comparaison de plus de deux sources simultanément (évolution possible, non traitée
  ici).
- Détection ou suggestion automatique des colonnes d'appariement — l'utilisateur les
  fournit.
- Interface graphique dédiée : le rapport est un artefact de données (fichier/table),
  pas un outil interactif de résolution de conflits.
- Le choix de l'algorithme de similarité précis et de la bibliothèque associée
  (question ouverte, tranchée à l'implémentation).

## Comportement attendu

**Entrées :**
- Source A et source B, chacune un jeu de données structuré en colonnes (mêmes
  formats que ceux déjà produits par la préparation existante).
- Une configuration :
  - colonnes d'appariement (une ou plusieurs), chacune avec sa tolérance aux
    variations mineures ;
  - seuil de similarité globale à partir duquel un appariement est retenu ;
  - colonnes à comparer pour détecter un écart de valeur sur un enregistrement par
    ailleurs apparié (indépendant des colonnes d'appariement).

**Étapes :**
1. **Déduplication interne** de A, puis de B, sur les colonnes d'appariement : produit
   une version dédoublonnée de chaque source, et une liste séparée des doublons
   internes retirés (tracés, jamais supprimés silencieusement).
2. **Appariement approché** entre A et B dédoublonnées : pour chaque enregistrement de
   A, recherche du/des meilleur(s) candidat(s) dans B dont le score de similarité sur
   les colonnes d'appariement dépasse le seuil configuré.
3. **Classification** de chaque enregistrement/paire :
   - apparié, score ≥ seuil, aucun écart sur les colonnes comparées → **concordant** ;
   - apparié, score ≥ seuil, écart sur au moins une colonne comparée → **écart de
     valeur** (avec le détail : colonne, valeur côté A, valeur côté B) ;
   - un enregistrement de A (ou B) correspond à plusieurs enregistrements de l'autre
     source au-dessus du seuil → **doublon croisé**, signalé, jamais résolu seul ;
   - aucun candidat de l'autre source au-dessus du seuil → **présent seulement dans
     A** (symétriquement pour B).
4. **Production du rapport** : la liste de tous les enregistrements/paires avec leur
   statut, plus les deux listes de doublons internes retirés à l'étape 1.

**Sorties :** un rapport structuré (a minima tabulaire), réutilisable tel quel par le
pipeline d'upload existant vers Superset s'il doit être publié — cette spec ne tranche
pas si c'est automatique (voir Questions ouvertes).

**Cas d'erreur :**
- Une colonne d'appariement ou de comparaison absente de l'une des deux sources →
  échec explicite avant tout traitement, pas de comparaison partielle silencieuse.
- Source vide (A ou B) → rapport produit, sans erreur : tous les enregistrements de
  l'autre source ressortent en « présent seulement dans... ».
- Aucun appariement au-dessus du seuil pour aucun enregistrement → rapport composé
  uniquement d'entrées « présent seulement dans A » / « présent seulement dans B ».

## Critères d'acceptation

- [ ] Deux sources strictement identiques produisent un rapport sans écart ni doublon
      croisé — tout est « concordant ».
- [ ] Un enregistrement de A sans aucun candidat ≥ seuil dans B est signalé « présent
      seulement dans A », jamais silencieusement omis du rapport.
- [ ] Un enregistrement apparié dont une colonne comparée diffère entre A et B est
      signalé « écart de valeur », avec la colonne et les deux valeurs.
- [ ] Un doublon interne à une source est retiré du jeu comparé et apparaît dans une
      liste de doublons internes séparée — jamais supprimé sans trace.
- [ ] Un enregistrement de A apparié à plusieurs enregistrements de B au-dessus du
      seuil est signalé « doublon croisé », sans résolution automatique.
- [ ] Les colonnes d'appariement, leur tolérance, le seuil et les colonnes comparées
      sont configurables sans modifier le code.
- [ ] Aucune exécution ne modifie ou ne fusionne les données sources : seule la
      génération du rapport a un effet observable.
- [ ] Une colonne d'appariement/comparaison absente d'une source fait échouer
      l'exécution avant tout traitement, avec un message explicite.

## Questions ouvertes

Tranchées à l'implémentation (2026-08-27), consignées ici plutôt que rejouées :

- **Algorithme de similarité** : `difflib.SequenceMatcher` de la stdlib Python, sur
  valeurs normalisées (minuscules, accents retirés, espaces compactés) — pas de
  dépendance externe (pandas/rapidfuzz), pour rester aussi minimal que
  `superset-uploader` (DP-0001). Score combiné = moyenne simple des similarités par
  colonne d'appariement.
- **Publication vers Superset** : pas automatique. `report.csv` est un CSV standard,
  poussable avec `.claude/skills/superset-upload/upload.sh` comme n'importe quel autre
  fichier préparé — pas d'intégration dédiée en V1.

Restent ouvertes :

- **Seuil de similarité par défaut** : fixé à 0,85 dans l'implémentation, à ajuster
  empiriquement une fois un jeu de données réel utilisé.
- **Généralisation à N sources** (annoncée par le nom du projet) : explicitement hors
  périmètre de cette V1. Si elle est reprise plus tard, elle demandera de nouveaux
  arbitrages (comparer toutes les paires ? une source pivot ?) — à traiter dans une
  spec ultérieure, pas une extension silencieuse de celle-ci.
- **Performance** : comparaison en O(|A|×|B|), sans indexation/blocage — suffisant
  pour les volumes visés par ce projet, pas optimisé pour de gros jeux de données.

## Implémentation

`.claude/skills/compare-sources/` — voir son `SKILL.md`. Testé de bout en bout le
2026-08-27 : suite `unittest` (12 tests, stdlib, exécutée dans l'image Docker) au vert,
plus un scénario manuel avec typo, accents, doublon interne et enregistrements
uniques de chaque côté, résultat conforme à tous les critères d'acceptation
ci-dessus.
