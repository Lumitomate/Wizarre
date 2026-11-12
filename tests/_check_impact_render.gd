extends Node2D

## Outil d'inspection manuel (la CI ne le lance pas) : fait naître une
## explosion d'impact GLACE sur fond sombre et capture des screenshots
## PNG à des instants DONNÉS EN SECONDES (chronométrage réel — les
## premières frames du rendu sont lentes, compter des frames fausse le
## timing). Vérifie le remappage du shader à l'écran : les sprites de
## référence sont rouges, l'élément est glace → aucun rouge ne doit
## subsister. Captures dans tests/.
## Lancer FENÊTRÉ : godot res://tests/_check_impact_render.tscn

const CAPTURES := [0.05, 0.12, 0.2, 0.28, 0.4]


func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = Color(0.1, 0.1, 0.15)
	fond.size = Vector2(1280, 720)
	add_child(fond)

	# Explosion GLACE : les sprites de référence sont rouges — si du rouge
	# subsiste à l'écran, le remappage ne passe pas au rendu.
	var fx: ImpactExplosion = null
	ImpactExplosion.spawn(self, Vector2(640, 360),
		ImpactExplosion.rampe_pour_type(GlobalEnum.AttackType.G2))
	for enfant in get_children():
		if enfant is ImpactExplosion:
			fx = enfant

	var debut_ms := Time.get_ticks_msec()
	for instant: float in CAPTURES:
		# Chronomètre RÉEL : les frames de rendu n'ont pas de durée garantie
		while Time.get_ticks_msec() - debut_ms < instant * 1000.0:
			await get_tree().process_frame
		# L'horloge interne de l'effet fait foi pour l'age affiché
		var age: float = fx._age if is_instance_valid(fx) else -1.0
		var chemin := "res://tests/_capture_impact_%.2f.png" % instant
		get_viewport().get_texture().get_image().save_png(chemin)
		print("capture %s (age réel de l'effet : %.3f s)" % [chemin, age])

	get_tree().quit(0)
