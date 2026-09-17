extends SceneTree

# Test headless : après un game over, reset_players_spells doit remettre
# les sorts de chaque joueur sur la config par défaut.

func _initialize() -> void:
	var global_info = load("res://scripts/global_info.gd").new()
	var default_spells: Dictionary = global_info.run_info["players_info"]["default"]["spells"]

	# Simulation d'une run : les joueurs ont ramassé d'autres sorts
	global_info.run_info["players_info"][0] = {
		"lives": 0,
		"energy_counts": [1, 2, 3],
		"spells": {
			0: {"attack_type": 5, "attack_tier": 2},
			1: {"attack_type": 6, "attack_tier": 1},
			2: {"attack_type": 7, "attack_tier": 0},
		}
	}
	global_info.run_info["players_info"][1] = {
		"lives": 2,
		"energy_counts": [0, 0, 0],
		"spells": {
			0: {"attack_type": 8, "attack_tier": 1},
			1: {"attack_type": 9, "attack_tier": 3},
			2: {"attack_type": 10, "attack_tier": 2},
		}
	}

	global_info.reset_players_spells()

	var ok := true
	for id in [0, 1]:
		var spells: Dictionary = global_info.run_info["players_info"][id]["spells"]
		for tube in [0, 1, 2]:
			var got: Dictionary = spells[tube]
			var want: Dictionary = default_spells[tube]
			if got["attack_type"] != want["attack_type"] or got["attack_tier"] != want["attack_tier"]:
				print("TEST ÉCHOUÉ: joueur %d tube %d : %s au lieu de %s" % [id, tube, got, want])
				ok = false
	# Le "default" ne doit pas avoir été altéré
	if global_info.run_info["players_info"]["default"]["spells"] != default_spells:
		print("TEST ÉCHOUÉ: l'entrée default a été modifiée")
		ok = false
	# L'énergie de la run perdue reste en l'état (non demandé de la resetter)
	if global_info.run_info["players_info"][0]["energy_counts"] != [1, 2, 3]:
		print("TEST ÉCHOUÉ: energy_counts ne devrait pas avoir changé")
		ok = false

	if ok:
		print("TEST: TOUS LES TESTS PASSENT")
		quit(0)
	else:
		quit(1)
