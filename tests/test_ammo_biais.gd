extends Node2D

## Test du tirage pondéré par le manque (à lancer avec
## tests/test_ammo_biais.tscn). Vérifie :
##  1. Sans sorcier actif → poids uniformes 1/1/1 (repli homepage/tests) ;
##  2. Poids calculés : tube vide → poids_tube_vide, tube plein →
##     poids_tube_plein, 2/4 → exactement au milieu ;
##  3. Tous les spawners d'un même cycle reçoivent les MÊMES poids ;
##  4. Le spawner fait un tirage pondéré : avec poids [5, 1, 1], le
##     Fossil sort ~5 fois plus souvent que les autres types ;
##  5. Sans poids (repli) : tirage uniforme 1/3 ;
##  6. L'état de PlayerManager est restauré après le test.

var _failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _director() -> AmmoSpawnDirector:
	return load("res://scenes/ammo_spawn_director.tscn").instantiate() as AmmoSpawnDirector


## Injecte 2 faux sorciers dans PlayerManager (la partie n'existe pas en
## headless : pas de manette). Renvoie l'état à restaurer.
var _sauvegarde: Array = []


func _inserer_sorciers(s1: Sorcerer, s2: Sorcerer) -> void:
	_sauvegarde = [PlayerManager.game_active, PlayerManager.game_players,
		PlayerManager.players]
	PlayerManager.game_active = true
	PlayerManager.game_players = [90, 91]
	PlayerManager.players = {90: s1, 91: s2}


func _restaurer_player_manager() -> void:
	PlayerManager.game_active = _sauvegarde[0]
	PlayerManager.game_players = _sauvegarde[1]
	PlayerManager.players = _sauvegarde[2]


func _ready() -> void:
	await _test_poids()
	await _test_tirage_pondere()
	_restaurer_player_manager()
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)


func _sorcier(r: Array) -> Sorcerer:
	var s := Sorcerer.new()
	s.energy_counts = r
	return s


# --- 1+2. Poids du cycle : uniforme sans sorcier, lerp sinon -----------
func _test_poids() -> void:
	var d := _director()
	add_child(d)
	await get_tree().process_frame
	# Sans sorcier : uniforme 1/1/1
	var p := d._poids_du_cycle()
	_check(p == ([1.0, 1.0, 1.0] as Array[float]), "sans sorcier : poids uniformes 1/1/1")
	# 2 sorciers : l'un avec les tubes vides, l'autre avec les tubes pleins
	# (moyenne des taux = (0 + 1)/2 = 0.5 → poids au milieu = 3)
	_inserer_sorciers(_sorcier([0, 0, 0]), _sorcier([4, 4, 4]))
	p = d._poids_du_cycle()
	_check(p == ([3.0, 3.0, 3.0] as Array[float]),
		"tubes vides/pleins : moyenne des taux = milieu (3) (%s)" % str(p))
	# Tous les sorciers ont les tubes vides → poids = poids_tube_vide
	_inserer_sorciers(_sorcier([0, 0, 0]), _sorcier([0, 0, 0]))
	p = d._poids_du_cycle()
	_check(p == ([d.poids_tube_vide, d.poids_tube_vide, d.poids_tube_vide] as Array[float]),
		"tubes tous vides : poids = poids_tube_vide (%s)" % str(p))
	# Tous les sorciers ont les tubes pleins → poids = poids_tube_plein
	_inserer_sorciers(_sorcier([4, 4, 4]), _sorcier([4, 4, 4]))
	p = d._poids_du_cycle()
	_check(p == ([d.poids_tube_plein, d.poids_tube_plein, d.poids_tube_plein] as Array[float]),
		"tubes tous pleins : poids = poids_tube_plein (%s)" % str(p))
	# Remplissage moyen 2/4 : poids exactement au milieu
	_inserer_sorciers(_sorcier([2, 2, 2]), _sorcier([2, 2, 2]))
	p = d._poids_du_cycle()
	var milieu := lerpf(1.0, 5.0, 1.0 - 0.5)
	_check(p == ([milieu, milieu, milieu] as Array[float]),
		"tubes à 2/4 : poids au milieu (lerp) = %s" % str(p))
	# Manque asymétrique : chaque type reçoit SON poids
	_inserer_sorciers(_sorcier([0, 4, 2]), _sorcier([0, 4, 2]))
	p = d._poids_du_cycle()
	_check(p == ([5.0, 1.0, 3.0] as Array[float]),
		"remplissages mixtes : poids 5 / 1 / 3 (%s)" % str(p))
	_restaurer_player_manager()
	d.free()


# --- 3+4+5. Le spawner tire selon les poids du cycle -------------------
func _test_tirage_pondere() -> void:
	var d := _director()
	add_child(d)
	await get_tree().process_frame
	# Injecte 2 sorciers : Fossil vide (poids 5), Pure et Tainted pleins (poids 1)
	_inserer_sorciers(_sorcier([0, 4, 4]), _sorcier([0, 4, 4]))
	var poids := d._poids_du_cycle()
	_check(poids == ([5.0, 1.0, 1.0] as Array[float]), "cycle : poids [5, 1, 1]")
	# Le spawner tire selon les poids : Fossil ~5/7, Pure ~1/7, Tainted ~1/7
	var spawner: SpawnerAmmo = load("res://scenes/spawner_ammo.tscn").instantiate()
	add_child(spawner)
	await get_tree().process_frame
	var compteur := {0: 0, 1: 0, 2: 0}
	var nb := 7000
	for i in nb:
		var t := spawner._pick_ammo_type(poids)
		compteur[int(t)] += 1
	var f := float(compteur[0]) / nb
	var pu := float(compteur[1]) / nb
	var ta := float(compteur[2]) / nb
	_check(f > 0.60 and f < 0.80, "poids [5,1,1] : Fossil sort ~71%% (ici %.1f%%)" % (f * 100))
	_check(pu > 0.05 and pu < 0.25 and ta > 0.05 and ta < 0.25,
		"poids [5,1,1] : Pure et Tainted ~14%% chacun (%.1f%% / %.1f%%)" % [pu * 100, ta * 100])
	# Sans poids : uniforme 1/3
	compteur = {0: 0, 1: 0, 2: 0}
	for i in nb:
		var t := spawner._pick_ammo_type([])
		compteur[int(t)] += 1
	f = float(compteur[0]) / nb
	pu = float(compteur[1]) / nb
	ta = float(compteur[2]) / nb
	_check(f > 0.25 and f < 0.42 and pu > 0.25 and pu < 0.42 and ta > 0.25 and ta < 0.42,
		"sans poids : uniforme 1/3 (%.1f%% / %.1f%% / %.1f%%)" % [f * 100, pu * 100, ta * 100])
	# Tous les spawners d'un même cycle reçoivent les MÊMES poids : le
	# directeur calcule les poids UNE fois par cycle (fait vérifié dans
	# le code : _poids_du_cycle() est appelée avant la boucle de tir)
	_restaurer_player_manager()
	d.free()
	spawner.free()
