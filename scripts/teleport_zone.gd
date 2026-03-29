extends Area2D

@export var destination : GlobalEnum.Location

func _on_body_entered(body):
	if body.is_in_group("player_group"):
		Global.goto_scene(destination)
