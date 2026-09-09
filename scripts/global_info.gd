extends Node

# EnergyType is defined in GlobalEnum
# Maps directly to tube index: Fossil=0 (tube 1), Pure=1 (tube 2), Tainted=2 (tube 3)

var run_info: Dictionary = {
	"level_number" : 0,
	"run_duration" : 0, # en millisecondes
	"players_info": {
		"default" : {
			"lives": 3,
			"energy_counts": [3, 3, 3],  # Fossil, Pure, Tainted
			"spells": {
				# Each tube contains one spell; the tube determines the energy type needed
				0: {  # Tube 1 → Fossil : G1 = IceBall tier I
					"attack_type" : GlobalEnum.AttackType.F3,
					"attack_tier" : 0
				},
				1: {  # Tube 2 → Pure : G3 = IceBlade tier III
					"attack_type" : GlobalEnum.AttackType.G3,
					"attack_tier" : 2
				},
				2: {  # Tube 3 → Tainted : L1 = LightRay tier I
					"attack_type" : GlobalEnum.AttackType.L1,
					"attack_tier" : 0
				},
			}
		}
	}
}
