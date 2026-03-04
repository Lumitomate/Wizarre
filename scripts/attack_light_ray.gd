extends Area2D


func _ready() -> void:
	$AnimatedSprite2D.play("pre_spawn")
	$CollisionShape2D.disabled = true

func _on_animated_sprite_2d_animation_finished() -> void:
	match $AnimatedSprite2D.animation:
		&"pre_spawn":
			$AnimatedSprite2D.play("spawn")
			$CollisionShape2D.disabled = false
		&"spawn":
			queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group") or body.is_in_group("ennemy_group"):
		body.hit(1)
