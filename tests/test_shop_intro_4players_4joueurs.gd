extends Node
## Test headless du magasin intro à 4 joueurs, cas 4 JOUEURS (mode forcé,
## aucune manette en headless) : les 4 couloirs actifs, 4 types distincts
## (aucun doublon), et ouverture de la ShopDoor seulement au QUATRIÈME
## passage. Lancé comme scène :
## godot --headless res://tests/test_shop_intro_4players_4joueurs.tscn

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
	# Le mode 4 joueurs est forcé PLUS TARD (step 3) : laissé ici, un
	# switch immédiat débrancherait l'éliminateur AVANT que l'objet
	# d'origine (spawn différé du spawner) ne le traverse — le doublon
	# resterait sous la bulle. En step 3, l'objet a déjà été éliminé.


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		# Force le mode 4 joueurs (aucune manette en headless : la scène a
		# démarré en mode 3 joueurs avec scellement). L'objet du couloir
		# bas-droite a été éliminé au démarrage : on défait ce que le mode
		# 3 joueurs avait branché (plus d'élimination, association au
		# couloir 3) et on re-spawn un objet avec son type coordonné
		# (≠ les 3 autres, règle anti-doublon).
		inst._couloirs_actifs.assign([0, 1, 2, 3])
		inst.get_node("Bubble4").child_entered_tree.disconnect(inst._eliminer_objet_bulle4)
		inst.get_node("Bubble4").child_entered_tree.connect(inst._on_objet_spawned.bind(3))
		inst.get_node("Bubble4/SpawnerObjet").spawn_object()
	if step == 5:
		# 4 couloirs actifs, 4 types distincts
		print("couloirs actifs: ", inst._couloirs_actifs, " ([0, 1, 2, 3] attendu)")
		var types := []
		for couloir: int in inst._couloirs_actifs:
			types.append(inst._spawner(couloir).chosen_object_type)
		print("types: ", types, " (4 distincts attendus)")
		var objets_bulle4 := 0
		for c: Node in inst.get_node("Bubble4").get_children():
			if c is AttackObject:
				objets_bulle4 += 1
		print("objets sous bulle 4: ", objets_bulle4, " (1 attendu)")
	if step == 7:
		# Prise + passages des couloirs 0 et 1 : la shop ne doit pas s'ouvrir
		for couloir: int in [0, 1]:
			for c: Node in inst._bulle(couloir).get_children():
				if c is AttackObject:
					c.attrapee.emit(sorcier_test)
			inst._on_zone_passage(sorcier_test, couloir)
		print(">>> couloirs 0 et 1 pris + passés (2/4)")
	if step == 9:
		print("shop après 2 passages/4: ", inst._shop_ouverte, " (false attendu)")
		# Prise + passages des couloirs 2 et 3 (dernier actif)
		for couloir: int in [2, 3]:
			for c: Node in inst._bulle(couloir).get_children():
				if c is AttackObject:
					c.attrapee.emit(sorcier_test)
			inst._on_zone_passage(sorcier_test, couloir)
		print(">>> couloirs 2 et 3 pris + passés (4/4)")
	if step == 11:
		print("shop après les 4 passages: ", inst._shop_ouverte, " (true attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
