# CLAUDE.md — Wizarre

À noter : le propriétaire du projet n'est pas technique mais est fortement intéressé par le développement de ce projet. Il est donc important d'expliquer clairement les concepts, de ne pas employer de jargon excessif, et de valider les décisions avec lui quand c'est pertinent.

## À propos du projet

**Wizarre** est un **jeu vidéo 2D multijoueur local** (jusqu'à 4 joueurs sur une même machine, via les manettes ou le clavier). Le projet est développé avec le moteur de jeu **Godot 4**.

## Agent skills

### Issue tracker

Issues et pull requests sur GitHub Issues (via `gh`). Les PR externes sont incluses dans la file de triage. Voir `docs/agents/issue-tracker.md`.

### Triage labels

Étiquettes canoniques : `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. Voir `docs/agents/triage-labels.md`.

### Domain docs

Un seul contexte — `CONTEXT.md` + `docs/adr/` à la racine. Voir `docs/agents/domain.md`.

### Impacts, dégâts et échelles

Avant de toucher au pipeline de dégâts (`hit()`), à un effet visuel (spawn,
attache, échelle) ou à un shader : lire `docs/agents/impacts-et-echelles.md`.

### Checks

Lancer les tests headless, vérifier la compilation, et la règle des modes
test (jamais câblés en dur, interrupteur `WIZARDE_TEST_*`) : voir
`docs/agents/checks.md`. Avant de déclarer un changement de routage fait,
valider avec `tests/test_parcours.tscn`.

### Travail perdu

Modif écrasée ou fichiers restaurés par erreur : lire
`docs/agents/recuperation-perdue.md` avant toute récupération.