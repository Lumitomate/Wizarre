extends Node2D

signal block_spawn
signal save_data

@export var enemies_to_kill: int = 25

# Espacement du HUD des joueurs : largeur d'un panneau + moitié pour le
# décalage visuel (layout 4 joueurs : 0, 269, 807, 1076 px)
const HUD_PANEL_SPACING := 269
const START_Y_POSITION := 25

var enemies_killed: int = 0
var enemies_spawned: int = 0
var level_start_time: int

var player_info_scene: PackedScene = preload("res://scenes/hud/hud_players_info.tscn")


func _ready() -> void:

	enemies_to_kill += 3 * GlobalInfo.run_info["level_number"]
	level_start_time = Time.get_ticks_msec()

	# Spawn players via PlayerManager (joueurs figés au démarrage de la
	# partie : les manettes branchées en cours de partie ne créent aucun
		# joueur, elles ne peuvent que reprendre une place déconnectée)
	PlayerManager.spawn_all_players(self, {"lives": 3})

	# Create HUD for each player
	for controller_id in PlayerManager.active_player_ids():
		add_player_hud(controller_id)

	$ProgressBar.set_percent(0)
	$AudioStreamPlayer.play()



func add_player_hud(controller_id):

	var player_info : PlayerInfo = player_info_scene.instantiate()

	# Décalage horizontal par joueur : emplacement + emplacement/2 (division
	# entière) (layout 4 joueurs : 0, 269, 807, 1076 px). L'emplacement
	# (0-3) remplace l'id de device : les joueurs clavier sont intégrés
	@warning_ignore("integer_division")
	var slot: int = PlayerManager.get_player_slot(controller_id)
	var hud_offset: int = HUD_PANEL_SPACING * (slot + slot / 2)
	player_info.position = Vector2(8, START_Y_POSITION) + Vector2(hud_offset, 0)

	player_info.set_bg_color(slot)

	if controller_id in GlobalInfo.run_info["players_info"].keys():
		player_info.load_data(GlobalInfo.run_info["players_info"][controller_id])
	else:
		player_info.load_data(GlobalInfo.run_info["players_info"]["default"])

	var player = PlayerManager.players[controller_id]

	save_data.connect(player._on_save_data)

	player.ammo_changed.connect(player_info._on_ammo_changed)
	player.life_changed.connect(player_info._on_life_changed)

	add_child(player_info)



func _on_enemy_killed() -> void:

	enemies_killed += 1

	$ProgressBar.set_percent(float(enemies_killed) / float(enemies_to_kill))

	if enemies_killed == enemies_to_kill:
		$Terrain1PortesSortieOuverture1.play()
		# Les plantes carnivores (P1) encore en jeu se rétractent au lieu
		# de continuer à attaquer une fois la vague terminée
		for plant in get_tree().get_nodes_in_group("atk_p1"):
			if plant.has_method("retract"):
				plant.retract()



func _on_enemy_spawned() -> void:

	enemies_spawned += 1

	if enemies_spawned == enemies_to_kill:
		block_spawn.emit()



func go_to_shop() -> void:

	save_data.emit()

	GlobalInfo.run_info["run_duration"] = Time.get_ticks_msec() - level_start_time
	GlobalInfo.run_info["level_number"] += 1

	Global.goto_scene(GlobalEnum.Location.SHOP)




func _on_terrain_1_portes_sortie_ouverture_1_shop_entered() -> void:
	go_to_shop()
