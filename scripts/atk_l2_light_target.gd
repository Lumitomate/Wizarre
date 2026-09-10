class_name AttackLightTarget extends AttackProjectile

@export var speed: int = 500
@export var tier_scale: float = 1.0

enum Phase {
	TARGETING,
	EXPLODING
}

var phase: Phase = Phase.TARGETING
var caster: Node2D = null

const FRAME_IDLE = 0
const FRAME_CARDINAL = 1
const FRAME_DIAGONAL = 2
const EXPLOSION_START_FRAME = 11

@onready var sprite_orientation = $SpriteOrientation
@onready var sprite_explosion = $SpriteExplosion
@onready var collision = $CollisionPolygon2D


func _ready() -> void:
	add_to_group("light_target_group")
	collision.disabled = true
	body_entered.connect(_on_body_entered)
	_apply_tier_scale()
	_set_frame(FRAME_IDLE, 0.0, false)
	sprite_orientation.play("Atk_l2_Orientation")


func _physics_process(delta: float) -> void:
	if phase == Phase.TARGETING:
		_update_targeting(delta)
	elif phase == Phase.EXPLODING:
		_update_explosion()


func _update_targeting(delta: float) -> void:
	var stick = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)

	if stick.length() < 0.2:
		position = caster.global_position
		_set_frame(FRAME_IDLE, 0.0, false)
		return

	var dir := stick.normalized()
	position += dir * speed * delta

	# Clamp dans l'écran
	var screen_size := get_viewport_rect().size
	position.x = clamp(position.x, 0.0, screen_size.x)
	position.y = clamp(position.y, 0.0, screen_size.y)

	_set_frame_from_direction(dir)


func _set_frame_from_direction(dir: Vector2) -> void:
	var angle = dir.angle()
	var sector: int = int((angle + PI / 8) / (PI / 4)) % 8
	# 0 = droite, 1 = bas-droite, 2 = bas, 3 = bas-gauche,
	# 4 = gauche, 5 = haut-gauche, 6 = haut, 7 = haut-droite

	var frame: int
	var rot: float
	var flip: bool

	match sector:
		0:  # droite
			frame = FRAME_CARDINAL; rot = 0.0; flip = false
		1:  # bas-droite
			frame = FRAME_DIAGONAL; rot = PI / 4; flip = true
		2:  # bas
			frame = FRAME_CARDINAL; rot = PI / 2; flip = false
		3:  # bas-gauche
			frame = FRAME_DIAGONAL; rot = PI / 2; flip = true
		4:  # gauche
			frame = FRAME_CARDINAL; rot = PI; flip = true
		5:  # haut-gauche
			frame = FRAME_DIAGONAL; rot = -PI / 4; flip = true
		6:  # haut
			frame = FRAME_CARDINAL; rot = -PI / 2; flip = false
		7:  # haut-droite
			frame = FRAME_DIAGONAL; rot = -PI / 4; flip = false

	_set_frame(frame, rot, flip)


func _set_frame(frame: int, rot: float, flip: bool) -> void:
	sprite_orientation.frame = frame
	sprite_orientation.rotation = rot
	sprite_orientation.flip_h = flip


func _update_explosion() -> void:
	if sprite_explosion.frame >= EXPLOSION_START_FRAME:
		collision.disabled = false
	else:
		collision.disabled = true


func start_explosion() -> void:
	if phase != Phase.TARGETING:
		return
	phase = Phase.EXPLODING
	collision.disabled = true
	sprite_orientation.visible = false
	sprite_explosion.play("Atk_l2_Explosion")


func _on_animation_finished() -> void:
	if sprite_explosion.animation == &"Atk_l2_Explosion":
		queue_free()


func _apply_tier_scale() -> void:
	scale = Vector2(tier_scale, tier_scale)
