extends Node

var current_scene = null
var number_of_players = null

var scenes = {
	GlobalEnum.Location.HOMEPAGE: "res://scenes/niveaux/terrain1/homepage.tscn",
	GlobalEnum.Location.LEVEL: "res://scenes/niveaux/terrain1/level.tscn",
	GlobalEnum.Location.SHOP: "res://scenes/niveaux/magasin/shop.tscn"
}

func _ready() -> void:
	var root = get_tree().root
	current_scene = root.get_child(-1)

func goto_scene(scene: GlobalEnum.Location) -> void:
	PlayerManager.save_players_data()
	_deferred_goto_scene.call_deferred(scenes[scene])

func _deferred_goto_scene(path: String) -> void:
	current_scene.free()
	
	var s = ResourceLoader.load(path)
	
	current_scene = s.instantiate()
	
	get_tree().root.add_child(current_scene)
	
	get_tree().current_scene = current_scene
