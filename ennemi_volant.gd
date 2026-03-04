extends CharacterBody2D
@export var speed=150
var target:Node2D=null


func _on_area_2d_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
	if body.is_in_group("player_group"):
		target=body
		
func _physics_process(_delta: float) -> void:
	if target!=null:
		velocity=(target.position-position).normalized()*speed
	else:
		velocity=Vector2.ZERO
	move_and_slide()
