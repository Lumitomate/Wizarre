extends Node
## Test de migration du magasin intro 4 joueurs : les 4 fixtures des
## couloirs (Bubble, Bubble2, Bubble3, Bubble4) sont des CABINES
## (instances de bubble_cabine.tscn, script cabin.gd) — plus de bulle de
## verre inline dans cette scène (migration cabine, cf. tickets/002).
## Chaque cabine active contient bien son objet spawné, et la cabine du
## couloir scellé (3 joueurs headless) n'en contient pas.
## Lancé : godot --headless res://tests/test_shop_intro_bulle_contact.tscn

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


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 5:
		# Les 4 fixtures sont des cabines (class_name Cabin).
		var fixtures := ["Bubble", "Bubble2", "Bubble3", "Bubble4"]
		for nom: String in fixtures:
			var fixture: Node2D = inst.get_node(nom)
			_check(fixture is Cabin, nom + " est une cabine (Cabin)")
			_check(fixture.get_node_or_null("SpawnerObjet") != null,
				nom + " contient son SpawnerObjet")
			_check(fixture.get_node_or_null("ZoneContact") == null,
				nom + " n'a plus de ZoneContact (bulle de verre retirée)")
		# Chaque cabine de couloir ACTIF contient son objet spawné ;
		# la cabine du couloir scellé (3 joueurs headless) n'en a pas.
		for couloir: int in inst._couloirs_actifs:
			var objet_trouve := false
			for c: Node in inst._bulle(couloir).get_children():
				if c is AttackObject:
					objet_trouve = true
			_check(objet_trouve,
				"cabine du couloir %d : objet spawné" % couloir)
		var objet_bulle4 := false
		for c: Node in inst.get_node("Bubble4").get_children():
			if c is AttackObject:
				objet_bulle4 = true
		_check(not objet_bulle4, "cabine 4 scellée : aucun objet")
	if step == 7:
		if failures == 0:
			print("RESULT: PASS")
			get_tree().quit(0)
		else:
			print("RESULT: FAIL (%d)" % failures)
			get_tree().quit(1)
