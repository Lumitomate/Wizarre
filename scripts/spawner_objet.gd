extends Node2D

var objet_medaille_scene: PackedScene 	= preload("res://scenes/objet_medaille.tscn")
var objet_miroir_scene: PackedScene 	= preload("res://scenes/objet_miroir.tscn")
var objet_moufle_scene: PackedScene 	= preload("res://scenes/objet_moufle.tscn")

func _ready() -> void:
	var attack_family
	var attack_type = randi() % Enum.AttackType.size() as Enum.AttackType
	var attack_tier = randi() % Enum.AttackTier.size() as Enum.AttackTier
	
	var object_to_spawn_scene : PackedScene
	
	match attack_type:
		Enum.AttackType.FIREBALL:
			attack_family = Enum.AttackFamily.Red
			attack_type = Enum.AttackType.FIRECOLUMN
			object_to_spawn_scene = objet_medaille_scene
		Enum.AttackType.LIGHTRAY:
			attack_family = Enum.AttackFamily.Yellow
			object_to_spawn_scene = objet_miroir_scene
		Enum.AttackType.FIRECOLUMN:
			attack_family = Enum.AttackFamily.Red
			object_to_spawn_scene = objet_medaille_scene
		Enum.AttackType.ICEBALL:
			attack_family = Enum.AttackFamily.Blue
			object_to_spawn_scene = objet_moufle_scene
	
	var object_to_spawn: AttackObject = object_to_spawn_scene.instantiate()
	
	object_to_spawn.item_attack_family = attack_family
	object_to_spawn.item_attack_type = attack_type
	object_to_spawn.item_attack_tier = attack_tier
	object_to_spawn.position = position
	
	get_parent().add_child.call_deferred(object_to_spawn)
	print("Object spawned")
