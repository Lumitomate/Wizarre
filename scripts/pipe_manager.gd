class_name PipeManager extends Node2D

## Sac du sorcier : orchestre les 3 tuyaux (Pipe) autonomes qu'il contient.
## Rôle : ORCHESTRATEUR VISUEL uniquement. Il anime la sélection d'un tube
## (sortie/refermeture), affiche l'icône du sort chargé et les effets
## (flash, onde), et se synchronise avec l'état du Sorcerer.
##
## Toute la DONNÉE (munitions, sorts, tube sélectionné) vit dans le
## Sorcerer, source de vérité. La référence au Sorcerer est INJECTÉE par
## le Sorcerer lui-même (cf. setup(), appelé dans son _ready) — ce script
## ne fait AUCUN get_parent() : la dépendance est explicite et testable.
## Toute la logique de décision (toggle de sélection, fermeture après
## échange, consommation d'énergie) vit aussi dans le Sorcerer ; ce
## script ne fait qu'animer ce que le Sorcerer lui ordonne.

## Sorcier auquel ce sac est rattaché (injecté via setup()). Source de
## vérité : energy_counts, spells, selected_tube, frozen.
var sorcerer: Sorcerer = null

@onready var pipe_coal: Pipe = $PipeCoal
@onready var pipe_pure: Pipe = $PipePure
@onready var pipe_tainted: Pipe = $PipeTainted

## Injection de la référence au Sorcerer : branche les signaux de mise à
## jour (munitions, sorts) et synchronise l'affichage avec l'état actuel.
## Appelé par le Sorcerer dans son _ready, avant load_data().
func setup(sorcier: Sorcerer) -> void:
	sorcerer = sorcier
	if not sorcerer.ammo_changed.is_connected(_on_ammo_changed):
		sorcerer.ammo_changed.connect(_on_ammo_changed)
	if not sorcerer.spell_changed.is_connected(_on_spell_changed):
		sorcerer.spell_changed.connect(_on_spell_changed)
	refresh_all()

## Renvoie le tuyau d'index `index` (0 = Coal/Fossil, 1 = Pure, 2 = Tainted).
## Utilisé aussi par object_attack.gd pour connaître la position du tube.
func get_tube_node(index: int) -> Pipe:
	match index:
		0: return pipe_coal
		1: return pipe_pure
		2: return pipe_tainted
	return null

## Munitions d'un tube : le Sorcerer émet ammo_changed, le tuyau se
## met à jour avec la valeur de la source de vérité.
func _on_ammo_changed(tube_index: int, _ammo_amount: int) -> void:
	if sorcerer == null or tube_index < 0 or tube_index >= 3:
		return
	get_tube_node(tube_index).set_ammo(sorcerer.energy_counts[tube_index])

## Sort chargé d'un tube : le Sorcerer émet spell_changed, l'icône du
## tuyau se met à jour (famille + tier).
func _on_spell_changed(tube_index: int, spell: Dictionary) -> void:
	if tube_index < 0 or tube_index >= 3:
		return
	get_tube_node(tube_index).set_spell(spell)

## Anime la sélection d'un tube : ORDRE de la source de vérité (le
## Sorcerer a déjà calculé selected_tube). Ce script ne décide rien.
## - selected == -1          → refermeture (anim reverse) de `previous` ;
## - selected != -1          → ouverture (Grow) de `selected` + flash,
##   refermeture de `previous` si ouvert, retour statique des autres.
func apply_selection(selected: int, previous: int) -> void:
	if selected == -1:
		# Refermeture seule (ré-appui sur le tube sorti, ou fermeture
		# après échange en boutique)
		if previous != -1 and previous != selected:
			get_tube_node(previous).play_reverse()
		return

	# L'ancien tube se referme (reverse) pendant que le nouveau sort
	if previous != -1 and previous != selected:
		get_tube_node(previous).play_reverse()

	# Le nouveau tube sort (16 frames)
	var pipe := get_tube_node(selected)
	pipe.play_grow()
	# Flash de sélection au-dessus du tube qui sort — sauf pour le sorcier
	# d'affichage du pause (frozen) : le soulèvement des tuyaux y est
	# décoratif, un flash lumineux au milieu du menu serait du bruit
	if sorcerer == null or not sorcerer.frozen:
		pipe.flash_select(_tube_spell_type(selected))

	# Les tubes non concernés reviennent à l'affichage statique
	for i in range(3):
		if i != selected and i != previous:
			get_tube_node(i).reset_display()

## Type du sort porté par le tube (pour la couleur du flash) :
## lit le sort du Sorcerer, source de vérité (blanc si tube vide)
func _tube_spell_type(tube_index: int) -> int:
	if sorcerer == null or tube_index < 0 or tube_index >= 3:
		return -1
	var spell: Dictionary = sorcerer.spells[tube_index]
	return spell.get("attack_type", -1)

## Synchronise tous les tuyaux avec l'état du Sorcerer (munitions + sorts).
## Appelé par setup() et à l'entrée en boutique (cf. shop_intro_base.gd).
func refresh_all() -> void:
	for i in range(3):
		var pipe := get_tube_node(i)
		if pipe == null:
			continue
		if sorcerer != null:
			pipe.set_ammo(sorcerer.energy_counts[i])
			pipe.set_spell(sorcerer.spells.get(i, {}))
		else:
			pipe.reset_display()

## Onde d'arrivée d'objet dans le tube `tube_index` (délégation au tuyau).
## Rien pour le sorcier d'affichage du pause (frozen) : décoratif.
func flasher_onde(tube_index: int, attack_type: int) -> void:
	if sorcerer != null and sorcerer.frozen:
		return
	if tube_index < 0 or tube_index >= 3:
		return
	get_tube_node(tube_index).flasher_onde(attack_type)
