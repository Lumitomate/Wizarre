extends Node

enum AttackType {
	FIREBALL,
	LIGHTRAY,
	FIRECOLUMN
}


const SPRITE_SIZE = 64

var fireball_scene = preload("res://scenes/attack_fireball.tscn")
var lightray_scene = preload("res://scenes/attack_light_ray.tscn")
var firecolumn_scene = preload("res://scenes/attack_fire_column.tscn")


func spawn_attack(attack_type: AttackType, player_position: Vector2, player_direction: Vector2, screen_size: Vector2) -> Array[Node]:
	
	var spawn_list: Array[Node]
	
	match attack_type:
		AttackType.FIREBALL:
			var fireball = fireball_scene.instantiate()
			fireball.position = player_position + 60 * player_direction
			fireball.direction = player_direction
			spawn_list.append(fireball)
			
		AttackType.LIGHTRAY:
			for i in range(screen_size.x / SPRITE_SIZE):
				var lightray = lightray_scene.instantiate()
				lightray.position = Vector2(i * SPRITE_SIZE, player_position.y)
				spawn_list.append(lightray)
				
		AttackType.FIRECOLUMN:
			var previous_column: AttackFireColumn = null
			for i in range((screen_size.y / SPRITE_SIZE) + 1):
				var firecolumn: AttackFireColumn = firecolumn_scene.instantiate()
				firecolumn.position = Vector2(player_position.x, i * SPRITE_SIZE)
				if previous_column != null:
					firecolumn.previous_pre_spawn_done.connect(previous_column._on_previous_pre_spawn_done)
				spawn_list.append(firecolumn)
				previous_column = firecolumn
			previous_column.is_last = true

	return spawn_list
