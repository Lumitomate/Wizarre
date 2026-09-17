class_name AttackIceSpike
extends AttackProjectile

@export var speed: int = 1500
@export var spawn_immunity_time: float = 0.15  # secondes avant que la hitbox s'active

var direction: Vector2 = Vector2.RIGHT
var _level_scale: Vector2 = Vector2.ONE
var tier_scale: float = 1.0
var player_immunity: bool = true


func apply_level_scale(level_scale: Vector2) -> void:
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
	await get_tree().create_timer(spawn_immunity_time).timeout
	player_immunity = false

func _physics_process(delta: float) -> void:
	position += speed * direction * delta

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func can_damage(body: Node2D) -> bool:
	# Le joueur est immunisé juste après le spawn (la hitbox s'active après
	# un court délai pour éviter de toucher le lanceur)
	return not (player_immunity and body.is_in_group("player_group"))
