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
@export var dash_invincible_after_duration: float = 0.5 # temps d'invincibilité après le dash
@export var dash_ignore_groups: Array[String] = ["enemy_group", "players"] # groupes à traverser pendant le dash — adapte les noms à tes groupes existants
@export var dash_unstuck_distance: float = 40.0 # distance en dessous de laquelle on considère 2 joueurs "superposés" en fin de dash
@export var dash_unstuck_push: float = 24.0 # écart appliqué pour les séparer proprement
@export var dash_trail_interval: float = 0.01 # secondes entre deux images rémanentes
@export var dash_trail_fade_duration: float = 0.2 # temps de disparition d'une image rémanente
@export var dash_trail_start_alpha: float = 1.0 # opacité de départ d'une image rémanente (1.0 = 100%)

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
var energy_counts: Array = [3, 3, 3]  # Fossil, Pure, Tainted
var animation_suffix: String
var in_shop: bool = false
var selected_tube: int = -1
var can_fire: bool = true
var can_take_damage: bool = true
var level_scale: Vector2

# Après une détonation de mine, on attend le relâchement du bouton
# avant d'autoriser un nouveau tir (sinon le bouton encore maintenu
# re-pose une mine aussitôt)
var fire_wait_release := {
	0: false,  # Fossil (Tube 1)
	1: false,  # Pure (Tube 2)
	2: false,  # Tainted (Tube 3)
}

# État précédent des boutons de tube (front montant pour la sélection en boutique)
var tube_buttons_prev := {
	0: false,
	1: false,
	2: false,
}

var spells: Dictionary = {}

var is_jump_long_press: bool = false

var current_state: GlobalEnum.State = GlobalEnum.State.IDLE

var is_hit_flash: bool = false
var hit_flash_timer: float = 0.0
var hit_knockback_velocity: Vector2 = Vector2.ZERO
var hit_knockback_timer: float = 0.0
var hit_flash_duration: float = 0.5  # durée totale du flash
var hit_flash_interval: float = 0.05  # intervalle de clignotement
var original_modulate: Color = Color.WHITE

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


	# Détection front montant (juste-appuyé) pour les 3 boutons de tube,
	# mise à jour chaque frame pour ne rater aucun appui
	var jx := _tube_button_just_pressed(0, JOY_BUTTON_X)
	var jy := _tube_button_just_pressed(1, JOY_BUTTON_Y)
	var jb := _tube_button_just_pressed(2, JOY_BUTTON_B)

	if can_fire and not is_dashing:
		if jx:
			if in_shop:
				select_tube(0)
			else:
				fire_attack(0)
		elif jy:
			if in_shop:
				select_tube(1)
			else:
				fire_attack(1)
		elif jb:
			if in_shop:
				select_tube(2)
			else:
				fire_attack(2)

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

	# --- Dead Cells style hit flash & blink ---
	if is_hit_flash:
		hit_flash_timer += delta
		# Clignotement: alterne entre rouge et transparent
		var blink = fmod(hit_flash_timer, hit_flash_interval * 2.0)
		if blink < hit_flash_interval:
			$AnimatedSprite2D.modulate = Color(2.0, 0.3, 0.3, 0.7)  # rouge
		else:
			$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 0.4)  # transparent
		if hit_flash_timer >= hit_flash_duration:
			is_hit_flash = false
			hit_flash_timer = 0.0
			$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 1.0)  # reset

	# Knockback basé sur la direction du dash
	if hit_knockback_timer > 0:
		hit_knockback_timer -= delta
		velocity = hit_knockback_velocity
		# Le knockback décroît progressivement
		hit_knockback_velocity = hit_knockback_velocity.lerp(Vector2.ZERO, delta * 8.0)
		move_and_slide()
		# Pendant le knockback, on ignore les inputs et la gravité
		return

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

	# --- Dead Cells style hit flash & blink ---
	if is_hit_flash:
		hit_flash_timer += delta
		# Clignotement: alterne entre rouge et transparent
		var blink = fmod(hit_flash_timer, hit_flash_interval * 2.0)
		if blink < hit_flash_interval:
			$AnimatedSprite2D.modulate = Color(2.0, 0.3, 0.3, 0.7)  # rouge clair
		else:
			$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 0.4)  # transparent
		if hit_flash_timer >= hit_flash_duration:
			is_hit_flash = false
			hit_flash_timer = 0.0
			$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 1.0)  # reset
	# --- Fin du flash ---


func spawn_dash_afterimage() -> void:
	var afterimage = Sprite2D.new()
	afterimage.texture = $AnimatedSprite2D.sprite_frames.get_frame_texture($AnimatedSprite2D.animation, $AnimatedSprite2D.frame)

	get_parent().add_child(afterimage) # on l'ajoute à l'arbre AVANT de fixer son transform global

	afterimage.global_position = $AnimatedSprite2D.global_position
	afterimage.global_rotation = $AnimatedSprite2D.global_rotation
	afterimage.global_scale = $AnimatedSprite2D.global_scale
	afterimage.flip_h = $AnimatedSprite2D.flip_h
	afterimage.z_index = z_index + 10 # au-dessus de tout pour être visible

	var afterimage_material = ShaderMaterial.new()
	afterimage_material.shader = dash_shader_material.shader
	afterimage_material.set_shader_parameter("white_amount", 1.0)
	afterimage.material = afterimage_material
	afterimage.modulate.a = dash_trail_start_alpha

	# Crée le tween directement sur l'afterimage pour une meilleure gestion
	var trail_tween = afterimage.create_tween()
	trail_tween.set_parallel(false)
	trail_tween.set_trans(Tween.TRANS_LINEAR)
	trail_tween.set_ease(Tween.EASE_IN)
	trail_tween.tween_property(afterimage, "modulate:a", 0.0, dash_trail_fade_duration)
	trail_tween.tween_callback(Callable(afterimage, "queue_free"))


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
	dash_invincible = true

	# On dash dans la direction actuelle du stick, ou dans le sens du regard si le stick est au repos
	if direction.length() > 0.2:
		dash_direction = direction.normalized()
	else:
		dash_direction = Vector2($AnimatedSprite2D.flip_h and -1 or 1, 0)

	for group_name in dash_ignore_groups:
		for body in get_tree().get_nodes_in_group(group_name):
			if body != self and body is Node2D:
				add_collision_exception_with(body)

	$AnimatedSprite2D.modulate.a = dash_invisible_alpha
	dash_shader_material.set_shader_parameter("white_amount", 1.0)
	can_take_damage = false

	dash_trail_accumulator = 0.0
	spawn_dash_afterimage()

	$DashDuration.start()


func end_dash() -> void:
	is_dashing = false

	for group_name in dash_ignore_groups:
		for body in get_tree().get_nodes_in_group(group_name):
			if body != self and body is Node2D:
				remove_collision_exception_with(body)

	unstick_from_other_players()

	$AnimatedSprite2D.modulate.a = 1.0
	dash_shader_material.set_shader_parameter("white_amount", 0.0)
	# L'invincibilité continue après le dash via le timer
	$DashInvicibiliyAfter.wait_time = dash_invincible_after_duration
	$DashInvicibiliyAfter.start()
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


func set_attack(tube_index: int, attack_type: int, attack_tier: int) -> void:
	if tube_index < 0 or tube_index >= 3:
		return
	spells[tube_index] = {
		"attack_type": attack_type,
		"attack_tier": attack_tier
	}
	print("Mon sort dans le tube %d est maintenant %d de tier %d" % [tube_index, attack_type, attack_tier])
	# Notifie le sac pour mettre à jour l'icône du sort dans le tube
	if has_node("SorcererSac"):
		$SorcererSac.set_spell(tube_index, attack_type, attack_tier)

func fire_attack(tube_index: int) -> void:
	if tube_index < 0 or tube_index >= 3:
		return
	# Impossible de tirer pendant la phase de magasin
	if in_shop:
		return
	var spell = spells[tube_index]
	if spell.is_empty():
		return
	
	var attack_type: int = spell["attack_type"]
	var attack_tier: int = spell["attack_tier"]
	
	# Mine posée en idle par ce joueur : le 2e appui déclenche la chute
	# et l'explosion au lieu de poser une nouvelle mine (sans consommer d'énergie)
	if attack_type == GlobalEnum.AttackType.F3:
		var mine := _get_own_mine()
		if mine != null:
			mine.explode()
			# Verrou de relâchement : éviter le re-déclenchement tant que le bouton est maintenu
			fire_wait_release[tube_index] = true
			return
	
	# Consomme l'énergie du tube
	if energy_counts[tube_index] <= 0:
		return
	energy_counts[tube_index] -= 1
	ammo_changed.emit(tube_index, energy_counts[tube_index])
	$AttackCooldown.start()
	can_fire = false
	
	# Après la pose d'une mine : attendre le relâchement du bouton avant
	# le prochain tir (le 2e appui servira à déclencher l'explosion)
	if attack_type == GlobalEnum.AttackType.F3:
		fire_wait_release[tube_index] = true
	
	var attack_list = attack_launcher_script.new().spawn_attack(attack_type, attack_tier, position, direction, screen_size, level_scale, self)
	for attack in attack_list:
		self.get_parent().add_child(attack)

# Lit le bouton d'attaque du tube : renvoie true seulement si
# le bouton est pressé ET que le verrou de relâchement n'est pas actif.
# Si le verrou est actif, il se lève dès que le bouton est relâché.
func _fire_button_pressed(tube_index: int, button: JoyButton) -> bool:
	var pressed := Input.is_joy_button_pressed(controller_id, button)
	if fire_wait_release.get(tube_index, false):
		if not pressed:
			fire_wait_release[tube_index] = false
		return false
	return pressed

# Front montant : renvoie true uniquement à l'instant où le bouton passe
# de relâché à appuyé (un seul appel par appui, contrairement à is_joy_button_pressed
# qui renvoie true à chaque frame tant que le bouton est maintenu).
# Essentiel en boutique : sans ça, select_tube est rappelé chaque frame et
# le tube se referme aussitôt sorti.
func _tube_button_just_pressed(tube_index: int, button: JoyButton) -> bool:
	var pressed := Input.is_joy_button_pressed(controller_id, button)
	var was_pressed: bool = tube_buttons_prev.get(tube_index, false)
	tube_buttons_prev[tube_index] = pressed
	return pressed and not was_pressed

func select_tube(tube_index: int) -> void:
	if tube_index < 0 or tube_index >= 3:
		return
	selected_tube = tube_index
	# Délègue l'animation au sac (noms de nœuds et animations gérés par SorcererSac)
	$SorcererSac.select_tube(tube_index)

# Cherche une mine posée par CE joueur encore en phase idle
func _get_own_mine() -> AttackFireMine:
	for node in get_tree().get_nodes_in_group("fire_mine_group"):
		var mine := node as AttackFireMine
		if mine != null and mine.caster == self and mine.phase == AttackFireMine.Phase.IDLE:
			return mine
	return null

func add_energy(tube_index: int, amount: int) -> void:
	energy_counts[tube_index] += amount
	ammo_changed.emit(tube_index, energy_counts[tube_index])
	


func hit(damage: int):
	if can_take_damage:
		lives -= damage
		var damage_label = damage_label_scene.instantiate()
		damage_label.position = level_scale * (position - Vector2(0, 64))
		life_changed.emit(lives)
		print("Je prends des dégats (" + str(lives) + ")")
		if lives == 0:
			die()
		$DamageCooldown.start()
		can_take_damage = false
		# --- Dead Cells style damage feedback ---
		is_hit_flash = true
		hit_flash_timer = 0.0  # délai avant le premier flash
		hit_knockback_timer = 0.3  # durée du knockback (secondes)
		# Knockback basé sur la direction de l'ennemi (repoussé par lui)
		# On cherche l'ennemi le plus proche pour définir la direction du knockback
		var nearest_enemy = Vector2.ZERO
		var min_dist = 99999.0
		for node in get_tree().get_nodes_in_group("enemy_group"):
			if node is CharacterBody2D:
				var d = position.distance_to(node.position)
				if d < min_dist:
					min_dist = d
					nearest_enemy = (position - node.position).normalized()
		var kb_x = nearest_enemy.x * 1000.0
		var kb_y = nearest_enemy.y * 1000.0 - 200.0
		hit_knockback_velocity = Vector2(kb_x, kb_y)
		original_modulate = $AnimatedSprite2D.modulate
		# --- Fin ---


func die():
	export_data()
	queue_free()


func export_data() -> void :
	GlobalInfo.run_info["players_info"][controller_id] = {
		"lives": lives,
		"energy_counts": energy_counts,
		"spells": spells
	}

func load_data() -> void:
	var data_to_load = GlobalInfo.run_info["players_info"]["default"].duplicate(true)
	if controller_id in GlobalInfo.run_info["players_info"].keys():
		data_to_load = GlobalInfo.run_info["players_info"][controller_id]
		
	lives = data_to_load["lives"]
	energy_counts = data_to_load["energy_counts"]
	spells = data_to_load["spells"]
	
	# Le sac s'initialise avant le sorcier : on rafraîchit ses animations
	# avec les valeurs réellement chargées
	if has_node("SorcererSac"):
		$SorcererSac.refresh_all()

func _on_attack_cooldown_timeout() -> void:
	can_fire = true


func _on_damage_cooldown_timeout() -> void:
	can_take_damage = true
	# --- Fin du feedback de dégât ---

func _on_dash_duration_timeout() -> void:
	end_dash()


func _on_dash_invicibiliy_after_timeout() -> void:
	can_take_damage = true

func _on_dash_cooldown_timeout() -> void:
	can_dash = true

func _on_save_data() -> void:
	export_data()
