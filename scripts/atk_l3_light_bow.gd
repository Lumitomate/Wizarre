class_name AttackLightBow extends AttackProjectile

# Arc Lumineux (L3) — 2 phases :
# 1. TARGETING : l'arc est planté à l'endroit du sorcier (1er appui).
#    Le sorcier s'éloigne pour charger : la distance arc ↔ sorcier règle
#    la frame de la flèche (elle grossit), celle de l'arc (il se bande),
#    la largeur de la hitbox et la vitesse du futur tir. Une ligne
#    pointillée relie l'arc au sorcier. La flèche de visée grossit avec
#    la charge (jusqu'à l'échelle du tier, ex. ×2 au tier 3) mais est
#    bridée par la place disponible : elle ne dépasse jamais ni l'arc
#    ni le sorcier.
# 2. SHOT : au 2e appui, la flèche part du sorcier vers l'arc le long de
#    l'axe figé au moment du tir, puis continue au-delà de l'arc. L'arc
#    débande. Trop près (≤ 60 px) : le tir est annulé, l'arc disparaît
#    et la munition est rendue (géré par sorcerer.gd).
# Un dash du sorcier annule aussi l'attaque (munition rendue).

enum Phase { TARGETING, SHOT, DONE }

@export var tier_scale: float = 1.0

var caster: Node2D = null
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
const ARROW_LENGTH := 128.0   # longueur totale du sprite de la flèche

# Marges de sortie d'écran (en px locaux) avant suppression du projectile
const SCREEN_MARGIN := 256.0

var _shoot_speed := MIN_SPEED
var _full_width := 0.0  # largeur de la hitbox à pleine charge
var _dash_points: Array[Sprite2D] = []

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
	_apply_tier_scale()
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
	# La flèche de visée compense le scale du tier (sinon elle serait
	# décalée et agrandie : impossible à garder entre l'arc et le sorcier)
	arrow.scale = Vector2(1.0 / tier_scale, 1.0 / tier_scale)
	# La flèche pointe du sorcier vers l'arc (le sprite de base pointe
	# vers la droite) : on la retourne horizontalement
	arrow.flip_h = true
	arrow.visible = false
	point_template.visible = false  # sert uniquement de modèle pour les pointillés


func can_damage(body: Node2D) -> bool:
	# La flèche ne peut pas toucher son lanceur
	return body != caster


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
	# invisible à 60 px ou moins, dernière frame à 350 px ou plus
	arrow.visible = dist > MIN_DIST
	arrow.frame = roundi(t * LAST_FRAME)

	# Échelle de la flèche : elle grossit avec la charge (×1 → échelle du
	# tier), bridée par la place disponible entre l'arc et son point de
	# repos (60 px du sorcier) pour ne jamais dépasser l'un ni l'autre
	var arrow_scale: float = lerpf(1.0, tier_scale, t)
	arrow_scale = minf(maxf(arrow_scale, 1.0), maxf((dist - ARROW_GAP) / ARROW_LENGTH, 1.0))
	arrow.scale = Vector2(arrow_scale / tier_scale, arrow_scale / tier_scale)
	arrow.position = Vector2((dist - ARROW_GAP - ARROW_HALF_WIDTH * arrow_scale) / tier_scale, 0.0)

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
	# Points strictement entre l'arc et le sorcier, espacés de DASH_SPACING
	# px VISUELS : l'espacement local compense le scale du tier, sinon les
	# pointillés défilent et passent derrière le sorcier
	var spacing := DASH_SPACING / tier_scale
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
			_dash_points[i].position = Vector2((i + 1) * spacing, 0)
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

	# L'axe (rotation du nœud) est déjà figé : la flèche part d'où elle
	# repose (à quelques pixels du sorcier) vers l'arc, puis continue
	# au-delà de l'arc. Elle reprend l'échelle du tier : la flèche tirée
	# est plus grosse aux tiers supérieurs (comme sa hitbox).
	arrow.scale = Vector2.ONE
	arrow.visible = true
	arrow.frame = roundi(t * LAST_FRAME)
	# La queue de la flèche reste calée où était la flèche de visée
	arrow.position = Vector2((dist - ARROW_GAP) / tier_scale - ARROW_HALF_WIDTH, 0.0)
	collision.position = arrow.position
	(collision.shape as RectangleShape2D).size.x = maxf(_full_width * t, 2.0)
	# La hitbox ne s'active qu'une fois la flèche tirée
	collision.disabled = false

	_clear_dash()
	# L'arc débande : lecture inversée jusqu'au repos, puis il disparaît
	bow.speed_scale = 2.0
	bow.play_backwards(BOW_ANIM)
	return true


func _update_shot(delta: float) -> void:
	# La flèche vole vers l'arc (axe X local inversé) puis au-delà
	arrow.position.x -= _shoot_speed * delta
	collision.position = arrow.position
	# Fin du "débandage" de l'arc (frame 0 = arc au repos) : il disparaît.
	# Ni animation_finished ni is_playing() ne sont fiables en lecture
	# inversée, on teste donc directement la frame
	if bow.visible and bow.frame == 0:
		bow.visible = false
	_free_if_off_screen()


func _free_if_off_screen() -> void:
	var canvas := get_viewport().get_canvas_transform()
	var screen_pos := canvas * arrow.global_position
	if not get_viewport_rect().grow(SCREEN_MARGIN).has_point(screen_pos):
		queue_free()


func _caster_distance() -> float:
	if caster == null or not is_instance_valid(caster):
		return 0.0
	return (caster.position - position).length()


func _apply_tier_scale() -> void:
	scale = Vector2(tier_scale, tier_scale)
