extends Node2D


@export var can_spawn: bool = true

var gemme_scene: PackedScene = preload("res://scenes/gemme.tscn")
var can_spawn_gemme: bool = true


func _ready() -> void:
	$SpawnCooldown.start()


func _on_spawn_cooldown_timeout() -> void:
	var gemme = gemme_scene.instantiate()
	gemme.position = position
	gemme.gemme_color = randi() % 3
	get_parent().add_child(gemme)
	can_spawn_gemme = false
	


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		can_spawn_gemme = true
		
func _on_block_spawn() -> void:
	can_spawn = false


func _on_level_block_spawn() -> void:
	pass # Replace with function body.
