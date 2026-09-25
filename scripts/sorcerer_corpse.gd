class_name SorcererCorpse
extends CharacterBody2D

# Cadavre de sorcier laissé au sol après la mort (remplace l'ancienne
# disparition par queue_free) :
# - premier bond léger vers le haut, direction horizontale aléatoire ;
# - figé sur la frame 0 de l'animation "death", plus contrôlable ;
# - collision_layer = 0 : toutes les entités passent à travers, mais elles le
#   poussent très légèrement quand elles le chevauchent ;
# - collision_mask = 12 : seule la tilemap (physics layer 12) le bloque ;
# - périodiquement (4 à 20 s), si aucun autre sorcier n'est à moins de 100 px,
#   il rejoue l'animation "death" une fois puis revient sur la frame 0 ;
# - il disparaît (fondu) quand son joueur reprend vie : un nouveau sorcier
#   apparaît au magasin suivant.

const GRAVITY := 3000.0          # même gravité que le sorcier vivant
const HOP_HORIZONTAL := 150.0    # amplitude horizontale aléatoire du bond
const HOP_VERTICAL := 300.0      # impulsion verticale du bond
const FRICTION := 200.0          # décélération horizontale (px/s²)
const PUSH_RADIUS := 48.0        # distance en dessous de laquelle une entité pousse le corps
const PUSH_ACCELERATION := 150.0 # force (très légère) avec laquelle le corps est poussé
const PROXIMITY_RADIUS := 100.0  # distance "trop proche" d'un autre sorcier
const REPLAY_MIN_DELAY := 4.0    # délai mini avant de rejouer l'animation
const REPLAY_MAX_DELAY := 20.0   # délai maxi avant de rejouer l'animation
const REVIVE_POLL_INTERVAL := 1.0 # fréquence de vérification de la renaissance
const FADE_DURATION := 0.6       # durée du fondu de disparition
const FALL_OVER_DURATION := 0.45 # durée de la bascule à l'horizontale

var controller_id: int = 0

var _sprite: AnimatedSprite2D
var _replay_delay: float = 0.0
var _replay_timer: float = 0.0
var _is_replaying: bool = false
var _poll_timer: float = 0.0
var _is_fading: bool = false


# Construit le cadavre à partir d'un sorcier : copie transform, forme de
# collision, sprite frames et matériau (couleurs de robe du défunt).
static func from_sorcerer(sorcerer: Sorcerer) -> SorcererCorpse:
	var corpse := SorcererCorpse.new()
	corpse.controller_id = sorcerer.controller_id
	corpse.position = sorcerer.position
	corpse.scale = sorcerer.scale
	var source_sprite: AnimatedSprite2D = sorcerer.get_node("AnimatedSprite2D")
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = source_sprite.sprite_frames
	sprite.animation = &"death"
	sprite.frame = 0
	sprite.flip_h = source_sprite.flip_h
	sprite.texture_filter = source_sprite.texture_filter
	# Matériau dupliqué pour conserver les couleurs de robe du défunt
	# (le matériau source appartient au sorcier sur le point d'être libéré)
	sprite.material = source_sprite.material.duplicate()
	corpse.add_child(sprite)
	var source_shape: CollisionShape2D = sorcerer.get_node("CollisionShape2D")
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.shape = source_shape.shape
	shape.position = source_shape.position
	corpse.add_child(shape)
	return corpse


func _ready() -> void:
	# Toutes les entités passent à travers (plus rien ne le détecte), mais le
	# corps reste bloqué par la tilemap (physics layer 12)
	collision_layer = 0
	collision_mask = 12
	add_to_group("corpse_group")

	_sprite = get_node("AnimatedSprite2D")
	# Reste figé sur la frame 0 de "death" (l'animation n'est pas lancée)
	_sprite.stop()
	_sprite.animation_finished.connect(_on_animation_finished)

	# Petit bond unique vers le haut, direction horizontale aléatoire
	velocity = Vector2(randf_range(-HOP_HORIZONTAL, HOP_HORIZONTAL), -HOP_VERTICAL)
	_replay_delay = randf_range(REPLAY_MIN_DELAY, REPLAY_MAX_DELAY)

	# Bascule à l'horizontale (effet ragdoll) : le corps tombe dans le sens
	# de son élan. Légère sur-rotation puis stabilisation (TRANS_BACK).
	var fall_dir := signf(velocity.x)
	if fall_dir == 0.0:
		fall_dir = 1.0 if randf() < 0.5 else -1.0
	var fall_tween := create_tween()
	fall_tween.tween_property(_sprite, "rotation", fall_dir * PI / 2.0, FALL_OVER_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _is_fading:
		return

	# Gravité + frottement horizontal : le corps retombe et se stabilise
	velocity.y += GRAVITY * delta
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	move_and_slide()
	if is_on_floor():
		velocity.y = 0.0

	_apply_entity_push()
	_update_replay(delta)
	_update_revive_poll(delta)


# Les entités passent à travers le corps, mais le chevauchement le pousse
# très légèrement (effet "ragdoll mou") sans jamais le déplacer loin.
func _apply_entity_push() -> void:
	var push := Vector2.ZERO
	for group_name in ["player_group", "enemy_group"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Node2D:
				var entity := node as Node2D
				var offset: Vector2 = global_position - entity.global_position
				var dist := offset.length()
				if dist < PUSH_RADIUS and dist > 0.01:
					push += offset / dist
	if push != Vector2.ZERO:
		velocity += push.normalized() * PUSH_ACCELERATION * get_physics_process_delta_time()


# Toutes les REPLAY_MIN_DELAY..REPLAY_MAX_DELAY secondes : si aucun autre
# sorcier n'est trop proche, rejoue "death" une fois puis revient frame 0.
func _update_replay(delta: float) -> void:
	if _is_replaying:
		return
	_replay_timer += delta
	if _replay_timer < _replay_delay:
		return
	_replay_timer = 0.0
	_replay_delay = randf_range(REPLAY_MIN_DELAY, REPLAY_MAX_DELAY)
	if _is_other_sorcerer_close():
		return
	_is_replaying = true
	_sprite.play("death")


func _is_other_sorcerer_close() -> bool:
	for node in get_tree().get_nodes_in_group("player_group"):
		if node is Node2D and global_position.distance_to(node.global_position) < PROXIMITY_RADIUS:
			return true
	return false


# Fin de la rejoue de "death" : retour figé sur la frame 0.
func _on_animation_finished() -> void:
	if _sprite.animation == &"death":
		_sprite.stop()
		_sprite.frame = 0
		_is_replaying = false


# Le joueur a repris vie au magasin suivant → le corps disparaît en fondu.
func _update_revive_poll(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer < REVIVE_POLL_INTERVAL:
		return
	_poll_timer = 0.0
	for node in get_tree().get_nodes_in_group("player_group"):
		if node is Sorcerer and node.controller_id == controller_id:
			_start_fade()
			return


func _start_fade() -> void:
	if _is_fading:
		return
	_is_fading = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(queue_free)
