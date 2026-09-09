class_name SorcererSac extends Area2D

enum EnergyType { Fossil, Pure, Tainted }

@export var tube_energies: Array[EnergyType] = [EnergyType.Fossil, EnergyType.Pure, EnergyType.Tainted]

var tube_spells: Array[Dictionary] = [ {}, {}, {} ]  # Each tube: { attack_type, attack_tier }
var selected_tube: int = -1  # -1 = no tube selected
var spell_icons: Array[AnimatedSprite2D] = []  # Icônes positionnées dans la scène
var icon_base_y: Array[float] = []  # Position Y initiale des icônes (définie dans la scène)
var grow_states: Array[int] = [0, 0, 0]  # 0=idle, 1=sorti (fin de Grow), -1=reverse en cours

# Montée de l'icône (px) synchronisée avec l'anim du tube
const ICON_RISE := 15.0

signal spell_changed(tube_index)

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

func get_tube_anim_prefix(energy: EnergyType) -> String:
	if energy == EnergyType.Fossil:
		return "Pipe_Coal"
	elif energy == EnergyType.Pure:
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

func _on_ammo_changed(tube_index: int, _ammunition_amount: int) -> void:
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

func get_spell(tube_index: int) -> Dictionary:
	if tube_index < 0 or tube_index >= 3:
		return {}
	return tube_spells[tube_index]

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
