extends Node

const SPRITE_SIZE = 64

var fireball_scene = preload("res://scenes/attack_fireball.tscn")
var lightray_scene = preload("res://scenes/attack_light_ray.tscn")
var firecolumn_scene = preload("res://scenes/attack_fire_column.tscn")
var ice_ball_scene = preload("res://scenes/attack_ice_ball.tscn")


func spawn_attack(attack_type: Enum.AttackType, attack_tier: Enum.AttackTier,  player_position: Vector2, player_direction: Vector2, screen_size: Vector2, level_scale: Vector2) -> Array[Node]:
	
	var spawn_list: Array[Node]
	
	attack_tier += 1
	
	match attack_type:
		Enum.AttackType.FIREBALL:
			player_position *= level_scale
			var spread = PI / 4
			for i in range(attack_tier):
				var fireball: AttackFireBall = fireball_scene.instantiate()
				fireball.transform = fireball.transform.rotated(player_direction.angle() + (i * spread) - (attack_tier - 1) * spread / 2 )
				fireball.position = player_position + 60 * player_direction.normalized()
				fireball.direction = player_direction.normalized()
				spawn_list.append(fireball)
			
		Enum.AttackType.LIGHTRAY:
			player_position *= level_scale
			var ray_nb = attack_tier
			for n in range(ray_nb):
				for i in range(-(screen_size.length() / SPRITE_SIZE), (screen_size.length() / SPRITE_SIZE) + 1):
					var attack_position = (i + 1) * SPRITE_SIZE * player_direction.normalized().rotated(n * PI / ray_nb) + player_position
					if attack_position.x > -SPRITE_SIZE and attack_position.x < screen_size.x + SPRITE_SIZE and attack_position.y > -SPRITE_SIZE and attack_position.y < screen_size.y + SPRITE_SIZE:
						var lightray:AttackLightRay = lightray_scene.instantiate()
						lightray.transform = lightray.transform.rotated(player_direction.angle() + n * PI / ray_nb)
						lightray.position = attack_position
						spawn_list.append(lightray)
				
		Enum.AttackType.FIRECOLUMN:
			player_position *= level_scale
			var previous_column: AttackFireColumn = null
			#player_direction = player_direction.rotated(PI / 2)
			for i in range(-(screen_size.length() / SPRITE_SIZE), (screen_size.length() / SPRITE_SIZE) + 1):
				var attack_position = -(i + 1) * SPRITE_SIZE * player_direction.normalized() + player_position
				if attack_position.x > -SPRITE_SIZE and attack_position.x < screen_size.x + SPRITE_SIZE and attack_position.y > -SPRITE_SIZE and attack_position.y < screen_size.y + SPRITE_SIZE:
					var firecolumn: AttackFireColumn = firecolumn_scene.instantiate()
					firecolumn.transform = firecolumn.transform.scaled(Vector2(float(attack_tier) * 1/3, 1)).rotated(player_direction.angle() + PI/2)
					firecolumn.position = attack_position
					if previous_column != null:
						firecolumn.previous_pre_spawn_done.connect(previous_column._on_previous_pre_spawn_done)
					spawn_list.append(firecolumn)
					previous_column = firecolumn
			previous_column.is_last = true
		
		Enum.AttackType.ICEBALL:
			var ice_ball: AttackIceBall = ice_ball_scene.instantiate()
			ice_ball.transform = ice_ball.transform.rotated(player_direction.angle())
			ice_ball.scale(2 * level_scale)
			ice_ball.position = player_position + 60 * player_direction.normalized()
			ice_ball.linear_velocity = 300 * attack_tier * player_direction.normalized()
			#ice_ball.direction = player_direction.normalized()
			spawn_list.append(ice_ball)

	return spawn_list
