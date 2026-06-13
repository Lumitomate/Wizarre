class_name AttackCarnivorous extends Node2D

@onready var head = $AnimatedSprite2D
@onready var stem = $Line2D
@onready var detection_zone = $AnimatedSprite2D/Area2D
@onready var eat_timer = $AnimatedSprite2D/Timer
@onready var stem_anchor = $AnimatedSprite2D/Marker2D  # ← ton Marker2D à la base de la tête

@export var idle_radius: float = 40.0
@export var idle_speed: float = 0.8
@export var chase_speed: float = 4.0
@export var stem_base_pos: Vector2 = Vector2(0, 0)
@export var stem_segments: int = 8

var target_enemy: EnnemyFlying = null
var time: float = 0.0
var is_eating: bool = false
var head_rest_position: Vector2 = Vector2(0, -100)

func _ready():
	detection_zone.body_entered.connect(_on_enemy_entered)
	detection_zone.body_exited.connect(_on_enemy_exited)
	eat_timer.timeout.connect(_on_eat_finished)
	head.play("atk_p_idle")
	$Sprite2D.play()
	

func _process(delta):
	time += delta
	if is_eating:
		return
	if target_enemy and is_instance_valid(target_enemy):
		_chase_enemy(delta)
	else:
		_idle_movement(delta)
	_update_stem()  # toujours appelé

func _idle_movement(delta):
	var angle = sin(time * idle_speed) * deg_to_rad(30)
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
		head.position += direction.normalized() * chase_speed * delta * 60
		head.rotation = lerp_angle(head.rotation, direction.angle() + PI/2, delta * 5.0)

func _start_eating():
	if is_eating:
		return
	is_eating = true
	head.play("atk_p_bite")
	await head.animation_finished
	
	if target_enemy and is_instance_valid(target_enemy):
		target_enemy.die()
	target_enemy = null
	
	head.play("atk_p_chew")
	eat_timer.start()

func _on_eat_finished():
	is_eating = false
	head.play("atk_p_idle")

func _update_stem():
	stem.clear_points()
	var base = stem_base_pos
	var tip = stem.to_local(stem_anchor.global_position)
	for i in range(stem_segments + 1):
		var t = float(i) / float(stem_segments)
		var control = Vector2(
			lerp(base.x, tip.x, 0.5) + sin(time * 0.5) * 10.0,
			lerp(base.y, tip.y, 0.3)
		)
		var point = base.bezier_interpolate(control, control, tip, t)
		stem.add_point(point)

func _on_enemy_entered(body: Node2D):
	if body is EnnemyFlying and target_enemy == null and not is_eating:
		target_enemy = body

func _on_enemy_exited(body: Node2D):
	if body == target_enemy and not is_eating:
		target_enemy = null
