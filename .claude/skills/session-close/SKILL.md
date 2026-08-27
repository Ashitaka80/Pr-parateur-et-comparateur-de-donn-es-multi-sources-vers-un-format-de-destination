---
name: session-close
description: Check that the current session can be closed without leaving a teammate stranded — runs the project's config and traceability audits, verifies docs/PASSATION.md is current, that nothing is uncommitted or unpushed, that no secret entered git history, and lists decisions still awaiting human ratification. Use when the user says they are wrapping up, closing, or ending the session, before handing work over, or when asked what remains to be done before stopping.
---

# Clôture de session

Plusieurs développeurs travaillent sur ce dépôt. La délégation **D-0003** confie la
gestion de git à Claude, avec une contrepartie explicite : **en fin de session, un
collègue doit être en mesure de prendre la suite.** Ce skill vérifie que c'est vrai.

```bash
.claude/skills/session-close/close.sh
```

Le script est **en lecture seule** : il ne commite pas, ne pousse pas, ne corrige rien.
Il dit ce qui manque ; les actions restent des décisions, prises sous D-0003 et D-0004.

## Ce qu'il vérifie

1. **Contrôles outillés** — `project-init check` et `decision-log check` au vert.
2. **Passation** — `docs/PASSATION.md` daté d'aujourd'hui. Avertit aussi si des commits
   ont été faits dans la journée sans que ce document soit touché : c'est le signe
   typique d'un travail avancé mais non transmis.
3. **État git** — branche thématique (jamais `main`, ADR-0009), arbre propre, et
   **rien qui ne soit poussé** : un commit local est invisible pour l'équipe.
4. **Secrets** — `.env` absent de l'historique git.
5. **En attente** — décisions portant `validation: à confirmer` et entrées du registre
   à confirmer, à soumettre au développeur avant de partir.

## Ordre de clôture recommandé

1. Mettre à jour `docs/PASSATION.md` : **ce qui bloque d'abord**, puis l'état, puis la
   prochaine action recommandée. Écrire ce qu'un collègue ne peut pas deviner.
2. Tracer les décisions prises pendant la session (`trace.sh adr`) et les autorisations
   accordées (`docs/delegations/REGISTRE.md`) — pas « plus tard », maintenant.
3. Committer, pousser.
4. `close.sh` — doit sortir en 0.
5. Soumettre au développeur les points en attente de ratification.

## Le piège que ce skill existe pour éviter

Une session peut se terminer avec tous les tests au vert, un dépôt propre en apparence,
et pourtant rien d'exploitable : le travail est en local, le document de passation décrit
un état vieux de trois heures, et trois décisions attendent une validation que personne ne
sait devoir donner. Rien de tout cela n'est visible sans le vérifier explicitement.
