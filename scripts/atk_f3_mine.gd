class_name AttackFireMine extends AttackProjectile

# Mine de Feu (tier 3) — 3 phases :
# 1. IDLE     : posée au-dessus du sorcier, animation "idle" en boucle
# 2. FALL     : au 2e appui, animation "chute" et descente jusqu'au sol
# 3. EXPLODE  : une fois le sol touché, animation "Explosion"
#
# La hitbox est active dès la frame 0 de l'explosion et suit la forme
# du sprite (interpolation entre frames clés), mise à l'échelle du tier.

enum Phase { IDLE, FALL, EXPLODE }

@export var fall_speed: float = 600.0
@export var tier_scale: float = 1.0

var caster: Node2D = null
var phase: Phase = Phase.IDLE

const IDLE_ANIM = "Idle"
const FALL_ANIM = "Chute"
const EXPLOSION_ANIM = "Explosion"

# Couches physiques du sol (TileMap) pour le raycast de chute
const GROUND_MASK := 4

# Points de la hitbox aux frames clés de l'explosion (x, y).
# L'animation ayant perdu ses 4 premières frames, les clés sont
# décalées : 4->0, 16->12, 26->22.
const FRAME_HITBOX = {
	0: [
		Vector2(3, 76), Vector2(0, 76), Vector2(-3, 76),
		Vector2(-2, 74), Vector2(0, 74), Vector2(2, 74)
	],
	12: [
		Vector2(24, 21), Vector2(0, 49), Vector2(-24, 19),
		Vector2(-14, -23), Vector2(0, -44), Vector2(14, -23)
	],
	22: [
		Vector2(33, -45), Vector2(0, -45), Vector2(-32, -45),
		Vector2(-29, -66), Vector2(0, -71), Vector2(29, -66)
	]
}

# Échelle de la mine selon le tier (ajustable)
# S'applique au sprite ET à la hitbox (scale du nœud racine)
const TIER_SCALE = {
	1: 0.8,   # tier I  : petite explosion
	2: 2.5,   # tier II : moyenne
	3: 4.0   # tier III : grande explosion
}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionPolygon2D = $CollisionPolygon2D


func _ready() -> void:
	add_to_group("fire_mine_group")
	collision_shape.disabled = true
	body_entered.connect(_on_body_entered)
	sprite.play(IDLE_ANIM)


func setup_tier(tier: int) -> void:
	tier_scale = TIER_SCALE.get(tier, 1.0)
	# Met le nœud entier (sprite + hitbox) à l'échelle du tier
	scale = Vector2(tier_scale, tier_scale)


# Appelée par le sorcerer au 2e appui : la mine se détache et tombe
func explode() -> void:
	if phase != Phase.IDLE:
		return
	phase = Phase.FALL
	# Marque la mine comme "partie" : le sorcier ne la retrouvera plus
	# et le verrou d'appui reste en place jusqu'au relâchement
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(FALL_ANIM):
		sprite.play(FALL_ANIM)
	else:
		sprite.pause()  # animation "chute" pas encore ajoutée : tombe quand même


func _physics_process(delta: float) -> void:
	if phase != Phase.FALL:
		return
	var dist := fall_speed * delta
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, dist + _half_height()),
		GROUND_MASK
	)
	var hit := space.intersect_ray(query)
	if hit:
		# Pose le centre de la mine à demi-hauteur au-dessus du sol
		global_position.y = hit.position.y - _half_height()
		_start_explosion()
	else:
		global_position.y += dist


# Demi-hauteur actuelle du sprite (en coordonnées globales, tier inclus)
func _half_height() -> float:
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var height := tex.get_height() if tex != null else 32
	return height * 0.5 * global_scale.y


func _start_explosion() -> void:
	phase = Phase.EXPLODE
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(EXPLOSION_ANIM):
		sprite.play(EXPLOSION_ANIM)
	# Hitbox active dès la frame 0 (frame_changed ne se déclenche pas
	# si la frame reste 0, on l'applique donc manuellement)
	_update_hitbox(sprite.frame)


func _on_frame_changed() -> void:
	_update_hitbox(sprite.frame)


func _update_hitbox(current_frame: int) -> void:
	collision_shape.disabled = false
	# Points en coordonnées locales : le scale du nœud racine
	# (fixé par setup_tier) les met automatiquement à l'échelle
	collision_shape.polygon = _get_points_for_frame(current_frame)


# Interpole linéairement les points entre les frames clés
func _get_points_for_frame(frame: int) -> PackedVector2Array:
	var keys = FRAME_HITBOX.keys()
	keys.sort()
	var points: PackedVector2Array = PackedVector2Array()
	if frame <= keys[0]:
		for p in FRAME_HITBOX[keys[0]]:
			points.append(p)
		return points
	if frame >= keys[-1]:
		for p in FRAME_HITBOX[keys[-1]]:
			points.append(p)
		return points
	# interpolation entre les deux clés encadrantes
	var f0: int = 0
	var f1: int = 0
	for i in range(keys.size() - 1):
		if frame >= keys[i] and frame <= keys[i + 1]:
			f0 = keys[i]
			f1 = keys[i + 1]
			break
	var t := float(frame - f0) / float(f1 - f0)
	var p0 = FRAME_HITBOX[f0]
	var p1 = FRAME_HITBOX[f1]
	for i in range(p0.size()):
		points.append(p0[i].lerp(p1[i], t))
	return points


func _on_animation_finished() -> void:
	if sprite.animation == EXPLOSION_ANIM:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	# Ne touche jamais le lanceur, sinon il s'auto-détruirait en posant la mine
	if body == caster:
		return
	super._on_body_entered(body)
