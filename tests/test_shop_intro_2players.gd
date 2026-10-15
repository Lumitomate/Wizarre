extends Node
## Test headless du magasin intro à 2 joueurs : deux objets de types
## différents, prises des deux couloirs, passages, ouverture de la
## ShopDoor seulement au DERNIER passage. Lancé comme scène :
## godot --headless res://tests/test_shop_intro_2players.tscn

var inst: Node
var step := 0
var sorcier_test: Sorcerer


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/niveaux/magasin/magasin_intro/shop_2players_intro.tscn")
	inst = scene.instantiate()
	var holder := Node2D.new()
	add_child(holder)
	holder.add_child(inst)
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier_test = sorc_scene.instantiate()
	sorcier_test.controller_id = 0
	sorcier_test.load_data()
	holder.add_child(sorcier_test)
	# Force le mode 2 joueurs (aucune manette en headless : la scène a
	# démarré en mode 1 joueur). On défait ce que le mode 1 joueur avait
	# branché : plus d'élimination de l'objet bas, association au couloir.
	inst._couloirs_actifs.assign([0, 1])
	inst.get_node("Bubble2").child_entered_tree.disconnect(inst._eliminer_objet_bulle2)
	inst.get_node("Bubble2").child_entered_tree.connect(inst._on_objet_spawned.bind(1))
	# L'objet du bas a été éliminé au démarrage : re-spawn avec son type
	# coordonné (≠ type du haut, règle anti-doublon).
	inst.get_node("Bubble2/SpawnerObjet").spawn_object()


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		var type_haut: int = inst.get_node("Bubble/SpawnerObjet").chosen_object_type
		var objets_bas: Array = []
		for c: Node in inst.get_node("Bubble2").get_children():
			if c is AttackObject:
				objets_bas.append(c.item_attack_type)
		print("types: haut=", type_haut, " bas=", objets_bas, " (≠ attendus: anti-doublon)")
	if step == 5:
		# Prise de l'objet du haut SEULEMENT : la shop ne doit pas s'ouvrir
		for c: Node in inst.get_node("Bubble").get_children():
			if c is AttackObject:
				c.attrapee.emit(sorcier_test)
		print(">>> objet haut pris")
	if step == 7:
		print("porte dieu haut: ", inst.get_node("PorteMagasinEpreuve").opened, " (true)",
			" | dieu bas: ", inst.get_node("PorteMagasinEpreuve2").opened, " (false)")
		inst._on_zone_passage(sorcier_test, 0)
		print(">>> passage couloir haut (1/2)")
	if step == 9:
		print("shop après 1 passage/2: ", inst._shop_ouverte, " (false attendu)")
	if step == 11:
		# Prise de l'objet du bas + passage
		for c: Node in inst.get_node("Bubble2").get_children():
			if c is AttackObject:
				c.attrapee.emit(sorcier_test)
		inst._on_zone_passage(sorcier_test, 1)
		print(">>> objet bas pris + passage couloir bas (2/2)")
	if step == 13:
		print("porte dieu bas: ", inst.get_node("PorteMagasinEpreuve2").opened, " (true)")
		print("shop après les 2 passages: ", inst._shop_ouverte, " (true attendu)")
		print("=== TEST TERMINÉ ===")
		get_tree().quit()
