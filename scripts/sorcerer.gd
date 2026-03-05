class_name Sorcerer extends CharacterBody2D

const SPRITE_SIZE = 64

enum SorcererColor {
	Blue,
	Red,
	Green,
	Yellow
}

enum AttackFamily {
	Red,
	Green,
	Blue
}

signal ammo_changed

@export var speed: int = 500
@export var jump_impulse: int = 1500
@export var fall_acceleration: int = 4000
@export var sorcerer_color: SorcererColor = SorcererColor.Blue
@export var controller_id: int = 0
@export var lives: int = 3

const attack_launcher_script = preload("res://scripts/spawner_attack.gd")

var screen_size: Vector2
var direction: Vector2 = Vector2.RIGHT
var ammunitions: Array = [3, 3, 3]
var animation_suffix: String
var can_fire: bool = true
var can_take_damage: bool = true


func _ready() -> void:
	screen_size = get_viewport_rect().size
	position = screen_size / 2
	position += Vector2(0, SPRITE_SIZE * controller_id)

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
		if Input.is_joy_button_pressed(controller_id, JOY_BUTTON_B):
			fire_attack(AttackFamily.Red)
		elif Input.is_joy_button_pressed(controller_id, JOY_BUTTON_X):
			fire_attack(AttackFamily.Green)
		elif Input.is_joy_button_pressed(controller_id, JOY_BUTTON_Y):
			fire_attack(AttackFamily.Blue)


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
	
	# Gesion de la physique
	move_and_slide()


func fire_attack(attack_family:AttackFamily) -> void:
	var attack_launcher = attack_launcher_script.new()
	var scale: Vector2 = get_parent().transform.get_scale()
	
	if ammunitions[attack_family] > 0:
		
		var attack_type: int
		match attack_family:
			AttackFamily.Red:
				attack_type = attack_launcher.AttackType.FIREBALL
			AttackFamily.Green:
				attack_type = attack_launcher.AttackType.FIRECOLUMN
			AttackFamily.Blue:
				attack_type = attack_launcher.AttackType.LIGHTRAY

		var attack_list = attack_launcher.spawn_attack(attack_type, scale * position, direction, screen_size)

		ammunitions[attack_family] -= 1
		ammo_changed.emit(attack_family, ammunitions[attack_family])
		$AttackCooldown.start()
		can_fire = false
		for attack in attack_list:
			self.get_parent().add_child(attack)


func add_ammo(ammo_type: int, ammo_amount: int) -> void:
	ammunitions[ammo_type] += ammo_amount
	ammo_changed.emit(ammo_type, ammunitions[ammo_type])
	


func hit(damage: int):
	if can_take_damage:
		lives -= damage
		if lives == 0:
			die()
		$DamageCooldown.start()
		can_take_damage = false


func die():
	queue_free()


func _on_attack_cooldown_timeout() -> void:
	can_fire = true


func _on_damage_cooldown_timeout() -> void:
	can_take_damage = true
