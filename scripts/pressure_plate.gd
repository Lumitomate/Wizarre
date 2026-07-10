extends Node2D
class_name PressurePlate

signal activated
signal deactivated

@export var target_path: NodePath
@export var press_depth: float = 4.0
@export var press_duration: float = 0.12
@export var release_duration: float = 0.2

@onready var plate_body: StaticBody2D = $StaticBody2D
@onready var trigger_area: Area2D = $TriggerArea

var target: Node
var bodies_on_plate: Array = []
var press_tween: Tween
var rest_position: Vector2

func _ready() -> void:
	target = get_node_or_null(target_path)
	rest_position = plate_body.position

	trigger_area.body_entered.connect(_on_body_entered)
	trigger_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player_group"):
		return
	if body in bodies_on_plate:
		return

	bodies_on_plate.append(body)
	if bodies_on_plate.size() == 1:
		_activate()

func _on_body_exited(body: Node) -> void:
	if body in bodies_on_plate:
		bodies_on_plate.erase(body)

	if bodies_on_plate.is_empty():
		_deactivate()

func _activate() -> void:
	emit_signal("activated")
	if target and target.has_method("activate"):
		target.activate()
	_animate_plate(rest_position + Vector2(0, press_depth), press_duration)

func _deactivate() -> void:
	emit_signal("deactivated")
	if target and target.has_method("deactivate"):
		target.deactivate()
	_animate_plate(rest_position, release_duration)

func _animate_plate(target_pos: Vector2, duration: float) -> void:
	if press_tween:
		press_tween.kill()
	press_tween = create_tween()
	press_tween.set_ease(Tween.EASE_OUT)
	press_tween.set_trans(Tween.TRANS_QUAD)
	press_tween.tween_property(plate_body, "position", target_pos, duration)
	
	
