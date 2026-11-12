extends Node
## Test headless du magasin intro à 4 joueurs, cas 3 JOUEURS (mode par
## défaut en headless, aucune manette) : couloir bas-droite scellé en
## blocs 1:1 sur (18,10)→(27,15), objet de la cabine 4 éliminé, 3 types
## distincts, et NOUVELLE RÈGLE de sortie — la ShopDoor s'ouvre quand
## les TROIS portes de cabines se sont fermées (sorciers enfermés), pas
## au passage dans les portes défi. Lancé comme scène :
## godot --headless res://tests/test_shop_intro_4players.tscn

var inst: Node
var step := 0
var failures := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		failures += 1


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/niveaux/magasin/magasin_intro/shop_4players_intro.tscn")
	inst = scene.instantiate()
	var holder := Node2D.new()
	add_child(holder)
	holder.add_child(inst)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Scellement : toute la zone (18,10)→(27,15) doit être en bloc 1:1
		var tilemap: TileMapLayer = inst.get_node("TileMapLayer")
		var tous_scelles := true
		for y in range(10, 16):
			for x in range(18, 28):
				if tilemap.get_cell_atlas_coords(Vector2i(x, y)) != Vector2i(1, 1):
					tous_scelles = false
		_check(tous_scelles, "scellement (18,10)→(27,15) en bloc 1:1")
		# La cabine du couloir scellé ne propose rien (objet éliminé)
		var objets_bulle4 := 0
		for c: Node in inst.get_node("Bubble4").get_children():
			if c is AttackObject:
				objets_bulle4 += 1
		_check(objets_bulle4 == 0, "cabine 4 scellée : aucun objet")
		# 3 couloirs actifs, 3 types distincts
		_check(inst._couloirs_actifs == [0, 1, 2],
			"couloirs actifs [0, 1, 2] : " + str(inst._couloirs_actifs))
		var types := []
		for couloir: int in inst._couloirs_actifs:
			types.append(inst._spawner(couloir).chosen_object_type)
		var distincts := true
		for i in types.size():
			for j in range(i + 1, types.size()):
				if types[i] == types[j]:
					distincts = false
		_check(distincts, "3 types distincts : " + str(types))
	if step == 5:
		# Fermeture de la porte de la cabine du couloir 0 SEULE : la shop
		# ne doit pas s'ouvrir.
		inst._cabine(0).porte_fermee.emit()
		print(">>> porte cabine couloir 0 fermée (1/3)")
	if step == 7:
		_check(not inst._shop_ouverte, "shop fermée après 1 fermeture/3")
		inst._cabine(1).porte_fermee.emit()
		print(">>> porte cabine couloir 1 fermée (2/3)")
	if step == 9:
		_check(not inst._shop_ouverte, "shop fermée après 2 fermetures/3")
		inst._cabine(2).porte_fermee.emit()
		print(">>> porte cabine couloir 2 fermée (3/3)")
	if step == 11:
		_check(inst._shop_ouverte, "shop OUVERTE par les 3 fermetures")
		print("=== TEST TERMINÉ ===")
		if failures == 0:
			print("RESULT: PASS")
			get_tree().quit(0)
		else:
			print("RESULT: FAIL (%d)" % failures)
			get_tree().quit(1)
