class_name AttackFireColumn extends AttackProjectile

signal previous_pre_spawn_done


var is_last = false


func _ready() -> void:
	super._ready()
	visible = is_last
	$CollisionShape2D.disabled = true
	$Timeout.start()
	# Garde anti double-coup : suivre les sorties de zone (l'entrée est
	# gérée par le _on_body_entered de la base, déjà câblé dans la scène)
	body_exited.connect(_on_body_exited)
	if is_last:
		start()


## Règle validée : être dans une colonne de feu protège d'un nouveau
## coup de colonne de feu (chaîne de colonnes = un seul toc par passage).
func can_damage(body: Node2D) -> bool:
	return not double_toc_bloque(body)


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
