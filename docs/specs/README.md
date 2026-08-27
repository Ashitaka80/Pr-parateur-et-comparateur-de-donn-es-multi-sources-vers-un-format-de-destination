# Spécifications

Une spec décrit **ce que le logiciel doit faire** ; un ADR décrit **pourquoi il est
construit ainsi**. Quand une spec impose un choix de conception structurant, elle
cite l'ADR correspondant plutôt que de le rejouer.

Nouvelle spec : `.claude/skills/decision-log/trace.sh spec "Titre"`.

<!-- INDEX:début - régénéré par trace.sh index, ne pas éditer à la main -->
_Aucun document pour l'instant._
<!-- INDEX:fin -->

## À écrire en priorité

Le cœur fonctionnel annoncé par le nom du projet — la **comparaison et la
réconciliation multi-sources** — n'est ni spécifié ni implémenté. C'est la première
spec à produire, et elle demande des arbitrages métier (règles d'appariement entre
sources, traitement des écarts, politique de dédoublonnage) qui appartiennent aux
développeurs : Claude peut instruire les options, pas trancher (voir `docs/delegations/`).
