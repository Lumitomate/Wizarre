class_name SorcererSac extends Area2D

@export var tube_energies: Array[GlobalEnum.EnergyType] = [GlobalEnum.EnergyType.Fossil, GlobalEnum.EnergyType.Pure, GlobalEnum.EnergyType.Tainted]

var tube_spells: Array[Dictionary] = [ {}, {}, {} ]  # Each tube: { attack_type, attack_tier }
var selected_tube: int = -1  # -1 = no tube selected
var spell_icons: Array[AnimatedSprite2D] = []  # Icônes positionnées dans la scène
var icon_base_y: Array[float] = []  # Position Y initiale des icônes (définie dans la scène)
var grow_states: Array[int] = [0, 0, 0]  # 0=idle, 1=sorti (fin de Grow), -1=reverse en cours

@export var tube_close_delay: float = 0.5 # délai avant qu'un tube échangé en boutique se referme

# Montée de l'icône (px) synchronisée avec l'anim du tube
const ICON_RISE := 15.0

signal spell_changed(tube_index)

# --- Flash de sélection (rayon au-dessus du tube qui sort) ---
# Colonne de lumière additive colorée selon la famille du sort du tube
# (feu rouge, glace bleu, lumière jaune, plante vert, vide → blanc,
# cf. WizardPalette.get_attack_family_color). Lancée uniquement quand un
# tube SORT (sélection / changement) — jamais sur les refermetures — et
# pas pour le sorcier d'affichage du pause (frozen).
const FLASH_WIDTH := 12.0
const FLASH_HEIGHT := 40.0
## Résolution de génération de la texture (2× la taille affichée, pour
## lisser les bords horizontaux)
const FLASH_TEX_WIDTH := 24.0
const FLASH_TEX_HEIGHT := 80.0
## Échelle du sprite : taille affichée / résolution de génération
const FLASH_SCALE := Vector2(FLASH_WIDTH / FLASH_TEX_WIDTH, FLASH_HEIGHT / FLASH_TEX_HEIGHT)
const FLASH_BURST := 0.1   # jaillissement (scale 0 → 1)
const FLASH_HOLD := 0.15   # tenue pleine
const FLASH_FADE := 0.25   # fondu

var _flash: Sprite2D = null
var _flash_tween: Tween = null

func _ready() -> void:
	var sorcerer = get_parent() as Sorcerer
	if sorcerer != null:
		sorcerer.ammo_changed.connect(_on_ammo_changed)
	
	# Icônes de sort placées manuellement dans la scène (AnimSpriteIcones*)
	spell_icons = [$AnimSpriteIconesCoal, $AnimSpriteIconesPure, $AnimSpriteIconesTainted]
	for i in range(3):
		icon_base_y.append(spell_icons[i].position.y)
	
	for i in range(3):
		var sprite = get_tube_node(i)
		if sprite == null or sprite.sprite_frames == null:
			continue
		# Retour à l'idle quand l'anim Grow se termine (boutique)
		sprite.animation_finished.connect(_on_grow_finished.bind(i))
		# Les anims Grow ne tournent qu'une fois
		for ammo in range(5):
			var anim_name = "%s_%d" % [get_tube_anim_prefix(tube_energies[i]), ammo]
			if sprite.sprite_frames.has_animation(anim_name):
				sprite.sprite_frames.set_animation_loop(anim_name, false)
	
	# Refresh all tube animations with current ammo levels
	for i in range(3):
		_update_tube_anim(i)
		_update_spell_icon(i)

func _process(_delta: float) -> void:
	# L'icône suit la progression de l'anim du tube, dans les deux sens :
	# - Grow (avant) : frame 0 → dernière, l'icône monte de 15 px
	# - Reverse      : dernière → 0, l'icône redescend
	# - Idle         : frame 0, icône à sa position d'origine
	for i in range(3):
		if i >= spell_icons.size() or i >= icon_base_y.size():
			continue
		var sprite = get_tube_node(i)
		if sprite == null or sprite.sprite_frames == null:
			continue
		var frame_count: int = sprite.sprite_frames.get_frame_count(sprite.animation)
		if frame_count <= 1:
			continue
		var ratio := clampf(float(sprite.frame) / float(frame_count - 1), 0.0, 1.0)
		spell_icons[i].position.y = icon_base_y[i] - ICON_RISE * ratio

func get_tube_node(index: int) -> AnimatedSprite2D:
	match index:
		0: return $AnimSpriteCoal    # Fossil (Charbon)
		1: return $AnimSpritePure    # Pure (Energie)
		2: return $AnimSpriteTainted # Tainted
	return null

func get_tube_anim_prefix(energy: GlobalEnum.EnergyType) -> String:
	if energy == GlobalEnum.EnergyType.Fossil:
		return "Pipe_Coal"
	elif energy == GlobalEnum.EnergyType.Pure:
		return "Pipe_Energy"
	return "Pipe_Tainted"

func _update_tube_anim(tube_index: int) -> void:
	# Affichage statique (frame 0 = visuel simple des munitions) : utilisé en jeu
	var sorcerer = get_parent() as Sorcerer
	if sorcerer == null:
		return
	var ammo: int = sorcerer.energy_counts[tube_index]
	var sprite = get_tube_node(tube_index)
	if sprite == null:
		return
	var anim_name = "%s_%d" % [get_tube_anim_prefix(tube_energies[tube_index]), ammo]
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name):
		sprite.animation = anim_name
		sprite.stop()  # stop() = frame 0 affichée, pas d'animation

func _on_grow_finished(tube_index: int) -> void:
	if grow_states[tube_index] == -1:
		# Reverse terminé → retour à l'affichage statique (frame 0)
		grow_states[tube_index] = 0
		_update_tube_anim(tube_index)
	# Fin du Grow avant : le tube reste sur la dernière frame (étendu)

func get_spell_icon_anim(attack_type: int) -> String:
	# Les noms d'enum (F1, G3, L1...) correspondent aux animations de la scène :
	# F1 → "Icone_AtkF1", G3 → "Icone_AtkG3", L1 → "Icone_AtkL1"...
	var type_name: String = GlobalEnum.AttackType.keys()[attack_type]
	var anim_name = "Icone_Atk" + type_name
	if spell_icons.size() > 0 and spell_icons[0].sprite_frames.has_animation(anim_name):
		return anim_name
	# F0 (Fireball) n'a pas d'icône dédiée : on utilise celle de F1
	if type_name == "F0" and spell_icons.size() > 0 and spell_icons[0].sprite_frames.has_animation("Icone_AtkF1"):
		return "Icone_AtkF1"
	return ""

func _update_spell_icon(tube_index: int) -> void:
	var sorcerer = get_parent() as Sorcerer
	if sorcerer == null or tube_index < 0 or tube_index >= spell_icons.size():
		return
	var icon = spell_icons[tube_index]
	var spell: Dictionary = sorcerer.spells[tube_index]
	if spell.is_empty():
		icon.visible = false
		return
	var anim_name = get_spell_icon_anim(spell["attack_type"])
	if anim_name == "" or not icon.sprite_frames.has_animation(anim_name):
		icon.visible = false
		return
	icon.visible = true
	icon.play(anim_name)

func play_grow_anim(tube_index: int) -> void:
	# Sortie du tube (16 frames) : uniquement lors de la sélection en boutique
	var sprite = get_tube_node(tube_index)
	if sprite == null:
		return
	_update_tube_anim(tube_index)  # positionne la bonne anim selon le nb de munitions
	sprite.play()                  # lecture avant
	grow_states[tube_index] = 1

func play_reverse_anim(tube_index: int) -> void:
	# Referme le tube : l'anim se joue à l'envers depuis la frame actuelle
	var sprite = get_tube_node(tube_index)
	if sprite == null:
		return
	if grow_states[tube_index] == 1:
		sprite.play_backwards()
		grow_states[tube_index] = -1
	else:
		# Le tube n'était pas sorti : retour direct à l'idle
		_update_tube_anim(tube_index)

func _on_ammo_changed(tube_index: int, _ammo_amount: int) -> void:
	_update_tube_anim(tube_index)

func refresh_all() -> void:
	for i in range(3):
		_update_tube_anim(i)
		_update_spell_icon(i)

func select_tube(tube_index: int) -> void:
	if tube_index < 0 or tube_index >= 3:
		return
	
	# Réappui sur le tube déjà sorti : il se referme (anim reverse) et se désélectionne
	if selected_tube == tube_index:
		selected_tube = -1
		play_reverse_anim(tube_index)
		return
	
	var previous = selected_tube
	selected_tube = tube_index
	
	# L'ancien tube se referme (reverse) pendant que le nouveau sort
	if previous != -1:
		play_reverse_anim(previous)
	
	# Le nouveau tube sort (16 frames)
	play_grow_anim(tube_index)
	# Flash de sélection au-dessus du tube qui sort
	_flasher_tube(tube_index)
	
	# Les tubes non concernés reviennent à l'affichage statique
	for i in range(3):
		if i != tube_index and i != previous:
			_update_tube_anim(i)

func set_spell(tube_index: int, attack_type: int, attack_tier: int) -> void:
	if tube_index < 0 or tube_index >= 3:
		return
	
	tube_spells[tube_index] = {
		"attack_type": attack_type,
		"attack_tier": attack_tier
	}
	
	# Met à jour l'icône du sort affichée dans le tube
	_update_spell_icon(tube_index)
	spell_changed.emit(tube_index)
	
	# En boutique : après l'échange (objet attrapé), le tube se referme
	# tout seul après un court délai, et se désélectionne (il faudra
	# réactiver un tube pour échanger à nouveau)
	var sorcerer = get_parent() as Sorcerer
	if sorcerer != null and sorcerer.in_shop:
		get_tree().create_timer(tube_close_delay).timeout.connect(
			_close_tube_after_swap.bind(tube_index)
		)

func _close_tube_after_swap(tube_index: int) -> void:
	# Le sorcier peut avoir quitté la boutique (ou être mort) pendant le délai
	if not is_inside_tree():
		return
	if selected_tube == tube_index:
		selected_tube = -1
		# Synchronise le sorcier : un tube descendu ne doit plus accepter
		# d'objet (la règle d'attrapage teste selected_tube du sorcier)
		var sorcerer := get_parent() as Sorcerer
		if sorcerer != null:
			sorcerer.selected_tube = -1
	play_reverse_anim(tube_index)

func get_spell(tube_index: int) -> Dictionary:
	if tube_index < 0 or tube_index >= 3:
		return {}
	return tube_spells[tube_index]


## Flash lumineux au-dessus du tube `tube_index` qui vient de sortir :
## colonne additive qui jaillit de la bouche du tube, tient, puis fond
## (total ~0,5 s, terminé avant la fin de la montée du tube). Re-flash
## sur sélection rapide : le tween précédent est tué, le rayon repart.
func _flasher_tube(tube_index: int) -> void:
	var sorcerer = get_parent() as Sorcerer
	# Sorcier d'affichage du pause : le soulèvement des tuyaux y est
	# décoratif, un flash lumineux au milieu du menu serait du bruit
	if sorcerer == null or sorcerer.frozen:
		return
	if _flash == null:
		_flash = _creer_flash()
		add_child(_flash)
	# Couleur : famille du sort contenu (blanc si tube vide)
	var spell: Dictionary = sorcerer.spells[tube_index]
	var couleur: Color = WizardPalette.get_attack_family_color(spell.get("attack_type", -1))
	_flash.modulate = Color(couleur.r, couleur.g, couleur.b, 1.0)
	# Ancrage : base du rayon à la bouche du tube (position de base de
	# l'icône du sort, qui est centrée sur le tube)
	_flash.position = Vector2(spell_icons[tube_index].position.x, icon_base_y[tube_index])
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.scale = Vector2(FLASH_SCALE.x, 0.02)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "scale:y", FLASH_SCALE.y, FLASH_BURST)
	_flash_tween.tween_interval(FLASH_HOLD)
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, FLASH_FADE)


## Construit le sprite du rayon (une fois pour toutes) : texture
## générée par pixel — fondu VERTICAL (transparent en haut, opaque à la
## base) × fondu HORIZONTAL (cœur plein, bords légèrement transparents,
## profil parabolique). Blending additif. Origine à la base du rayon
## (centré en x, s'étend vers le haut) pour que le jaillissement scale
## vers le haut uniquement. Texture en CACHE STATIQUE : identique pour
## tous les sorciers, elle n'est générée qu'une fois par partie.
static var _flash_texture: ImageTexture = null

func _creer_flash() -> Sprite2D:
	if _flash_texture == null:
		_flash_texture = _generer_texture_flash()
	var flash := Sprite2D.new()
	flash.texture = _flash_texture
	flash.centered = false
	flash.offset = Vector2(-FLASH_TEX_WIDTH * 0.5, -FLASH_TEX_HEIGHT)
	flash.scale = FLASH_SCALE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = mat
	flash.z_index = 5
	return flash


## Génération de la texture du rayon (pixel par pixel) : fondu vertical
## (transparent en haut → opaque à la base) × fondu horizontal (cœur
## plein, bords légèrement transparents, profil parabolique).
func _generer_texture_flash() -> ImageTexture:
	var largeur := int(FLASH_TEX_WIDTH)
	var hauteur := int(FLASH_TEX_HEIGHT)
	var img := Image.create(largeur, hauteur, false, Image.FORMAT_RGBA8)
	for y in hauteur:
		# Fondu vertical : 0 (transparent) en haut → 1 (opaque) à la base
		var alpha_v := float(y) / (hauteur - 1)
		for x in largeur:
			# Fondu horizontal : 1 au centre → 0 sur les bords (parabole,
			# bords légèrement transparents sans creux marqué)
			var u := absf(float(x) - (largeur - 1) * 0.5) / ((largeur - 1) * 0.5)
			var a := alpha_v * (1.0 - u * u)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

# --- Onde d'arrivée d'objet (anneau radial style Dead Cells) ---
# Anneau lumineux ADDITIF fin qui jaillit de la bouche du tube quand un
# objet y arrive (début de l'absorption, cf. object_attack._absorption).
# Départ rapide, freinage en fin d'expansion (ease-out), fondu sur la
# seconde moitié. Enfant du sac : l'onde suit le sorcier s'il marche.
# Style PIXELISÉ : texture BASSE résolution agrandie avec filtrage
# "nearest" (chaque texel devient un gros pixel carré à l'écran) et
# profil d'opacité quantifié (bords nets, pas de dégradé lissé).
# Couleur : famille de l'attaque portée par l'objet (cf. WizardPalette),
# passée en paramètre car le sort n'est chargé dans le tube qu'après.
const ONDE_RAYON := 15.0          # rayon final affiché (px)
const ONDE_DUREE := 0.3           # durée totale (s)
const ONDE_TEX_RAYON := 8.0       # rayon de l'anneau dans la texture (texels)
const ONDE_TEX_TAILLE := 32.0     # résolution de la texture carrée (texels)
const ONDE_TEX_EPAISSEUR := 2.0   # épaisseur de l'anneau en texels
## Échelle finale : rayon affiché / rayon texture (24 px → ×3, un texel = 3 px écran)
const ONDE_SCALE_MAX := ONDE_RAYON / ONDE_TEX_RAYON
## Échelle de départ : l'anneau part d'un petit point (~1 px de rayon)
const ONDE_SCALE_DEPART := 1.0 / ONDE_TEX_RAYON

var _onde_arrivee: Sprite2D = null
var _onde_arrivee_tween: Tween = null

## Onde d'arrivée d'objet dans le tube `tube_index`. L'anneau naît de la
## bouche du tube, s'étend jusqu'à ONDE_RAYON en ease-out sur ONDE_DUREE,
## alpha plein au départ puis fondu sur la seconde moitié. Une nouvelle
## onde pendant la précédente : le tween est tué, l'anneau repart.
## Comme le flash de sélection : rien pour le sorcier d'affichage du
## pause (frozen).
func flasher_onde(tube_index: int, attack_type: int) -> void:
	var sorcerer = get_parent() as Sorcerer
	if sorcerer == null or sorcerer.frozen:
		return
	if tube_index < 0 or tube_index >= spell_icons.size():
		return
	if _onde_arrivee == null:
		_onde_arrivee = _creer_onde_arrivee()
		add_child(_onde_arrivee)
	# Couleur : famille de l'attaque portée par l'objet (blanc si inconnu)
	var couleur: Color = WizardPalette.get_attack_family_color(attack_type)
	_onde_arrivee.modulate = Color(couleur.r, couleur.g, couleur.b, 1.0)
	# Ancrage : position COURANTE de la gemme du sort. La gemme monte avec
	# l'anim du tube (cf. _process, ICON_RISE), et l'onde se déclenche le
	# plus souvent tube sorti — l'ancrer sur sa position de base (tube
	# baissé) la ferait apparaître 15 px plus bas que la gemme réelle.
	_onde_arrivee.position = spell_icons[tube_index].position
	_lancer_particules_onde(_onde_arrivee.position, couleur)
	if _onde_arrivee_tween != null and _onde_arrivee_tween.is_valid():
		_onde_arrivee_tween.kill()
	_onde_arrivee.scale = Vector2.ONE * ONDE_SCALE_DEPART
	_onde_arrivee_tween = create_tween()
	_onde_arrivee_tween.set_parallel(true)
	_onde_arrivee_tween.tween_property(_onde_arrivee, "scale", Vector2.ONE * ONDE_SCALE_MAX, ONDE_DUREE)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_onde_arrivee_tween.tween_property(_onde_arrivee, "modulate:a", 0.0, ONDE_DUREE * 0.5)\
		.set_delay(ONDE_DUREE * 0.5)


## Construit le sprite de l'anneau (une fois pour toutes) : texture
## générée par pixel — anneau fin centré, profil linéaire doux. Blending
## additif, même z_index que le flash. Texture en CACHE STATIQUE :
## identique pour tous les sorciers, générée une fois par partie.
static var _onde_arrivee_texture: ImageTexture = null

func _creer_onde_arrivee() -> Sprite2D:
	if _onde_arrivee_texture == null:
		_onde_arrivee_texture = _generer_texture_onde_arrivee()
	var onde := Sprite2D.new()
	onde.texture = _onde_arrivee_texture
	# Filtrage "nearest" : agrandissement sans lissage → gros pixels nets
	onde.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	onde.material = CanvasItemMaterial.new()
	onde.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	onde.z_index = 5
	return onde


## Génération de la texture de l'anneau (pixel par pixel) : anneau
## centré sur ONDE_TEX_RAYON, épaisseur ONDE_TEX_EPAISSEUR. Profil
## QUANTIFIÉ (style pixel) : cœur plein, puis un anneau de
## demi-intensité, puis rien — bords nets, sans dégradé lissé.
func _generer_texture_onde_arrivee() -> ImageTexture:
	var taille := int(ONDE_TEX_TAILLE)
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	var centre := (taille - 1) * 0.5
	var demi_epaisseur := ONDE_TEX_EPAISSEUR * 0.5
	for y in taille:
		for x in taille:
			var d := Vector2(x - centre, y - centre).length()
			var u := absf(d - ONDE_TEX_RAYON) / demi_epaisseur
			var a := 1.0 if u < 0.5 else (0.5 if u < 1.0 else 0.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## Petit éclat qui accompagne l'onde : 3 à 5 pixels carrés qui partent
## radialement de la gemme dans des directions aléatoires, freinent
## (ease-out) sur la même durée que l'anneau, fondent sur la seconde
## moitié, puis se libèrent tout seuls. Même style pixelisé que
## l'anneau : un carré de la taille d'un « gros pixel », blending additif.
const ONDE_PARTICULE_TAILLE := 3   # px écran (un texel de l'anneau)
const ONDE_PARTICULE_DISTANCE := 5  # part de ONDE_RAYON × ce facteur minimum
static var _particule_texture: ImageTexture = null

func _lancer_particules_onde(centre: Vector2, couleur: Color) -> void:
	if _particule_texture == null:
		_particule_texture = _generer_texture_carre(ONDE_PARTICULE_TAILLE)
	var nombre := randi_range(3, 5)
	for i in nombre:
		var angle := randf() * TAU
		var distance := ONDE_RAYON * randf_range(ONDE_PARTICULE_DISTANCE, 1.0)
		var particule := Sprite2D.new()
		particule.texture = _particule_texture
		particule.set_meta("onde_particule", true)  # repérable par les tests
		particule.position = centre
		particule.modulate = Color(couleur.r, couleur.g, couleur.b, 1.0)
		particule.material = CanvasItemMaterial.new()
		particule.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		particule.z_index = 5
		add_child(particule)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particule, "position",\
			centre + Vector2.from_angle(angle) * distance, ONDE_DUREE)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particule, "modulate:a", 0.0, ONDE_DUREE * 0.5)\
			.set_delay(ONDE_DUREE * 0.5)
		tween.chain().tween_callback(particule.queue_free)


## Texture d'un carré blanc plein (pixel de particule)
func _generer_texture_carre(taille: int) -> ImageTexture:
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


func get_energy_count(tube_index: int) -> int:
	if tube_index < 0 or tube_index >= 3:
		return 0
	var sorcerer = get_parent() as Sorcerer
	if sorcerer == null:
		return 0
	return sorcerer.energy_counts[tube_index]

func consume_energy(tube_index: int, amount: int) -> bool:
	if tube_index < 0 or tube_index >= 3:
		return false
	if get_energy_count(tube_index) >= amount:
		get_parent().energy_counts[tube_index] -= amount
		return true
	return false
