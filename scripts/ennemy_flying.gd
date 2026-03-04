extends CharacterBody2D

@export var speed = 200
@export var lives = 3

var target : Node2D = null
var can_take_damage: bool = true


func _ready() -> void:
	$AnimatedSprite2D.play("default")
	velocity = Vector2(1 - 2 * randf(), 1 - 2 * randf()).normalized() * speed


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		if target == null or position.distance_to(target.position) > position.distance_to(body.position):
			target=body


func _process(delta: float) -> void:
	if velocity.x > 0:
		$AnimatedSprite2D.flip_h = true
	elif velocity.x < 0:
		$AnimatedSprite2D.flip_h = false


func _physics_process(_delta: float) -> void:
	if target!=null:
		velocity=(target.position-position).normalized() * speed
	
		# Collisions
	for index in range(get_slide_collision_count()):
		var collider = get_slide_collision(index).get_collider()

		if collider == null:
			continue
		elif collider.is_in_group("player_group"):
			var player: Sorcerer = collider
			player.hit(1)
		
	move_and_slide()


func hit(damage: int):
	if can_take_damage:
		lives -= damage
		if lives == 0:
			die()
		$DamageCooldown.start()
		can_take_damage = false


func die():
	queue_free()


func _on_damage_cooldown_timeout() -> void:
	can_take_damage = true
