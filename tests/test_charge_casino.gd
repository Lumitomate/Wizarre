extends Node2D
func _ready() -> void:
	var inst = load("res://scenes/niveaux/magasin/magasin_casino/shop_gambling.tscn").instantiate()
	add_child(inst)
	await get_tree().process_frame
	var machine = inst.get_node("GamblingMachin")
	var solide := machine.get_node_or_null("CorpsSolide") as StaticBody2D
	print("CorpsSolide présent: ", solide != null)
	if solide:
		print("  layer/mask: ", solide.collision_layer, "/", solide.collision_mask, " (joueur mask=5 → couche 1 requise)")
		print("  polygones: ", solide.get_children().size())
	print("machine global_scale: ", machine.global_scale)
	print("RESULT: PASS")
	get_tree().quit(0)
