extends Node
## Test headless du magasin course à 2 joueurs après remplacement de la
## bulle de verre par la cabine, et après la nouvelle règle de sortie :
##  - la porte de sortie est FERMÉE à l'arrivée ;
##  - elle ne s'ouvre qu'à la fin du sablier ET si le caisson est libre ;
##  - si le sablier se termine pendant que le caisson est occupé, elle
##    attend qu'il se libère.
## Lancé : godot --headless res://tests/test_shop_2players_race.tscn

var inst: Node
var caisson: Cabin
var sorcier: Sorcerer
var step := 0
var _failures := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _ready() -> void:
	var scene: PackedScene = load(
		"res://scenes/niveaux/magasin/magasin_course/shop_2players_race.tscn")
	inst = scene.instantiate()
	add_child(inst)

	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.position = Vector2(4000, 20)
	add_child(sorcier)
	sorcier.load_data()


func _physics_process(_delta: float) -> void:
	step += 1
	var porte := inst.get_node("ShopDoor")
	var zone := porte.get_node("Area2D/CollisionShape2D") as CollisionShape2D
	caisson = inst.get_node_or_null("Bubble2") as Cabin

	if step == 3:
		_check(caisson != null and caisson.etat == Cabin.Etat.ACTIVE
				and not caisson.est_occupee(),
			"le caisson démarre libre (ACTIVE)")
		if caisson != null:
			var objet := _trouver_objet(caisson)
			_check(objet != null and objet.capturable == false,
				"le caisson porte un objet intrapable")

	if step == 4:
		_check(not porte.is_playing() and zone.disabled,
			"la porte de sortie est FERMÉE à l'arrivée")
		# Le caisson est occupé pendant toute la suite du test.
		caisson.entrer(sorcier)
		_check(caisson.est_occupee(), "le caisson est occupé")

	if step == 6:
		# Fin du sablier pendant que le caisson est occupé.
		inst.get_node("Sablier").ecoulement_termine.emit()

	if step == 14:
		_check(not porte.is_playing() and zone.disabled,
			"la porte reste fermée tant que le caisson est occupé")
		# Le sorcier ressort du caisson.
		caisson.etat = Cabin.Etat.INERT
		_check(not caisson.est_occupee(), "le caisson est libéré")

	if step == 18:
		_check(porte.is_playing(),
			"la porte s'ouvre dès que le caisson se libère")

	if step == 200:
		_check(not zone.disabled, "la porte de sortie est devenue franchissable")
		if _failures == 0:
			print("RESULT: PASS")
			get_tree().quit(0)
		else:
			print("RESULT: FAIL (%d)" % _failures)
			get_tree().quit(1)


func _trouver_objet(cabine: Node) -> AttackObject:
	for c in cabine.get_children():
		if c is AttackObject:
			return c
	return null
