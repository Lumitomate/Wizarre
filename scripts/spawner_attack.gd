extends Node

enum AttackType {
	FIREBALL,
	LIGHTRAY,
	FIRECOLUMN,
	ICEBALL
}


const SPRITE_SIZE = 64

var fireball_scene = preload("res://scenes/attack_fireball.tscn")
var lightray_scene = preload("res://scenes/attack_light_ray.tscn")
var firecolumn_scene = preload("res://scenes/attack_fire_column.tscn")
var ice_ball_scene = preload("res://scenes/attack_ice_ball.tscn")


func spawn_attack(attack_type: AttackType, player_position: Vector2, player_direction: Vector2, screen_size: Vector2, level_scale: Vector2) -> Array[Node]:
	
	var spawn_list: Array[Node]
	
	match attack_type:
		AttackType.FIREBALL:
			player_position *= level_scale
			var fireball: AttackFireBall = fireball_scene.instantiate()
			fireball.transform = fireball.transform.rotated(player_direction.angle())
			fireball.position = player_position + 60 * player_direction.normalized()
			fireball.direction = player_direction.normalized()
			spawn_list.append(fireball)
			
		AttackType.LIGHTRAY:
			player_position *= level_scale
			for i in range(-(screen_size.length() / SPRITE_SIZE), (screen_size.length() / SPRITE_SIZE) + 1):
				var attack_position = (i + 1) * SPRITE_SIZE * player_direction.normalized() + player_position
				if attack_position.x > -SPRITE_SIZE and attack_position.x < screen_size.x + SPRITE_SIZE and attack_position.y > -SPRITE_SIZE and attack_position.y < screen_size.y + SPRITE_SIZE:
					var lightray:AttackLightRay = lightray_scene.instantiate()
					lightray.transform = lightray.transform.rotated(player_direction.angle())
					lightray.position = attack_position
					spawn_list.append(lightray)
				
		AttackType.FIRECOLUMN:
			player_position *= level_scale
			var previous_column: AttackFireColumn = null
			#player_direction = player_direction.rotated(PI / 2)
			for i in range(-(screen_size.length() / SPRITE_SIZE), (screen_size.length() / SPRITE_SIZE) + 1):
				var attack_position = -(i + 1) * SPRITE_SIZE * player_direction.normalized() + player_position
				if attack_position.x > -SPRITE_SIZE and attack_position.x < screen_size.x + SPRITE_SIZE and attack_position.y > -SPRITE_SIZE and attack_position.y < screen_size.y + SPRITE_SIZE:
					var firecolumn: AttackFireColumn = firecolumn_scene.instantiate()
					firecolumn.transform = firecolumn.transform.rotated(player_direction.angle() + PI/2)
					firecolumn.position = attack_position
					if previous_column != null:
						firecolumn.previous_pre_spawn_done.connect(previous_column._on_previous_pre_spawn_done)
					spawn_list.append(firecolumn)
					previous_column = firecolumn
			previous_column.is_last = true
		
		AttackType.ICEBALL:
			var ice_ball: AttackIceBall = ice_ball_scene.instantiate()
			ice_ball.transform = ice_ball.transform.rotated(player_direction.angle())
			ice_ball.scale(2 * level_scale)
			ice_ball.position = player_position + 60 * player_direction.normalized()
			ice_ball.linear_velocity = 1000 * player_direction.normalized()
			#ice_ball.direction = player_direction.normalized()
			spawn_list.append(ice_ball)

	return spawn_list
