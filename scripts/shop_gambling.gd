extends Node2D

## Magasin casino (machine à sous) : les sorciers entrent par la porte
## d'entrée, la machine tourne, et chaque joueur arrête les rouleaux de
## son choix avec les plaques de pression. Quand les 3 rouleaux sont
## calés, la machine livre l'objet-attaque au sorcier désigné (vol
## d'absorption, cf. gambling_machine.gd / object_attack.gd) : la porte
## de sortie ne s'ouvre QU'À CETTE FIN (une seule livraison par visite).
## Quand un sorcier touche la porte de sortie, TOUT LE MONDE passe au
## niveau suivant (même règle que Shophands : goto_level change la scène
## entière).

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
	# La porte de sortie ne s'ouvre qu'après la livraison de la machine
	$GamblingMachin.livraison_terminee.connect(_on_machine_livraison)
	$ShopDoor.shop_entered.connect(_on_shop_door_shop_entered)
	# Cinématique d'arrivée par la porte d'entrée (dgel des joueurs à la
	# refermeture, cf. entry_door_cinematic.gd) — les sorciers se sont
	# auto-inscrits à la porte à leur spawn (comportement par défaut)
	var porte := _find_entry_door()
	if porte != null:
		porte.lancer_cinematique()


## Livraison terminée : l'objet a rejoint le tube du sorcier désigné,
## la porte de sortie s'ouvre.
func _on_machine_livraison() -> void:
	$ShopDoor.play()


func _find_entry_door() -> EntryDoorCinematic:
	for child in get_children():
		if child is EntryDoorCinematic:
			return child
	return null


func goto_level() -> void:
	save_data.emit()
	Global.goto_scene(GlobalEnum.Location.LEVEL)


func _on_shop_door_shop_entered() -> void:
	goto_level()
