class_name AttackPlantBramble
extends RigidBody2D

# Ronce dirigeable (P3, PlantBrush) : une base sort du sol au point de tir,
# puis des tronçons poussent en chaîne (comme les phalanges d'un doigt),
# chacun dans la direction du précédent ±60°, pilotée par le stick.
#
# Le lanceur est immobilisé pendant la croissance (comme la cible L2).
# Fins possibles :
#  - 2e appui sur le bouton ou dash → gel sur place 2 s, puis décomposition
#    depuis le bout de la ronce (le dernier tronçon) vers la base ;
#  - contact ennemi (1 dégât) → décomposition depuis le tronçon touché,
#    dans les deux sens ;
#  - fin de croissance naturelle → gel automatique 2 s, puis décomposition
#    depuis le bout.
# Chaque tronçon passe en Decomposition à sa frame 2, en cascade de 0,1 s.
# La hitbox disparaît dès qu'un tronçon se décompose ; la base disparaît
# quand la cascade atteint le premier tronçon.

const SEGMENT_SCENE: PackedScene = preload("res://scenes/atk/atk_p3_bramble_segment.tscn")

# Bulbe de pointe : coiffe le tronçon en cours de pousse pendant TOUTE la
# croissance (déplacé de tronçon en tronçon), puis reste sur le dernier.
# Son anim (Bite1 → Bite21) est synchronisée sur la durée totale de pousse :
# jouée plus lentement au tier III, dont la ronce met plus de temps à pousser.
# Contenu ancré en bas du canvas 96×64.
const TIP_BULB_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite1.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite2.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite3.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite4.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite5.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite6.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite7.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite8.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite9.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite10.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite11.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite12.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite13.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite14.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite15.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite16.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite17.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite18.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite19.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite20.png"),
	preload("res://assets/sprites/Attaques/Plante/AtkP1_Carnivorous/CarnivorV2/Atk_P_Bite2/Atk_P_1_V2_Bite21.png"),
]
const TIP_BULB_CANVAS_BOTTOM := 32.0   # distance centre→bas du canvas 96×64
# Enfoncement du bulbe dans la tige : son contenu ne remplit pas tout le
# bas du canvas → on le fait chevaucher la pointe pour supprimer l'espace
# perçu entre le bulbe et le dernier tronçon (moitié d'un espacement = 8 px)
const TIP_BULB_SINK := 8.0
# Échelle du bulbe : c'est le MÊME sprite que la tête de la plante P1,
# laquelle n'a pas d'échelle propre (cf. apply_level_scale de la graine P1
# : seule la graine en vol est agrandie). Le multiplier par le
# grossissement des ronces (sprite_scale_multiplier) le rendait 1,4× plus
# gros que la tête carnivore. À 1.0, il a exactement la taille de la tête
# P1, et suit l'échelle de la scène comme elle.
const TIP_BULB_SCALE := 1.0

# Hauteur du dessin d'un tronçon dans son canvas 32×16 : le contenu occupe
# toute la hauteur. L'espacement entre tronçons en découle pour qu'ils se
# touchent sans trou, quelle que soit l'échelle.
const SEGMENT_CONTENT_HEIGHT := 16.0
## Vitesse de pousse : 1 tronçon toutes les 0,1 s (2× plus rapide qu'à
## l'origine, 0,2 s). L'anim Grow de chaque tronçon est accélérée d'autant
## (GROW_SPEED_SCALE, transmise au tronçon) pour se terminer avant l'émission
## du suivant.
const SEGMENT_INTERVAL := 0.1
## speed_scale de l'anim Grow : 8 frames à 12 fps = 0,667 s à vitesse 1,
## donc 0,667 / SEGMENT_INTERVAL ≈ 6,8 pour finir en ~0,1 s
const GROW_SPEED_SCALE := 6.8
const GEL_DURATION := 2.0              # gel avant décomposition
const CASCADE_INTERVAL := 0.1          # 0,1 s entre deux tronçons qui se décomposent
const BASE_APPEAR_DURATION := 0.3      # apparition de la base : scale 0 → 100 %
const CLEANUP_DELAY := 1.5             # après la fin de la cascade (anim decomp : 1,4 s)

# Graine (vol initial, cf. graine P1)
const SEED_REST_SPEED := 10.0          # vitesse sous laquelle la graine est posée
const MONDE_MASK := 8                  # calque du décor (tuiles) : seuls les sols comptent


# Grossissement des sprites : les ronces natives font 32×16 px, trop petits
# face aux personnages ; 2× comme la plante carnivore (P1)
@export var sprite_scale_multiplier: float = 2.0

enum Phase { FLYING, GROWING, WAITING, DECOMPOSING }

var caster: Node2D = null
var attack_tier: int = 1
var direction := Vector2.UP
var level_scale := Vector2.ONE
# Vélocité initiale de la graine (fixée par le spawner au tir)
var launch_velocity := Vector2(200.0, 0)
var phase := Phase.FLYING

var _segments: Array[AttackPlantBrambleSegment] = []
var _max_segments := 3
var _spawn_timer := 0.0
var _wait_timer := 0.0
var _next_position := Vector2.ZERO
var _cascade_order: Array[int] = []
var _cascade_timer := 0.0
var _cleanup_started := false
var _tip_bulb: Sprite2D = null         # bulbe glissant sur la pointe de la ronce
var _growth_elapsed := 0.0             # temps écoulé depuis la plantation
var _bulb_segment_index := 0           # tronçon actuellement coiffé par le bulbe
var _connector_done := false           # tronçon de liaison fini de pousser
## Direction du dernier tronçon posé : l'angle entre deux tronçons
## consécutifs est limité à ±_get_max_turn() au moment de la pose
var _last_direction := Vector2.UP
## Rebond de la graine sur les sorciers (composant réutilisable)
var _rebond: RebondSorciers = null

@onready var base_back: AnimatedSprite2D = $BaseBack
@onready var base_front: AnimatedSprite2D = $BaseFront
@onready var seed_sprite: Sprite2D = $SeedSprite
@onready var seed_collision: CollisionShape2D = $SeedCollision


func _ready() -> void:
	add_to_group("plant_bramble_group")
	_max_segments = 5 + (attack_tier - 1) * 4
	# Graine en vol : même échelle que la graine P1 (2 × level_scale)
	var e := level_scale.x * 2.0
	seed_sprite.scale = Vector2(e, e)
	seed_collision.scale = Vector2(e, e)
	linear_velocity = launch_velocity
	# La base n'apparaît qu'une fois la graine plantée
	base_back.scale = Vector2.ZERO
	base_front.scale = Vector2.ZERO
	# Rebond sur les sorciers : composant réutilisable (détection du corps
	# visible, normale calculée contre la capsule élargie jusqu'aux pieds,
	# ennemis traversés, lanceur inclus dans les rebonds)
	_rebond = RebondSorciers.new()
	_rebond.echelle = seed_collision.scale.x
	add_child(_rebond)


func is_growing() -> bool:
	return phase == Phase.GROWING


func _process(delta: float) -> void:
	# Phase graine (cf. atk_p1_carnivorous_seed.gd) : la graine vole puis
	# ne plante que si sa place est libre
	if phase != Phase.FLYING:
		return
	if linear_velocity.length() < SEED_REST_SPEED:
		# Éclosion uniquement posée sur le sol (cf. graine P1) : au sommet
		# d'un lancer vertical la vitesse est aussi ~0
		if _is_on_ground() and _is_spot_free():
			_plant()
		return
	if linear_velocity.dot(Vector2.RIGHT) < 0:
		seed_sprite.flip_h = true




## Vrai si aucun ennemi ni sorcier ne chevauche la graine : la ronce ne
## doit éclore que sur le sol (copié de la graine P1)
func _is_spot_free() -> bool:
	var space_state := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = seed_collision.shape
	params.transform = seed_collision.global_transform
	# Masque tous les calques pour détecter ennemis et sorciers où qu'ils soient
	params.collision_mask = 0x7FFFFFFF
	params.exclude = [get_rid()]
	for hit in space_state.intersect_shape(params):
		var collider = hit.collider
		if collider.is_in_group("enemy_group") or collider.is_in_group("player_group"):
			return false
	return true


## Plantation : la graine gèle au sol, disparaît, et la base sort de terre
func _plant() -> void:
	phase = Phase.GROWING
	freeze = true
	rotation = 0.0
	_snap_to_ground()
	seed_sprite.visible = false
	seed_collision.set_deferred("disabled", true)
	# La base sort de terre : scale 0 → 100 %. Les deux couches jouent
	# l'animation par défaut définie dans la scène (BaseBack derrière la
	# ronce via z_index -1, BaseFront devant via z_index 1)
	base_back.visible = true
	base_front.visible = true
	base_back.play()
	base_front.play()
	var target_scale := level_scale * sprite_scale_multiplier
	var tween := create_tween().set_parallel(true)
	tween.tween_property(base_back, "scale", target_scale, BASE_APPEAR_DURATION)
	tween.tween_property(base_front, "scale", target_scale, BASE_APPEAR_DURATION)
	# Bulbe de pointe : au-dessus des tiges (z 0), il glisse le long de la
	# ronce pendant la croissance
	# Bulbe de pointe : au-dessus des tiges (z 0), il glisse le long de la
	# ronce pendant la croissance. Nearest : comme tous les sprites du jeu
	# (les nœuds de la scène P3 sont en Nearest, ce nœud créé au runtime
	# doit l'être aussi, sinon il serait lissé)
	_tip_bulb = Sprite2D.new()
	_tip_bulb.texture = TIP_BULB_FRAMES[0]
	_tip_bulb.z_index = 1
	_tip_bulb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tip_bulb.scale = Vector2(TIP_BULB_SCALE, TIP_BULB_SCALE)
	add_child(_tip_bulb)
	# Premier tronçon immédiat, depuis la base
	_next_position = Vector2.ZERO
	_last_direction = direction
	_spawn_segment()
	_spawn_timer = 0.0


## Vrai si la graine repose sur le sol (rayon court vers le bas, cf. P1)
## Restreint au DÉCOR (calque tuiles) : sans ça, un sorcier qui saute
## sous la graine flottante est pris pour du sol et la ronce pousse en
## plein vol à son sommet
func _is_on_ground() -> bool:
	var space_state := get_world_2d().direct_space_state
	var half_height: float = (seed_collision.shape.height / 2.0) * seed_collision.scale.y
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, half_height + 6.0)
	)
	query.exclude = [get_rid()]
	query.collision_mask = 8
	return not space_state.intersect_ray(query).is_empty()


## Colle la graine (et donc la base de la ronce) au sol (copié de la graine P1)
func _snap_to_ground() -> void:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -50),
		global_position + Vector2(0, 200)
	)
	query.exclude = [get_rid()]
	# Décor uniquement : un sorcier sous la graine ne doit pas servir de sol
	query.collision_mask = 8
	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y


# Gel (2e appui ou dash) : la ronce reste à son stade actuel 2 s, puis se
# décompose depuis le haut. Les tronçons en pleine pousse passent en Idle.
# NB : nom "freeze_growth" car "freeze" est déjà la propriété RigidBody2D.
func freeze_growth() -> void:
	if phase != Phase.GROWING:
		return
	phase = Phase.WAITING
	_wait_timer = 0.0
	for seg in _segments:
		seg.freeze_to_idle()


func _physics_process(delta: float) -> void:
	match phase:
		Phase.FLYING:
			pass # graine en vol : géré dans _process
		Phase.GROWING:
			_process_growing(delta)
		Phase.WAITING:
			_wait_timer += delta
			# Le bulbe continue de suivre la pointe pendant la pousse du
			# tronçon de liaison, puis se cale exactement (sans saut : sa
			# cible est déjà au sommet quand grow_done passe à true)
			_update_bulb_frame()
			_update_bulb_position(false, delta)
			if not _connector_done and _segments[_segments.size() - 1].grow_done:
				_connector_done = true
				_update_bulb_position(true)
				if _tip_bulb != null:
					_tip_bulb.texture = TIP_BULB_FRAMES[TIP_BULB_FRAMES.size() - 1]
			if _wait_timer >= GEL_DURATION:
				_start_decomposition_from_top()
		Phase.DECOMPOSING:
			_process_decomposing(delta)


func _process_growing(delta: float) -> void:
	_steer()
	_growth_elapsed += delta
	_update_bulb_frame()
	_update_bulb_position(false, delta)
	_spawn_timer += delta
	if _spawn_timer >= SEGMENT_INTERVAL and _segments.size() < _max_segments:
		_spawn_timer = 0.0
		_spawn_segment()
	# Fin de croissance : tous les tronçons sont poussés et le dernier a
	# terminé son Grow → gel automatique 2 s
	if _segments.size() >= _max_segments and _segments[_segments.size() - 1].grow_done:
		phase = Phase.WAITING
		_wait_timer = 0.0
		# Tronçon de liaison : comble l'espace entre la dernière tige et le
		# bulbe (suit la direction du dernier tronçon, participe à la cascade).
		# Le bulbe le suit pendant sa pousse (voir WAITING) et ne se cale
		# sur son sommet que lorsqu'il a fini de pousser.
		_spawn_connector_segment()


# Angle maximal entre un tronçon et le suivant, qui dépend du tier :
# ±25° au tier 1, ±35° au tier 2, ±45° au tier 3.
func _get_max_turn() -> float:
	match attack_tier:
		1:
			return deg_to_rad(25.0)
		2:
			return deg_to_rad(35.0)
		3:
			return deg_to_rad(45.0)
		_:
			return deg_to_rad(45.0)


func _steer() -> void:
	# Direction voulue par le lanceur (comme la cible L2 : si le lanceur a
	# disparu, la ronce continue dans la dernière direction connue)
	var controller := 0
	if caster != null and is_instance_valid(caster) and "input_device" in caster:
		controller = caster.input_device
	var stick := PlayerInput.direction(controller)
	if stick.length() < 0.2:
		return
	var prev_angle := direction.angle()
	# wrapf : take le plus court chemin angulaire, puis limite à ±60°
	var delta_angle := wrapf(stick.normalized().angle() - prev_angle, -PI, PI)
	var clamped := clampf(delta_angle, -_get_max_turn(), _get_max_turn())
	direction = Vector2.RIGHT.rotated(prev_angle + clamped)


# Espacement entre les origines de deux tronçons consécutifs : la hauteur
# du contenu du sprite × scale effectif → tronçons collés, sans trou
func _segment_spacing() -> float:
	return SEGMENT_CONTENT_HEIGHT * level_scale.x * sprite_scale_multiplier


func _spawn_segment() -> void:
	var seg: AttackPlantBrambleSegment = SEGMENT_SCENE.instantiate()
	seg.index = _segments.size()
	seg.level_scale = level_scale * sprite_scale_multiplier
	seg.position = _next_position
	# Angle entre ce tronçon et le précédent limité à ±max_turn (±25°/35°/45°
	# selon le tier) : le stick pilote `direction` en continu, mais c'est à
	# la POSE du tronçon que l'écart avec le précédent est bridé
	var prev_angle := _last_direction.angle()
	var delta_angle := wrapf(direction.angle() - prev_angle, -PI, PI)
	var max_turn := _get_max_turn()
	var seg_direction := Vector2.RIGHT.rotated(prev_angle + clampf(delta_angle, -max_turn, max_turn))
	_last_direction = seg_direction
	# Les sprites de ronce sont dessinés verticaux (pointant vers le haut,
	# comme les segments de la colonne F1) : angle + PI/2 → direction UP
	# = sprite non pivoté
	seg.rotation = seg_direction.angle() + PI / 2.0
	seg.enemy_touched.connect(_on_enemy_touched)
	add_child(seg)
	# Le lanceur peut avoir disparu (mort, changement de scène) pendant la
	# pousse : on ne transmet que s'il est encore valide
	if caster != null and is_instance_valid(caster):
		seg.caster = caster
	seg.grow_speed_scale = GROW_SPEED_SCALE
	seg.start_grow()
	_segments.append(seg)
	_bulb_segment_index = seg.index
	_next_position += seg_direction * _segment_spacing()


# Positionne le bulbe sur la pointe VISIBLE de la ronce : il glisse le
# long de la polyligne formée par les tronçons (suit aussi la courbure
# imposée par le stick), du bas du premier sprite à la plantation jusqu'au
# haut du dernier sprite en fin de croissance. Continu → pas de téléportation.
func _update_bulb_position(full: bool = false, delta: float = 0.0) -> void:
	if _tip_bulb == null or _segments.is_empty():
		return
	var spacing := _segment_spacing()
	# Longueur déjà poussée depuis la base : tronçons terminés + progression
	# du tronçon en cours (son Grow dure ~l'intervalle d'émission)
	var grown: float
	if full:
		grown = spacing * _segments.size()
	else:
		# Sync sur la progression RÉELLEMENT DESSINÉE de la tige en cours
		# (frames de l'anim Grow) : le bulbe reste collé au bout visible au
		# lieu d'avancer à vitesse constante pendant que la tige progresse
		# par à-coups d'images
		grown = (_segments.size() - 1) * spacing \
			+ _segments[_segments.size() - 1].grow_fraction() * spacing
	# Parcours de la polyligne : tronçon i couvre l'arc [i*spacing, (i+1)*spacing]
	var i := mini(int(grown / spacing), _segments.size() - 1)
	var covered := grown - i * spacing
	var seg := _segments[i]
	var d := Vector2.UP.rotated(seg.rotation)  # direction du tronçon (sprites verticaux)
	var tip := seg.position + d * covered
	# Le bulbe s'oriente comme le tronçon qu'il coiffe (texture dessinée
	# verticale, même convention que les tiges). Rotation lissée par
	# lerp_angle pour éviter les à-coups quand un nouveau tronçon tourne.
	if full:
		_tip_bulb.rotation = seg.rotation
	else:
		_tip_bulb.rotation = lerp_angle(_tip_bulb.rotation, seg.rotation, minf(1.0, delta * 15.0))
	# Origine du bulbe : contenu ancré en bas du canvas (32 px), enfoncé de
	# TIP_BULB_SINK dans la tige pour que le bas du bulbe chevauche la pointe
	# (offset × échelle du bulbe, pas celle des tronçons)
	var target := tip + d * ((TIP_BULB_CANVAS_BOTTOM - TIP_BULB_SINK) * TIP_BULB_SCALE)
	if full:
		_tip_bulb.position = target
	else:
		# Lissage exponentiel : la cible est quantifiée par les frames de
		# l'anim Grow ; le lerp absorbe les sauts → mouvement continu
		_tip_bulb.position = _tip_bulb.position.lerp(target, minf(1.0, delta * 20.0))


# Avance l'anim du bulbe (Bite1 → Bite21) proportionnellement à la durée
# totale de croissance : plus lente au tier III qu'au tier I
func _update_bulb_frame() -> void:
	if _tip_bulb == null:
		return
	var total := SEGMENT_INTERVAL * _max_segments
	var p := clampf(_growth_elapsed / total, 0.0, 1.0)
	_tip_bulb.texture = TIP_BULB_FRAMES[int(p * (TIP_BULB_FRAMES.size() - 1))]


# Tronçon de liaison fin de pousse : dans le prolongement direct du
# dernier tronçon (même direction, pas de pilotage stick)
func _spawn_connector_segment() -> void:
	var last := _segments[_segments.size() - 1]
	var seg: AttackPlantBrambleSegment = SEGMENT_SCENE.instantiate()
	seg.index = _segments.size()
	seg.level_scale = level_scale * sprite_scale_multiplier
	seg.position = last.position + Vector2.UP.rotated(last.rotation) * _segment_spacing()
	seg.rotation = last.rotation
	seg.enemy_touched.connect(_on_enemy_touched)
	add_child(seg)
	if caster != null and is_instance_valid(caster):
		seg.caster = caster
	seg.grow_speed_scale = GROW_SPEED_SCALE
	seg.start_grow()
	_segments.append(seg)
	_bulb_segment_index = seg.index


# Décomposition déclenchée par un contact ennemi sur le tronçon `index` :
# cascade dans les deux sens depuis le point de contact
func _on_enemy_touched(index: int) -> void:
	if phase == Phase.DECOMPOSING:
		return
	var order: Array[int] = []
	for d in range(_segments.size()):
		if index + d < _segments.size():
			order.append(index + d)
		if d > 0 and index - d >= 0:
			order.append(index - d)
	_begin_decomposition(order)


# Décomposition depuis le bout de la ronce vers la base (gel / fin de
# croissance)
func _start_decomposition_from_top() -> void:
	var order: Array[int] = []
	for i in range(_segments.size() - 1, -1, -1):
		order.append(i)
	_begin_decomposition(order)


func _begin_decomposition(order: Array[int]) -> void:
	phase = Phase.DECOMPOSING
	_cascade_order = order
	_cascade_timer = 0.0


func _process_decomposing(delta: float) -> void:
	if not _cascade_order.is_empty():
		_cascade_timer -= delta
		if _cascade_timer > 0.0:
			return
		_cascade_timer = CASCADE_INTERVAL
		var seg_index: int = _cascade_order.pop_front()
		if seg_index < _segments.size() and is_instance_valid(_segments[seg_index]):
			_segments[seg_index].start_decomposition()
			# Le bulbe disparaît quand la cascade atteint le tronçon qu'il coiffe
			if _tip_bulb != null and seg_index == _bulb_segment_index:
				_tip_bulb.queue_free()
				_tip_bulb = null
		# La base disparaît quand la cascade atteint le premier tronçon
		if seg_index == 0:
			base_back.visible = false
			base_front.visible = false
	else:
		# Cascade terminée : les tronçons finissent leur anim puis se
		# libèrent ; on libère le conteneur juste après
		if not _cleanup_started:
			_cleanup_started = true
			get_tree().create_timer(CLEANUP_DELAY).timeout.connect(queue_free)
