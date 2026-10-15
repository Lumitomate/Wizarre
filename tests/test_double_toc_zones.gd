extends Node
## Régression « double-coup dans la colonne de feu / le rayon de lumière »
## (règle validée : être dans une zone du type protège d'un nouveau coup
## du même type ; sortir de toutes les zones lève la protection ;
## isolation par type d'attaque). Les coups sont observés via les VIES du
## sorcier (le vrai contrat). Lancé comme scène :
## godot --headless res://tests/test_double_toc_zones.tscn

var step := 0
var sorcier: Sorcerer
var colonne1: AttackFireColumn
var colonne2: AttackFireColumn
var rayon1: AttackLightRay
var rayon2: AttackLightRay


func _ready() -> void:
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)
	sorcier.global_position = Vector2(300, 300)
	sorcier.can_take_damage = true
	var colonne_scene: PackedScene = load("res://scenes/atk/atk_f1_fire_column.tscn")
	colonne1 = colonne_scene.instantiate()
	colonne2 = colonne_scene.instantiate()
	add_child(colonne1)
	add_child(colonne2)
	colonne1.global_position = Vector2(300, 300)  # sur le joueur
	colonne2.global_position = Vector2(364, 300)  # 64 px plus loin (chaîne)
	var ray_scene: PackedScene = load("res://scenes/atk/atk_l1_light_ray.tscn")
	rayon1 = ray_scene.instantiate()
	rayon2 = ray_scene.instantiate()
	add_child(rayon1)
	add_child(rayon2)
	rayon1.global_position = Vector2(300, 300)
	rayon2.global_position = Vector2(364, 300)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Premier contact : le toc passe (lives 3 -> 2)
		print("1er contact autorisé: ",
			colonne1.can_damage(sorcier) and sorcier.lives == 3, " (true attendu)")
		colonne1._on_body_entered(sorcier)
		print("vies après 1er contact: ", sorcier.lives == 2, " (2 attendu)")
	if step == 5:
		# La 2e colonne de la chaîne chevauche le joueur : TOC BLOQUÉ
		var avant: bool = colonne2.can_damage(sorcier)
		colonne2._on_body_entered(sorcier)
		print("2e colonne: autorisé= ", avant, " (false attendu)")
		print("vies inchangées (pas de 2e toc): ", sorcier.lives == 2, " (2 attendu)")
	if step == 7:
		# Quitter la colonne 1 en restant dans la 2 : toujours protégé
		colonne1._on_body_exited(sorcier)
		print("toujours dans le feu (colonne 2): autorisé= ",
			colonne2.can_damage(sorcier), " (false attendu)")
	if step == 9:
		# Quitter la dernière colonne : protection levée, re-toc possible
		colonne2._on_body_exited(sorcier)
		print("sortie de tout le feu: autorisé= ",
			colonne2.can_damage(sorcier), " (true attendu)")
	if step == 11:
		# Isolation par type : un rayon L1 n'est pas bloqué par le feu
		var avant_r1: bool = rayon1.can_damage(sorcier)
		rayon1._on_body_entered(sorcier)
		print("rayon L1 touche malgré le feu: ", avant_r1, " (true attendu)")
	if step == 13:
		# 2e rayon L1 chevauchant : bloqué (règle propre à la lumière)
		var avant_r2: bool = rayon2.can_damage(sorcier)
		rayon2._on_body_entered(sorcier)
		print("2e rayon L1: autorisé= ", avant_r2, " (false attendu)")
	if step == 15:
		# Sortie des deux rayons : protection lumière levée
		rayon1._on_body_exited(sorcier)
		rayon2._on_body_exited(sorcier)
		print("sortie de la lumière: autorisé= ",
			rayon1.can_damage(sorcier), " (true attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
