class_name AttackLightBow extends AttackProjectile

# Arc Lumineux (L3) — 2 phases :
# 1. TARGETING : l'arc est planté à l'endroit du sorcier (1er appui).
#    Le sorcier s'éloigne pour charger : la distance arc ↔ sorcier règle
#    la frame de la flèche, celle de l'arc (il se bande), la largeur de
#    la hitbox et la vitesse du futur tir. Une ligne pointillée relie
#    l'arc au sorcier.
# 2. SHOT : au 2e appui, les flèches partent DU SORCIER (sa position
#    actuelle) vers un point de l'arc dépendant du tier — le centre
#    (tier I), les 2 extrémités (tier II), les 2 extrémités + le centre
#    (tier III) — puis continuent en ligne droite au-delà de l'arc.
#    L'arc débande. Trop près (≤ 60 px) : le tir est annulé, l'arc
#    disparaît et la munition est rendue (géré par sorcerer.gd).
# Un dash du sorcier annule aussi l'attaque (munition rendue).
#
# Le tier ne change PAS la taille : il détermine le nombre de flèches
# et leurs trajectoires en éventail à travers les points de l'arc.

enum Phase { TARGETING, SHOT, DONE }

# Nombre de flèches de l'éventail : le tier est reçu en base 1 depuis
# spawner_attack (1/2/3 flèches pour tier I/II/III)
@export var attack_tier: int = 1

var phase: Phase = Phase.TARGETING

const ARROW_ANIM := &"AtkL3_LightBow_arrow"
const BOW_ANIM := &"AtkL3_LightBow_Bend"

const MIN_DIST := 60.0    # en dessous : flèche invisible, tir impossible
const MAX_DIST := 350.0   # au-delà : dernière frame, hitbox pleine, vitesse max
const LAST_FRAME := 23
const MIN_SPEED := 200.0
const MAX_SPEED := 1600.0
const DASH_SPACING := 24.0  # espacement des pointillés

const ARROW_GAP := 60.0       # espace entre le sorcier et la queue de la flèche
const ARROW_HALF_WIDTH := 64.0  # demi-largeur du sprite de la flèche

# Marges de sortie d'écran (en px locaux) avant suppression du projectile
const SCREEN_MARGIN := 256.0

# Grâce du lanceur : les flèches partent de lui, il est insensible à ses
# propres flèches pendant ce délai, puis vulnérable (comme la firewave)
const CASTER_GRACE_TIME := 0.4

var _shoot_speed := MIN_SPEED
var _full_width := 0.0  # largeur de la hitbox à pleine charge
var _dash_points: Array[Sprite2D] = []
# Grâce restante au lanceur après le tir (0 = vulnérable à ses flèches)
var _caster_grace := 0.0
# Flèches tirées : {"sprite": AnimatedSprite2D, "shape": CollisionShape2D,
# "dir": Vector2} — sprite/shape nullés quand la flèche sort de l'écran
var _flying_arrows: Array[Dictionary] = []

@onready var arrow: AnimatedSprite2D = $AnimatedSprite2D_Arrow
@onready var bow: AnimatedSprite2D = $AnimatedSprite2D_Bow
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var point_template: Sprite2D = $Sprite2D_Point


func _ready() -> void:
	add_to_group("light_bow_group")
	# La hitbox est redimensionnée à la volée : chaque arc possède SA
	# propre ressource de forme (sinon les 4 joueurs partageraient la même)
	collision.shape = collision.shape.duplicate()
	_full_width = (collision.shape as RectangleShape2D).size.x
	collision.disabled = true
	body_entered.connect(_on_body_entered)
	bow.animation = BOW_ANIM
	# La corde de l'arc doit faire face au sorcier (la flèche vole du
	# côté de la corde) : le sprite de base courbe à l'opposé, on le
	# retourne horizontalement
	bow.flip_h = true
	# La boucle est désactivée pour que le "débandage" inversé se termine
	# (la ressource est partagée entre les joueurs, mais tous veulent la
	# même animation non bouclée)
	bow.sprite_frames.set_animation_loop(BOW_ANIM, false)
	bow.frame = 0
	arrow.animation = ARROW_ANIM
	arrow.stop()
	# La flèche pointe du sorcier vers l'arc (le sprite de base pointe
	# vers la droite) : on la retourne horizontalement
	arrow.flip_h = true
	arrow.visible = false
	point_template.visible = false  # sert uniquement de modèle pour les pointillés


func can_damage(body: Node2D) -> bool:
	# Les flèches partent du lanceur : il est insensible pendant la grâce,
	# puis peut se prendre ses propres flèches (comme la firewave)
	if body == caster and _caster_grace > 0.0:
		return false
	return true


func _physics_process(_delta: float) -> void:
	match phase:
		Phase.TARGETING:
			_update_targeting()
		Phase.SHOT:
			_update_shot(_delta)
		Phase.DONE:
			pass


# --- Phase 1 : ciblage -------------------------------------------------------

func _update_targeting() -> void:
	# Lanceur disparu (mort) : l'arc ne sert plus à rien
	if caster == null or not is_instance_valid(caster):
		queue_free()
		return

	var to_caster: Vector2 = caster.position - position
	var dist := to_caster.length()

	# Le nœud racine est orienté : son axe X local pointe toujours vers le
	# sorcier (l'arc, la flèche et les pointillés sont dessinés le long de X)
	if dist > 0.01:
		rotation = to_caster.angle()

	var t := _charge_ratio(dist)

	# Flèche posée à quelques pixels du sorcier, pointée vers l'arc :
	# invisible à 60 px ou moins, dernière frame à 350 px ou plus. La
	# charge se lit sur les frames (flèche + arc), pas sur la taille.
	arrow.visible = dist > MIN_DIST
	arrow.frame = roundi(t * LAST_FRAME)
	arrow.position = Vector2(dist - ARROW_GAP - ARROW_HALF_WIDTH, 0.0)

	# L'arc se bande avec la distance (dernier frame à 140 px ou plus)
	bow.frame = roundi(t * _last_bow_frame())

	# La hitbox (encore inactive) prend déjà la largeur qu'elle aura au tir
	(collision.shape as RectangleShape2D).size.x = maxf(_full_width * t, 2.0)

	_update_dash(dist)


func _charge_ratio(dist: float) -> float:
	return clampf((dist - MIN_DIST) / (MAX_DIST - MIN_DIST), 0.0, 1.0)



func _last_bow_frame() -> int:
	return bow.sprite_frames.get_frame_count(BOW_ANIM) - 1


func _update_dash(distance: float) -> void:
	# Points strictement entre l'arc et le sorcier, espacés de DASH_SPACING px
	var needed := maxi(int((distance - DASH_SPACING) / DASH_SPACING), 0)
	while _dash_points.size() < needed:
		var p := Sprite2D.new()
		p.texture = point_template.texture
		p.texture_filter = point_template.texture_filter
		add_child(p)
		_dash_points.append(p)
	for i in _dash_points.size():
		if i < needed:
			_dash_points[i].visible = true
			_dash_points[i].position = Vector2((i + 1) * DASH_SPACING, 0)
		else:
			_dash_points[i].visible = false


func _clear_dash() -> void:
	for p in _dash_points:
		p.queue_free()
	_dash_points.clear()


# --- Phase 2 : tir -----------------------------------------------------------

# Annule l'attaque (appelé quand le sorcier dash) : l'arc disparaît.
func cancel() -> void:
	if phase != Phase.TARGETING:
		return
	phase = Phase.DONE
	queue_free()


# Appelée par le sorcier au 2e appui. Renvoie false si le tir est annulé
# (sorcier trop proche de l'arc) : le nœud se détruit alors lui-même.
func try_shoot() -> bool:
	if phase != Phase.TARGETING:
		return false
	var dist := _caster_distance()
	if dist <= MIN_DIST:
		phase = Phase.DONE
		queue_free()
		return false

	phase = Phase.SHOT
	var t := _charge_ratio(dist)
	_shoot_speed = lerpf(MIN_SPEED, MAX_SPEED, t)

	# Trajectoires définies par 2 points : le SORCIER (position actuelle
	# au moment du tir) et un point de l'arc dépendant du tier :
	#   tier I   → le centre de l'arc
	#   tier II  → les 2 extrémités de l'arc
	#   tier III → les 2 extrémités + le centre
	# Tout est calculé en coordonnées Level (le référentiel commun du
	# sorcier et de l'arc) : les extrémités de l'arc sont à ±demi-hauteur
	# de son sprite, tourné de son axe figé au moment du ciblage.
	var tip_half := _bow_tip_half_height()
	var aim_points: Array[Vector2] = []
	match attack_tier:
		2:
			aim_points = [position + Vector2(0, -tip_half).rotated(rotation), \
					position + Vector2(0, tip_half).rotated(rotation)]
		3:
			aim_points = [position + Vector2(0, -tip_half).rotated(rotation), \
					position, \
					position + Vector2(0, tip_half).rotated(rotation)]
		_:
			aim_points = [position]

	# La flèche de visée sert de modèle : cachée, chaque flèche tirée en
	# est une copie partant du sorcier vers son point de passage sur l'arc
	# (direction = droite sorcier → point de l'arc), avec sa propre hitbox.
	# Les sprites sont des enfants du nœud (dont l'axe X pointe vers le
	# sorcier) : directions et positions passent du référentiel Level au
	# référentiel local par une rotation de -rotation.
	arrow.visible = false
	collision.disabled = true

	for aim_point in aim_points:
		var dir := (aim_point - caster.position).normalized()
		var dir_local := dir.rotated(-rotation)
		var start_local := (caster.position - position).rotated(-rotation)

		var sprite: AnimatedSprite2D = arrow.duplicate()
		sprite.scale = Vector2.ONE
		sprite.visible = true
		# flip_h : le sprite pointe visuellement vers son -X local, la
		# rotation est donc décalée d'un demi-tour par rapport à dir
		sprite.rotation = dir_local.angle() + PI
		sprite.position = start_local
		add_child(sprite)

		# Une hitbox par flèche, alignée sur son angle de vol (rectangle :
		# insensible au demi-tour)
		var shape_node := CollisionShape2D.new()
		var rect: RectangleShape2D = collision.shape.duplicate()
		rect.size.x = maxf(_full_width * t, 2.0)
		shape_node.shape = rect
		shape_node.rotation = dir_local.angle()
		shape_node.position = start_local
		add_child(shape_node)

		_flying_arrows.append({
			"sprite": sprite,
			"shape": shape_node,
			"dir": dir_local,
		})

	_clear_dash()
	# Grâce du lanceur au moment du tir
	_caster_grace = CASTER_GRACE_TIME
	# L'arc débande : lecture inversée jusqu'au repos, puis il disparaît
	bow.speed_scale = 2.0
	bow.play_backwards(BOW_ANIM)
	return true


# Demi-hauteur de l'arc = position de ses extrémités : lue sur la frame
# courante (l'arc se bande, ses extrémités bougent avec la charge)
func _bow_tip_half_height() -> float:
	var tex := bow.sprite_frames.get_frame_texture(BOW_ANIM, bow.frame)
	if tex == null:
		return 32.0
	return tex.get_height() * 0.5 * bow.scale.y


func _update_shot(delta: float) -> void:
	# Décompte de la grâce du lanceur (0 = à nouveau vulnérable)
	if _caster_grace > 0.0:
		_caster_grace -= delta

	# Fin du "débandage" de l'arc (frame 0 = arc au repos) : il disparaît.
	# Ni animation_finished ni is_playing() ne sont fiables en lecture
	# inversée, on teste donc directement la frame
	if bow.visible and bow.frame == 0:
		bow.visible = false

	# Chaque flèche vole le long de son propre angle de l'éventail
	var remaining := 0
	for a in _flying_arrows:
		var sprite: AnimatedSprite2D = a["sprite"]
		if sprite == null:
			continue  # déjà sortie de l'écran
		sprite.position += a["dir"] * _shoot_speed * delta
		var shape: CollisionShape2D = a["shape"]
		shape.position = sprite.position

		var canvas := get_viewport().get_canvas_transform()
		var screen_pos := canvas * sprite.global_position
		if not get_viewport_rect().grow(SCREEN_MARGIN).has_point(screen_pos):
			sprite.queue_free()
			shape.queue_free()
			a["sprite"] = null
			a["shape"] = null
		else:
			remaining += 1

	# Toutes les flèches sont sorties de l'écran : le nœud se libère
	if remaining == 0:
		queue_free()


func _caster_distance() -> float:
	if caster == null or not is_instance_valid(caster):
		return 0.0
	return (caster.position - position).length()
