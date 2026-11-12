extends Node

## Test du module Protection (source de vérité de l'invincibilité du
## sorcier). Le test passe par l'interface du module (hit(), dash_started(),
## dash_ended(), is_untouchable()) et par la façade Sorcerer (hit(),
## is_untouchable(), can_take_damage) — jamais par l'implémentation.
## Lancé comme scène : godot --headless res://tests/test_protection.tscn


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

	# 1. Sorcier frais : touchable, et la façade duck-typing des boss le dit
	var ok_frais: bool = not sorcerer.is_untouchable() and sorcerer.can_take_damage
	print("Sorcier frais → touchable (façade boss incluse) : %s" % ok_frais)
	if not ok_frais:
		failures += 1

	# 2. Dash : intouchable pendant, fenêtre post-dash intouchable après
	prot.dash_started()
	var ok_dash: bool = sorcerer.is_untouchable()
	print("Dash en cours → intouchable : %s" % ok_dash)
	if not ok_dash:
		failures += 1
	prot.dash_ended()
	var ok_post_dash: bool = sorcerer.is_untouchable()
	print("Fin de dash → fenêtre post-dash intouchable : %s" % ok_post_dash)
	if not ok_post_dash:
		failures += 1

	# 3. Intouchable (dash) → un coup ne passe PAS : vies intactes,
	#    pas de cooldown démarré
	prot.dash_started()
	sorcerer.hit(1)
	var ok_bloque: bool = sorcerer.is_untouchable() and sorcerer.lives == 3 \
		and prot._damage_cooldown.is_stopped()
	print("Coup pendant le dash → bloqué (vies intactes) : %s" % ok_bloque)
	if not ok_bloque:
		failures += 1
	prot.dash_ended()
	# La fenêtre post-dash (0,5 s) doit expirer avant le coup réel
	await get_tree().create_timer(0.6).timeout

	# 4. Coup réel → intouchable pendant le cooldown (0,7 s) + hit_taken
	#    (vies décrémentées par le Sorcerer, la mort reste chez lui)
	sorcerer.hit(1)
	var ok_coup: bool = sorcerer.is_untouchable() and sorcerer.lives == 2
	print("Coup reçu → intouchable pendant le cooldown + vies décrémentées : %s" % ok_coup)
	if not ok_coup:
		failures += 1

	# 5. Cooldown qui expire pendant le dash → l'invincibilité tient
	#    (le bug historique : expirer réactivait la vulnérabilité)
	prot.dash_started()
	await get_tree().create_timer(0.8).timeout
	var ok_course: bool = sorcerer.is_untouchable()
	print("Cooldown dégât expiré pendant le dash → toujours intouchable : %s" % ok_course)
	if not ok_course:
		failures += 1

	# 6. Fin du dash + fenêtre post-dash expirée → vulnérable à nouveau
	prot.dash_ended()
	await get_tree().create_timer(0.6).timeout
	var ok_normal: bool = not sorcerer.is_untouchable() and sorcerer.can_take_damage
	print("Fenêtre post-dash expirée → vulnérable à nouveau : %s" % ok_normal)
	if not ok_normal:
		failures += 1

	if failures > 0:
		print("RESULT: FAIL (%d)" % failures)
		get_tree().quit(1)
		return
	print("RESULT: PASS")
	get_tree().quit(0)
