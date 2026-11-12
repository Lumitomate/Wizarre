# Ticket 006 — Process : committer chaque jalon dès qu'il passe les tests

## Statut : ready-for-agent

## Priorité : haute

## Contexte

La migration du shop course 4 joueurs (remplacement de la bulle de verre
par la cabine) a été **perdue** le 12/11 : elle n'a jamais été commitée
et une version ancienne l'a écrasée. Rien que le hasard a préservé le
shop réflexe 4 joueurs (fichiers non suivis jamais touchés). Toute la
session de récupération (tickets 007, 008) découle de cette seule cause
racine : un travail resté hors git pendant 6 semaines.

## Changement proposé

Ajouter à la fin de `docs/agents/checks.md` une règle courte, dans
l'esprit « un jalon validé = un commit » :

> Dès qu'un jalon passe la suite complète (`tests/parallel.sh`), le
> committer — même en WIP (`wip: ...`). Le travail non commité est la
> première cause de perte : la récupération coûte une session entière.

Ne PAS dupliquer la règle dans `CLAUDE.md` : la section Checks de
CLAUDE.md pointe déjà vers `docs/agents/checks.md`.

## Critères d'acceptation

- `docs/agents/checks.md` contient la règle « jalon validé → commit ».
- Aucune duplication dans `CLAUDE.md`.
