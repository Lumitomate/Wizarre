extends Node2D
## Magasin à 2 joueurs (épreuve de réflexe) : atteint quand la partie compte
## exactement 2 joueurs (voir le routage dans global.gd). Les joueurs
## arrivent par la porte d'entrée du terrain1 et repartent par la porte
## de sortie, qui s'ouvre dès qu'ils arrivent dans la salle.

signal save_data


func _ready() -> void:
	# Spawn les joueurs via PlayerManager (joueurs figés au démarrage de
	# la partie : pas de nouveau joueur si une manette se branche ici)
	PlayerManager.spawn_all_players(self)
	# Mode boutique activé pour tous les joueurs de cette scène
	for controller_id in PlayerManager.active_player_ids():
		var player: Sorcerer = PlayerManager.players.get(controller_id)
		if player != null:
			player.in_shop = true
	# La porte de sortie s'ouvre dès l'arrivée dans la salle
	$ShopDoor.play()


func goto_level():
	save_data.emit()
	Global.goto_scene(GlobalEnum.Location.LEVEL)


func _on_shop_door_shop_entered() -> void:
	goto_level()