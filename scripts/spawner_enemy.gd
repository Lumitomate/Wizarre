extends Area2D

signal enemy_spawned

@export var can_spawn: bool = true

var players_in_range: Array[Sorcerer]
var enemy_scene: PackedScene = preload("res://scenes/enemy_flying.tscn")

func _ready() -> void:
	$AnimatedSprite2D.play("SpawnerApparition")
	$SpawnCooldown.wait_time += randf()
	$SpawnCooldown.start()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group") and not body in players_in_range:
		players_in_range.append(body)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player_group") and body in players_in_range:
		players_in_range.erase(body)


func _on_spawn_cooldown_timeout() -> void:
	if players_in_range.is_empty() and can_spawn:
		$AnimatedSprite2D.play("SpawnerApparition")


func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation==&"SpawnerApparition":
		spawn()
		$AnimatedSprite2D.play("SpawnerIdle")

func _on_block_spawn() -> void:
	can_spawn = false

func spawn() -> void:
	if can_spawn:
		var enemy: EnemyFlying = enemy_scene.instantiate()
		enemy.enemy_killed.connect(get_parent()._on_enemy_killed)
		enemy.position = position
		enemy_spawned.emit()
		get_parent().add_child(enemy)
