extends SceneTree

# Test headless : après un game over, reset_run doit tout remettre à zéro —
# niveau de vague, durée de run, et suppression des entrées par manette
# (vies, énergies, sorts) pour que le prochain spawn retombe sur "default".

func _initialize() -> void:
	var failures := 0
	var global_info = load("res://scripts/global_info.gd").new()

	# Simulation d'une run avancée : vague 4, durée 90 s, deux manettes
	# avec des sorts/vies/énergies personnalisés
	global_info.run_info["level_number"] = 4
	global_info.run_info["run_duration"] = 90_000
	global_info.run_info["players_info"][0] = {
		"lives": 0,
		"energy_counts": [1, 2, 3],
		"spells": {0: {"attack_type": 5, "attack_tier": 2}}
	}
	global_info.run_info["players_info"][1] = {
		"lives": 2,
		"energy_counts": [0, 0, 0],
		"spells": {0: {"attack_type": 8, "attack_tier": 1}}
	}

	global_info.reset_run()

	if global_info.run_info["level_number"] == 0:
		print("OK: level_number remis à 0")
	else:
		print("FAIL: level_number = %s" % global_info.run_info["level_number"])
		failures += 1

	if global_info.run_info["run_duration"] == 0:
		print("OK: run_duration remise à 0")
	else:
		print("FAIL: run_duration = %s" % global_info.run_info["run_duration"])
		failures += 1

	# Plus aucune entrée par manette : load_data retombera sur "default"
	for key in global_info.run_info["players_info"].keys():
		if key is int:
			print("FAIL: entrée manette %s encore présente" % key)
			failures += 1
	print("OK: entrées par manette supprimées (fallback sur default)")

	# La config "default" est intacte
	var default_lives: int = global_info.run_info["players_info"]["default"]["lives"]
	if default_lives == 3:
		print("OK: config default intacte (lives = 3)")
	else:
		print("FAIL: default lives = %s" % default_lives)
		failures += 1

	if failures == 0:
		print("RESULT: PASS")
		quit(0)
	else:
		print("RESULT: FAIL (%d)" % failures)
		quit(1)