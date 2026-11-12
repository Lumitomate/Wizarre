extends Node
## Test headless du magasin intro à 4 joueurs, cas 4 JOUEURS (mode forcé,
## aucune manette en headless) : les 4 couloirs actifs, 4 types distincts
## (aucun doublon), et NOUVELLE RÈGLE de sortie — la ShopDoor s'ouvre
## quand les QUATRE rituels de cabines sont TERMINÉS (attaques
## installées), pas au passage dans les portes défi. Lancé comme scène :
## godot --headless res://tests/test_shop_intro_4players_4joueurs.tscn

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
	# Le mode 4 joueurs est forcé PLUS TARD (step 3) : laissé ici, un
	# switch immédiat débrancherait l'éliminateur AVANT que l'objet
	# d'origine (spawn différé du spawner) ne le traverse — le doublon
	# resterait sous la cabine. En step 3, l'objet a déjà été éliminé.


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
		# Le couloir 3 n'était pas actif au _ready : sa cabine n'a reçu
		# aucun branchement, on refait ici celui de la base (sort_installe
		# → porte défi + ShopDoor).
		inst.get_node("Bubble4").sort_installe.connect(inst._on_cabine_installee.bind(3))
		# Le spawner de la cabine 4 n'a pas été coordonné au _ready (couloir
		# alors inactif) : on lui assigne ici un type ≠ des 3 autres, comme
		# le ferait _coordonner_types_objets si les 4 couloirs avaient été
		# actifs dès le départ. Sans cela, le type re-spawné est un tirage
		# au hasard qui peut DOUBLER un type déjà posé (déjà observé).
		var spawner4: Node = inst.get_node("Bubble4/SpawnerObjet")
		var deja_pris: Array = []
		for couloir: int in [0, 1, 2]:
			deja_pris.append(inst._spawner(couloir).chosen_object_type)
		var libres: Array = spawner4.PROPOSABLE_TYPES.filter(
			func(t: int) -> bool: return t not in deja_pris)
		spawner4.chosen_object_type = libres[randi() % libres.size()]
		spawner4.spawn_object()
	if step == 5:
		# 4 couloirs actifs, 4 types distincts
		_check(inst._couloirs_actifs == [0, 1, 2, 3], "couloirs actifs [0, 1, 2, 3]")
		var types := []
		for couloir: int in inst._couloirs_actifs:
			types.append(inst._spawner(couloir).chosen_object_type)
		var distincts := true
		for i in types.size():
			for j in range(i + 1, types.size()):
				if types[i] == types[j]:
					distincts = false
		_check(distincts, "4 types distincts (règle anti-doublon) : " + str(types))
		var objets_bulle4 := 0
		for c: Node in inst.get_node("Bubble4").get_children():
			if c is AttackObject:
				objets_bulle4 += 1
		_check(objets_bulle4 == 1, "objet sous la cabine 4 (1 attendu)")
	if step == 7:
		# Fins de rituel des cabines des couloirs 0 et 1 : la shop ne doit
		# pas s'ouvrir.
		for couloir: int in [0, 1]:
			inst._cabine(couloir).sort_installe.emit(null, 0, GlobalEnum.AttackType.F1, 0)
		print(">>> rituels cabines couloirs 0 et 1 terminés (2/4)")
	if step == 9:
		_check(not inst._shop_ouverte, "shop fermée après 2 rituels/4")
		# Fins de rituel des couloirs 2 et 3 (dernier actif)
		for couloir: int in [2, 3]:
			inst._cabine(couloir).sort_installe.emit(null, 0, GlobalEnum.AttackType.G1, 0)
		print(">>> rituels cabines couloirs 2 et 3 terminés (4/4)")
	if step == 11:
		_check(inst._shop_ouverte, "shop ouverte après les 4 fins de rituel")
		print("=== TEST TERMINÉ ===")
		if failures == 0:
			print("RESULT: PASS")
			get_tree().quit(0)
		else:
			print("RESULT: FAIL (%d)" % failures)
			get_tree().quit(1)
