extends Area2D

signal enemy_spawned

@export var can_spawn: bool = true

var players_in_range: Array[Sorcerer]
## Spawning gelé (cinématique d'arrivée) : aucune vague ne peut apparaître
var frozen: bool = false
var enemy_scene: PackedScene = preload("res://scenes/entities/ennemies/enemy_flying.tscn")
var enemy_2lifes_scene: PackedScene = preload("res://scenes/entities/ennemies/enemy_2lifes.tscn")
var enemy_fly_scene: PackedScene = preload("res://scenes/entities/ennemies/enemy_fly.tscn")

# Nombre de mouches par groupe
const FLY_GROUP_SIZE := 5
# Éparpillement des mouches autour du spawner (en px)
const FLY_GROUP_SPREAD := 48.0

# Répartition des variantes selon la vague (interpolation linéaire) :
#   vague 0  : 100 % simple,  0 % 2 vies,  0 % mouches
#   vague 15 :  10 % simple, 45 % 2 vies, 45 % mouches
# Au-delà de la vague 15, la répartition finale reste appliquée.
const MIX_START_WAVE := 0
const MIX_END_WAVE := 15
const MIX_START_CHANCES := {"simple": 1.0, "two_lifes": 0.0, "fly": 0.0}
const MIX_END_CHANCES := {"simple": 0.1, "two_lifes": 0.45, "fly": 0.45}

# Progression par vague : le temps entre deux apparitions est multiplié
# par ce facteur à chaque nouvelle vague (< 1 = accélération très légère)
const SPAWN_TIME_FACTOR_PER_WAVE := 0.97

func _ready() -> void:
	add_to_group("enemy_spawner_group")
	$AnimatedSprite2D.play("SpawnerApparition")
	# Vague 0 (première vague) = vitesse de base, puis légère accélération
	$SpawnCooldown.wait_time *= pow(SPAWN_TIME_FACTOR_PER_WAVE, GlobalInfo.run_info["level_number"])
	$SpawnCooldown.wait_time += randf()
	$SpawnCooldown.start()

## Gel du spawning (cinématique d'arrivée) : stoppe le timer ET l'animation
## en cours — un spawn part de animation_finished, pas du timer : couper
## le timer seul laisserait la vague déjà programmée apparaître quand même
func set_spawning_frozen(value: bool) -> void:
	frozen = value
	if value:
		$SpawnCooldown.stop()
		$AnimatedSprite2D.stop()
		$AnimatedSprite2D.animation = &"SpawnerIdle"
	else:
		$SpawnCooldown.start()
		# Spawner vivant dès la libération : l'anim idle tourne en boucle
		# (sinon le sprite reste figé sur l'anim idle ARRÊTÉE du gel)
		$AnimatedSprite2D.play("SpawnerIdle")
		# Première vague rapide : on rejoue tout de suite l'anim d'apparition
		# (comme au chargement du niveau avant la cinématique), sinon il
		# faudrait attendre un cycle complet du timer (10 s). Uniquement si
		# aucun joueur n'est déjà dans la zone (règle habituelle du spawner).
		if players_in_range.is_empty() and can_spawn:
			$AnimatedSprite2D.play("SpawnerApparition")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_group") and not body in players_in_range:
		players_in_range.append(body)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player_group") and body in players_in_range:
		players_in_range.erase(body)


func _on_spawn_cooldown_timeout() -> void:
	if frozen or not players_in_range.is_empty() or not can_spawn:
		return
	$AnimatedSprite2D.play("SpawnerApparition")


func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation==&"SpawnerApparition":
		if frozen:
			$AnimatedSprite2D.animation = &"SpawnerIdle"
			return
		spawn()
		$AnimatedSprite2D.play("SpawnerIdle")

func _on_block_spawn() -> void:
	can_spawn = false
	# Quota atteint : le spawner ne fait plus apparaître de monstres, mais
	# il reste VIVANT visuellement — si son anim est arrêtée (ex. gel de la
	# cinématique d'arrivée), on relance l'anim idle en boucle
	if not $AnimatedSprite2D.is_playing():
		$AnimatedSprite2D.play("SpawnerIdle")

## Chances de chaque variante pour la vague en cours : interpolation
## linéaire de MIX_START_CHANCES à MIX_END_CHANCES entre MIX_START_WAVE
## et MIX_END_WAVE, puis palier au-delà.
func _wave_chances() -> Dictionary:
	var wave: int = GlobalInfo.run_info["level_number"]
	var t := clampf(float(wave - MIX_START_WAVE) / float(MIX_END_WAVE - MIX_START_WAVE), 0.0, 1.0)
	var chances := {}
	for key: String in MIX_START_CHANCES:
		chances[key] = lerpf(MIX_START_CHANCES[key], MIX_END_CHANCES[key], t)
	return chances


func spawn() -> void:
	if can_spawn:
		# Répartition selon la vague, tirage dans l'ordre : mouches,
		# 2 vies, puis simple (la base prend le reste)
		var chances := _wave_chances()
		var roll := randf()
		if roll < chances["fly"]:
			_spawn_fly_group()
		elif roll < chances["fly"] + chances["two_lifes"]:
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
