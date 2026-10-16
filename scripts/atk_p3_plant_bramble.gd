class_name AttackPlantBramble
extends RigidBody2D

# Ronce dirigeable (P3, PlantBrush) : une base sort du sol au point de tir,
# puis des TIGES poussent en parallèle depuis cette même base — 1 au
# tier I, 2 au tier II, 3 au tier III. Une tige est une chaîne de
# tronçons (comme les phalanges d'un doigt), chacun dans la direction du
# précédent ±max_turn, pilotée par le stick (toutes les tiges suivent le
# stick de la même façon) ; ce sont les PREMIERS tronçons, pré-écartés
# en éventail, qui séparent les tiges. Au tier III, les têtes partent
# avec un léger décalage (gauche → centre → droite). Chaque tige a son
# propre bulbe de tête et son budget de tronçons (budget TOTAL conservé :
# 5 / 9 / 13, réparti au plus juste — surplus à la première lancée au
# tier II, à la centrale au tier III).
#
# Le lanceur est immobilisé pendant la croissance (comme la cible L2).
# Fins possibles :
#  - 2e appui sur le bouton ou dash → gel sur place 2 s (dès que la
#    dernière tige a fini de pousser), puis décomposition de chaque tige
#    depuis son bout vers la base, cascades simultanées ;
#  - contact ennemi (1 dégât) → SEULE la tige touchée se décompose
#    (cascade dans les deux sens depuis le tronçon touché), les autres
#    tiges continuent de vivre et de pousser ;
#  - fin de croissance naturelle → gel automatique 2 s, puis
#    décomposition de toutes les tiges.
# Chaque tronçon passe en Decomposition à sa frame 2, en cascade de 0,1 s.
# La hitbox disparaît dès qu'un tronçon se décompose ; la base (commune
# à toutes les tiges) disparaît quand TOUTES les tiges ont été décomposées.

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

# --- Multi-tiges ---
## Écart initial des premières directions : l'éventail de départ qui
## sépare les tiges (commun aux tiers multi-tiges)
const ECART_TIGES_DEG := 25.0
## Décalage de départ des têtes au tier III (gauche → centre → droite)
const ECART_TIGES := 0.15
## Nombre de premiers tronçons qui posent la direction d'écartement de
## la tige avant de suivre le stick (2 → séparation visible sans excès)
const TIGES_TRONCONS_ECART := 2

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

## Une tige : une chaîne de tronçons + son bulbe de tête, avec tout son
## état de pousse et de décomposition. Toutes partent de la même base.
class Tige:
	var segments: Array[AttackPlantBrambleSegment] = []
	var budget: int = 5                  # tronçons à émettre (hors tronçon de liaison)
	var next_position := Vector2.ZERO    # position de pose du prochain tronçon
	var last_direction := Vector2.UP     # direction du dernier tronçon posé
	var bulb: Sprite2D = null            # bulbe de tête (naît au 1er tronçon)
	var bulb_segment_index := 0          # tronçon actuellement coiffé par le bulbe
	var connector_spawned := false       # tronçon de liaison émis (fin naturelle)
	var connector_done := false          # tronçon de liaison fini de pousser
	var start_delay := 0.0               # décalage de départ (tier III)
	var spawn_timer := 0.0
	var elapsed := 0.0                   # temps de croissance de LA tige (anim bulbe)
	var cascade_order: Array[int] = []   # ordre de décomposition (vide = vivante)
	var cascade_timer := 0.0
	var cascade_started := false         # vrai dès que la tige se décompose

var _tiges: Array[Tige] = []
var _wait_timer := 0.0
var _cleanup_started := false
## Rebond de la graine sur les sorciers (composant réutilisable)
var _rebond: RebondSorciers = null

@onready var base_back: AnimatedSprite2D = $BaseBack
@onready var base_front: AnimatedSprite2D = $BaseFront
@onready var seed_sprite: Sprite2D = $SeedSprite
@onready var seed_collision: CollisionShape2D = $SeedCollision


func _ready() -> void:
	add_to_group("plant_bramble_group")
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


func _process(_delta: float) -> void:
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
	# Tiges : toutes partent de la même base ; ce sont les PREMIERS
	# tronçons, pré-écartés en éventail, qui les séparent (le bulbe de
	# chaque tige naît avec son premier tronçon)
	_construire_tiges()


## Construit les tiges selon le tier. Budget TOTAL de tronçons conservé
## (5 / 9 / 13) réparti au plus juste : surplus à la première lancée au
## tier II, à la centrale au tier III. Toutes partent de la même base
## (aucun décalage d'origine) dans la direction de plantation tournée
## de ±ECART_TIGES_DEG — ce sont les premiers tronçons qui écartent les
## tiges. Au tier III, les départs sont décalés dans l'ordre
## gauche → centre → droite.
func _construire_tiges() -> void:
	var ecart := deg_to_rad(ECART_TIGES_DEG)
	var budgets: Array[int] = []
	var ecarts: Array[float] = []
	var delais: Array[float] = []
	match attack_tier:
		1:
			budgets = [5]
			ecarts = [0.0]
			delais = [0.0]
		2:
			budgets = [5, 4]
			ecarts = [-ecart, ecart]
			delais = [0.0, 0.0]
		_:
			budgets = [4, 5, 4]
			ecarts = [-ecart, 0.0, ecart]
			delais = [0.0, ECART_TIGES, ECART_TIGES * 2.0]
	for i in budgets.size():
		var tige := Tige.new()
		tige.budget = budgets[i]
		tige.start_delay = delais[i]
		tige.last_direction = direction.rotated(ecarts[i])
		_tiges.append(tige)


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
	for tige in _tiges:
		for seg in tige.segments:
			seg.freeze_to_idle()


func _physics_process(delta: float) -> void:
	match phase:
		Phase.FLYING:
			pass # graine en vol : géré dans _process
		Phase.GROWING:
			_process_growing(delta)
		Phase.WAITING:
			_wait_timer += delta
			# Chaque bulbe suit la pousse du tronçon de liaison de sa tige,
			# puis se cale exactement (sans saut : sa cible est déjà au
			# sommet quand grow_done passe à true)
			for tige in _tiges:
				if tige.bulb == null or tige.cascade_started:
					continue
				_update_bulb_frame(tige)
				_update_bulb_position(tige, false, delta)
				if tige.connector_spawned and not tige.connector_done \
						and tige.segments[tige.segments.size() - 1].grow_done:
					tige.connector_done = true
					_update_bulb_position(tige, true)
					tige.bulb.texture = TIP_BULB_FRAMES[TIP_BULB_FRAMES.size() - 1]
			if _wait_timer >= GEL_DURATION:
				_start_decomposition_from_top()
		Phase.DECOMPOSING:
			pass # cascades gérées pour chaque tige ci-dessous
	# Cascades de décomposition, indépendantes par tige : elles tournent
	# dans toutes les phases (une tige touchée se décompose pendant que
	# les autres poussent)
	_process_cascades(delta)


func _process_growing(delta: float) -> void:
	# Une seule direction voulue pour toutes les tiges (le stick la
	# pilote comme avant, ±max_turn) ; chaque tige l'applique depuis SA
	# dernière direction au moment de poser chaque tronçon → convergence
	# naturelle vers des trajectoires parallèles
	_steer()
	var toutes_finies := true
	for tige in _tiges:
		if tige.cascade_started:
			continue  # tige touchée : elle ne pousse plus
		if tige.start_delay > 0.0:
			tige.start_delay -= delta
			toutes_finies = false
			continue
		tige.elapsed += delta
		_update_bulb_frame(tige)
		_update_bulb_position(tige, false, delta)
		tige.spawn_timer += delta
		if tige.spawn_timer >= SEGMENT_INTERVAL and tige.segments.size() < tige.budget:
			tige.spawn_timer = 0.0
			_spawn_segment(tige)
		var finie := tige.segments.size() >= tige.budget \
			and tige.segments[tige.segments.size() - 1].grow_done
		if finie and not tige.connector_spawned:
			# Fin de croissance naturelle de la tige : tronçon de liaison
			# (comble l'espace entre la dernière tige et le bulbe ; le
			# bulbe le suit pendant sa pousse, cf. WAITING)
			_spawn_connector_segment(tige)
		if not finie:
			toutes_finies = false
	# Fin de croissance de la ronce entière : toutes les tiges ont émis
	# leurs tronçons (les tronçons de liaison finissent de pousser pendant
	# le gel, cf. WAITING) → gel automatique 2 s
	if toutes_finies:
		phase = Phase.WAITING
		_wait_timer = 0.0


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


func _spawn_segment(tige: Tige) -> void:
	var seg: AttackPlantBrambleSegment = SEGMENT_SCENE.instantiate()
	seg.index = tige.segments.size()
	seg.level_scale = level_scale * sprite_scale_multiplier
	seg.position = tige.next_position
	var seg_direction: Vector2
	if tige.segments.size() < TIGES_TRONCONS_ECART:
		# Les premiers tronçons posent la direction d'écartement de la
		# tige : c'est eux qui ouvrent l'éventail entre les tiges
		seg_direction = tige.last_direction
	else:
		# Angle entre ce tronçon et le précédent limité à ±max_turn
		# (±25°/35°/45° selon le tier) : le stick pilote `direction` en
		# continu, mais c'est à la POSE du tronçon que l'écart avec le
		# précédent est bridé
		var prev_angle := tige.last_direction.angle()
		var delta_angle := wrapf(direction.angle() - prev_angle, -PI, PI)
		var max_turn := _get_max_turn()
		seg_direction = Vector2.RIGHT.rotated(prev_angle + clampf(delta_angle, -max_turn, max_turn))
	tige.last_direction = seg_direction
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
	tige.segments.append(seg)
	tige.bulb_segment_index = tige.segments.size() - 1
	tige.next_position += seg_direction * _segment_spacing()
	# Le bulbe de la tige naît avec son premier tronçon
	if tige.bulb == null:
		tige.bulb = _creer_bulbe()


## Bulbe de pointe d'une tige : au-dessus des tiges (z 0), il glisse le
	# long de la tige pendant la croissance. Nearest : comme tous les
	# sprites du jeu (les nœuds de la scène P3 sont en Nearest, ce nœud
	# créé au runtime doit l'être aussi, sinon il serait lissé)
func _creer_bulbe() -> Sprite2D:
	var bulb := Sprite2D.new()
	bulb.texture = TIP_BULB_FRAMES[0]
	bulb.z_index = 1
	bulb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bulb.scale = Vector2(TIP_BULB_SCALE, TIP_BULB_SCALE)
	add_child(bulb)
	return bulb


# Positionne le bulbe sur la pointe VISIBLE de SA tige : il glisse le
# long de la polyligne formée par les tronçons (suit aussi la courbure
# imposée par le stick), du bas du premier sprite à la plantation jusqu'au
# haut du dernier sprite en fin de croissance. Continu → pas de téléportation.
func _update_bulb_position(tige: Tige, full: bool = false, delta: float = 0.0) -> void:
	if tige.bulb == null or tige.segments.is_empty():
		return
	var spacing := _segment_spacing()
	var grown: float
	if full:
		grown = spacing * tige.segments.size()
	else:
		# Sync sur la progression RÉELLEMENT DESSINÉE de la tige en cours
		# (frames de l'anim Grow) : le bulbe reste collé au bout visible
		grown = (tige.segments.size() - 1) * spacing \
			+ tige.segments[tige.segments.size() - 1].grow_fraction() * spacing
	var i := mini(int(grown / spacing), tige.segments.size() - 1)
	var covered := grown - i * spacing
	var seg := tige.segments[i]
	var d := Vector2.UP.rotated(seg.rotation)  # direction du tronçon (sprites verticaux)
	var tip := seg.position + d * covered
	if full:
		tige.bulb.rotation = seg.rotation
	else:
		tige.bulb.rotation = lerp_angle(tige.bulb.rotation, seg.rotation, minf(1.0, delta * 15.0))
	var target := tip + d * ((TIP_BULB_CANVAS_BOTTOM - TIP_BULB_SINK) * TIP_BULB_SCALE)
	if full:
		tige.bulb.position = target
	else:
		tige.bulb.position = tige.bulb.position.lerp(target, minf(1.0, delta * 20.0))


# Avance l'anim du bulbe (Bite1 → Bite21) proportionnellement à la durée
# de croissance DE SA tige : toutes les têtes mûrissent en même temps une
# fois leur pousse lancée (le décalage du tier III est dans le départ)
func _update_bulb_frame(tige: Tige) -> void:
	if tige.bulb == null:
		return
	var total := SEGMENT_INTERVAL * tige.budget
	var p := clampf(tige.elapsed / total, 0.0, 1.0)
	tige.bulb.texture = TIP_BULB_FRAMES[int(p * (TIP_BULB_FRAMES.size() - 1))]


# Tronçon de liaison fin de pousse : dans le prolongement direct du
# dernier tronçon (même direction, pas de pilotage stick)
func _spawn_connector_segment(tige: Tige) -> void:
	var last := tige.segments[tige.segments.size() - 1]
	var seg: AttackPlantBrambleSegment = SEGMENT_SCENE.instantiate()
	seg.index = tige.segments.size()
	seg.level_scale = level_scale * sprite_scale_multiplier
	seg.position = last.position + Vector2.UP.rotated(last.rotation) * _segment_spacing()
	seg.rotation = last.rotation
	seg.enemy_touched.connect(_on_enemy_touched)
	add_child(seg)
	if caster != null and is_instance_valid(caster):
		seg.caster = caster
	seg.grow_speed_scale = GROW_SPEED_SCALE
	seg.start_grow()
	tige.segments.append(seg)
	tige.bulb_segment_index = tige.segments.size() - 1
	tige.connector_spawned = true


## Retrouve la tige qui contient le tronçon `seg` (null si introuvable)
func _tige_de(seg: AttackPlantBrambleSegment) -> Tige:
	for tige in _tiges:
		if tige.segments.has(seg):
			return tige
	return null


# Décomposition déclenchée par un contact ennemi sur un tronçon : SEULE
# la tige qui le contient se décompose (cascade dans les deux sens depuis
# le point de contact) — les autres tiges continuent de vivre et de pousser
func _on_enemy_touched(seg: AttackPlantBrambleSegment) -> void:
	var tige := _tige_de(seg)
	if tige == null or tige.cascade_started:
		return
	var index := tige.segments.find(seg)
	var order: Array[int] = []
	for d in range(tige.segments.size()):
		if index + d < tige.segments.size():
			order.append(index + d)
		if d > 0 and index - d >= 0:
			order.append(index - d)
	_begin_decomposition(tige, order)


# Décomposition de chaque tige depuis son bout vers la base (gel / fin de
# croissance) : les cascades démarrent toutes en même temps, chacune sur
# sa propre tige
func _start_decomposition_from_top() -> void:
	phase = Phase.DECOMPOSING
	for tige in _tiges:
		if tige.cascade_started:
			continue
		var order: Array[int] = []
		for i in range(tige.segments.size() - 1, -1, -1):
			order.append(i)
		_begin_decomposition(tige, order)


func _begin_decomposition(tige: Tige, order: Array[int]) -> void:
	tige.cascade_started = true
	tige.cascade_order = order
	tige.cascade_timer = 0.0


# Avance les cascades, indépendantes par tige : chaque tige décompose ses
# tronçons à son rythme (CASCADE_INTERVAL). La base (commune) ne disparaît
# que quand TOUTES les tiges ont été décomposées, puis le conteneur se
# libère après l'anim de décomposition.
func _process_cascades(delta: float) -> void:
	if _cleanup_started or _tiges.is_empty():
		# _tiges vide (phase graine, avant plantation) : sans ce garde, la
		# boucle sur un tableau vide laisserait toutes_lancees et
		# toutes_vides à true et armerait le nettoyage dès le lancement
		return
	var toutes_lancees := true
	var toutes_vides := true
	for tige in _tiges:
		if not tige.cascade_order.is_empty():
			toutes_vides = false
			tige.cascade_timer -= delta
			if tige.cascade_timer > 0.0:
				continue
			tige.cascade_timer = CASCADE_INTERVAL
			var seg_index: int = tige.cascade_order.pop_front()
			if seg_index < tige.segments.size() and is_instance_valid(tige.segments[seg_index]):
				tige.segments[seg_index].start_decomposition()
				# Le bulbe disparaît quand la cascade atteint le tronçon qu'il coiffe
				if tige.bulb != null and seg_index == tige.bulb_segment_index:
					tige.bulb.queue_free()
					tige.bulb = null
		if not tige.cascade_started:
			toutes_lancees = false
	if toutes_lancees and toutes_vides:
		base_back.visible = false
		base_front.visible = false
		_cleanup_started = true
		get_tree().create_timer(CLEANUP_DELAY).timeout.connect(queue_free)
