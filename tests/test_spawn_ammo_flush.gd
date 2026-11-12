extends Node2D

## Test headless : spawn_now doit rester invoquable depuis un callback
## physique (body_entered, exécuté PENDANT le flush des requêtes) sans
## toucher à l'état de collision pendant le flush — la munition n'est
## ajoutée qu'à la frame suivante (appel différé, cf. spawner_ammo.gd).
## Régression de l'erreur « Can't change this state while flushing
## queries » : fin de vague → level._on_enemy_killed →
## spawner_ammo.spawn_now, le tout déclenché par un body_entered (ronce
## P3, projectile…).
## Lancé comme scène : godot --headless res://tests/test_spawn_ammo_flush.tscn

var failures := 0
var _spawner: Node2D
var _holder: Node2D
var _contact := false
var _ammo_dans_flush := -1


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK: " + msg)
	else:
		print("FAIL: " + msg)
		failures += 1


func _ready() -> void:
	_holder = Node2D.new()
	add_child(_holder)
	_spawner = (load("res://scenes/spawner_ammo.tscn") as PackedScene).instantiate()
	_holder.add_child(_spawner)
	await get_tree().process_frame

	# Piège à flush : le handler de body_entered s'exécute pendant le
	# flush des requêtes physiques, exactement comme
	# atk_p3_bramble_segment._on_body_entered dans le jeu.
	var zone := Area2D.new()
	var forme := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100, 100)
	forme.shape = rect
	zone.add_child(forme)
	zone.body_entered.connect(_on_body_entered)
	add_child(zone)

	var corps := StaticBody2D.new()
	var forme_corps := CollisionShape2D.new()
	forme_corps.shape = rect
	corps.add_child(forme_corps)
	corps.position = Vector2(10, 0)  # chevauche la zone
	add_child(corps)

	for i in 120:
		await get_tree().physics_frame
		if _contact:
			break
	check(_contact, "body_entered déclenché (contexte de flush reproduit)")
	check(_ammo_dans_flush == 0,
		"aucune munition ajoutée PENDANT le flush (spawn différé)")

	await get_tree().process_frame
	await get_tree().process_frame
	var n := 0
	for enfant in _holder.get_children():
		if enfant is Ammo:
			n += 1
	check(n == 1, "munition ajoutée à la frame suivante (obtenu %d)" % n)

	if failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % failures)
		get_tree().quit(1)


func _on_body_entered(_body: Node2D) -> void:
	_contact = true
	# Comme dans le jeu : le spawn est demandé depuis le callback physique.
	_spawner.spawn_now()
	# Lecture seule, autorisée pendant le flush : combien de munitions
	# l'appel vient-il d'ajouter ? Réponse attendue : aucune (différé).
	_ammo_dans_flush = _compter_ammo()


func _compter_ammo() -> int:
	var n := 0
	for enfant in _holder.get_children():
		if enfant is Ammo:
			n += 1
	return n
