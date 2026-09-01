class_name AttackFireWave
extends Area2D

@export var speed: int = 1000
@export var tier_scale: float = 1.0

var direction: Vector2 = Vector2.LEFT

const FRAME_HEIGHTS = {
	0: 0,
	5: 4,
	18: 10,
	24: 32,
	31: 64,
	43: 132,
	48: 192,
	53: 316,
	56: 384,
	59: 448,
	62: 448
}

const BASE_POINTS = [
	Vector2(-116, -225),
	Vector2(-116, 225),
	Vector2(-45, 193),
	Vector2(-10, 124),
	Vector2(0, 0),
	Vector2(-10, -124),
	Vector2(-45, -193)
]

const MAX_HEIGHT = 448.0

@onready var sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionPolygon2D

# frame maximale selon le tier (à ajuster visuellement)
const TIER_MAX_FRAMES = {
	1: 40,  # petite vague
	2: 52,  # vague moyenne
	3: 62   # grande vague (animation complète)
}

var max_frame: int = 62

func _ready() -> void:
	sprite.play("atk_f2_grow")
	collision_shape.disabled = true
	body_entered.connect(_on_body_entered)

func setup_tier(tier: int) -> void:
	max_frame = TIER_MAX_FRAMES.get(tier, 62)

func _physics_process(delta: float) -> void:
	position += speed * direction * delta
	if sprite.frame >= max_frame:
		sprite.pause()
	_update_hitbox(sprite.frame)

func _on_frame_changed() -> void:
	_update_hitbox(sprite.frame)

func _update_hitbox(current_frame: int) -> void:
	var height = _get_height_for_frame(current_frame) * tier_scale
	if height <= 0:
		collision_shape.disabled = true
		return
	collision_shape.disabled = false
	print("frame: ", current_frame, " height: ", height, " disabled: ", collision_shape.disabled)
	var scale_y = height / MAX_HEIGHT
	var scale_x = 0.0 if current_frame < 4 else 1.0
	var new_points = PackedVector2Array()
	for p in BASE_POINTS:
		new_points.append(Vector2(p.x * scale_x, p.y * scale_y))
	collision_shape.polygon = new_points

func _get_height_for_frame(frame: int) -> float:
	var sorted_frames = FRAME_HEIGHTS.keys()
	sorted_frames.sort()
	if frame <= sorted_frames[0]:
		return float(FRAME_HEIGHTS[sorted_frames[0]])
	if frame >= sorted_frames[-1]:
		return float(FRAME_HEIGHTS[sorted_frames[-1]])
	for i in range(sorted_frames.size() - 1):
		var f0 = sorted_frames[i]
		var f1 = sorted_frames[i + 1]
		if frame >= f0 and frame <= f1:
			var t = float(frame - f0) / float(f1 - f0)
			return lerp(float(FRAME_HEIGHTS[f0]), float(FRAME_HEIGHTS[f1]), t)
	return 0.0

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group") or body.is_in_group("enemy_group"):
		body.hit(1)
