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

# --- Dash ---
@export var dash_speed: int = 1200
@export var dash_duration: float = 0.1 # durée du dash en secondes
@export var dash_cooldown: float = 1.0 # temps avant de pouvoir redasher
@export var dash_invisible_alpha: float = 0.25 # transparence pendant le dash
@export var dash_invincible: bool = true # optionnel : intouchable pendant le dash
@export var dash_ignore_groups: Array[String] = ["enemies", "players"] # groupes à traverser pendant le dash — adapte les noms à tes groupes existants
@export var dash_unstuck_distance: float = 40.0 # distance en dessous de laquelle on considère 2 joueurs "superposés" en fin de dash
@export var dash_unstuck_push: float = 24.0 # écart appliqué pour les séparer proprement
@export var dash_trail_interval: float = 0.01 # secondes entre deux images rémanentes
@export var dash_trail_fade_duration: float = 0.2 # temps de disparition d'une image rémanente
@export var dash_trail_start_alpha: float = 0.2 # opacité de départ d'une image rémanente

var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: Vector2 = Vector2.RIGHT
var dash_shader_material: ShaderMaterial
var dash_trail_accumulator: float = 0.0

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
	#print(Input.get_connected_joypads())
	add_to_group("players")
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

	$DashDuration.wait_time = dash_duration
	$DashDuration.one_shot = true
	if not $DashDuration.timeout.is_connected(_on_dash_duration_timeout):
		$DashDuration.timeout.connect(_on_dash_duration_timeout)
	$DashCooldown.wait_time = dash_cooldown
	$DashCooldown.one_shot = true
	if not $DashCooldown.timeout.is_connected(_on_dash_cooldown_timeout):
		$DashCooldown.timeout.connect(_on_dash_cooldown_timeout)

	dash_shader_material = ShaderMaterial.new()
	dash_shader_material.shader = preload("res://assets/shaders/dash_white.gdshader")
	$AnimatedSprite2D.material = dash_shader_material


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


	if can_fire and not is_dashing:
		if Input.is_joy_button_pressed(controller_id, JOY_BUTTON_X):
			fire_attack(GlobalEnum.AttackFamily.Red)
		elif Input.is_joy_button_pressed(controller_id, JOY_BUTTON_Y):
			fire_attack(GlobalEnum.AttackFamily.Blue)
		elif Input.is_joy_button_pressed(controller_id, JOY_BUTTON_B):
			fire_attack(GlobalEnum.AttackFamily.Yellow)

	if can_dash and not is_dashing:
		if Input.is_joy_button_pressed(controller_id, JOY_BUTTON_LEFT_SHOULDER):
			start_dash()
			
	if !Input.is_joy_button_pressed(controller_id, JOY_BUTTON_A):
		is_jump_long_press = false;

	

func _physics_process(delta: float) -> void:

	if is_dashing:
		velocity = dash_direction * dash_speed
		move_and_slide()
		if is_dash_blocked():
			stop_dash_on_collision()
			return

		dash_trail_accumulator += delta
		if dash_trail_accumulator >= dash_trail_interval:
			dash_trail_accumulator = 0.0
			spawn_dash_afterimage()
		return

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


func spawn_dash_afterimage() -> void:
	var afterimage = Sprite2D.new()
	afterimage.texture = $AnimatedSprite2D.sprite_frames.get_frame_texture($AnimatedSprite2D.animation, $AnimatedSprite2D.frame)

	get_parent().add_child(afterimage) # on l'ajoute à l'arbre AVANT de fixer son transform global

	afterimage.global_position = $AnimatedSprite2D.global_position
	afterimage.global_rotation = $AnimatedSprite2D.global_rotation
	afterimage.global_scale = $AnimatedSprite2D.global_scale
	afterimage.flip_h = $AnimatedSprite2D.flip_h
	afterimage.z_index = z_index - 1 # affiché derrière le joueur, ajuste si besoin

	var afterimage_material = ShaderMaterial.new()
	afterimage_material.shader = dash_shader_material.shader
	afterimage_material.set_shader_parameter("white_amount", 1.0)
	afterimage.material = afterimage_material
	afterimage.modulate.a = dash_trail_start_alpha

	var trail_tween = create_tween()
	trail_tween.tween_property(afterimage, "modulate:a", 0.0, dash_trail_fade_duration)
	trail_tween.tween_callback(afterimage.queue_free)


func is_dash_blocked() -> bool:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		# On ne considère bloquant que si la surface touchée s'oppose réellement
		# à la direction du dash (ex: un mur en pleine face), pas le sol quand on dash à l'horizontale
		if dash_direction.dot(collision.get_normal()) < -0.1:
			return true
	return false


func stop_dash_on_collision() -> void:
	if not is_dashing:
		return
	$DashDuration.stop() # on annule le temps de dash restant, on l'a déjà géré manuellement
	velocity = Vector2.ZERO # on ne garde pas l'élan du dash au moment de l'impact
	end_dash()


func start_dash() -> void:
	is_dashing = true
	can_dash = false

	# On dash dans la direction actuelle du stick, ou dans le sens du regard si le stick est au repos
	if direction.length() > 0.2:
		dash_direction = direction.normalized()
	else:
		dash_direction = Vector2($AnimatedSprite2D.flip_h and -1 or 1, 0)

	for group_name in dash_ignore_groups:
		for body in get_tree().get_nodes_in_group(group_name):
			if body != self and body is CollisionObject2D:
				add_collision_exception_with(body)

	$AnimatedSprite2D.modulate.a = dash_invisible_alpha
	dash_shader_material.set_shader_parameter("white_amount", 1.0)
	if dash_invincible:
		can_take_damage = false

	dash_trail_accumulator = 0.0
	spawn_dash_afterimage()

	$DashDuration.start()


func end_dash() -> void:
	is_dashing = false

	for group_name in dash_ignore_groups:
		for body in get_tree().get_nodes_in_group(group_name):
			if body != self and body is CollisionObject2D:
				remove_collision_exception_with(body)

	unstick_from_other_players()

	$AnimatedSprite2D.modulate.a = 1.0
	dash_shader_material.set_shader_parameter("white_amount", 0.0)
	if dash_invincible:
		can_take_damage = true
	$DashCooldown.start()


func unstick_from_other_players() -> void:
	for body in get_tree().get_nodes_in_group("players"):
		if body == self or not body is Node2D:
			continue
		var distance_to_body = position.distance_to(body.position)
		if distance_to_body < dash_unstuck_distance:
			var push_direction = position - body.position
			if push_direction.length() < 0.01:
				push_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			position += push_direction.normalized() * dash_unstuck_push


func set_attack(attack_family: GlobalEnum.AttackFamily, attack_type: GlobalEnum.AttackType, attack_tier: GlobalEnum.AttackTier) -> void:
	attacks[attack_family]["attack_type"] = attack_type
	attacks[attack_family]["attack_tier"] = attack_tier
	print("Mon attaque est maintenant " + str(attack_type) + " et de tier " + str(attack_tier))

func fire_attack(attack_family: GlobalEnum.AttackFamily) -> void:
	var attack_launcher = attack_launcher_script.new()
	
	if ammunitions[attack_family] > 0:
		
		var attack_type: GlobalEnum.AttackType = attacks[attack_family]["attack_type"]
		var attack_tier: GlobalEnum.AttackTier = attacks[attack_family]["attack_tier"]
		var attack_list = attack_launcher.spawn_attack(attack_type, attack_tier, position, direction, screen_size, level_scale, self)
		
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

func _on_dash_duration_timeout() -> void:
	end_dash()


func _on_dash_cooldown_timeout() -> void:
	can_dash = true

func _on_save_data() -> void:
	export_data()
