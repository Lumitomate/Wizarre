extends RigidBody2D

@export var speed: int = 1000;

var direction: Vector2 = Vector2.LEFT

func _enter_tree() -> void:
	linear_velocity = speed * direction
	if direction == Vector2.LEFT:
		$Sprite2D.flip_h = true
