# Ticket 008 — Runbook : récupérer un travail perdu (modif écrasée)

## Statut : ready-for-agent

## Priorité : moyenne

## Contexte

La récupération de la modification perdue du shop course 4 joueurs a
coûté ~6 tours d'outils d'enquête forensique, à reconstituer de zéro.
Faits découverts en chemin, qu'aucun document ne retenait :

- les **`.bak` laissés par les agents** à côté des scènes sont la trace
  la plus fiable (jamais commités, donc invisibles à `git log` — les
  comparer avec `git hash-object` + `git log --all --find-object`) ;
- les **stash supprimés** réapparaissent comme commits orphelins
  (« On main: ... ») dans `git fsck --lost-found` ;
- les stash actifs ont des noms obscurs (`git stash show -p
  'stash@{N}' --name-only` pour les trier) ;
- **Godot ne garde AUCUNE sauvegarde** de scripts/scènes en dehors du
  disque (`.godot/` ne contient que caches d'éditeur) ;
- le `git status` complet noie le contexte dans ~400 lignes d'assets
  non suivis : préférer `git status --short -uno` ou des chemins ciblés.

## Changement proposé

Créer `docs/agents/recuperation-perdue.md` : l'ordre de recherche des
traces (1. `.bak` et fichiers non suivis à côté des cibles → 2. stashes
actifs → 3. commits orphelins `git fsck` → 4. blobs fantômes), ce qui ne
sert à rien (pas de backups Godot), et les commandes prêtes à copier.

Ajouter un pointeur dans `CLAUDE.md` (section Agent skills), front-loadé :

> ### Travail perdu
> Modif écrasée ou fichiers restaurés par erreur : lire
> `docs/agents/recuperation-perdue.md` avant toute récupération.

Une ligne : le contenu vit dans le doc, pas dans CLAUDE.md.

## Critères d'acceptation

- `docs/agents/recuperation-perdue.md` existe, avec l'ordre de recherche
  et les commandes exactes utilisées dans la session du 14/11.
- `CLAUDE.md` contient le pointeur (une ligne, pas plus).
