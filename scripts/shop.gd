extends Node2D

var known_controllers:Array[int] = []
var sorcerer_scene: PackedScene = preload("res://scenes/sorcerer.tscn")


func _ready() -> void:
	for controller_id in Input.get_connected_joypads():
		if not controller_id in known_controllers:
			add_player(controller_id)
	$ShopDoor.play()
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
	
	if controller_id in GlobalInfo.run_info["players_info"].keys():
		sorcerer.load_data(GlobalInfo.run_info["players_info"][controller_id])
	else:
		sorcerer.load_data(GlobalInfo.run_info["players_info"]["default"])
	
	sorcerer.can_fire = false
	
	self.add_child(sorcerer)


func goto_level():
	Global.goto_scene("res://scenes/level.tscn")

func _on_shop_door_shop_entered() -> void:
	goto_level()


func _on_bulle_sorcerer_contact_bubble() -> void:
	$Bulle.can_open = false
	$Bulle2.can_open = false
	$Bulle3.can_open = false
