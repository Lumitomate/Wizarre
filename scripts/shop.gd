extends Node2D

signal save_data


func _ready() -> void:
	# Spawn les joueurs via PlayerManager
	PlayerManager.spawn_all_players(self)
	# Manette branchée en cours de partie : son joueur apparaît directemement
	PlayerManager.player_added.connect(_on_player_added)
	# Mode boutique activé pour tous les joueurs de cette scène
	for controller_id in PlayerManager.known_controllers:
		var player: Sorcerer = PlayerManager.players.get(controller_id)
		if player != null:
			player.in_shop = true
	$ShopDoor.play()


func _on_player_added(controller_id: int) -> void:
	PlayerManager.spawn_player(self, controller_id)
	var player: Sorcerer = PlayerManager.players.get(controller_id)
	if player != null:
		player.in_shop = true


func goto_level():
	save_data.emit()
	Global.goto_scene(GlobalEnum.Location.LEVEL)

func _on_shop_door_shop_entered() -> void:
	goto_level()


func _on_bubble_sorcerer_contact_bubble() -> void:
	$Bulle.can_open = false
	$Bulle2.can_open = false
	$Bulle3.can_open = false
	# Pas de désélection des tubes ici : le contact d'une bulle ne doit pas
	# annuler le tube activé pendant la prise d'objets. Le changement de scène
	# (niveau suivant) recrée des sorciers neufs de toute façon.
