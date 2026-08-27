---
id: ADR-0009
titre: Workflow git — branches thématiques, Conventional Commits, passation écrite
statut: acceptée
date: 2026-08-27
décideur: user808 <user808@mail.com>
proposé par: Claude
validation: confirmée
ratification: décidé sous délégation D-0003 le 2026-08-27
délégation: D-0003
remplace: —
remplacé par: —
---

## Contexte

La gestion de git a été déléguée à Claude (D-0003), avec une exigence explicite :
**en fin de session, un collègue doit pouvoir prendre la suite.** L'historique
existant compte trois commits en anglais, en phrases libres
(`Add project README`), sans convention ni périmètre affiché.

Deux risques à couvrir : du travail qui reste non committé à la fin d'une session, et
des commits dont on ne peut pas dire, six mois plus tard, ce qu'ils changeaient ni
pourquoi.

## Options envisagées

- **Commits libres directement sur `main`** — *Pour :* aucune cérémonie, cohérent avec
  l'historique existant. *Contre :* pas de point de relecture, et sur un dépôt à
  plusieurs développeurs le travail de Claude se mélange à celui des humains sans
  frontière visible.
- **Un commit unique en fin de session** — *Pour :* simple. *Contre :* si la session
  s'interrompt, tout est perdu pour le collègue ; et un gros commit fourre-tout est
  irrelisible.
- **Branche thématique + commits atomiques + Conventional Commits** — *Pour :* chaque
  commit a un périmètre et un pourquoi, l'historique est filtrable par type et par
  périmètre, `main` reste relisible. *Contre :* rompt avec le style des trois commits
  existants, et impose une discipline de découpage.

## Décision

1. **Branches thématiques.** Aucun commit direct sur `main`. Nommage
   `type/sujet-en-kebab-case` (`feat/`, `fix/`, `docs/`, `chore/`, `refactor/`).
2. **Conventional Commits**, sujet en français conformément à DP-0004 :
   `type(périmètre): sujet à l'impératif`. Corps expliquant **pourquoi**, pas quoi —
   le diff dit déjà le quoi. Référence à l'ADR quand il y en a un.
3. **Commits atomiques et au fil de l'eau**, jamais un bloc en fin de session : un
   commit = un changement cohérent, qui laisse le dépôt dans un état fonctionnel.
4. **`docs/PASSATION.md` tenu à jour** en fin de session : état réel, travail en cours,
   points bloquants, prochaine action. C'est le document que lit le collègue qui reprend.
5. **`git push` reste hors délégation** : action sortante, demandée explicitement à
   chaque fois. Idem pour toute réécriture d'historique publié.

## Conséquences

- L'historique devient hétérogène : trois commits en anglais en phrases libres, puis
  des Conventional Commits en français. Assumé — réécrire l'historique publié coûterait
  plus que le bénéfice, et la rupture est datable via cet ADR.
- Le travail de Claude arrive sur des branches, donc relisible avant intégration dans
  `main` par un développeur.
- Une session interrompue laisse malgré tout un état exploitable, puisque les commits
  sont faits en cours de route et non à la fin.
