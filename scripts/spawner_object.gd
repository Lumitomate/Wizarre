extends Node2D

# Spawner d'objets du magasin. Chaque spawner propose UN objet, et les
# spawners d'une même pièce se coordonnent pour ne jamais proposer
# deux fois le même objet (voir _pick_unique_type).

var medal_object_scene: PackedScene 	= preload("res://scenes/objets/obj_f1_medal.tscn")
var mirror_object_scene: PackedScene 	= preload("res://scenes/objets/obj_l1_mirror.tscn")
var mitten_object_scene: PackedScene 	= preload("res://scenes/objets/obj_g1_mitten.tscn")
var seeds_object_scene: PackedScene 	= preload("res://scenes/objets/obj_p1_seeds.tscn")
var jar_object_scene: PackedScene 	= preload("res://scenes/objets/obj_p2_jar.tscn")
var crown_object_scene: PackedScene 	= preload("res://scenes/objets/obj_f2_crown.tscn")
var scarf_object_scene: PackedScene 	= preload("res://scenes/objets/obj_g2_scarf.tscn")
var beanie_object_scene: PackedScene 	= preload("res://scenes/objets/obj_g3_beanie.tscn")
var belt_object_scene: PackedScene 	= preload("res://scenes/objets/obj_f3_belt.tscn")
var brush_object_scene: PackedScene 	= preload("res://scenes/objets/obj_l3_brosse.tscn")
var comb_object_scene: PackedScene 	= preload("res://scenes/objets/obj_l3_brosse.tscn")

# Type final de l'objet proposé par ce spawner (-1 = pas encore choisi)
var chosen_object_type: int = -1

# Les types d'objets distincts proposables dans le magasin.
# (F0 Fireball n'a pas d'objet dédié : il est redirigé vers F1)
const PROPOSABLE_TYPES := [
	GlobalEnum.AttackType.F1, GlobalEnum.AttackType.F2, GlobalEnum.AttackType.F3,
	GlobalEnum.AttackType.G1, GlobalEnum.AttackType.G2, GlobalEnum.AttackType.G3,
	GlobalEnum.AttackType.L1, GlobalEnum.AttackType.L2, GlobalEnum.AttackType.L3,
	GlobalEnum.AttackType.P1, GlobalEnum.AttackType.P2,
]

func _ready() -> void:
	# Tous les objets du magasin apparaissent en Bronze. Le tier réel de
	# l'attaque est calculé à la prise, selon les attaques du joueur
	# (voir object_attack.gd)
	var attack_tier: GlobalEnum.AttackTier = GlobalEnum.AttackTier.I
	
	var final_type: int = _pick_unique_type()
	chosen_object_type = final_type
	
	var attack_family
	var object_to_spawn_scene: PackedScene
	
	match final_type:
		GlobalEnum.AttackType.F1:
			attack_family = GlobalEnum.AttackFamily.Fossil
			object_to_spawn_scene = medal_object_scene
		GlobalEnum.AttackType.L1:
			attack_family = GlobalEnum.AttackFamily.Pure
			object_to_spawn_scene = mirror_object_scene
		GlobalEnum.AttackType.G1:
			attack_family = GlobalEnum.AttackFamily.Tainted
			object_to_spawn_scene = mitten_object_scene
		GlobalEnum.AttackType.P1:
			attack_family = GlobalEnum.AttackFamily.Fossil
			object_to_spawn_scene = seeds_object_scene
		GlobalEnum.AttackType.P2:
			attack_family = GlobalEnum.AttackFamily.Fossil
			object_to_spawn_scene = jar_object_scene
		GlobalEnum.AttackType.F2:
			attack_family = GlobalEnum.AttackFamily.Fossil
			object_to_spawn_scene = crown_object_scene
		GlobalEnum.AttackType.G2:
			attack_family = GlobalEnum.AttackFamily.Tainted
			object_to_spawn_scene = scarf_object_scene
		GlobalEnum.AttackType.G3:
			attack_family = GlobalEnum.AttackFamily.Tainted
			object_to_spawn_scene = beanie_object_scene
		GlobalEnum.AttackType.F3:
			attack_family = GlobalEnum.AttackFamily.Fossil
			object_to_spawn_scene = belt_object_scene
		GlobalEnum.AttackType.L2:
			attack_family = GlobalEnum.AttackFamily.Pure
			object_to_spawn_scene = comb_object_scene
		GlobalEnum.AttackType.L3:
			attack_family = GlobalEnum.AttackFamily.Pure
			object_to_spawn_scene = brush_object_scene
	
	var object_to_spawn: AttackObject = object_to_spawn_scene.instantiate()
	
	object_to_spawn.item_attack_family = attack_family
	object_to_spawn.item_attack_type = final_type as GlobalEnum.AttackType
	object_to_spawn.item_attack_tier = attack_tier
	object_to_spawn.position = position
	# L'objet ne doit pas hériter du grossissement du spawner : si le spawner
	# est placé dans un conteneur mis à l'échelle dans l'éditeur (épreuve,
	# déco...), on ramène l'objet à la taille standard des objets du magasin
	# (celle de la scène racine).
	var scene_root: Node = self
	while scene_root.get_parent() != null and scene_root.get_parent() != get_tree().root:
		scene_root = scene_root.get_parent()
	var target_scale: Vector2 = (scene_root as Node2D).global_transform.get_scale()
	var parent_scale: Vector2 = get_global_transform().get_scale()
	object_to_spawn.scale = Vector2(target_scale.x / parent_scale.x, target_scale.y / parent_scale.y)
	
	get_parent().add_child.call_deferred(object_to_spawn)

func get_chosen_object_type() -> int:
	return chosen_object_type

# Types déjà choisis par les autres spawners de la même pièce
func _get_sibling_chosen_types() -> Array:
	var taken := []
	var parent = get_parent()
	if parent == null:
		return taken
	for child in parent.get_children():
		if child != self and child != null and "chosen_object_type" in child:
			var t: int = child.chosen_object_type
			if t != -1:
				taken.append(t)
	return taken

# Choisit un type d'objet au hasard parmi ceux pas encore proposés
# par les autres spawners. Les _ready des spawners s'exécutent
# séquentiellement (ordre de l'arbre), donc pas de collision possible.
func _pick_unique_type() -> int:
	var taken := _get_sibling_chosen_types()
	var available: Array = PROPOSABLE_TYPES.filter(func(t): return not taken.has(t))
	if available.is_empty():
		# Plus rien de disponible (plus de spawners que d'objets) : au hasard
		return PROPOSABLE_TYPES[randi() % PROPOSABLE_TYPES.size()]
	return available[randi() % available.size()]
