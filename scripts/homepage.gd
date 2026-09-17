extends Node2D

func _ready():
	# can_fire=false : pas d'attaques sur l'écran home.
	# tubes_selectable=true : X/Y/B soulèvent les tuyaux du sac,
	# comme dans la boutique.
	PlayerManager.spawn_all_players(self, {"can_fire": false, "tubes_selectable": true})
	PlayerManager.player_added.connect(_on_player_added)

func _on_player_added(controller_id):
	PlayerManager.spawn_player(self, controller_id, {"can_fire": false, "tubes_selectable": true})
