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
var time: float = 0.0
var is_eating: bool = false
var is_retracting: bool = false
var bite_triggered: bool = false
var plant_parent: Node = null

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
				target_enemy.die()
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
