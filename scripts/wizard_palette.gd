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


# Couleurs de flash des tubes (sélection en boutique / homepage), par
# FAMILLE d'attaque : préfixe du type ("F1" → feu, "G2" → glace,
# "L3" → lumière, "P1" → plante). Teintes vives pensées pour un rendu
# additif (rayon lumineux) ; tube vide ou type inconnu → blanc.
const ATTACK_FAMILY_COLORS := {
	"F": Color("#ff5544"),  # feu
	"G": Color("#55b8ff"),  # glace
	"L": Color("#ffd24a"),  # lumière
	"P": Color("#66e05a"),  # plante
}


## Couleur de flash d'un tube contenant `attack_type` : la famille est
## déduite du préfixe du nom d'enum (cf. ATTACK_FAMILY_COLORS). Blanc
## pour tube vide (-1) ou type inconnu.
static func get_attack_family_color(attack_type: int) -> Color:
	if attack_type < 0 or attack_type >= GlobalEnum.AttackType.size():
		return Color.WHITE
	var type_name: String = GlobalEnum.AttackType.keys()[attack_type]
	return ATTACK_FAMILY_COLORS.get(type_name.left(1), Color.WHITE)


# Applique les couleurs d'un sorcier à un matériau utilisant
# wizard_color.gdshader
static func apply_to_material(material: ShaderMaterial, color: GlobalEnum.SorcererColor) -> void:
	var palette := get_palette(color)
	material.set_shader_parameter("eye_color", palette["eye"])
	for i in palette["robe"].size():
		material.set_shader_parameter("robe_color_%d" % i, palette["robe"][i])
