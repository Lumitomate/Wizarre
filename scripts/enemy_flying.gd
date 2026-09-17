class_name EnemyFlying extends CharacterBody2D


signal enemy_killed

@export var speed: int = 200
@export var lives: int = 1  # la scène enemy_flying.tscn est la référence en jeu

var target : Node2D = null
# Dernier sorcier à avoir infligé des dégâts (pour la représaille et le
# signalement du tueur à l'essaim)
var last_attacker: Node2D = null
var target_position: Vector2 = Vector2(0, 0)
var can_take_damage: bool = true
var is_bouncing: bool = false
var level_scale: Vector2
var screen_size: Vector2

var damage_label_scene = preload("res://scenes/hud/hud_damage_label.tscn")


func _ready() -> void:
	add_to_group("enemy_group")
	level_scale = get_parent().transform.get_scale()
	screen_size = get_viewport_rect().size
	if lives >= 2:
		$AnimatedSprite2D.play("2vies_2")
	else:
		$AnimatedSprite2D.play("default")
	
	$NavigationAgent2D.path_desired_distance = 20.0
	$NavigationAgent2D.target_desired_distance = 20.0
	$NavigationAgent2D.path_max_distance = 40.0
	
	enemy_setup.call_deferred()

func enemy_setup():
	# Wait for the first physics frame so the NavigationServer can sync.
	await get_tree().physics_frame
	set_navigation_target(Vector2(randi() % int(screen_size.x), randi() % int(screen_size.y)))

func set_navigation_target(target_position: Vector2):
	$NavigationAgent2D.target_position = target_position
	
func set_random_navigation_target():
	set_navigation_target(screen_size / 4 + Vector2(randi() % int(screen_size.x / 2), randi() % int(screen_size.y / 2)))

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		if target == null or position.distance_to(target.position) > position.distance_to(body.position):
			target = body


func _process(_delta: float) -> void:
	if !is_bouncing:
		if velocity.x > 0:
			$AnimatedSprite2D.flip_h = true
		elif velocity.x < 0:
			$AnimatedSprite2D.flip_h = false
	
	if target != null:
		set_navigation_target(target.global_position)


func _physics_process(delta: float) -> void:
	if $NavigationAgent2D.is_navigation_finished():
		set_random_navigation_target()
		
	var next_path_position: Vector2 = $NavigationAgent2D.get_next_path_position()
	var velocity_trg = _desired_direction(next_path_position) * speed
	if velocity.dot(velocity_trg) <= 0 or velocity.length() < velocity_trg.length():
		velocity += 5 * velocity_trg * delta
	else:
		velocity = velocity_trg
	
		# Collisions
	for index in range(get_slide_collision_count()):
		var collider = get_slide_collision(index).get_collider()

		if collider == null:
			continue
		elif collider.is_in_group("player_group"):
			var player: Sorcerer = collider
			player.hit(1)
			bounce_on(player)

	move_and_slide()


# Direction de déplacement souhaitée vers le prochain point de chemin.
# Point d'extension pour les variantes (ex : EnemyFly ajoute la cohésion
# d'essaim)
func _desired_direction(next_path_position: Vector2) -> Vector2:
	return global_position.direction_to(next_path_position)


func bounce_on(collider: CollisionObject2D) -> void:
	velocity = - (collider.position - position).normalized() * speed * 2
	$BounceBackDuration.start()
	is_bouncing = true


func hit(damage: int, attacker: Node2D = null) -> void:
	var damage_label = damage_label_scene.instantiate()
	damage_label.position = level_scale * (position - Vector2(0, 64))
	damage_label.amount = damage
	get_parent().add_child(damage_label)
	if can_take_damage:
		lives -= damage
		# Représaille : un ennemi sans cible fonce sur le sorcier qui l'a touché
		if attacker != null and is_instance_valid(attacker) and attacker.is_in_group("player_group"):
			last_attacker = attacker
			if target == null:
				target = attacker
		if lives == 1:
			$AnimatedSprite2D.play("2vies_1")
		# --- Dead Cells style hit feedback ---
		# Flash rouge bref sur l'ennemi, puis retour à la couleur normale
		var flash_tween := create_tween()
		flash_tween.tween_property($AnimatedSprite2D, "modulate", Color(1.0, 0.1, 0.1, 1.0), 0.05)
		flash_tween.tween_property($AnimatedSprite2D, "modulate", Color.WHITE, 0.15)
		# Knockback sur l'ennemi : repoussé par le sorcier qui l'a touché
		# (recherche du joueur le plus proche : compatible multi-sorciers)
		var direction_away := _direction_away_from_nearest_player()
		velocity = direction_away * 400.0 + Vector2.UP * 100.0
		$BounceBackDuration.start()
		is_bouncing = true
		# --- Fin ---
		if lives == 0:
			die(attacker)
		$DamageCooldown.start()
		can_take_damage = false


func die(attacker: Node2D = null) -> void:
	if attacker != null:
		last_attacker = attacker
	# queue_free AVANT l'émission du signal : les auditeurs qui vérifient
	# l'état d'un groupe (ex : essaim de mouches) voient bien cet ennemi
	# comme mort au moment du handler
	queue_free()
	enemy_killed.emit()


func _on_damage_cooldown_timeout() -> void:
	can_take_damage = true


func _on_bounce_back_duration_timeout() -> void:
	is_bouncing = false


# Direction opposée au joueur (sorcier) le plus proche, Vector2.ZERO si aucun
func _direction_away_from_nearest_player() -> Vector2:
	var away := Vector2.UP
	var min_distance := INF
	for player in get_tree().get_nodes_in_group("player_group"):
		if not is_instance_valid(player):
			continue
		var d: float = position.distance_to(player.global_position)
		if d < min_distance:
			min_distance = d
			away = (position - player.global_position).normalized()
	return away
