class_name AttackFireColumn extends Area2D

signal previous_pre_spawn_done


var is_last = false


func _ready() -> void:
	visible = is_last
	$CollisionShape2D.disabled = true
	$Timeout.start()
	if is_last:
		start()


func start() -> void:
	visible = true
	$AnimatedSprite2D.play("pre_spawn")

func _on_previous_pre_spawn_done() -> void:
	start()


func _on_timeout_timeout() -> void:
	queue_free()


func _on_animated_sprite_2d_animation_finished() -> void:
	match $AnimatedSprite2D.animation:
		&"pre_spawn":
			previous_pre_spawn_done.emit()
			$AnimatedSprite2D.play("spawn")
			$CollisionShape2D.disabled = false
		&"spawn":
			$AnimatedSprite2D.play("idle")


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group") or body.is_in_group("ennemy_group"):
		body.hit(1)
