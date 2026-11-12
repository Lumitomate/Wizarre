extends Node
## Test headless de la cabine (Cabin) : remplace la bulle de verre.
## Vérifie, en pilotant la cabine par ses seams (entrer / appui_bouton) :
##  - l'objet est intrapable (lévitation conservée) ;
##  - un sorcier qui entre est enfermé ; les tuyaux sortent SEULEMENT une
##    fois la porte fermée, de gauche à droite, et le panneau apparaît ;
##  - tant que la porte n'est pas fermée, les appuis ne font rien ;
##  - une lumière maintenue jusqu'au bout verrouille le choix ;
##  - explosion + sortie du tuyau, puis le bras installe le sort :
##    set_attack RÉEL, signal sort_installe, cabine inerte ensuite ;
##  - une cabine sans objet est inerte (entrer ne fait rien) ;
##  - une cabine VERROUILLÉE est fermée de base (porte fermée, entrée
##    refusée) jusqu'à ouvrir(), qui ouvre les portes tout de suite.
## Lancé : godot --headless res://tests/test_cabine.tscn
##
## Le test est PILOTÉ PAR ÉVÉNEMENTS (porte fermée, état CONFIRMING,
## explosion passée, état DONE/INERT) et non par des numéros de frame :
## les tweens et animations utilisent le temps « idle », qui n'avance pas
## au même rythme que _physics_process en headless.

var inst: Cabin
var inst_vide: Cabin
var sorcier: Sorcerer

var step := 0
var _failures := 0
var _positions_tuyaux: Array[Vector2] = []
var _objet: AttackObject = null

var _pressed := false
var _press_step := 0
var _lumiere_verifie := false
var _ordre_verifie := false
var _confirme_verifie := false
var _objet_verifie := false
var _retract_verifie := false
var _done_verifie := false
var _inert_verifie := false
var _fade_verifie := false

# Scénario « cabine verrouillée » (fermée de base, ouvrir()).
var inst_verrou: Cabin
var _verrou_ferme_verifie := false
var _verrou_ouvert_verifie := false
var _verrou_occup_verifie := false

var _signal_recu := false
var _signal_tube := -1
var _signal_type := -1


func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _tuyau(i: int) -> Node2D:
	return [inst.get_node("Pipe Fossil"), inst.get_node("Pipe energy"),
		inst.get_node("Pipe tainted")][i] as Node2D


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

	var scene: PackedScene = load("res://scenes/niveaux/magasin/bubble2.tscn")
	inst = scene.instantiate()
	# Type d'objet forcé AVANT le _ready du spawner (sinon tirage aléatoire).
	inst.get_node("SpawnerObjet").chosen_object_type = GlobalEnum.AttackType.L2
	inst.lit_entree = false
	add_child(inst)

	# Deuxième cabine, privée de son objet, assez loin pour ne pas capter
	# le sorcier de test.
	inst_vide = scene.instantiate()
	inst_vide.get_node("SpawnerObjet").chosen_object_type = GlobalEnum.AttackType.L2
	inst_vide.lit_entree = false
	inst_vide.position = Vector2(2000, 0)
	add_child(inst_vide)

	# Troisième cabine, VERROUILLÉE (fermée de base, comme le montage du
	# magasin reflex), loin de tout pour ne rien capter.
	inst_verrou = scene.instantiate()
	inst_verrou.get_node("SpawnerObjet").chosen_object_type = GlobalEnum.AttackType.L2
	inst_verrou.lit_entree = false
	inst_verrou.verrouillee = true
	inst_verrou.position = Vector2(3000, 0)
	add_child(inst_verrou)

	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	sorcier.in_shop = true
	# Position loin de la cabine AVANT add_child : le corps physique est
	# enregistré ici (sinon il l'est à (0,0), qui chevauche le seuil).
	sorcier.position = Vector2(400.0, 20.0)
	add_child(sorcier)
	# APRÈS add_child : le _ready du sorcier recharge les sorts sauvegardés.
	sorcier.spells = {
		0: {"attack_type": GlobalEnum.AttackType.F1, "attack_tier": 0},
		1: {},
		2: {"attack_type": GlobalEnum.AttackType.G1, "attack_tier": 0},
	}
	sorcier.energy_counts = [1, 2, 3]
	sorcier.global_position = Vector2(400.0, 20.0)

	inst.sort_installe.connect(func(_s: Sorcerer, tube: int, type: int, tier: int) -> void:
		_signal_recu = true
		_signal_tube = tube
		_signal_type = type)


func _physics_process(_delta: float) -> void:
	step += 1
	var porte := inst.get_node("AnimatedSprite2D_porte") as AnimatedSprite2D
	var explosion := inst.get_node("AnimatedSprite2D_explosion") as AnimatedSprite2D

	# --- Mise en place ---
	if step == 3:
		_objet = _trouver_objet(inst)
		_check(_objet != null, "l'objet de la cabine a été posé")
		_check(_objet != null and _objet.capturable == false,
			"l'objet de la cabine est intrapable")
		for i in range(3):
			_positions_tuyaux.append(_tuyau(i).position)
		var vide := _trouver_objet(inst_vide)
		if vide != null:
			vide.queue_free()

	if step == 6:
		_check(inst.etat == Cabin.Etat.ACTIVE, "cabine ACTIVE avant entrée")
		var lueurs_vides := true
		for n in ["BoutonsLumiere/BoutonLumiere_fossil", "BoutonsLumiere/BoutonLumiere_energy",
				"BoutonsLumiere/BoutonLumiere_tainted"]:
			if (inst.get_node(n) as AnimatedSprite2D).frame != 0:
				lueurs_vides = false
		_check(lueurs_vides, "les 3 lumières démarrent sur la frame vide")
		_check(porte.z_index == 0,
			"porte au z_index de base tant que le sorcier n'est pas dedans")

	# --- Entrée par détection physique réelle ---
	if step == 8:
		sorcier.global_position = Vector2(-22.5, 20.0)

	if step == 12:
		_check(inst.etat == Cabin.Etat.OCCUPIED,
			"la détection physique fait entrer le sorcier (OCCUPIED)")
		_check(sorcier.cabin_lock, "le sorcier est verrouillé (cabin_lock)")
		_check(porte.z_index == Cabin.Z_PORTE_DEVANT,
			"la porte passe devant le sorcier enfermé")
		_check(sorcier.get_node("PipeManager").visible,
			"le sac est encore visible pendant la fermeture")
		var au_repos := true
		for i in range(3):
			if absf(_tuyau(i).position.y - _positions_tuyaux[i].y) > 0.5:
				au_repos = false
		_check(au_repos, "les tuyaux restent en place tant que la porte n'est pas fermée")
		# Appui AVANT la fermeture : ne doit rien déclencher.
		inst.appui_bouton(0, true)
		_check(not (inst.get_node("BoutonsLumiere/BoutonLumiere_fossil/Icone") as AnimatedSprite2D).visible,
			"le panneau n'apparaît pas tant que la porte n'est pas fermée")

	# --- La porte se ferme : les tuyaux sortent, le panneau apparaît ---
	# Les tuyaux ne bougent qu'après la fermeture complète (animation_finished) :
	# leur premier déplacement signale que le choix est ouvert.
	if not _pressed and inst.etat == Cabin.Etat.OCCUPIED \
			and _tuyau(0).position.y < _positions_tuyaux[0].y - 0.5:
		_pressed = true
		_press_step = step
		_check((inst.get_node("BoutonsLumiere/BoutonLumiere_fossil/Icone") as AnimatedSprite2D).visible,
			"le panneau apparaît à la fermeture de la porte")
		inst.appui_bouton(0, true)

	# La lumière s'allume dès l'appui (la frame 0 vide ne doit pas retarder).
	if _pressed and not _lumiere_verifie:
		var lumiere := inst.get_node("BoutonsLumiere/BoutonLumiere_fossil") as AnimatedSprite2D
		if lumiere.frame >= 1:
			_lumiere_verifie = true
			_check(step - _press_step <= 6,
				"la lumière s'allume immédiatement (pas de frame morte)")

	if _pressed and not _ordre_verifie:
		var y0 := _tuyau(0).position.y
		var y1 := _tuyau(1).position.y
		var y2 := _tuyau(2).position.y
		# Fenêtre : le dernier a démarré, le premier n'a pas fini.
		if y2 < _positions_tuyaux[2].y - 1.0 \
				and y0 > _positions_tuyaux[0].y - Cabin.SORTIE_TUYAUX + 1.0:
			_check(y0 < y1 and y1 < y2,
				"les tuyaux sortent de gauche à droite (léger décalage)")
			_ordre_verifie = true

	# --- Confirmation : explosion, tuyaux montés, sac caché ---
	if not _confirme_verifie and inst.etat == Cabin.Etat.CONFIRMING:
		_confirme_verifie = true
		_check(explosion.visible, "explosion lancée à la confirmation")
		var arrives := true
		for i in range(3):
			if absf(_tuyau(i).position.y
					- (_positions_tuyaux[i].y - Cabin.SORTIE_TUYAUX)) > 0.5:
				arrives = false
		_check(arrives, "les 3 tuyaux sont montés de %d px" % int(Cabin.SORTIE_TUYAUX))
		_check(not sorcier.get_node("PipeManager").visible,
			"le sac a disparu à l'avant-dernière frame de fermeture")

	# --- L'objet disparaît à la frame 3 de l'explosion ---
	# Marge après la frame 3 : l'ordre entre _physics_process (test) et
	# _process (AnimatedSprite/cabine) peut décaler d'une frame.
	if not _objet_verifie and explosion.frame >= 10:
		_objet_verifie = true
		_check(_objet == null or not _objet.visible,
			"l'objet disparaît pendant l'explosion")

	# --- Les tuyaux se replient AVANT l'ouverture de la porte ---
	if not _retract_verifie and inst.etat == Cabin.Etat.RETRACTING:
		_retract_verifie = true
		_check(porte.frame == 11,
			"la porte reste fermée pendant que les tuyaux se replient")
		_check(not sorcier.get_node("PipeManager").visible,
			"le sac reste caché pendant le repli")

	# --- Fin du rituel : set_attack réel, signal, icônes ---
	if not _done_verifie and inst.etat == Cabin.Etat.DONE:
		_done_verifie = true
		_check(_signal_recu, "signal sort_installe émis")
		_check(_signal_tube == 0, "sort installé dans le tube 0")
		_check(_signal_type == GlobalEnum.AttackType.L2, "nouveau sort = L2")
		_check(sorcier.spells[0].get("attack_type", -1) == GlobalEnum.AttackType.L2,
			"set_attack RÉEL appliqué au sorcier")
		_check(not sorcier.cabin_lock, "le sorcier est déverrouillé")
		_check(sorcier.get_node("PipeManager").visible,
			"le sac réapparaît à l'ouverture de la porte")
		_check(inst.get_node("Pipe Fossil/Icone").animation == "Icone_AtkL2",
			"l'icône du tuyau soulevé a été remplacée (frame 63)")
		_check(not inst.get_node("Icones/IconeReceptacle").visible,
			"le réceptacle et son icône ont disparu (frame 30)")
		var lueurs_eteintes := true
		for n in ["BoutonsLumiere/BoutonLumiere_fossil", "BoutonsLumiere/BoutonLumiere_energy",
				"BoutonsLumiere/BoutonLumiere_tainted"]:
			if (inst.get_node(n) as AnimatedSprite2D).visible:
				lueurs_eteintes = false
		_check(lueurs_eteintes, "les lumières ont disparu à la mise en tube (frame 63)")
		var icone_panneau := inst.get_node("BoutonsLumiere/BoutonLumiere_fossil/Icone") as AnimatedSprite2D
		_check(not icone_panneau.visible or icone_panneau.modulate.a < 1.0,
			"les icônes du panneau disparaissent en fondu à la réouverture")
		# Le sorcier sort : on l'éloigne pour déclencher body_exited.
		sorcier.global_position = Vector2(400.0, 20.0)

	if _done_verifie and not _inert_verifie and inst.etat == Cabin.Etat.INERT:
		_inert_verifie = true
		_check(porte.z_index == 0,
			"le z_index de la porte revient à sa base après la sortie")
		# Cabine sans objet : inerte.
		inst_vide.entrer(sorcier)
		_check(inst_vide.etat == Cabin.Etat.ACTIVE,
			"une cabine sans objet reste ACTIVE (inerte)")
		_check(inst_vide.est_inerte(), "est_inerte() vrai sans objet")

	if _inert_verifie and not _fade_verifie:
		if not (inst.get_node("BoutonsLumiere/BoutonLumiere_fossil/Icone") as AnimatedSprite2D).visible:
			_fade_verifie = true
			_check(true, "fade out terminé : icône du panneau masquée")

	# --- Cabine verrouillée : fermée de base, entrée refusée ---
	if _inert_verifie and not _verrou_ferme_verifie:
		_verrou_ferme_verifie = true
		var porte_verrou := inst_verrou.get_node("AnimatedSprite2D_porte") as AnimatedSprite2D
		_check(inst_verrou.verrouillee, "cabine verrouillée : verrouillee vrai")
		_check(porte_verrou.frame == porte_verrou.sprite_frames.get_frame_count(porte_verrou.animation) - 1,
			"cabine verrouillée : porte fermée de base")
		_check((inst_verrou.get_node("AnimatedSprite2D_box") as AnimatedSprite2D).frame == 0,
			"cabine verrouillée : ombre fermée")
		_check(not inst_verrou.get_node("ZoneEntree").monitoring,
			"cabine verrouillée : détection d'entrée coupée")
		var objet_verrou := _trouver_objet(inst_verrou)
		_check(objet_verrou != null and objet_verrou.capturable == false,
			"cabine verrouillée : objet présent et intrapable")
		inst_verrou.entrer(sorcier)
		_check(inst_verrou.etat == Cabin.Etat.ACTIVE,
			"cabine verrouillée : entrer() est refusé")
		# Déverrouillage : les portes s'ouvrent tout de suite.
		inst_verrou.ouvrir()
		_check(not inst_verrou.verrouillee, "ouvrir() déverrouille la cabine")
		_check(inst_verrou.get_node("ZoneEntree").monitoring,
			"ouvrir() réarme la détection d'entrée")

	# Les portes s'ouvrent par animation : on attend qu'elles soient
	# arrivées à bout, puis le sorcier peut entrer.
	if _verrou_ferme_verifie and not _verrou_ouvert_verifie:
		var porte_verrou := inst_verrou.get_node("AnimatedSprite2D_porte") as AnimatedSprite2D
		if porte_verrou.frame == 0:
			_verrou_ouvert_verifie = true
			_check(true, "ouvrir() ouvre les portes jusqu'au bout")
			sorcier.global_position = inst_verrou.position + Vector2(-22.5, 20.0)

	if _verrou_ouvert_verifie and not _verrou_occup_verifie:
		if inst_verrou.etat == Cabin.Etat.OCCUPIED:
			_verrou_occup_verifie = true
			_check(true, "cabine déverrouillée : la détection fait entrer le sorcier")

	# --- Fin ---
	if (_fade_verifie and _verrou_occup_verifie) or step > 4000:
		if not _fade_verifie:
			_check(false, "le rituel s'est terminé dans le temps imparti")
		if not _verrou_occup_verifie:
			_check(false, "la cabine verrouillée s'est ouverte et a accueilli le sorcier dans le temps imparti")
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
