class_name AttackIceBall extends RigidBody2D

@export var spawn_immunity_time: float = 1.0 # durée d'immunité du lanceur après le spawn

var caster: Node2D = null
var player_immunity: bool = true # le lanceur ne peut pas se toucher juste après le tir


func _ready() -> void:
	$AnimatedSprite2D.play("default")
	# Immunité du lanceur pendant spawn_immunity_time après le tir
	await get_tree().create_timer(spawn_immunity_time).timeout
	player_immunity = false

func can_damage(body: Node2D) -> bool:
	# Le lanceur est immunisé juste après le tir (la boule part devant lui)
	return not (player_immunity and body == caster)

func _on_body_entered(body: Node2D) -> void:
	if not can_damage(body):
		return
	if body.is_in_group("enemy_group"):
		body.hit(1, caster)
	elif body.is_in_group("player_group"):
		body.hit(1)

func apply_level_scale(level_scale: Vector2) -> void:
	$AnimatedSprite2D.scale = level_scale
	$CollisionShape2D.scale = level_scale

func _process(_delta: float) -> void:
	if linear_velocity.length() < 10:
		queue_free()
	
	if linear_velocity.dot(Vector2.RIGHT) < 0:
		$AnimatedSprite2D.flip_h = true
