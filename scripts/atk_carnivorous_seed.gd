class_name CarnivorousSeed
extends RigidBody2D

@export var head_scene: PackedScene = preload("res://scenes/atk_carnivorous_head.tscn")
@export var grow_animation: String = "Grow"
@export var idle_animation: String = "Idle"
@onready var base_plante: AnimatedSprite2D = $BasePlante
@onready var stem_origin = $BasePlante/OriginStem
@export var tier1_height: float = -60.0
@export var tier2_height: float = -55.0
@export var tier3_height: float = -50.0
@export var tier_spread: float = 35.0  # écartement horizontal entre têtes

var attack_tier: int = 1
var heads_remaining: int = 0
var is_planted: bool = false

func scale(level_scale: Vector2) -> void:
	$Sprite2D.scale = level_scale
	$CollisionShape2D.scale = level_scale

func _process(_delta: float) -> void:
	if is_planted:
		return

	if linear_velocity.length() < 10:
		_plant()
		return

	if linear_velocity.dot(Vector2.RIGHT) < 0:
		$Sprite2D.flip_h = true

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
		global_position + Vector2(0, -50),  # part un peu au-dessus, au cas où déjà enfoncé
		global_position + Vector2(0, 200)   # descend chercher le sol
	)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y


func _on_grow_finished():
	base_plante.play(idle_animation)


func _setup_tier(tier: int):
	tier = max(tier, 1)
	heads_remaining = tier

	var rest_positions = _get_rest_positions_for_tier(tier)
	for i in range(tier):
		var head_instance: CarnivorousHead = head_scene.instantiate()
		add_child(head_instance)
		var time_offset = i * 0.7
		head_instance.setup(stem_origin, rest_positions[i], time_offset)
		head_instance.head_finished.connect(_on_head_finished)

func _get_rest_positions_for_tier(tier: int) -> Array[Vector2]:
	match tier:
		1:
			return [Vector2(0, tier1_height)]
		2:
			return [Vector2(-tier_spread, tier2_height), Vector2(tier_spread, tier2_height)]
		3:
			return [Vector2(-tier_spread, tier3_height), Vector2(0, tier1_height), Vector2(tier_spread, tier3_height)]
		_:
			return [Vector2(0, tier1_height)]

func _on_head_finished():
	heads_remaining -= 1
	if heads_remaining <= 0:
		queue_free()
