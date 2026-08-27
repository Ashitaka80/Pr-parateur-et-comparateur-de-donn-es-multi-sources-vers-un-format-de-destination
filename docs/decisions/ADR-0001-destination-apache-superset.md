---
id: ADR-0001
titre: Apache Superset comme premier outil de destination
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

Le projet prépare et compare des données multi-sources pour les pousser « vers un
format de destination ». Cette destination était indéterminée au démarrage. Il fallait
une cible concrète pour valider le pipeline de bout en bout plutôt que de concevoir en
abstrait un connecteur générique.

## Options envisagées

- **Un fichier de sortie normalisé (CSV/Parquet)** — *Pour :* trivial, sans
  infrastructure. *Contre :* ne prouve rien sur l'intégration à un outil réel, où se
  concentrent les difficultés (API, authentification, typage, schémas).
- **Un outil de BI (Apache Superset)** — *Pour :* cible réaliste, API REST documentée,
  déployable en local, exploitation immédiate des données poussées. *Contre :* impose
  une infrastructure de développement à maintenir.
- **Un entrepôt de données (BigQuery, Snowflake)** — *Pour :* cible d'entreprise
  fréquente. *Contre :* dépendance à un service payant et à un accès réseau externe.

## Décision

La destination est **Apache Superset**, en instance locale de développement.
L'architecture reste néanmoins pensée pour accueillir d'autres destinations : la
préparation des données est séparée de l'étape de publication.

## Conséquences

- Le dépôt embarque un outil d'upload spécifique à l'API Superset (ADR-0005).
- Superset lui-même **ne fait pas partie du dépôt** : c'est un service tiers installé
  séparément, ce qui garde le dépôt applicatif indépendant de sa cible.
- Le support d'une seconde destination reste non prouvé tant qu'elle n'est pas écrite.
