extends CharacterBody2D

@export var speed: int = 700
@export var jump_impulse: int = 2500
@export var fall_acceleration: int = 10000

var fireball_scene = preload("res://attack_fireball.tscn")

var screen_size: Vector2
var direction: Vector2 = Vector2.RIGHT
var ammunition: Array = [3, 3, 3]

func _ready() -> void:
	screen_size = get_viewport_rect().size

func _process(_delta: float) -> void:
	if  (Input.is_action_just_pressed("fire_1") and ammunition[0] > 0) or (Input.is_action_just_pressed("fire_2") and ammunition[1] > 0) or (Input.is_action_just_pressed("fire_3") and ammunition[2] > 0):
		var fireball = fireball_scene.instantiate()
		fireball.position = position + 60 * direction
		fireball.direction = direction
		if Input.is_action_just_pressed("fire_1"):
			fireball.color_mod = Color(1, 0, 0)
			ammunition[0] -= 1
			print("Remaining red: " + str(ammunition[0]))
		elif  Input.is_action_just_pressed("fire_2"):
			fireball.color_mod = Color(0, 1, 0)
			ammunition[1] -= 1
			print("Remaining green: " + str(ammunition[1]))
		elif Input.is_action_just_pressed("fire_3"):
			fireball.color_mod = Color(0, 0, 1)
			ammunition[2] -= 1
			print("Remaining blue: " + str(ammunition[2]))
		self.get_parent().add_child(fireball)
		
	if Input.is_action_pressed("move_left"):
		$AnimatedSprite2D.flip_h = true
		$AnimatedSprite2D.play("walk")
		direction = Vector2.LEFT
	elif Input.is_action_pressed("move_right"):
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.flip_h = false
		direction = Vector2.RIGHT
	else:
		$AnimatedSprite2D.stop()

func _physics_process(delta: float) -> void:
	
	velocity.x = 0
	if Input.is_action_pressed("move_left"):
		velocity.x = -1 * speed
	elif Input.is_action_pressed("move_right"):
		velocity.x = 1 * speed
		
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = -jump_impulse
	
	if not is_on_floor():
		velocity.y += fall_acceleration * delta

	for index in range(get_slide_collision_count()):
		var collider = get_slide_collision(index).get_collider()
		
		if collider == null:
			continue
		elif collider.is_in_group("gemme_group"):
			ammunition[0] += 1
			var gemme = collider
			gemme.delete()
	move_and_slide()
