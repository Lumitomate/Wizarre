extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/entities/ennemies/enemy_2lifes.tscn")
	var enemy: EnemyFlying = scene.instantiate()
	print("TEST: type = ", enemy.get_class(), " / script = ", enemy.get_script().resource_path.get_file())
	print("TEST: lives = ", enemy.lives)
	if enemy.lives == 2 and enemy is EnemyFlying:
		print("TEST: TOUS LES TESTS PASSENT")
		quit(0)
	else:
		print("TEST ÉCHOUÉ")
		quit(1)
