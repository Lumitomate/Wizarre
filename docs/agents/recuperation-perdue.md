# Travail perdu — retrouver une modif écrasée

À lire AVANT toute tentative de récupération : la session du 14/11 a coûté
~6 tours d'outils d'enquête parce que ces traces n'étaient documentées
nulle part. Suivre l'ordre ci-dessous, du plus fiable au plus indirect.

Préambule : **Godot ne garde AUCUNE sauvegarde** de scripts ou scènes en
dehors du disque. `.godot/` ne contient que des caches d'éditeur — inutile
d'y chercher une version précédente.

## Ordre de recherche

### 1. Les `.bak` et fichiers non suivis à côté des cibles

Les `.bak` laissés par les agents à côté des scènes sont la trace la plus
fiable : ils ne sont **jamais commités**, donc invisibles à `git log`. Ils
existent pourtant bien sur le disque. Chercher aussi tout fichier non suivi
autour des fichiers cibles :

```sh
git status --short -uno
ls **/*.bak
```

Utiliser `git status --short -uno` plutôt que `git status` complet : le
status complet noie le contexte dans ~400 lignes d'assets non suivis. Pour
cibler un répertoire précis, donner directement le chemin :

```sh
git status --short -uno -- scenes/
```

Comparer un `.bak` avec l'historique pour savoir s'il correspond à une
version commitée (oubliée ou écrasée) :

```sh
git hash-object chemin/vers/scene.tscn.bak
git log --all --find-object=<hash>
```

Si `git log --find-object` trouve le blob, la version perdue est dans
l'historique — la retrouver avec `git show <commit>:<chemin>`. Sinon, le
`.bak` reste une copie exploitable en l'état.

### 2. Les stashes actifs

Leur libellé est souvent obscur ; lister leur contenu réel pour les trier :

```sh
git stash list
git stash show -p 'stash@{N}' --name-only
```

Vérifier les stashes UN PAR UN : le libellé ne dit pas ce qu'il y a dedans.

### 3. Les commits orphelins (stash supprimés)

Un stash supprimé (drop, reset…) réapparaît comme commit orphelin dans
`git fsck` — son message commence typiquement par « On main: ... » :

```sh
git fsck --lost-found
```

Inspecter chaque commit orphelin trouvé pour retrouver celui qui contenait
le travail perdu :

```sh
git show <hash>
```

### 4. Les blobs fantômes

En dernier recours : des blobs orphelins (contenu jamais commité, rattaché
à aucun commit) peuvent être listés et inspectés individuellement. C'est la
piste la plus longue car chaque blob doit être ouvert à la main — ne l'a
tenter qu'après les étapes 1–3.

## Ensuite

Restaurer la meilleure version trouvée, puis revalider avec la suite de
tests (voir `docs/agents/checks.md`). Et une fois le jalon redevenu
fonctionnel : le committer immédiatement — un travail non commité reste la
première cause de perte.
