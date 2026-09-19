extends Node

# Test headless de l'animation d'attaque cosmétique :
# - fire_attack() réussi -> animation attack_fire lancée
# - tir sans munitions -> pas d'animation
# - un changement d'état (saut) coupe l'animation
# - fin naturelle -> retour à l'animation de l'état courant
# - re-tir pendant l'animation -> repart de la frame 0

var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("TEST OK: " + msg)
	else:
		print("TEST ÉCHOUÉ: " + msg)
		failures += 1


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	var holder := Node2D.new()
	add_child(holder)
	# Sorts par défaut (tubes remplis), comme au spawn réel du jeu
	var default_spells: Dictionary = GlobalInfo.run_info["players_info"]["default"]["spells"].duplicate(true)
	GlobalInfo.run_info["players_info"][0] = {"lives": 3, "energy_counts": [3, 3, 3], "spells": default_spells}
	var sorcerer: Sorcerer = scene.instantiate()
	sorcerer.controller_id = 0
	sorcerer.sorcerer_color = GlobalEnum.SorcererColor.Red
	holder.add_child(sorcerer)
	await get_tree().process_frame
	var sprite: AnimatedSprite2D = sorcerer.get_node("AnimatedSprite2D")

	# 1. Tir réussi -> animation d'attaque
	sorcerer.fire_attack(0)
	check(sprite.animation == &"attack_fire" and sprite.is_playing(), "tir réussi lance attack_fire")
	check(sorcerer.is_playing_attack, "drapeau is_playing_attack actif")
	check(sprite.frame == 0, "attaque démarrée à la frame 0")

	# 2. Un changement d'état coupe l'animation (comportement réactif)
	sorcerer.set_state(GlobalEnum.State.JUMP)
	check(sprite.animation == &"jump", "saut coupe l'animation d'attaque")
	check(not sorcerer.is_playing_attack, "drapeau réarmé après interruption")

	# 3. Fin naturelle -> retour à l'animation de l'état courant
	sorcerer.set_state(GlobalEnum.State.IDLE)
	sorcerer.fire_attack(0)
	check(sprite.animation == &"attack_fire", "deuxième tir relance l'attaque")
	# on force la fin de l'animation (ce que ferait le signal)
	sorcerer._on_attack_animation_finished()
	check(sprite.animation == &"idle", "fin d'attaque -> retour à l'animation d'état (idle)")

	# 4. Tir sans munitions -> pas d'animation
	sorcerer.energy_counts[0] = 0
	var ammo_before: int = sorcerer.energy_counts[0]
	sorcerer.fire_attack(0)
	check(sorcerer.energy_counts[0] == ammo_before and not sorcerer.is_playing_attack, "tir sans munitions ne lance rien")

	# 5. L'animation attaque dure 12 frames @ 24 fps, non bouclée
	var frames := sprite.sprite_frames
	check(frames.get_frame_count("attack_fire") == 12 and not frames.get_animation_loop("attack_fire"), "attack_fire : 12 frames, sans boucle")

	print("TEST: TOUS LES TESTS PASSENT" if failures == 0 else "TEST ÉCHOUÉ")
	get_tree().quit(0 if failures == 0 else 1)
