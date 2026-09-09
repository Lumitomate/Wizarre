extends Node2D

var medal_object_scene: PackedScene 	= preload("res://scenes/obj_f1_medal.tscn")
var mirror_object_scene: PackedScene 	= preload("res://scenes/obj_l1_mirror.tscn")
var mitten_object_scene: PackedScene 	= preload("res://scenes/obj_g1_mitten.tscn")
var seeds_object_scene: PackedScene 	= preload("res://scenes/obj_p1_seeds.tscn")
var jar_object_scene: PackedScene 	= preload("res://scenes/obj_p2_jar.tscn")
var crown_object_scene: PackedScene 	= preload("res://scenes/obj_f2_crown.tscn")
var scarf_object_scene: PackedScene 	= preload("res://scenes/obj_g2_scarf.tscn")
var fireball_attack_scene: PackedScene 	= preload("res://scenes/atk_f0_fireball.tscn")
var beanie_object_scene: PackedScene 	= preload("res://scenes/obj_g3_beanie.tscn")
var belt_object_scene: PackedScene 	= preload("res://scenes/obj_f3_belt.tscn")


func _ready() -> void:
	var attack_family
	var attack_type = randi() % GlobalEnum.AttackType.size() as GlobalEnum.AttackType
	var attack_tier = randi() % GlobalEnum.AttackTier.size() as GlobalEnum.AttackTier
	
	var object_to_spawn_scene : PackedScene
	
	match attack_type:
		GlobalEnum.AttackType.F0:
			attack_family = GlobalEnum.AttackFamily.Red
			attack_type = GlobalEnum.AttackType.F1
			object_to_spawn_scene = medal_object_scene
		GlobalEnum.AttackType.L1:
			attack_family = GlobalEnum.AttackFamily.Yellow
			object_to_spawn_scene = mirror_object_scene
		GlobalEnum.AttackType.F1:
			attack_family = GlobalEnum.AttackFamily.Red
			object_to_spawn_scene = medal_object_scene
		GlobalEnum.AttackType.G1:
			attack_family = GlobalEnum.AttackFamily.Blue
			object_to_spawn_scene = mitten_object_scene
		GlobalEnum.AttackType.P1:
			attack_family = GlobalEnum.AttackFamily.Red
			object_to_spawn_scene = seeds_object_scene
		GlobalEnum.AttackType.P2:
			attack_family = GlobalEnum.AttackFamily.Red
			object_to_spawn_scene = jar_object_scene
		GlobalEnum.AttackType.F2:
			attack_family = GlobalEnum.AttackFamily.Red
			object_to_spawn_scene = crown_object_scene
		GlobalEnum.AttackType.G2:
			attack_family = GlobalEnum.AttackFamily.Blue
			object_to_spawn_scene = scarf_object_scene
		GlobalEnum.AttackType.G3:
			attack_family = GlobalEnum.AttackFamily.Blue
			object_to_spawn_scene = beanie_object_scene
		GlobalEnum.AttackType.F3:
			attack_family = GlobalEnum.AttackFamily.Red
			object_to_spawn_scene = belt_object_scene
	
	var object_to_spawn: AttackObject = object_to_spawn_scene.instantiate()
	
	object_to_spawn.item_attack_family = attack_family
	object_to_spawn.item_attack_type = attack_type
	object_to_spawn.item_attack_tier = attack_tier
	object_to_spawn.position = position
	
	get_parent().add_child.call_deferred(object_to_spawn)
