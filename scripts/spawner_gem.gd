extends Node2D


@export var can_spawn: bool = true

var gem_scene: PackedScene = preload("res://scenes/gem.tscn")
var can_spawn_gem: bool = true


func _ready() -> void:
	$SpawnCooldown.start()


func _on_spawn_cooldown_timeout() -> void:
	var gem = gem_scene.instantiate()
	gem.position = position
	gem.gem_color = randi() % 3
	get_parent().add_child(gem)
	can_spawn_gem = false
	


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group"):
		can_spawn_gem = true
		
func _on_block_spawn() -> void:
	can_spawn = false


func _on_level_block_spawn() -> void:
	pass # Replace with function body.
