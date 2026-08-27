# Registre des délégations et directives permanentes

Ce fichier a un but opérationnel précis : **éviter que Claude repose une question
déjà tranchée.** Il se lit avant de solliciter un développeur, et s'écrit dans la
session même où une autorisation est accordée.

Deux registres distincts :

- **Délégations (`D-XXXX`)** — ce que Claude est autorisé à **décider seul**, et
  jusqu'où. La responsabilité reste à qui délègue.
- **Directives permanentes (`DP-XXXX`)** — ce qu'un développeur a **tranché une fois
  pour toutes**. Ce ne sont pas des délégations : ce sont des réponses définitives,
  à ne plus reproposer sans raison nouvelle.

Statuts : `active` · `à confirmer` (appliquée mais jamais formulée explicitement par
un humain — à ratifier ou corriger) · `révoquée`.

> **Une délégation ne se présume pas.** L'absence d'objection n'est pas une
> autorisation : elle donne au mieux le statut `à confirmer`.

---

## Délégations

### D-0001 — Choix de l'organisation documentaire
- **Accordée par** : `user808 <user808@mail.com>`
- **Le** : 2026-08-27
- **Statut** : active
- **Portée** : définir et faire évoluer l'arborescence de traçabilité (`docs/`), ses
  formats de fichier, ses conventions de nommage et son outillage.
- **Limites** : ne couvre pas le *contenu* des décisions tracées, ni la suppression
  d'un ADR existant.
- **Source** : demande explicite — « tracer toute décision […] dans une arborescence
  de ton choix ».

### D-0002 — Mise à jour de la documentation devenue inexacte
- **Accordée par** : `user808 <user808@mail.com>`
- **Le** : 2026-08-27 (ratifiée le 2026-08-27)
- **Statut** : active
- **Portée** : corriger `README.md`, `CLAUDE.md` et les fichiers de `docs/` quand un
  changement du code les rend factuellement faux (chemin obsolète, commande qui a
  changé, variable ajoutée), sans demander à chaque fois.
- **Limites** : correction factuelle uniquement — ne couvre ni la réécriture d'une
  section, ni un changement de périmètre annoncé du projet.
- **Source** : pratique constatée sur deux sessions, puis ratifiée explicitement —
  « je ratifie […] D-0002 ».

### D-0003 — Gestion de git et du versionnement
- **Accordée par** : `user808 <user808@mail.com>`
- **Le** : 2026-08-27
- **Statut** : active
- **Portée** : décider **quand committer**, comment découper les commits, comment les
  nommer, et quelle branche créer. Ne plus demander « veux-tu que je commite ? ».
- **Contrepartie exigée** : à la fin d'une session, **un collègue doit pouvoir prendre
  la suite** — rien d'important ne reste en modifications non committées, les messages
  expliquent le pourquoi, et `docs/PASSATION.md` reflète l'état réel.
- **Limites** : ne couvre **pas** la réécriture d'historique déjà publié (`rebase`, `force-push`, `filter-repo`), ni
  la suppression de branches d'autrui, ni un commit direct sur `main`.
- **Source** : demande explicite — « Je te délègue la gestion du git et le versionning.
  A toi de voir quand commiter, sachant qu'en fin de session il faut qu'un collègue soit
  en mesure de prendre la suite. »
- **Trace** : ADR-0009.

### D-0004 — Push vers `origin`
- **Accordée par** : `user808 <user808@mail.com>`
- **Le** : 2026-08-27
- **Statut** : active
- **Portée** : pousser les branches de travail vers `origin` sans demander à chaque fois.
  Étend D-0003, qui excluait explicitement cette action sortante.
- **Limites** : ne couvre **pas** le push sur `main`, ni un `--force` / `--force-with-lease`,
  ni la publication de contenu qui n'aurait pas été relu (vérifier avant chaque push
  qu'aucun secret n'entre dans l'historique).
- **Source** : demande explicite — « Je te délègue désormais le push. »
- **Trace** : ADR-0009 (workflow git).

---

## Directives permanentes

### DP-0001 — Aucune dépendance Python installée sur la machine hôte
- **Posée par** : `user808 <user808@mail.com>`
- **Statut** : active
- **Règle** : tout code applicatif s'exécute en conteneur. Un venv hôte, même pour une
  seule dépendance, est refusé.
- **Portée** : outillage du projet. Ne pas reproposer d'installation `pip` hôte.
- **Trace** : ADR-0005.

### DP-0002 — Services tiers déployés en Docker, pas installés à la main
- **Posée par** : `user808 <user808@mail.com>`
- **Statut** : active
- **Règle** : un service tiers (Superset et ses successeurs) se déploie via Docker
  Compose, jugé plus proche d'un déploiement réaliste et réinitialisable.
- **Trace** : ADR-0002.

### DP-0003 — Secrets hors de git, mais configuration documentée
- **Posée par** : `user808 <user808@mail.com>`
- **Statut** : active
- **Règle** : aucune valeur réelle de credential dans le dépôt ; en contrepartie, la
  liste exhaustive des variables attendues et leur rôle sont versionnés
  (`.env.example`). Ne pas demander l'arbitrage entre les deux : les deux sont exigés.
- **Trace** : ADR-0007.

### DP-0004 — Documentation rédigée en français
- **Posée par** : `user808 <user808@mail.com>`
- **Statut** : active (ratifiée le 2026-08-27)
- **Règle** : `README.md`, `CLAUDE.md` et `docs/` sont en français. Les fichiers
  `SKILL.md` ont jusqu'ici un en-tête `description` en anglais (lu par Claude Code) et
  un corps en français.
- **Source** : constat sur l'ensemble des fichiers existants, puis ratifié
  explicitement — « je ratifie […] DP-0004 ».

---

## Ajouter une entrée

Quand un développeur accorde une autorisation ou tranche une question de manière
durable, Claude ajoute l'entrée **immédiatement**, avec l'identité de la personne, la
date, la portée, et surtout **les limites** — une délégation sans limite écrite sera
interprétée trop largement. Citer la formulation d'origine en `Source` quand elle est
disponible : elle vaut mieux qu'une reformulation.
