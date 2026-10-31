## ═══════════════════════════════════════════════════════════════════════
##  G1 · BOULE DE GLACE — famille Glace — atk_g1_ice_ball.tscn
## ═══════════════════════════════════════════════════════════════════════
##  JEU   : boule de glace physique lancée devant le sorcier (rebonds).
##  TIER  : taille ×0.50 / ×0.75 / ×1.00 et vitesse de lancement
##          200 / 600 / 900.
##  SPAWN : lancée à 60 px devant le sorcier, transform orienté selon la
##          visée, taille via apply_level_scale.
##  CORPS : RigidBody2D — physique libre (rebonds), HORS contrat anti
##          double-coup d'AttackProjectile.
class_name AttackIceBall extends RigidBody2D

@export var spawn_immunity_time: float = 1.0 # durée d'immunité du lanceur après le spawn

var caster: Node2D = null
var player_immunity: bool = true # le lanceur ne peut pas se toucher juste après le tir

## Contrat de spawn (cf. AttackSpawner) : une boule de glace lancée
## devant le sorcier — taille et vitesse de lancement selon le tier.
static var _SCENE: PackedScene = null
static func setup_spawn(attack_tier: int, position: Vector2, direction: Vector2, _screen_size: Vector2, level_scale: Vector2, caster: Node2D) -> Array[Node]:
	if _SCENE == null:
		_SCENE = load("res://scenes/atk/atk_g1_ice_ball.tscn")
	var ice_ball: AttackIceBall = _SCENE.instantiate()
	ice_ball.caster = caster
	ice_ball.transform = ice_ball.transform.rotated(direction.angle())
	# Taille par tier : le tier 3 garde la taille actuelle (facteur 1),
	# tier 2 = 75 %, tier 1 = 50 %
	var g1_tier_scale := 0.5 + 0.25 * (attack_tier - 1)
	ice_ball.apply_level_scale(2 * level_scale * g1_tier_scale)
	ice_ball.position = position + 60 * direction.normalized()
	# Vitesse de lancement par tier : le tier 1 part moins fort
	# (200 au lieu de 300), les tiers suivants gardent leur vitesse
	const G1_LAUNCH_SPEEDS := [200.0, 600.0, 900.0]
	ice_ball.linear_velocity = Vector2(G1_LAUNCH_SPEEDS[attack_tier - 1], 0).rotated(direction.angle())
	return [ice_ball]


func _ready() -> void:
	$AnimatedSprite2D.play("default")
	# Immunité du lanceur pendant spawn_immunity_time après le tir
	await get_tree().create_timer(spawn_immunity_time).timeout
	player_immunity = false

func can_damage(body: Node2D) -> bool:
	# Le lanceur est immunisé juste après le tir (la boule part devant lui)
	return not (player_immunity and body == caster)

func _on_body_entered(body: Node2D) -> void:
	if not can_damage(body):
		return
	if body.is_in_group("enemy_group"):
		# Origine = la boule de glace : l'ennemi éclate dans le sens de son vol
		# Attaquant validé : le caster peut être libéré (morte pendant le vol)
		body.hit(1, EntityFinder.attaquant_valide(caster), self)
	elif body.is_in_group("player_group"):
		body.hit(1)

func apply_level_scale(level_scale: Vector2) -> void:
	$AnimatedSprite2D.scale = level_scale
	$CollisionShape2D.scale = level_scale

func _process(_delta: float) -> void:
	if linear_velocity.length() < 10:
		queue_free()
	
	if linear_velocity.dot(Vector2.RIGHT) < 0:
		$AnimatedSprite2D.flip_h = true
