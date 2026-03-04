extends Area2D


var players_in_range: Array[Sorcerer]
var ennemy_scene: PackedScene = preload("res://scenes/ennemy_flying.tscn")


func _ready() -> void:
	$SpawnCooldown.start()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group") and not body in players_in_range:
		players_in_range.append(body)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player_group") and body in players_in_range:
		players_in_range.erase(body)


func _on_spawn_cooldown_timeout() -> void:
	if players_in_range.is_empty():
		var ennemy = ennemy_scene.instantiate()
		ennemy.position = position
		get_parent().add_child(ennemy)
