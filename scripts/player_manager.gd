extends Node

signal player_added(controller_id)
# Joueur de la partie dont la manette vient d'être déconnectée
signal player_disconnected(controller_id)
# Joueur repris : manette d'origine rebranchée, ou nouvelle manette ayant
# pris la place d'un joueur déconnecté
signal player_reconnected(controller_id)

var known_controllers: Array[int] = []
var players = {}

var sorcerer_scene: PackedScene = preload("res://scenes/entities/players/sorcerer.tscn")

# --- État de la partie en cours ---
# Identités des joueurs de la partie (device id au moment du démarrage) :
# figé par start_game(), JAMAIS augmenté pendant la partie. Une nouvelle
# manette ne peut que reprendre la place d'un joueur déconnecté.
var game_active := false
var game_players: Array[int] = []
# Joueurs de la partie dont la manette est déconnectée (place libre)
var disconnected_players: Array[int] = []
# Identité de joueur -> device physique qui le contrôle actuellement
# (absent = sa propre manette d'origine)
var input_devices := {}


func _ready():

	# joueurs déjà connectés
	for controller_id in Input.get_connected_joypads():
		if not controller_id in known_controllers:
			_add_controller(controller_id)

	# détecter nouvelles manettes / déconnexions
	Input.connect("joy_connection_changed", _on_joy_connection_changed)


# Début d'une partie (départ de Home) : le nombre de joueurs est figé.
func start_game() -> void:
	game_active = true
	game_players = known_controllers.duplicate()
	disconnected_players.clear()
	input_devices.clear()


# Retour sur Home : la partie est terminée. Toutes les manettes
# connectées pourront créer des joueurs à la prochaine partie.
func end_game() -> void:
	game_active = false
	game_players.clear()
	disconnected_players.clear()
	input_devices.clear()


func is_game_player(controller_id: int) -> bool:
	return controller_id in game_players


# Device physique qui contrôle actuellement ce joueur (par défaut : sa
# propre manette d'origine ; peut être une manette de remplacement)
func get_input_device(controller_id: int) -> int:
	return input_devices.get(controller_id, controller_id)


# Devices physiques de chaque joueur actuellement connecté
func connected_game_devices() -> Array[int]:
	var devices: Array[int] = []
	for id in game_players:
		if id in disconnected_players:
			continue
		devices.append(get_input_device(id))
	return devices


# Ids des joueurs à faire apparaître dans la scène courante : les joueurs
# de la partie pendant une partie, toutes les manettes disponibles sur Home
func active_player_ids() -> Array[int]:
	return game_players.duplicate() if game_active else known_controllers.duplicate()


func _on_joy_connection_changed(device: int, connected: bool):
	if connected:
		# Reconnexion de la manette d'origine d'un joueur déconnecté
		if game_active and device in disconnected_players:
			disconnected_players.erase(device)
			player_reconnected.emit(device)
		if not device in known_controllers:
			_add_controller(device)
		# Prise de contrôle : une nouvelle manette reprend la place d'un
		# joueur déconnecté (jamais création d'un joueur supplémentaire).
		# Le nombre de joueurs de la partie reste inchangé.
		if game_active and not is_game_player(device) and not disconnected_players.is_empty():
			var player_id: int = disconnected_players.pop_front()
			input_devices[player_id] = device
			var sorcerer = players.get(player_id)
			if sorcerer != null and is_instance_valid(sorcerer):
				sorcerer.input_device = device
			player_reconnected.emit(player_id)
	else:
		known_controllers.erase(device)
		if game_active:
			# Le device déconnecté contrôlait-il un joueur (manette d'origine
			# ou manette de remplacement) ? Si oui, sa place devient libre
			for id in game_players:
				if id in disconnected_players:
					continue
				if get_input_device(id) == device:
					disconnected_players.append(id)
					player_disconnected.emit(id)
					break


func _add_controller(controller_id):
	if controller_id in known_controllers:
		return
	known_controllers.append(controller_id)
	players[controller_id] = null

	player_added.emit(controller_id)


func spawn_player(parent: Node, controller_id: int, player_config: Dictionary = {}):

	var player: Sorcerer = sorcerer_scene.instantiate()
	player.controller_id = controller_id
	player.sorcerer_color = (controller_id % 4) as GlobalEnum.SorcererColor
	# L'identité (controller_id) reste immuable ; la manette physique
	# pollée peut être celle d'un remplaçant (voir input_devices)
	player.input_device = get_input_device(controller_id)

	player.load_data()

	for k in player_config.keys():
		if k == "can_fire":
			player.can_fire = player_config[k]
		elif k == "tubes_selectable":
			player.tubes_selectable = player_config[k]
		elif k == "lives":
			player.lives = player_config[k]

	parent.add_child(player)

	players[controller_id] = player


func spawn_all_players(parent: Node, player_config: Dictionary = {}):

	for controller_id in active_player_ids():
		spawn_player(parent, controller_id, player_config)


func save_players_data():
	for controller_id in known_controllers:
		if players[controller_id] != null:
			players[controller_id].export_data()
