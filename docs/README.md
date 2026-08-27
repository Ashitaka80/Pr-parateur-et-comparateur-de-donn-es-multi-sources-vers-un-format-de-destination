# Documentation de projet — décisions, délégations, spécifications

Plusieurs développeurs travaillent sur ce dépôt, avec l'assistance de Claude Code.
Cette arborescence existe pour qu'une décision ne vive jamais uniquement dans
l'historique d'une conversation : **ce qui n'est pas écrit ici n'engage personne.**

## Où va quoi

| Dossier | Contenu | Question à laquelle il répond |
|---|---|---|
| [`decisions/`](decisions/) | ADR — une décision par fichier, numérotée, immuable | *Pourquoi c'est fait comme ça, et qui l'a décidé ?* |
| [`delegations/`](delegations/REGISTRE.md) | Délégations accordées à Claude + directives permanentes | *Claude peut-il trancher seul ? Cette question a-t-elle déjà été tranchée ?* |
| [`specs/`](specs/) | Spécifications fonctionnelles et techniques | *Qu'est-ce que ça doit faire, exactement ?* |
| [`CONTRIBUTEURS.md`](CONTRIBUTEURS.md) | Identités utilisées pour l'attribution | *Qui est « user808 » ?* |
| [`PASSATION.md`](PASSATION.md) | État réel du projet en fin de session | *Je reprends le travail, où en est-on ?* |

## Règles

1. **Toute décision structurante donne lieu à un ADR.** Structurante = elle
   contraint le travail futur, ou son annulation coûterait plus qu'une heure.
   En cas de doute, écrire l'ADR : il est court.
2. **Un ADR est attribué à une personne nommée**, jamais à « l'équipe » ni à
   « Claude » seul. Une décision prise par Claude sans validation humaine porte
   `validation: à confirmer` : elle est appliquée mais reste à ratifier.
3. **Un ADR accepté ne se modifie pas.** On le remplace par un nouvel ADR qui le
   supersède (`remplace:` / `remplacé par:`). L'historique des erreurs a autant de
   valeur que celui des réussites.
4. **Toute autorisation accordée à Claude est inscrite au registre** dans la
   session où elle est donnée — sinon la question sera reposée.

## Outillage

Le skill `.claude/skills/decision-log/` (bash pur, rien à installer) :

```bash
.claude/skills/decision-log/trace.sh adr "Titre de la décision"   # nouvel ADR pré-rempli
.claude/skills/decision-log/trace.sh spec "Titre de la spec"      # nouvelle spec
.claude/skills/decision-log/trace.sh index                        # régénère les index
.claude/skills/decision-log/trace.sh check                        # lint (frontmatter, statuts, index)
.claude/skills/decision-log/trace.sh list                         # vue d'ensemble
```
