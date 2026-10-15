extends Node
## Régression : les attaques qui s'encrent sur le sol (graines P1 et P3)
## traversaient le sol de l'ascenseur — la plateforme (AnimatableBody2D)
## n'était que sur le calque 1 alors que les graines ne détectent que le
## calque 8 (tuiles). Correctif : plateforme sur les calques 1 + 8.
## Lancé comme scène : godot --headless res://tests/test_graine_ascenseur.tscn

var step := 0
var ascenseur: Node2D
var graine_p1: AttackCarnivorousSeed
var graine_p3: Node2D


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/niveaux/terrain1/map1_elevator.tscn")
	ascenseur = scene.instantiate()
	add_child(ascenseur)
	var p1_scene: PackedScene = load("res://scenes/atk/atk_p1_carnivorous_seed.tscn")
	graine_p1 = p1_scene.instantiate()
	graine_p1.freeze = true
	graine_p1.caster = null
	add_child(graine_p1)
	var p3_scene: PackedScene = load("res://scenes/atk/atk_p3_plant_bramble.tscn")
	graine_p3 = p3_scene.instantiate()
	graine_p3.freeze = true
	add_child(graine_p3)
	# Le calque du corps de la plateforme est bien 1 + 8
	var corps: AnimatableBody2D = ascenseur.get_node("AnimatableBody2D")
	print("calque plateforme (1+8=9 attendu): ", corps.collision_layer)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Pose une graine de chaque type, reposant exactement sur le
		# sommet du Sol de la plateforme (Sol : 185,5 x 32 à y = +72
		# local → sommet à +56)
		var corps: AnimatableBody2D = ascenseur.get_node("AnimatableBody2D")
		var sommet_sol: float = corps.global_position.y + 56.0
		for paire in [[graine_p1, "P1", "CollisionShape2D"], [graine_p3, "P3", "SeedCollision"]]:
			var graine = paire[0]
			var forme: CollisionShape2D = graine.get_node(paire[2])
			var demi_hauteur: float = (forme.shape.height / 2.0) * forme.scale.y
			graine.global_position = Vector2(corps.global_position.x, sommet_sol - demi_hauteur)
		print(">>> graines posées sur le sol de la plateforme")
	if step == 6:
		# Les rayons de sol des graines (masque 8) doivent voir la
		# plateforme : _is_on_ground() = true pour les deux
		print("graine P1 repose sur la plateforme: ", graine_p1._is_on_ground(), " (true attendu)")
		print("graine P3 repose sur la plateforme: ", graine_p3._is_on_ground(), " (true attendu)")
	if step == 8:
		# Contre-épreuve : au-dessus du vide (hors plateforme), aucun sol
		var corps: AnimatableBody2D = ascenseur.get_node("AnimatableBody2D")
		var sommet_sol: float = corps.global_position.y + 56.0
		var forme: CollisionShape2D = graine_p1.get_node("CollisionShape2D")
		var demi_hauteur: float = (forme.shape.height / 2.0) * forme.scale.y
		graine_p1.global_position = Vector2(corps.global_position.x + 300.0, sommet_sol - demi_hauteur)
	if step == 10:
		print("hors plateforme (vide): P1 ne détecte pas de sol: ",
			not graine_p1._is_on_ground(), " (true attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
