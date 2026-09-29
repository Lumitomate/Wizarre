extends Node2D

func _ready():
	# can_fire=true : les attaques sont utilisables sur l'écran home
	# (tir ami : les joueurs peuvent s'atteindre entre eux).
	# tubes_selectable=true : X/Y/B soulèvent les tuyaux du sac,
	# comme dans la boutique.
	# in_homepage=true : si un joueur perd toutes ses vies, son cadavre
	# reste 1,5 s puis il respawn (valeurs par défaut, comme une nouvelle
	# manette) — jamais de game over sur cet écran.
	var config := {"can_fire": true, "tubes_selectable": true, "in_homepage": true}
	PlayerManager.spawn_all_players(self, config)
	PlayerManager.player_added.connect(_on_player_added)

func _on_player_added(controller_id):
	PlayerManager.spawn_player(self, controller_id, {"can_fire": true, "tubes_selectable": true, "in_homepage": true})
