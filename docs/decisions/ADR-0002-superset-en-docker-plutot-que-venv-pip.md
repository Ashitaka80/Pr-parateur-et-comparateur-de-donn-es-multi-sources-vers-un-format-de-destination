---
id: ADR-0002
titre: Superset déployé en Docker plutôt qu'installé en venv pip
statut: acceptée
date: 2026-08-27
décideur: user808 <user808@mail.com>
proposé par: Claude
validation: confirmée
délégation: —
remplace: —
remplacé par: —
---

## Contexte

Une première installation de Superset via `pip install apache-superset` dans un venv
(`/home/user/superset/venv`) a été réalisée et **fonctionnait**, après contournement
d'un bug de compatibilité : `flask-caching` 2.5.0 casse `SupersetMetastoreCache`, qui
ne supporte pas le kwarg `ignore_delete_many_errors` introduit par les versions
récentes — résolu en figeant `flask-caching==2.1.0`.

Ce contournement illustre le coût de l'approche : l'environnement dépend de l'état du
résolveur pip au moment de l'installation, et n'est pas reproductible.

## Options envisagées

- **venv pip** — *Pour :* déjà en place et fonctionnel, démarrage rapide, pas de
  dépendance à Docker. *Contre :* environnement non reproductible, épinglages
  manuels, éloigné d'un déploiement réel, réinitialisation coûteuse.
- **Docker Compose** — *Pour :* proche d'un déploiement réaliste, réinitialisable,
  versions figées par les images. *Contre :* exige l'installation de Docker (droits
  root) et une configuration de proxy supplémentaire.

## Décision

Superset tourne en **Docker Compose**. L'installation venv est abandonnée
(processus gunicorn arrêté, venv conservé sans être supprimé).

Cette décision a été prise **sur demande explicite du développeur**, alors que
l'installation venv fonctionnait — le critère retenu est le réalisme du déploiement et
le coût de maintenance, pas le fonctionnement immédiat.

## Conséquences

- Généralisée en directive permanente **DP-0002** : les services tiers se déploient en
  Docker.
- A imposé de résoudre trois problèmes d'infrastructure documentés dans `CLAUDE.md` :
  installation de Docker par le développeur (pas de `sudo` interactif depuis Claude
  Code), proxy HTTP à injecter dans le daemon via un drop-in systemd, puis proxy à
  injecter aussi dans les conteneurs via `docker/.env-local`.
- Le venv abandonné reste sur disque : à supprimer si l'espace ou la clarté l'exigent.
