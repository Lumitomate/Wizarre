class_name AttackIceBall extends RigidBody2D


func _ready() -> void:
	$AnimatedSprite2D.play("default")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group") or body.is_in_group("ennemy_group"):
		body.hit(1)

func scale(level_scale: Vector2) -> void:
	$AnimatedSprite2D.scale = level_scale
	$CollisionShape2D.scale = level_scale

func _process(_delta: float) -> void:
	if linear_velocity.length() < 10:
		queue_free()
	
	if linear_velocity.dot(Vector2.RIGHT) < 0:
		$AnimatedSprite2D.flip_h = true
