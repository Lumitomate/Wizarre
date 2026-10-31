# Attaques — les 13 types

Les 13 attaques (cf. `GlobalEnum.AttackType`) partagent un contrat de spawn
unique : `AttackSpawner.spawn_attack(...)` résout le type dans `REGISTRE` et
appelle le `setup_spawn(...)` statique du script de l'attaque. Ce contrat est
documenté en tête de `scripts/spawner_attack.gd`.

## Sommaire

| Type | Nom | Famille | Script | Scène |
|------|-----|---------|--------|-------|
| F0 | Boule de feu | Feu | `scripts/atk_f0_fireball.gd` | `scenes/atk/atk_f0_fireball.tscn` |
| F1 | Colonne de feu | Feu | `scripts/atk_f1_fire_column.gd` | `scenes/atk/atk_f1_fire_column.tscn` |
| F2 | Vague de feu | Feu | `scripts/atk_f2_wave.gd` | `scenes/atk/atk_f2_wave.tscn` |
| F3 | Mine de feu | Feu | `scripts/atk_f3_mine.gd` | `scenes/atk/atk_f3_mine.tscn` |
| G1 | Boule de glace | Glace | `scripts/atk_g1_ice_ball.gd` | `scenes/atk/atk_g1_ice_ball.tscn` |
| G2 | Piques de glace | Glace | `scripts/atk_g2_ice_spike.gd` | `scenes/atk/atk_g2_ice_spike.tscn` |
| G3 | Lame de glace | Glace | `scripts/atk_g3_blade.gd` | `scenes/atk/atk_g3_blade.tscn` |
| L1 | Rayon de lumière | Lumière | `scripts/atk_l1_light_ray.gd` | `scenes/atk/atk_l1_light_ray.tscn` |
| L2 | Cible lumineuse | Lumière | `scripts/atk_l2_light_target.gd` | `scenes/atk/atk_l2_light_target.tscn` |
| L3 | Arc lumineux | Lumière | `scripts/atk_l3_light_bow.gd` | `scenes/atk/atk_l3_light_bow.tscn` |
| P1 | Tête carnivore | Plante | `scripts/atk_p1_carnivorous_seed.gd` | `scenes/atk/atk_p1_carnivorous_seed.tscn` |
| P2 | Boule de plante | Plante | `scripts/atk_p2_explo.gd` | `scenes/atk/atk_p2_explo.tscn` |
| P3 | Ronce dirigeable | Plante | `scripts/atk_p3_plant_bramble.gd` | `scenes/atk/atk_p3_plant_bramble.tscn` |

## Description par attaque

### Feu

- **F0 · Boule de feu** — `AttackFireBall` (`AttackProjectile`, Area2D)
  1 à 3 boules de feu partent en éventail vers la visée.
  Tier : I = 1 boule · II = 2 · III = 3.

- **F1 · Colonne de feu** — `AttackFireColumn` (`AttackProjectile`, Area2D)
  Une chaîne de colonnes de feu le long de la visée — la plus proche du
  sorcier démarre en premier puis déclenche les suivantes
  (signal `previous_pre_spawn_done`).
  Tier : largeur des colonnes (×1/3 par tier).

- **F2 · Vague de feu** — `AttackFireWave` (`AttackProjectile`, Area2D)
  Une vague de feu part devant le sorcier en grandissant.
  Tier : hauteur maximale atteinte par la vague (cf. `FRAME_HEIGHTS`).

- **F3 · Mine de feu** — `AttackFireMine` (`AttackProjectile`, Area2D)
  Mine posable — IDLE (posée au-dessus du sorcier, lévitation vers le sol)
  → FALL (au 2e appui, chute animée) → EXPLODE (au contact du sol).

### Glace

- **G1 · Boule de glace** — `AttackIceBall` (`RigidBody2D`, physique libre)
  Boule de glace physique lancée devant le sorcier (rebonds). Hors contrat
  anti double-coup d'`AttackProjectile`.
  Tier : taille ×0.50 / ×0.75 / ×1.00 et vitesse de lancement 200 / 600 / 900.

- **G2 · Piques de glace** — `AttackIceSpike` (`AttackProjectile`, Area2D)
  Un anneau de piques de glace jaillit autour du point de tir.
  Tier : I = 4 piques · II = 6 · III = 8.

- **G3 · Lame de glace** — `AttackIceBlade` (`AttackProjectile`, Area2D)
  2 lames de glace orbitant autour du lanceur (il les rase).
  Tier : réglé par `setup` (taille et durée de rotation).

### Lumière

- **L1 · Rayon de lumière** — `AttackLightRay` (`AttackProjectile`, Area2D)
  Rideau de rayons de lumière — faisceaux parallèles qui s'activent après un
  pre_spawn, détruits en fin d'anim.
  Tier : nombre de faisceaux parallèles.

- **L2 · Cible lumineuse** — `AttackLightTarget` (`AttackProjectile`, Area2D)
  Cible lumineuse posée à l'endroit du sorcier — TARGETING puis EXPLODING
  (au 2e appui).
  Tier : taille de la cible ×1 / ×4 / ×7.

- **L3 · Arc lumineux** — `AttackLightBow` (`AttackProjectile`, Area2D)
  Arc planté sur le sorcier — s'éloigner le charge (la distance arc ↔ sorcier
  règle la bande de l'arc et la puissance), le 2e appui tire les flèches du
  sorcier vers l'arc (règles détaillées dans le script ; annulation :
  `sorcerer.gd`).
  Tier : nombre de flèches — I = centre · II = extrémités · III = les 3.

### Plante

- **P1 · Tête carnivore** — `AttackCarnivorousSeed` (`RigidBody2D`, physique libre)
  Graine lancée en cloche qui plante au premier emplacement libre — une tête
  carnivore pousse puis mord la proie la plus proche (la tête vit dans
  `atk_p1_carnivorous_head.gd`).
  Tier : hauteur et nombre de têtes (`tier1/2/3_height`, `tier_spread`).

- **P2 · Boule de plante** — `AttackPlantBall` (`RigidBody2D`, physique libre)
  Boule de plante qui roule puis explose en zone. Hors contrat anti
  double-coup d'`AttackProjectile`.
  Tier : taille de l'explosion (`explosion_max_scale` via `setup_tier`).

- **P3 · Ronce dirigeable** — `AttackPlantBramble` (`RigidBody2D`, physique libre)
  Ronce pilotée au stick : une base sort du sol, puis des tiges poussent en
  parallèle (1/2/3 selon le tier), chaque tronçon dans la direction du
  précédent ±max_turn. Immobilise le lanceur pendant la croissance.
  Tier : nombre de tiges I = 1 · II = 2 · III = 3 ; budget tronçons
  TOTAL 5 / 9 / 13.

## Contrat de spawn (résumé)

Chaque script d'attaque expose :

```gdscript
static func setup_spawn(
    attack_tier: int,      # 1-based : I = 1, II = 2, III = 3
    position: Vector2,     # position du sorcier (coords locales Level)
    direction: Vector2,    # direction de visée
    screen_size: Vector2,  # taille de l'écran (attaques plein écran)
    level_scale: Vector2,  # échelle du niveau (taille des sprites)
    caster: Node2D,        # sorcier lanceur (représailles, immunité…)
) -> Array[Node]           # les nœuds à ajouter à l'arbre
```

- `setup_spawn` N'AJOUTE JAMAIS les nœuds à l'arbre (c'est à l'appelant).
- L'attaque multiplie elle-même `position` par `level_scale` si besoin.
- La direction est normalisée par l'attaque avant usage.
- Ajouter une attaque = nouveau script avec `setup_spawn` + une entrée dans
  `GlobalEnum.AttackType` + une ligne dans `REGISTRE`.

## Tests

- `tests/test_smoke_13_attaques.gd` : spawn de chaque type × chaque tier,
  validité des nœuds, survie à 2 frames physiques, registre complet.
- `tests/test_attaque_caster_libere.gd` : une attaque dont le caster est mort
  pendant son vol ne fait pas planter la machine.
- `tests/test_attack_animation.gd`, `tests/test_direction_tir.gd` : animations
  et direction de tir.
