extends Node
## Test headless du magasin intro à 4 joueurs, cas 3 JOUEURS (mode par
## défaut en headless, aucune manette) : couloir bas-droite scellé en
## blocs 1:1 sur (18,10)→(27,15), objet de la bulle 4 éliminé, 3 types
## distincts, et ouverture de la ShopDoor seulement au TROISIÈME passage.
## Lancé comme scène : godot --headless res://tests/test_shop_intro_4players.tscn

var inst: Node
var step := 0
var sorcier_test: Sorcerer


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/niveaux/magasin/magasin_intro/shop_4players_intro.tscn")
	inst = scene.instantiate()
	var holder := Node2D.new()
	add_child(holder)
	holder.add_child(inst)
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier_test = sorc_scene.instantiate()
	sorcier_test.controller_id = 0
	sorcier_test.load_data()
	holder.add_child(sorcier_test)


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
		print("scellement (18,10)->(27,15) en bloc 1:1: ", tous_scelles, " (true attendu)")
		# La bulle du couloir scellé ne propose rien (objet éliminé)
		var objets_bulle4: Array = []
		for c: Node in inst.get_node("Bubble4").get_children():
			if c is AttackObject:
				objets_bulle4.append(c)
		print("objets sous bulle 4 scellée: ", objets_bulle4.size(), " (0 attendu)")
		# 3 couloirs actifs, 3 types distincts
		print("couloirs actifs: ", inst._couloirs_actifs, " ([0, 1, 2] attendu)")
		var types := []
		for couloir: int in inst._couloirs_actifs:
			types.append(inst._spawner(couloir).chosen_object_type)
		print("types: ", types, " (3 distincts attendus)")
	if step == 5:
		# Prise de l'objet du couloir 0 SEULEMENT : la shop ne doit pas s'ouvrir
		for c: Node in inst._bulle(0).get_children():
			if c is AttackObject:
				c.attrapee.emit(sorcier_test)
		inst._on_zone_passage(sorcier_test, 0)
		print(">>> objet couloir 0 pris + passage (1/3)")
	if step == 7:
		print("shop après 1 passage/3: ", inst._shop_ouverte, " (false attendu)")
		# Prise + passage couloir 1
		for c: Node in inst._bulle(1).get_children():
			if c is AttackObject:
				c.attrapee.emit(sorcier_test)
		inst._on_zone_passage(sorcier_test, 1)
		print(">>> objet couloir 1 pris + passage (2/3)")
	if step == 9:
		print("shop après 2 passages/3: ", inst._shop_ouverte, " (false attendu)")
		# Prise + passage couloir 2 (dernier actif)
		for c: Node in inst._bulle(2).get_children():
			if c is AttackObject:
				c.attrapee.emit(sorcier_test)
		inst._on_zone_passage(sorcier_test, 2)
		print(">>> objet couloir 2 pris + passage (3/3)")
	if step == 11:
		print("shop après les 3 passages: ", inst._shop_ouverte, " (true attendu)")
		# Le passage du couloir SCELLÉ ne doit rien changer (garde-fou)
		inst._on_zone_passage(sorcier_test, 3)
		print("passage couloir scellé ignoré: ", not inst._passages.has(3), " (true attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
