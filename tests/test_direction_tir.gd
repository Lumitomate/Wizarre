extends Node2D

## Test headless du sens de tir des attaques (lancer : godot --headless
## res://tests/test_direction_tir.tscn) :
##  1. tir sans direction tenue → l'attaque part devant le sorcier (sens
##     du regard), même si la dernière visée était vers le haut (cas du
##     saut clavier : la touche de saut EST la touche « haut ») ;
##  2. tir avec une direction tenue (W = haut injecté) → l'attaque suit
##     la direction tenue ;
##  3. regard à gauche (flip_h) sans direction tenue → l'attaque part à
##     gauche.

var _failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _ready() -> void:
	await get_tree().process_frame
	await _test_tir()
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _creer_sorcier() -> Sorcerer:
	var sorcier: Sorcerer = load("res://scenes/entities/players/sorcerer.tscn").instantiate()
	# spells doit être rempli AVANT l'ajout à l'arbre : le sac du sorcier
	# lit les 3 tubes à son _ready pour afficher les icônes
	for i in 3:
		sorcier.spells[i] = { "attack_type": GlobalEnum.AttackType.F0, "attack_tier": 0 }
	add_child(sorcier)
	# ... mais load_data() (dans _ready) écrase spells/energy depuis
	# GlobalInfo : on reconfigure après coup
	sorcier.input_device = PlayerInput.KEYBOARD_P1
	sorcier.in_shop = false
	sorcier.can_fire = true
	sorcier.energy_counts = [9, 9, 9]
	for i in 3:
		sorcier.spells[i] = { "attack_type": GlobalEnum.AttackType.F0, "attack_tier": 0 }
	return sorcier


## Tire une boule de feu et renvoie sa direction de vol.
func _tirer_et_direction(sorcier: Sorcerer) -> Vector2:
	var avant := _boules(sorcier).size()
	sorcier.fire_attack(0)
	await _frames(2)
	var boules := _boules(sorcier)
	if boules.size() <= avant:
		return Vector2.INF  # aucun tir
	return boules[boules.size() - 1].direction


func _boules(sorcier: Sorcerer) -> Array:
	var resultat := []
	for child in get_children():
		if child is AttackFireBall:
			resultat.append(child)
	return resultat


## Injecte (relâche) une touche physique pour le clavier 1.
func _touche(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _test_tir() -> void:
	# Le clavier 1 n'appuie sur rien : le tir part DEVANT (à droite ici)
	var sorcier := _creer_sorcier()
	await _frames(2)
	var dir := await _tirer_et_direction(sorcier)
	_check(dir.is_equal_approx(Vector2.RIGHT), "tir sans direction tenue → devant le sorcier (à droite)")

	# Simule le saut clavier : la touche « haut » (W) a été pressée puis
	# relâchée → la dernière visée est vers le haut (aim_direction polluée).
	# Le tir suivant SANS direction doit quand même partir devant.
	sorcier.aim_direction = Vector2.UP
	dir = await _tirer_et_direction(sorcier)
	_check(dir.is_equal_approx(Vector2.RIGHT),
		"tir après un saut clavier (visée haute résiduelle) → toujours devant, pas vers le haut")

	# Direction tenue (W = haut) : l'attaque suit la direction tenue
	_touche(KEY_W, true)
	await _frames(2)
	dir = await _tirer_et_direction(sorcier)
	_check(dir.is_equal_approx(Vector2.UP), "tir avec le haut tenu → l'attaque part vers le haut")
	_touche(KEY_W, false)
	await _frames(2)

	# Regard à gauche, aucune direction tenue → tir à gauche
	sorcier.get_node("AnimatedSprite2D").flip_h = true
	dir = await _tirer_et_direction(sorcier)
	_check(dir.is_equal_approx(Vector2.LEFT), "tir sans direction tenue, regard à gauche → vers la gauche")

	# Direction tenue (D = droite) même le regard à gauche : suit la tenue
	_touche(KEY_D, true)
	await _frames(2)
	dir = await _tirer_et_direction(sorcier)
	_check(dir.is_equal_approx(Vector2.RIGHT), "tir avec la droite tenue, regard à gauche → vers la droite")
	_touche(KEY_D, false)

	sorcier.queue_free()
	await _frames(2)