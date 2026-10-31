## ═══════════════════════════════════════════════════════════════════════
##  F1 · COLONNE DE FEU — famille Feu — atk_f1_fire_column.tscn
## ═══════════════════════════════════════════════════════════════════════
##  JEU   : une chaîne de colonnes de feu le long de la visée — la plus
##          proche du sorcier démarre en premier puis déclenche les
##          suivantes (signal previous_pre_spawn_done).
##  TIER  : largeur des colonnes (×1/3 par tier).
##  SPAWN : posées à rebours le long de la visée (pas de 64 px), bornées
##          à l'écran ; la DERNIÈRE posée (la plus proche du sorcier)
##          est is_last et déclenche toute la chaîne.
##  CORPS : AttackProjectile (Area2D — dégâts de contact + anti double-coup)
class_name AttackFireColumn extends AttackProjectile

signal previous_pre_spawn_done


var is_last = false


## Contrat de spawn (cf. AttackSpawner) : chaîne de colonnes de feu le
## long de la visée à rebours (la plus proche démarre en premier et
## déclenche la suivante via previous_pre_spawn_done).
static var _SCENE: PackedScene = null
static func setup_spawn(attack_tier: int, position: Vector2, direction: Vector2, screen_size: Vector2, level_scale: Vector2, _caster: Node2D) -> Array[Node]:
	if _SCENE == null:
		_SCENE = load("res://scenes/atk/atk_f1_fire_column.tscn")
	var spawn_list: Array[Node] = []
	const SPRITE_SIZE = 64
	var pos := position * level_scale
	var previous_column: AttackFireColumn = null
	for i in range(-(screen_size.length() / SPRITE_SIZE), (screen_size.length() / SPRITE_SIZE) + 1):
		var attack_position = -(i + 1) * SPRITE_SIZE * direction.normalized() + pos
		if attack_position.x > -SPRITE_SIZE and attack_position.x < screen_size.x + SPRITE_SIZE and attack_position.y > -SPRITE_SIZE and attack_position.y < screen_size.y + SPRITE_SIZE:
			var firecolumn: AttackFireColumn = _SCENE.instantiate()
			firecolumn.transform = firecolumn.transform.scaled(Vector2(float(attack_tier) * 1.0/3.0, 1)).rotated(direction.angle() + PI/2)
			firecolumn.position = attack_position
			if previous_column != null:
				firecolumn.previous_pre_spawn_done.connect(previous_column._on_previous_pre_spawn_done)
			spawn_list.append(firecolumn)
			previous_column = firecolumn
	previous_column.is_last = true
	return spawn_list


func _ready() -> void:
	super._ready()
	visible = is_last
	$CollisionShape2D.disabled = true
	$Timeout.start()
	# Garde anti double-coup : suivre les sorties de zone (l'entrée est
	# gérée par le _on_body_entered de la base, déjà câblé dans la scène)
	body_exited.connect(_on_body_exited)
	if is_last:
		start()


## Règle validée : être dans une colonne de feu protège d'un nouveau
## coup de colonne de feu (chaîne de colonnes = un seul toc par passage).
func can_damage(body: Node2D) -> bool:
	return not double_toc_bloque(body)


func start() -> void:
	visible = true
	$AnimatedSprite2D.play("pre_spawn")

func _on_previous_pre_spawn_done() -> void:
	start()


func _on_timeout_timeout() -> void:
	queue_free()


func _on_animated_sprite_2d_animation_finished() -> void:
	match $AnimatedSprite2D.animation:
		&"pre_spawn":
			previous_pre_spawn_done.emit()
			$AnimatedSprite2D.play("spawn")
			$CollisionShape2D.disabled = false
		&"spawn":
			$AnimatedSprite2D.play("idle")
