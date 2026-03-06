extends Node2D

signal block_spawn

@export var ennemies_to_kill: int = 25

var known_controllers:Array[int] = []
var sorcerer_scene: PackedScene = preload("res://scenes/sorcerer.tscn")
var player_info_scene: PackedScene = preload("res://scenes/players_info.tscn")
var ennemies_killed: int = 0
var ennemies_spawned: int = 0


func _ready() -> void:
	for controller_id in Input.get_connected_joypads():
		if not controller_id in known_controllers:
			add_player(controller_id)
	Input.connect("joy_connection_changed", _on_joy_connection_changed)
	$ProgressBar.set_percent(0)
	$AudioStreamPlayer.play()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	Input.get_connected_joypads()
	for controller_id in Input.get_connected_joypads():
		if not controller_id in known_controllers:
			add_player(controller_id)


func add_player(controller_id):
	print("Adding player: " + str(controller_id))
	known_controllers.append(controller_id)
	var ammunitions: Array[int] = [3, 3, 3]
	var lives: int = 3
	
	# Initialize player for controller
	var sorcerer : Sorcerer = sorcerer_scene.instantiate()
	sorcerer.controller_id = controller_id
	sorcerer.sorcerer_color = controller_id % 4
	sorcerer.ammunitions = ammunitions
	sorcerer.lives = lives
	
	# Adding HUD for player
	var player_info : PlayerInfo = player_info_scene.instantiate()
	player_info.position = Vector2(8, 25) + Vector2(269 * (controller_id + controller_id / 2), 0)
	player_info.set_bg_color(controller_id % 4)
	player_info.ammunitions = ammunitions
	player_info.lives = lives
	sorcerer.ammo_changed.connect(player_info._on_ammo_changed)
	sorcerer.life_changed.connect(player_info._on_life_changed)
	
	self.add_child(sorcerer)
	self.add_child(player_info)


func _on_ennemy_killed() -> void:
	ennemies_killed +=1
	$ProgressBar.set_percent(float(ennemies_killed) / float(ennemies_to_kill))
	if ennemies_killed == ennemies_to_kill:
		$Terrain1PortesSortieOuverture1.play()

func _on_ennemy_spawned() -> void:
	ennemies_spawned += 1
	if ennemies_spawned == ennemies_to_kill:
		block_spawn.emit()


func go_to_shop() -> void:
	#call_deferred("get_tree().change_scene_to_file()", "res://scenes/shop.tscn")
	get_tree().change_scene_to_file("res://scenes/shop.tscn")


func _on_terrain_1_portes_sortie_ouverture_1_shop_entered() -> void:
	call_deferred("go_to_shop")
