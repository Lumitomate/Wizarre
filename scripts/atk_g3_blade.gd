class_name AttackIceBlade
extends Area2D

@export var rotation_duration: float = 1.0
@export var orbit_radius: float = 80.0

const FRAME_HEIGHTS = {
	0: 0,
	10: 60,
	17: 67,
	21: 81,
	25: 96,
	30: 114,
	35: 128
}
const MAX_HEIGHT = 128.0

var player: Node2D = null
var start_angle: float = 0.0
var rotation_direction: float = 1.0
var tier_scale: float = 1.0
var _level_scale: Vector2 = Vector2.ONE
var current_angle: float = 0.0
var rotation_timer: float = 0.0
var is_rotating: bool = false
var base_polygon_points: PackedVector2Array = PackedVector2Array()
var hit_bodies: Array = []

@onready var sprite = $AnimatedSprite2D
@onready var collision_polygon = $CollisionPolygon2D

func setup(p: Node2D, angle: float, rot_dir: float, tier: int, level_scale: Vector2) -> void:
	player = p
	start_angle = angle
	current_angle = angle
	rotation_direction = rot_dir
	tier_scale = float(tier)
	_level_scale = level_scale
	orbit_radius = orbit_radius * (tier_scale + 0.5) / 1.5

func _ready() -> void:
	base_polygon_points = collision_polygon.polygon
	body_entered.connect(_on_body_entered)
	sprite.scale = _level_scale * tier_scale
	sprite.play("Growth")
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_growth_finished)

func _on_frame_changed() -> void:
	if sprite.animation == "Growth":
		_update_hitbox(sprite.frame)

func _update_hitbox(current_frame: int) -> void:
	var height = _get_height_for_frame(current_frame) * tier_scale
	var scale_y = max(height, 0.0) / MAX_HEIGHT
	var new_points = PackedVector2Array()
	for p in base_polygon_points:
		new_points.append(Vector2(p.x, p.y * scale_y))
	collision_polygon.polygon = new_points

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

func _on_growth_finished() -> void:
	is_rotating = true
	# reconstruit les points à taille max avec tier_scale
	var max_points = PackedVector2Array()
	for p in base_polygon_points:
		max_points.append(Vector2(p.x, p.y * tier_scale))
	collision_polygon.polygon = max_points
	sprite.play("Shot")

func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		queue_free()
		return

	# détection manuelle pendant Growth car la hitbox change trop vite
	if not is_rotating:
		for body in get_overlapping_bodies():
			if body not in hit_bodies:
				if body.is_in_group("player_group") or body.is_in_group("enemy_group"):
					hit_bodies.append(body)
					body.hit(1)

	if is_rotating:
		rotation_timer += delta
		var t = clamp(rotation_timer / rotation_duration, 0.0, 1.0)
		current_angle = start_angle + rotation_direction * (PI / 2.0) * t
		if t >= 1.0:
			queue_free()
			return

	var offset = Vector2.RIGHT.rotated(current_angle) * orbit_radius
	global_position = player.global_position + offset
	rotation = current_angle + PI / 2.0

func _on_body_entered(body: Node2D) -> void:
	print("body entered: ", body.name, " has hit: ", body.has_method("hit"), " groups: ", body.get_groups())
	if body.is_in_group("player_group") or body.is_in_group("enemy_group"):
		body.hit(1)
