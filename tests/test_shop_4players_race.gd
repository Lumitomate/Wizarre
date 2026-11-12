extends Node
## Test headless du magasin course à 3-4 joueurs — règle de sortie validée
## (comme la course 2 joueurs) :
##  - la porte de sortie est FERMÉE à l'arrivée ;
##  - elle s'ouvre à la PREMIÈRE de ces deux échéances : fin du rituel de
##    la cabine (sort_installe) OU fermeture TOTALE de la porte défi
##    (descente démarrée à la fin du PREMIER des 2 sabliers, qui
##    tournent en parallèle) ;
##  - si un joueur dash sous la porte pendant la descente, elle se
##    réouvre pour de bon et ne se refermera JAMAIS : la sortie attend
##    alors la fin du rituel (jamais d'ouverture avant).
## Trois scénarios sur trois instances fraîches (la sortie, une fois
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
	match _scenario:
		1: _scenario_descente()
		2: _scenario_rituel()
		3: _scenario_dash()


## Scénario 1 : descente normale — personne ne passe, la porte défi
## touche le sol et la sortie s'ouvre (rituel en cours ou pas).
func _scenario_descente() -> void:
	if step == 3:
		_check(caisson != null and not caisson.est_occupee(),
			"le caisson démarre libre")
	if step == 4:
		_check(_porte_fermee(), "la porte de sortie est FERMÉE à l'arrivée")
		caisson.entrer(sorcier)
		_check(caisson.est_occupee(), "le rituel démarre (caisson occupé)")
	if step == 6:
		inst.get_node("Sablier").ecoulement_termine.emit()
		print(">>> fin du premier sablier : descente de la porte défi")
	if step == 8:
		_check(_porte_fermee(), "la sortie attend la descente complète")
	if step == 120:
		# Descente de la porte défi : ~20 frames à 12 fps ≈ 1,7 s ≈ 100
		# frames physiques — la porte a touché le sol.
		_check(inst.get_node("ShopDoor").is_playing(),
			"la sortie s'ouvre à la fermeture TOTALE de la porte défi")
		_fin_scenario()


## Scénario 2 : la fin du rituel ouvre la sortie SANS attendre le sablier.
func _scenario_rituel() -> void:
	if step == 3:
		_check(_porte_fermee(), "la porte de sortie est FERMÉE à l'arrivée")
	if step == 5:
		caisson.sort_installe.emit(sorcier, 0, GlobalEnum.AttackType.L1, 0)
		print(">>> fin du rituel de la cabine")
	if step == 7:
		_check(inst.get_node("ShopDoor").is_playing(),
			"la sortie s'ouvre à la fin du rituel, sabliers non finis")
		_fin_scenario()


## Scénario 3 (LE BUG RAPPORTÉ) : un joueur dash sous la porte défi
## pendant sa descente → elle se réouvre pour de bon et ne se refermera
## JAMAIS → la sortie ne doit PAS s'ouvrir à ce moment ; elle attend la
## fin du rituel.
func _scenario_dash() -> void:
	if step == 3:
		_check(_porte_fermee(), "la porte de sortie est FERMÉE à l'arrivée")
	if step == 4:
		inst.get_node("Sablier").ecoulement_termine.emit()
		print(">>> fin du premier sablier : descente de la porte défi")
	if step == 6:
		# Le dash : un joueur passe pendant la descente → réouverture
		# définitive (la porte ne touchera jamais le sol).
		inst.get_node("PorteMagasinEpreuve").deverrouiller()
		print(">>> dash sous la porte défi pendant la descente")
	if step == 8:
		inst.get_node("Sablier2").ecoulement_termine.emit()
		print(">>> fin du second sablier (sans effet : porte déverrouillée)")
	if step == 120:
		# La descente (≈1,7 s) est largement écoulée : la porte ne s'est
		# JAMAIS refermée, la sortie doit toujours être fermée.
		_check(_porte_fermee(),
			"la sortie ne s'ouvre PAS : la porte défi ne s'est jamais refermée")
	if step == 122:
		caisson.sort_installe.emit(sorcier, 0, GlobalEnum.AttackType.G1, 0)
		print(">>> fin du rituel de la cabine")
	if step == 124:
		_check(inst.get_node("ShopDoor").is_playing(),
			"la sortie s'ouvre à la fin du rituel (seule échéance restante)")
		_fin_scenario()


func _fin_scenario() -> void:
	inst.queue_free()
	sorcier.queue_free()
	step = 0
	if _scenario < 3:
		_scenario += 1
		_charger_scene()
		return
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures)
		get_tree().quit(1)
