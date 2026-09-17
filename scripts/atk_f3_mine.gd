class_name AttackFireMine extends AttackProjectile

# Mine de Feu (tier 3) — 3 phases :
# 1. IDLE     : posée au-dessus du sorcier, animation "idle" en boucle.
#               Posée en l'air, elle descend doucement (lévitation)
#               jusqu'au sol, puis s'y pose en attendant le 2e appui.
# 2. FALL     : au 2e appui, animation "chute" et descente jusqu'au sol
# 3. EXPLODE  : une fois le sol touché, animation "Explosion"
#
# La hitbox est active dès la frame 0 de l'explosion et suit la forme
# du sprite (interpolation entre frames clés), mise à l'échelle du tier.

enum Phase { IDLE, FALL, EXPLODE }

# Distance (px monde) entre le centre du nœud et la mine VISIBLE pendant
# l'idle (contenu collé en bas du canvas 64×152, ×2 par le scale idle) :
# le spawner s'en sert pour faire apparaître la mine au-dessus du sorcier
const IDLE_CONTENT_DROP := 100.0

# Hauteur (px) entre le bas visible de la mine posée en idle et le sol :
# la mine flotte légèrement au lieu de toucher le sol
const IDLE_HOVER := 8.0

@export var fall_speed: float = 600.0
@export var levitate_speed: float = 20.0  # vitesse de descente en l'air (phase idle)
@export var tier_scale: float = 1.0


var caster: Node2D = null
var phase: Phase = Phase.IDLE
var _ground_y := 0.0
var _levitate_landed := false  # vrai une fois la mine posée au sol

const IDLE_ANIM = "Idle"
const FALL_ANIM = "Chute"
const EXPLOSION_ANIM = "Explosion"

# Grossissement léger du sprite pendant la phase idle (la chute et
# l'explosion reviennent à l'échelle 1 pour ne pas doubler le scale de tier)
const IDLE_SCALE := 2

# Couches physiques du sol (TileMap) pour le raycast de chute
const GROUND_MASK := 4

# Points de la hitbox aux frames clés de l'explosion (x, y).
# L'animation ayant perdu ses 4 premières frames, les clés sont
# décalées : 4->0, 16->12, 26->22.
const FRAME_HITBOX = {
	0: [
		Vector2(3, 76), Vector2(0, 76), Vector2(-3, 76),
		Vector2(-2, 74), Vector2(0, 74), Vector2(2, 74)
	],
	12: [
		Vector2(24, 21), Vector2(0, 49), Vector2(-24, 19),
		Vector2(-14, -23), Vector2(0, -44), Vector2(14, -23)
	],
	22: [
		Vector2(33, -45), Vector2(0, -45), Vector2(-32, -45),
		Vector2(-29, -66), Vector2(0, -71), Vector2(29, -66)
	]
}

# Échelle de l'explosion selon le tier (ajustable)
# Appliqué au démarrage de l'explosion au nœud racine : met à l'échelle
# le sprite d'explosion ET la hitbox, sans toucher à la mine idle/chute
const TIER_SCALE = {
	1: 0.8,   # tier I  : petite explosion
	2: 2.5,   # tier II : moyenne
	3: 4.0   # tier III : grande explosion
}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionPolygon2D = $CollisionPolygon2D


func _ready() -> void:
	add_to_group("fire_mine_group")
	collision_shape.disabled = true
	body_entered.connect(_on_body_entered)
	# Si setup_tier a déjà lancé l'animation idle du tier (appel avant
	# l'entrée dans l'arbre), on ne l'écrase pas avec l'anim par défaut
	if not sprite.is_playing():
		sprite.play(IDLE_ANIM)
	# La mine idle est légèrement agrandie
	sprite.scale = Vector2(IDLE_SCALE, IDLE_SCALE)


func setup_tier(tier: int) -> void:
	tier_scale = TIER_SCALE.get(tier, 1.0)
	# Le tier n'affecte NI la mine posée NI la chute : seul le scale est
	# mémorisé ici et appliqué au moment de l'explosion (_start_explosion)
	# setup_tier est appelée par le spawner AVANT l'entrée dans l'arbre :
	# @onready n'a pas encore initialisé `sprite`, on le récupère à la main
	if sprite == null:
		sprite = get_node_or_null("AnimatedSprite2D")
		if sprite == null:
			push_error("AttackFireMine: noeud AnimatedSprite2D introuvable")
			return
	# Joue l'animation Idle du tier (définie dans la scène)
	var anim_name := "Idle_%d" % tier
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		sprite.play(IDLE_ANIM)


func explode() -> void:
	if phase != Phase.IDLE:
		return
	phase = Phase.FALL
	# La chute et l'explosion reprennent la taille d'origine du sprite
	sprite.scale = Vector2.ONE
	# La mine posée rétrécit avec le changement d'échelle (idle ×2 → chute
	# ×1) : recale son bas visible sur le sol mémorisé pendant l'idle,
	# sinon elle flotterait puis retomberait visuellement au déclenchement
	if _levitate_landed:
		global_position.y = _ground_y - _mine_base_offset()
	# Marque la mine comme "partie" : le sorcier ne la retrouvera plus
	# et le verrou d'appui reste en place jusqu'au relâchement
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(FALL_ANIM):
		sprite.play(FALL_ANIM)
	else:
		sprite.pause()  # animation "chute" pas encore ajoutée : tombe quand même


func _physics_process(delta: float) -> void:
	match phase:
		Phase.IDLE:
			_update_idle(delta)
		Phase.FALL:
			_update_fall(delta)
		Phase.EXPLODE:
			pass


# Phase IDLE en l'air : descente lente vers le sol (lévitation). Une fois
# posée, la mine reste en attente du 2e appui (qui déclenche la chute)
func _update_idle(delta: float) -> void:
	if _levitate_landed:
		return
	var hit := _ground_ray(levitate_speed * delta + IDLE_HOVER)
	if hit:
		# Pose la mine : bas VISIBLE du sprite à IDLE_HOVER au-dessus du sol
		_ground_y = hit.position.y
		global_position.y = hit.position.y - _mine_base_offset() - IDLE_HOVER
		_levitate_landed = true
	else:
		global_position.y += levitate_speed * delta


func _update_fall(delta: float) -> void:
	# Mine déjà posée au moment du déclenchement : le sol est déjà connu
	# (_ground_y mémorisé pendant l'idle), explosion immédiate. Un raycast
	# partirait de la base exactement collée à la surface : à distance 0 il
	# ne détecte rien et la mine traverserait la plateforme sur laquelle
	# elle est posée.
	if _levitate_landed:
		_start_explosion()
		return
	var dist := fall_speed * delta
	var hit := _ground_ray(dist)
	if hit:
		# Mémorise le sol et pose le bas VISIBLE de la mine dessus
		_ground_y = hit.position.y
		global_position.y = _ground_y - _mine_base_offset()
		_start_explosion()
	else:
		global_position.y += dist


# Raycast vers le bas depuis la BASE VISIBLE de la mine (et non depuis le
# centre du canvas, qui peut se trouver au-dessus d'un bloc bas) : la mine
# ne peut ainsi détecter que le sol sous elle, jamais le dessous d'un bloc
# au-dessus duquel son canvas dépasse. Renvoie le point de sol touché dans
# la distance donnée (dictionnaire vide sinon).
func _ground_ray(dist: float) -> Dictionary:
	var from := global_position + Vector2(0, _mine_base_offset())
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		from,
		from + Vector2(0, dist + 2.0),
		GROUND_MASK
	)
	return space.intersect_ray(query)


# Distance (px monde) entre le centre du nœud et le bas VISIBLE de la
# frame courante. Les canvases des sprites (64×152) sont bien plus grands
# que la mine visible (~15×18 px en bas du canvas) : se baser sur le canvas
# plaçait le centre jusqu'à 152 px au-dessus de la mine — donc parfois
# AU-DESSUS d'un bloc bas — et les raycasts de chute touchaient alors le
# dessus du bloc au lieu du sol (d'où les explosions au-dessus des blocs).
var _base_offset_cache := {}

func _mine_base_offset() -> float:
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return 0.0
	var id := tex.get_instance_id()
	if not _base_offset_cache.has(id):
		var used := tex.get_image().get_used_rect()
		_base_offset_cache[id] = \
				(float(used.position.y + used.size.y) - tex.get_height() * 0.5)
	return _base_offset_cache[id] * sprite.global_scale.y


# Demi-hauteur actuelle du sprite (le sprite n'est jamais mis à l'échelle
# pendant idle/chute : global_scale reste à 1)
func _half_height() -> float:
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var height := tex.get_height() if tex != null else 32
	# Le scale du SPRITE (agrandi en idle) s'ajoute au scale du nœud racine
	return height * 0.5 * sprite.global_scale.y


func _start_explosion() -> void:
	phase = Phase.EXPLODE
	# Le scale du tier est appliqué uniquement ici : sprite d'explosion
	# et hitbox grossissent, la mine posée/chute restait à taille normale
	scale = Vector2(tier_scale, tier_scale)
	# Recale la BASE du feu (bas du canvas) exactement sur le sol :
	# le scale s'applique autour du centre du sprite, sans ce recalage la
	# base flotterait (tier < 1) ou s'enfoncerait (tier > 1)
	global_position.y = _ground_y - _half_height()
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(EXPLOSION_ANIM):
		sprite.play(EXPLOSION_ANIM)
	# Hitbox active dès la frame 0 (frame_changed ne se déclenche pas
	# si la frame reste 0, on l'applique donc manuellement)
	_update_hitbox(sprite.frame)


func _on_frame_changed() -> void:
	_update_hitbox(sprite.frame)


func _update_hitbox(current_frame: int) -> void:
	collision_shape.disabled = false
	# Points en coordonnées locales : le scale du nœud racine
	# (fixé par _start_explosion) les met automatiquement à l'échelle
	collision_shape.polygon = _get_points_for_frame(current_frame)


# Interpole linéairement les points entre les frames clés
func _get_points_for_frame(frame: int) -> PackedVector2Array:
	var keys = FRAME_HITBOX.keys()
	keys.sort()
	var points: PackedVector2Array = PackedVector2Array()
	if frame <= keys[0]:
		for p in FRAME_HITBOX[keys[0]]:
			points.append(p)
		return points
	if frame >= keys[-1]:
		for p in FRAME_HITBOX[keys[-1]]:
			points.append(p)
		return points
	# interpolation entre les deux clés encadrantes
	var f0: int = 0
	var f1: int = 0
	for i in range(keys.size() - 1):
		if frame >= keys[i] and frame <= keys[i + 1]:
			f0 = keys[i]
			f1 = keys[i + 1]
			break
	var t := float(frame - f0) / float(f1 - f0)
	var p0 = FRAME_HITBOX[f0]
	var p1 = FRAME_HITBOX[f1]
	for i in range(p0.size()):
		points.append(p0[i].lerp(p1[i], t))
	return points


func _on_animation_finished() -> void:
	if sprite.animation == EXPLOSION_ANIM:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	# La mine blesse TOUS les joueurs, lanceur compris. La hitbox n'est
	# active que pendant l'explosion (elle reste désactivée pendant les
	# phases IDLE et FALL), donc poser la mine ne blesse personne en soi :
	# seul le souffle de l'explosion fait des dégâts.
	super._on_body_entered(body)
