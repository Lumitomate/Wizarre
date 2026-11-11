# Checks — vérifier avant de rendre la main

## Lancer les tests headless

Chaque `tests/test_*.tscn` est un test autonome : il se ferme seul avec un
code de sortie (0 = tout passe, 1 = échec d'assertion). Lancer un test :

```sh
godot --headless res://tests/test_parcours.tscn
```

Lancer toute la suite :

```sh
for t in tests/test_*.tscn; do godot --headless "$t" > /dev/null 2>&1 \
  && echo "pass $t" || echo "ÉCHEC $t"; done
```

La CI (`.github/workflows/tests.yml`) lance la même boucle à chaque push
sur main et à chaque pull request. Les scènes `_check_*.tscn` et
`_preview_*.tscn` sont des outils manuels (inspection visuelle), pas des
tests automatisés — la CI ne les lance pas.

Tout nouveau test doit se terminer par `get_tree().quit(0/1)` et imprimer
`RESULT: PASS` / `RESULT: FAIL (n)` (le nombre d'échecs), comme
`tests/test_shop_router.gd`. Un test qui se contente d'imprimer des
valeurs « attendues » sans les vérifier ne détecte aucune régression.

Pendant l'itération : lancer seulement les tests ciblés touchés par le
changement. La suite complète se lance UNE fois en fin de session — en
parallèle via `tests/parallel.sh [workers]` (4 par défaut, ~4× plus
rapide que la boucle séquentielle), ou à la main avec la boucle ci-dessus.

## Vérifications visuelles (fenêtré) — le headless ne voit pas le rendu

Les tests headless vérifient la LOGIQUE (nœuds, propriétés, matériaux)
mais ne rendent RIEN : un shader dont le fragment est faux (ex :
re-multiplication de `COLOR`, cf. `CODING_STANDARDS.md` règle 1) passe
toutes les vérifications headless et rend noir à l'écran. Toute création
ou retouche de shader / effet visuel exige donc sa vérification en rendu
réel :

1. une scène `_check_*_render.tscn` (cf. `tests/_check_shader_render.tscn`
   pour le patron minimal : sprite isolé, agrandi, sur fond sombre) qui
   capture `get_viewport().get_texture().get_image().save_png(...)` à des
   instants DONNÉS EN SECONDES (chronomètre `Time.get_ticks_msec` — les
   premières frames du rendu sont lentes, compter des frames fausse le
   timing) ;
2. lancer FENÊTRÉ (`godot res://tests/_check_X.tscn`, une fenêtre
   s'ouvre brièvement) et analyser le PNG produit (PIL/couleurs uniques)
   contre les valeurs attendues.

Exemples à copier : `_check_shader_render` (un sprite, un matériau),
`_check_kill_render` (un kill complet, timeline multi-instants).

## Vérifier qu'un script compile

```sh
godot --headless --quit
```

Charge le projet complet (autoloads inclus) et signale toute erreur de
compilation. Ne pas utiliser `godot --check-only -s <script>` : hors du
projet, les autoloads (`Global`, `GlobalInfo`, `PlayerManager`,
`ShopRouter`, `PauseManager`) sont inconnus et le script échoue à tort.

## Overrides de test : jamais câblés en dur

Un comportement modifié « le temps des tests » doit toujours passer par un
interrupteur explicite, jamais par une modification en dur du code de
routage — un override en dur oublié court-circuite silencieusement le
comportement réel des sessions suivantes (cela a déjà coûté une session
entière : l'ascenseur envoyait au boss au lieu des magasins d'intro).

Deux formes acceptées :

- **Variable d'environnement `WIZARDE_TEST_*`** pour les modes de session
  (routage, contenus de test) : inactifs par défaut, activés au lancement,
  rien ne change dans le dépôt. Exemple : `WIZARDE_TEST_BOSS=1` envoie
  l'ascenseur directement à la salle du boss avec des attaques aléatoires
  (cf. `teleport_zone.gd` et `boss_controller.gd`).
- **`@export` désactivé par défaut** pour les réglages d'inspecteur.
  Exemple : `ShopRouter.forcer_magasin` / `magasin_force`.

À la fin d'une session qui a mis en place un mode test : vérifier que le
jeu se comporte normalement SANS variable d'environnement (lancer
`godot --headless res://tests/test_parcours.tscn`, qui teste les deux).
