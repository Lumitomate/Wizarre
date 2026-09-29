class_name AttackPlantBrambleSegment
extends Area2D

# Un tronçon de ronce (P3) : pousse (Grow), reste en place (Idle), puis se
# décompose (Decomposition démarrant à la frame 2). La hitbox est active
# dès le début du Grow ; un contact ennemi blesse et prévient le conteneur.

signal grow_finished
signal enemy_touched(index: int)

var caster: Node2D = null
var index: int = 0
var level_scale := Vector2.ONE
var damage: int = 1
var grow_done := false
## Vitesse de l'anim Grow, fixée par le conteneur (atk_p3_plant_bramble.gd)
## pour rester synchronisée avec l'intervalle d'émission des tronçons
var grow_speed_scale: float = 3.4

var _decomposing := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: CollisionShape2D = $CollisionShape2D_hitboxDamage


func _ready() -> void:
	collision_mask = 5
	sprite.scale = level_scale
	# La hitbox suit le grossissement des sprites : le scale du nœud
	# grossit la forme autour de SON origine, il faut donc aussi décaler
	# la position (hauteur de forme 16 px ancrée au bas du canvas)
	var e := level_scale.x
	hitbox.scale = Vector2(e, e)
	hitbox.position = Vector2(0, -8.0 * e)
	body_entered.connect(_on_body_entered)
	sprite.animation_finished.connect(_on_sprite_animation_finished)


## Progression de pousse réellement dessinée (0 → 1) : combine l'index de
## frame et la progression dans la frame. Utilisée par le conteneur pour
## coller le bulbe à la pointe visible de la tige.
func grow_fraction() -> float:
	# Idle = tige entière dessinée (y compris après un gel en pleine pousse)
	if grow_done or sprite.animation == &"Idle":
		return 1.0
	if sprite.animation != &"Grow":
		return 0.0
	var count := sprite.sprite_frames.get_frame_count(&"Grow")
	if count == 0:
		return 0.0
	return clampf((float(sprite.frame) + sprite.frame_progress) / float(count), 0.0, 1.0)


func start_grow() -> void:
	# 8 frames : accélérées pour finir avant le tronçon suivant (l'intervalle
	# d'émission et la vitesse correspondante sont fixés par le conteneur)
	sprite.speed_scale = grow_speed_scale
	sprite.play("Grow")


func freeze_to_idle() -> void:
	# Gel (dash ou 2e appui) : le tronçon reste à son stade actuel,
	# on saute directement à Idle
	if _decomposing or sprite.animation != &"Grow":
		return
	sprite.speed_scale = 1.0
	sprite.play("Idle")


func start_decomposition() -> void:
	if _decomposing:
		return
	_decomposing = true
	# La hitbox disparaît dès que le tronçon se décompose
	hitbox.set_deferred("disabled", true)
	sprite.speed_scale = 1.0
	sprite.play("decomposition")
	# La décomposition démarre à la frame 2 de l'anim (spec P3)
	sprite.frame = 2


func _on_sprite_animation_finished() -> void:
	match sprite.animation:
		&"Grow":
			sprite.speed_scale = 1.0
			sprite.play("Idle")
			grow_done = true
			grow_finished.emit()
		&"decomposition":
			queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _decomposing:
		return
	# Le lanceur peut avoir été libéré entre-temps (mort, changement de scène)
	var reprisal_caster: Node2D = caster if caster != null and is_instance_valid(caster) else null
	if body.is_in_group("enemy_group"):
		body.hit(damage, reprisal_caster)
		enemy_touched.emit(index)
	elif body.is_in_group("player_group"):
		# Tout sorcier au contact est blessé (y compris le lanceur)
		body.hit(damage)
