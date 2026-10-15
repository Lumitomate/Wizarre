extends Node
## Test du routage de la première salle : teleport destination_finale()
## retourne le magasin intro 2 joueurs à ≤2 joueurs, et le magasin intro
## 3-4 joueurs à partir de 3. Lancé :
## godot --headless res://tests/test_shop_intro_routing.tscn

func _ready() -> void:
	var zone_scene: PackedScene = load("res://scenes/teleport_zone.tscn")
	var holder := Node2D.new()
	add_child(holder)
	# Le nombre de joueurs est lu via PlayerManager.active_player_ids()
	# (= known_controllers tant que game_active est faux, cf.
	# player_manager.gd) : on simule 2, 3 puis 4 manettes en headless.
	var zone: Area2D = zone_scene.instantiate()
	zone.destination = GlobalEnum.Location.LEVEL
	holder.add_child(zone)
	print("0 joueur → ", zone.destination_finale(), " (SHOP_2PLAYERS_INTRO=7 attendu)")
	PlayerManager.known_controllers.assign([0, 1])
	print("2 joueurs → ", zone.destination_finale(), " (SHOP_2PLAYERS_INTRO=7 attendu)")
	PlayerManager.known_controllers.assign([0, 1, 2])
	print("3 joueurs → ", zone.destination_finale(), " (SHOP_4PLAYERS_INTRO=8 attendu)")
	PlayerManager.known_controllers.assign([0, 1, 2, 3])
	print("4 joueurs → ", zone.destination_finale(), " (SHOP_4PLAYERS_INTRO=8 attendu)")
	print("=== TEST TERMINÉ ===")
	get_tree().quit()
