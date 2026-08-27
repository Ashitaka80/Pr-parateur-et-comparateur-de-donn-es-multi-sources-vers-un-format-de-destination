---
id: ADR-0003
titre: Image Superset pré-construite `latest` plutôt que build depuis les sources
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

Le dépôt `apache/superset` propose plusieurs compositions Docker : `docker-compose.yml`
(build depuis les sources, avec serveur de développement frontend) et
`docker-compose-image-tag.yml` (images pré-construites tirées du registre).

## Options envisagées

- **Build depuis les sources** — *Pour :* permet de modifier Superset. *Contre :* build
  long, nécessite le frontend dev server, inutile ici puisque Superset n'est pas modifié.
- **Image `latest-dev`** — *Pour :* outillage de développement inclus. *Contre :* image
  plus lourde, sans bénéfice pour un usage d'intégration par API.
- **Image `latest` (prod)** — *Pour :* pull rapide, proche d'un déploiement réel.
  *Contre :* on subit les régressions publiées en amont (voir ADR-0006).

## Décision

`TAG=latest` via `docker-compose-image-tag.yml`.

## Conséquences

- Démarrage nettement plus rapide, pas de chaîne de build à maintenir.
- **On subit les bugs de l'image publiée** — matérialisé par ADR-0006.
- `latest` est un tag mouvant : un `docker compose pull` peut changer la version sous
  les pieds de l'équipe. Épingler une version précise serait plus sûr et reste ouvert.
