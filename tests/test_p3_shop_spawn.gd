extends Node

# Test runtime : instancie le vrai magasin et vérifie que les objets
# d'attaque (dont potentiellement P3) spawn correctement.

var _frames := 0

func _ready() -> void:
	var shop: Node = load("res://scenes/niveaux/magasin/shop.tscn").instantiate()
	add_child(shop)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 10:
		return
	var objects := []
	_collect_objects(self, objects)
	var types := {}
	for obj in objects:
		var t: int = obj.item_attack_type
		types[GlobalEnum.AttackType.keys()[t]] = types.get(GlobalEnum.AttackType.keys()[t], 0) + 1
	print("OBJETS SPAWNES: %d -> %s" % [objects.size(), types])
	if objects.is_empty():
		print("RESULT: FAIL (aucun objet spawné)")
		get_tree().quit(1)
	else:
		print("RESULT: PASS")
		get_tree().quit(0)

func _collect_objects(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is AttackObject:
			out.append(child)
		_collect_objects(child, out)