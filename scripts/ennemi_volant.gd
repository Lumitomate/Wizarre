extends CharacterBody2D

@export var speed = 200
@export var lives = 3

var target : Node2D = null


func _ready() -> void:
	$AnimatedSprite2D.play("default")

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		if target == null or position.distance_to(target.position) > position.distance_to(body.position):
			target=body
		
func _physics_process(_delta: float) -> void:
	if target!=null:
		velocity=(target.position-position).normalized()*speed
	else:
		velocity=Vector2.ZERO
		
		# Collisions
	for index in range(get_slide_collision_count()):
		var collider = get_slide_collision(index).get_collider()

		if collider == null:
			continue
		elif collider.is_in_group("player_group"):
			var player: Sorcerer = collider
		
	move_and_slide()


func hit(damage: int):
	lives -= damage
	if lives == 0:
		die()

func die():
	queue_free()
