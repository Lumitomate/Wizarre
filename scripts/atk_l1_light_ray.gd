class_name AttackLightRay extends AttackProjectile


func _ready() -> void:
	super._ready()
	# Garde anti double-coup : suivre les sorties de zone (l'entrée est
	# gérée par le _on_body_entered de la base, déjà câblé dans la scène)
	body_exited.connect(_on_body_exited)
	$AnimatedSprite2D.play("pre_spawn")
	$CollisionShape2D.disabled = true


## Règle validée : être dans un rayon de lumière protège d'un nouveau
## coup de rayon (l'éventail du tier peut chevaucher plusieurs rayons =
## un seul toc par passage).
func can_damage(body: Node2D) -> bool:
	return not double_toc_bloque(body)


func _on_animated_sprite_2d_animation_finished() -> void:
	match $AnimatedSprite2D.animation:
		&"pre_spawn":
			$AnimatedSprite2D.play("spawn")
			$CollisionShape2D.disabled = false
		&"spawn":
			queue_free()
