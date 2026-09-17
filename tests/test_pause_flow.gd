extends Node

# Test headless des scénarios de pause (scénarios A-H du cahier des charges,
# hors lecture réelle des boutons impossible en headless) :
# - figage du nombre de joueurs au démarrage
# - déconnexion -> pause + sorcier masqué
# - reconnexion / prise de contrôle par une nouvelle manette
# - impossibilité de créer un joueur supplémentaire
# - jauge Reprendre (remplissage forcé -> reprise immédiate)

var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("TEST OK: " + msg)
	else:
		print("TEST ÉCHOUÉ: " + msg)
		failures += 1


func _ready() -> void:
	# --- Mise en place : 2 manettes connues, partie démarrée ---
	PlayerManager._add_controller(0)
	PlayerManager._add_controller(1)
	PlayerManager.start_game()
	print("DEBUG known=%s game=%s" % [str(PlayerManager.known_controllers), str(PlayerManager.game_players)])
	check(PlayerManager.game_active, "partie active")
	check(str(PlayerManager.game_players) == str([0, 1]), "2 joueurs figés au démarrage")

	# --- Scénario E : nouvelle manette sans déconnexion -> ignorée ---
	PlayerManager._on_joy_connection_changed(5, true)
	check(str(PlayerManager.game_players) == str([0, 1]), "E: nouvelle manette ne crée pas de joueur")
	check(5 in PlayerManager.known_controllers, "E: la manette est connue (pour le prochain Home)")

	# --- Scénario B : déconnexion -> pause immédiate + place libre ---
	var disconnect_events: Array = []
	PlayerManager.player_disconnected.connect(func(id): disconnect_events.append(id))
	PlayerManager._on_joy_connection_changed(1, false)
	check(disconnect_events == [1], "B: signal de déconnexion émis")
	check(str(PlayerManager.disconnected_players) == str([1]), "B: place du joueur 1 libre")
	check(PauseManager.paused, "B: pause immédiate")
	check(get_tree().paused, "B: gameplay suspendu (get_tree.paused)")
	check(PauseManager.dummies.size() == 1, "B: seul le sorcier du joueur connecté est affiché")

	# --- Scénario B/C : nouvelle manette prend la place du joueur 1 ---
	var reconnect_events: Array = []
	PlayerManager.player_reconnected.connect(func(id): reconnect_events.append(id))
	PlayerManager._on_joy_connection_changed(7, true)
	check(reconnect_events == [1], "B: signal de reprise émis pour le JOUEUR 1 (identité conservée)")
	check(PlayerManager.input_devices.get(1, -1) == 7, "B/C: la manette 7 contrôle le joueur 1")
	check(str(PlayerManager.game_players) == str([0, 1]), "B/C: toujours 2 joueurs, pas de 3e")
	check(PauseManager.dummies.size() == 2, "B: le sorcier 1 réapparaît dans l'écran de pause")

	# --- Scénario F : encore une nouvelle manette pendant la pause -> ignorée ---
	PlayerManager._on_joy_connection_changed(8, true)
	check(str(PlayerManager.game_players) == str([0, 1]), "F: aucun nouveau joueur pendant la pause")
	check(PauseManager.dummies.size() == 2, "F: aucun sorcier supplémentaire")

	# --- Scénario D : deux joueurs déconnectés, deux reprises ---
	PlayerManager._on_joy_connection_changed(0, false)
	check(str(PlayerManager.disconnected_players) == str([0]), "D: joueur 0 déconnecté")
	check(PauseManager.dummies.size() == 1, "D: plus aucun des deux sorciers n'est affiché... un seul")
	PlayerManager._on_joy_connection_changed(9, true)   # reprend le joueur 0
	check(PlayerManager.input_devices.get(0, -1) == 9, "D: la manette 9 reprend le joueur 0")
	# Le joueur 1 a de nouveau une place libre ? Non : il est déjà repris par la 7.
	# On déconnecte la 7 puis deux nouvelles manettes arrivent.
	PlayerManager._on_joy_connection_changed(7, false)
	check(str(PlayerManager.disconnected_players) == str([1]), "D: joueur 1 redéconnecté")
	check(PauseManager.dummies.size() == 1, "D: un seul sorcier affiché")
	PlayerManager._on_joy_connection_changed(11, true)  # reprend le joueur 1
	check(PlayerManager.input_devices.get(1, -1) == 11, "D: la manette 11 reprend le joueur 1")
	PlayerManager._on_joy_connection_changed(12, true)  # 3e manette -> ignorée
	check(str(PlayerManager.game_players) == str([0, 1]), "D: une 3e nouvelle manette ne crée rien")
	check(PauseManager.dummies.size() == 2, "D: les deux sorciers sont de retour")

	# --- Reconnexion de la manette d'origine d'un joueur repris ---
	PlayerManager._on_joy_connection_changed(1, true)
	check(str(PlayerManager.game_players) == str([0, 1]), "C: la manette d'origine ne duplique personne")

	# --- Jauge Reprendre : remplissage -> reprise immédiate ---
	PauseManager.gauge = 1.0
	PauseManager.resume_game()
	check(not PauseManager.paused, "A: reprise immédiate jauge pleine")
	check(not get_tree().paused, "A: gameplay relancé")
	check(PauseManager.dummies.is_empty(), "A: sorciers d'affichage libérés")

	# --- Pause via pause_game direct puis retour Home (fin de partie) ---
	PauseManager.pause_game()
	check(PauseManager.paused, "pause manuelle active")
	# déconnexion totale : toujours en pause, aucune reprise possible
	# (0 est contrôlé par 9, 1 par 11 après les prises de contrôle)
	PlayerManager._on_joy_connection_changed(9, false)
	PlayerManager._on_joy_connection_changed(11, false)
	check(PauseManager.paused, "H: toutes manettes déconnectées -> jeu toujours en pause")
	check(PauseManager.dummies.is_empty(), "H: aucun sorcier affiché")
	Global.goto_scene(GlobalEnum.Location.HOMEPAGE)
	check(not PauseManager.paused, "H: retour Home force la sortie de pause")
	check(not PlayerManager.game_active, "11: partie terminée en arrivant sur Home")
	check(PlayerManager.game_players.is_empty(), "11: état de partie vidé")
	check(not get_tree().paused, "11: arbre non pausé pour Home")

	# --- Nouvelle partie : les manettes connectées peuvent rejoindre ---
	PlayerManager._on_joy_connection_changed(5, false)  # la 5 avait été ignorée
	PlayerManager._add_controller(5)
	PlayerManager.start_game()
	check(5 in PlayerManager.game_players, "11: la manette ignorée devient joueur à la nouvelle partie")

	if failures == 0:
		print("TEST: TOUS LES TESTS PASSENT")
		get_tree().quit(0)
	else:
		print("TEST: %d échec(s)" % failures)
		get_tree().quit(1)
