extends Node2D

## Test headless du ShopRouter (lancer : godot --headless
## res://tests/test_shop_router.tscn) : tirage pondéré par nombre de
## joueurs, poids nuls, listes vides, et accessibilité de l'autoload.

var _failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _ready() -> void:
	# L'autoload est bien présent dans l'arbre du jeu
	_check(ShopRouter != null, "autoload ShopRouter accessible")

	var router: Node = load("res://scripts/shop_router.gd").new()

	# Tirage équilibré à 2 joueurs (poids 1/1/1) : chacun ~1/3
	var compteur := { SHOP: 0, REFLEX: 0, RACE: 0 }
	for i in 9000:
		var tirage: int = router.tirer_magasin(2)
		match tirage:
			GlobalEnum.Location.SHOP: compteur[SHOP] += 1
			GlobalEnum.Location.SHOP_2PLAYERS_REFLEX: compteur[REFLEX] += 1
			GlobalEnum.Location.SHOP_2PLAYERS_RACE: compteur[RACE] += 1
	for cle in compteur:
		var part: float = float(compteur[cle]) / 9000.0
		_check(part > 0.28 and part < 0.38,
			"2 joueurs, poids 1/1/1 : part %.0f%% (attendu ~33%%)" % (part * 100.0))

	# Pondération 1/1/2 : le troisième sort ~1/2
	var poids_112: Array[float] = [1.0, 1.0, 2.0]
	router.poids_2_joueurs = poids_112
	var nb_troisieme := 0
	for i in 9000:
		if router.tirer_magasin(2) == GlobalEnum.Location.SHOP_2PLAYERS_RACE:
			nb_troisieme += 1
	var part_troisieme := float(nb_troisieme) / 9000.0
	_check(part_troisieme > 0.45 and part_troisieme < 0.55,
		"2 joueurs, poids 1/1/2 : le troisième sort %.0f%% (attendu ~50%%)" % (part_troisieme * 100.0))

	# Poids à 0 : magasin désactivé sans le retirer de la liste (la course
	# et le classique se partagent la place du réflexe désactivé)
	var poids_101: Array[float] = [1.0, 0.0, 1.0]
	router.poids_2_joueurs = poids_101
	var aucun_reflexe := true
	for i in 4000:
		if router.tirer_magasin(2) == GlobalEnum.Location.SHOP_2PLAYERS_REFLEX:
			aucun_reflexe = false
	_check(aucun_reflexe, "2 joueurs, poids 1/0/1 : le réflexe ne sort jamais")

	# 1, 3 et 4 joueurs : les listes configurées sortent
	_check(router.tirer_magasin(1) == GlobalEnum.Location.SHOP, "1 joueur : magasin classique")
	_check(router.tirer_magasin(3) == GlobalEnum.Location.SHOP_HANDS, "3 joueurs : shophands")
	_check(router.tirer_magasin(4) == GlobalEnum.Location.SHOP_HANDS, "4 joueurs : shophands")

	# Listes vides / poids tous nuls : fallback propre (pas de crash)
	router.magasins_1_joueur = [] as Array[GlobalEnum.Location]
	_check(router.tirer_magasin(1) == GlobalEnum.Location.SHOP, "1 joueur, liste vide : fallback magasin classique")
	router.magasins_1_joueur = [GlobalEnum.Location.SHOP] as Array[GlobalEnum.Location]
	router.poids_1_joueur = [0.0] as Array[float]
	_check(router.tirer_magasin(1) == GlobalEnum.Location.SHOP, "1 joueur, poids nul : fallback premier de la liste")

	router.free()
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)


enum { SHOP, REFLEX, RACE }
