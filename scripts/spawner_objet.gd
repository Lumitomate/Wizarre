extends Node2D

var objet_medaille_scene: PackedScene 	= preload("res://scenes/obj_f1_medaille.tscn")
var objet_miroir_scene: PackedScene 	= preload("res://scenes/obj_l1_miroir.tscn")
var objet_moufle_scene: PackedScene 	= preload("res://scenes/obj_g1_moufle.tscn")
var objet_graines_scene: PackedScene 	= preload("res://scenes/obj_p1_graines.tscn")
var objet_bocal_scene: PackedScene 	= preload("res://scenes/obj_p2_bocal.tscn")


func _ready() -> void:
	var attack_family
	var attack_type = randi() % GlobalEnum.AttackType.size() as GlobalEnum.AttackType
	var attack_tier = randi() % GlobalEnum.AttackTier.size() as GlobalEnum.AttackTier
	
	var object_to_spawn_scene : PackedScene
	
	match attack_type:
		GlobalEnum.AttackType.FIREBALL:
			attack_family = GlobalEnum.AttackFamily.Red
			attack_type = GlobalEnum.AttackType.FIRECOLUMN
			object_to_spawn_scene = objet_medaille_scene
		GlobalEnum.AttackType.LIGHTRAY:
			attack_family = GlobalEnum.AttackFamily.Yellow
			object_to_spawn_scene = objet_miroir_scene
		GlobalEnum.AttackType.FIRECOLUMN:
			attack_family = GlobalEnum.AttackFamily.Red
			object_to_spawn_scene = objet_medaille_scene
		GlobalEnum.AttackType.ICEBALL:
			attack_family = GlobalEnum.AttackFamily.Blue
			object_to_spawn_scene = objet_moufle_scene
		GlobalEnum.AttackType.CARNIVOROUS:
			attack_family = GlobalEnum.AttackFamily.Red
			object_to_spawn_scene = objet_graines_scene
		GlobalEnum.AttackType.PLANTBALL:
			attack_family = GlobalEnum.AttackFamily.Red
			object_to_spawn_scene = objet_bocal_scene
	
	var object_to_spawn: AttackObject = object_to_spawn_scene.instantiate()
	
	object_to_spawn.item_attack_family = attack_family
	object_to_spawn.item_attack_type = attack_type
	object_to_spawn.item_attack_tier = attack_tier
	object_to_spawn.position = position
	
	get_parent().add_child.call_deferred(object_to_spawn)
