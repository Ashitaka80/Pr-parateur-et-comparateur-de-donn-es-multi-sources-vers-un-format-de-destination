---
name: decision-log
description: Trace architectural decisions (ADR), specifications, and the delegations/standing directives the developers have granted, under docs/. Use BEFORE asking a developer a question that may already have been settled, whenever a structuring choice is made or an authorization is granted, and when the user asks who decided what, why something is built this way, or asks to record a decision, spec, or permission.
---

# Traçabilité des décisions, délégations et spécifications

Plusieurs développeurs travaillent sur ce dépôt. Une décision qui ne vit que dans
l'historique d'une conversation n'existe pas pour l'équipe. Ce skill outille
l'arborescence `docs/` — voir [`docs/README.md`](../../../docs/README.md).

## Réflexe avant de poser une question

**Lire `docs/delegations/REGISTRE.md` avant de solliciter un développeur.** Il contient :

- les **délégations** (`D-XXXX`) : ce que je suis autorisé à décider seul, et jusqu'où ;
- les **directives permanentes** (`DP-XXXX`) : ce qui a été tranché une fois pour
  toutes et ne doit pas être reproposé.

C'est la raison d'être du registre : ne pas reposer une question déjà répondue.

## Réflexe après une réponse

Dès qu'un développeur **accorde une autorisation, refuse une approche ou pose une
règle durable**, inscrire l'entrée au registre dans la même session — avec son
identité, la date, la portée, **les limites**, et la formulation d'origine en `Source`.
Une délégation sans limite écrite finit interprétée trop largement.

## Quand écrire un ADR

Dès qu'un choix contraint le travail futur, ou que revenir dessus coûterait plus
d'une heure. En cas de doute, écrire : un ADR fait quinze lignes.

```bash
.claude/skills/decision-log/trace.sh adr "Titre de la décision"
.claude/skills/decision-log/trace.sh index     # après création ou modification
.claude/skills/decision-log/trace.sh check     # lint complet
.claude/skills/decision-log/trace.sh list      # décisions, délégations, points en attente
```

Renseigner **les options écartées** autant que l'option retenue : c'est ce qui évite
de réexplorer une impasse plus tard.

## Règles d'attribution — le point qui compte

- **Claude n'est jamais `décideur`.** Il figure en `proposé par:` ; `décideur:` porte
  une personne, par son identité git, recensée dans `docs/CONTRIBUTEURS.md`.
  `trace.sh check` échoue si Claude apparaît comme décideur.
- Une décision appliquée **sans validation humaine explicite** porte
  `validation: à confirmer`. Elle s'applique, mais elle est en dette : `trace.sh list`
  l'affiche en attente de ratification. **Ne jamais mettre `confirmée` par confort** —
  c'est précisément l'information que l'équipe vient chercher ici.
- Une décision prise sous délégation porte le numéro `D-XXXX` : la responsabilité
  remonte à qui a délégué.
- **Un ADR accepté ne se modifie pas.** On en écrit un nouveau qui le remplace
  (`remplace:` / `remplacé par:`, statut `remplacée`).

## Ce que `check` vérifie

Frontmatter complet, statuts dans le vocabulaire autorisé, `id` cohérent avec le nom
de fichier, décideur non-Claude et recensé dans `CONTRIBUTEURS.md`, délégation citée
existant réellement au registre, index à jour, et décompte des points en attente de
ratification.

## Répartition avec `CLAUDE.md`

`CLAUDE.md` garde les notes d'exploitation : état de l'infra, pièges, commandes,
contournements. `docs/decisions/` porte le **pourquoi** et le **qui**. Quand un ADR
existe, `CLAUDE.md` le cite au lieu de rejouer l'argumentaire.
