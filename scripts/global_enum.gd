class_name GlobalEnum

enum AttackType {
	F0,  # Fireball    (boule de feu)    - atk_f0_fireball
	F1,  # FireColumn  (colonne de feu)   - atk_f1_fire_column
	F2,  # FireWave    (vague de feu)     - atk_f2_wave
	F3,  # FireMine    (mine de feu)      - atk_f3_mine
	G1,  # IceBall     (boule de glace)   - atk_g1_ice_ball
	G2,  # IceSpike    (pique de glace)   - atk_g2_ice_spike
	G3,  # IceBlade    (lame de glace)    - atk_g3_blade
	L1,  # LightRay    (rayon de lumière) - atk_l1_light_ray
	L2,  # LightTarget (cible lumineuse)  - atk_l2_light_target
	L3,  # LightBow    (arc lumineux)     - atk_l3_light_bow
	P1,  # Carnivorous (plante carnivore) - atk_p1_carnivorous
	P2,  # PlantBall   (boule de plante)  - atk_p2_explo
	P3,  # PlantBrush   (ronce dirigeable) - atk_p3_plant_bramble
}

enum AttackTier {
	I,
	II,
	III,
}

enum SorcererColor {
	Red,
	Green,
	Blue,
	Yellow
}

enum EnergyType {
	Fossil,
	Pure,
	Tainted
}

# Familles d'attaque des objets de boutique. Noms historiques de couleurs
# (red/blue/yellow) renommés vers les énergies correspondantes ; les
# ordinaux sont conservés (les scènes d'objets stockent des ints).
# Attention : l'ordre diffère de EnergyType. Green n'a pas de tube dédié.
enum AttackFamily {
	Fossil,
	Tainted,
	Pure,
	Green
}

enum State {
	IDLE, 
	RUN, 
	JUMP, 
	FALL,
	ATTACK
}

enum DoorType {
	TIME,
	FRIENDSHIP,
	NO_DAMAGE
}

enum Location {
	HOMEPAGE,
	LEVEL,
	SHOP,
	SHOP_2PLAYERS_REFLEX,
	SHOP_2PLAYERS_RACE,
	SHOP_4PLAYERS_RACE
}
