class_name EnnemyFlying extends CharacterBody2D


signal ennemy_killed

@export var speed = 200
@export var lives = 3

var target : Node2D = null
var can_take_damage: bool = true
var is_bouncing: bool = false
var level_scale: Vector2

var damage_label_scene = preload("res://scenes/hud_damage_label.tscn")


func _ready() -> void:
	var screen_size = get_viewport_rect().size
	level_scale = get_parent().transform.get_scale()
	$AnimatedSprite2D.play("default")
	velocity = position.direction_to(screen_size / 2).rotated( 0.1  *randf()).normalized() * speed


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		if target == null or position.distance_to(target.position) > position.distance_to(body.position):
			target=body


func _process(_delta: float) -> void:
	if !is_bouncing:
		if velocity.x > 0:
			$AnimatedSprite2D.flip_h = true
		elif velocity.x < 0:
			$AnimatedSprite2D.flip_h = false


func _physics_process(delta: float) -> void:
	if target!=null:
		var velocity_trg = (target.position - position).normalized() * speed
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


func bounce_on(collider: CollisionObject2D) -> void:
	velocity = - (collider.position - position).normalized() * speed * 2
	$BounceBackDuration.start()
	is_bouncing = true


func hit(damage: int):
	var damage_label = damage_label_scene.instantiate()
	damage_label.position = level_scale * (position - Vector2(0, 64))
	damage_label.amount = damage
	get_parent().add_child(damage_label)
	if can_take_damage:
		lives -= damage
		if lives == 0:
			die()
		$DamageCooldown.start()
		can_take_damage = false


func die():
	ennemy_killed.emit()
	queue_free()


func _on_damage_cooldown_timeout() -> void:
	can_take_damage = true


func _on_bounce_back_duration_timeout() -> void:
	is_bouncing = false
