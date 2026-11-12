extends Node2D

## Aperçu VISUEL des icônes de sorts sur les boutons lumière de la cabine.
## Ouvrir cette scène dans l'éditeur et appuyer sur F6 : la cabine est
## affichée à l'échelle de jeu (2), avec une icône de sort figée et
## visible sur chaque bouton lumière, plus l'icône du réceptacle.
## Réglages : dans bubble_cabine.tscn, chaque icône est un enfant de son bouton
## (BoutonsLumiere/BoutonLumiere_*/Icone) — position et scale sont
## relatives au bouton. Ajuster, puis F6 à nouveau.

const SORTS := [
	["F1", "Icone_AtkF1"],
	["L2", "Icone_AtkL2"],
	["G3", "Icone_AtkG3"],
]

@onready var _label: Label = $Label


func _ready() -> void:
	var cabine: Node2D = load("res://scenes/niveaux/magasin/bubble_cabine.tscn").instantiate()
	cabine.position = Vector2(576, 380)
	cabine.scale = Vector2(2, 2)
	add_child(cabine)
	# Les icônes sont invisibles au repos (cabin.gd les affiche pendant le
	# rituel) : on les force visibles pour l'aperçu.
	var boutons := [
		"BoutonsLumiere/BoutonLumiere_fossil",
		"BoutonsLumiere/BoutonLumiere_energy",
		"BoutonsLumiere/BoutonLumiere_tainted",
	]
	for i in boutons.size():
		var icone := cabine.get_node(boutons[i] + "/Icone") as AnimatedSprite2D
		icone.animation = SORTS[i][1]
		icone.visible = true
		icone.modulate.a = 1.0
	var receptacle := cabine.get_node("Icones/IconeReceptacle") as AnimatedSprite2D
	receptacle.visible = true
	receptacle.modulate.a = 1.0
	_label.text = "Aperçu icônes de sorts — F1 / L2 / G3 sur les boutons lumière + réceptacle (échelle jeu ×2)"
