class_name AttackLightRay extends AttackProjectile


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
