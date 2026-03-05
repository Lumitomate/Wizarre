extends Node2D

var known_controllers:Array[int] = []
var sorcerer_scene: PackedScene = preload("res://scenes/sorcerer.tscn")


func _ready() -> void:
	for controller_id in Input.get_connected_joypads():
		if not controller_id in known_controllers:
			add_player(controller_id)
	#Input.connect("joy_connection_changed", _on_joy_connection_changed)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	Input.get_connected_joypads()
	for controller_id in Input.get_connected_joypads():
		if not controller_id in known_controllers:
			add_player(controller_id)


func add_player(controller_id):
	print("Adding player: " + str(controller_id))
	known_controllers.append(controller_id)
	var ammunitions: Array[int] = [0, 0, 0]
	var lives: int = 3
	
	# Initialize player for controller
	var sorcerer : Sorcerer = sorcerer_scene.instantiate()
	sorcerer.controller_id = controller_id
	sorcerer.sorcerer_color = controller_id % 4
	sorcerer.ammunitions = ammunitions
	sorcerer.can_fire = false
	sorcerer.lives = lives
	
	self.add_child(sorcerer)
