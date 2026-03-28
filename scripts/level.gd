extends Node2D

signal block_spawn
signal save_data

@export var ennemies_to_kill: int = 25

var ennemies_killed: int = 0
var ennemies_spawned: int = 0
var level_start_time: int

var player_info_scene: PackedScene = preload("res://scenes/hud_players_info.tscn")


func _ready() -> void:

	ennemies_to_kill += 3 * GlobalInfo.run_info["level_number"]
	level_start_time = Time.get_ticks_msec()

	# Spawn les joueurs via PlayerManager
	PlayerManager.spawn_all_players(self)

	# Créer le HUD pour chaque joueur
	for controller_id in PlayerManager.known_controllers:
		add_player_hud(controller_id)

	$ProgressBar.set_percent(0)
	$AudioStreamPlayer.play()

	print(GlobalInfo.run_info)



func add_player_hud(controller_id):

	var player_info : PlayerInfo = player_info_scene.instantiate()

	player_info.position = Vector2(8, 25) + Vector2(269 * (controller_id + controller_id / 2), 0)

	player_info.set_bg_color(controller_id % 4)

	if controller_id in GlobalInfo.run_info["players_info"].keys():
		player_info.load_data(GlobalInfo.run_info["players_info"][controller_id])
	else:
		player_info.load_data(GlobalInfo.run_info["players_info"]["default"])

	var player = PlayerManager.players[controller_id]

	save_data.connect(player._on_save_data)

	player.ammo_changed.connect(player_info._on_ammo_changed)
	player.life_changed.connect(player_info._on_life_changed)

	add_child(player_info)



func _on_ennemy_killed() -> void:

	ennemies_killed += 1

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
