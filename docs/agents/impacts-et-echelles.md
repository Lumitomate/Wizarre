# Impacts, dégâts et échelles — ce que la navigation ne montre pas

Reference pour toute retouche du pipeline de dégâts, des effets visuels
(impact, mort), ou des sprites affectés par l'échelle. Le glossaire métier
est dans `CONTEXT.md` ; ici, ce sont les faits d'architecture que ni la
structure des fichiers ni le glossaire ne révèlent.

## Le contrat `hit()` — point d'entrée unique de « une attaque touche »

`EnemyFlying.hit(damage, attacker, origin, attack_type)` est LE choke point :
les 13 attaques y passent, et c'est là que vivent le feedback de hit (flash,
knockback), l'explosion d'impact (`ImpactExplosion.spawn`), puis le `die()`
si `lives` tombe à 0. Toute nouvelle attaque doit y passer — ne jamais
appeler `die()` directement depuis une attaque.

Sémantique des paramètres :

- `origin` : le **nœud qui porte le coup** — idéalement le nœud de
  l'attaque, mais un SOUS-NŒUD est accepté : la recherche inverse dans
  `AttackSpawner.REGISTRE` (type → script) **remonte la hiérarchie des
  parents** jusqu'à trouver un script d'attaque (ex : un tronçon de ronce
  `AttackPlantBrambleSegment`, absent du REGISTRE, résout via son parent
  `AttackPlantBramble`). L'origine sert aussi à la direction d'éclatement
  à la mort. Une origine sans ancêtre d'attaque retombe sur la rampe de
  repli (feu).
- `attack_type` : secours explicite pour les attaquants dont `origin` n'est
  pas le nœud d'attaque. Deux court-circuits connus, à ne pas généraliser :
  - `atk_g3_blade.gd` passe **le joueur** comme origin (les lames gravitent
    autour de lui) → il passe `attack_type` explicitement ;
  - `atk_p1_carnivorous_head.gd` **mange sa proie d'un coup** : il appelle
    `die()` directement (jamais `hit()`) → l'explosion d'impact est spawnée
    explicitement dans la morsure fatale, avec la couleur P1.
- `attack_type = -1` (défaut) : rampe de repli = feu (la rampe de référence
  des sprites d'explosion).

L'explosion d'impact ne se déclenche QUE quand les dégâts sont réellement
appliqués (bloc `if can_take_damage:`) : un contact sans dégâts (cooldown,
graine) ne produit rien.

## Effets attachés à un ennemi : où, dans quel espace

- Effets spawnés dans `hit()`/`die()` → ajoutés à **`get_parent()` de
  l'ennemi** (le Level), en **coordonnées locales de l'ennemi** — comme
  `EnemyDeathBurst` et `ImpactExplosion`. Ne PAS attacher l'effet à
  l'ennemi lui-même : il bouge (knockback) et disparaît (`queue_free`).
- Le `damage_label` est l'exception à connaître : `top_level = true`, donc
  en coordonnées **globales**, d'où son `level_scale * (position - offset)`.

## Échelles : les trois chiffres qui coexistent

1. **`level_scale`** : lu depuis `get_parent().transform.get_scale()`
   (l'échelle du Level, ex : 0,7). Les attaques la reçoivent via
   `AttackSpawner.spawn_attack(..., level_scale, ...)` et l'appliquent
   elles-mêmes (`apply_level_scale`) — le spawner ne multiplie rien.
2. **L'échelle cuite dans les scènes d'ennemis** : la racine de
   `enemy_flying.tscn` porte `scale = (2,2)`. Un ennemi se rend donc à
   `2 × level_scale`. Un effet « à l'échelle du monstre » porte le même
   facteur sur sa racine ; `ImpactExplosion` fait volontairement plus petit
   (1,25, cf. `ECHELLE_RACINE`).
3. **Le rendu final** : `gl_compatibility` (choix web) — chaque
   matériau/shader est compilé par le GPU à sa première apparition à
   l'écran, sans précompilation possible. L'écran-titre fait tourner
   `WarmupRendu` (cf. `scripts/warmup_rendu.gd`) : toute nouvelle attaque
   ou effet doit y être ajouté s'il introduit un matériau que le gameplay
   n'a jamais affiché avant.

## Vérifier ses changements

Headless : `docs/agents/checks.md`. Rendu réel (indispensable pour un
shader) : captures via les scènes `_check_*_render` — cf. la section
« Vérifications visuelles » du même fichier. Standards de revue :
`CODING_STANDARDS.md` (règles 2 et 3 concernent directement ce pipeline).
