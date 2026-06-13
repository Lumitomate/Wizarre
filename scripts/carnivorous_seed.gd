class_name CarnivorousSeed extends RigidBody2D

var carnivorous_scene = preload("res://scenes/attack_carnivorous.tscn")

func scale(level_scale: Vector2) -> void:
	$Sprite2D.scale = level_scale
	$CollisionShape2D.scale = level_scale
	
func _process(_delta: float) -> void:
	if linear_velocity.length() < 10:
		var carnivorous_plant: AttackCarnivorous = carnivorous_scene.instantiate()
		carnivorous_plant.position = position
		self.get_parent().add_child(carnivorous_plant)
		queue_free()
	
	if linear_velocity.dot(Vector2.RIGHT) < 0:
		$Sprite2D.flip_h = true
