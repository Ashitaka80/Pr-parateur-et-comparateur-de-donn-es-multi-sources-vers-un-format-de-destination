---
id: ADR-0010
titre: Vendoriser la stack Superset dans le dépôt plutôt que dépendre d'un clone externe
statut: acceptée
date: 2026-08-27
décideur: user808 <user808@mail.com>
proposé par: Claude
validation: confirmée
ratification: demande explicite du 2026-08-27
délégation: —
remplace: —
remplacé par: —
---

## Contexte

L'infrastructure Superset vivait hors du dépôt, dans un clone d'`apache/superset` en
`/home/user/superset-docker`, présenté comme « service tiers installé séparément »
(ADR-0001). Ce clone contenait aussi la configuration **propre au projet** : secrets
alignés, variables de proxy pour les conteneurs, et `docker/requirements-local.txt`
ajouté pour les workers.

Ce clone a disparu de la machine. Avec lui a disparu toute la configuration, qui
n'existait nulle part ailleurs : le dépôt seul ne permettait pas de remonter un
environnement fonctionnel. Un collègue qui clone le projet héritait d'un outil d'upload
sans cible où le pointer.

Le développeur a demandé que **toute arborescence utile au projet et située hors de
l'arborescence projet y soit ramenée**.

## Options envisagées

- **Documenter l'installation externe** dans le README, sans vendoriser. *Pour :* le
  dépôt reste petit et sans code tiers. *Contre :* c'est précisément ce qui existait, et
  qui a échoué — une procédure écrite ne remplace pas des fichiers versionnés.
- **Cloner `apache/superset` en sous-module git.** *Pour :* mise à jour d'upstream par
  une commande. *Contre :* tire un dépôt de plusieurs centaines de Mo pour trois
  fichiers ; les sous-modules sont une source classique d'états incohérents ; la
  configuration locale n'y a pas sa place.
- **Réécrire un `docker-compose.yml` minimal de notre cru.** *Pour :* sur mesure, sans
  code tiers. *Contre :* réécrit de mémoire ce qu'upstream maintient et teste ; perd les
  scripts de bootstrap, d'init et de healthcheck, qui portent l'essentiel de la logique.
- **Vendoriser les fichiers nécessaires** (`docker-compose-image-tag.yml` + `docker/`),
  avec le commit d'origine noté. *Pour :* dépôt autonome, fichiers éprouvés par upstream,
  diffables contre une version plus récente. *Contre :* copie figée, à resynchroniser à
  la main.

## Décision

Les fichiers nécessaires d'`apache/superset` sont copiés dans **`infra/superset/`**
(164 Ko), en-têtes de licence Apache-2.0 conservés, avec le commit d'origine enregistré
dans `infra/superset/UPSTREAM` :

    5879994e683e7ec01ed4809eaf35552f7f69b0b4

Un wrapper **`infra/superset/superset.sh`** (`secrets`, `up`, `down`, `reset`,
`status`, `logs`) pilote la stack et **fige le nom de projet compose à `superset`**.
Sans ce verrouillage, compose déduirait le nom du dossier, et le réseau changerait de
nom selon l'emplacement du dépôt — cassant le tool d'upload, qui s'y attache.

`superset.sh secrets` génère les mots de passe et **règle au passage deux pièges
documentés** : il aligne `POSTGRES_PASSWORD` et `DATABASE_PASSWORD` (leur divergence
faisait échouer `superset-init`), et reprend les variables de proxy de l'environnement
pour les injecter dans les conteneurs.

## Conséquences

- **Le dépôt devient autonome** : cloner, `superset.sh secrets`, `superset.sh up`,
  et l'environnement est debout. C'était l'objectif.
- `upload.sh` cible désormais le réseau `superset_default` (au lieu de
  `superset-docker_default`), surchargeable par `SUPERSET_NETWORK`.
- `docker/.env` d'upstream est versionné (aucun secret) via une **exception explicite**
  dans `.gitignore`, dont la règle `.env` l'aurait sinon exclu — et le déploiement
  aurait échoué chez le collègue sans que rien ne le signale.
- **Copie figée** : les correctifs d'upstream ne remontent pas seuls. Le fichier
  `UPSTREAM` existe pour rendre la comparaison possible.
- ADR-0001 disait Superset « hors du dépôt applicatif » : ce n'est plus vrai pour son
  déploiement de développement. La séparation demeure au sens où Superset reste un
  service tiers, non une dépendance de code.
