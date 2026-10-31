## ═══════════════════════════════════════════════════════════════════════
##  F0 · BOULE DE FEU — famille Feu — atk_f0_fireball.tscn
## ═══════════════════════════════════════════════════════════════════════
##  JEU   : 1 à 3 boules de feu partent en éventail vers la visée.
##  TIER  : I = 1 boule · II = 2 · III = 3.
##  SPAWN : éventail autour de la direction de visée (spread π/4),
##          lancées à 60 px devant le sorcier.
##  CORPS : AttackProjectile (Area2D — dégâts de contact + anti double-coup)
class_name AttackFireBall extends AttackProjectile

@export var speed: int = 2000

var direction: Vector2 = Vector2.LEFT


## Contrat de spawn (cf. AttackSpawner) : 1 à 3 boules de feu réparties
## en éventail autour de la visée (même convention que les autres
## attaques, cf. G1 : tier 1 = I). Retourne les nœuds à ajouter à l'arbre.
static var _SCENE: PackedScene = null
static func setup_spawn(spawn_tier: int, spawn_position: Vector2, spawn_direction: Vector2, _spawn_screen_size: Vector2, spawn_level_scale: Vector2, _spawn_caster: Node2D) -> Array[Node]:
	if _SCENE == null:
		_SCENE = load("res://scenes/atk/atk_f0_fireball.tscn")
	var spawn_list: Array[Node] = []
	var pos := spawn_position * spawn_level_scale
	var spread = PI / 4
	for i in range(spawn_tier):
		var fireball: AttackFireBall = _SCENE.instantiate()
		fireball.transform = fireball.transform.rotated(spawn_direction.angle() + (i * spread) - (spawn_tier - 1) * spread / 2)
		fireball.position = pos + 60 * spawn_direction.normalized()
		fireball.direction = spawn_direction.normalized()
		spawn_list.append(fireball)
	return spawn_list


func _enter_tree() -> void:
	if direction == Vector2.LEFT:
		$Sprite2D.flip_h = true


func _physics_process(delta: float) -> void:
	position += speed * direction * delta


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
