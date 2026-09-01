class_name AttackCarnivorousSeed
extends RigidBody2D

@export var head_scene: PackedScene = preload("res://scenes/atk_p1_carnivorous_head.tscn")
@export var grow_animation: String = "Grow"
@export var idle_animation: String = "Idle"
@export var idle_tier3_animation: String = "idle_tier3"
@onready var base_plante: AnimatedSprite2D = $BasePlante
@onready var stem_origin = $BasePlante/OriginStem
@onready var oeil: Sprite2D = $BasePlante/Oeil

@export var tier1_height: float = -60.0
@export var tier2_height: float = -55.0
@export var tier3_height: float = -50.0
@export var tier_spread: float = 35.0
@export var eye_rotation_speed: float = 5.0
@export var shrink_speed: float = 8.0

var attack_tier: int = 1
var heads_remaining: int = 0
var is_planted: bool = false
var is_shrinking: bool = false
var heads: Array[CarnivorousHead] = []
var base_plante_initial_position: Vector2 = Vector2.ZERO
var base_plante_initial_scale: Vector2 = Vector2.ONE

func scale(level_scale: Vector2) -> void:
	$Sprite2D.scale = level_scale
	$CollisionShape2D.scale = level_scale

func _process(delta: float) -> void:
	if is_planted:
		if is_shrinking:
			var new_scale = base_plante.scale.lerp(Vector2.ZERO, delta * shrink_speed)
			base_plante.scale = new_scale
			# oeil.scale = new_scale  ← supprimer, géré automatiquement par l'héritage
			var scale_ratio = new_scale.y / base_plante_initial_scale.y
			var frame_size = base_plante.sprite_frames.get_frame_texture(base_plante.animation, base_plante.frame).get_height() * base_plante_initial_scale.y
			base_plante.position.y = base_plante_initial_position.y + frame_size * (1.0 - scale_ratio) * 0.5
			if base_plante.scale.length() < 0.05:
				queue_free()
			return
		if attack_tier == 3:
			_update_eye(delta)
		return
	if linear_velocity.length() < 10:
		_plant()
		return
	if linear_velocity.dot(Vector2.RIGHT) < 0:
		$Sprite2D.flip_h = true

func _update_eye(delta: float) -> void:
	var closest = _get_closest_entity()
	if closest:
		var direction = closest.global_position - oeil.global_position
		var target_angle = direction.angle() + PI / 2
		oeil.rotation = lerp_angle(oeil.rotation, target_angle, delta * eye_rotation_speed)

func _get_closest_entity() -> Node2D:
	var closest: Node2D = null
	var min_distance: float = INF
	for enemy in get_tree().get_nodes_in_group("enemy_group"):
		if not is_instance_valid(enemy):
			continue
		var d = oeil.global_position.distance_to(enemy.global_position)
		if d < min_distance:
			min_distance = d
			closest = enemy
	for player in get_tree().get_nodes_in_group("player_group"):
		if not is_instance_valid(player):
			continue
		var d = oeil.global_position.distance_to(player.global_position)
		if d < min_distance:
			min_distance = d
			closest = player
	return closest

func _plant():
	is_planted = true
	freeze = true
	rotation = 0.0
	_snap_to_ground()
	$Sprite2D.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	base_plante.visible = true
	base_plante.play(grow_animation)
	base_plante.animation_finished.connect(_on_grow_finished, CONNECT_ONE_SHOT)
	_setup_tier(attack_tier)

func _snap_to_ground():
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -50),
		global_position + Vector2(0, 200)
	)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y

func _on_grow_finished():
	if attack_tier == 3:
		base_plante.play(idle_tier3_animation)
		oeil.visible = true
	else:
		base_plante.play(idle_animation)
	base_plante_initial_position = base_plante.position
	base_plante_initial_scale = base_plante.scale

func _setup_tier(tier: int):
	tier = max(tier, 1)
	var head_count = 2 if tier == 3 else tier
	heads_remaining = head_count
	oeil.visible = false
	var rest_positions = _get_rest_positions_for_tier(tier)
	for i in range(head_count):
		var head_instance: CarnivorousHead = head_scene.instantiate()
		add_child(head_instance)
		var time_offset = i * 0.7
		head_instance.setup(stem_origin, rest_positions[i], time_offset, tier)
		head_instance.head_finished.connect(_on_head_finished)
		heads.append(head_instance)

func _get_rest_positions_for_tier(tier: int) -> Array[Vector2]:
	match tier:
		1:
			return [Vector2(0, tier1_height)]
		2:
			return [Vector2(-tier_spread, tier2_height), Vector2(tier_spread, tier2_height)]
		3:
			return [Vector2(-tier_spread, tier3_height), Vector2(tier_spread, tier3_height)]
		_:
			return [Vector2(0, tier1_height)]

func _on_head_finished():
	heads_remaining -= 1
	if heads_remaining <= 0:
		is_shrinking = true

func is_closest_head_for_enemy(requester: CarnivorousHead, enemy: Node2D) -> bool:
	var min_distance = requester.head.global_position.distance_to(enemy.global_position)
	for h in heads:
		if h == requester or not is_instance_valid(h):
			continue
		var d = h.head.global_position.distance_to(enemy.global_position)
		if d < min_distance:
			return false
	return true
