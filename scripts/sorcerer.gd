class_name Sorcerer extends CharacterBody2D

const SPRITE_SIZE = 64

signal ammo_changed
signal life_changed

@export var speed: int = 400
@export var jump_impulse: int = 1000
@export var fall_acceleration: int = 3000
@export var sorcerer_color: Enum.SorcererColor
@export var controller_id: int = 0

const attack_launcher_script = preload("res://scripts/spawner_attack.gd")
var damage_label_scene = preload("res://scenes/damage_label.tscn")

var lives: int = 3
var screen_size: Vector2
var direction: Vector2 = Vector2.RIGHT
var ammunitions: Array = [3, 3, 3]
var animation_suffix: String
var can_fire: bool = true
var can_take_damage: bool = true
var level_scale: Vector2

var  competences = {
	"attack_red":
		{
			"attack_type" : Enum.AttackType.FIRECOLUMN,
			"attack_tier" : Enum.AttackTier.I
		},
	"attack_blue":
		{
			"attack_type" : Enum.AttackType.ICEBALL,
			"attack_tier" : Enum.AttackTier.I
		},
	"attack_yellow":
		{
			"attack_type" : Enum.AttackType.LIGHTRAY,
			"attack_tier" : Enum.AttackTier.I
		},
}

func _ready() -> void:
	print("pop")
	screen_size = get_viewport_rect().size
	level_scale = get_parent().transform.get_scale()
	position = screen_size / 2
	position += Vector2(0, SPRITE_SIZE * controller_id)

	match sorcerer_color :
		Enum.SorcererColor.Blue:
			animation_suffix = "blue"
		Enum.SorcererColor.Red:
			animation_suffix = "red"
		Enum.SorcererColor.Green:
			animation_suffix = "green"
		Enum.SorcererColor.Yellow:
			animation_suffix = "yellow"
	$AnimatedSprite2D.play("walk_" + animation_suffix)


func _process(_delta: float) -> void:
	var new_direction = Vector2(Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_X), Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_Y))
	if new_direction.length() > 0.2:
		direction = new_direction
	else:
		direction = Vector2(Vector2.RIGHT.dot(direction), 0.00001).normalized() * 0.1
	if direction.x < -0.2:
		$AnimatedSprite2D.flip_h = true
		$AnimatedSprite2D.play("walk_" + animation_suffix)
	elif direction.x > 0.2:
		$AnimatedSprite2D.flip_h = false
		$AnimatedSprite2D.play("walk_" + animation_suffix)
	else:
		$AnimatedSprite2D.stop()
		
	if can_fire:
		if Input.is_joy_button_pressed(controller_id, JOY_BUTTON_X):
			fire_attack(Enum.AttackFamily.Red)
		elif Input.is_joy_button_pressed(controller_id, JOY_BUTTON_Y):
			fire_attack(Enum.AttackFamily.Blue)
		elif Input.is_joy_button_pressed(controller_id, JOY_BUTTON_B):
			fire_attack(Enum.AttackFamily.Yellow)


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


func fire_attack(attack_family: Enum.AttackFamily) -> void:
	var attack_launcher = attack_launcher_script.new()
	
	if ammunitions[attack_family] > 0:
		
		var attack_type: int
		var attack_tier: int
		match attack_family:
			Enum.AttackFamily.Red:
				attack_type = competences["attack_red"]["attack_type"]
				attack_tier = competences["attack_red"]["attack_tier"]
			Enum.AttackFamily.Blue:
				attack_type = competences["attack_blue"]["attack_type"]
				attack_tier = competences["attack_blue"]["attack_tier"]
			Enum.AttackFamily.Yellow:
				attack_type = competences["attack_yellow"]["attack_type"]
				attack_tier = competences["attack_yellow"]["attack_tier"]

		var attack_list = attack_launcher.spawn_attack(attack_type, attack_tier, position, direction, screen_size, level_scale)

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
		var damage_label = damage_label_scene.instantiate()
		damage_label.position = level_scale * (position - Vector2(0, 64))
		get_parent().add_child(damage_label)
		life_changed.emit(lives)
		print("Je prends des dégats (" + str(lives) + ")")
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
