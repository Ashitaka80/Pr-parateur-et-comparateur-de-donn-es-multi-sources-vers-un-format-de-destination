# Décisions d'architecture (ADR)

Une décision par fichier, numérotée, **immuable une fois acceptée** : on ne la
réécrit pas, on la remplace par un nouvel ADR qui la supersède. La trace des choix
écartés vaut autant que celle des choix retenus — c'est elle qui évite de réexplorer
une impasse six mois plus tard.

Nouvelle décision : `.claude/skills/decision-log/trace.sh adr "Titre"`, puis
`trace.sh index`.

## Attribution

`décideur:` porte **une personne**, identifiée par son identité git
(voir [`../CONTRIBUTEURS.md`](../CONTRIBUTEURS.md)). Claude n'est jamais décideur : il
apparaît en `proposé par:`. Une décision appliquée sans validation humaine explicite
porte `validation: à confirmer` — elle tient, mais elle attend une ratification.

<!-- INDEX:début - régénéré par trace.sh index, ne pas éditer à la main -->
| ID | Décision | Statut | Décideur | Validation |
|---|---|---|---|---|
| [ADR-0001](ADR-0001-destination-apache-superset.md) | Apache Superset comme premier outil de destination | acceptée | user808 <user808@mail.com> | confirmée |
| [ADR-0002](ADR-0002-superset-en-docker-plutot-que-venv-pip.md) | Superset déployé en Docker plutôt qu'installé en venv pip | acceptée | user808 <user808@mail.com> | confirmée |
| [ADR-0003](ADR-0003-image-superset-prebuild-latest.md) | Image Superset pré-construite `latest` plutôt que build depuis les sources | acceptée | user808 <user808@mail.com> | confirmée |
| [ADR-0004](ADR-0004-base-uploads-distincte-de-la-metadata-db.md) | Base Postgres `uploads` distincte de la metadata DB de Superset | acceptée | user808 <user808@mail.com> | confirmée |
| [ADR-0005](ADR-0005-outil-upload-image-dediee-jetable.md) | Outil d'upload exécuté dans une image Docker dédiée et jetable | acceptée | user808 <user808@mail.com> | confirmée |
| [ADR-0006](ADR-0006-workers-celery-arretes.md) | Workers Celery arrêtés plutôt que réparés | acceptée | user808 <user808@mail.com> | confirmée |
| [ADR-0007](ADR-0007-secrets-env-local-et-modele-versionne.md) | Secrets en `.env` local, contrat de configuration versionné en `.env.example` | acceptée | user808 <user808@mail.com> | confirmée |
| [ADR-0008](ADR-0008-tracabilite-des-decisions-et-delegations.md) | Traçabilité écrite des décisions, délégations et spécifications | acceptée | user808 <user808@mail.com> | confirmée |
| [ADR-0009](ADR-0009-workflow-git-et-versionnement.md) | Workflow git — branches thématiques, Conventional Commits, passation écrite | acceptée | user808 <user808@mail.com> | confirmée |
| [ADR-0010](ADR-0010-vendoriser-la-stack-superset.md) | Vendoriser la stack Superset dans le dépôt plutôt que dépendre d'un clone externe | acceptée | user808 <user808@mail.com> | confirmée |
| [ADR-0011](ADR-0011-bootstrap-et-smoke-test-integres-a-superset-sh.md) | Bootstrap et smoke-test intégrés à superset.sh | acceptée | user808 <user808@mail.com> | confirmée |
| [ADR-0012](ADR-0012-script-push-git-avec-authentification-dediee.md) | Script de push git avec authentification dédiée, à lancer par le développeur | acceptée | user808 <user808@mail.com> | confirmée |
<!-- INDEX:fin -->
