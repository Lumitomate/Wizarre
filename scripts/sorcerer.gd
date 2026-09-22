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

# --- Wall slide / Wall jump ---
@export var wall_slide_max_fall_speed: int = 150 # vitesse de chute max pendant une glissade contre un mur
@export var wall_slide_max_duration: float = 0.5 # durée max de la glissade ralentie (ensuite on re-chute normalement)
@export var wall_jump_impulse: int = 900 # impulsion verticale fixe du wall jump (plus haut que jump_impulse_min)
@export var wall_jump_horizontal_impulse: int = 500 # impulsion horizontale de base, opposée au mur
@export var wall_jump_stick_influence: float = 0.4 # à quel point le stick modifie la direction du wall jump
@export var sorcerer_color: GlobalEnum.SorcererColor
var controller_id: int = 0
# Device physique dont on lit les entrées : distinct de controller_id
# (identité/données immuables) pour qu'une manette de remplacement puisse
# prendre le contrôle d'un joueur déconnecté. -1 = non initialisé.
var input_device: int = -1
# Sorcier d'affichage (écran de pause) : idle + soulèvement de tuyaux
# uniquement — ni physique, ni déplacement, ni saut, ni attaque, ni dash
var frozen: bool = false

# --- Dash ---
@export var dash_speed: int = 1200
@export var dash_duration: float = 0.1 # durée du dash en secondes
@export var dash_cooldown: float = 1.0 # temps avant de pouvoir redasher
@export var dash_invisible_alpha: float = 0.25 # transparence pendant le dash
@export var dash_invincible: bool = true # optionnel : intouchable pendant le dash
@export var dash_invincible_after_duration: float = 0.5 # temps d'invincibilité après le dash
@export var dash_ignore_groups: Array[String] = ["enemy_group", "player_group"] # groupes à traverser pendant le dash
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

var damage_label_scene: PackedScene = preload("res://scenes/hud/hud_damage_label.tscn")

var lives: int = 3
var screen_size: Vector2
var direction: Vector2 = Vector2.RIGHT
var energy_counts: Array = [3, 3, 3]  # Fossil, Pure, Tainted
# Maximum de munitions par tube (0 à 4 : le HUD ne couvre que cet intervalle)
const MAX_ENERGY := 4
var in_shop: bool = false
# Tuyaux soulevables hors boutique (écran home) : X/Y/B font sortir les
# tuyaux comme en boutique, sans pouvoir tirer
var tubes_selectable: bool = false
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

# --- Wall slide / Wall jump ---
var is_wall_sliding: bool = false # vrai pendant une glissade contre un mur
var wall_slide_timer: float = 0.0 # temps de glissade accumulé pour la durée max
var jump_button_prev: bool = false # état du bouton A à la frame précédente (front montant pour le wall jump)
var last_wall_jump_side: int = 0 # côté du mur du dernier wall jump (-1 = mur à gauche, +1 = mur à droite) ; 0 = réarmé (sol touché)

var current_state: GlobalEnum.State = GlobalEnum.State.IDLE
# Vrai tant que l'animation d'attaque cosmétique est en cours (elle est
# alors coupée par un changement d'état, ou relancée par un nouveau tir)
var is_playing_attack: bool = false

var is_hit_flash: bool = false
var hit_flash_timer: float = 0.0
var hit_knockback_velocity: Vector2 = Vector2.ZERO
var hit_knockback_timer: float = 0.0
var hit_flash_duration: float = 0.5  # durée totale du flash
var hit_flash_interval: float = 0.05  # intervalle de clignotement

func _ready() -> void:
	add_to_group("player_group")
	screen_size = get_viewport_rect().size
	level_scale = get_parent().transform.get_scale()
	var slot := PlayerManager.get_player_slot(controller_id)
	# Apparition à la porte d'entrée du terrain1 si la scène en contient une
	# (level, magasins) : les joueurs sont écartés autour de la porte selon
	# leur rang. Sinon (Home, écran de pause) : ancien point central.
	var entry_door: Node2D = get_parent().get_node_or_null("Terrain1PortesEntree")
	if entry_door != null:
		var active_ids := PlayerManager.active_player_ids()
		var rank: int = active_ids.find(controller_id)
		if rank == -1:
			rank = slot
		var player_count: int = maxi(1, active_ids.size())
		position = entry_door.position \
				+ Vector2((rank - (player_count - 1) / 2.0) * 64.0, -SPRITE_SIZE * 2.0)
	else:
		position = (1.4 * screen_size / 2) + Vector2(slot * 64, 128)
		position += Vector2(0, SPRITE_SIZE * slot)
	if input_device == -1:
		input_device = controller_id
	load_data()
	lives = 3

	$AnimatedSprite2D.play("walk")

	if not $AnimatedSprite2D.animation_finished.is_connected(_on_attack_animation_finished):
		$AnimatedSprite2D.animation_finished.connect(_on_attack_animation_finished)

	$DashDuration.wait_time = dash_duration
	$DashDuration.one_shot = true
	if not $DashDuration.timeout.is_connected(_on_dash_duration_timeout):
		$DashDuration.timeout.connect(_on_dash_duration_timeout)
	$DashCooldown.wait_time = dash_cooldown
	$DashCooldown.one_shot = true
	if not $DashCooldown.timeout.is_connected(_on_dash_cooldown_timeout):
		$DashCooldown.timeout.connect(_on_dash_cooldown_timeout)

	# Matériau créé à chaud (et non réutilisé depuis le .tscn) : les
	# sous-ressources d'une scène sont partagées entre toutes les instances,
	# or chaque joueur a besoin de ses propres couleurs de shader
	dash_shader_material = ShaderMaterial.new()
	dash_shader_material.shader = preload("res://assets/shaders/wizard_color.gdshader")
	WizardPalette.apply_to_material(dash_shader_material, sorcerer_color)
	$AnimatedSprite2D.material = dash_shader_material


func set_state(new_state: GlobalEnum.State) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	is_playing_attack = false
	_play_state_animation(new_state)


func _play_state_animation(state: GlobalEnum.State) -> void:
	match state:
		GlobalEnum.State.IDLE:
			$AnimatedSprite2D.play("idle")
			
		GlobalEnum.State.RUN:
			$AnimatedSprite2D.play("walk")
			
		GlobalEnum.State.JUMP:
			$AnimatedSprite2D.play("jump")
			
		GlobalEnum.State.FALL:
			$AnimatedSprite2D.play("fall")


func _play_attack_animation() -> void:
	var sprite := $AnimatedSprite2D
	is_playing_attack = true
	# stop() pour rejouer depuis la frame 0 si une attaque est déjà en cours
	sprite.stop()
	sprite.play("attack_fire")


func _on_attack_animation_finished() -> void:
	if not is_playing_attack:
		return
	is_playing_attack = false
	# Retour automatique à l'animation de l'état courant
	_play_state_animation(current_state)
			
		
func _process(_delta: float) -> void:
	# Détection front montant (juste-appuyé) pour les 3 boutons de tube,
	# mise à jour chaque frame pour ne rater aucun appui
	var jx := _tube_button_just_pressed(0)
	var jy := _tube_button_just_pressed(1)
	var jb := _tube_button_just_pressed(2)

	if frozen:
		# Sorcier d'affichage (écran de pause) : uniquement le soulèvement
		# des tuyaux ; le bouton de saut est réservé à la jauge Reprendre
		if jx:
			select_tube(0)
		elif jy:
			select_tube(1)
		elif jb:
			select_tube(2)
		return

	var new_direction = PlayerInput.direction(input_device)
	if new_direction.length() > 0.2:
		direction = new_direction
	else:
		direction = Vector2(Vector2.RIGHT.dot(direction), 0.00001).normalized() * 0.1
	if direction.x < -0.2:
		$AnimatedSprite2D.flip_h = true
	elif direction.x > 0.2:
		$AnimatedSprite2D.flip_h = false

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
	elif tubes_selectable and not is_dashing:
		# Écran home (et autres écrans sans tir) : les tuyaux se soulèvent
		# comme en boutique, sans déclencher d'attaque
		if jx:
			select_tube(0)
		elif jy:
			select_tube(1)
		elif jb:
			select_tube(2)

	if can_dash and not is_dashing:
		if PlayerInput.button_pressed(input_device, PlayerInput.Action.DASH):
			start_dash()
			
	if not PlayerInput.button_pressed(input_device, PlayerInput.Action.JUMP):
		is_jump_long_press = false

	

func _physics_process(delta: float) -> void:
	# Sorcier d'affichage : aucune physique (il resterait sinon en chute
	# sur l'écran de pause, et le bouton de saut le ferait sauter)
	if frozen:
		return

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

	# Ciblage L2 en cours : le sorcier est immobile (c'est la cible qui est
	# pilotée par le stick), mais la gravité continue s'il était en l'air.
	# Le second appui sur le tube L2 (explosion) reste géré dans _process/fire_attack.
	if _get_own_light_target() != null:
		velocity.x = 0
		if not is_on_floor():
			velocity.y += fall_acceleration * delta
		move_and_slide()
		set_state(GlobalEnum.State.FALL if not is_on_floor() else GlobalEnum.State.IDLE)
		return

	# Mouvements horizontaux
	var axis := PlayerInput.direction(input_device)
	if axis.x < -0.2:
		velocity.x = -speed
	elif axis.x > 0.2:
		velocity.x = speed
	else:
		velocity.x = 0

	# Saut + nuancier
	if is_on_floor() and PlayerInput.button_pressed(input_device, PlayerInput.Action.JUMP) and !is_jump_long_press:
		is_jump_long_press = true
		jump_pressed_time = 0.0
		velocity.y = -jump_impulse_min
		set_state(GlobalEnum.State.JUMP)

	# --- Dead Cells style hit flash & blink ---
	if is_hit_flash:
		_update_hit_flash(delta)

	# Knockback basé sur la direction du dash
	if hit_knockback_timer > 0:
		hit_knockback_timer -= delta
		velocity = hit_knockback_velocity
		# Le knockback décroît progressivement
		hit_knockback_velocity = hit_knockback_velocity.lerp(Vector2.ZERO, delta * 8.0)
		move_and_slide()
		# Pendant le knockback, on ignore les inputs et la gravité
		return

	if PlayerInput.button_pressed(input_device, PlayerInput.Action.JUMP) and is_jump_long_press:
		jump_pressed_time += delta
		if jump_pressed_time <= max_jump_time:
			var t = jump_pressed_time / max_jump_time
			var jump_boost = (jump_impulse_max - jump_impulse_min) * (1 - t) * delta
			velocity.y -= jump_boost

	# Détection du mur (1A) : on cherche une collision quasi verticale
	# (normale horizontale) pour connaître le côté du mur.
	# is_on_wall() reflète le move_and_slide de la frame précédente.
	var wall_side := 0
	if not is_on_floor() and is_on_wall():
		for i in get_slide_collision_count():
			var normal := get_slide_collision(i).get_normal()
			if abs(normal.x) > 0.7 and abs(normal.y) < 0.5:
				# normale pointant vers la droite → mur à notre gauche, et inversement
				wall_side = -1 if normal.x > 0 else 1
				break

	# Glissade (1A) : en l'air, collé au mur, stick poussé vers le mur.
	# La glissade ralentie est limitée dans le temps : au-delà de
	# wall_slide_max_duration on re-chute normalement (le wall jump reste possible).
	var axis_x := axis.x
	var touching_wall := wall_side != 0 and axis_x * wall_side > 0.2 and velocity.y > 0
	if touching_wall:
		wall_slide_timer += delta
	else:
		wall_slide_timer = 0.0 # on repose le compteur dès qu'on quitte le mur
	is_wall_sliding = touching_wall and wall_slide_timer <= wall_slide_max_duration

	# Gravité (réduite pendant la glissade : la chute est plafonnée)
	if not is_on_floor():
		if is_wall_sliding:
			velocity.y = min(velocity.y + fall_acceleration * delta, wall_slide_max_fall_speed)
		else:
			velocity.y += fall_acceleration * delta

	# Wall jump (2B/3B/4) : A en l'air au contact d'un mur.
	# Front montant uniquement : maintenir A ne déclenche pas le wall jump,
	# il faut un nouvel appui (sinon un saut au sol suivi du maintien de A
	# contre un mur redéclencherait un wall jump automatiquement).
	var jump_button_pressed := PlayerInput.button_pressed(input_device, PlayerInput.Action.JUMP)
	var jump_button_just_pressed := jump_button_pressed and not jump_button_prev
	jump_button_prev = jump_button_pressed
	if not is_on_floor() and wall_side != 0 and jump_button_just_pressed:
		# 2B : un seul wall jump par mur — l'autre mur ou le sol réarme
		if last_wall_jump_side != wall_side:
			last_wall_jump_side = wall_side

			# 4 : impulsion diagonale opposée au mur, légèrement modulée par le stick.
			# Pousser plus loin du mur écarte la trajectoire, pousser vers le mur la resserre,
			# mais impossible de sauter DANS le mur.
			var jump_h := float(-wall_side)
			if abs(axis_x) > 0.2:
				jump_h = clampf(jump_h + axis_x * wall_jump_stick_influence, -1.0, 1.0)

			velocity.x = jump_h * wall_jump_horizontal_impulse
			velocity.y = -wall_jump_impulse
			# 3B : impulsion fixe, on bloque le nuancier (pas de boost en maintenant A)
			is_jump_long_press = true
			jump_pressed_time = max_jump_time
			set_state(GlobalEnum.State.JUMP)

	# Physique
	move_and_slide()

	# Mise à jour des états
	if is_on_floor():
		last_wall_jump_side = 0 # le sol réarme le wall jump (2B)
		if abs(velocity.x) > 0:
			set_state(GlobalEnum.State.RUN)
		else:
			set_state(GlobalEnum.State.IDLE)
	else:
		if velocity.y > 0:
			set_state(GlobalEnum.State.FALL)


func _update_hit_flash(delta: float) -> void:
	hit_flash_timer += delta
	# Clignotement: alterne entre rouge et transparent
	var blink := fmod(hit_flash_timer, hit_flash_interval * 2.0)
	if blink < hit_flash_interval:
		$AnimatedSprite2D.modulate = Color(2.0, 0.3, 0.3, 0.7)  # rouge
	else:
		$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 0.4)  # transparent
	if hit_flash_timer >= hit_flash_duration:
		is_hit_flash = false
		hit_flash_timer = 0.0
		$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 1.0)  # reset


func spawn_dash_afterimage() -> void:
	var afterimage = Sprite2D.new()
	afterimage.texture = $AnimatedSprite2D.sprite_frames.get_frame_texture($AnimatedSprite2D.animation, $AnimatedSprite2D.frame)

	get_parent().add_child(afterimage) # on l'ajoute à l'arbre AVANT de fixer son transform global

	afterimage.global_position = $AnimatedSprite2D.global_position
	afterimage.global_rotation = $AnimatedSprite2D.global_rotation
	afterimage.global_scale = $AnimatedSprite2D.global_scale
	afterimage.flip_h = $AnimatedSprite2D.flip_h
	afterimage.z_index = z_index + 10 # au-dessus de tout pour être visible

	# Dupliqué pour hériter aussi des couleurs du shader (sinon les
	# traînées de dash apparaîtraient avec la palette rouge de base)
	var afterimage_material: ShaderMaterial = dash_shader_material.duplicate()
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
	# Dasher pendant un ciblage (arc L3 ou cible L2) annule l'attaque
	# (munition rendue)
	_cancel_light_bow()
	_cancel_light_target()
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
	for body in get_tree().get_nodes_in_group("player_group"):
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
	# Le tier d'une attaque dépend du nombre d'attaques du même élément :
	# on re-normalise pour que TOUTES les attaques de cet élément montent
	# au bon tier (collecter un 2e feu passe aussi le 1er feu en tier II)
	SpellRules.normalize_spell_tiers(spells)
	var t: int = spells[tube_index]["attack_tier"]
	# Notifie le sac pour mettre à jour l'icône du sort dans le tube
	if has_node("SorcererSac"):
		$SorcererSac.set_spell(tube_index, attack_type, t)

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
	
	# Pendant un ciblage (L2 ou L3), le sorcier ne peut pas lancer une autre
	# attaque : seul le second appui sur le tube du ciblage en cours est
	# autorisé (le L3 reste libre de ses mouvements, lui)
	var own_light_target := _get_own_light_target()
	var own_light_bow := _get_own_light_bow()
	if own_light_bow != null and attack_type != GlobalEnum.AttackType.L3:
		return
	if own_light_target != null and attack_type != GlobalEnum.AttackType.L2:
		return
	
	# Cible lumineuse L2 : le 2e appui déclenche l'explosion du curseur
	if attack_type == GlobalEnum.AttackType.L2:
		var light_target := own_light_target
		if light_target != null:
			light_target.start_explosion()
			fire_wait_release[tube_index] = true
			return

	# Arc lumineux L3 : le 2e appui tire la flèche
	if attack_type == GlobalEnum.AttackType.L3 and own_light_bow != null:
		if not own_light_bow.try_shoot():
			# Tir annulé (sorcier trop proche de l'arc) : l'arc disparaît
			# et la munition du tube est rendue
			add_energy(tube_index, 1)
		# Verrou de relâchement : éviter un nouveau tir tant que le bouton
		# est maintenu
		fire_wait_release[tube_index] = true
		return

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
	_play_attack_animation()
	
	# Après la pose d'une mine : attendre le relâchement du bouton avant
	# le prochain tir (le 2e appui servira à déclencher l'explosion)
	if attack_type == GlobalEnum.AttackType.F3:
		fire_wait_release[tube_index] = true
	
	var attack_list := AttackSpawner.spawn_attack(attack_type, attack_tier, position, direction, screen_size, level_scale, self)
	for attack in attack_list:
		self.get_parent().add_child(attack)

# Lit le bouton d'attaque du tube : renvoie true seulement si
# le bouton est pressé ET que le verrou de relâchement n'est pas actif.
# Si le verrou est actif, il se lève dès que le bouton est relâché.
func _fire_button_pressed(tube_index: int) -> bool:
	var pressed := PlayerInput.button_pressed(input_device, _tube_button(tube_index))
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
func _tube_button_just_pressed(tube_index: int) -> bool:
	var pressed := PlayerInput.button_pressed(input_device, _tube_button(tube_index))
	var was_pressed: bool = tube_buttons_prev.get(tube_index, false)
	tube_buttons_prev[tube_index] = pressed
	return pressed and not was_pressed


## Bouton logique d'un tube d'attaque (0/1/2 → ATK1/ATK2/ATK3)
func _tube_button(tube_index: int) -> PlayerInput.Action:
	match tube_index:
		0: return PlayerInput.Action.ATK1
		1: return PlayerInput.Action.ATK2
		_: return PlayerInput.Action.ATK3

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

# Cherche la cible lumineuse posée par CE joueur encore en phase TARGETING
func _get_own_light_target() -> AttackLightTarget:
	for node in get_tree().get_nodes_in_group("light_target_group"):
		var target := node as AttackLightTarget
		if target != null and target.caster == self and target.phase == AttackLightTarget.Phase.TARGETING:
			return target
	return null

# Cherche l'arc lumineux planté par CE joueur encore en phase TARGETING
func _get_own_light_bow() -> AttackLightBow:
	for node in get_tree().get_nodes_in_group("light_bow_group"):
		var bow := node as AttackLightBow
		if bow != null and bow.caster == self and bow.phase == AttackLightBow.Phase.TARGETING:
			return bow
	return null

# Annule l'arc lumineux planté par CE joueur et rend la munition du tube
# qui le porte (le ciblage a déjà coûté 1 munition au 1er appui)
func _cancel_light_bow() -> void:
	var bow := _get_own_light_bow()
	if bow == null:
		return
	for i in range(3):
		var spell: Dictionary = spells[i]
		if not spell.is_empty() and spell["attack_type"] == GlobalEnum.AttackType.L3:
			add_energy(i, 1)
			break
	bow.cancel()

# Annule la cible lumineuse (L2) de CE joueur et rend la munition du tube
# qui la porte (le ciblage a déjà coûté 1 munition au 1er appui)
func _cancel_light_target() -> void:
	var target := _get_own_light_target()
	if target == null:
		return
	for i in range(3):
		var spell: Dictionary = spells[i]
		if not spell.is_empty() and spell["attack_type"] == GlobalEnum.AttackType.L2:
			add_energy(i, 1)
			break
	target.cancel()

func add_energy(tube_index: int, amount: int) -> void:
	energy_counts[tube_index] = min(energy_counts[tube_index] + amount, MAX_ENERGY)
	ammo_changed.emit(tube_index, energy_counts[tube_index])
	


func hit(damage: int) -> void:
	if can_take_damage:
		lives -= damage
		var damage_label = damage_label_scene.instantiate()
		damage_label.position = level_scale * (position - Vector2(0, 64))
		life_changed.emit(lives)
		if lives == 0:
			die()
		$DamageCooldown.start()
		can_take_damage = false
		# --- Dead Cells style damage feedback ---
		is_hit_flash = true
		hit_flash_timer = 0.0  # délai avant le premier flash
		# Flash rouge identique à celui du monstre (enemy_flying.gd) :
		# montée au rouge vif en 0,05 s puis retour à la normale en 0,15 s.
		# Passe par self_modulate pour ne pas interférer avec le modulate
		# utilisé par le clignotement
		$AnimatedSprite2D.self_modulate = Color.WHITE
		var red_flash := create_tween()
		red_flash.tween_property($AnimatedSprite2D, "self_modulate", Color(1.0, 0.1, 0.1, 1.0), 0.05)
		red_flash.tween_property($AnimatedSprite2D, "self_modulate", Color.WHITE, 0.15)
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
		# --- Fin ---


func die() -> void:
	export_data()
	# Le sorcier disparaît mais la partie continue tant qu'il reste au
	# moins un joueur en vie : seul la mort de TOUS les joueurs ramène à
	# l'écran d'accueil
	queue_free()
	if not _other_players_alive():
		# Game over : la run est finie, on repart des sorts par défaut.
		# Sans ça, les sorts exportés à la mort (export_data) seraient
		# rechargés par load_data au prochain spawn.
		GlobalInfo.reset_players_spells()
		Global.goto_scene(GlobalEnum.Location.HOMEPAGE)


# Y a-t-il encore au moins un joueur (autre que ce sorcier) en vie ?
# Les joueurs morts ont été libérés (queue_free) : leur référence reste
# dans PlayerManager.players mais est invalide, d'où le is_instance_valid.
# La variable n'est volontairement PAS typée : assigner une instance
# libérée à une variable typée plante avant même la vérification.
func _other_players_alive() -> bool:
	for id in PlayerManager.known_controllers:
		if id == controller_id:
			continue
		var player = PlayerManager.players.get(id)
		if player != null and is_instance_valid(player) and player.is_inside_tree():
			return true
	return false


func export_data() -> void:
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
	SpellRules.normalize_spell_tiers(spells)
	
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
