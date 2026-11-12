class_name ImpactExplosion
extends Node2D

## ═══════════════════════════════════════════════════════════════════════
##  EXPLOSION D'IMPACT — feedback visuel quand une attaque touche un ennemi
## ═══════════════════════════════════════════════════════════════════════
##  Purement décoratif : aucun dégât, aucune collision. Spawné par
##  EnemyFlying.hit() UNIQUEMENT quand le coup fait réellement mal — un
##  contact sans dégâts (ex : graine au contact d'un monstre) ne déclenche
##  rien. S'auto-supprime quand l'explosion est terminée.
##
##  TIMELINE (60 fps — anim très rapide pour un max de choc) :
##    t = 0         : 3 à 7 particules dessinées (5 variantes de 7 frames,
##                    jouées une fois) partent du centre dans des
##                    directions réparties de façon homogène. Les variantes
##                    « fines » naissent plus excentrées : elles forment le
##                    pourtour de l'explosion, les « larges » le cœur.
##                    Une particule d'autant plus excentrée part d'autant
##                    plus vite. Chaque particule porte un halo additif qui
##                    simule la lumière : opaque et clair près de la
##                    particule, transparent et foncé loin, extinction
##                    exponentielle.
##    t = 5 frames  : des pixels blancs lumineux giclent du centre dans des
##                    directions diverses (vitesse ∝ excentrance du départ,
##                    comme les particules) : blanc au centre, ils
##                    ralentissent, virent vers la couleur sombre de la
##                    rampe et deviennent transparents, le tout en
##                    exponentielles. Ils survivent AUX SPRITES : les
##                    particules disparaissent à la fin de leur anim (7
##                    frames), les pixels persistent encore un peu.
##
##  PIXEL ART : la variété vient du tirage des 5 variantes et du miroir
##  horizontal flip_h, qui préserve la grille de pixels. Les sprites sont
##  orientés (rotation) pour que le bas du dessin regarde le centre de
##  l'explosion et le haut pointe vers l'extérieur — jamais retournés
##  verticalement, sinon bas et haut s'échangeraient.
##
##  COULEURS : chaque famille d'attaque a sa rampe (du sombre au clair) ;
##  les sprites de référence sont dessinés en rampe rouge feu et
##  recolorisés par remappage EXACT (assets/shaders/impact_palette.gdshader,
##  même patron que wizard_color.gdshader). Le blanc reste blanc.

## Rampe par famille, du sombre au clair (préfixe du nom d'enum, cf.
## WizardPalette.get_attack_family_color). « F » est la rampe de référence
## dessinée dans les sprites — c'est aussi le repli si l'élément d'une
## attaque ne peut pas être déterminé.
const RAMPES := {
	"F": [Color("ff0000"), Color("ff4d00"), Color("ff9400"), Color("ffba00")],  # feu (référence)
	"G": [Color("00a8e0"), Color("17c5ff"), Color("62d8ff"), Color("92e4ff")],  # glace
	"P": [Color("008400"), Color("00ce00"), Color("5ce836"), Color("95ff7f")],  # plante
	"L": [Color("8a6f30"), Color("e6cb2e"), Color("fbf236"), Color("ffff86")],  # lumière
}

const FPS := 60.0
const NB_FRAMES := 7
const FRAME_ETINCELLES := 5          # les pixels blancs partent à la frame 5
const T_ETINCELLES := FRAME_ETINCELLES / FPS
const DUREE_TOTALE := 0.4            # auto-suppression

const NB_PARTICULES_MIN := 3
const NB_PARTICULES_MAX := 7
const NB_ETINCELLES_MIN := 10
const NB_ETINCELLES_MAX := 16

# Rayons d'apparition (px, espace local de l'effet) — les fines naissent
# plus excentrées : pourtour de l'explosion ; les larges, le cœur.
const RAYON_LARGE_MIN := 6.0
const RAYON_LARGE_MAX := 30.0
const RAYON_FINE_MIN := 26.0
const RAYON_FINE_MAX := 42.0

# Vitesse ∝ excentrance du point de départ (spéc. : « plus le point de
# départ est excentré, plus la particule va vite »).
const VITESSE_BASE := 70.0           # px/s même au centre
const VITESSE_PAR_PX := 7.0          # px/s ajoutés par px d'excentrance
const FREINAGE_PARTICULE := 7.0      # décélération exponentielle (1/s)

# Étincelles blanches : giclée rapide puis freinage marqué. Elles
# survivent aux sprites (qui disparaissent à la fin de leur anim) :
# vie 0,3 s contre 7/60 ≈ 0,12 s pour les particules.
const ETINCELLE_VITESSE_BASE := 150.0
const ETINCELLE_VITESSE_PAR_PX := 8.0
const ETINCELLE_FREINAGE := 5.0
const ETINCELLE_VIE := 0.3
# Blanc → couleur sombre de la rampe + fondu alpha, tout en exponentielles.
const ETINCELLE_DECRO_COULEUR := 6.0
const ETINCELLE_DECRO_ALPHA := 8.0

# Halo lumineux autour de chaque particule (texture 64 px, radial).
const HALO_ALPHA_BASE := 0.55        # opacité au centre à t = 0
const HALO_DECROISSANCE := 9.0       # extinction exponentielle (1/s)
const HALO_ECHELLE := 2.5            # « assez large » : ~5× la particule

# Les sprites d'ennemis portent leur échelle ×2 sur la racine de leur
# scène (cf. enemy_flying.tscn) ; l'explosion est volontairement PLUS
# PETITE qu'eux (1,25) : un impact compact, pas une bouffée énorme.
const ECHELLE_RACINE := 1.25

# Jitter angulaire (radians) autour de la répartition homogène.
const JITTER_PARTICULE := 0.15
const JITTER_ETINCELLE := 0.3

## Les 5 variantes dessinées (7 frames chacune), fines en fin de liste.
## Le dossier « Explosion_large_ 3 » porte bien une espace dans son nom.
const REPERTOIRE := "res://assets/sprites/particules/atk_explosion"
const VARIANTES := [
	{"rep": REPERTOIRE + "/Explosion_large_1/ParticuleEplosion_large1_%d.png", "fine": false},
	{"rep": REPERTOIRE + "/Explosion_large_2/ParticuleEplosion_large2_%d.png", "fine": false},
	{"rep": REPERTOIRE + "/Explosion_large_ 3/ParticuleEplosion_large3_%d.png", "fine": false},
	{"rep": REPERTOIRE + "/Explosion_fine_1/ParticuleEplosion_fin1_%d.png", "fine": true},
	{"rep": REPERTOIRE + "/Explosion_fine_2/ParticuleEplosion_fin2_%d.png", "fine": true},
]

static var _frames_variantes: Array[SpriteFrames] = []
static var _est_fine: Array[bool] = []
static var _shader_palette: Shader = null
static var _halo_texture: GradientTexture2D = null
static var _texture_etincelle: ImageTexture = null

var _rampe: Array[Color] = []
var _particules: Array[Dictionary] = []   # {noeud, halo, vitesse}
var _etincelles: Array[Dictionary] = []   # {noeud, vitesse, age}
var _material: ShaderMaterial = null
var _materiel_additif: CanvasItemMaterial = null
var _age := 0.0
var _etincelles_lancees := false


## Rampe de l'explosion pour un coup porté : le type explicite (4e
## paramètre de EnemyFlying.hit — les attaques dont l'origine du coup n'est
## pas le nœud d'attaque, ex : lames orbitantes G3) gagne ; sinon recherche
## inverse du script dans AttackSpawner.REGISTRE en REMONTANT la
## hiérarchie — un sous-nœud peut porter le coup à la place de son attaque
## (ex : AttackPlantBrambleSegment, enfant de AttackPlantBramble, absent
## du REGISTRE) ; sinon rampe de référence (feu).
static func couleur_impact(origin: Node2D, attack_type: int = -1) -> Array[Color]:
	if attack_type >= 0:
		return rampe_pour_type(attack_type)
	if origin != null and is_instance_valid(origin):
		var noeud: Node = origin
		while noeud != null:
			var script_attaque: GDScript = noeud.get_script()
			if script_attaque != null:
				for type in AttackSpawner.REGISTRE:
					if AttackSpawner.REGISTRE[type] == script_attaque:
						return rampe_pour_type(type)
			noeud = noeud.get_parent()
	return rampe_pour_type(-1)


## Rampe d'une famille d'attaque : préfixe du nom d'enum (« F1 » → feu),
## cf. WizardPalette.get_attack_family_color. Type inconnu → référence.
static func rampe_pour_type(attack_type: int) -> Array[Color]:
	if attack_type < 0 or attack_type >= GlobalEnum.AttackType.size():
		return _rampe_depuis_lettre("")
	var lettre: String = GlobalEnum.AttackType.keys()[attack_type].left(1)
	return _rampe_depuis_lettre(lettre)


static func _rampe_depuis_lettre(lettre: String) -> Array[Color]:
	var rampe: Array[Color] = []
	for c: Color in RAMPES.get(lettre, RAMPES["F"]):
		rampe.append(c)
	return rampe


## Spawn l'explosion : parent = conteneur de l'ennemi (la Level, comme
## EnemyDeathBurst — les coordonnées locales de l'ennemi y sont valables),
## centre = position de l'impact, rampe = couleurs de l'élément.
static func spawn(parent: Node, centre: Vector2, rampe: Array[Color]) -> void:
	var fx := ImpactExplosion.new()
	fx.position = centre
	fx.scale = Vector2(ECHELLE_RACINE, ECHELLE_RACINE)
	fx._rampe = rampe
	parent.add_child(fx)


func _ready() -> void:
	_assurer_frames()
	_creer_particules()


func _process(delta: float) -> void:
	_age += delta
	for p: Dictionary in _particules:
		var noeud: AnimatedSprite2D = p["noeud"]
		noeud.position += p["vitesse"] * delta
		p["vitesse"] = p["vitesse"] * exp(-FREINAGE_PARTICULE * delta)
		# Le halo s'éteint exponentiellement (simule la lumière qui meurt).
		var halo: Sprite2D = p["halo"]
		halo.modulate.a = HALO_ALPHA_BASE * exp(-HALO_DECROISSANCE * _age)
	for e: Dictionary in _etincelles:
		var noeud: Sprite2D = e["noeud"]
		e["age"] += delta
		var t: float = e["age"]
		noeud.position += e["vitesse"] * delta
		e["vitesse"] = e["vitesse"] * exp(-ETINCELLE_FREINAGE * delta)
		var melange := 1.0 - exp(-ETINCELLE_DECRO_COULEUR * t)
		noeud.modulate = Color(Color.WHITE.lerp(_rampe[0], melange),
			exp(-ETINCELLE_DECRO_ALPHA * t))
		# Vie écoulée : déjà quasi transparente (fondu exponentiel), on
		# coupe net pour ne pas garder des nœuds inutiles en vie.
		if t >= ETINCELLE_VIE:
			noeud.visible = false
	# Les pixels blancs partent à la frame 5 des assets (5/60 s) — APRÈS la
	# boucle de mise à jour : une étincelle qui vient de naître ne doit pas
	# vieillir d'un delta entier dans la frame de sa naissance.
	if not _etincelles_lancees and _age >= T_ETINCELLES:
		_etincelles_lancees = true
		_creer_etincelles()
	if _age >= DUREE_TOTALE:
		queue_free()


# --- Construction -------------------------------------------------------

func _creer_particules() -> void:
	var n := randi_range(NB_PARTICULES_MIN, NB_PARTICULES_MAX)
	# Directions réparties de façon homogène sur le cercle (offset global
	# aléatoire + léger jitter) : explosion lisible, pas d'amas.
	var offset := randf() * TAU
	for i in n:
		var angle := offset + TAU * float(i) / float(n) + randf_range(-JITTER_PARTICULE, JITTER_PARTICULE)
		var dir := Vector2.from_angle(angle)
		var idx_variante := randi_range(0, _frames_variantes.size() - 1)
		var rayon := randf_range(RAYON_FINE_MIN, RAYON_FINE_MAX) if _est_fine[idx_variante] \
			else randf_range(RAYON_LARGE_MIN, RAYON_LARGE_MAX)
		# Départ aligné sur la grille de pixels (partie entière).
		var depart := (dir * rayon).round()
		# Halo d'abord : dessiné derrière la particule.
		var halo := Sprite2D.new()
		halo.name = "Halo%d" % i
		halo.texture = _texture_halo()
		halo.texture_filter = TEXTURE_FILTER_NEAREST
		halo.material = _materiel_lumiere()
		halo.position = depart
		halo.scale = Vector2(HALO_ECHELLE, HALO_ECHELLE)
		halo.modulate = _rampe[3]  # la nuance la plus claire = la lumière
		halo.modulate.a = HALO_ALPHA_BASE
		add_child(halo)
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Particule%d" % i
		sprite.sprite_frames = _frames_variantes[idx_variante]
		sprite.texture_filter = TEXTURE_FILTER_NEAREST
		sprite.material = _material_rampe()
		sprite.position = depart
		# Orientation : le haut du sprite (local -Y) pointe vers l'extérieur,
		# le bas vers le centre. flip_h seul : variété sans inverser haut/bas.
		sprite.rotation = angle + PI / 2.0
		sprite.flip_h = randf() < 0.5
		sprite.play(&"default")
		# Une fois les 7 frames jouées, la particule disparaît (le halo, lui,
		# continue de s'éteindre doucement).
		sprite.animation_finished.connect(sprite.hide)
		add_child(sprite)
		_particules.append({
			"noeud": sprite,
			"halo": halo,
			"vitesse": dir * (VITESSE_BASE + VITESSE_PAR_PX * rayon),
		})


func _creer_etincelles() -> void:
	var n := randi_range(NB_ETINCELLES_MIN, NB_ETINCELLES_MAX)
	var offset := randf() * TAU
	for i in n:
		var dir := Vector2.from_angle(offset + TAU * float(i) / float(n) + randf_range(-JITTER_ETINCELLE, JITTER_ETINCELLE))
		var depart := (dir * randf_range(2.0, 10.0)).round()
		var noeud := Sprite2D.new()
		noeud.name = "Etincelle%d" % i
		noeud.texture = _texture_pixels_blancs()
		noeud.texture_filter = TEXTURE_FILTER_NEAREST
		noeud.material = _materiel_lumiere()
		noeud.position = depart
		add_child(noeud)
		_etincelles.append({
			"noeud": noeud,
			"vitesse": dir * (ETINCELLE_VITESSE_BASE + ETINCELLE_VITESSE_PAR_PX * depart.length()),
			"age": 0.0,
		})


# --- Ressources partagées (chargées une seule fois pour toutes les
# explosions : chaque instance ne duplique que son matériau de rampe,
# qui porte les couleurs de SA famille) ----------------------------------

static func _assurer_frames() -> void:
	if not _frames_variantes.is_empty():
		return
	for variante: Dictionary in VARIANTES:
		var frames := SpriteFrames.new()
		frames.set_animation_speed(&"default", FPS)
		frames.set_animation_loop(&"default", false)
		for i in range(1, NB_FRAMES + 1):
			frames.add_frame(&"default", load(variante["rep"] % i))
		_frames_variantes.append(frames)
		_est_fine.append(variante["fine"])


func _material_rampe() -> ShaderMaterial:
	if _material == null:
		if _shader_palette == null:
			_shader_palette = load("res://assets/shaders/impact_palette.gdshader")
		_material = ShaderMaterial.new()
		_material.shader = _shader_palette
		for i in _rampe.size():
			_material.set_shader_parameter("ramp_color_%d" % i, _rampe[i])
	return _material


## Halo lumineux et étincelles : rendu additif (la lumière s'ajoute).
func _materiel_lumiere() -> CanvasItemMaterial:
	if _materiel_additif == null:
		_materiel_additif = CanvasItemMaterial.new()
		_materiel_additif.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _materiel_additif


## Halo radial : blanc au centre, transparent au bord. La chute
## d'opacité approxime une exponentielle (paliers du gradient). La
## couleur vient du modulate du sprite, la texture reste blanche.
static func _texture_halo() -> GradientTexture2D:
	if _halo_texture == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 0.6, 1.0])
		g.colors = PackedColorArray([
			Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.5),
			Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.0),
		])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 64
		tex.height = 64
		_halo_texture = tex
	return _halo_texture


## Étincelle = 2×2 pixels blancs purs (le modulate porte la couleur).
static func _texture_pixels_blancs() -> ImageTexture:
	if _texture_etincelle == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_texture_etincelle = ImageTexture.create_from_image(img)
	return _texture_etincelle
