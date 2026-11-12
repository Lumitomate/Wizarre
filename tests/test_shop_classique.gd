extends Node
## Test headless du magasin classique converti aux cabines : les 3
## fixtures sont des cabines (Cabin) tenant chacune un objet de type
## DISTINCT, et la règle « UN SEUL OBJET PAR VISITE » — dès qu'un
## sorcier entre dans une cabine, les deux autres sont scellées (objet
## retiré, entrée bloquée, porte refermée avec son animation).
## Lancé : godot --headless res://tests/test_shop_classique.tscn

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
	var scene: PackedScene = load("res://scenes/niveaux/magasin/magasin_classique/shop.tscn")
	inst = scene.instantiate()
	var holder := Node2D.new()
	add_child(holder)
	holder.add_child(inst)


func _porte_fermee(cabine: Cabin) -> bool:
	var porte: AnimatedSprite2D = cabine.get_node("AnimatedSprite2D_porte")
	var derniere := porte.sprite_frames.get_frame_count(porte.animation) - 1
	return not porte.is_playing() and porte.frame >= derniere


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 5:
		# 3 cabines, chacune avec son objet, tous les types DISTINCTS
		# (coordination de l'hôte : les spawners internes ne se voient pas).
		var cabines: Array = inst._cabines()
		var trois := true
		for cabine: Cabin in cabines:
			if not (cabine is Cabin):
				trois = false
		_check(trois, "3 fixtures = Cabin")
		var types := []
		for cabine: Cabin in cabines:
			var objet_trouve := false
			for c: Node in cabine.get_children():
				if c is AttackObject:
					objet_trouve = true
					types.append(c.item_attack_type)
			_check(objet_trouve, "cabine avec objet spawné")
		var distincts := true
		for i in types.size():
			for j in range(i + 1, types.size()):
				if types[i] == types[j]:
					distincts = false
		_check(distincts, "types distincts entre les 3 cabines : " + str(types))
		# Aucune cabine scellée avant la première entrée.
		var inertes := 0
		for cabine: Cabin in cabines:
			if cabine.est_inerte():
				inertes += 1
		_check(inertes == 0, "aucune cabine inerte avant la première entrée")
		# Règle « un seul objet par visite » : entrée dans la cabine 0
		# (signal émis par cabin.entrer ; simulation du branchement).
		print(">>> entrée du sorcier dans la cabine 0")
		cabines[0].sorcier_entre.emit(null)
	if step == 9:
		# La fermeture est ANIMÉE, pas instantanée : 2 ticks après le
		# scellement, la porte ne peut pas avoir atteint sa dernière frame
		# (l'anim dure 1 s — insensible à la charge, contrairement à un
		# check « en cours » à un step fixe, fragile en parallèle).
		for nom: String in ["Cabine2", "Cabine3"]:
			var cabine: Cabin = inst.get_node(nom)
			_check(not _porte_fermee(cabine),
				nom + " : fermeture ANIMÉE (pas déjà fermée 2 ticks après)")
		# Règle de sortie : rituel en cours → la sortie se referme.
		var sortie: Node = inst.get_node("ShopDoor")
		var zone_sortie: CollisionShape2D = sortie.get_node("CollisionShape2D")
		_check(zone_sortie.disabled and not sortie.is_playing(),
			"la sortie est FERMÉE pendant le rituel")
	if step == 7:
		# Les deux autres cabines sont scellées TÔT (dès l'entrée) :
		# inertes, entrée coupée, verrouillées, porte en cours de fermeture.
		for nom: String in ["Cabine2", "Cabine3"]:
			var cabine: Cabin = inst.get_node(nom)
			_check(cabine.est_inerte(), nom + " inerte (objet retiré)")
			_check(cabine.verrouillee, nom + " verrouillée")
			_check(not cabine.get_node("ZoneEntree").monitoring,
				nom + " : détection d'entrée coupée")
		# La cabine occupée garde son objet (le rituel se poursuit).
		_check(not inst.get_node("Cabine").est_inerte(),
			"cabine 0 : objet conservé (rituel en cours)")
	if step == 25:
		# Les murs générés bloquent déjà l'entrée pendant la fermeture.
		for nom: String in ["Cabine2", "Cabine3"]:
			var cabine: Cabin = inst.get_node(nom)
			var mur: CollisionShape2D = cabine.get_node("Murs").get_child(0).get_child(0)
			_check(not mur.disabled, nom + " : murs actifs")
	if step == 70:
		# Les animations de fermeture ont atteint la porte fermée.
		for nom: String in ["Cabine2", "Cabine3"]:
			var cabine: Cabin = inst.get_node(nom)
			_check(_porte_fermee(cabine), nom + " : porte fermée (fin d'animation)")
		# Le sorcier a fini son rituel et ressorti : la sortie se rouvre.
		inst._cabines()[0].sorcier_sorti.emit(null)
		print(">>> sorcier ressorti")
	if step == 72:
		var sortie: Node = inst.get_node("ShopDoor")
		_check(sortie.is_playing(),
			"la sortie se ROUVRE dès que le sorcier ressort")
	if step == 72:
		if failures == 0:
			print("RESULT: PASS")
			get_tree().quit(0)
		else:
			print("RESULT: FAIL (%d)" % failures)
			get_tree().quit(1)
