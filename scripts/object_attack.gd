class_name AttackObject extends Area2D

## Émis quand un sorcier attrape l'objet (juste avant sa disparition) :
## le magasin Shophands s'en sert pour ouvrir sa porte de sortie une fois
## l'objet pris (cf. shop_hands.gd).
signal attrapee(sorcier: Sorcerer)

var item_attack_family: GlobalEnum.AttackFamily
@export var item_attack_type: GlobalEnum.AttackType
var item_attack_tier: GlobalEnum.AttackTier

var animation_name: String

# --- Vol d'absorption (prise de l'objet) ---
# Au contact : collision coupée, signal attrapee émis (les portes des
# hôtes s'ouvrent — inchangé), puis l'objet s'envole en arc de cloche
# vers le tube sélectionné du sorcier en rétrécissant et en fondant
# vers une petite sphère blanche (générée en code). Le sort n'est
# chargé dans le tube qu'à l'ARRIVÉE (set_attack → icône + délai de
# refermeture du sac), pour que le vol garde son sens : l'objet rejoint
# visiblement un tube encore vide. Le signal attrapee, lui, reste émis
# au contact : aucun impact gameplay.
const VOL_DURATION := 0.6      # vol complet (rétrécissement sur la 1re moitié)
const VOL_ARC_HAUTEUR := 40.0  # sommet de l'arc au-dessus de la ligne de vol
const VOL_SPHERE_DIAMETRE := 12.0  # diamètre final de la perle (unités locales)
const VOL_ABSORPTION := 0.05   # fondu d'absorption dans le tube à l'arrivée

# --- Objet vivant (lévitation, ébranlement, onde de chaleur) ---
# Mêmes réglages que le titre Wezarb vivant (cf. liquid_flow_controller) :
# les deux motifs partagent la grammaire « objet vivant ».
const LEVITATION_AMPLITUDE := 5.0   # oscillation verticale (px locaux)
const LEVITATION_PERIODE := 2.0     # durée d'un cycle complet (s)
const POUSSANCE_DISTANCE := 13.0    # recul au contact sans tube (px locaux)
const POUSSANCE_DUREE := 0.13       # poussee avant le retour élastique (s)
const RETOUR_ELASTIQUE_DUREE := 2.1 # oscillations décroissantes (s)
const ONDE_PERIODE := 2.0           # délai entre deux ondes de chaleur (s)
const ONDE_DUREE := 0.8             # durée d'expansion d'une onde (s)
const ONDE_RAYON_DEPART := 12.0     # rayon de départ (bord de l'objet)
const ONDE_RAYON_MAX := 40.0        # rayon maximal de l'onde
const ONDE_TEX_TAILLE := 64.0       # résolution de la texture carrée de l'onde
## Onde de chaleur DÉSACTIVÉE (réfraction d'écran jugée trop présente,
## shader conservé de côté : assets/shaders/heat_wave.gdshader). Passer
## à true pour la réactiver telle quelle.
const ONDE_ACTIVE := false
const HEAT_SHADER := preload("res://assets/shaders/heat_wave.gdshader")

var _sorcier_cible: Sorcerer = null
var _depart: Vector2 = Vector2.ZERO
var _sphere: Sprite2D = null
# Garde anti double-catch : la coupure de collision est différée (serveur
# physique), deux corps entrant dans la même frame déclencheraient sinon
# deux vols.
var _attrapee_deja := false

## Objet vivant : position de base (lévitation), phase aléatoire, recul
## courant de l'ébranlement, onde de chaleur en cours.
var _base_position := Vector2.ZERO
var _base_initialisee := false
var _phase_levitation := 0.0
var _temps := 0.0
var _recul := Vector2.ZERO
var _ebranlement_tween: Tween = null
var _onde: Sprite2D = null
var _onde_temps := 0.0
## Texture blanche de l'onde (le dessin de l'anneau est fait par le
## shader) — cache statique, identique pour tous les objets.
static var _onde_texture: ImageTexture = null

func _ready() -> void:
	_phase_levitation = randf() * TAU
	match item_attack_tier:
		GlobalEnum.AttackTier.III:
			animation_name = "Or"
		GlobalEnum.AttackTier.II:
			animation_name = "Argent"
		GlobalEnum.AttackTier.I:
			animation_name = "Bronze"
			
	$ObjetAttaqueAnimation.play(animation_name)
	
func _on_body_entered(body: Node2D) -> void:
	if _attrapee_deja:
		return
	if body.is_in_group("player_group"):
		var sorcerer: Sorcerer = body
		
		# En boutique : le remplacement n'a lieu que si un tube est activé.
		# Sinon l'objet reste en place MAIS réagit : il est bousculé
		# légèrement et revient élastiquement à sa place (règle du titre
		# Wezarb vivant, cf. _ebranler).
		if sorcerer.in_shop and sorcerer.selected_tube == -1:
			_ebranler(sorcerer)
			return
		
		_lancer_vol(sorcerer)
		attrapee.emit(sorcerer)

## Démarre le vol d'absorption : collision coupée (l'objet n'est plus
## attrapable), rétrécissement + fondu vers la sphère blanche sur la
## première moitié du vol, arc de cloche piloté par _vol_etape (cible
## suivie en live : le sorcier peut marcher et changer de tube). Le
## sort est chargé à l'arrivée (cf. _finaliser) ; l'objet n'est libéré
## qu'à la fin de l'absorption.
func _lancer_vol(sorcerer: Sorcerer) -> void:
	_attrapee_deja = true
	_sorcier_cible = sorcerer
	_depart = global_position
	set_deferred("monitoring", false)
	# L'objet cesse d'être « vivant » : ébranlement coupé net, onde de
	# chaleur terminée (le vol prend le relais)
	if _ebranlement_tween != null and _ebranlement_tween.is_valid():
		_ebranlement_tween.kill()
	if _onde != null and is_instance_valid(_onde):
		_onde.queue_free()
		_onde = null
	# Sphère colorée qui remplace l'objet en vol (enfant : hérite du
	# rétrécissement du parent). Couleur = famille de l'objet, mêmes
	# teintes que les rayons de sélection des tubes (cf. WizardPalette).
	_sphere = _creer_sphere()
	var couleur: Color = WizardPalette.get_attack_family_color(item_attack_type)
	_sphere.modulate = Color(couleur.r, couleur.g, couleur.b, 0.0)
	add_child(_sphere)
	# Taille cible : le sprite de l'objet réduit au diamètre de la sphère
	var sprite := $ObjetAttaqueAnimation as AnimatedSprite2D
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	var taille_sprite: float = maxf(tex.get_size().x, tex.get_size().y)
	var echelle_finale := VOL_SPHERE_DIAMETRE / maxf(taille_sprite, 1.0)
	# Rétrécissement pendant la première moitié du vol
	var retrecir := create_tween()
	retrecir.tween_property(self, "scale", Vector2.ONE * echelle_finale, VOL_DURATION * 0.5)
	# Fondu enchaîné : l'anim d'origine s'efface, la sphère apparaît
	var fondu := create_tween()
	fondu.set_parallel(true)
	fondu.tween_property(sprite, "modulate:a", 0.0, VOL_DURATION * 0.5)
	fondu.tween_property(_sphere, "modulate:a", 1.0, VOL_DURATION * 0.5)
	# Arc de cloche (cible suivie en live), puis absorption dans le tube
	var vol := create_tween()
	vol.tween_method(_vol_etape, 0.0, 1.0, VOL_DURATION)
	vol.tween_callback(_absorption)

## Une étape du vol : t ∈ [0, 1] le long de la ligne départ → cible
## actuelle, avec un sommet en cloche (sinus) recalculé chaque frame sur
## la position COURANTE du tube (le sorcier bouge pendant le vol).
func _vol_etape(t: float) -> void:
	var cible := _position_tube()
	var ligne := _depart.lerp(cible, t)
	global_position = ligne + Vector2(0, -VOL_ARC_HAUTEUR * sin(PI * t))

## Position actuelle du tube de destination (suivi en live : le sorcier
## bouge, et peut changer de tube sélectionné en cours de vol — la
## sphère rejoint le tube sélectionné à l'arrivée).
func _position_tube() -> Vector2:
	if _sorcier_cible == null or not is_instance_valid(_sorcier_cible):
		return _depart
	var sac := _sorcier_cible.get_node_or_null("SorcererSac") as SorcererSac
	if sac == null:
		return _sorcier_cible.global_position
	var tube := sac.get_tube_node(_tube_cible(_sorcier_cible))
	if tube == null:
		return _sorcier_cible.global_position
	return tube.global_position

## Index du tube de destination (règles d'origine : tube sélectionné en
## boutique, sinon famille → tube).
func _tube_cible(sorcier: Sorcerer) -> int:
	var tube_index: int = sorcier.selected_tube
	if tube_index == -1:
		match item_attack_family:
			GlobalEnum.AttackFamily.Fossil:
				tube_index = 0   # Fossil
			GlobalEnum.AttackFamily.Pure:
				tube_index = 1   # Pure
			GlobalEnum.AttackFamily.Tainted:
				tube_index = 2   # Tainted
			_:
				tube_index = 0
	return tube_index

## Arrivée dans le tube : absorption visuelle (la sphère fond dans le
## tube) puis chargement du sort.
func _absorption() -> void:
	if _sphere == null or not is_instance_valid(_sphere):
		_finaliser()
		return
	var fondu := create_tween()
	fondu.tween_property(_sphere, "modulate:a", 0.0, VOL_ABSORPTION)
	fondu.tween_callback(_finaliser)

## Chargement du sort dans le tube de destination : tube re-déterminé à
## l'arrivée (le joueur peut avoir changé de sélection pendant le vol)
## et tier recalculé sur les sorts ACTUELS du sorcier. Puis libération.
func _finaliser() -> void:
	if _sorcier_cible != null and is_instance_valid(_sorcier_cible):
		var tube_index := _tube_cible(_sorcier_cible)
		# Tier = nombre d'attaques du même élément que le joueur aura
		# après l'échange (1 → tier I, 2 → tier II, 3 ou plus → tier III).
		# On simule l'ajout de l'objet dans le tube pour que le comptage
		# inclue le nouvel objet lui-même.
		var projected_spells: Dictionary = _sorcier_cible.spells.duplicate(true)
		projected_spells[tube_index] = { "attack_type": item_attack_type, "attack_tier": 0 }
		var tier: int = SpellRules.compute_tier(projected_spells, item_attack_type)
		_sorcier_cible.set_attack(tube_index, item_attack_type, tier)
	queue_free()

## Petite sphère à bord doux, générée pixel par pixel (aucun
## asset) : cœur opaque, liseré fondu sur le dernier quart du rayon.
## Sa couleur est appliquée via modulate au moment du vol (famille de
## l'élément, cf. WizardPalette.get_attack_family_color).
## Texture en CACHE STATIQUE : identique pour tous les objets, elle
## n'est générée qu'une fois par partie.
static var _sphere_texture: ImageTexture = null

func _creer_sphere() -> Sprite2D:
	if _sphere_texture == null:
		_sphere_texture = _generer_texture_sphere()
	var sphere := Sprite2D.new()
	sphere.texture = _sphere_texture
	sphere.modulate.a = 0.0
	sphere.z_index = 1
	return sphere


## Génération de la texture de la sphère (pixel par pixel) : cœur
## opaque, bord fondu sur le dernier quart du rayon.
func _generer_texture_sphere() -> ImageTexture:
	var taille := 24
	var rayon := (taille - 1) * 0.5
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	for y in taille:
		for x in taille:
			var d := Vector2(x - rayon, y - rayon).length() / rayon
			var a := clampf((1.0 - d) / 0.25, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# --- Objet vivant : lévitation, ébranlement, onde de chaleur ---

## Tant que l'objet n'est pas attrapé : lévitation (sinus vertical,
## phase aléatoire) + onde de chaleur périodique. La position vaut
## base + flottement + recul d'ébranlement — les trois effets se
## composent, comme le titre Wezarb vivant.
func _physics_process(delta: float) -> void:
	if _attrapee_deja:
		return
	# Base capturée à la première frame physique : le spawner positionne
	# l'objet (parfois après l'ajout dans l'arbre), la base doit être la
	# position réelle de départ.
	if not _base_initialisee:
		_base_position = position
		_base_initialisee = true
	_temps += delta
	var flottement := Vector2(
		0.0, sin(TAU * _temps / LEVITATION_PERIODE + _phase_levitation) * LEVITATION_AMPLITUDE
	)
	position = _base_position + flottement + _recul
	_maj_onde(delta)


## Ébranlement « objet poussé » (motif du titre, cf.
## liquid_flow_controller) : poussee rapide opposée au joueur, puis
## retour élastique en oscillations décroissantes vers la base. Un
## nouvel ébranlement remplace le précédent (recul courant conservé).
func _ebranler(sorcier: Sorcerer) -> void:
	var direction := global_position - sorcier.global_position
	if direction.length() < 1.0:
		direction = Vector2.UP
	direction = direction.normalized()
	var poussee := direction * POUSSANCE_DISTANCE
	if _ebranlement_tween != null and _ebranlement_tween.is_valid():
		_ebranlement_tween.kill()
	_ebranlement_tween = create_tween()
	# Poussée rapide depuis le recul courant
	_ebranlement_tween.tween_method(
		func(v: Vector2) -> void: _recul = v,
		_recul, _recul + poussee, POUSSANCE_DUREE
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Retour élastique : oscillations décroissantes vers la position d'origine
	_ebranlement_tween.tween_method(
		func(v: Vector2) -> void: _recul = v,
		_recul + poussee, Vector2.ZERO, RETOUR_ELASTIQUE_DUREE
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Cycle de l'onde de chaleur : à chaque période, l'anneau s'étend du
## bord de l'objet jusqu'à son rayon maximal en s'estompant, puis se
## tait jusqu'au cycle suivant. Un seul sprite réutilisé.
## DÉSACTIVÉE (ONDE_ACTIVE = false) : aucune création, aucun coût.
func _maj_onde(delta: float) -> void:
	if not ONDE_ACTIVE:
		return
	if _onde == null:
		_onde = _creer_onde()
		add_child(_onde)
	_onde_temps += delta
	if _onde_temps >= ONDE_PERIODE:
		_onde_temps -= ONDE_PERIODE
	var t := _onde_temps / ONDE_DUREE
	if t <= 1.0:
		_onde.visible = true
		var rayon := lerpf(ONDE_RAYON_DEPART, ONDE_RAYON_MAX, t)
		_onde.scale = Vector2.ONE * (rayon * 2.0 / ONDE_TEX_TAILLE)
		_onde.modulate.a = 1.0 - t
	else:
		_onde.visible = false


## Le sprite de l'onde : carré plein recouvert du shader de réfraction
## (le dessin de l'anneau — bande, ondulation, transparence — est
## entièrement fait dans heat_wave.gdshader, qui lit l'écran derrière).
func _creer_onde() -> Sprite2D:
	if _onde_texture == null:
		var img := Image.create(int(ONDE_TEX_TAILLE), int(ONDE_TEX_TAILLE), false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_onde_texture = ImageTexture.create_from_image(img)
	var onde := Sprite2D.new()
	onde.texture = _onde_texture
	var material := ShaderMaterial.new()
	material.shader = HEAT_SHADER
	onde.material = material
	onde.visible = false
	return onde
