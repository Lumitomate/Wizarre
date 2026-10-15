extends Node
## Régression du bug « téléportation » : un joueur debout SUR LE TOIT de
## l'ascenseur descendu est détecté dans la zone d'écrasement DÈS LE
## DÉBUT de la remontée (position d'anim encore en bas). Reprendre la
## lecture de l'anim terminée la faisait repartir du début : le corps
## sautait en haut de la cage. Correctif : blocage au démontée non
## entamée → pas de descente de secours, cycle normal direct. Le toit
## ne doit JAMAIS sauter, et une fois le joueur parti, la remontée doit
## se dérouler. Lancé comme scène :
## godot --headless res://tests/test_ascenseur_toit.tscn

var step := 0
var ascenseur: Node2D
var sorcier: Sorcerer
var anim_player: AnimationPlayer
var corps: AnimatableBody2D
var saut_detecte := false
var positions_vues := []


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/niveaux/terrain1/map1_elevator.tscn")
	ascenseur = scene.instantiate()
	add_child(ascenseur)
	anim_player = ascenseur.get_node("AnimatableBody2D/AnimationPlayer")
	corps = ascenseur.get_node("AnimatableBody2D")
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	add_child(sorcier)
	sorcier.global_position = Vector2(400, 400)
	PlayerManager.known_controllers.assign([0])


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		ascenseur.start_the_movement()
	if step > 3:
		# Garde-fou permanent : le corps ne doit jamais sauter pendant la
		# remontée bloquée (l'anim ne doit pas repartir du début)
		var pos := anim_player.current_animation_position
		if positions_vues.size() > 0 and pos < positions_vues.back() - 0.05 \
				and ascenseur._remontee_bloquee:
			print("!!! SAUT D'ANIMATION DÉTECTÉ à step ", step,
				" : ", positions_vues.back(), " -> ", pos)
			saut_detecte = true
			print("=== TEST ÉCHOUÉ ===")
			get_tree().quit()
			return
		if positions_vues.is_empty() or absf(pos - positions_vues.back()) > 0.001:
			positions_vues.append(pos)
	if step == 185:
		# Descente réelle terminée (3 s) → AU_BAS ; le joueur monte sur
		# le toit et y RESTE
		print("descente en fin de course: etat=", ascenseur._etat, " (1=DESCENTE, le signal de fin arrive juste après)")
		sorcier.global_position = corps.global_position + Vector2(0, -88 - 29)
	if step == 300:
		# Deux cycles grâce→remontée→blocage→AU_BAS se sont écoulés
		print("ascenseur cloué au bas (joueur sur le toit): ",
			absf(corps.global_position.y - 180.0) < 1.0, " (true attendu)")
		print("anim jamais repartie du début: ", not saut_detecte, " (true attendu)")
		print("blocage actif en cours: ", ascenseur._remontee_bloquee, " (true ou false selon le cycle)")
	if step == 450:
		# Le joueur QUITTE le toit : la prochaine tentative doit monter
		sorcier.global_position = Vector2(600, 600)
	if step == 520:
		# La remontée est en cours (l'anim recule = le corps monte)
		print("remontée après départ du joueur: ", str(ascenseur._etat) == "3",
			" (REMONTEE attendu)")
		print("corps en ascension: ", corps.global_position.y < 180.0, " (true attendu)")
		print("anim en remontée (position < 3.0): ",
			anim_player.current_animation_position < 3.0, " (true attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
