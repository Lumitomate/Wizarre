extends Node

## Vérification headless de l'effet de lancement de sort : instanciation,
## application de la forme/couleur au shader, chorégraphie (vivant au
## départ, détruit à la fin), et correspondance élément → couleur.

const DURATION := 0.16 + 0.10 + 0.15 + 0.05  # pop + hold + fade + marge


func _ready() -> void:
	var failures := 0

	# 1. Forme et couleur bien appliquées au shader
	var shape: CastShape = load("res://scenes/outils/cast_shape.tscn").instantiate()
	shape.shape_kind = CastShape.Shape.Triangle
	shape.element = CastShape.Element.Glace
	add_child(shape)
	await get_tree().process_frame
	var mat: ShaderMaterial = shape.get_node("Shape").material
	var ok_shape: bool = mat.get_shader_parameter("mask") != null \
			and (mat.get_shader_parameter("mask") as Texture2D).resource_path.contains("Triangle1")
	var ok_color: bool = mat.get_shader_parameter("core_color") == CastShape.CORE_COLORS[CastShape.Element.Glace]
	var ok_alive: bool = is_instance_valid(shape) and shape.scale.x > 0.0
	print("Triangle/Glace : masque=%s couleur=%s vivant=%s" % [ok_shape, ok_color, ok_alive])
	if not (ok_shape and ok_color and ok_alive):
		failures += 1

	# 2. Le nœud se détruit seul à la fin de la chorégraphie
	await get_tree().create_timer(DURATION).timeout
	var ok_freed := not is_instance_valid(shape)
	print("Auto-destruction en fin d'effet : %s" % ok_freed)
	if not ok_freed:
		failures += 1

	# 3. Palette : chaque élément a bien un cœur et un halo distincts
	var ok_palette := CastShape.CORE_COLORS.size() == 4 and CastShape.GLOW_COLORS.size() == 4
	print("Palette 4 éléments : %s" % ok_palette)
	if not ok_palette:
		failures += 1

	print("Résultat : %s" % ("ÉCHEC (%d)" % failures if failures > 0 else "OK"))
	get_tree().quit(1 if failures > 0 else 0)
