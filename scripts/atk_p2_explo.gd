class_name AttackPlantBall
extends RigidBody2D

@onready var sprite = $AnimatedSprite2D
#@onready var push_area = $PushArea
#@onready var push_shape = $PushArea/CollisionShape2D
@onready var explosion_area = $ExplosionArea
@onready var explosion_shape = $ExplosionArea/CollisionShape2D

#@export var push_force: float = 300.0
@export var explosion_damage: int = 1
@export var roll_duration: float = 3.0
@export var explosion_duration: float = 7.0 / 24.0
@export var explosion_delay_frames: int = 0
@export var tier_scale_multiplier: float = 1.0

var attack_tier: int = 1
var is_exploding: bool = false
var is_explosion_growing: bool = false
var explosion_done: bool = false
var roll_timer: float = 0.0
var explosion_timer: float = 0.0
var explosion_delay_counter: int = 0
var explosion_max_scale: float = 1.0
var _level_scale: Vector2 = Vector2.ONE

func scale(level_scale: Vector2) -> void:
	_level_scale = level_scale
	$AnimatedSprite2D.scale = level_scale
	#$PushArea/CollisionShape2D.scale = level_scale

func setup_tier(tier: int) -> void:
	attack_tier = tier
	explosion_max_scale = tier_scale_multiplier + attack_tier * tier_scale_multiplier

func _ready() -> void:
	explosion_shape.scale = Vector2.ZERO
	explosion_area.monitoring = false
	explosion_area.body_entered.connect(_on_explosion_body_entered)
	sprite.play("rotation")
	sprite.animation_finished.connect(_on_animation_finished)

func _process(delta: float) -> void:
	if is_exploding:
		if explosion_done:
			return
		if not is_explosion_growing:
			explosion_delay_counter += 1
			if explosion_delay_counter >= explosion_delay_frames:
				is_explosion_growing = true
				explosion_timer = 0.0
		else:
			explosion_timer += delta
			var t = clamp(explosion_timer / explosion_duration, 0.0, 1.0)
			var current_scale = lerp(0.0, explosion_max_scale, t)
			explosion_shape.scale = Vector2.ONE * current_scale
			explosion_area.monitoring = true
			if t >= 1.0:
				is_explosion_growing = false
				explosion_done = true
				explosion_area.monitoring = false
		return

	roll_timer += delta
	if roll_timer >= roll_duration:
		_start_explosion()
		return

	if linear_velocity.dot(Vector2.RIGHT) < 0:
		sprite.flip_h = true

func _on_animation_finished() -> void:
	match sprite.animation:
		"rotation":
			sprite.play("lumiere")
		"lumiere":
			_start_explosion()
		"explosion":
			queue_free()

func _start_explosion() -> void:
	if is_exploding:
		return
	is_exploding = true
	explosion_done = false
	explosion_delay_counter = 0
	#push_shape.set_deferred("disabled", true)
	sprite.scale = _level_scale * explosion_max_scale
	sprite.play("explosion")

func _on_explosion_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy_group"):
		body.hit(explosion_damage)
	elif body.is_in_group("player_group"):
		body.hit(1)

#func _on_push_body_entered(body: Node2D) -> void:
	#if is_exploding:
		#return
	#if body.is_in_group("enemy_group"):
		#var direction = (body.global_position - global_position).normalized()
		#if body is RigidBody2D:
			#body.apply_central_impulse(direction * push_force)
		#elif body.has_method("knockback"):
			#body.knockback(direction * push_force)
