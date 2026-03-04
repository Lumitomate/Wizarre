extends Area2D

@export var speed: int = 2000;

var direction: Vector2 = Vector2.LEFT
var color_mod: Color = Color(1, 1, 1)

func _enter_tree() -> void:
	modulate = color_mod
	if direction == Vector2.LEFT:
		$Sprite2D.flip_h = true

func _physics_process(delta: float) -> void:
	position += speed * direction * delta

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group") or body.is_in_group("ennemy_group"):
		body.hit(1)
