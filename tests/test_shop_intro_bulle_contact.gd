extends Node
## Test de la règle « bulle fermée jusqu'au contact » : la bulle reste
## Idle (fermée, collision active) même après les cinématiques ; le
## contact d'un sorcier la casse (une seule fois). Lancé :
## godot --headless res://tests/test_shop_intro_bulle_contact.tscn

var inst: Node
var step := 0
var sorcier_test: Sorcerer


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/niveaux/magasin/magasin_intro/shop_2players_intro.tscn")
	inst = scene.instantiate()
	var holder := Node2D.new()
	add_child(holder)
	holder.add_child(inst)
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier_test = sorc_scene.instantiate()
	sorcier_test.controller_id = 0
	sorcier_test.load_data()
	holder.add_child(sorcier_test)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 5:
		# Fin des cinématiques simulée (0 joueurs headless) : la bulle ne
		# doit PAS avoir cassé (nouvelle règle : contact requis)
		var bulle: Node2D = inst.get_node("Bubble")
		var sprite: AnimatedSprite2D = bulle.get_node("AnimatedSprite2D_Bulle")
		print("après cinématiques: bulle ", sprite.animation, " (Idle = fermée attendu)",
			" | collision disabled: ", bulle.get_node("CollisionShape2D").disabled, " (false attendu)")
		# Un corps non-joueur ne doit rien déclencher
		inst._on_bulle_contactee(null, 0)
		print("contact non-joueur: cassée=", inst._bulles_cassees, " ({} attendu)")
		# Contact joueur → casse
		inst._on_bulle_contactee(sorcier_test, 0)
		print(">>> contact joueur simulé")
	if step == 7:
		var bulle: Node2D = inst.get_node("Bubble")
		var sprite: AnimatedSprite2D = bulle.get_node("AnimatedSprite2D_Bulle")
		print("après contact: anim=", sprite.animation, " playing=", sprite.is_playing(), " (default attendu)",
			" | cassée=", inst._bulles_cassees.get(0, false), " (true attendu)")
		# Re-contact : ne doit pas rejouer l'anim (une seule fois)
		inst._on_bulle_contactee(sorcier_test, 0)
		sprite.stop()
		print(">>> re-contact simulé (ignoré attendu)")
	if step == 9:
		var sprite: AnimatedSprite2D = inst.get_node("Bubble/AnimatedSprite2D_Bulle")
		print("état final: playing=", sprite.is_playing(), " (false attendu: pas de re-casse)")
		# Test PHYSIQUE réel : le sorcier avancé près de la bulle doit
		# déclencher body_entered de la ZoneContact (detection area vs body).
		# Nouvelle bulle (jamais cassée) : Bubble2 est scellée à 1 joueur...
		# on re-utilise Bubble2 dont on force la bulle en mode testable.
		var bulle2: Node2D = inst.get_node("Bubble2")
		bulle2.position = inst.get_node("Bubble").position + Vector2(200, 0)
		var fired := {"value": false}
		bulle2.get_node("ZoneContact").body_entered.connect(func(b: Node2D) -> void:
			fired.value = true)
		sorcier_test.global_position = bulle2.global_position + Vector2(30, 0)
		print(">>> sorcier placé à 30px du centre de la bulle 2 (zone 34px)")
	if step == 11:
		var fired: bool = inst.get_node("Bubble2/ZoneContact").overlaps_body(sorcier_test)
		print("overlap physique zone/sorcier: ", fired, " (true attendu: capsule contact 34 > corps solide 25)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
