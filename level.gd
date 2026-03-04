extends Node2D

#@export var player_spawn_position: Vector2 = Vector2(40, 40)

var known_controllers:Array[int] = []
var sorcerer_scene: PackedScene = preload("res://sorcerer.tscn")
var player_info_scene: PackedScene = preload("res://players_info.tscn")

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
	var sorcerer = sorcerer_scene.instantiate()
	sorcerer.controller_id = controller_id
	sorcerer.sorcerer_color = controller_id % 4
	
	var player_info = player_info_scene.instantiate()
	player_info.position = Vector2(0, 32 * controller_id)
	sorcerer.ammo_changed.connect(player_info._on_ammo_changed)
	
	self.add_child(sorcerer)
	self.add_child(player_info)
