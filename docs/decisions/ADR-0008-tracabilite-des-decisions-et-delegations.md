---
id: ADR-0008
titre: Traçabilité écrite des décisions, délégations et spécifications
statut: acceptée
date: 2026-08-27
décideur: user808 <user808@mail.com>
proposé par: user808
validation: confirmée
délégation: D-0001
remplace: —
remplacé par: —
---

## Contexte

Plusieurs développeurs travaillent sur le projet, assistés de Claude Code. Jusqu'ici
les décisions vivaient dans `CLAUDE.md` — utile, mais c'est un récit chronologique
sans attribution : on y lit *ce qui a été fait*, jamais *qui l'a décidé*. Par ailleurs
Claude reposait d'une session à l'autre des questions déjà tranchées, faute d'un
endroit où les réponses durables soient consignées.

## Options envisagées

- **Continuer dans `CLAUDE.md`** — *Pour :* un seul fichier, chargé automatiquement.
  *Contre :* pas d'attribution, pas de statut, grossit sans fin, mélange décisions et
  notes d'exploitation.
- **Un outil externe** (issues GitHub, wiki) — *Pour :* commentaires, notifications.
  *Contre :* décorrélé du code, invisible pour Claude Code, dépend d'un accès réseau.
- **ADR versionnés dans le dépôt** — *Pour :* revus avec le code, attribuables par
  git, lisibles hors ligne, format éprouvé. *Contre :* discipline à tenir.

## Décision

Une arborescence `docs/` à trois branches : `decisions/` (ADR numérotés et immuables),
`delegations/` (registre des autorisations et des directives permanentes),
`specs/` (spécifications). L'attribution utilise l'identité git, recensée dans
`docs/CONTRIBUTEURS.md`.

Deux règles portent l'essentiel de la valeur :

1. **Claude n'est jamais décideur.** Il propose ; le champ `décideur:` porte une
   personne. Une décision prise sans validation humaine porte `validation: à confirmer`
   — elle s'applique, mais reste explicitement en attente de ratification.
2. **Le registre des délégations se lit avant de poser une question**, et s'écrit dans
   la session où l'autorisation est donnée.

## Conséquences

- Les décisions antérieures ont été reconstituées depuis `CLAUDE.md` en ADR-0001 à
  ADR-0007. Celles jamais validées explicitement portent `validation: à confirmer` :
  **elles attendent une ratification**, ce n'est pas une formalité.
- `CLAUDE.md` conserve son rôle : notes d'exploitation, pièges, état de l'infra. Il
  renvoie vers `docs/decisions/` pour le *pourquoi*.
- Le skill `.claude/skills/decision-log/` outille et vérifie le respect du format ;
  sans lui, la discipline se relâche silencieusement.
