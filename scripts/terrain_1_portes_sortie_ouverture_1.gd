extends AnimatedSprite2D

signal shop_entered


func _ready() -> void:
	$Area2D/CollisionShape2D.disabled = true


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		shop_entered.emit()


func _on_animation_finished() -> void:
	$Area2D/CollisionShape2D.disabled = false
