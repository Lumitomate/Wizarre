extends Node2D

var known_controllers:Array[int] = []
var sorcerer_scene: PackedScene = preload("res://scenes/sorcerer.tscn")
var player_info_scene: PackedScene = preload("res://scenes/players_info.tscn")


func _ready() -> void:
	for controller_id in Input.get_connected_joypads():
		if not controller_id in known_controllers:
			add_player(controller_id)
	Input.connect("joy_connection_changed", _on_joy_connection_changed)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	Input.get_connected_joypads()
	for controller_id in Input.get_connected_joypads():
		if not controller_id in known_controllers:
			add_player(controller_id)


func add_player(controller_id):
	print("Adding player: " + str(controller_id))
	known_controllers.append(controller_id)
	var ammunitions: Array[int] = [3, 3, 3]
	
	# Initialize player for controller
	var sorcerer : Sorcerer = sorcerer_scene.instantiate()
	sorcerer.controller_id = controller_id
	sorcerer.sorcerer_color = controller_id % 4
	sorcerer.ammunitions = ammunitions
	
	# Adding HUD for player
	var player_info : PlayerInfo = player_info_scene.instantiate()
	player_info.position = Vector2(0, 20) + Vector2(0, 40 * controller_id)
	player_info.set_bg_color(controller_id % 4)
	player_info.ammunitions = ammunitions
	sorcerer.ammo_changed.connect(player_info._on_ammo_changed)
	
	self.add_child(sorcerer)
	self.add_child(player_info)
