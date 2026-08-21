class_name AttackIceSpike
extends Area2D

@export var speed: int = 1500
@export var spawn_immunity_time: float = 0.15  # secondes avant que la hitbox s'active

var direction: Vector2 = Vector2.RIGHT
var _level_scale: Vector2 = Vector2.ONE
var tier_scale: float = 1.0
var player_immunity: bool = true


func scale(level_scale: Vector2) -> void:
	_level_scale = level_scale
	$AnimatedSprite2D.scale = level_scale
	$CollisionPolygon2D.scale = level_scale

func setup_tier(tier: int) -> void:
	tier_scale = float(tier)
	$AnimatedSprite2D.scale = _level_scale * tier_scale
	$CollisionPolygon2D.scale = _level_scale * tier_scale

func _ready() -> void:
	$AnimatedSprite2D.play("idle")
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(0.15).timeout
	player_immunity = false

func _physics_process(delta: float) -> void:
	position += speed * direction * delta

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ennemy_group"):
		body.hit(1)
	elif body.is_in_group("player_group") and not player_immunity:
		body.hit(1)
