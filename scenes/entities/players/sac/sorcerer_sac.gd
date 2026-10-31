class_name SorcererSac extends Area2D

## Sac du sorcier : orchestre les 3 tuyaux (Pipe) autonomes qu'il contient.
## Il gère : la sélection d'un tube (sortie/refermeture animées), l'échange
## d'objet en boutique, et la synchronisation de l'état du Sorcerer
## (munitions, sorts) vers les tuyaux.
## Tout ce qui est purement visuel vit dans Pipe (anim, icône, flash,
## onde) ; ce script ne manipule plus les sprites directement.

@export var tube_close_delay: float = 0.5 # délai avant qu'un tube échangé en boutique se referme

var tube_spells: Array[Dictionary] = [ {}, {}, {} ]  # Each tube: { attack_type, attack_tier }
var selected_tube: int = -1  # -1 = no tube selected

signal spell_changed(tube_index)

func _ready() -> void:
	var sorcerer = get_parent() as Sorcerer
	if sorcerer != null:
		sorcerer.ammo_changed.connect(_on_ammo_changed)
	refresh_all()

## Renvoie le tuyau d'index `index` (0 = Coal/Fossil, 1 = Pure, 2 = Tainted).
## Utilisé aussi par object_attack.gd pour connaître la position du tube.
func get_tube_node(index: int) -> Pipe:
	match index:
		0: return $PipeCoal
		1: return $PipePure
		2: return $PipeTainted
	return null

func _on_ammo_changed(tube_index: int, _ammo_amount: int) -> void:
	var sorcerer = get_parent() as Sorcerer
	if sorcerer == null or tube_index < 0 or tube_index >= 3:
		return
	get_tube_node(tube_index).set_ammo(sorcerer.energy_counts[tube_index])

func select_tube(tube_index: int) -> void:
	if tube_index < 0 or tube_index >= 3:
		return

	# Réappui sur le tube déjà sorti : il se referme (anim reverse) et se désélectionne
	if selected_tube == tube_index:
		selected_tube = -1
		get_tube_node(tube_index).play_reverse()
		return

	var previous = selected_tube
	selected_tube = tube_index

	# L'ancien tube se referme (reverse) pendant que le nouveau sort
	if previous != -1:
		get_tube_node(previous).play_reverse()

	# Le nouveau tube sort (16 frames)
	var pipe := get_tube_node(tube_index)
	pipe.play_grow()
	# Flash de sélection au-dessus du tube qui sort — sauf pour le sorcier
	# d'affichage du pause (frozen) : le soulèvement des tuyaux y est
	# décoratif, un flash lumineux au milieu du menu serait du bruit
	var sorcerer = get_parent() as Sorcerer
	if sorcerer == null or not sorcerer.frozen:
		pipe.flash_select(_tube_spell_type(tube_index))

	# Les tubes non concernés reviennent à l'affichage statique
	for i in range(3):
		if i != tube_index and i != previous:
			get_tube_node(i).reset_display()

## Type du sort porté par le tube (pour la couleur du flash) :
## lit le sort du Sorcerer, source de vérité (blanc si tube vide)
func _tube_spell_type(tube_index: int) -> int:
	var sorcerer = get_parent() as Sorcerer
	if sorcerer == null or tube_index < 0 or tube_index >= 3:
		return -1
	var spell: Dictionary = sorcerer.spells[tube_index]
	return spell.get("attack_type", -1)

func set_spell(tube_index: int, attack_type: int, attack_tier: int) -> void:
	if tube_index < 0 or tube_index >= 3:
		return

	tube_spells[tube_index] = {
		"attack_type": attack_type,
		"attack_tier": attack_tier
	}

	# Met à jour l'icône du sort affichée dans le tuyau
	get_tube_node(tube_index).set_spell({"attack_type": attack_type, "attack_tier": attack_tier})
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
	get_tube_node(tube_index).play_reverse()

func get_spell(tube_index: int) -> Dictionary:
	if tube_index < 0 or tube_index >= 3:
		return {}
	return tube_spells[tube_index]

## Synchronise tous les tuyaux avec l'état du Sorcerer (munitions + sorts).
## Appelé au chargement des données et à l'entrée en boutique.
func refresh_all() -> void:
	var sorcerer = get_parent() as Sorcerer
	for i in range(3):
		var pipe := get_tube_node(i)
		if pipe == null:
			continue
		if sorcerer != null:
			pipe.set_ammo(sorcerer.energy_counts[i])
			var sp: Dictionary = sorcerer.spells.get(i, {})
			pipe.set_spell(sp)
		else:
			pipe.reset_display()

## Onde d'arrivée d'objet dans le tube `tube_index` (délégation au tuyau).
## Rien pour le sorcier d'affichage du pause (frozen) : décoratif.
func flasher_onde(tube_index: int, attack_type: int) -> void:
	var sorcerer = get_parent() as Sorcerer
	if sorcerer == null or sorcerer.frozen:
		return
	if tube_index < 0 or tube_index >= 3:
		return
	get_tube_node(tube_index).flasher_onde(attack_type)

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
