class_name Sorcerer extends CharacterBody2D

const SPRITE_SIZE = 64

signal ammo_changed
signal life_changed

@export var speed: int = 400
var jump_pressed_time: float = 0.0
var is_jumping: bool = false
@export var max_jump_time: float = 0.3 # durée max que l'on peut "charger" le saut en secondes
@export var jump_impulse_min: int = 600 # saut minimal
@export var jump_impulse_max: int = 5000 # saut maximal
@export var fall_acceleration: int = 3000
@export var sorcerer_color: GlobalEnum.SorcererColor
var controller_id: int = 0

const attack_launcher_script = preload("res://scripts/spawner_attack.gd")
var damage_label_scene = preload("res://scenes/hud_damage_label.tscn")

var lives: int = 3
var screen_size: Vector2
var direction: Vector2 = Vector2.RIGHT
var ammunitions: Array = [3, 3, 3]
var animation_suffix: String
var can_fire: bool = true
var can_take_damage: bool = true
var level_scale: Vector2

var attacks

var is_jump_long_press: bool = false

var current_state: GlobalEnum.State = GlobalEnum.State.IDLE

func _ready() -> void:
	print(Input.get_connected_joypads())
	screen_size = get_viewport_rect().size
	level_scale = get_parent().transform.get_scale()
	position = (1.4 * screen_size / 2) + Vector2(controller_id * 64, 128)
	position += Vector2(0, SPRITE_SIZE * controller_id)
	load_data()
	lives = 3

	match sorcerer_color :
		GlobalEnum.SorcererColor.Blue:
			animation_suffix = "blue"
		GlobalEnum.SorcererColor.Red:
			animation_suffix = "red"
		GlobalEnum.SorcererColor.Green:
			animation_suffix = "green"
		GlobalEnum.SorcererColor.Yellow:
			animation_suffix = "yellow"
	$AnimatedSprite2D.play("walk_" + animation_suffix)


func set_state(new_state: GlobalEnum.State) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	
	match current_state:
		GlobalEnum.State.IDLE:
			$AnimatedSprite2D.play("idle_" + animation_suffix)
			
		GlobalEnum.State.RUN:
			$AnimatedSprite2D.play("walk_" + animation_suffix)
			
		GlobalEnum.State.JUMP:
			$AnimatedSprite2D.play("jump_" + animation_suffix)
			
		GlobalEnum.State.FALL:
			$AnimatedSprite2D.play("fall_" + animation_suffix)
			
		
func _process(_delta: float) -> void:
	var new_direction = Vector2(Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_X), Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_Y))
	if new_direction.length() > 0.2:
		direction = new_direction
	else:
		direction = Vector2(Vector2.RIGHT.dot(direction), 0.00001).normalized() * 0.1
	if direction.x < -0.2:
		$AnimatedSprite2D.flip_h = true
	elif direction.x > 0.2:
		$AnimatedSprite2D.flip_h = false


	if can_fire:
		if Input.is_joy_button_pressed(controller_id, JOY_BUTTON_X):
			fire_attack(GlobalEnum.AttackFamily.Red)
		elif Input.is_joy_button_pressed(controller_id, JOY_BUTTON_Y):
			fire_attack(GlobalEnum.AttackFamily.Blue)
		elif Input.is_joy_button_pressed(controller_id, JOY_BUTTON_B):
			fire_attack(GlobalEnum.AttackFamily.Yellow)
			
	if !Input.is_joy_button_pressed(controller_id, JOY_BUTTON_A):
		is_jump_long_press = false;

	

func _physics_process(delta: float) -> void:

	# Mouvements horizontaux
	if Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_X) < -0.2:
		velocity.x = -speed
	elif Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_X) > 0.2:
		velocity.x = speed
	else:
		velocity.x = 0

	# Saut + nuancier
	if is_on_floor() and Input.is_joy_button_pressed(controller_id, JOY_BUTTON_A) and !is_jump_long_press:
		is_jump_long_press = true
		jump_pressed_time = 0.0
		velocity.y = -jump_impulse_min
		set_state(GlobalEnum.State.JUMP)

	if Input.is_joy_button_pressed(controller_id, JOY_BUTTON_A) and is_jump_long_press:
		jump_pressed_time += delta
		if jump_pressed_time <= max_jump_time:
			var t = jump_pressed_time / max_jump_time
			var jump_boost = (jump_impulse_max - jump_impulse_min) * (1 - t) * delta
			velocity.y -= jump_boost

	# Gravité
	if not is_on_floor():
		velocity.y += fall_acceleration * delta

	# Physique
	move_and_slide()


	# Mise à jour des états
	if is_on_floor():
		if abs(velocity.x) > 0:
			set_state(GlobalEnum.State.RUN)
		else:
			set_state(GlobalEnum.State.IDLE)
	else:
		if velocity.y > 0:
			set_state(GlobalEnum.State.FALL)


func set_attack(attack_family: GlobalEnum.AttackFamily, attack_type: GlobalEnum.AttackType, attack_tier: GlobalEnum.AttackTier) -> void:
	attacks[attack_family]["attack_type"] = attack_type
	attacks[attack_family]["attack_tier"] = attack_tier
	print("Mon attaque est maintenant " + str(attack_type) + " et de tier " + str(attack_tier))

func fire_attack(attack_family: GlobalEnum.AttackFamily) -> void:
	var attack_launcher = attack_launcher_script.new()
	
	if ammunitions[attack_family] > 0:
		
		var attack_type: GlobalEnum.AttackType = attacks[attack_family]["attack_type"]
		var attack_tier: GlobalEnum.AttackTier = attacks[attack_family]["attack_tier"]

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
	export_data()
	queue_free()


func export_data() -> void :
	GlobalInfo.run_info["players_info"][controller_id] = {
		"lives": lives,
		"ammunitions": ammunitions,
		"attacks": attacks
	}

func load_data() -> void:
	var data_to_load = GlobalInfo.run_info["players_info"]["default"].duplicate(true)
	if controller_id in GlobalInfo.run_info["players_info"].keys():
		data_to_load = GlobalInfo.run_info["players_info"][controller_id]
		
	lives = data_to_load["lives"]
	ammunitions = data_to_load["ammunitions"]
	attacks = data_to_load["attacks"]

func _on_attack_cooldown_timeout() -> void:
	can_fire = true


func _on_damage_cooldown_timeout() -> void:
	can_take_damage = true

func _on_save_data() -> void:
	export_data()
