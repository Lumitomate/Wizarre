class_name Dust extends Node

## Dust — la fumée de contact du Sorcerer : bouffée à l'atterrissage, au
## décollage du saut, au premier contact du mur, pendant la glissade, et
## au wall jump. Le Sorcerer raconte l'événement (position de contact =
## sa géométrie de capsule, force = vitesse du contact, côté du mur) :
## le module décide si ça fume et comment (seuil, éventail, émission
## continue de glissade, teinte par la surface).

## Seuil calé sur la gravité du jeu (fall_acceleration = 3000) : 400 px/s
## ≈ une chute de 27 px minimum ; 1200 px/s ≈ une chute de 240 px = nuage max.

const SIZE := 3          # px écran par pixel de fumée
const COLORS: Array[Color] = [
	Color(1, 1, 1), Color(0.85, 0.85, 0.85), Color(0.7, 0.7, 0.7)]
const FORCE_MIN := 3       # particules au contact le plus doux
const FORCE_MAX := 8       # particules au contact le plus violent
const SPEED_THRESHOLD := 400.0  # px/s : en dessous, pas de fumée
const MAX_SPEED := 1200.0   # px/s : au-delà, force maximale
const LIFETIME := 0.35      # durée de vie d'une particule (s)
const DISTANCE := 16.0      # dispersion depuis le point de contact (px)
const UPWARD_DRIFT := 10.0  # dérive verticale vers le haut (la fumée monte)
const SLIDE_INTERVAL := 0.07  # délai entre 2 particules pendant une glissade (s)
## Teinture par la surface : mélange entre la couleur moyenne de la tuile
## touchée et le blanc (0 = couleur brute du sol, 1 = blanc pur). 0.5 :
## la fumée garde sa nature claire et lisible tout en prenant la teinte
## du sol (briques violettes → fumée mauve claire).
const TINT_MIX := 0.5
## Écart angulaire de l'éventail (demi-angle autour de la normale). Au
## sol : ±90° → les particules partent STRICTEMENT sur les côtés
## (l'horizontale), jamais vers le haut — la dérive les fait monter
## ensuite. Au mur : plus resserré (±60°).
const FLOOR_FAN := PI / 2.0
const WALL_FAN := PI / 3.0
## Remontée du point d'émission au sol : les pixels de 3 px sont centrés
## sur le point de contact, 2 px au-dessus de la surface les font
## flotter JUSTE au-dessus du sol au lieu d'à moitié dedans.
const FEET_LIFT := 2.0

var sorcier: Sorcerer

## Accumulateur d'émission continue de glissade
var _slide_accum: float = 0.0

## Texture d'un carré blanc plein (pixel de fumée) — cache statique,
## identique pour tous les sorciers.
static var _texture: ImageTexture = null

## Image décodée d'une texture d'atlas (cache statique : le décodage
## n'arrive qu'une fois par texture, pour tout le jeu).
static var _surface_images: Dictionary = {}   # texture de l'atlas → Image décodée
static var _moyennes_tuiles: Dictionary = {}  # "textureId_x_y" → Color moyenne


func setup(s: Sorcerer) -> void:
	sorcier = s


# ── Événements racontés par le Sorcerer ─────────────────────────────────────

## Décollage du saut : même bouffée qu'à l'atterrissage (pieds, éventail
## latéral), force indexée sur l'impulsion du saut — la fumée
## reste au point de départ, elle matérialise l'envol
func jump_takeoff(centre: Vector2, force: float) -> void:
	spawn_puff(centre, Vector2.UP, force, FLOOR_FAN)


## Atterrissage : bouffée proportionnelle à la vitesse d'impact
func landing(centre: Vector2, force: float) -> void:
	spawn_puff(centre, Vector2.UP, force, FLOOR_FAN)


## Premier contact du mur : fumée proportionnelle à la vitesse de chute à
## l'impact (éventail resserré)
func wall_slide_start(centre: Vector2, mur_cote: int, force: float) -> void:
	spawn_puff(centre, Vector2(-mur_cote, 0), force, WALL_FAN)


## Émission continue pendant la glissade (les bottes raclent le mur)
func wall_slide_tick(centre: Vector2, mur_cote: int, delta: float) -> void:
	_slide_accum += delta
	if _slide_accum >= SLIDE_INTERVAL:
		_slide_accum = 0.0
		_spawn_particule(centre, Vector2(-mur_cote, 0), WALL_FAN)


## Fin de la glissade : on repose le compteur d'émission continue
func wall_slide_end() -> void:
	_slide_accum = 0.0


## Wall jump : la poussée déloge un VRAI nuage au point de contact du mur :
## force maximale (la vitesse de chute est ici plafonnée par la
## glissade, trop basse pour le seuil), et particules partant en
## MAJORITÉ vers le bas (la poussière délogée tombe le long du mur).
## mur_cote clampe l'arrivée du côté libre : sans lui, l'éventail
## vers le bas renverrait une moitié des particules DANS le mur.
func wall_jump(centre: Vector2, mur_cote: int) -> void:
	spawn_puff(centre, Vector2.DOWN, MAX_SPEED, WALL_FAN, mur_cote)


# ── Émission ─────────────────────────────────────────────────────────────────

## Bouffée de poussière au point de contact `centre`. `force` = vitesse du
## contact (px/s) : en dessous de SPEED_THRESHOLD, rien ; au-delà,
## le nombre de particules monte linéairement jusqu'à FORCE_MAX.
## `normale` = normale de la surface (UP au sol, horizontale au mur) :
## les particules jaillissent en éventail autour de cette normale.
func spawn_puff(centre: Vector2, normale: Vector2, force: float,\
		eventail: float = WALL_FAN, mur_cote: int = 0) -> void:
	if force < SPEED_THRESHOLD:
		return
	var intensite := clampf(
		(force - SPEED_THRESHOLD) / (MAX_SPEED - SPEED_THRESHOLD),
		0.0, 1.0)
	var nombre := roundi(lerpf(FORCE_MIN, FORCE_MAX, intensite))
	for i in nombre:
		_spawn_particule(centre, normale, eventail, mur_cote)


## Une particule de fumée : pixel carré blanc-gris (nuance tirée au
## hasard, comme le sang des ennemis a ses 3 couleurs), blending NORMAL
## (pas de matériau : la poussière masque au lieu d'illuminer), éjectée
## en éventail autour de `normale`, dérive vers le haut, fondu, puis
## auto-libération. Ajoutée au PARENT du sorcier (le niveau) en
## coordonnées GLOBALES : la fumée RESTE à l'endroit du contact au lieu
## de suivre le sorcier — c'est elle qui matérialise d'où il a sauté.
## Le tween est créé sur la particule elle-même : si le sorcier meurt
## pendant, les particules finissent leur fondu et se libèrent seules.
func _spawn_particule(centre: Vector2, normale: Vector2,\
		eventail: float = WALL_FAN, mur_cote: int = 0) -> void:
	if _texture == null:
		_texture = _generer_texture_carre(SIZE)
	var particule := Sprite2D.new()
	particule.texture = _texture
	particule.set_meta("poussiere", true)  # repérable par les tests
	var teinte := _nuance_poussiere(_couleur_surface(centre))
	particule.modulate = Color(teinte.r, teinte.g, teinte.b, 1.0)
	particule.z_index = 4
	sorcier.get_parent().add_child(particule)
	particule.global_position = centre
	var angle := normale.angle() + randf_range(-eventail, eventail)
	var arrivee := centre \
		+ Vector2.from_angle(angle) * DISTANCE * randf_range(0.3, 1.0) \
		+ Vector2(0, -UPWARD_DRIFT * randf_range(0.5, 1.0))
	# Au mur : l'éventail peut renvoyer une particule DANS le mur — on
	# clampe l'arrivée du côté libre (au moins 3 px du point de contact)
	if mur_cote != 0:
		var libre := -mur_cote
		arrivee.x = centre.x + maxf((arrivee.x - centre.x) * libre, 3.0) * libre
	var tween := particule.create_tween()
	tween.set_parallel(true)
	tween.tween_property(particule, "global_position", arrivee, LIFETIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(particule, "modulate:a", 0.0, LIFETIME * 0.5)\
		.set_delay(LIFETIME * 0.5)
	tween.chain().tween_callback(particule.queue_free)


## Couleur de FUMÉE pour un contact au point global `centre` : une des
## 3 nuances de la teinte de la surface (mélangée au blanc, cf.
## TINT_MIX), ou une des 3 nuances de gris d'origine si la
## surface n'est pas une tuile (repli blanc-gris).
func _nuance_poussiere(teinte: Color) -> Color:
	if teinte == Color.WHITE:
		return COLORS[randi_range(0, COLORS.size() - 1)]
	match randi_range(0, 2):
		0: return teinte.darkened(0.15)
		1: return teinte
		_: return teinte.lerp(Color.WHITE, 0.3)


## Couleur de la surface au point global `centre` : moyenne de la tuile
## du TileMapLayer du niveau sous ce point, mélangée au blanc. Blanc pur
## si pas de tuile (repli) ou si la tuile est entièrement transparente.
func _couleur_surface(centre: Vector2) -> Color:
	var tilemap := _trouver_tilemap()
	if tilemap == null:
		return Color.WHITE
	var cellule := tilemap.local_to_map(tilemap.to_local(centre))
	var tuile: TileData = tilemap.get_cell_tile_data(cellule)
	if tuile == null:
		return Color.WHITE
	var source := tilemap.tile_set.get_source(tilemap.get_cell_source_id(cellule)) as TileSetAtlasSource
	if source == null or source.texture == null:
		return Color.WHITE
	var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(cellule)
	var cle := "%s_%d_%d" % [source.texture.get_instance_id(), atlas_coords.x, atlas_coords.y]
	if _moyennes_tuiles.has(cle):
		return _moyennes_tuiles[cle].lerp(Color.WHITE, TINT_MIX)
	var moyenne := _moyenne_tuile(source, atlas_coords)
	_moyennes_tuiles[cle] = moyenne
	return moyenne.lerp(Color.WHITE, TINT_MIX)


## TileMapLayer du niveau : premier trouvé parmi les descendants du
## parent du sorcier (le niveau), mémorisé (la recherche est coûteuse,
## elle n'arrive qu'une fois par sorcier).
var _tilemap_memo: TileMapLayer = null


func _trouver_tilemap() -> TileMapLayer:
	if _tilemap_memo != null and is_instance_valid(_tilemap_memo):
		return _tilemap_memo
	var racine := sorcier.get_parent()
	if racine == null:
		return null
	var trouves := racine.find_children("*", "TileMapLayer", true, false)
	if trouves.is_empty():
		return null
	_tilemap_memo = trouves[0]
	return _tilemap_memo


## Moyenne des pixels OPAQUES de la tuile `atlas_coords` dans l'atlas
## `source` (les pixels transparents des tuiles à contours sont ignorés).
func _moyenne_tuile(source: TileSetAtlasSource, atlas_coords: Vector2i) -> Color:
	var img := _image_de_texture(source.texture)
	if img == null:
		return Color.WHITE
	var taille := source.texture_region_size
	var origine := atlas_coords * taille
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in range(origine.y, origine.y + taille.y):
		for x in range(origine.x, origine.x + taille.x):
			var pixel := img.get_pixel(x, y)
			if pixel.a > 0.0:
				r += pixel.r
				g += pixel.g
				b += pixel.b
				n += 1
	if n == 0:
		return Color.WHITE
	return Color(r / n, g / n, b / n)


## Image décodée d'une texture d'atlas (cache statique : le décodage
## n'arrive qu'une fois par texture, pour tout le jeu).
static func _image_de_texture(texture: Texture2D) -> Image:
	if _surface_images.has(texture):
		return _surface_images[texture]
	var img := texture.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	_surface_images[texture] = img
	return img


## Texture d'un carré blanc plein (pixel de fumée) — cache statique,
## identique pour tous les sorciers.
static func _generer_texture_carre(taille: int) -> ImageTexture:
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)
