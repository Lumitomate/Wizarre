extends Node
## Test headless du bug rapporté : « quand je sors d'un shop, j'ai encore
## un tube soulevé alors qu'ils sont sensés être tous bas ».
##
## Deux vérifications :
##   1. Cabine : un sorcier qui ENTRE avec un tube levé (sélectionné pour
##      attraper un objet) doit ressortir de la cabine avec TOUS ses
##      tuyaux rabattus. Aujourd'hui, le sac masqué pendant le rituel
##      réapparaît avec le tube encore levé — et rien ne le referme plus
##      tard : le timer de fermeture après échange ne concerne que le tube
##      qui a reçu l'échange, pas celui sélectionné par le joueur.
##   2. Sortie du magasin : dès que le fondu de sortie démarre (porte de
##      sortie), les tubes sélectionnés doivent se rabattre.
## Lancé : godot --headless res://tests/test_tube_leve_sortie_shop.tscn

var step := 0
var failures := 0
var sorcier: Sorcerer
var sac: PipeManager
var cabine: Cabin
var _pressed := false
var _positions_tuyaux: Array[Vector2] = []
var _fin_rituel_verifiee := false
var _fin_rituel_step := 0
var _fermeture_verifiee := false
var _step_fermeture := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		failures += 1


## Tous les tuyaux du sac sont au repos : grow_state 0 et frame 0.
func _sac_au_repos() -> bool:
	for i in range(3):
		var p: Pipe = sac.get_tube_node(i)
		if p == null or p.grow_state != 0 or p.anim_sprite.frame != 0:
			return false
	return true


func _ready() -> void:
	# Sol : sans lui, le CharacterBody2D tombe à l'infini.
	var sol := StaticBody2D.new()
	sol.collision_layer = 1
	var forme := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	forme.shape = rect
	forme.position = Vector2(0, 90)
	sol.add_child(forme)
	add_child(sol)

	var scene: PackedScene = load("res://scenes/niveaux/magasin/bubble_cabine.tscn")
	cabine = scene.instantiate()
	cabine.get_node("SpawnerObjet").chosen_object_type = GlobalEnum.AttackType.L2
	cabine.lit_entree = false
	add_child(cabine)

	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	sorcier.in_shop = true
	# Loin de la cabine AVANT add_child (cf. test_cabine.gd)
	sorcier.position = Vector2(400.0, 20.0)
	add_child(sorcier)
	sorcier.global_position = Vector2(400.0, 20.0)
	sac = sorcier.get_node("PipeManager") as PipeManager
	for n: String in ["Pipe Fossil", "Pipe energy", "Pipe tainted"]:
		_positions_tuyaux.append((cabine.get_node(n) as Pipe).position)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 5:
		# Le sorcier soulève son tube 0 (sélection) : il est levé quand
		# il se présente devant la cabine.
		sorcier.select_tube(0)
	if step == 40:
		var p0: Pipe = sac.get_tube_node(0)
		_check(p0.grow_state == 1 and p0.anim_sprite.frame > 0,
			"tube 0 levé avant l'entrée en cabine (grow_state=%d frame=%d)"
				% [p0.grow_state, p0.anim_sprite.frame])
		# Entrée par détection physique réelle (comme test_cabine.gd)
		sorcier.global_position = Vector2(-22.5, 20.0)
	if step == 44:
		_check(cabine.etat == Cabin.Etat.OCCUPIED,
			"le sorcier est enfermé dans la cabine (OCCUPIED)")

	# Choix du tube 2 sur le panneau de la cabine (maintien continu dès
	# que la porte est fermée et les tuyaux sortis) — DÉSALIGNÉ du tube 0
	# levé par le joueur : c'est ce cas qui reste bloqué pour toujours,
	# le timer de fermeture après échange ne visant que le tube qui a
	# reçu l'objet.
	if cabine != null and cabine.etat == Cabin.Etat.OCCUPIED \
			and not _pressed \
			and (cabine.get_node("Pipe tainted") as Pipe).position.y \
					< _positions_tuyaux[2].y - 0.5:
		_pressed = true
		cabine.appui_bouton(2, true)

	# ── Fin du rituel : portes rouvertes, sac réaffiché ─────────────────
	# ── Fin du rituel : portes rouvertes, sac réaffiché ─────────────
	if _pressed and cabine.etat == Cabin.Etat.DONE and sac.visible \
			and not _fin_rituel_verifiee:
		var p0: Pipe = sac.get_tube_node(0)
		print("après la cabine : sac visible=", sac.visible,
			" tube 0 grow_state=", p0.grow_state,
			" frame=", p0.anim_sprite.frame,
			" selected_tube=", sorcier.selected_tube)
		_check(sorcier.selected_tube == -1,
			"cabine : aucun tube sélectionné à la sortie du rituel")
		_check(_sac_au_repos(),
			"cabine : à la sortie du rituel, tous les tuyaux du sorcier sont rabattus")
		_fin_rituel_verifiee = true
		_fin_rituel_step = step
	# ── Seam de fermeture forcée (portes de sortie, etc.) ───────────
	if _fin_rituel_verifiee and not _fermeture_verifiee \
			and step - _fin_rituel_step > 5:
		_fermeture_verifiee = true
		sorcier.select_tube(1)
		var p1: Pipe = sac.get_tube_node(1)
		_check(p1.grow_state == 1, "tube 1 soulevé pour le test de fermeture")
		sorcier.fermer_tube_selectionne()
		_check(sorcier.selected_tube == -1,
			"fermer_tube_selectionne() désélectionne le tube")
		_step_fermeture = step
	# L'anim de refermeture (~16 frames à 24 fps) doit terminer à l'idle
	if _step_fermeture > 0 and step - _step_fermeture > 40:
		_check(_sac_au_repos(),
			"fermer_tube_selectionne() rabat le tube soulevé")
		print("=== TEST TERMINÉ ===")
		get_tree().quit(1 if failures > 0 else 0)
	if step > 1800:
		print("FAIL: timeout (cabine bloquée dans l'état ", cabine.etat, ")")
		failures += 1
		get_tree().quit(1)
