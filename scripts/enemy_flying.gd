class_name EnemyFlying extends CharacterBody2D


signal enemy_killed

## Délai sans cible au-delà duquel l'ennemi fonce sur le sorcier le plus
## proche, même si celui-ci est hors de sa zone de détection
const NO_TARGET_CHASE_DELAY := 8.0

@export var speed: int = 200
@export var lives: int = 1  # la scène enemy_flying.tscn est la référence en jeu

var target : Node2D = null
# Temps écoulé sans aucune cible (remis à zéro dès qu'une cible est prise)
var _no_target_timer: float = 0.0
# Dernier sorcier à avoir infligé des dégâts (pour la représaille et le
# signalement du tueur à l'essaim)
var last_attacker: Node2D = null
var target_position: Vector2 = Vector2(0, 0)
var can_take_damage: bool = true
var is_bouncing: bool = false
var level_scale: Vector2
var screen_size: Vector2

var damage_label_scene = preload("res://scenes/hud/hud_damage_label.tscn")
var death_burst_scene = preload("res://scenes/objets/enemy_death_burst.tscn")

## Quantités de débris à la mort (l'éclatement) ; la mouche les réduit
@export var burst_chunks_min := 3
@export var burst_chunks_max := 6
@export var burst_blood_min := 30
@export var burst_blood_max := 50


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

func set_navigation_target(cible: Vector2):
	$NavigationAgent2D.target_position = cible
	
func set_random_navigation_target():
	set_navigation_target(screen_size / 4 + Vector2(randi() % int(screen_size.x / 2), randi() % int(screen_size.y / 2)))

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		if target == null or position.distance_to(target.position) > position.distance_to(body.position):
			target = body


func _process(delta: float) -> void:
	if !is_bouncing:
		if velocity.x > 0:
			$AnimatedSprite2D.flip_h = true
		elif velocity.x < 0:
			$AnimatedSprite2D.flip_h = false
	
	if target != null:
		set_navigation_target(target.global_position)
		_no_target_timer = 0.0
	else:
		# Sans cible depuis trop longtemps : fonce sur le sorcier le plus
		# proche, même hors de la zone de détection (évite les ennemis qui
		# errent indéfiniment parce que personne ne passe à portée)
		_no_target_timer += delta
		if _no_target_timer >= NO_TARGET_CHASE_DELAY:
			var nearest := _nearest_player()
			if nearest != null:
				target = nearest
				_no_target_timer = 0.0


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


func hit(damage: int, attacker: Node2D = null, origin: Node2D = null) -> void:
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
			die(attacker, origin)
		$DamageCooldown.start()
		can_take_damage = false


func die(attacker: Node2D = null, origin: Node2D = null) -> void:
	if attacker != null:
		last_attacker = attacker
	# Éclatement en morceaux + sang, orienté par le sens de l'attaque fatale
	_spawn_death_burst(origin)
	# queue_free AVANT l'émission du signal : les auditeurs qui vérifient
	# l'état d'un groupe (ex : essaim de mouches) voient bien cet ennemi
	# comme mort au moment du handler
	queue_free()
	enemy_killed.emit()


## Fait éclater l'ennemi en débris à sa position. Direction = opposée à
## l'origine du coup fatal (projectile, graine, ronce…), avec repli sur le
## sorcier attaquant puis vers le haut si rien n'est disponible.
func _spawn_death_burst(origin: Node2D = null) -> void:
	var source := origin
	if source == null or not is_instance_valid(source):
		source = last_attacker
	var burst_direction := Vector2.UP
	if source != null and is_instance_valid(source):
		burst_direction = global_position - source.global_position
		if burst_direction.length() > 0.01:
			burst_direction = burst_direction.normalized()
		else:
			burst_direction = Vector2.UP
	var burst: EnemyDeathBurst = death_burst_scene.instantiate()
	burst.position = position
	burst.direction = burst_direction
	burst.chunk_count_min = burst_chunks_min
	burst.chunk_count_max = burst_chunks_max
	burst.blood_count_min = burst_blood_min
	burst.blood_count_max = burst_blood_max
	# Un ennemi peut mourir hors de l'arbre (tests) : pas d'éclatement alors
	# add_child différé : hit() est souvent appelé depuis un signal de contact
	# (projectile), pendant le flush des requêtes physiques — y créer des
	# CharacterBody2D à ce moment est interdit par le moteur
	var parent := get_parent()
	if parent != null:
		parent.add_child.call_deferred(burst)


func _on_damage_cooldown_timeout() -> void:
	can_take_damage = true


func _on_bounce_back_duration_timeout() -> void:
	is_bouncing = false


# Sorcier (joueur) vivant le plus proche, null si aucun
# (logique mutualisée dans EntityFinder)
func _nearest_player() -> Node2D:
	return EntityFinder.plus_proche(self, global_position, ["player_group"])


# Direction opposée au joueur (sorcier) le plus proche, Vector2.UP si aucun
func _direction_away_from_nearest_player() -> Vector2:
	var player := _nearest_player()
	if player == null:
		return Vector2.UP
	return (position - player.global_position).normalized()
