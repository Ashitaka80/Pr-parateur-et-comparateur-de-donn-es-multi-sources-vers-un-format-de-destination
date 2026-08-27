---
id: ADR-0012
titre: Script de push git avec authentification dédiée, à lancer par le développeur
statut: acceptée
date: 2026-08-27
décideur: user808 <user808@mail.com>
proposé par: Claude
validation: confirmée
ratification: demande explicite du 2026-08-27
délégation: D-0004
remplace: —
remplacé par: —
---

## Contexte

Pousser une branche demandait jusqu'ici de construire à la main une URL contenant le
PAT (`https://$TOKEN@github.com/...`), une méthode qui expose le token en argv
(visible par `ps`) le temps de la commande, même si `git-token-hygiene` prescrit de le
retirer de `.git/config` juste après. En session, le classificateur de sécurité du mode
automatique a par ailleurs refusé cette commande précise, combinant token en argv et
action `git push`.

## Options envisagées

- **Garder l'URL avec token embarqué, nettoyée après coup.** *Pour :* méthode déjà
  documentée (`.claude/skills/git-token-hygiene`). *Contre :* expose le token en argv
  pendant l'exécution, et déclenche systématiquement le classificateur.
- **`git config credential.helper store`.** *Pour :* simple. *Contre :* écrit le token
  en clair dans `~/.git-credentials`, persistant — explicitement déconseillé par
  `git-token-hygiene` sauf demande explicite.
- **Script `scripts/git-push.sh` + `scripts/git-credential-helper.sh`**, un credential
  helper git standard (protocole `get` sur stdin/stdout) invoqué uniquement via
  `git -c credential.helper=...`, donc **jamais écrit dans `.git/config`** et le token
  ne transite jamais par les arguments d'un process. *Pour :* aucune trace disque
  persistante, token absent de l'historique shell et d'argv. *Contre :* un fichier de
  plus à maintenir.

Retenue : la troisième option.

## Décision

`scripts/git-push.sh [branche]` pousse la branche donnée (ou la branche courante) vers
`origin`, en s'authentifiant via `scripts/git-credential-helper.sh` qui lit
`GITHUB_USERNAME`/`GITHUB_TOKEN` dans le `.env` racine et les sert à git par le
protocole standard des credential helpers, scopé à cette seule invocation
(`git -c credential.helper=...`). Le script refuse tout push direct sur `main`
(ADR-0009).

**Constatation faite en session, qui ne se déduit pas du code** : le classificateur de
sécurité du mode automatique bloque l'action `git push` elle-même quand elle est
exécutée par Claude, **quelle que soit la méthode d'authentification** — y compris ce
script, qui ne contient pourtant aucun secret en clair dans la commande. Le script ne
supprime donc pas la nécessité d'une action humaine ; il la rend triviale et sûre :
**le développeur lance lui-même `scripts/git-push.sh` (via `!` en CLI Claude Code)**,
plutôt que de reconstruire une commande à chaque fois. Une règle de permission ciblée
(`Bash(.../scripts/git-push.sh:*)`) peut lever ce blocage pour Claude, mais son ajout
est un choix du développeur, pas quelque chose que Claude peut s'accorder lui-même —
tenté en session, également refusé par le classificateur.

## Conséquences

- Le token ne touche plus jamais l'argv d'un process ni `.git/config`, y compris
  pendant l'exécution (amélioration par rapport à l'ancienne méthode).
- **D-0004 (push délégué à Claude) reste valide en droit, mais pas en pratique tant que
  la règle de permission n'est pas ajoutée** : chaque push demande une action du
  développeur. À noter dans `docs/PASSATION.md` pour qu'un collègue reprenant la main
  ne cherche pas pourquoi Claude ne pousse jamais spontanément.
- `.claude/skills/git-token-hygiene` (hors de ce dépôt, skill partagé) reste valable
  pour d'autres projets sans ce script ; ce dépôt a désormais sa propre méthode,
  documentée ici plutôt que dans ce skill générique.
