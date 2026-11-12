extends Node

## Test du parcours d'une partie (routage des scènes), en headless :
##  1. l'ascenseur de la page d'accueil mène aux magasins d'intro
##     (2 joueurs ou 3-4 joueurs) — remplace test_shop_intro_routing ;
##  2. mode test WIZARDE_TEST_BOSS : l'ascenseur mène directement à la
##     salle du boss ;
##  3. à la sortie d'un magasin, on retourne dans un niveau, SAUF après
##     la vague affichée IV (compteur interne 4) où l'on va à la salle
##     du boss — le compteur saute alors à 5 pour que la vague suivante
##     redevienne un niveau classique (elle affiche VI).
## Lancé : godot --headless res://tests/test_parcours.tscn

var _failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _ready() -> void:
	var global: Node = load("res://scripts/global.gd").new()

	# ── 1. Ascenseur : routage normal vers les magasins d'intro ──────────
	# Le nombre de joueurs est lu via PlayerManager.active_player_ids()
	# (= known_controllers tant que game_active est faux, cf.
	# player_manager.gd) : on simule 2 puis 4 manettes en headless.
	var zone_scene: PackedScene = load("res://scenes/teleport_zone.tscn")
	var holder := Node2D.new()
	add_child(holder)
	var zone: Area2D = zone_scene.instantiate()
	zone.destination = GlobalEnum.Location.LEVEL
	holder.add_child(zone)

	PlayerManager.known_controllers.assign([0, 1])
	_check(zone.destination_finale() == GlobalEnum.Location.SHOP_2PLAYERS_INTRO,
			"ascenseur 2 joueurs → magasin intro 2 joueurs")
	PlayerManager.known_controllers.assign([0, 1, 2, 3])
	_check(zone.destination_finale() == GlobalEnum.Location.SHOP_4PLAYERS_INTRO,
			"ascenseur 4 joueurs → magasin intro 3-4 joueurs")

	# ── 2. Mode test : ascenseur → salle du boss directement ────────────
	OS.set_environment("WIZARDE_TEST_BOSS", "1")
	_check(zone.destination_finale() == GlobalEnum.Location.BOSS_FIGHT,
			"mode test WIZARDE_TEST_BOSS : ascenseur → salle du boss")
	OS.set_environment("WIZARDE_TEST_BOSS", "")
	_check(zone.destination_finale() == GlobalEnum.Location.SHOP_4PLAYERS_INTRO,
			"mode test désactivé : routage normal rétabli")

	# ── 3. Sortie de magasin : redirection boss après la vague IV ───────
	# Simulation du run : chaque itération fixe le compteur interne tel
	# qu'il est à la SORTIE d'un magasin (l'incrément de fin de niveau a
	# déjà eu lieu), puis applique la redirection. Séquence attendue :
	# vagues internes 0-3 → niveaux classiques, 4 → BOSS, 5-6 → classiques.
	var attendu: Array[GlobalEnum.Location] = [
		GlobalEnum.Location.LEVEL,		# vague affichée I
		GlobalEnum.Location.LEVEL,		# vague affichée II
		GlobalEnum.Location.LEVEL,		# vague affichée III
		GlobalEnum.Location.LEVEL,		# vague affichée IV
		GlobalEnum.Location.BOSS_FIGHT,	# créneau de la vague affichée V
		GlobalEnum.Location.LEVEL,		# vague affichée VI
		GlobalEnum.Location.LEVEL,		# vague affichée VII
	]
	for i in attendu.size():
		Run.set_wave_number(i)
		var obtenu: GlobalEnum.Location = global._redirection_boss(GlobalEnum.Location.LEVEL)
		_check(obtenu == attendu[i],
				"sortie de magasin, compteur interne %d → %s" % [i, attendu[i]])
		if i == 4:
			_check(Run.wave_number() == 5,
					"redirection boss : le compteur interne saute à 5")

	# Une sortie de magasin vers un autre magasin n'est jamais redirigée
	Run.set_wave_number(4)
	_check(global._redirection_boss(GlobalEnum.Location.SHOP) == GlobalEnum.Location.SHOP,
			"magasin → magasin : jamais redirigé vers le boss")

	global.free()
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)
