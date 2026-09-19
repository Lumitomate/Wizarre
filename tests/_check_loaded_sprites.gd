extends Node

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	var holder := Node2D.new()
	add_child(holder)
	var sorcerer: Sorcerer = scene.instantiate()
	sorcerer.controller_id = 0
	sorcerer.sorcerer_color = GlobalEnum.SorcererColor.Green
	holder.add_child(sorcerer)
	await get_tree().process_frame

	var sprite: AnimatedSprite2D = sorcerer.get_node("AnimatedSprite2D")
	print("Shader actif        : ", (sprite.material as ShaderMaterial).shader.resource_path)
	print("Animation en cours  : ", sprite.animation)
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	print("Texture affichée    : ", tex.resource_path)
	print("Oeil (uniform)      : ", sprite.material.get_shader_parameter("eye_color"))

	# Le HUD aussi
	var hud = load("res://scenes/hud/hud_players_info.tscn").instantiate()
	add_child(hud)
	hud.set_bg_color(GlobalEnum.SorcererColor.Yellow)
	await get_tree().process_frame
	var hud_tex: Texture2D = hud.get_node("SorcereColor").sprite_frames.get_frame_texture("default", 0)
	print("Texture HUD         : ", hud_tex.resource_path)
	get_tree().quit(0)
