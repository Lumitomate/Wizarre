extends Node2D

## Outil d'inspection manuel (la CI ne le lance pas) : rend un SEUL sprite
## de particule (frame 5, celle qui contient les 3 nuances sombres de la
## rampe de référence) agrandi ×8, avec le matériau impact_palette réglé
## sur la rampe GLACE, et capture le résultat. Attendu si le shader est
## correct : ff0000 → 00a8e0, ff4d00 → 17c5ff, ff9400 → 62d8ff, blanc →
## blanc. Capture dans tests/_capture_shader.png.
## Lancer FENÊTRÉ : godot res://tests/_check_shader_render.tscn

func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = Color(0.05, 0.05, 0.08)
	fond.size = Vector2(1280, 720)
	add_child(fond)

	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 24.0)
	frames.set_animation_loop(&"default", false)
	for i in range(1, 8):
		frames.add_frame(&"default", load(
			"res://assets/sprites/particules/atk_explosion/Explosion_large_1/ParticuleEplosion_large1_%d.png" % i))

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(640, 360)
	sprite.scale = Vector2(8, 8)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/impact_palette.gdshader")
	var rampe := ImpactExplosion.rampe_pour_type(GlobalEnum.AttackType.G2)
	for i in rampe.size():
		mat.set_shader_parameter("ramp_color_%d" % i, rampe[i])
	sprite.material = mat

	sprite.animation = &"default"
	sprite.frame = 4  # frame 5 : ff0000 + ff4d00 + ff9400, figée (pas de play)
	add_child(sprite)

	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://tests/_capture_shader.png")
	print("capture écrite : tests/_capture_shader.png")
	get_tree().quit(0)
