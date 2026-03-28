extends Node2D

signal player_added(controller_id)

var known_controllers: Array[int] = []
var players = {}

var sorcerer_scene: PackedScene = preload("res://scenes/sorcerer.tscn")

func _ready():

	# joueurs déjà connectés
	for controller_id in Input.get_connected_joypads():
		if not controller_id in known_controllers:
			_add_controller(controller_id)

	# détecter nouvelles manettes
	Input.connect("joy_connection_changed", _on_joy_connection_changed)



func _on_joy_connection_changed(device: int, connected: bool):

	if connected and not device in known_controllers:
		_add_controller(device)



func _add_controller(controller_id):

	print("Controller detected: ", controller_id)

	known_controllers.append(controller_id)
	players[controller_id] = null

	player_added.emit(controller_id)



func spawn_player(parent: Node, controller_id: int):

	if players[controller_id] != null:
		return

	var player = sorcerer_scene.instantiate()

	player.controller_id = controller_id
	player.sorcerer_color = controller_id % 4

	parent.add_child(player)

	players[controller_id] = player



func spawn_all_players(parent: Node):

	for controller_id in known_controllers:
		spawn_player(parent, controller_id)
