class_name AttackSpawner

const SPRITE_SIZE = 64

static var fireball_scene: PackedScene = preload("res://scenes/atk_f0_fireball.tscn")
static var lightray_scene: PackedScene = preload("res://scenes/atk_l1_light_ray.tscn")
static var firecolumn_scene: PackedScene = preload("res://scenes/atk_f1_fire_column.tscn")
static var ice_ball_scene: PackedScene = preload("res://scenes/atk_g1_ice_ball.tscn")
static var carnivorous_scene: PackedScene = preload("res://scenes/atk_p1_carnivorous_seed.tscn")
static var plantball_scene: PackedScene = preload("res://scenes/atk_p2_explo.tscn")
static var fire_wave_scene: PackedScene = preload("res://scenes/atk_f2_wave.tscn")
static var ice_spike_scene: PackedScene = preload("res://scenes/atk_g2_ice_spike.tscn")
static var ice_blade_scene: PackedScene = preload("res://scenes/atk_g3_blade.tscn")
static var mine_scene: PackedScene = preload("res://scenes/atk_f3_mine.tscn")
static var lighttarget_scene: PackedScene = preload("res://scenes/atk_l2_light_target.tscn")

static func spawn_attack(attack_type: GlobalEnum.AttackType, attack_tier: GlobalEnum.AttackTier, player_position: Vector2, player_direction: Vector2, screen_size: Vector2, level_scale: Vector2, caster: Node2D) -> Array[Node]:
	
	var spawn_list: Array[Node]
	
	var int_attack_tier: int = int(attack_tier) + 1
	
	match attack_type:
		GlobalEnum.AttackType.F0:
			player_position *= level_scale
			var spread = PI / 4
			for i in range(attack_tier):
				var fireball: AttackFireBall = fireball_scene.instantiate()
				fireball.transform = fireball.transform.rotated(player_direction.angle() + (i * spread) - (int_attack_tier - 1) * spread / 2 )
				fireball.position = player_position + 60 * player_direction.normalized()
				fireball.direction = player_direction.normalized()
				spawn_list.append(fireball)
			
		GlobalEnum.AttackType.L1:
			player_position *= level_scale
			var ray_nb = int_attack_tier
			for n in range(ray_nb):
				for i in range(-(screen_size.length() / SPRITE_SIZE), (screen_size.length() / SPRITE_SIZE) + 1):
					var attack_position = (i + 1) * SPRITE_SIZE * player_direction.normalized().rotated(n * PI / ray_nb) + player_position
					if attack_position.x > -SPRITE_SIZE and attack_position.x < screen_size.x + SPRITE_SIZE and attack_position.y > -SPRITE_SIZE and attack_position.y < screen_size.y + SPRITE_SIZE:
						var lightray:AttackLightRay = lightray_scene.instantiate()
						lightray.transform = lightray.transform.rotated(player_direction.angle() + n * PI / ray_nb)
						lightray.position = attack_position
						spawn_list.append(lightray)
				
		GlobalEnum.AttackType.F1:
			player_position *= level_scale
			var previous_column: AttackFireColumn = null
			#player_direction = player_direction.rotated(PI / 2)
			for i in range(-(screen_size.length() / SPRITE_SIZE), (screen_size.length() / SPRITE_SIZE) + 1):
				var attack_position = -(i + 1) * SPRITE_SIZE * player_direction.normalized() + player_position
				if attack_position.x > -SPRITE_SIZE and attack_position.x < screen_size.x + SPRITE_SIZE and attack_position.y > -SPRITE_SIZE and attack_position.y < screen_size.y + SPRITE_SIZE:
					var firecolumn: AttackFireColumn = firecolumn_scene.instantiate()
					firecolumn.transform = firecolumn.transform.scaled(Vector2(float(int_attack_tier) * 1/3, 1)).rotated(player_direction.angle() + PI/2)
					firecolumn.position = attack_position
					if previous_column != null:
						firecolumn.previous_pre_spawn_done.connect(previous_column._on_previous_pre_spawn_done)
					spawn_list.append(firecolumn)
					previous_column = firecolumn
			previous_column.is_last = true
		
		GlobalEnum.AttackType.G1:
			var ice_ball: AttackIceBall = ice_ball_scene.instantiate()
			ice_ball.transform = ice_ball.transform.rotated(player_direction.angle())
			ice_ball.scale(2 * level_scale)
			ice_ball.position = player_position + 60 * player_direction.normalized()
			ice_ball.linear_velocity = 300 * int_attack_tier * player_direction.normalized()
			#ice_ball.direction = player_direction.normalized()
			spawn_list.append(ice_ball)
			
		GlobalEnum.AttackType.P1:
			var carnivorous: AttackCarnivorousSeed = carnivorous_scene.instantiate()
			carnivorous.transform = carnivorous.transform.rotated(player_direction.angle())
			carnivorous.scale(2 * level_scale)
			carnivorous.position = player_position + 60 * player_direction.normalized()
			carnivorous.linear_velocity = 200 * player_direction.normalized()
			carnivorous.attack_tier = int_attack_tier
			spawn_list.append(carnivorous)

		GlobalEnum.AttackType.P2:
			var plant_ball: AttackPlantBall = plantball_scene.instantiate()
			plant_ball.transform = plant_ball.transform.rotated(player_direction.angle())
			plant_ball.scale(level_scale)
			plant_ball.position = player_position + 60 * player_direction.normalized()
			plant_ball.linear_velocity = 300 * player_direction.normalized()
			plant_ball.setup_tier(int_attack_tier)
			spawn_list.append(plant_ball)
			
		GlobalEnum.AttackType.F2:
			var fire_wave: AttackFireWave = fire_wave_scene.instantiate()
			fire_wave.direction = player_direction.normalized()
			fire_wave.position = player_position + 60 * player_direction.normalized()
			fire_wave.tier_scale = 1.0 + (int_attack_tier - 1) * 3.0
			fire_wave.setup_tier(int_attack_tier)
			fire_wave.rotation = player_direction.angle()
			spawn_list.append(fire_wave)

		GlobalEnum.AttackType.G2:
			var spike_count = 4 + (int_attack_tier - 1) * 2
			var angle_step = TAU / spike_count
			var start_angle = player_direction.angle() + PI / 4  # décalage de 45°
			for i in range(spike_count):
				var ice_spike: AttackIceSpike = ice_spike_scene.instantiate()
				var spike_angle = start_angle + (i * angle_step)
				ice_spike.rotation = spike_angle
				ice_spike.direction = Vector2.RIGHT.rotated(spike_angle)
				ice_spike.position = player_position + 60 * Vector2.RIGHT.rotated(spike_angle)
				ice_spike.scale(level_scale)
				ice_spike.setup_tier(int_attack_tier)
				spawn_list.append(ice_spike)

		GlobalEnum.AttackType.G3:
			var ice_blade_count = 2
			var angle_step = TAU / ice_blade_count
			var rot_dir = 1.0 if player_direction.x >= 0 else -1.0
			var start_angle = -PI / 2.0  # démarre à la verticale (haut)
			for i in range(ice_blade_count):
				var ice_blade: AttackIceBlade = ice_blade_scene.instantiate()
				var ice_blade_angle = start_angle + i * angle_step
				ice_blade.setup(
					caster,
					ice_blade_angle,
					rot_dir,
					int_attack_tier,
					level_scale
				)
				spawn_list.append(ice_blade)

		GlobalEnum.AttackType.F3:
			# La mine est posée sur le sorcier, décalée de 28 px vers le haut
			# (position locale au Level, comme le sorcier : pas de scale à appliquer)
			var mine: AttackFireMine = mine_scene.instantiate()
			mine.position = player_position + Vector2(0, -28)
			mine.setup_tier(int_attack_tier)
			mine.caster = caster
			spawn_list.append(mine)
		GlobalEnum.AttackType.L2:
			var light_target: AttackLightTarget = lighttarget_scene.instantiate()
			light_target.position = player_position
			light_target.tier_scale = 1.0 + (int_attack_tier - 1) * 3.0
			light_target.scale = Vector2(light_target.tier_scale, light_target.tier_scale)
			light_target.caster = caster
			spawn_list.append(light_target)
	return spawn_list
