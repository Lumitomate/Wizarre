extends Node2D

func _ready():

	PlayerManager.spawn_all_players(self)

	PlayerManager.player_added.connect(_on_player_added)



func _on_player_added(controller_id):

	PlayerManager.spawn_player(self, controller_id)
