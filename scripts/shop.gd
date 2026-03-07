extends Node2D

signal save_data

var known_controllers:Array[int] = []
var sorcerer_scene: PackedScene = preload("res://scenes/sorcerer.tscn")


func _ready() -> void:
	for controller_id in Input.get_connected_joypads():
		if not controller_id in known_controllers:
			add_player(controller_id)
	$ShopDoor.play()
	print(GlobalInfo.run_info)
	#Input.connect("joy_connection_changed", _on_joy_connection_changed)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	Input.get_connected_joypads()
	for controller_id in Input.get_connected_joypads():
		if not controller_id in known_controllers:
			add_player(controller_id)


func add_player(controller_id):
	print("Adding player: " + str(controller_id))
	known_controllers.append(controller_id)
	
	# Initialize player for controller
	var sorcerer : Sorcerer = sorcerer_scene.instantiate()
	sorcerer.controller_id = controller_id
	sorcerer.sorcerer_color = controller_id % 4
	sorcerer.can_fire = false
	sorcerer.lives = 3
	
	
	add_child(sorcerer)
	save_data.connect(sorcerer._on_save_data)


func goto_level():
	save_data.emit()
	print(GlobalInfo.run_info)
	Global.goto_scene("res://scenes/level.tscn")

func _on_shop_door_shop_entered() -> void:
	goto_level()


func _on_bulle_sorcerer_contact_bubble() -> void:
	$Bulle.can_open = false
	$Bulle2.can_open = false
	$Bulle3.can_open = false
