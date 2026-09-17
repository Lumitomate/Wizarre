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
					"attack_type" : GlobalEnum.AttackType.L1,
					"attack_tier" : 0
				},
				1: {  # Tube 2 → Pure : G3 = IceBlade tier III
					"attack_type" : GlobalEnum.AttackType.P2,
					"attack_tier" : 2
				},
				2: {  # Tube 3 → Tainted : L1 = LightRay tier I
					"attack_type" : GlobalEnum.AttackType.P1,
					"attack_tier" : 0
				},
			}
		}
	}
}


# Game over (retour à l'écran home après mort de tous les joueurs) : les
# sorts de la run perdue ne doivent pas se retrouver sur la run suivante
# (load_data relit players_info à chaque spawn). On remet les sorts de
# chaque joueur sur la configuration de départ ("default").
func reset_players_spells() -> void:
	var default_spells: Dictionary = run_info["players_info"]["default"]["spells"].duplicate(true)
	for controller_id in run_info["players_info"].keys():
		# Les joueurs sont indexés par des ints ; "default" est la seule
		# clé String (et un int == String plante en GDScript)
		if not (controller_id is int):
			continue
		run_info["players_info"][controller_id]["spells"] = default_spells.duplicate(true)
