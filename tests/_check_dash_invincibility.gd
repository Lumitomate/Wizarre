extends Node

## Vérification headless du conflit de timers sur l'invincibilité du
## sorcier. Scénario du bug corrigé (b53b810) : un coup reçu juste avant
## un dash ne doit PAS lever l'invincibilité pendant le dash (le cooldown
## de dégât qui expirait réactivait la vulnérabilité en plein dash).
##
## Le test passe par l'interface du module Protection (hit(), dash_started(),
## dash_ended(), is_untouchable()) : plus de manipulation des timers ni de
## la variable can_take_damage — l'invincibilité est DÉRIVÉE des trois
## sources indépendantes, la course entre timers ne peut plus se produire.
## Lancé comme scène : godot --headless res://tests/_check_dash_invincibility.tscn


func _ready() -> void:
	var failures := 0
	# Holder Node2D : le _ready du sorcier lit le scale de son parent
	var holder := Node2D.new()
	add_child(holder)
	var sorcerer: Sorcerer = load("res://scenes/entities/players/sorcerer.tscn").instantiate()
	sorcerer.controller_id = 0
	holder.add_child(sorcerer)
	await get_tree().process_frame

	var prot: Protection = sorcerer.get_node("Protection")

	# 1. Coup réel (via la façade Sorcerer) : le cooldown de dégât démarre
	#    → intouchable pendant 0,7 s, et les vies ont décrémenté
	sorcerer.hit(1)
	var ok_hit: bool = sorcerer.is_untouchable() and sorcerer.lives == 2
	print("Coup reçu → intouchable pendant le cooldown + vies décrémentées : %s" % ok_hit)
	if not ok_hit:
		failures += 1

	# 2. Le sorcier dash : toujours intouchable, et le cooldown de dégât
	#    expire PENDANT le dash (0,7 s > 0,1 s) — l'invincibilité tient
	#    (avant : expirer réactivait can_take_damage → mort en dashant)
	prot.dash_started()
	await get_tree().create_timer(0.8).timeout
	var ok_dash: bool = sorcerer.is_untouchable()
	print("Cooldown dégât expiré pendant le dash → toujours intouchable : %s" % ok_dash)
	if not ok_dash:
		failures += 1

	# 3. Fin du dash → fenêtre post-dash (0,5 s) : toujours intouchable
	prot.dash_ended()
	var ok_post_dash: bool = sorcerer.is_untouchable()
	print("Fin de dash → fenêtre post-dash intouchable : %s" % ok_post_dash)
	if not ok_post_dash:
		failures += 1

	# 4. La fenêtre post-dash expire → vulnérable à nouveau (et la façade
	#    duck-typing des boss est cohérente)
	await get_tree().create_timer(0.6).timeout
	var ok_normal: bool = not sorcerer.is_untouchable() and sorcerer.can_take_damage
	print("Fenêtre post-dash expirée → vulnérable à nouveau : %s" % ok_normal)
	if not ok_normal:
		failures += 1

	# 5. Un coup arrive → de nouveau intouchable (cooldown), et les vies
	#    décrémentent encore
	sorcerer.hit(1)
	var ok_hit2: bool = sorcerer.is_untouchable() and sorcerer.lives == 1
	print("Deuxième coup → intouchable + vies décrémentées : %s" % ok_hit2)
	if not ok_hit2:
		failures += 1

	if failures > 0:
		print("RESULT: FAIL (%d)" % failures)
		get_tree().quit(1)
		return
	print("RESULT: PASS")
	get_tree().quit(0)
