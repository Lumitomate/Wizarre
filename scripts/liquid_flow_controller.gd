class_name LiquidFlowController
extends Area2D

## Attaché à la racine HudTitrageWezarb (Area2D). Détecte les attaques
## (Area2D dont le script hérite d'AttackProjectile) près des polygones de
## lettres (CollisionPolygon2D enfants) et déclenche la vague de liquide
## blanc dans les canaux de la lettre touchée (shader liquid_flow.gdshader).
##
## Détection : une requête physique par lettre sur son rectangle élargi de
## contact_tolerance — les attaques posées juste à côté d'une lettre
## (colonne de feu) sont vues même sans chevauchement de hitbox.
##
## Point d'impact = point d'ENTRÉE de l'attaque dans la lettre :
## - attaque en mouvement : intersection de son déplacement (position
##   précédente -> position actuelle) avec le bord du polygone ;
## - attaque statique (colonne de feu posée) : son origine si elle est dans
##   la lettre, sinon le bord le plus proche dans la tolérance.
##
## Les colonnes de feu se déclenchent en chaîne : chaque colonne qui
## chevauche la lettre relancerait la vague depuis son propre point. Une
## vague déclenchée par une attaque statique n'est donc pas relancée par
## une autre attaque statique ; en revanche une attaque en mouvement
## (boule de feu...) la remplace normalement.

const FLOW_SHADER := preload("res://assets/shaders/liquid_flow.gdshader")

## Cerne et ombre portée, toutes deux noires semi-transparentes. La cerne
## est fine (OUTLINE_WIDTH). Générées une fois au chargement par dilatation
## de la silhouette de chaque lettre, sur un canvas AGRANDI de la largeur
## du contour : les lettres touchent les bords de leur texture, la
## dilatation serait coupée sans ça (plus de cerne sur les côtés).
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.5)  # noir à 50 %
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.5)  # noir à 50 %
## Épaisseur de la cerne autour de chaque lettre (pixels texture).
const OUTLINE_WIDTH := 1
## Épaisseur de la silhouette de l'ombre (pixels texture).
const SHADOW_WIDTH := 3
## Décalage de l'ombre portée sous chaque lettre (px locaux du titre).
const SHADOW_OFFSET := Vector2(0.0, 12.0)

## Durée du remplissage : le blanc avance jusqu'à couvrir toute la lettre.
@export var fill_time := 0.8
## Durée pendant laquelle la lettre reste blanche avant de s'éteindre.
@export var hold_time := 0.2
## Durée de la disparition : le blanc fond vers le rouge d'origine.
@export var fade_time := 1.0
## Distance max (unités locales du titre) entre l'origine d'une attaque
## statique hors lettre et le bord de la lettre pour déclencher la vague
## depuis ce bord. ~ demi-hauteur de la hitbox d'une colonne de feu.
@export var contact_tolerance := 24.0
## Couches de collision des attaques recherchées (fireball : 3, colonne : 1).
@export_flags_2d_physics var detection_mask := 3

## Flottement permanent : amplitude de l'oscillation verticale (px locaux).
@export var float_amplitude := 5.0
## Flottement permanent : durée d'un cycle complet (secondes).
@export var float_period := 2.0
## Flottement permanent : décalage de phase entre lettres voisines (s).
@export var float_phase_step := 0.1
## Impact : distance de recul de la lettre dans la direction du tir (px locaux).
@export var push_distance := 13.0
## Impact : durée de la poussée avant le retour élastique (secondes).
@export var push_time := 0.13
## Impact : durée du retour élastique (oscillations décroissantes, secondes).
@export var elastic_time := 2.1

## {circuit: ShaderMaterial} des circuits des lettres présentes.
var _materials: Dictionary = {}
## {CollisionPolygon2D: Sprite2D circuit associé} (nom "CollisionPolygon2D A"
## -> "TitrageA_Circuit").
var _letters: Dictionary = {}
## {CollisionPolygon2D: PhysicsShapeQueryParameters2D} requête par lettre.
var _queries: Dictionary = {}
## {id_attaque: {circuit: true}} : lettres déjà déclenchées par chaque attaque.
## Clés = instance_id : les attaques se libèrent en fin de vie (queue_free),
## et conserver des objets libérés dans un dictionnaire déclenche des
## erreurs "previously freed instance" ; un id libéré ne correspond plus
## simplement à rien.
var _active_hits: Dictionary = {}
## {id_attaque: Vector2} position globale de l'attaque à la frame précédente.
var _prev_positions: Dictionary = {}
## {circuit: Tween} vague en cours par lettre.
var _tweens: Dictionary = {}
## {circuit: bool} la vague en cours vient-elle d'une attaque statique ?
var _wave_static: Dictionary = {}

## Données de mouvement par lettre :
## [{letter, circuit, base, phase, recoil}] — base = position d'origine
## (identique pour la lettre et son circuit), phase = décalage du
## flottement, recoil = décalage courant de l'ébranlement d'impact.
var _motion: Array[Dictionary] = []
## Temps écoulé (accumulé en physique : respecte la pause du jeu).
var _elapsed := 0.0
## {Sprite2D lettre: Tween} ébranlement en cours par lettre.
var _motion_tweens: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		var polygon := child as CollisionPolygon2D
		if polygon == null:
			continue
		var letter := polygon.name.get_slice(" ", 1)
		var circuit := get_node_or_null(NodePath("Titrage%s_Circuit" % letter)) as Sprite2D
		if circuit == null or circuit.texture == null:
			continue
		var letter_sprite := get_node_or_null(NodePath("Titrage%s" % letter)) as Sprite2D
		var material := ShaderMaterial.new()
		material.shader = FLOW_SHADER
		material.set_shader_parameter("texture_size", circuit.texture.get_size())
		circuit.material = material
		_materials[circuit] = material
		_letters[polygon] = circuit
		_queries[polygon] = _build_query(polygon)
		# Données de flottement : la lettre emmène son circuit (même position
		# d'origine dans la scène).
		if letter_sprite != null:
			var outline_tex := _build_outline_texture(letter_sprite, OUTLINE_COLOR, OUTLINE_WIDTH)
			var shadow_tex := _build_outline_texture(letter_sprite, SHADOW_COLOR, SHADOW_WIDTH)
			var shadow := Sprite2D.new()
			shadow.name = "Titrage%s_Ombre" % letter
			shadow.texture = shadow_tex
			shadow.texture_filter = 1
			var ring := Sprite2D.new()
			ring.name = "Titrage%s_Cerne" % letter
			ring.texture = outline_tex
			ring.texture_filter = 1
			add_child(shadow)
			add_child(ring)
			_motion.append({
				"letter": letter_sprite,
				"circuit": circuit,
				"ombre": shadow,
				"cerne": ring,
				"base": letter_sprite.position,
				"phase": 0.0,
				"recoil": Vector2.ZERO,
			})
	# Rayon d'onde commun : la plus grande diagonale des lettres. Toutes les
	# vagues avancent alors à la même vitesse en px/s (rayon / fill_time).
	var max_radius := 0.0
	for circuit: Sprite2D in _letters.values():
		max_radius = maxf(max_radius, circuit.texture.get_size().length())
	for material: ShaderMaterial in _materials.values():
		material.set_shader_parameter("wave_radius_px", max_radius)
		# Bande de fondu = moitié du rayon : chaque pixel s'estompe sur
		# ~1/3 de la durée du retrait quand le front le traverse.
		material.set_shader_parameter("fade_band_px", max_radius * 0.5)
	# Tri du flottement de gauche à droite (décalage de phase consécutif).
	_motion.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.base as Vector2).x < (b.base as Vector2).x)
	# Phases après tri gauche -> droite : chaque lettre décalée de phase_step.
	for i in _motion.size():
		_motion[i].phase = TAU * float_phase_step / float_period * i
	# Ordre de dessin : ombres derrière tout, puis cernes, puis lettres
	# (l'ordre des enfants d'un Node2D est l'ordre de dessin).
	var count := _motion.size()
	for i in count:
		move_child(_motion[i].ombre, i)
	for i in count:
		move_child(_motion[i].cerne, count + i)


## Silhouette dilatée de la lettre : tout pixel à moins de width px d'un
## pixel opaque devient color, le reste transparent. Sert à la cerne
## (derrière la lettre : seul l'anneau dépasse) et à l'ombre (copie
## décalée vers le bas).
func _build_outline_texture(letter: Sprite2D, color: Color, width: int) -> ImageTexture:
	var src: Image = letter.texture.get_image()
	if src.is_compressed():
		src.decompress()
	var size := src.get_size()
	# Canvas agrandi de width de chaque côté : les lettres touchent les bords
	# de leur texture, la dilatation doit pouvoir déborder. Le contenu est
	# décalé de +width : le centre reste aligné, le sprite garde sa position.
	var out := Image.create(size.x + 2 * width, size.y + 2 * width, false, Image.FORMAT_RGBA8)
	var offsets: Array[Vector2i] = []
	for dy in range(-width, width + 1):
		for dx in range(-width, width + 1):
			if dx * dx + dy * dy <= width * width:
				offsets.append(Vector2i(dx, dy))
	for y in out.get_height():
		for x in out.get_width():
			for offset: Vector2i in offsets:
				# Pixel lettre correspondant : le contenu est décalé de +width
				# dans le canvas agrandi, la dilatation s'étend autour.
				var p := Vector2i(x, y) - Vector2i(width, width) + offset
				if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y:
					continue
				if src.get_pixelv(p).a > 0.1:
					out.set_pixel(x, y, color)
					break
	return ImageTexture.create_from_image(out)


## Requête physique pour une lettre : rectangle englobant son polygone,
## élargi de la tolérance de contact, centré sur la lettre.
func _build_query(polygon: CollisionPolygon2D) -> PhysicsShapeQueryParameters2D:
	var pts := PackedVector2Array()
	for p in polygon.polygon:
		pts.append(to_local(polygon.global_transform * p))
	var min_pt := pts[0]
	var max_pt := pts[0]
	for p in pts:
		min_pt = min_pt.min(p)
		max_pt = max_pt.max(p)
	var center := (min_pt + max_pt) / 2.0
	var ext := max_pt - min_pt + Vector2.ONE * 2.0 * contact_tolerance
	var shape := RectangleShape2D.new()
	# Les requêtes physiques exigent des dimensions GLOBALES : les unités
	# locales du titre sont agrandies par l'échelle globale du nœud.
	shape.size = ext * global_transform.get_scale()
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_transform * center)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = detection_mask
	params.exclude = [get_rid()]
	return params


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_update_float()
	var space := get_world_2d().direct_space_state
	var seen: Dictionary = {}
	for polygon: CollisionPolygon2D in _queries:
		var circuit: Sprite2D = _letters[polygon]
		for hit: Dictionary in space.intersect_shape(_queries[polygon], 8):
			var area: Area2D = hit.collider
			if not (area is AttackProjectile):
				continue
			var attack_id := area.get_instance_id()
			seen[attack_id] = true
			var prev: Vector2 = _prev_positions.get(attack_id, area.global_position)
			var curr: Vector2 = area.global_position
			_prev_positions[attack_id] = curr
			if not _active_hits.has(attack_id):
				_active_hits[attack_id] = {}
			var triggered: Dictionary = _active_hits[attack_id]
			if triggered.has(circuit):
				continue
			if _tweens.has(circuit) and _wave_static.get(circuit, false):
				# Vague en cours venue d'une attaque statique : une autre
				# attaque statique (chaîne de colonnes) ne la relance pas.
				# L'attaque est consommée pour cette lettre : elle ne
				# redéclenchera pas une fois la vague terminée.
				triggered[circuit] = true
				continue
			var uv := _impact_uv(polygon, circuit, prev, curr)
			if uv != Vector2.INF:
				triggered[circuit] = true
				_trigger(circuit, uv, prev.distance_to(curr) < 1.0)
				_start_recoil(circuit, curr)
	# Une attaque sortie du titre (ou libérée) redevient capable de
	# redéclencher une vague.
	for attack_id: int in _active_hits.keys():
		if not seen.has(attack_id):
			_active_hits.erase(attack_id)
			_prev_positions.erase(attack_id)


## Position de chaque lettre (et de son circuit, sa cerne et son ombre) =
## base + flottement sinusoïdal vertical (phases décalées de gauche à
## droite) + ébranlement.
func _update_float() -> void:
	for data: Dictionary in _motion:
		var offset := Vector2(0.0, sin(TAU * _elapsed / float_period + data.phase) * float_amplitude)
		offset += data.recoil
		var pos: Vector2 = data.base + offset
		(data.letter as Sprite2D).position = pos
		(data.circuit as Sprite2D).position = pos
		(data.cerne as Sprite2D).position = pos
		(data.ombre as Sprite2D).position = pos + SHADOW_OFFSET


## Ébranlement d'impact : la lettre est poussée dans la direction du tir
## (loin de l'attaque) puis revient avec un rebond élastique. Un nouvel
## impact reprend depuis le recul courant, le flottement n'est pas touché.
func _start_recoil(circuit: Sprite2D, attack_global: Vector2) -> void:
	var data: Dictionary = {}
	for d: Dictionary in _motion:
		if d.circuit == circuit:
			data = d
			break
	if data.is_empty():
		return
	var letter: Sprite2D = data.letter
	var center_global: Vector2 = global_transform * (data.base as Vector2)
	var dir: Vector2 = (center_global - attack_global).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var push := dir * push_distance
	if _motion_tweens.has(letter):
		_motion_tweens[letter].kill()
	var start: Vector2 = data.recoil
	var tween := create_tween()
	_motion_tweens[letter] = tween
	# Poussée rapide dans la direction du tir, depuis le recul courant.
	tween.tween_method(
		func(v: Vector2) -> void: data.recoil = v,
		start, start + push, push_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Retour élastique : oscillations décroissantes vers la position d'origine.
	tween.tween_method(
		func(v: Vector2) -> void: data.recoil = v,
		start + push, Vector2.ZERO, elastic_time
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _motion_tweens.erase(letter))


## UV du point d'ENTRÉE de l'attaque dans le polygone de la lettre
## (déplacement précédent -> actuel intersecté au bord, ou bord le plus
## proche pour une attaque statique), sinon Vector2.INF.
func _impact_uv(polygon: CollisionPolygon2D, circuit: Sprite2D, prev: Vector2, curr: Vector2) -> Vector2:
	# Points du polygone en coordonnées locales du titre.
	var pts := PackedVector2Array()
	for p in polygon.polygon:
		pts.append(to_local(polygon.global_transform * p))
	var origin := to_local(curr)
	var prev_l := to_local(prev)
	var moving := origin.distance_to(prev_l) > 0.5
	var impact := Vector2.INF
	if moving:
		# Première traversée du bord du polygone = point d'entrée.
		var best_t := INF
		for i in pts.size():
			var x: Variant = Geometry2D.segment_intersects_segment(
				prev_l, origin, pts[i], pts[(i + 1) % pts.size()]
			)
			if x is Vector2:
				var t: float = prev_l.distance_to(x)
				if t < best_t:
					best_t = t
					impact = x
	if impact == Vector2.INF:
		if Geometry2D.is_point_in_polygon(origin, pts):
			impact = origin
		elif not moving:
			# Attaque statique posée à côté de la lettre : bord le plus
			# proche dans la tolérance de contact.
			var best_d := contact_tolerance
			for i in pts.size():
				var cp := Geometry2D.get_closest_point_to_segment(origin, pts[i], pts[(i + 1) % pts.size()])
				var d := cp.distance_to(origin)
				if d < best_d:
					best_d = d
					impact = cp
	if impact == Vector2.INF:
		return Vector2.INF
	var uv := (impact - circuit.position) / circuit.texture.get_size() + Vector2(0.5, 0.5)
	return uv.clamp(Vector2.ZERO, Vector2.ONE)


func _trigger(circuit: Sprite2D, uv: Vector2, from_static: bool) -> void:
	var material: ShaderMaterial = _materials.get(circuit)
	if material == null:
		return
	# Une attaque en mouvement remplace la vague en cours sur cette lettre.
	if _tweens.has(circuit):
		_tweens[circuit].kill()
	_wave_static[circuit] = from_static
	material.set_shader_parameter("hit_uv", uv)
	material.set_shader_parameter("flow_front", 0.0)
	material.set_shader_parameter("fade_front", 0.0)
	var tween := create_tween()
	_tweens[circuit] = tween
	# Remplissage : le blanc avance depuis l'impact et reste derrière lui.
	tween.tween_method(
		func(progress: float) -> void: material.set_shader_parameter("flow_front", progress),
		0.0, 1.0, fill_time
	)
	# Pause : la lettre entièrement blanche un instant.
	tween.tween_interval(hold_time)
	# Disparition : onde de retrait depuis l'impact, chaque pixel s'estompe
	# progressivement pendant que le front le traverse.
	tween.tween_method(
		func(progress: float) -> void: material.set_shader_parameter("fade_front", progress),
		0.0, 1.0, fade_time
	)
	tween.tween_callback(func() -> void:
		_tweens.erase(circuit)
		_wave_static.erase(circuit)
	)
