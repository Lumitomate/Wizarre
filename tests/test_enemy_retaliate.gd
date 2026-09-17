extends SceneTree

func _initialize() -> void:
	var ok := true

	# --- Représaille : un ennemi sans cible prend son attaquant pour cible
	var flying_scene: PackedScene = load("res://scenes/entities/ennemies/enemy_2lifes.tscn")
	var enemy: EnemyFlying = flying_scene.instantiate()
	var holder := Node2D.new()
	root.add_child(holder)
	holder.add_child(enemy)
	await process_frame

	var shooter := Node2D.new()
	shooter.add_to_group("player_group")
	holder.add_child(shooter)

	print("TEST: cible avant dégât = ", enemy.target)
	enemy.hit(1, shooter)
	print("TEST: cible après dégât = ", enemy.target)
	if enemy.target != shooter:
		ok = false

	# Un ennemi ayant déjà une cible ne la change pas
	var other := Node2D.new()
	other.add_to_group("player_group")
	holder.add_child(other)
	enemy.hit(1, other)
	print("TEST: cible après 2e attaquant = ", enemy.target)
	if enemy.target != shooter:
		ok = false
	enemy.queue_free()

	# --- Essaim : la mort d'une mouche désigne le tueur aux survivantes
	var fly_scene: PackedScene = load("res://scenes/entities/ennemies/enemy_fly.tscn")
	var group: Array[EnemyFly] = []
	for i in 3:
		var f: EnemyFly = fly_scene.instantiate()
		holder.add_child(f)
		group.append(f)
	for f in group:
		f.swarm = group
	await process_frame

	# Les survivantes n'ont pas de cible ; la mouche 0 meurt, tuée par shooter
	group[0].hit(1, shooter)  # lives 1 → 0 : die(shooter) via hit
	print("TEST: cible survivante 1 = ", group[1].target)
	print("TEST: cible survivante 2 = ", group[2].target)
	if group[1].target != shooter or group[2].target != shooter:
		ok = false

	# Le tueur invalide (pas un sorcier) ne devient pas une cible
	var fly_lone: EnemyFly = fly_scene.instantiate()
	holder.add_child(fly_lone)
	await process_frame
	var not_a_player := Node2D.new()
	holder.add_child(not_a_player)
	fly_lone.hit(1, not_a_player)  # meurt, mais attaquant hors player_group
	if fly_lone.target != null:
		ok = false

	if ok:
		print("TEST: TOUS LES TESTS PASSENT")
		quit(0)
	else:
		print("TEST ÉCHOUÉ")
		quit(1)
