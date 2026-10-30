extends Node2D

## Test du respawn homepage via cadavre (à lancer avec
## tests/test_respawn_homepage.tscn). Vérifie :
##  1. Un sorcier de la homepage qui meurt re-spawn après ~1,5 s ;
##  2. Le sorcier respawné CONSERVE in_homepage = true (bug corrigé :
##     sans ça, sa mort suivante ne re-spawn jamais et peut déclencher
##     un reset de run depuis la homepage) ;
##  3. Deuxième mort → deuxième respawn ;
##  4. Les données sauvegardées sont effacées au respawn (retour aux
##     valeurs par défaut) ;
##  5. L'état de PlayerManager est restauré après le test.

var _failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _attendre(cond: Callable, timeout_s: float) -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > timeout_s:
			return false
	return true


func _sorcier_vivant(id: int) -> Sorcerer:
	var p = PlayerManager.players.get(id)
	if p != null and is_instance_valid(p) and p.is_inside_tree():
		return p
	return null


func _ready() -> void:
	Engine.time_scale = 4.0
	# État de PlayerManager sauvegardé puis restauré en fin de test
	var sauvegarde := [PlayerManager.game_active, PlayerManager.game_players,
		PlayerManager.players.duplicate()]

	# 1. Spawn via PlayerManager avec la config homepage
	PlayerManager.spawn_player(self, 90, {"can_fire": true, "in_homepage": true})
	var s1 := _sorcier_vivant(90)
	_check(s1 != null, "sorcerer spawné sur la homepage")
	_check(s1.in_homepage, "sorcerer spawné : in_homepage = true")
	_check(s1.can_fire, "sorcerer spawné : can_fire = true")

	# 2. Première mort → respawn ~1,5 s (0,375 s réels à time_scale 4)
	s1.die()
	var respawn := await _attendre(func() -> bool:
		var s := _sorcier_vivant(90)
		return s != null and s != s1, 2.0)
	_check(respawn, "1re mort : sorcier re-spawné après ~1,5 s")
	var s2 := _sorcier_vivant(90)
	_check(s2.in_homepage, "sorcier respawné : in_homepage préservé (bug corrigé)")
	_check(s2.can_fire, "sorcier respawné : can_fire préservé")
	_check(s2.lives == 3, "sorcier respawné : données par défaut (3 vies)")

	# 3. Deuxième mort → deuxième respawn (le bug empêchait celui-ci)
	s2.die()
	respawn = await _attendre(func() -> bool:
		var s := _sorcier_vivant(90)
		return s != null and s != s2, 2.0)
	_check(respawn, "2e mort : sorcier re-spawné (boucle de respawn infinie)")
	var s3 := _sorcier_vivant(90)
	_check(s3.in_homepage, "sorcier respawné (2e) : in_homepage préservé")

	# Nettoyage : le sorcier de test et l'état de PlayerManager
	if _sorcier_vivant(90) != null:
		_sorcier_vivant(90).queue_free()
	PlayerManager.game_active = sauvegarde[0]
	PlayerManager.game_players = sauvegarde[1]
	PlayerManager.players = sauvegarde[2]
	GlobalInfo.run_info["players_info"].erase(90)
	Engine.time_scale = 1.0

	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)
