extends Node
## Test headless du magasin intro à 2 joueurs : deux cabines de types
## différents, et NOUVELLE RÈGLE de sortie — la ShopDoor s'ouvre quand
## les DEUX portes de cabines se sont fermées (sorciers enfermés), pas
## au passage dans les portes défi ; les portes dieu ne s'ouvrent qu'à
## la fin des rituels (sorts installés). Lancé comme scène :
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
	# Force le mode 2 joueurs (aucune manette en headless : la scène a
	# démarré en mode 1 joueur). On défait ce que le mode 1 joueur avait
	# branché : plus d'élimination de l'objet bas. Le couloir bas n'était
	# pas actif au _ready : sa cabine n'a reçu aucun branchement, on
	# refait ici ceux de la base (porte_fermee → ShopDoor, sort_installe
	# → porte dieu).
	inst._couloirs_actifs.assign([0, 1])
	inst.get_node("Bubble3").child_entered_tree.disconnect(inst._eliminer_objet_bulle2)
	inst.get_node("Bubble3").porte_fermee.connect(inst._on_cabine_porte_fermee.bind(1))
	inst.get_node("Bubble3").sort_installe.connect(inst._on_cabine_installee.bind(1))
	# L'objet du bas a été éliminé au démarrage : re-spawn avec son type
	# coordonné (≠ type du haut, règle anti-doublon).
	inst.get_node("Bubble3/SpawnerObjet").spawn_object()


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 3:
		var type_haut: int = inst.get_node("Bubble2/SpawnerObjet").chosen_object_type
		var type_bas: int = inst.get_node("Bubble3/SpawnerObjet").chosen_object_type
		_check(type_haut != type_bas,
			"types distincts (anti-doublon) : haut=%d bas=%d" % [type_haut, type_bas])
	if step == 5:
		# La porte de la cabine du haut se referme SEULE : la shop ne doit
		# pas s'ouvrir.
		inst.get_node("Bubble2").porte_fermee.emit()
		print(">>> porte cabine haut fermée (1/2)")
	if step == 7:
		_check(not inst._shop_ouverte, "shop fermée après 1 fermeture/2")
		_check(not inst.get_node("PorteMagasinEpreuve").opened,
			"porte dieu haut encore fermée (le rituel n'est pas fini)")
	if step == 9:
		# La porte de la cabine du bas se referme : 2/2 → shop ouverte.
		inst.get_node("Bubble3").porte_fermee.emit()
		print(">>> porte cabine bas fermée (2/2)")
	if step == 11:
		_check(inst._shop_ouverte, "shop OUVERTE par les 2 fermetures")
	if step == 13:
		# Les portes dieu s'ouvrent à la FIN des rituels, pas avant.
		inst.get_node("Bubble2").sort_installe.emit(null, 0, GlobalEnum.AttackType.F1, 0)
		inst.get_node("Bubble3").sort_installe.emit(null, 0, GlobalEnum.AttackType.G1, 0)
		print(">>> sorts installés (fin des rituels)")
	if step == 15:
		_check(inst.get_node("PorteMagasinEpreuve").opened, "porte dieu haut ouverte")
		_check(inst.get_node("PorteMagasinEpreuve2").opened, "porte dieu bas ouverte")
		print("=== TEST TERMINÉ ===")
		if failures == 0:
			print("RESULT: PASS")
			get_tree().quit(0)
		else:
			print("RESULT: FAIL (%d)" % failures)
			get_tree().quit(1)
