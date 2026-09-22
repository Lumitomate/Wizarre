class_name CarnivorousHead
extends Node2D

signal head_finished

@onready var head = $HeadPlante
@onready var stem = $Stem
@onready var detection_zone = $HeadPlante/Area2D
@onready var stem_anchor = $HeadPlante/EndPointStem

@export var idle_radius: float = 40.0
@export var idle_speed: float = 0.8
@export var chase_speed: float = 3.0
@export var chase_speed_player: float = 2.5
@export var stem_segments: int = 8
@export var retract_speed: float = 4.0
@export var bite_kill_frame: int = 4

var stem_origin: Node2D = null
var head_rest_position: Vector2 = Vector2(0, -300)
var time_offset: float = 0.0
var attack_tier: int = 1

var target_enemy = null
# Sorcier qui a planté la plante (pour la représaille des ennemis tués)
var caster: Node2D = null
var time: float = 0.0
var is_eating: bool = false
var is_retracting: bool = false
var bite_triggered: bool = false
var plant_parent: Node = null

# Validation d'emplacement : la tête ne doit jamais être dans un mur ni
# hors de l'écran. Dernier endroit valide connu (auquel on la ramène).
var _last_valid_position := Vector2.ZERO
var _spot_validated := false

# Marge par rapport aux bords de l'écran (en px monde)
const SCREEN_MARGIN := 40.0

func setup(origin: Node2D, rest_pos: Vector2, t_offset: float, tier: int = 1):
	stem_origin = origin
	head_rest_position = rest_pos
	time_offset = t_offset
	attack_tier = tier
	head.position = head_rest_position

func _ready():
	plant_parent = get_parent()
	detection_zone.body_entered.connect(_on_area_2d_body_entered)
	detection_zone.body_exited.connect(_on_area_2d_body_exited)
	head.play("atk_p1_idle")

func _process(delta):
	time += delta
	if is_retracting:
		_retract_head(delta)
		_update_stem()
		return
	if is_eating:
		return
	if target_enemy and is_instance_valid(target_enemy):
		_chase_enemy(delta)
	else:
		_idle_movement(delta)
	_validate_spot()
	_update_stem()

func _idle_movement(delta):
	var t = time + time_offset
	var angle = sin(t * idle_speed) * deg_to_rad(30)
	var target_offset = Vector2(
		sin(angle) * idle_radius,
		-abs(cos(angle)) * idle_radius * 0.5
		)
	head.position = head.position.lerp(head_rest_position + target_offset, delta * 2.0)
	head.rotation = lerp_angle(head.rotation, angle * 0.5, delta * 3.0)

func _chase_enemy(delta):
	var direction = target_enemy.global_position - head.global_position
	var distance = direction.length()
	if distance < 20.0:
		_start_eating()
	else:
		var speed = chase_speed_player if target_enemy.is_in_group("player_group") else chase_speed
		head.position += direction.normalized() * speed * delta * 60
		head.rotation = lerp_angle(head.rotation, direction.angle() + PI/2, delta * 5.0)

func _start_eating():
	if is_eating:
		return
	is_eating = true
	bite_triggered = false
	head.play("atk_p1_bite")
	head.frame_changed.connect(_on_bite_frame_changed)
	await head.animation_finished
	head.frame_changed.disconnect(_on_bite_frame_changed)
	target_enemy = null
	is_eating = false
	is_retracting = true

func _on_bite_frame_changed():
	if bite_triggered:
		return
	if head.animation == "atk_p1_bite" and head.frame == bite_kill_frame:
		bite_triggered = true
		if target_enemy and is_instance_valid(target_enemy):
			if target_enemy is EnemyFlying:
				target_enemy.die(caster)
			elif target_enemy.is_in_group("player_group"):
				target_enemy.hit(1)

func _retract_head(delta):
	var target_local = head.position + (to_local(stem_origin.global_position) - to_local(stem_anchor.global_position))
	head.position = head.position.lerp(target_local, delta * retract_speed)
	head.rotation = lerp_angle(head.rotation, 0.0, delta * retract_speed)
	var reached_base = stem_anchor.global_position.distance_to(stem_origin.global_position) < 5.0
	if reached_base:
		var correction = stem_origin.global_position - stem_anchor.global_position
		head.global_position += correction
		head.rotation = 0.0
		_finish_head()

func _finish_head():
	is_retracting = false
	head_finished.emit()
	queue_free()

func _update_stem():
	stem.clear_points()
	var base = stem.to_local(stem_origin.global_position)
	var tip = stem.to_local(stem_anchor.global_position)
	for i in range(stem_segments + 1):
		var t = float(i) / float(stem_segments)
		var control = Vector2(
			lerp(base.x, tip.x, 0.5) + sin((time + time_offset) * 0.5) * 10.0,
			lerp(base.y, tip.y, 0.3)
		)
		var point = base.bezier_interpolate(control, control, tip, t)
		stem.add_point(point)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if target_enemy == null and not is_eating and not is_retracting:
		if body is EnemyFlying:
			if plant_parent and plant_parent.has_method("is_closest_head_for_enemy"):
				if not plant_parent.is_closest_head_for_enemy(self, body):
					return
			target_enemy = body
			head.play("atk_p1_open")
		elif body.is_in_group("player_group") and attack_tier < 3:
			target_enemy = body
			head.play("atk_p1_open")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == target_enemy and not is_eating:
		target_enemy = null
		head.play("atk_p1_idle")


## Rétracte la tête immédiatement, sans mordre (appelée quand tous les
## ennemis du niveau ont été tués). La logique de retour à la base est
## celle de _retract_head, déjà en place.
func retract() -> void:
	target_enemy = null
	is_eating = false
	is_retracting = true


## Vrai si la tête peut être à cette position : centre hors des murs
## (tuiles du décor ; ennemis et sorciers ignorés) et dans l'écran.
func _is_spot_valid(pos: Vector2) -> bool:
	var viewport := get_viewport()
	var screen_pos: Vector2 = viewport.canvas_transform * pos
	var screen_size := viewport.get_visible_rect().size
	if screen_pos.x < SCREEN_MARGIN or screen_pos.x > screen_size.x - SCREEN_MARGIN \
			or screen_pos.y < SCREEN_MARGIN or screen_pos.y > screen_size.y - SCREEN_MARGIN:
		return false
	# Le centre de la tête est-il à l'intérieur d'une tuile du décor ?
	var space_state := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	# Tous les calques : on détecte le décor quel que soit son calque,
	# puis on ignore les entités (ennemi/sorcier)
	params.collision_mask = 0x7FFFFFFF
	for hit in space_state.intersect_point(params, 4):
		var collider = hit.collider
		if collider.is_in_group("enemy_group") or collider.is_in_group("player_group"):
			continue
		return false
	return true


## Cherche un endroit valide pour la tête (elle doit "pouvoir apparaître") :
## spirale autour de la base de la plante, en commençant vers le haut, puis
## décrochage vertical au-dessus de la base. Le point de repos de l'idle est
## ajusté pour que l'oscillation reste dans la zone valide.
func _find_valid_spot() -> void:
	var base: Vector2 = stem_origin.global_position if stem_origin != null else (plant_parent as Node2D).global_position
	var target: Vector2 = head.global_position
	if not _is_spot_valid(target):
		var valid = _find_valid_around(base)
		if valid == null:
			for dy in range(2, 48, 2):
				var candidate: Vector2 = base + Vector2(0, -float(dy))
				if _is_spot_valid(candidate):
					valid = candidate
					break
		if valid == null:
			valid = base
		head.global_position = valid
		head_rest_position = plant_parent.to_local(valid)
	_last_valid_position = head.global_position
	_spot_validated = true


## Premier emplacement valide trouvé en spirale autour de center,
## ou null si aucun (jusqu'à 160 px).
func _find_valid_around(center: Vector2) -> Variant:
	for radius in [24.0, 48.0, 72.0, 96.0, 120.0, 160.0]:
		for i in 16:
			var angle := -PI / 2.0 + TAU * float(i) / 16.0
			var candidate: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
			if _is_spot_valid(candidate):
				return candidate
	return null


## Après un déplacement : si la tête finit dans un mur ou hors de l'écran,
## on la ramène au dernier endroit valide connu.
func _validate_spot() -> void:
	if not _spot_validated:
		_find_valid_spot()
		return
	if _is_spot_valid(head.global_position):
		_last_valid_position = head.global_position
	else:
		head.global_position = _last_valid_position
