class_name Sorcerer extends CharacterBody2D

enum SorcererColor {
	Blue,
	Red,
	Green,
	Yellow
}

@export var speed: int = 500
@export var jump_impulse: int = 1500
@export var fall_acceleration: int = 5000
@export var sorcerer_color: SorcererColor = SorcererColor.Blue
@export var controller_id: int = 0
@export var lives: int = 3

var fireball_scene = preload("res://attack_fireball.tscn")

var screen_size: Vector2
var direction: Vector2 = Vector2.RIGHT
var ammunition: Array = [3, 3, 3]
var animation_suffix: String
var can_fire: bool = true

func _ready() -> void:
	screen_size = get_viewport_rect().size
	position = screen_size / 2
	position += Vector2(0, 64 * controller_id)

	match sorcerer_color :
		SorcererColor.Blue:
			animation_suffix = "blue"
		SorcererColor.Red:
			animation_suffix = "red"
		SorcererColor.Green:
			animation_suffix = "green"
		SorcererColor.Yellow:
			animation_suffix = "yellow"
	$AnimatedSprite2D.play("walk_" + animation_suffix)

func _process(_delta: float) -> void:
	if Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_X) < -0.2:
		$AnimatedSprite2D.flip_h = true
		$AnimatedSprite2D.play("walk_" + animation_suffix)
		direction = Vector2.LEFT
	elif Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_X) > 0.2:
		$AnimatedSprite2D.flip_h = false
		$AnimatedSprite2D.play("walk_" + animation_suffix)
		direction = Vector2.RIGHT
	else:
		$AnimatedSprite2D.stop()
		
	if can_fire:
		if  (Input.is_joy_button_pressed(controller_id, JOY_BUTTON_B) and ammunition[0] > 0) or (Input.is_joy_button_pressed(controller_id, JOY_BUTTON_X) and ammunition[1] > 0) or (Input.is_joy_button_pressed(controller_id, JOY_BUTTON_Y) and ammunition[2] > 0):
			var fireball = fireball_scene.instantiate()
			fireball.position = position + 60 * direction
			fireball.direction = direction
			if Input.is_joy_button_pressed(controller_id, JOY_BUTTON_B):
				fireball.color_mod = Color(1, 0, 0)
				ammunition[0] -= 1
				print("Remaining red: " + str(ammunition[0]))

			elif Input.is_joy_button_pressed(controller_id, JOY_BUTTON_X):
				fireball.color_mod = Color(0, 1, 0)
				ammunition[1] -= 1
				print("Remaining green: " + str(ammunition[1]))

			elif Input.is_joy_button_pressed(controller_id, JOY_BUTTON_Y):
				fireball.color_mod = Color(0, 0, 1)
				ammunition[2] -= 1
				print("Remaining blue: " + str(ammunition[2]))

			$AttackCooldown.start()
			can_fire = false
			self.get_parent().add_child(fireball)

func _physics_process(delta: float) -> void:
	
	# Mouvements
	if Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_X) < -0.2:
		velocity.x = -1 * speed
	elif Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_X) > 0.2:
		velocity.x = 1 * speed
	else:
		velocity.x = 0
	
	# Sauts
	if is_on_floor() and Input.is_joy_button_pressed(controller_id, JOY_BUTTON_A):
		velocity.y = -jump_impulse
	
	if not is_on_floor():
		velocity.y += fall_acceleration * delta

	# Collisions
	for index in range(get_slide_collision_count()):
		var collider = get_slide_collision(index).get_collider()

		if collider == null:
			continue
		elif collider.is_in_group("gemme_group"):
			ammunition[0] += 1
			var gemme = collider
			gemme.delete()
		#elif collider.is_in_group("attack_group"):
			#print("Touché!")
			#lives -= 1
	
	# Gesion de la physique
	move_and_slide()

func hit(damage: int):
	lives -= damage
	print("Remaining lives:" + str(lives))
	if lives == 0:
		die()
	
func die():
	queue_free()

func _on_attack_cooldown_timeout() -> void:
	can_fire = true
