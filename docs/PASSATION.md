# Passation — état du projet

> Document de reprise : **à lire en premier si vous reprenez le travail.**
> Mis à jour en fin de session (obligation posée par la délégation D-0003).
> Dernière mise à jour : **2026-08-27**.

## En une phrase

Le pipeline « préparer un fichier → le pousser dans Superset comme dataset » est
écrit, testé et documenté. **La comparaison entre deux sources — le cœur annoncé du
projet — est désormais spécifiée (SPEC-0001) et implémentée** (`.claude/skills/compare-sources/`,
branche `docs/spec-0001-comparaison-multi-sources`, pas encore mergée dans `main`).
Reste hors périmètre : la généralisation à plus de deux sources.

## Branches ouvertes, pas encore mergées dans `main` (2026-08-27)

Trois branches coexistent, chacune un chantier distinct, aucune mergée :

| Branche | Contenu | Poussée sur origin ? |
|---|---|---|
| `main` | Base : préparation + upload Superset, traçabilité (10 ADR) | — |
| `feat/bootstrap-smoke-test` | ADR-0011 (`superset.sh bootstrap`/`smoke-test`), ADR-0012 (`scripts/git-push.sh` + credential helper dédié) | Oui, 4 commits |
| `docs/spec-0001-comparaison-multi-sources` | SPEC-0001 + skill `compare-sources` (implémenté, testé) | **Non — à pousser** |

**Avant de repartir de `main` en clonant à nouveau**, vérifier ces branches sur
`origin` — leur travail n'existe nulle part ailleurs.

## État vérifié le 2026-08-27

**La chaîne complète a été validée de bout en bout sur cette machine** : stack démarrée
depuis `infra/superset/`, image `superset-uploader` construite, CSV de démo (200 lignes)
uploadé, table `ventes_demo` créée dans la base `uploads` et dataset enregistré dans
Superset (id 22), tous deux vérifiés en base.

Sur une **autre** machine, il reste à dérouler :

```bash
./infra/superset/superset.sh secrets   # génère les mots de passe, les affiche
./infra/superset/superset.sh up        # première init : plusieurs minutes
docker build -t superset-uploader:latest \
  --build-arg HTTP_PROXY="$HTTP_PROXY" --build-arg HTTPS_PROXY="$HTTPS_PROXY" \
  .claude/skills/superset-upload/
.claude/skills/project-init/init.sh check   # doit être au vert
```

## Historique — ce qui bloquait avant le 2026-08-27

1. La stack Superset avait disparu de la machine. Résolu : elle est **dans le dépôt**
   (`infra/superset/`, ADR-0010), et elle tourne.
2. Deux valeurs manquaient dans `.env`. Résolu : générées par `superset.sh secrets` et
   reportées ; `init.sh check` est au vert.
3. L'image `superset-uploader` restait à construire. Résolu sur cette machine ; à
   refaire sur toute machine neuve, avec les `--build-arg` de proxy.

## Où en est le dépôt

| Brique | État |
|---|---|
| Skill/tool d'upload vers Superset | Écrit, testé de bout en bout lors d'une session antérieure (CSV de démo, puis fichier INSEE des décès en largeur fixe, 56 493 lignes) |
| Configuration et secrets (`.env` / `.env.example` / skill `project-init`) | Fait et vérifié |
| Stack Superset vendorisée (`infra/superset/`) | Démarrée et validée de bout en bout |
| Traçabilité (`docs/`, skill `decision-log`) | Fait, 12 ADR, 4 délégations, 1 spec, registre à jour |
| Préparation de sources à format non standard | **Ad hoc** : script écrit au cas par cas, jamais généralisé |
| **Comparaison de deux sources** (SPEC-0001) | **Fait** : `compare-sources`, testé (12 tests unitaires + scénario manuel), sur branche `docs/spec-0001-comparaison-multi-sources` |
| Généralisation de la comparaison à N sources | Pas commencé — explicitement hors périmètre de SPEC-0001 |
| Bootstrap/smoke-test one-shot pour une machine neuve | Fait (ADR-0011), sur branche `feat/bootstrap-smoke-test` |
| Script de push git avec authentification dédiée | Fait (ADR-0012), sur branche `feat/bootstrap-smoke-test` — **push toujours à lancer par le développeur**, le classificateur du mode auto le bloque pour Claude |
| Autres destinations que Superset | Pas commencé |
| Workers Celery Superset | Jamais démarrés par `superset.sh up` (bug amont, ADR-0006) ; `WITH_WORKERS=1` pour forcer |

## Par où commencer

1. **Lire `docs/delegations/REGISTRE.md`** — il dit ce qui est déjà tranché et ne doit
   pas être rouvert (pas de Python sur l'hôte, services tiers en Docker, secrets hors git).
2. **Lire `docs/decisions/`** pour le pourquoi de l'architecture. `CLAUDE.md` complète
   avec les pièges d'exploitation (proxy, mots de passe Postgres, bugs d'image amont).
3. **Remonter l'environnement** : voir le bloc de commandes ci-dessus.
4. **Vérifier** : `.claude/skills/project-init/init.sh check` et
   `.claude/skills/decision-log/trace.sh check` doivent être au vert.
5. **En fin de session** : `.claude/skills/session-close/close.sh` doit sortir en 0 —
   il vérifie que rien ne reste en local, que ce document est à jour, et liste les
   décisions en attente de validation.

## Prochaine action recommandée

1. **Pousser `docs/spec-0001-comparaison-multi-sources` sur origin**, puis ouvrir des
   PR pour les deux branches en attente et décider d'un ordre de merge dans `main`
   (elles ne se recouvrent pas, l'ordre importe peu).
2. Ensuite, au choix de l'équipe : généraliser la comparaison à N sources, généraliser
   la préparation de formats non standard (actuellement ad hoc), ou décider si
   `compare-sources` doit pousser son rapport vers Superset automatiquement (question
   tranchée « non » pour la V1 dans SPEC-0001, à rouvrir si le besoin se confirme).

## Points ouverts pour l'équipe

- **`docs/CONTRIBUTEURS.md` ne contient qu'une personne.** Le projet est annoncé comme
  travaillé à plusieurs : chaque développeur doit y ajouter son identité git, sinon les
  ADR qu'il signe ne sont rattachables à personne (`trace.sh check` le signale).
- **La PR [#1](https://github.com/Ashitaka80/Pr-parateur-et-comparateur-de-donn-es-multi-sources-vers-un-format-de-destination/pull/1)
  est fusionnée dans `main`** (merge commit `7c2da18`, 10 commits conservés) — sur
  demande explicite, **sans relecture par un tiers**. Les trois points qu'elle soumettait
  à un relecteur restent donc ouverts : compléter `docs/CONTRIBUTEURS.md`, écrire
  `SPEC-0001` avant de coder la comparaison, et décider d'épingler ou non le tag d'image
  Superset (ADR-0003).
  Point à connaître pour la suite : les jetons **fine-grained** (`github_pat_…`) essayés
  sur ce dépôt échouaient tous en `403 Resource not accessible by personal access token`,
  alors même que le compte avait le rôle *push*. Un jeton **classique** (`ghp_…`) avec
  le scope `repo` fonctionne. En cas de 403 au push, vérifier d'abord le type de jeton
  avant de chercher ailleurs.

- **Une entorse à ADR-0009 est en place sur `main`, à trancher.** Le commit `17e3927`
  (mise à jour de ce document après la fusion de la PR #1) a été poussé **directement sur
  `main`**, alors qu'ADR-0009 interdit tout commit direct sur cette branche et que la
  délégation D-0004 exclut le push sur `main`. L'historique n'a pas été réécrit : la trace
  vaut mieux que l'effacement. Trois suites possibles, au choix de l'équipe :
  - **Amender ADR-0009** par un nouvel ADR autorisant les commits de documentation sur
    `main` — sinon la règle écrite et la pratique divergent dès le premier jour ;
  - **Durcir** : activer une protection de branche côté GitHub, qui rendrait l'entorse
    impossible plutôt que déconseillée ;
  - **Traiter le cas comme une exception assumée**, notée au registre des délégations.

  Tant que rien n'est tranché, la règle reste celle d'ADR-0009 : passer par une branche.

- **Le tag d'image Superset est `latest`**, donc mouvant (ADR-0003) : un `docker compose
  pull` peut changer la version sous les pieds de l'équipe. Épingler serait plus sûr.
