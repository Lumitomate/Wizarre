extends Node
## Régression du bug P1 « dash sur la tête : pas de dégâts mais la tête
## est mangée quand même ». L'exploit : le dash coupe les collisions de
## CORPS mais pas la détection de ZONE (Area2D) — le joueur déclenchait
## la poursuite, la tête mordait dans le fantôme (hit() bloqué par
## can_take_damage) et SE CONSOMMAIT. Correctif : cible invincible =
## jamais ciblée, jamais poursuivie, jamais consommée. Lancé comme
## scène : godot --headless res://tests/test_p1_dash.tscn

var step := 0
var sorcier: Sorcerer
var plante: AttackCarnivorousSeed
var tete: CarnivorousHead


func _ready() -> void:
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)
	sorcier.global_position = Vector2(300, 300)
	var seed_scene: PackedScene = load("res://scenes/atk/atk_p1_carnivorous_seed.tscn")
	plante = seed_scene.instantiate()
	plante.attack_tier = 2
	plante.caster = sorcier
	add_child(plante)
	plante.global_position = Vector2(400, 300)
	plante.freeze = true
	plante._plant()
	plante.base_plante.animation_finished.emit()
	tete = plante.heads[0]
	PlayerManager.known_controllers.assign([0])


func tete_vivante() -> bool:
	return is_instance_valid(tete) and tete.is_inside_tree()


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Acquisition BLOQUÉE : le joueur est invincible (dash)
		sorcier.can_take_damage = false
		tete._on_area_2d_body_entered(sorcier)
		print("acquisition refusée (invincible): ", tete.target_enemy == null, " (true attendu)")
	if step == 5:
		# Acquisition OK : le joueur redevenu touchable
		sorcier.can_take_damage = true
		tete._on_area_2d_body_entered(sorcier)
		print("acquisition acceptée (touchable): ", tete.target_enemy == sorcier, " (true attendu)")
	if step == 7:
		# Poursuite : le joueur dash en cours de course → décrochage
		sorcier.can_take_damage = false
		tete._chase_enemy(0.016)
		print("décrochage pendant la poursuite: ", tete.target_enemy == null, " (true attendu)")
		print("tête toujours vivante (pas consommée): ", tete_vivante(), " (true attendu)")
	if step == 9:
		# MORSURE RATÉE : cible acquise puis dash avant la frame de morsure
		sorcier.can_take_damage = true
		tete.target_enemy = sorcier
		tete._start_eating()
		sorcier.can_take_damage = false
		tete.head.frame = tete.bite_kill_frame
		tete.head.frame_changed.emit()
		print("--- état au toc (morsure ratée) ---")
		print("morsure déclenchée (marker): ", tete.bite_triggered, " (true attendu)")
		print("cible libérée au toc: ", tete.target_enemy == null, " (true attendu)")
		print("aucun dégât (dash = esquive): ", sorcier.lives == 3, " (true attendu)")
		print("retour à idle immédiat (anim coupée): ", tete.head.animation == "atk_p1_idle"
			and not tete.is_eating, " (true attendu)")
	if step == 12:
		# La tête reste disponible ET le signal frame_changed a bien été
		# déconnecté (pas de double gestion à la morsure suivante)
		print("tête vivante et non retractée après raté: ",
			tete_vivante() and not tete.is_retracting, " (true attendu)")
	if step == 14:
		# MORSURE RÉUSSIE : cible touchable au toc → dégâts + consommation
		sorcier.can_take_damage = true
		tete.target_enemy = sorcier
		tete._start_eating()
		tete.head.frame = tete.bite_kill_frame
		tete.head.frame_changed.emit()
		print("--- morsure réussie ---")
		print("dégâts infligés: ", sorcier.lives == 2, " (2 attendu, true)")
	if step == 120:
		# Fin réelle de l'anim de morsure → consommation : la tête se
		# rétracte puis se libère (elle a pu être déjà freed à ce stade)
		print("tête consommée (rétractée puis libérée): ",
			not is_instance_valid(tete) or not tete.is_inside_tree() or tete.is_retracting,
			" (true attendu)")
	if step == 122:
		# Coordination : l'autre tête ne peut pas cibler le même joueur
		var autre: CarnivorousHead = plante.heads[1]
		var garde: bool = plante.is_closest_head_for_enemy(autre, sorcier)
		print("garde une proie/une tête (joueurs inclus): ", garde == false,
			" (false attendu: la tête 0 est plus proche)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
