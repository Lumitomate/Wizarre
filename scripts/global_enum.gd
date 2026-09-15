class_name GlobalEnum

enum AttackType {
	F0,  # Fireball    (boule de feu)    - atk_f0_fireball
	L1,  # LightRay    (rayon de lumière) - atk_l1_light_ray
	F1,  # FireColumn  (colonne de feu)   - atk_f1_fire_column
	G1,  # IceBall     (boule de glace)   - atk_g1_ice_ball
	P1,  # Carnivorous (plante carnivore) - atk_p1_carnivorous
	P2,  # PlantBall   (boule de plante)  - atk_p2_explo
	F2,  # FireWave    (vague de feu)     - atk_f2_wave
	G2,  # IceSpike    (pique de glace)   - atk_g2_ice_spike
	G3,  # IceBlade    (lame de glace)    - atk_g3_blade
	F3,  # FireMine    (mine de feu)      - atk_f3_mine
	L2,  # LightTarget (cible lumineuse)  - atk_l2_light_target
	L3,  # LightBow    (arc lumineux)     - atk_l3_light_bow
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

enum AttackFamily {
	Red,
	Blue,
	Yellow,
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
	SHOP
}
