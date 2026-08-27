# Passation — état du projet

> Document de reprise : **à lire en premier si vous reprenez le travail.**
> Mis à jour en fin de session (obligation posée par la délégation D-0003).
> Dernière mise à jour : **2026-08-27**.

## En une phrase

Le pipeline « préparer un fichier → le pousser dans Superset comme dataset » est
écrit, testé et documenté ; **le cœur annoncé du projet — la comparaison
multi-sources — n'est pas commencé.**

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
| Traçabilité (`docs/`, skill `decision-log`) | Fait, 10 ADR, 4 délégations, registre à jour |
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
- **Rien n'est encore poussé sur `origin`.** Le push est délégué (D-0004), mais il
  échoue : `remote: Permission to Ashitaka80/… denied to Al-Garoth`, et l'API répond
  `Resource not accessible by personal access token`. Le `GITHUB_TOKEN` du `.env` est un
  jeton **fine-grained** appartenant au compte `Al-Garoth`, qui a bien le rôle *push* sur
  le dépôt mais dont le jeton ne porte pas la permission **Contents: Read and write**.
  À corriger côté GitHub (Settings → Developer settings → Personal access tokens →
  Fine-grained → ce jeton → Repository permissions → Contents : Read and write, en
  vérifiant que le dépôt figure bien dans son périmètre). Le travail est committé
  localement sur la branche `feat/tracabilite-et-configuration`.
- **Le tag d'image Superset est `latest`**, donc mouvant (ADR-0003) : un `docker compose
  pull` peut changer la version sous les pieds de l'équipe. Épingler serait plus sûr.
