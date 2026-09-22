extends Area2D
## Épreuve de réflexe à 2 plaques de pression avec bulle de verre :
## - un joueur sur une plaque → la plaque descend de PLATE_DESCENT px,
##   puis l'animation d'énergie de son côté se lance vers l'avant ;
## - si le joueur quitte la plaque → elle remonte et l'animation repart
##   dans l'autre sens depuis la frame où elle en était ;
## - si les 2 plaques sont maintenues ET que les 2 animations sont à la
##   dernière frame en même temps → la bulle s'ouvre (cassure de verre) et
##   sa hitbox saute, libérant l'objet qu'elle bloquait.

signal bubble_opened

# Descente maximale de la plaque pressée (4 px) et durée de la descente
const PLATE_DESCENT := 4.0
const PLATE_PRESS_DURATION := 0.12
# Frame à partir de laquelle la hitbox de la bulle saute (comme bubble.gd)
const BUBBLE_OPEN_FRAME := 15

var _plates := {}
var _bubble_opened := false

@onready var _bubble_sprite: AnimatedSprite2D = $Bubble/AnimatedSprite2D_Bulle
@onready var _bubble_collision: CollisionShape2D = $Bubble/CollisionShape2D


func _ready() -> void:
	_plates = {
		"left": {
			"area": $PlateLeft/DetectionZone,
			"body": $PlateLeft,
			"energy": $AnimatedSprite2D_left,
			"count": 0,
			"base_y": $PlateLeft.position.y,
		},
		"right": {
			"area": $PlateRight/DetectionZone,
			"body": $PlateRight,
			"energy": $AnimatedSprite2D_right,
			"count": 0,
			"base_y": $PlateRight.position.y,
		},
	}
	for side: String in _plates:
		var plate: Dictionary = _plates[side]
		# Animations d'énergie : premières frames, à l'arrêt
		var energy: AnimatedSprite2D = plate["energy"]
		energy.stop()
		energy.frame = 0
		var area: Area2D = plate["area"]
		area.body_entered.connect(_on_plate_body_entered.bind(side))
		area.body_exited.connect(_on_plate_body_exited.bind(side))
	_bubble_sprite.play("Idle")


func _process(_delta: float) -> void:
	if _bubble_opened:
		# La hitbox de la bulle saute à la frame 15 de la cassure
		if not _bubble_collision_cleared() and _bubble_sprite.frame >= BUBBLE_OPEN_FRAME:
			_bubble_collision.set_deferred("disabled", true)
		return
	if _both_plates_fully_energized():
		_open_bubble()


func _on_plate_body_entered(body: Node2D, side: String) -> void:
	if not body.is_in_group("player_group"):
		return
	var plate: Dictionary = _plates[side]
	plate["count"] = int(plate["count"]) + 1
	if plate["count"] == 1:
		_press_plate(side)


func _on_plate_body_exited(body: Node2D, side: String) -> void:
	if not body.is_in_group("player_group"):
		return
	var plate: Dictionary = _plates[side]
	plate["count"] = maxi(0, int(plate["count"]) - 1)
	if plate["count"] == 0:
		_release_plate(side)


## La plaque entière (sprite ET hitbox) descend de PLATE_DESCENT px ;
## une fois totalement appuyée, l'animation d'énergie de son côté se lance
## (en reprenant depuis la frame courante si elle était en train de se vider).
func _press_plate(side: String) -> void:
	var plate: Dictionary = _plates[side]
	var body: StaticBody2D = plate["body"]
	_plate_kill_tween(plate)
	var tween := create_tween()
	plate["tween"] = tween
	tween.tween_property(body, "position:y", float(plate["base_y"]) + PLATE_DESCENT, PLATE_PRESS_DURATION)
	tween.tween_callback(func():
		if plate["count"] > 0:
			(plate["energy"] as AnimatedSprite2D).play()
	)


## Le joueur a quitté : la plaque entière (sprite + hitbox) remonte et
## l'animation d'énergie repart dans l'autre sens depuis la frame courante.
func _release_plate(side: String) -> void:
	var plate: Dictionary = _plates[side]
	_plate_kill_tween(plate)
	var body: StaticBody2D = plate["body"]
	var tween := create_tween()
	plate["tween"] = tween
	tween.tween_property(body, "position:y", float(plate["base_y"]), PLATE_PRESS_DURATION)
	var energy: AnimatedSprite2D = plate["energy"]
	if energy.frame > 0:
		energy.play_backwards()


func _plate_kill_tween(plate: Dictionary) -> void:
	var existing = plate.get("tween")
	if existing != null and (existing as Tween).is_valid():
		(existing as Tween).kill()


func _bubble_collision_cleared() -> bool:
	return _bubble_collision.disabled


## Les 2 plaques enfoncées ET les 2 animations d'énergie à leur dernière frame
func _both_plates_fully_energized() -> bool:
	for side: String in _plates:
		var plate: Dictionary = _plates[side]
		if int(plate["count"]) <= 0:
			return false
		var energy: AnimatedSprite2D = plate["energy"]
		if energy.frame < energy.sprite_frames.get_frame_count(energy.animation) - 1:
			return false
	return true


## Ouverture de la bulle : anim de cassure, puis la hitbox saute
## (déclenché dans _process à la frame BUBBLE_OPEN_FRAME).
func _open_bubble() -> void:
	_bubble_opened = true
	_bubble_sprite.play("default")
	bubble_opened.emit()