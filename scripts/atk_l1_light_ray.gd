## ═══════════════════════════════════════════════════════════════════════
##  L1 · RAYON DE LUMIÈRE — famille Lumière — atk_l1_light_ray.tscn
## ═══════════════════════════════════════════════════════════════════════
##  JEU   : rideau de rayons de lumière — faisceaux parallèles qui
##          s'activent après un pre_spawn, détruits en fin d'anim.
##  TIER  : nombre de faisceaux parallèles.
##  SPAWN : rangée de rayons espacés de 64 px le long de la visée (éventail
##          selon le tier), bornée à l'écran.
##  CORPS : AttackProjectile (Area2D — dégâts de contact + anti double-coup)
class_name AttackLightRay extends AttackProjectile

## Contrat de spawn (cf. AttackSpawner) : rideau de rayons parallèles
## (ray_nb selon le tier) couvrant l'écran dans la direction de visée.
static var _SCENE: PackedScene = null
static func setup_spawn(attack_tier: int, position: Vector2, direction: Vector2, screen_size: Vector2, _level_scale: Vector2, caster: Node2D) -> Array[Node]:
	if _SCENE == null:
		_SCENE = load("res://scenes/atk/atk_l1_light_ray.tscn")
	var spawn_list: Array[Node] = []
	const SPRITE_SIZE = 64
	var pos := position * _level_scale
	var ray_nb = attack_tier
	for n in range(ray_nb):
		for i in range(-(screen_size.length() / SPRITE_SIZE), (screen_size.length() / SPRITE_SIZE) + 1):
			var attack_position = (i + 1) * SPRITE_SIZE * direction.normalized().rotated(n * PI / ray_nb) + pos
			if attack_position.x > -SPRITE_SIZE and attack_position.x < screen_size.x + SPRITE_SIZE and attack_position.y > -SPRITE_SIZE and attack_position.y < screen_size.y + SPRITE_SIZE:
				var lightray: AttackLightRay = _SCENE.instantiate()
				lightray.caster = caster
				lightray.transform = lightray.transform.rotated(direction.angle() + n * PI / ray_nb)
				lightray.position = attack_position
				spawn_list.append(lightray)
	return spawn_list


func _ready() -> void:
	super._ready()
	# Garde anti double-coup : suivre les sorties de zone (l'entrée est
	# gérée par le _on_body_entered de la base, déjà câblé dans la scène)
	body_exited.connect(_on_body_exited)
	$AnimatedSprite2D.play("pre_spawn")
	$CollisionShape2D.disabled = true


## Règle validée : être dans un rayon de lumière protège d'un nouveau
## coup de rayon (l'éventail du tier peut chevaucher plusieurs rayons =
## un seul toc par passage).
func can_damage(body: Node2D) -> bool:
	return not double_toc_bloque(body)


func _on_animated_sprite_2d_animation_finished() -> void:
	match $AnimatedSprite2D.animation:
		&"pre_spawn":
			$AnimatedSprite2D.play("spawn")
			$CollisionShape2D.disabled = false
		&"spawn":
			queue_free()
