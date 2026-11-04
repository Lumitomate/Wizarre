extends Node

## Vérification headless du conflit de timers sur l'invincibilité du
## sorcier. Scénario du bug corrigé : un coup reçu juste avant un dash
## ne doit PAS lever l'invincibilité pendant le dash (le DamageCooldown
## qui expirait réactivait can_take_damage → mort en dashant dans une
## colonne de feu).


func _ready() -> void:
	var failures := 0
	# Holder Node2D : le _ready du sorcier lit le scale de son parent
	var holder := Node2D.new()
	add_child(holder)
	var sorcerer: Sorcerer = load("res://scenes/entities/players/sorcerer.tscn").instantiate()
	sorcerer.controller_id = 0
	holder.add_child(sorcerer)
	await get_tree().process_frame

	# 1. Le cooldown de dégât expire PENDANT un dash : l'invincibilité tient
	sorcerer.is_dashing = true
	sorcerer.can_take_damage = false
	sorcerer._on_damage_cooldown_timeout()
	var ok_dash: bool = not sorcerer.can_take_damage
	print("Cooldown dégât expire pendant le dash → toujours intouchable : %s" % ok_dash)
	if not ok_dash:
		failures += 1

	# 2. Idem pendant la fenêtre d'invincibilité de 0,5 s après le dash
	sorcerer.is_dashing = false
	sorcerer.get_node("DashInvicibiliyAfter").start()
	sorcerer._on_damage_cooldown_timeout()
	var ok_post_dash: bool = not sorcerer.can_take_damage
	print("Cooldown dégât expire pendant la fenêtre post-dash → intouchable : %s" % ok_post_dash)
	if not ok_post_dash:
		failures += 1

	# 3. Sans protection de dash active : l'invincibilité se lève normalement
	sorcerer.get_node("DashInvicibiliyAfter").stop()
	sorcerer._on_damage_cooldown_timeout()
	var ok_normal: bool = sorcerer.can_take_damage
	print("Cooldown dégât expire sans dash → vulnérable à nouveau : %s" % ok_normal)
	if not ok_normal:
		failures += 1

	# 4. La fin de la protection du dash lève bien l'invincibilité
	sorcerer._on_dash_invicibiliy_after_timeout()
	var ok_lift: bool = sorcerer.can_take_damage
	print("Fin de la protection post-dash → vulnérable : %s" % ok_lift)
	if not ok_lift:
		failures += 1

	print("Résultat : %s" % ("ÉCHEC (%d)" % failures if failures > 0 else "OK"))
	get_tree().quit(1 if failures > 0 else 0)
