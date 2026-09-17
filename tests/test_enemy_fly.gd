extends SceneTree

func _initialize() -> void:
	var ok := true

	# Scène mouche : charge, script, vitesse, hitbox réduite
	var fly_scene: PackedScene = load("res://scenes/entities/ennemies/enemy_fly.tscn")
	var fly: EnemyFly = fly_scene.instantiate()
	print("TEST: script mouche = ", fly.get_script().resource_path.get_file())
	print("TEST: fly_speed = ", fly.fly_speed, " / lives = ", fly.lives)
	if not (fly is EnemyFlying) or fly.fly_speed <= 100:
		ok = false

	# La hitbox est celle réglée dans l'éditeur, utilisée telle quelle
	var radius_before: float = (fly.get_node("CollisionShape2D").shape as CircleShape2D).radius
	# Entrée dans l'arbre sous un parent Node2D : EnemyFlying._ready lit
	# get_parent().transform
	var holder := Node2D.new()
	root.add_child(holder)
	holder.add_child(fly)
	await process_frame
	var radius: float = (fly.get_node("CollisionShape2D").shape as CircleShape2D).radius
	print("TEST: rayon hitbox = ", radius, " (éditéur : ", radius_before, ")")
	if not is_equal_approx(radius, radius_before):
		ok = false
	# L'animation est bien jouée (le _ready du parent doit avoir tourné)
	var sprite: AnimatedSprite2D = fly.get_node("AnimatedSprite2D")
	print("TEST: animation jouée = ", sprite.is_playing())
	if not sprite.is_playing():
		ok = false
	fly.queue_free()

	# Cohésion d'essaim : le centre de deux mouches est leur point milieu
	var fly2: EnemyFly = fly_scene.instantiate()
	holder.add_child(fly2)
	fly.position = Vector2(0, 0)
	fly2.position = Vector2(100, 40)
	var pair: Array[EnemyFly] = [fly, fly2]
	fly.swarm = pair
	fly2.swarm = pair
	var center: Vector2 = fly._swarm_center()
	print("TEST: centre essaim = ", center)
	if center.distance_to(Vector2(50, 20)) > 0.1:
		ok = false
	fly.queue_free()
	fly2.queue_free()

	# L'essaim compte pour UN SEUL kill quand tout le groupe est mort
	var mock_script := GDScript.new()
	mock_script.source_code = "extends Node\nvar kills := 0\nfunc _on_enemy_killed() -> void:\n\tkills += 1\n"
	mock_script.reload()
	var mock := Node.new()
	mock.set_script(mock_script)
	var spawner: Node = load("res://scripts/spawner_enemy.gd").new()
	mock.add_child(spawner)

	var group: Array[EnemyFly] = []
	for i in 5:
		var f: EnemyFly = fly_scene.instantiate()
		f.enemy_killed.connect(spawner._on_fly_killed.bind(group))
		group.append(f)
	for f in group:
		f.swarm = group

	# Une mouche meurt, les autres vivantes : pas de kill compté (via le
	# vrai chemin du signal die() → enemy_killed)
	group[0].die()
	print("TEST: kills après 1 mort = ", mock.kills)
	if mock.kills != 0:
		ok = false
	# Une 2e mouche meurt : toujours pas de kill compté
	group[1].die()
	if mock.kills != 0:
		ok = false
	# Tout l'essaim meurt : exactement 1 kill (émis par le handler, pas
	# manuellement)
	for i in range(2, 5):
		group[i].die()
	print("TEST: kills après essaim détruit = ", mock.kills)
	if mock.kills != 1:
		ok = false

	# Le spawner référence bien la scène mouche
	var spawner_script = load("res://scripts/spawner_enemy.gd")
	var src = spawner_script.source_code
	if "enemy_fly_scene" not in src or "FLY_CHANCE" not in src or "FLY_GROUP_SIZE" not in src:
		ok = false

	if ok:
		print("TEST: TOUS LES TESTS PASSENT")
		quit(0)
	else:
		print("TEST ÉCHOUÉ")
		quit(1)
