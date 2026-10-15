class_name PlayerInfo extends Control

var controller_id: int = 0

var ammo_counts: Array = [0, 0, 0]
var lives: int = 0

# Taille de base de chaque gemme (capturée à la première arrivée de
# munition) et pulse en cours : évite qu'un pulse chevauchant capture la
# taille gonflée comme « base » et laisse la gemme agrandie pour de bon
var _gem_base_scales := {}
var _gem_pulses := {}

# Les gemmes du HUD suivent l'ordre des énergies des tubes :
# Fossil = 0, Pure = 1, Tainted = 2
const GEM_NODES := ["HudFosil", "HudPure", "HudTainted"]

# Vol de la munition ramassée vers sa gemme (purement cosmétique : le
# compteur est déjà à jour quand le vol démarre)
const FLIGHT_DURATION := 0.2
const PULSE_DURATION := 0.15

func _ready() -> void:
	add_to_group("player_hud_group")
	refresh_status()


func load_data(data_to_load: Dictionary) -> void:
	lives = data_to_load["lives"]
	ammo_counts = data_to_load["energy_counts"]


func refresh_status() -> void:
	# Vies : le sprite couvre 0 à 3 (frame = nombre de vies)
	$HudVie.frame = clampi(lives, 0, 3)

	# Gemmes : sprites de 5 frames dans l'ordre décroissant
	# (frame 0 = 4 ammo ou plus, frame 4 = 0 ammo)
	for tube_index in range(ammo_counts.size()):
		var gem: AnimatedSprite2D = get_node(GEM_NODES[tube_index])
		gem.frame = 4 - clampi(ammo_counts[tube_index], 0, 4)

func set_bg_color(color_id: GlobalEnum.SorcererColor):
	# Le matériau du .tscn est partagé entre les 4 HUD joueurs : on en
	# duplique un par instance avant d'y écrire les couleurs du joueur
	var sprite: AnimatedSprite2D = $SorcereColor
	var mat: ShaderMaterial = sprite.material.duplicate()
	WizardPalette.apply_to_material(mat, color_id)
	sprite.material = mat


func _on_ammo_changed(tube_index: int, ammo_amount: int):
	ammo_counts[tube_index] = ammo_amount
	refresh_status()
	
func _on_life_changed(amount: int) -> void:
	lives = amount
	refresh_status()


## Fait voler une copie de la munition ramassée jusqu'à la gemme du tube
## correspondant (0,2 s, ease-out), puis pulse la gemme. La copie part de
## la position/taille de la munition dans le monde et rétrécit jusqu'à la
## taille de la gemme. Cosmétique : appelée APRÈS add_energy, jamais
## bloquante, et sans effet si le tube est inconnu.
func fly_ammo_in(tube_index: int, from_position: Vector2, from_scale: Vector2) -> void:
	if tube_index < 0 or tube_index >= GEM_NODES.size():
		return
	var gem: AnimatedSprite2D = get_node(GEM_NODES[tube_index])
	var ghost := Sprite2D.new()
	ghost.texture = Ammo.TEXTURES[tube_index as GlobalEnum.EnergyType]
	ghost.texture_filter = TEXTURE_FILTER_NEAREST
	ghost.z_index = 100  # passe devant le décor et le panneau HUD
	add_child(ghost)
	# Position/scale globales APRÈS add_child : hors de l'arbre, ces setters
	# ignorent la transformation du parent (le Level est scalé 0.7) et la
	# valeur serait réinterprétée en local → fantôme décalé au départ
	ghost.global_position = from_position
	ghost.global_scale = from_scale

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "global_position", gem.global_position, FLIGHT_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "global_scale", gem.global_scale, FLIGHT_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_on_ammo_arrived.bind(ghost, tube_index))


## Arrivée de la munition : le fantôme disparaît, la gemme pulse.
## Plusieurs munitions peuvent arriver en rafale sur la même gemme : le
## pulse en cours est coupé et la gemme repart de sa taille de base.
func _on_ammo_arrived(ghost: Sprite2D, tube_index: int) -> void:
	ghost.queue_free()
	var gem: AnimatedSprite2D = get_node(GEM_NODES[tube_index])
	if not _gem_base_scales.has(tube_index):
		_gem_base_scales[tube_index] = gem.scale
	var previous: Tween = _gem_pulses.get(tube_index)
	if previous != null and previous.is_valid():
		previous.kill()
	gem.scale = _gem_base_scales[tube_index]
	var pulse := create_tween()
	_gem_pulses[tube_index] = pulse
	pulse.tween_property(gem, "scale", _gem_base_scales[tube_index] * 1.25, PULSE_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulse.tween_property(gem, "scale", _gem_base_scales[tube_index], PULSE_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
