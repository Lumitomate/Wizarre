extends Node
## Test headless du magasin intro : scellement à 1 joueur, prise d'objet,
## ouverture porte dieu, passage ZonePassage, ouverture ShopDoor (garde-fou
## compris). Lancé comme scène : godot --headless res://tests/test_shop_intro.tscn

var inst: Node
var step := 0
var sorcier_test: Sorcerer


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/niveaux/magasin/magasin_intro/shop_2players_intro.tscn")
	inst = scene.instantiate()
	# Le spawner remonte l'arbre vers un Node2D (racine de scène) : le
	# conteneur de test doit en être un.
	var holder := Node2D.new()
	add_child(holder)
	holder.add_child(inst)
	# Sorcier de test pour les simulis de passage (le garde-fou exige un
	# Sorcerer réel).
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier_test = sorc_scene.instantiate()
	sorcier_test.controller_id = 0
	# Même ordre que PlayerManager.spawn_player : données chargées AVANT
	# l'entrée dans l'arbre (le sac les lit dans son _ready).
	sorcier_test.load_data()
	holder.add_child(sorcier_test)


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
		print("scellement: ", sells, "/112 blocs (attendu 112)")
		var objs: Array[String] = []
		for bubble_name in ["Bubble", "Bubble2"]:
			for c: Node in inst.get_node(bubble_name).get_children():
				if c is AttackObject:
					objs.append(bubble_name)
		print("objets sous bulles: ", objs, " (['Bubble'] attendu à 1 joueur: objet bas éliminé)")
		print("porte dieu haut ouverte: ", inst.get_node("PorteMagasinEpreuve").opened, " (false attendu)")
	if step == 6:
		# Simule la prise de l'objet du couloir haut
		for c: Node in inst.get_node("Bubble").get_children():
			if c is AttackObject:
				c.attrapee.emit(null)
				print(">>> objet haut pris")
	if step == 8:
		print("porte dieu ouverte après prise: ", inst.get_node("PorteMagasinEpreuve").opened, " (true attendu)")
		inst._on_zone_passage(sorcier_test, 0)
		print(">>> passage couloir haut simulé")
	if step == 10:
		print("shop ouverte après passage: ", inst._shop_ouverte, " (true attendu: 1 couloir actif)")
		# Garde-fou : un passage SANS prise ne doit rien déclencher
		inst._shop_ouverte = false
		inst._passages.clear()
		inst._objets_pris.clear()
		inst._on_zone_passage(sorcier_test, 0)
		print("passage sans prise → shop: ", inst._shop_ouverte, " (false attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
