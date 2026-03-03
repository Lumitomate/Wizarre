extends CharacterBody2D

@export var speed: int = 700
@export var jump_impulse: int = 2500
@export var fall_acceleration = 10000

var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport_rect().size

#func _process(delta: float) -> void:
	#if  Input.is_action_just_pressed("fire"):
		

func _physics_process(delta: float) -> void:
	velocity.x = 0
	if Input.is_action_pressed("move_left"):
		velocity.x = -1 * speed
		$Sprite2D.flip_h = true
	if Input.is_action_pressed("move_right"):
		velocity.x = 1 * speed
		$Sprite2D.flip_h = false
		
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = -jump_impulse
	
	if not is_on_floor():
		velocity.y += fall_acceleration * delta

	move_and_slide()
