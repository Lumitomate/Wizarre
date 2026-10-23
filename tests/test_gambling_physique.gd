extends Node2D
## Test PHYSIQUE fidèle au gameplay : un corps aux dimensions EXACTES du
## sorcier (CharacterBody2D, layer 1, mask 5, capsule 10×30 à l'échelle 2)
## évolue autour de la machine :
##  1. Au sol principal, il est bloqué par le flanc de la machine ;
##  2. Posé sur le plateau du socle, il marche vers un creux et y TOMBE ;
##  3. Debout dans le creux, la plaque le détecte (body_entered → appuis) ;
##  4. En ressortant, la plaque se relâche (body_exited).
const MACHINE := "res://scenes/niveaux/magasin/magasin_casino/gambling_machin.tscn"

var _corps: CharacterBody2D
var _machine: Node2D
var _failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _creer_corps(position_depart: Vector2) -> CharacterBody2D:
	# Mêmes réglages que sorcerer.tscn : CharacterBody2D, scale 2,
	# capsule par défaut (10×30) décalée de (0,1) local, groupe player_group
	# (les plaques n'acceptent que les corps de ce groupe).
	var corps := CharacterBody2D.new()
	corps.collision_layer = 1
	corps.collision_mask = 5
	corps.scale = Vector2(2, 2)
	corps.position = position_depart
	corps.add_to_group("player_group")
	var shape := CollisionShape2D.new()
	shape.position = Vector2(0, 1)
	shape.shape = CapsuleShape2D.new()
	corps.add_child(shape)
	return corps


func _avancer(vitesse: Vector2, frames: int) -> void:
	var delta := get_physics_process_delta_time()
	for i in frames:
		_corps.velocity = vitesse + Vector2(0, _corps.velocity.y + 980.0 * delta)
		_corps.move_and_slide()
		await get_tree().physics_frame


func _appuis(slot: int) -> int:
	return int(_machine._plaques[slot]["appuis"])


func _ready() -> void:
	Engine.time_scale = 4.0
	_machine = load(MACHINE).instantiate()
	add_child(_machine)
	# Sol principal au niveau du bas de la base machine (y=255), couche 3
	# (valeur 4) comme la tilemap des magasins — le masque joueur (5) la voit.
	var sol := StaticBody2D.new()
	sol.collision_layer = 4
	var forme_sol := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 40)
	forme_sol.shape = rect
	forme_sol.position = Vector2(0, 275)  # surface à y=255
	sol.add_child(forme_sol)
	add_child(sol)
	await get_tree().physics_frame

	# 1. Marche au sol vers la machine : bloqué par son flanc gauche
	_corps = _creer_corps(Vector2(-500, 220))
	add_child(_corps)
	await get_tree().physics_frame
	await _avancer(Vector2(150, 0), 240)
	_check(_corps.position.x < -224.0,
		"sol : corps bloqué par le flanc (x=%.1f, attendu < -224)" % _corps.position.x)

	# 2. Lâché au-dessus du creux central : il doit tomber et se poser SUR
	#    le pilier (pieds à y≈170 → centre ≈140), PAS sur le socle (193).
	_corps.position = Vector2(0, 60)
	_corps.velocity = Vector2.ZERO
	await get_tree().physics_frame
	await _avancer(Vector2.ZERO, 120)
	var y_finale := _corps.position.y
	_check(absf(_corps.position.x) < 10.0,
		"creux : le corps est bien dans l'encoche centrale (x=%.1f)" % _corps.position.x)
	_check(y_finale > 120.0 and y_finale < 165.0,
		"creux : le corps se tient SUR le pilier, il ne le traverse pas (y=%.1f, attendu ~140-156)" % y_finale)

	# 3. Debout sur le pilier : la plaque le détecte et s'enfonce
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_appuis(1) > 0,
		"plaque centrale : body_entered détecte le corps réel (appuis=%d)" % _appuis(1))
	_check(float(_machine._plaques[1]["profondeur"]) > 0.0,
		"plaque centrale : elle s'enfonce sous le joueur (profondeur=%.1f)" % float(_machine._plaques[1]["profondeur"]))

	# 4. Téléporté hors de la machine : la plaque doit se relâcher
	_corps.position = Vector2(-500, 220)
	_corps.velocity = Vector2.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_appuis(1) == 0, "plaque centrale : body_exited la relâche (appuis=0)")

	# 5. Pas de faux positif : debout sur une TOUR voisine (pieds à y=163,
	#    2 px au-dessus du haut de la zone) ou sur le socle latéral, aucune
	#    plaque ne doit se déclencher.
	_corps.position = Vector2(-48, 133)
	_corps.velocity = Vector2.ZERO
	await get_tree().physics_frame
	await _avancer(Vector2.ZERO, 30)
	_check(_appuis(1) == 0, "tour voisine : pas de déclenchement de la plaque centrale")
	_corps.position = Vector2(-180, 193)
	_corps.velocity = Vector2.ZERO
	await get_tree().physics_frame
	await _avancer(Vector2.ZERO, 30)
	_check(_appuis(0) == 0, "socle latéral : pas de déclenchement de la plaque gauche")

	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)
