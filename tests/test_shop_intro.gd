extends Node
## Test headless du magasin intro (2 joueurs, mode 1 joueur headless) :
## scellement à 1 joueur, et NOUVELLE RÈGLE de sortie — c'est la FIN DU
## RITUEL de la cabine (attaque installée, signal sort_installe) qui
## ouvre la ShopDoor (et la porte défi du couloir) ; ni la fermeture de
## la porte de la cabine, ni le passage dans la porte défi ne comptent.
## Lancé comme scène : godot --headless res://tests/test_shop_intro.tscn

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
	var scene: PackedScene = load("res://scenes/niveaux/magasin/magasin_intro/shop_2players_intro.tscn")
	inst = scene.instantiate()
	# Le spawner remonte l'arbre vers un Node2D (racine de scène) : le
	# conteneur de test doit en être un.
	var holder := Node2D.new()
	add_child(holder)
	holder.add_child(inst)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Scellement 1 joueur (0 joueurs actifs en headless → couloir haut seul)
		var tm: TileMapLayer = inst.get_node("TileMapLayer")
		var sells := 0
		for y in range(9, 16):
			for x in range(0, 16):
				if tm.get_cell_atlas_coords(Vector2i(x, y)) == Vector2i(1, 1):
					sells += 1
		_check(sells == 112, "scellement 112/112 blocs")
		var objs: Array[String] = []
		for cabine_nom in ["Bubble2", "Bubble3"]:
			for c: Node in inst.get_node(cabine_nom).get_children():
				if c is AttackObject:
					objs.append(cabine_nom)
		_check(objs == ["Bubble2"],
			"objet sous la cabine haute seule (cabine basse scellée : rien)")
		_check(not inst.get_node("PorteMagasinEpreuve").opened,
			"porte défi haute fermée au départ")
		_check(not inst._shop_ouverte, "shop fermée au départ")
	if step == 6:
		# Fin du rituel de la cabine haute (attaque installée) — signal
		# émis par cabin.gd juste avant la réouverture de ses portes.
		inst.get_node("Bubble2").sort_installe.emit(null, 0, GlobalEnum.AttackType.F1, 0)
		print(">>> sort installé (fin du rituel de la cabine haute)")
	if step == 8:
		_check(inst._shop_ouverte,
			"shop OUVERTE par la fin du rituel (1 couloir actif)")
		_check(inst.get_node("PorteMagasinEpreuve").opened,
			"porte défi haute ouverte par la fin du rituel")
		print("=== TEST TERMINÉ ===")
		if failures == 0:
			print("RESULT: PASS")
			get_tree().quit(0)
		else:
			print("RESULT: FAIL (%d)" % failures)
			get_tree().quit(1)
