extends Node

# Validation de la migration sprites sorciers -> sprite commun + shader :
# - la scène charge et s'instancie sans erreur
# - les animations ont mêmes noms, frames, vitesses et boucles qu'avant
# - le shader wizard_color est bien appliqué, couleurs par sorcier

const EXPECTED_ANIMS := {
	"attack_fire": {"frames": 12, "speed": 24.0, "loop": false},
	"fall": {"frames": 4, "speed": 12.0, "loop": false},
	"idle": {"frames": 8, "speed": 12.0, "loop": true},
	"jump": {"frames": 8, "speed": 24.0, "loop": false},
	"walk": {"frames": 12, "speed": 24.0, "loop": true},
}

const EYE_BY_COLOR := {
	GlobalEnum.SorcererColor.Red: Color("#5fcde4"),
	GlobalEnum.SorcererColor.Green: Color("#8a6f30"),
	GlobalEnum.SorcererColor.Blue: Color("#00ce00"),
	GlobalEnum.SorcererColor.Yellow: Color("#ff9400"),
}

func _ready() -> void:
	var ok := true

	var scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	if scene == null:
		print("TEST ÉCHOUÉ: sorcerer.tscn ne charge pas")
		get_tree().quit(1)
		return
	var sorcerer: Sorcerer = scene.instantiate()
	# Le sorcier s'attend à un parent Node2D (level_scale) et à des sorts
	# chargés (comme en jeu) : on reproduit ces conditions
	var holder := Node2D.new()
	add_child(holder)
	# Sorts par défaut (tubes remplis), comme au spawn réel du jeu
	var default_spells: Dictionary = GlobalInfo.run_info["players_info"]["default"]["spells"].duplicate(true)
	GlobalInfo.run_info["players_info"][0] = {"lives": 3, "energy_counts": [3, 3, 3], "spells": default_spells}
	sorcerer.controller_id = 0
	sorcerer.sorcerer_color = GlobalEnum.SorcererColor.Blue
	holder.add_child(sorcerer)
	await get_tree().process_frame

	# 1. Animations : mêmes frames / vitesse / boucle qu'avant migration
	var frames: SpriteFrames = sorcerer.get_node("AnimatedSprite2D").sprite_frames
	for anim_name in EXPECTED_ANIMS.keys():
		var expected: Dictionary = EXPECTED_ANIMS[anim_name]
		if not frames.has_animation(anim_name):
			print("TEST ÉCHOUÉ: animation manquante ", anim_name)
			ok = false
			continue
		var count := frames.get_frame_count(anim_name)
		var speed := frames.get_animation_speed(anim_name)
		var loop := frames.get_animation_loop(anim_name)
		print("TEST: ", anim_name, " -> ", count, " frames, speed ", speed, ", loop ", loop)
		if count != expected["frames"] or not is_equal_approx(speed, expected["speed"]) or loop != expected["loop"]:
			print("TEST ÉCHOUÉ: paramètres d'animation inattendus pour ", anim_name)
			ok = false

	# 2. Textures du sprite commun (32x32, toutes les frames présentes)
	for anim_name in EXPECTED_ANIMS.keys():
		for i in frames.get_frame_count(anim_name):
			var tex := frames.get_frame_texture(anim_name, i)
			if tex == null or tex.get_size() != Vector2(32, 32):
				print("TEST ÉCHOUÉ: texture invalide dans ", anim_name, " frame ", i)
				ok = false

	# 3. Shader : chaque couleur de sorcier produit ses paramètres
	var colors := [GlobalEnum.SorcererColor.Red, GlobalEnum.SorcererColor.Green, GlobalEnum.SorcererColor.Blue, GlobalEnum.SorcererColor.Yellow]
	for color in colors:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/wizard_color.gdshader")
		WizardPalette.apply_to_material(mat, color)
		if mat.get_shader_parameter("eye_color") != EYE_BY_COLOR[color]:
			print("TEST ÉCHOUÉ: couleur d'oeil incorrecte pour ", color)
			ok = false
		for i in 4:
			if mat.get_shader_parameter("robe_color_%d" % i) == null:
				print("TEST ÉCHOUÉ: robe_color_%d manquante pour " % i, color)
				ok = false
	print("TEST: palettes des 4 sorciers OK")

	# 4. Le matériau actif du sorcier (créé dans _ready) porte la couleur
	#    par défaut de la scène (Bleu = 3)
	var active_mat := sorcerer.get_node("AnimatedSprite2D").material as ShaderMaterial
	if active_mat == null or active_mat.get_shader_parameter("eye_color") != EYE_BY_COLOR[GlobalEnum.SorcererColor.Blue]:
		print("TEST ÉCHOUÉ: matériau actif sans couleur bleue")
		ok = false

	# 5. Le HUD charge et set_bg_color applique une matériau par instance
	var hud_scene: PackedScene = load("res://scenes/hud/hud_players_info.tscn")
	var huds := []
	if hud_scene == null:
		print("TEST ÉCHOUÉ: hud_players_info.tscn ne charge pas")
		ok = false
	else:
		for color in colors:
			var hud := hud_scene.instantiate()
			add_child(hud)
			hud.set_bg_color(color)
			huds.append(hud)
		await get_tree().process_frame
		var mats := {}
		for i in huds.size():
			var mat := huds[i].get_node("SorcereColor").material as ShaderMaterial
			if mat.get_shader_parameter("eye_color") != EYE_BY_COLOR[colors[i]]:
				print("TEST ÉCHOUÉ: HUD ", i, " avec mauvaise couleur")
				ok = false
			if mats.has(mat):
				print("TEST ÉCHOUÉ: matériau HUD partagé entre instances")
				ok = false
			mats[mat] = true
		print("TEST: HUD 4 joueurs, matériau indépendant par instance OK")

	sorcerer.queue_free()
	for hud in huds:
		hud.queue_free()
	if ok:
		print("TEST: TOUS LES TESTS PASSENT")
		get_tree().quit(0)
	else:
		print("TEST ÉCHOUÉ")
		get_tree().quit(1)
