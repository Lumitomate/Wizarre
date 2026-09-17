extends Area2D

signal enemy_spawned

@export var can_spawn: bool = true

var players_in_range: Array[Sorcerer]
var enemy_scene: PackedScene = preload("res://scenes/entities/ennemies/enemy_flying.tscn")
var enemy_2lifes_scene: PackedScene = preload("res://scenes/entities/ennemies/enemy_2lifes.tscn")
var enemy_fly_scene: PackedScene = preload("res://scenes/entities/ennemies/enemy_fly.tscn")

# Chances de chaque variante lors d'un spawn (la base prend le reste) :
# 30 % de monstres à 2 PV, 10 % de groupes de 5 mouches, 60 % de base
const TWO_LIFES_CHANCE := 0.3
const FLY_CHANCE := 0.1
# Nombre de mouches par groupe
const FLY_GROUP_SIZE := 5
# Éparpillement des mouches autour du spawner (en px)
const FLY_GROUP_SPREAD := 48.0

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
		# Variante aléatoire : 10 % groupe de 5 mouches, 30 % monstre à
		# 2 PV, 60 % monstre de base
		var roll := randf()
		if roll < FLY_CHANCE:
			_spawn_fly_group()
		elif roll < FLY_CHANCE + TWO_LIFES_CHANCE:
			_spawn_enemy(enemy_2lifes_scene)
		else:
			_spawn_enemy(enemy_scene)


# Fait apparaître un ennemi de la scène donnée et compte le spawn
func _spawn_enemy(scene: PackedScene) -> void:
	var enemy: EnemyFlying = scene.instantiate()
	enemy.enemy_killed.connect(get_parent()._on_enemy_killed)
	enemy.position = position
	enemy_spawned.emit()
	get_parent().add_child(enemy)


# Fait apparaître un groupe de mouches légèrement éparpillées autour du
# spawner. L'essaim compte comme UN SEUL ennemi pour le niveau : un seul
# enemy_spawned ici, et un seul kill quand la dernière mouche du groupe meurt
func _spawn_fly_group() -> void:
	var group: Array[EnemyFly] = []
	for i in FLY_GROUP_SIZE:
		var fly: EnemyFly = enemy_fly_scene.instantiate()
		fly.enemy_killed.connect(_on_fly_killed.bind(group))
		fly.position = position + Vector2(randf_range(-FLY_GROUP_SPREAD, FLY_GROUP_SPREAD), randf_range(-FLY_GROUP_SPREAD, FLY_GROUP_SPREAD))
		fly.swarm_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 40.0
		group.append(fly)
	for fly in group:
		fly.swarm = group
		get_parent().add_child(fly)
	enemy_spawned.emit()


# Mort d'une mouche du groupe : on ne compte le kill que lorsque toute
# l'essaim est tombé (l'essaim = 1 ennemi pour la jauge/porte du niveau)
func _on_fly_killed(group: Array[EnemyFly]) -> void:
	for fly in group:
		if is_instance_valid(fly) and not fly.is_queued_for_deletion():
			return
	get_parent()._on_enemy_killed()
