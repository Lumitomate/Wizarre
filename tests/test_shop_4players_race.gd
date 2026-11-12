extends Node
## Test headless du magasin course à 3-4 joueurs — règle de sortie validée :
##  - la porte de sortie est FERMÉE à l'arrivée ;
##  - elle s'ouvre à la PREMIÈRE de ces deux échéances : fin du rituel de
##    la cabine (sort_installe) OU fin des DEUX sabliers — plus
##    d'attente « caisson libre » ;
##  - un seul sablier fini ne suffit pas ;
##  - une fois ouverte, elle ne se referme jamais.
## Deux scénarios sur deux instances fraîches (la sortie, une fois
## ouverte, ne se referme pas). Lancé :
## godot --headless res://tests/test_shop_4players_race.tscn

var inst: Node
var caisson: Cabin
var sorcier: Sorcerer
var step := 0
var _failures := 0
var _scenario := 1


func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _porte_fermee() -> bool:
	var porte: Node = inst.get_node("ShopDoor")
	var zone: CollisionShape2D = porte.get_node("CollisionShape2D")
	return not porte.is_playing() and zone.disabled


func _ready() -> void:
	_charger_scene()


func _charger_scene() -> void:
	var scene: PackedScene = load(
		"res://scenes/niveaux/magasin/magasin_course/shop_4players_race.tscn")
	inst = scene.instantiate()
	add_child(inst)
	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.position = Vector2(4000, 20)
	add_child(sorcier)
	sorcier.load_data()
	caisson = inst.get_node_or_null("Bubble2") as Cabin


func _physics_process(_delta: float) -> void:
	step += 1
	if _scenario == 1:
		_scenario_sabliers()
	else:
		_scenario_rituel()


## Scénario 1 : les DEUX sabliers expirent pendant que le rituel est EN
## COURS — la sortie s'ouvre quand même (première échéance, plus
## d'attente « caisson libre ») ; un seul sablier ne suffit pas.
func _scenario_sabliers() -> void:
	if step == 3:
		_check(caisson != null and not caisson.est_occupee(),
			"le caisson démarre libre")
	if step == 4:
		_check(_porte_fermee(), "la porte de sortie est FERMÉE à l'arrivée")
		caisson.entrer(sorcier)
		_check(caisson.est_occupee(), "le rituel démarre (caisson occupé)")
	if step == 6:
		inst.get_node("Sablier").ecoulement_termine.emit()
	if step == 7:
		_check(_porte_fermee(), "un seul sablier fini ne suffit pas")
		inst.get_node("Sablier2").ecoulement_termine.emit()
		print(">>> fin des deux sabliers pendant le rituel")
	if step == 9:
		_check(inst.get_node("ShopDoor").is_playing(),
			"la sortie s'ouvre à la fin des 2 sabliers, rituel en cours ou pas")
		_fin_scenario()


## Scénario 2 (instance fraîche) : la fin du rituel de la cabine ouvre la
## sortie SANS attendre la fin des sabliers.
func _scenario_rituel() -> void:
	if step == 3:
		_check(_porte_fermee(), "la porte de sortie est FERMÉE à l'arrivée")
	if step == 5:
		# Fin du rituel (attaque installée) — sabliers NON finis (leur
		# écoulement automatique dure 4 s, largement plus loin).
		caisson.sort_installe.emit(sorcier, 0, GlobalEnum.AttackType.L1, 0)
		print(">>> fin du rituel de la cabine")
	if step == 7:
		_check(inst.get_node("ShopDoor").is_playing(),
			"la sortie s'ouvre à la fin du rituel, sabliers non finis")
		_fin_scenario()


func _fin_scenario() -> void:
	inst.queue_free()
	sorcier.queue_free()
	step = 0
	if _scenario == 1:
		_scenario = 2
		_charger_scene()
		return
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)
