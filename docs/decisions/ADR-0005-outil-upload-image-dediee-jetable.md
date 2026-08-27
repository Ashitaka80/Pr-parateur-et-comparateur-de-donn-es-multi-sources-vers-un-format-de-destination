---
id: ADR-0005
titre: Outil d'upload exécuté dans une image Docker dédiée et jetable
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

Le tool d'upload est un script Python dont la seule dépendance externe est `requests`.
Trois façons de l'exécuter ont été essayées successivement, chacune écartée pour une
raison différente — l'historique importe, car chaque option paraît raisonnable isolément.

## Options envisagées

- **venv sur la machine hôte** — *Pour :* une seule dépendance, immédiat, fonctionnait.
  *Contre :* incohérent avec un projet « tout Docker » — **retour explicite du
  développeur**, à l'origine de la directive permanente DP-0001.
- **`docker exec` dans le conteneur `superset_app`** — qui embarque déjà `requests`.
  *Pour :* aucune image à construire. *Contre :* impose de monter des chemins hôte
  (script, `.env`, fichier à uploader) dans un conteneur de service **persistant** ;
  les garde-fous de sécurité de l'environnement ont bloqué l'élargissement de ce
  montage au-delà d'un dossier de scripts. Un montage large et permanent sur un
  conteneur exposé est de toute façon un mauvais compromis.
- **Image dédiée et jetable** — `python:3.12-slim` + `requests`, lancée en
  `docker run --rm` par appel. *Pour :* aucun Python hôte, montage minimal et
  éphémère. *Contre :* une image à construire et à reconstruire après modification des
  scripts.

## Décision

Une image **`superset-uploader`**, construite depuis
`.claude/skills/superset-upload/Dockerfile`, lancée par `upload.sh` en
`docker run --rm` sur le réseau `superset-docker_default`. Le wrapper ne monte que
**le dossier parent du fichier `--file`** (lecture seule) et **`.env`** — rien d'autre
de l'hôte n'est exposé, et le montage ne survit pas à l'appel.

## Conséquences

- Satisfait DP-0001 sans le compromis de sécurité du montage large et permanent.
- **Les scripts sont `COPY`'d dans l'image au build**, pas montés : toute modification
  de `scripts/` impose `docker build -t superset-uploader:latest
  .claude/skills/superset-upload/`. C'est le principal irritant de cette approche.
- `docker build` **n'hérite pas** du proxy configuré au niveau du daemon : passer
  `--build-arg HTTP_PROXY=…` / `HTTPS_PROXY=…` pour les étapes `RUN pip install`.
- Le conteneur tournant sur le réseau docker, `SUPERSET_URL` doit être un hostname
  interne (`http://superset_app:8088`), d'où la variable distincte
  `SUPERSET_PUBLIC_URL` pour le lien affiché à l'humain.
