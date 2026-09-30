extends Area2D

@export var destination : GlobalEnum.Location

func _on_body_entered(body):
	if body.is_in_group("player_group"):
		if destination == GlobalEnum.Location.LEVEL:
			GlobalInfo.run_info["from_homepage"] = true
		Global.goto_scene(destination)
