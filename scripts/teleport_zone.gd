extends Area2D

@export var destination : GlobalEnum.Location

func _on_body_entered(body):
	print("EST ENTR222 DANS LE TP")
	if body.is_in_group("player"):
		Global.goto_location(destination)
