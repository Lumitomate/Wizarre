## ═══════════════════════════════════════════════════════════════════════
##  G2 · PIQUES DE GLACE — famille Glace — atk_g2_ice_spike.tscn
## ═══════════════════════════════════════════════════════════════════════
##  JEU   : un anneau de piques de glace jaillit autour du point de tir.
##  TIER  : I = 4 piques · II = 6 · III = 8.
##  SPAWN : anneau décalé de 45° par rapport à la visée, réparti sur TAU.
##  CORPS : AttackProjectile (Area2D — dégâts de contact + anti double-coup)
class_name AttackIceSpike
extends AttackProjectile

@export var speed: int = 1500
@export var spawn_immunity_time: float = 0.15  # secondes avant que la hitbox s'active

var direction: Vector2 = Vector2.RIGHT
var _level_scale: Vector2 = Vector2.ONE
var tier_scale: float = 1.0
var player_immunity: bool = true

## Contrat de spawn (cf. AttackSpawner) : anneau de piques de glace
## autour du point de tir (4 + 2×(tier-1) piques, décalés de 45°).
static var _SCENE: PackedScene = null
static func setup_spawn(attack_tier: int, position: Vector2, direction: Vector2, _screen_size: Vector2, level_scale: Vector2, _caster: Node2D) -> Array[Node]:
	if _SCENE == null:
		_SCENE = load("res://scenes/atk/atk_g2_ice_spike.tscn")
	var spawn_list: Array[Node] = []
	var spike_count = 4 + (attack_tier - 1) * 2
	var angle_step = TAU / spike_count
	var start_angle = direction.angle() + PI / 4  # décalage de 45°
	for i in range(spike_count):
		var ice_spike: AttackIceSpike = _SCENE.instantiate()
		var spike_angle = start_angle + (i * angle_step)
		ice_spike.rotation = spike_angle
		ice_spike.direction = Vector2.RIGHT.rotated(spike_angle)
		ice_spike.position = position + 60 * Vector2.RIGHT.rotated(spike_angle)
		ice_spike.apply_level_scale(level_scale)
		ice_spike.setup_tier(attack_tier)
		spawn_list.append(ice_spike)
	return spawn_list


func apply_level_scale(level_scale: Vector2) -> void:
	_level_scale = level_scale
	$AnimatedSprite2D.scale = level_scale
	$CollisionPolygon2D.scale = level_scale

func setup_tier(tier: int) -> void:
	tier_scale = float(tier)
	$AnimatedSprite2D.scale = _level_scale * tier_scale
	$CollisionPolygon2D.scale = _level_scale * tier_scale

func _ready() -> void:
	$AnimatedSprite2D.play("idle")
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(spawn_immunity_time).timeout
	player_immunity = false

func _physics_process(delta: float) -> void:
	position += speed * direction * delta

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func can_damage(body: Node2D) -> bool:
	# Le joueur est immunisé juste après le spawn (la hitbox s'active après
	# un court délai pour éviter de toucher le lanceur)
	return not (player_immunity and body.is_in_group("player_group"))
