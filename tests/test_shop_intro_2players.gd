extends Node
## Test headless du magasin intro à 2 joueurs : deux cabines de types
## différents, et NOUVELLE RÈGLE de sortie — la ShopDoor s'ouvre quand
## les DEUX rituels de cabines sont TERMINÉS (attaques installées), pas
## au passage dans les portes défi ; chaque porte défi s'ouvre à la fin
## de SON rituel. Lancé comme scène :
## godot --headless res://tests/test_shop_intro_2players.tscn

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
	if step == 2:
		# Force le mode 2 joueurs (aucune manette en headless : la scène a
		# démarré en mode 1 joueur). EN STEP 2, pas au _ready : l'objet du
		# bas (spawn différé du spawner) n'a pas encore traversé
		# l'éliminateur au _ready — le débrancher là le laisserait passer et
		# traîner sous la cabine. En step 2, le flush différé de la fin de
		# la première itération a déjà éliminé l'objet. On défait
		# ce que le mode 1 joueur avait branché ; le couloir bas n'était pas
		# actif au _ready : sa cabine n'a reçu aucun branchement, on refait
		# ici celui de la base (sort_installe → porte défi + ShopDoor).
		inst._couloirs_actifs.assign([0, 1])
		inst.get_node("Bubble3").child_entered_tree.disconnect(
			inst._eliminer_objet_bulle2)
		inst.get_node("Bubble3").sort_installe.connect(
			inst._on_cabine_installee.bind(1))
		# L'objet du bas a été éliminé : re-spawn avec son type coordonné
		# (≠ type du haut, règle anti-doublon — il n'a pas été coordonné au
		# _ready, le couloir bas étant alors inactif).
		var spawner_bas: Node = inst.get_node("Bubble3/SpawnerObjet")
		var type_haut_forcage: int = inst.get_node(
			"Bubble2/SpawnerObjet").chosen_object_type
		if spawner_bas.chosen_object_type == type_haut_forcage:
			var libres: Array = spawner_bas.PROPOSABLE_TYPES.filter(
				func(t: int) -> bool: return t != type_haut_forcage)
			spawner_bas.chosen_object_type = libres[randi() % libres.size()]
		spawner_bas.spawn_object()
	if step == 3:
		var type_haut: int = inst.get_node("Bubble2/SpawnerObjet").chosen_object_type
		var type_bas: int = inst.get_node("Bubble3/SpawnerObjet").chosen_object_type
		_check(type_haut != type_bas,
			"types distincts (anti-doublon) : haut=%d bas=%d" % [type_haut, type_bas])
		# Les OBJETS réels aussi (la coordination ne sert à rien si l'objet
		# sous la cabine garde l'ancien type — bug déjà vu : les signaux
		# branchés sur le spawner ne voyaient pas les objets, ajoutés à la
		# cabine).
		var objets: Array = []
		for nom: String in ["Bubble2", "Bubble3"]:
			for c: Node in inst.get_node(nom).get_children():
				if c is AttackObject:
					objets.append(c.item_attack_type)
		var objets_distincts: bool = objets.size() == 2 and objets[0] != objets[1]
		_check(objets_distincts,
			"objets réels distincts sous les 2 cabines : " + str(objets))
	if step == 5:
		# Fin du rituel de la cabine du haut SEULE : la shop ne doit pas
		# s'ouvrir.
		inst.get_node("Bubble2").sort_installe.emit(
			null, 0, GlobalEnum.AttackType.F1, 0)
		print(">>> sort installé (cabine haut, 1/2)")
	if step == 7:
		_check(not inst._shop_ouverte, "shop fermée après 1 rituel/2")
		_check(inst.get_node("PorteMagasinEpreuve").opened,
			"porte défi haut ouverte (son rituel est fini)")
		_check(not inst.get_node("PorteMagasinEpreuve2").opened,
			"porte défi bas encore fermée (rituel bas non fini)")
	if step == 9:
		# Fin du rituel de la cabine du bas : 2/2 → shop ouverte.
		inst.get_node("Bubble3").sort_installe.emit(
			null, 0, GlobalEnum.AttackType.G1, 0)
		print(">>> sort installé (cabine bas, 2/2)")
	if step == 11:
		_check(inst._shop_ouverte, "shop OUVERTE par les 2 fins de rituel")
		_check(inst.get_node("PorteMagasinEpreuve2").opened,
			"porte défi bas ouverte")
		print("=== TEST TERMINÉ ===")
		if failures == 0:
			print("RESULT: PASS")
			get_tree().quit(0)
		else:
			print("RESULT: FAIL (%d)" % failures)
			get_tree().quit(1)
