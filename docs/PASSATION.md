# Passation — état du projet

> Document de reprise : **à lire en premier si vous reprenez le travail.**
> Mis à jour en fin de session (obligation posée par la délégation D-0003).
> Dernière mise à jour : **2026-08-27**.

## En une phrase

Le pipeline « préparer un fichier → le pousser dans Superset comme dataset » est
écrit, testé et documenté ; **le cœur annoncé du projet — la comparaison
multi-sources — n'est pas commencé.**

## Ce qui bloque immédiatement

**L'outil d'upload n'est pas exécutable en l'état sur cette machine.**

1. **La stack Superset n'est pas démarrée** (`docker ps` ne retourne aucun conteneur),
   mais elle est désormais **dans le dépôt** (`infra/superset/`, ADR-0010) : plus besoin
   de recloner quoi que ce soit. Lancer `./infra/superset/superset.sh secrets` puis
   `./infra/superset/superset.sh up`. Le proxy de la machine est repris automatiquement
   dans les conteneurs par `secrets` ; le drop-in systemd du daemon docker est déjà en
   place sur cette machine, et les builds d'image ont besoin de `--build-arg` (CLAUDE.md).
2. **Deux valeurs manquent dans `.env`** : `SUPERSET_PASSWORD` (vide) et le mot de passe
   Postgres dans `SUPERSET_UPLOAD_SQLALCHEMY_URI` (placeholder `CHANGEME`). Elles sont
   générées par `superset.sh secrets`, qui les affiche à reporter.
   `.claude/skills/project-init/init.sh check` les signale tant que c'est en attente.
3. **L'image `superset-uploader` est à reconstruire** sur toute machine neuve :
   `docker build -t superset-uploader:latest .claude/skills/superset-upload/`.

## Où en est le dépôt

| Brique | État |
|---|---|
| Skill/tool d'upload vers Superset | Écrit, testé de bout en bout lors d'une session antérieure (CSV de démo, puis fichier INSEE des décès en largeur fixe, 56 493 lignes) |
| Configuration et secrets (`.env` / `.env.example` / skill `project-init`) | Fait et vérifié |
| Stack Superset vendorisée (`infra/superset/`) | Fichiers en place, wrapper écrit, compose validé — **jamais démarrée depuis cette machine** |
| Traçabilité (`docs/`, skill `decision-log`) | Fait, 10 ADR, registre des délégations à jour |
| Préparation de sources à format non standard | **Ad hoc** : script écrit au cas par cas, jamais généralisé |
| Comparaison / réconciliation multi-sources | **Pas commencé** |
| Autres destinations que Superset | Pas commencé |
| Workers Celery Superset | Volontairement arrêtés (ADR-0006) |

## Par où commencer

1. **Lire `docs/delegations/REGISTRE.md`** — il dit ce qui est déjà tranché et ne doit
   pas être rouvert (pas de Python sur l'hôte, services tiers en Docker, secrets hors git).
2. **Lire `docs/decisions/`** pour le pourquoi de l'architecture. `CLAUDE.md` complète
   avec les pièges d'exploitation (proxy, mots de passe Postgres, bugs d'image amont).
3. **Remonter l'environnement** : points 1 à 3 de « Ce qui bloque » ci-dessus.
4. **Vérifier** : `.claude/skills/project-init/init.sh check` et
   `.claude/skills/decision-log/trace.sh check` doivent être au vert.

## Prochaine action recommandée

Écrire **`SPEC-0001` sur la comparaison multi-sources** avant d'écrire du code : c'est
le cœur du projet, il n'existe pas, et il demande des arbitrages métier (règles
d'appariement entre sources, traitement des écarts, politique de dédoublonnage) qui
appartiennent aux développeurs. Modèle : `docs/specs/TEMPLATE.md`.

## Points ouverts pour l'équipe

- **`docs/CONTRIBUTEURS.md` ne contient qu'une personne.** Le projet est annoncé comme
  travaillé à plusieurs : chaque développeur doit y ajouter son identité git, sinon les
  ADR qu'il signe ne sont rattachables à personne (`trace.sh check` le signale).
- **`main` n'a jamais reçu de push** des travaux des dernières sessions : `git push`
  est hors délégation (D-0003) et doit être demandé.
- **Le tag d'image Superset est `latest`**, donc mouvant (ADR-0003) : un `docker compose
  pull` peut changer la version sous les pieds de l'équipe. Épingler serait plus sûr.
