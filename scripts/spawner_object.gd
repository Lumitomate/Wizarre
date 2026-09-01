extends Node2D

var medal_object_scene: PackedScene 	= preload("res://scenes/obj_f1_medal.tscn")
var mirror_object_scene: PackedScene 	= preload("res://scenes/obj_l1_mirror.tscn")
var mitten_object_scene: PackedScene 	= preload("res://scenes/obj_g1_mitten.tscn")
var seeds_object_scene: PackedScene 	= preload("res://scenes/obj_p1_seeds.tscn")
var jar_object_scene: PackedScene 	= preload("res://scenes/obj_p2_jar.tscn")
var crown_object_scene: PackedScene 	= preload("res://scenes/obj_f2_crown.tscn")
var scarf_object_scene: PackedScene 	= preload("res://scenes/obj_g2_scarf.tscn")
var fireball_attack_scene: PackedScene 	= preload("res://scenes/atk_f0_fireball.tscn")


func _ready() -> void:
	var attack_family
	var attack_type = randi() % GlobalEnum.AttackType.size() as GlobalEnum.AttackType
	var attack_tier = randi() % GlobalEnum.AttackTier.size() as GlobalEnum.AttackTier
	
	var object_to_spawn_scene : PackedScene
	
	match attack_type:
		GlobalEnum.AttackType.FIREBALL:
			attack_family = GlobalEnum.AttackFamily.Red
			attack_type = GlobalEnum.AttackType.FIRECOLUMN
			object_to_spawn_scene = medal_object_scene
		GlobalEnum.AttackType.LIGHTRAY:
			attack_family = GlobalEnum.AttackFamily.Yellow
			object_to_spawn_scene = mirror_object_scene
		GlobalEnum.AttackType.FIRECOLUMN:
			attack_family = GlobalEnum.AttackFamily.Red
			object_to_spawn_scene = medal_object_scene
		GlobalEnum.AttackType.ICEBALL:
			attack_family = GlobalEnum.AttackFamily.Blue
			object_to_spawn_scene = mitten_object_scene
		GlobalEnum.AttackType.CARNIVOROUS:
			attack_family = GlobalEnum.AttackFamily.Red
			object_to_spawn_scene = seeds_object_scene
		GlobalEnum.AttackType.PLANTBALL:
			attack_family = GlobalEnum.AttackFamily.Red
			object_to_spawn_scene = jar_object_scene
		GlobalEnum.AttackType.FIREWAVE:
			attack_family = GlobalEnum.AttackFamily.Red
			object_to_spawn_scene = crown_object_scene
		GlobalEnum.AttackType.ICESPIKE:
			attack_family = GlobalEnum.AttackFamily.Blue
			object_to_spawn_scene = scarf_object_scene
		GlobalEnum.AttackType.ICEBLADE:
			attack_family = GlobalEnum.AttackFamily.Blue
			object_to_spawn_scene = fireball_attack_scene
	
	var object_to_spawn: AttackObject = object_to_spawn_scene.instantiate()
	
	object_to_spawn.item_attack_family = attack_family
	object_to_spawn.item_attack_type = attack_type
	object_to_spawn.item_attack_tier = attack_tier
	object_to_spawn.position = position
	
	get_parent().add_child.call_deferred(object_to_spawn)
