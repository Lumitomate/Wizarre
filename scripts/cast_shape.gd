@tool
class_name CastShape extends Node2D

# Forme lumineuse qui apparaît devant le sorcier au lancement d'un sort.
# PUREMENT COSMÉTIQUE : aucun lien avec la physique ou les dégâts, le
# projectile part comme avant, dans la même frame.
#
# - La FORME suit le TUBE d'où part le sort : carré = tube Fossil (0),
#   triangle = tube Pure (1), rond = tube Tainted (2). Chaque forme est
#   un masque dessiné à la main (assets/sprites/Attaques/ShaderSpellCast).
# - La COULEUR suit l'ÉLÉMENT du sort, avec la palette des gemmes du HUD :
#   feu = orange, glace = bleu, lumière = jaune, plante = vert.
# - Le shader lit le masque comme une UV map : plus le pixel est blanc,
#   plus la lumière est opaque ; plus il est foncé, plus elle est
#   transparente. Le fondu du halo est donc dessiné dans le masque.
#
# Chorégraphie (~0,4 s) : pop-in avec overshoot + flash blanc → tenue →
# rétrécit et s'efface, puis le nœud se détruit tout seul.
#
# Grâce à @tool, la forme est visible (figée) dans l'éditeur pour régler
# taille/position ; le mouvement complet se voit en lançant la scène
# d'aperçu tests/_preview_cast_shape.tscn (F6).

enum Shape { Square, Triangle, Circle }
enum Element { Feu, Glace, Lumiere, Plante }

## Masques dessinés à la main : luminosité = opacité de la lumière
const MASK_TEXTURES := {
	Shape.Square: preload("res://assets/sprites/Attaques/ShaderSpellCast/Carre1.png"),
	Shape.Triangle: preload("res://assets/sprites/Attaques/ShaderSpellCast/Triangle1.png"),
	Shape.Circle: preload("res://assets/sprites/Attaques/ShaderSpellCast/Rond.png"),
}

# Palette des gemmes du HUD (HUD_Gemne_F/G/L/P) : ton vif pour les pixels
# clairs du masque (tracé), ton profond pour les pixels sombres (halo)
const CORE_COLORS := {
	Element.Feu: Color("#ff9400"),
	Element.Glace: Color("#00bde7"),
	Element.Lumiere: Color("#fbf236"),
	Element.Plante: Color("#99e550"),
}
const GLOW_COLORS := {
	Element.Feu: Color("#ff4d00"),
	Element.Glace: Color("#007cff"),
	Element.Lumiere: Color("#e6cb2e"),
	Element.Plante: Color("#00ce00"),
}

# Durées de la chorégraphie (en secondes)
const POP_DURATION := 0.16
const FLASH_DURATION := 0.05
const HOLD_DURATION := 0.10
const FADE_DURATION := 0.15

@export var shape_kind: Shape = Shape.Square:
	set(value):
		shape_kind = value
		if is_node_ready():
			_apply_look()
@export var element: Element = Element.Feu:
	set(value):
		element = value
		if is_node_ready():
			_apply_look()
## Multiplicateur de taille (0.5 = moitié du dessin natif 64 px)
@export var size_scale := 0.5:
	set(value):
		size_scale = value
		if is_node_ready():
			$Shape.scale = Vector2.ONE * size_scale


func _ready() -> void:
	$Shape.scale = Vector2.ONE * size_scale
	_apply_look()
	if not Engine.is_editor_hint():
		# Passer DEVANT le sprite du sorcier (enfant avec z relatif +1).
		# Dans la scène d'aperçu, le fond est à z -10 : l'effet reste visible.
		z_index = 1
		play()


# Applique le masque et les couleurs au matériau shader
# (resource_local_to_scene : le matériau est dupliqué par instance, chaque
# effet garde ses réglages)
func _apply_look() -> void:
	var mat := $Shape.material as ShaderMaterial
	if mat == null:
		return
	var tex: Texture2D = MASK_TEXTURES[shape_kind]
	# La texture sert à la fois de quad (taille du sprite) et de masque
	$Shape.texture = tex
	mat.set_shader_parameter("mask", tex)
	mat.set_shader_parameter("core_color", CORE_COLORS[element])
	mat.set_shader_parameter("glow_color", GLOW_COLORS[element])
	if Engine.is_editor_hint():
		# Aperçu figé dans l'éditeur : couleur pleine, sans flash
		mat.set_shader_parameter("flash", 0.0)
		mat.set_shader_parameter("opacity", 0.85)


# Joue la chorégraphie complète puis détruit le nœud
func play() -> void:
	var mat := $Shape.material as ShaderMaterial
	scale = Vector2.ONE * 0.05
	mat.set_shader_parameter("flash", 1.0)
	mat.set_shader_parameter("opacity", 1.0)

	var tw := create_tween()
	# Pop-in : l'overshoot de TRANS_BACK dépasse la taille cible puis
	# revient, en un seul tween. Le flash blanc retombe en parallèle.
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, POP_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("flash", v),
			1.0, 0.0, FLASH_DURATION)
	# Tenue : plus rien à animer pendant HOLD_DURATION
	tw.chain().tween_interval(HOLD_DURATION)
	# Sortie : la forme rétrécit et s'efface comme aspirée par le sort
	tw.chain().tween_method(
			func(v: float) -> void: mat.set_shader_parameter("opacity", v),
			1.0, 0.0, FADE_DURATION)
	tw.parallel().tween_property(self, "scale", Vector2.ONE * 0.4, FADE_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
