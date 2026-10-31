extends Node
## Test headless de l'« objet vivant » : lévitation (sinus vertical,
## phase fixée pour être déterministe), onde de chaleur (création,
## expansion), ébranlement au contact sans tube ouvert (recul puis
## retour élastique à zéro), et extinction de tout au moment de
## l'attrapage. Lancé comme scène :
## godot --headless res://tests/test_objet_vivant.tscn
##
## NB historique : ce test se contentait d'IMPRIMER ses booléens, sans
## jamais échouer — il affichait « false (true attendu) » en silence
## pendant que le contact ne se produisait plus du tout. Un test qui ne
## peut pas échouer ne teste rien : il utilise maintenant le _check /
## RESULT commun, et les positions sont commentées.

var step := 0
var sorcier: Sorcerer
var objet: AttackObject
var base := Vector2.ZERO
var _failures := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: " + label)
	else:
		print("FAIL: " + label)
		_failures += 1


func _ready() -> void:
	# Sol sous le sorcier : sans lui, le CharacterBody2D tombe à l'infini.
	# À la fin du test il était 11 000 px plus bas, donc hors du
	# chevauchement de l'objet : l'attrapage échouait. Surface à y = 332,
	# soit les pieds du sorcier (centre + 32) → il se tient à y = 300,
	# à la hauteur de l'objet.
	var sol := StaticBody2D.new()
	sol.collision_layer = 1
	var forme := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	forme.shape = rect
	forme.position = Vector2(576, 352)
	sol.add_child(forme)
	add_child(sol)

	var sorc_scene: PackedScene = load("res://scenes/entities/players/sorcerer.tscn")
	sorcier = sorc_scene.instantiate()
	sorcier.controller_id = 0
	sorcier.load_data()
	sorcier.in_shop = true
	add_child(sorcier)
	var obj_scene: PackedScene = load("res://scenes/objets/obj_p1_seeds.tscn")
	objet = obj_scene.instantiate()
	objet.position = Vector2(300, 300)
	add_child(objet)
	# Phase fixée APRÈS add_child (le _ready de l'objet la randomise) :
	# offset maximal au démarrage, comportement déterministe
	objet._phase_levitation = PI / 2
	base = objet.position
	# Le sorcier démarre HORS de portée : aucun chevauchement, donc aucune
	# prise automatique pendant qu'on mesure la lévitation. Il sera
	# rapproché juste avant le contact (cf. step 18).
	sorcier.global_position = objet.global_position + Vector2(-60, 0)


func _physics_process(_delta: float) -> void:
	step += 1
	if step == 5:
		# Lévitation : l'objet a quitté sa base verticalement (≤ amplitude)
		var ecart := objet.position.y - base.y
		_check(ecart > 4.0 and ecart < 5.5,
			"lévitation dans l'amplitude (écart %.2f, ~+4.8 attendu)" % ecart)
		_check(absf(objet.position.x - base.x) < 0.01,
			"lévitation : pas de dérive horizontale")
	if step == 8:
		# Onde de chaleur DÉSACTIVÉE (ONDE_ACTIVE = false) : jamais créée,
		# jamais visible (le shader reste de côté pour réactivation)
		_check(objet._onde == null, "onde désactivée (non créée)")
	if step == 18:
		# Contact sans tube ouvert : le sorcier entre en chevauchement RÉEL
		# (essayer_attraper refuse l'objet si overlaps_body() est faux).
		# Capsule du sorcier : 40 px de large (rayon 10 × échelle 2) ; disque
		# de l'objet : ~22 px. À 20 px d'écart le chevauchement ne fait que
		# 11 px, donc la poussée de 13 px l'annule : l'objet ressort du
		# chevauchement, y rentre à nouveau en revenant, et se fait repousser
		# en boucle. À 10 px d'écart le chevauchement (21 px) survit à la
		# poussée : on mesure bien UN ébranlement, puis son retour élastique.
		sorcier.selected_tube = -1
		sorcier.global_position = objet.global_position + Vector2(-10, 0)
	if step == 20:
		objet._on_body_entered(sorcier)
	if step == 24:
		_check(objet._recul.length() > 1.0, "recul en cours (poussée)")
		_check(objet._recul.x > 0.0, "poussée opposée au joueur (vers +x)")
		_check(is_instance_valid(objet), "objet toujours présent")
	if step == 160:
		# Retour élastique terminé (0.13 + 2.1 s ≈ 134 frames)
		_check(objet._recul.length() < 0.01, "retour élastique terminé")
		_check(absf(objet.position.x - base.x) < 0.01, "recul horizontal nul")
	if step == 162:
		# Attrapage : tube ouvert → vol ; l'onde et l'ébranlement cessent
		sorcier.selected_tube = 0
		sorcier.spells = {0: {}, 1: {}, 2: {}}
		objet._on_body_entered(sorcier)
	if step == 166:
		_check(objet._onde == null or not is_instance_valid(objet._onde),
			"onde éteinte au vol")
		_check(objet._sphere != null, "sphère du vol créée")
		if _failures == 0:
			print("RESULT: PASS")
			get_tree().quit(0)
		else:
			print("RESULT: FAIL (%d)" % _failures)
			get_tree().quit(1)
