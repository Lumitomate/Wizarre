class_name WizardPalette

# Couleurs de chaque sorcier, échantillonnées sur les sprites d'origine
# (rendu strictement identique à l'existant). La robe est donnée de la
# nuance la plus claire à la plus sombre ; le shader wizard_color.gdshader
# attend exactement cet ordre.
const PALETTES := {
	GlobalEnum.SorcererColor.Red: {
		"eye": Color("#5fcde4"),
		"robe": [Color("#d84d4d"), Color("#ac3232"), Color("#892f2f"), Color("#651414")],
	},
	GlobalEnum.SorcererColor.Green: {
		"eye": Color("#8a6f30"),
		"robe": [Color("#7dad50"), Color("#5f823f"), Color("#4b692f"), Color("#2b3a1e")],
	},
	GlobalEnum.SorcererColor.Blue: {
		"eye": Color("#00ce00"),
		"robe": [Color("#5b9fe1"), Color("#5b6ee1"), Color("#424b89"), Color("#242948")],
	},
	GlobalEnum.SorcererColor.Yellow: {
		"eye": Color("#ff9400"),
		"robe": [Color("#dda900"), Color("#c19300"), Color("#937616"), Color("#725b12")],
	},
}


static func get_palette(color: GlobalEnum.SorcererColor) -> Dictionary:
	return PALETTES[color]


# Applique les couleurs d'un sorcier à un matériau utilisant
# wizard_color.gdshader
static func apply_to_material(material: ShaderMaterial, color: GlobalEnum.SorcererColor) -> void:
	var palette := get_palette(color)
	material.set_shader_parameter("eye_color", palette["eye"])
	for i in palette["robe"].size():
		material.set_shader_parameter("robe_color_%d" % i, palette["robe"][i])
