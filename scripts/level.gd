extends Node2D

signal block_spawn
signal save_data

@export var ennemies_to_kill: int = 25

var known_controllers:Array[int] = []
var sorcerer_scene: PackedScene = preload("res://scenes/sorcerer.tscn")
var player_info_scene: PackedScene = preload("res://scenes/hud_players_info.tscn")
var ennemies_killed: int = 0
var ennemies_spawned: int = 0
var level_start_time: int

func _ready() -> void:
	ennemies_to_kill += 3 * GlobalInfo.run_info["level_number"]
	level_start_time = Time.get_ticks_msec()
	for controller_id in Input.get_connected_joypads():
		if not controller_id in known_controllers:
			add_player(controller_id)
	Input.connect("joy_connection_changed", _on_joy_connection_changed)
	$ProgressBar.set_percent(0)
	$AudioStreamPlayer.play()
	print(GlobalInfo.run_info)



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
	
	# Adding HUD for player
	var player_info : PlayerInfo = player_info_scene.instantiate()
	player_info.position = Vector2(8, 25) + Vector2(269 * (controller_id + controller_id / 2), 0)
	player_info.set_bg_color(controller_id % 4)
	
	if controller_id in GlobalInfo.run_info["players_info"].keys():
		player_info.load_data(GlobalInfo.run_info["players_info"][controller_id])
	else:
		player_info.load_data(GlobalInfo.run_info["players_info"]["default"])
	
	save_data.connect(sorcerer._on_save_data)
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
	save_data.emit()
	GlobalInfo.run_info["run_duration"] = Time.get_ticks_msec() - level_start_time
	GlobalInfo.run_info["level_number"] += 1
	Global.goto_scene("res://scenes/shop.tscn")
	print(GlobalInfo.run_info)



func _on_terrain_1_portes_sortie_ouverture_1_shop_entered() -> void:
	go_to_shop()
