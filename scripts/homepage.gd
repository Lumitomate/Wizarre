extends Node2D

func _ready():
	# can_fire=true : les attaques sont utilisables sur l'écran home
	# (tir ami : les joueurs peuvent s'atteindre entre eux).
	# PAS de tubes_selectable ici : X/Y/B doivent uniquement TIRER — en
	# le laissant à true, la fenêtre de cooldown après un tir (can_fire
	# false pendant 0,4 s) ouvrait la branche tubes_selectable et un
	# spam des boutons soulevait les tuyaux (exploit corrigé).
	# in_homepage=true : si un joueur perd toutes ses vies, son cadavre
	# reste 1,5 s puis il respawn (valeurs par défaut, comme une nouvelle
	# manette) — jamais de game over sur cet écran.
	var config := {"can_fire": true, "in_homepage": true}
	PlayerManager.spawn_all_players(self, config)
	PlayerManager.player_added.connect(_on_player_added)

	# Créer le HUD pour chaque joueur (même si pas visible, le système
	# d'amidon recharge doit fonctionner)
	for controller_id in PlayerManager.active_player_ids():
		add_player_hud(controller_id)

func _on_player_added(controller_id):
	PlayerManager.spawn_player(self, controller_id, {"can_fire": true, "in_homepage": true})
	add_player_hud(controller_id)

func add_player_hud(controller_id):
	var player_info_scene = preload("res://scenes/hud/hud_players_info.tscn")
	var player_info = player_info_scene.instantiate()
	var slot = PlayerManager.get_player_slot(controller_id)
	# Division entière volontaire : même formule d'espacement des panneaux
	# HUD que level.gd (les panneaux sont groupés par deux)
	@warning_ignore("integer_division")
	var hud_offset = 269 * (slot + slot / 2)
	player_info.position = Vector2(8, 25) + Vector2(hud_offset, 0)
	player_info.set_bg_color(slot)

	if controller_id in GlobalInfo.run_info["players_info"].keys():
		player_info.load_data(GlobalInfo.run_info["players_info"][controller_id])
	else:
		player_info.load_data(GlobalInfo.run_info["players_info"]["default"])

	var player = PlayerManager.players[controller_id]
	player.ammo_changed.connect(player_info._on_ammo_changed)
	player.life_changed.connect(player_info._on_life_changed)

	add_child(player_info)
	player_info.visible = false
