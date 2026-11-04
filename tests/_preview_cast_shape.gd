extends Node2D

## Aperçu VISUEL de l'effet de lancement de sort. Ouvrir cette scène dans
## l'éditeur et appuyer sur F6 : les 3 formes × 4 éléments défilent en
## boucle au centre, avec un label indiquant ce qui est affiché.
## Réglages à tester dans l'inspecteur du nœud CastShape (taille, halo
## dans le matériau du Sprite2D), puis F6 à nouveau.

const PREVIEW_INTERVAL := 0.8

var _combos: Array = []
var _index := 0
var _elapsed := 0.0

@onready var _label: Label = $Label


func _ready() -> void:
	for shape in CastShape.Shape.values():
		for element in CastShape.Element.values():
			_combos.append([shape, element])
	_spawn_next()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= PREVIEW_INTERVAL:
		_elapsed = 0.0
		_spawn_next()


func _spawn_next() -> void:
	var combo: Array = _combos[_index]
	_index = (_index + 1) % _combos.size()
	var shape: CastShape = load("res://scenes/outils/cast_shape.tscn").instantiate()
	shape.shape_kind = combo[0]
	shape.element = combo[1]
	shape.position = Vector2(576, 324)
	# Chaque effet vit sa vie (~0,4 s) puis se détruit seul ; le suivant
	# arrive PREVIEW_INTERVAL plus tard, aucun chevauchement gênant.
	add_child(shape)
	_label.text = "Forme : %s (tube %s) — Élément : %s" % [
		CastShape.Shape.keys()[combo[0]],
		["Fossil", "Pure", "Tainted"][combo[0]],
		CastShape.Element.keys()[combo[1]],
	]
