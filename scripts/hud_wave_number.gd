@tool
extends Node2D
## Affiche un numéro de vague en chiffres romains (I, V, X).
##
## Utilisation dans l'éditeur :
##   - la position du nœud définit le CENTRE de l'affichage ;
##   - la taille se règle avec la propriété Scale du nœud (aperçu immédiat) ;
##   - "preview_wave_number" dans l'inspecteur change le numéro affiché
##     dans l'éditeur (en jeu, c'est le numéro de vague réel qui s'affiche).
##
## Au lancement du jeu, le numéro affiché est la vague en cours
## (run_info["level_number"] + 1, car la première vague vaut 0 en interne).
##
## Les lettres sont construites dynamiquement : chaque lettre est posée à la
## suite de la précédente avec le chevauchement défini dans OVERLAP_PX, et un
## sprite Jonction est posé sur la bordure droite de la lettre de gauche pour
## la "relier" à la suivante. La lettre de gauche est toujours dessinée
## au-dessus de celle de droite, et la Jonction au-dessus de tout le monde.

const TEXTURES := {
	"I": preload("res://assets/sprites/HUD/HUD_WaveNumber/WaveNumber_1.png"),
	"V": preload("res://assets/sprites/HUD/HUD_WaveNumber/WaveNumber_2.png"),
	"X": preload("res://assets/sprites/HUD/HUD_WaveNumber/WaveNumber_3.png"),
}
const JONCTION_TEXTURE := preload("res://assets/sprites/HUD/HUD_WaveNumber/Jonction4.png")

const LETTER_SIZE := Vector2i(15, 16)
const JONCTION_WIDTH := 2

# Nombre de pixels communs entre la lettre de gauche et la lettre de droite,
# pour chaque paire de lettres consécutives possible.
const OVERLAP_PX := {
	"I X": 2,
	"I I": 5,
	"I V": 4,
	"X V": 2,
	"X X": 2,
	"X I": 2,
	"V I": 3,
}

# Conversion en chiffres romains : paires (valeur, symbole), du plus grand au
# plus petit. Avec I, V et X on couvre les vagues 1 à 39 (XXXIX).
const ROMAN_VALUES := [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
const MAX_WAVE := 39

# Numéro affiché dans l'éditeur (en jeu, le numéro de vague réel est utilisé).
@export_range(1, 39) var preview_wave_number: int = 4:
	set(value):
		preview_wave_number = value
		if is_node_ready():
			set_wave_number(value)

var _sprites: Array[Sprite2D] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		set_wave_number(preview_wave_number)
	else:
		# Accès à l'autoload par son chemin (compatibilité mode éditeur/tests)
		var global_info := get_node("/root/GlobalInfo")
		set_wave_number(global_info.run_info["level_number"] + 1)


func set_wave_number(wave: int) -> void:
	var roman := to_roman(wave)
	_build(roman)


## Convertit un nombre en chiffres romains avec les lettres I, V et X.
## Au-delà de MAX_WAVE, la valeur est bornée (pas de sprite pour L, C, D, M).
static func to_roman(number: int) -> String:
	if number < 1 or number > MAX_WAVE:
		push_warning("hud_wave_number : vague %d hors bornes (1-%d), valeur bornée." % [number, MAX_WAVE])
		number = clampi(number, 1, MAX_WAVE)

	var result := ""
	for entry: Array in ROMAN_VALUES:
		while number >= entry[0]:
			result += entry[1]
			number -= entry[0]
	return result


## Construit les sprites des lettres et des jonctions, centrés sur l'origine
## du nœud. Les positions x se calculent en cascade : chaque lettre est posée
## (largeur - chevauchement) plus à droite que la précédente.
func _build(roman: String) -> void:
	for sprite in _sprites:
		sprite.queue_free()
	_sprites.clear()

	var x := -_total_width(roman) / 2.0
	for i in roman.length():
		# La lettre de gauche doit rester au-dessus de celle de droite :
		# z_index décroissant de gauche à droite.
		var letter := _create_letter_sprite(roman[i], x, roman.length() - i)
		add_child(letter)
		_sprites.append(letter)

		# Jonction entre cette lettre et la suivante (bordure droite de la
		# lettre de gauche), dessinée au-dessus de toutes les lettres.
		if i < roman.length() - 1:
			var jonction_x := x + LETTER_SIZE.x - JONCTION_WIDTH
			var jonction := _create_jonction_sprite(jonction_x, roman.length() + 1)
			add_child(jonction)
			_sprites.append(jonction)

			x += LETTER_SIZE.x - _overlap(roman[i], roman[i + 1])


func _create_letter_sprite(letter: String, x: float, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURES[letter]
	sprite.centered = false
	sprite.position = Vector2(x, 0)
	sprite.z_index = z
	return sprite


func _create_jonction_sprite(x: float, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = JONCTION_TEXTURE
	sprite.centered = false
	sprite.position = Vector2(x, 0)
	sprite.z_index = z
	return sprite


## Chevauchement (pixels communs) entre la lettre de gauche et celle de droite.
func _overlap(left: String, right: String) -> int:
	return OVERLAP_PX.get("%s %s" % [left, right], 2)


## Largeur totale du nombre romain : la première lettre pleine, puis chaque
## lettre suivante décalée de (largeur - chevauchement).
func _total_width(roman: String) -> int:
	if roman.is_empty():
		return 0
	var width := LETTER_SIZE.x
	for i in roman.length() - 1:
		width += LETTER_SIZE.x - _overlap(roman[i], roman[i + 1])
	return width
