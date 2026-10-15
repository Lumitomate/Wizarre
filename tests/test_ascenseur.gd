extends Node
## Test headless de la machine à états de l'ascenseur de la homepage :
## départ à la jauge pleine (front montant), descente → délai de grâce →
## remontée si personne n'est parti, et anti-boucle (tout le monde resté
## à bord ne relance PAS instantanément). Lancé comme scène :
## godot --headless res://tests/test_ascenseur.tscn

var step := 0
var ascenseur: Node2D
var sorcier: Sorcerer


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/niveaux/terrain1/map1_elevator.tscn")
	ascenseur = scene.instantiate()
	add_child(ascenseur)
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)
	# Simule une manette connectée : en headless, aucune manette n'est
	# branchée, donc get_frame_to_reach() renverrait toujours 0 et la
	# jauge ne pourrait pas se remplir (cf. test_shop_intro_routing)
	PlayerManager.known_controllers.assign([0])


func etat() -> String:
	return str(ascenseur._etat)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Un joueur monte à bord : cible de jauge = 76 (seul joueur)
		ascenseur._on_area_2d_body_entered(sorcier)
		print(">>> joueur embarque (1/1 connecté)")
	if step == 5:
		# Jauge visuellement remplie : le front montant arme le départ
		ascenseur.animated_sprite_2D.frame = ascenseur.NUMBER_OF_FRAME_ELEVATOR
		ascenseur._on_animated_sprite_2d_frame_changed()
		print("descente lancée: ", etat() == "1", " (DESCENTE attendu)")
	if step == 7:
		# Descente physique terminée → délai de grâce démarré
		ascenseur._on_mouvement_termine(&"ascenseur_mouv_descente")
		var timer: Timer = ascenseur.get_node("AnimatableBody2D/Timer")
		print("en bas, délai de grâce: ", etat() == "2",
			" | timer démarré: ", not timer.is_stopped(),
			" | durée: ", timer.wait_time, " (1.5 attendu)")
	if step == 9:
		# Personne n'a traversé la zone → remontée
		ascenseur._on_delai_grace_timeout()
		var sprite: AnimatedSprite2D = ascenseur.animated_sprite_2D
		var anim_player: AnimationPlayer = ascenseur.get_node("AnimatableBody2D/AnimationPlayer")
		print("remontée lancée: ", etat() == "3", " (REMONTEE attendu)")
		print("sprite en lecture: ", sprite.is_playing(),
			" | mouvement en lecture: ", anim_player.is_playing())
	if step == 11:
		# Remontée terminée → retour à l'état normal
		ascenseur._on_mouvement_termine(&"ascenseur_mouv_descente")
		print("retour à l'état normal: ", etat() == "0", " (EN_HAUT attendu)")
	if step == 13:
		# ANTI-BOUCLE : le joueur est toujours à bord (jauge cible pleine)
		# → PAS de redépart instantané au sommet
		ascenseur.animated_sprite_2D.frame = ascenseur.NUMBER_OF_FRAME_ELEVATOR
		ascenseur._on_animated_sprite_2d_frame_changed()
		print("anti-boucle (joueur resté à bord, pas de redépart): ",
			etat() == "0", " (EN_HAUT attendu, pas DESCENTE)")
	if step == 15:
		# Le joueur sort puis re-rentre : front montant → départ armé
		ascenseur._on_area_2d_body_exited(sorcier)
		ascenseur._on_area_2d_body_entered(sorcier)
		ascenseur.animated_sprite_2D.frame = ascenseur.NUMBER_OF_FRAME_ELEVATOR
		ascenseur._on_animated_sprite_2d_frame_changed()
		print("redépart après sortie/re-entrée: ", etat() == "1", " (DESCENTE attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
